---
allowed-tools: mcp__task-master-ai__initialize_project, Read, Edit
description: Initialize task-master for a project with Claude Code provider
---

# Initialize Task Master

Set up task-master in the current project with Claude Code as the main provider.

## Steps

1. **Check if already initialized:**
   Use Read to check if `.taskmaster/config.json` exists.

2. **If not initialized, use MCP to initialize:**
   Call `mcp__task-master-ai__initialize_project` with:

   - `projectRoot`: Current working directory (absolute path)
   - `rules`: `["claude"]`
   - `skipInstall`: `true`
   - `addAliases`: `false`
   - `initGit`: `false`
   - `storeTasksInGit`: `true`
   - `yes`: `true`

3. **Update config.json for Claude Code provider:**
   After initialization, use Edit to update `.taskmaster/config.json` with:

   ```json
   {
     "models": {
       "main": {
         "provider": "claude-code",
         "modelId": "sonnet",
         "maxTokens": 64000,
         "temperature": 0.2
       },
       "research": {
         "provider": "claude-code",
         "modelId": "opus",
         "maxTokens": 32000,
         "temperature": 0.1
       },
       "fallback": {
         "provider": "claude-code",
         "modelId": "sonnet",
         "maxTokens": 64000,
         "temperature": 0.2
       }
     }
   }
   ```

4. **Cleanup**

- Remove .env.example
- Remove .mcp.json

5. **Report success:**

   ```
   Task-master initialized with:
   - Main model: Claude Code (sonnet)
   - Research model: Claude Code (opus)
   - Fallback model: Claude Code (sonnet)

   Next steps:
   - Add a PRD to .taskmaster/docs/prd.txt and run `parse_prd`
   - Or use `add_task` to create tasks manually
   ```

## If already initialized

If `.taskmaster/config.json` exists, ask the user:

- "Reset config?" - Overwrite config.json with Claude Code provider defaults
- "Keep existing" - Do nothing
