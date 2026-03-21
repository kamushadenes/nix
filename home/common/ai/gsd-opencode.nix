# GSD (Get Shit Done) framework for OpenCode
#
# Manages all GSD files via Nix instead of the npm installer.
# Files are stored in resources/opencode/gsd/ and deployed to ~/.config/opencode/.
# Update with: /gsd-update (runs npx --local in tmpdir, syncs back here)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  gsdDir = ./resources/opencode/gsd;

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

  # Collect all files from each GSD subdirectory
  agentFiles = collectFiles "${gsdDir}/agents" "";
  commandFiles = collectFiles "${gsdDir}/command" "";
  coreFiles = collectFiles "${gsdDir}/get-shit-done" "";
  hookFiles = collectFiles "${gsdDir}/hooks" "";

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

  scriptsDir = ./resources/opencode/scripts;

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
    // {
      ".config/opencode/gsd-file-manifest.json".source = "${gsdDir}/gsd-file-manifest.json";
      ".config/opencode/package.json".source = "${gsdDir}/package.json";

      # Update script
      ".config/opencode/scripts/gsd-update.sh" = {
        source = "${scriptsDir}/gsd-update.sh";
        executable = true;
      };
    };
}
