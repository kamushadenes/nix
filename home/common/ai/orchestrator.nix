# Agent Skills deployment
#
# Auto-discovers skills from resources/agents/skills/ and deploys to:
# - ~/.agents/skills/ (agentskills.io standard - OpenCode, Cursor, Gemini CLI, etc.)
# - ~/.claude/skills/ (Claude Code native discovery)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Resource directories
  sharedDir = ./resources/agents;
  skillsDir = "${sharedDir}/skills";

  # Auto-discover all skill directories (excluding _shared)
  skillEntries = builtins.readDir skillsDir;
  skillDirs = lib.filterAttrs (
    name: type: type == "directory" && !lib.hasPrefix "_" name
  ) skillEntries;

  # Recursively collect all files within a skill directory
  collectFilesRecursive =
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
        acc // (collectFilesRecursive fullPath relPath)
      else
        acc // { ${relPath} = fullPath; }
    ) { } (builtins.attrNames entries);

  # Collect all files from all skill directories
  skillFiles = lib.foldl' (
    acc: skillName:
    let
      skillPath = "${skillsDir}/${skillName}";
      files = collectFilesRecursive skillPath "";
    in
    acc
    // lib.mapAttrs' (relPath: srcPath: {
      name = "${skillName}/${relPath}";
      value = srcPath;
    }) files
  ) { } (builtins.attrNames skillDirs);

  # Convert skill files to home.file entries for a given prefix
  mkSkillEntries =
    prefix:
    lib.mapAttrs' (name: sourcePath: {
      name = "${prefix}/${name}";
      value =
        if lib.hasSuffix ".py" name || lib.hasSuffix ".sh" name then
          {
            source = sourcePath;
            executable = true;
          }
        else
          { source = sourcePath; };
    }) skillFiles;

  agentsSkillEntries = mkSkillEntries ".agents/skills";
  claudeSkillEntries = mkSkillEntries ".claude/skills";
in
{
  home.file = agentsSkillEntries // claudeSkillEntries;
}
