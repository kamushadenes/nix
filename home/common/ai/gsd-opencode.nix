# GSD (Get Shit Done) framework for OpenCode
#
# Manages all GSD files via Nix instead of the npm installer.
# Files are stored in resources/opencode/gsd/ and deployed to ~/.config/opencode/.
# Update with: gsd-update-opencode script
{
  config,
  lib,
  pkgs,
  ...
}:
let
  gsdDir = ./resources/opencode/gsd;
  scriptsDir = ./resources/opencode/scripts;

  # Recursively collect all files from a directory
  collectFiles =
    basePath: prefix:
    let
      entries = builtins.readDir basePath;
    in
    lib.foldl' (
      acc: name:
      let
        fullPath = "${basePath}/${name}";
        relPath = if prefix == "" then name else "${prefix}/${name}";
        type = entries.${name};
      in
      if type == "directory" then
        acc // (collectFiles fullPath relPath)
      else
        acc // { ${relPath} = fullPath; }
    ) { } (builtins.attrNames entries);

  # Build home.file entries for each category
  mkFileEntry = destPrefix: name: sourcePath: {
    name = ".config/opencode/${destPrefix}/${name}";
    value =
      if lib.hasSuffix ".js" name || lib.hasSuffix ".cjs" name || lib.hasSuffix ".sh" name then
        {
          source = sourcePath;
          executable = true;
        }
      else
        { source = sourcePath; };
  };

  # Guard: only collect if gsdDir exists (files may not be vendored yet)
  hasGsd = builtins.pathExists gsdDir;

  agentFiles = if hasGsd && builtins.pathExists "${gsdDir}/agents" then collectFiles "${gsdDir}/agents" "" else { };
  # OpenCode uses "command/" (singular) unlike Claude Code's "commands/"
  commandFiles = if hasGsd && builtins.pathExists "${gsdDir}/command" then collectFiles "${gsdDir}/command" "" else { };
  coreFiles = if hasGsd && builtins.pathExists "${gsdDir}/get-shit-done" then collectFiles "${gsdDir}/get-shit-done" "" else { };
  hookFiles = if hasGsd && builtins.pathExists "${gsdDir}/hooks" then collectFiles "${gsdDir}/hooks" "" else { };

  agentEntries = lib.mapAttrs' (mkFileEntry "agents") agentFiles;
  commandEntries = lib.mapAttrs' (mkFileEntry "command") commandFiles;
  coreEntries = lib.mapAttrs' (mkFileEntry "get-shit-done") coreFiles;
  hookEntries = lib.mapAttrs' (mkFileEntry "hooks") hookFiles;
in
{
  home.file =
    agentEntries
    // commandEntries
    // coreEntries
    // hookEntries
    // lib.optionalAttrs (hasGsd && builtins.pathExists "${gsdDir}/gsd-file-manifest.json") {
      ".config/opencode/gsd-file-manifest.json".source = "${gsdDir}/gsd-file-manifest.json";
    }
    // lib.optionalAttrs (builtins.pathExists "${scriptsDir}/gsd-update-opencode.sh") {
      ".config/opencode/scripts/gsd-update-opencode.sh" = {
        source = "${scriptsDir}/gsd-update-opencode.sh";
        executable = true;
      };
    };
}
