# GSD (Get Shit Done) framework for Claude Code
#
# Manages all GSD files via Nix instead of the npm installer.
# Files are stored in resources/claude-code/gsd/ and deployed to ~/.claude/.
# Update with: /gsd-update (runs npx --local in tmpdir, syncs back here)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  gsdDir = ./resources/claude-code/gsd;

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
  commandFiles = collectFiles "${gsdDir}/commands" "";
  coreFiles = collectFiles "${gsdDir}/get-shit-done" "";
  hookFiles = collectFiles "${gsdDir}/hooks" "";

  # Build home.file entries for each category
  mkFileEntry = destPrefix: name: sourcePath: {
    name = ".claude/${destPrefix}/${name}";
    value =
      if lib.hasSuffix ".js" name || lib.hasSuffix ".cjs" name || lib.hasSuffix ".sh" name then
        {
          source = sourcePath;
          executable = true;
        }
      else
        { source = sourcePath; };
  };

  scriptsDir = ./resources/claude-code/scripts;

  agentEntries = lib.mapAttrs' (mkFileEntry "agents") agentFiles;
  commandEntries = lib.mapAttrs' (mkFileEntry "commands") commandFiles;
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
      ".claude/gsd-file-manifest.json".source = "${gsdDir}/gsd-file-manifest.json";

      # Update script
      ".claude/scripts/gsd-update.sh" = {
        source = "${scriptsDir}/gsd-update.sh";
        executable = true;
      };
    };
}
