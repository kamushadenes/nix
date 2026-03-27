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

  # OpenCode's skill tool only discovers ~/.agents/skills/, not ~/.config/opencode/command/.
  # GSD workflows chain commands via Skill(skill="gsd-plan-phase") which uses the skill tool.
  # Generate minimal skill wrappers that bridge to the actual command files.
  commandDirEntries = builtins.readDir "${gsdDir}/command";
  realSkillNames = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./resources/agents/skills)
  );
  gsdCommandNames = builtins.filter (
    name:
    lib.hasPrefix "gsd-" name
    && lib.hasSuffix ".md" name
    && !builtins.elem (lib.removeSuffix ".md" name) realSkillNames
  ) (builtins.attrNames commandDirEntries);

  mkSkillWrapper =
    cmdFileName:
    let
      skillName = lib.removeSuffix ".md" cmdFileName;
    in
    {
      name = ".agents/skills/${skillName}/SKILL.md";
      value.text = ''
        ---
        name: ${skillName}
        description: GSD command ${skillName}. Loaded by GSD workflow chains.
        ---

        Read and follow the full instructions at `$HOME/.config/opencode/command/${cmdFileName}`.
      '';
    };

  skillWrapperEntries = builtins.listToAttrs (map mkSkillWrapper gsdCommandNames);
in
{
  home.file =
    agentEntries
    // commandEntries
    // coreEntries
    // hookEntries
    // skillWrapperEntries
    // {
      ".config/opencode/gsd-file-manifest.json".source = "${gsdDir}/gsd-file-manifest.json";

      ".config/opencode/scripts/gsd-update.sh" = {
        source = "${scriptsDir}/gsd-update.sh";
        executable = true;
      };
    };
}
