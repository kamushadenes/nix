# GSD (Get Shit Done) framework for Codex CLI
#
# Manages all GSD files via Nix instead of the npm installer.
# Files are stored in resources/codex/gsd/ and deployed to ~/.codex/.
# Update with: /gsd-update (runs npx --local in tmpdir, syncs back here)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  gsdDir = ./resources/codex/gsd;

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
  skillFiles = collectFiles "${gsdDir}/skills" "";
  coreFiles = collectFiles "${gsdDir}/get-shit-done" "";

  # Build home.file entries for each category
  mkFileEntry = destPrefix: name: sourcePath: {
    name = ".codex/${destPrefix}/${name}";
    value =
      if lib.hasSuffix ".js" name || lib.hasSuffix ".cjs" name || lib.hasSuffix ".sh" name then
        {
          source = sourcePath;
          executable = true;
        }
      else
        { source = sourcePath; };
  };

  scriptsDir = ./resources/codex/scripts;

  agentEntries = lib.mapAttrs' (mkFileEntry "agents") agentFiles;
  skillEntries = lib.mapAttrs' (mkFileEntry "skills") skillFiles;
  coreEntries = lib.mapAttrs' (mkFileEntry "get-shit-done") coreFiles;
in
{
  home.file =
    agentEntries
    // skillEntries
    // coreEntries
    // {
      ".codex/gsd-file-manifest.json".source = "${gsdDir}/gsd-file-manifest.json";
      # Note: GSD's config.toml is NOT deployed here — it would conflict with
      # codex-cli.nix's config.toml (MCP servers, model settings, features).
      # Agent discovery works via ~/.codex/agents/ directory, not config.toml registration.

      # Update script
      ".codex/scripts/gsd-update.sh" = {
        source = "${scriptsDir}/gsd-update.sh";
        executable = true;
      };
    };
}
