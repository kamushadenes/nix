# Agent Skills deployment
#
# Auto-discovers skills from resources/agents/skills/ and deploys to:
# - ~/.agents/skills/ (agentskills.io standard - OpenCode, Cursor, Gemini CLI, etc.)
# - ~/.claude/skills/ (Claude Code native discovery)
# Note: ~/.codex/skills/ is handled by codex-cli.nix with codex-specific versions
#
# Skills are sourced from two locations and merged (private overrides public on
# name collision):
#   1. Public:  ./resources/agents/skills/
#   2. Private: ${private}/home/common/ai/resources/agents/skills/ (optional)
{
  config,
  lib,
  pkgs,
  private ? null,
  ...
}:
let
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

  # Collect all files from all skill directories under a given skills root
  collectSkillsFromDir =
    skillsDir:
    let
      skillEntries = builtins.readDir skillsDir;
      skillDirs = lib.filterAttrs (
        name: type: type == "directory" && !lib.hasPrefix "_" name
      ) skillEntries;
    in
    lib.foldl' (
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

  # Public skills (always present)
  publicSkillsDir = ./resources/agents/skills;
  publicSkillFiles = collectSkillsFromDir publicSkillsDir;

  # Private skills (optional — only if private submodule available and dir exists)
  privateSkillsPath =
    if private != null then "${private}/home/common/ai/resources/agents/skills" else null;
  privateSkillFiles =
    if privateSkillsPath != null && builtins.pathExists privateSkillsPath then
      collectSkillsFromDir privateSkillsPath
    else
      { };

  # Merge — private wins on collision (lets private override public skill of same name)
  skillFiles = publicSkillFiles // privateSkillFiles;

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
