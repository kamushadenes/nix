# Orchestrator MCP Server configuration
#
# Provides:
# - MCP server for terminal automation (tmux_* tools)
# - AI CLI orchestration tools (ai_call, ai_spawn, ai_fetch, ai_review)
# - Auto-discovered skills from resources/claude-code/skills/
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Resource directories
  resourcesDir = ./resources/claude-code;
  scriptsDir = "${resourcesDir}/scripts";
  skillsDir = "${resourcesDir}/skills";

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

  # Convert skill files to home.file entries
  skillFileEntries = lib.mapAttrs' (name: sourcePath: {
    name = ".claude/skills/${name}";
    value =
      if lib.hasSuffix ".py" name || lib.hasSuffix ".sh" name then
        {
          source = sourcePath;
          executable = true;
        }
      else
        { source = sourcePath; };
  }) skillFiles;
in
{
  #############################################################################
  # Orchestrator Files
  #############################################################################

  home.file =
    {
      # Orchestrator MCP server - terminal automation
      ".config/orchestrator-mcp/server.py" = {
        source = "${scriptsDir}/orchestrator-mcp-server.py";
        executable = true;
      };
    }
    // skillFileEntries;
}
