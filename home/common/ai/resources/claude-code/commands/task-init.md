---
allowed-tools: Bash(mkdir:*), Bash(test:*), Bash(npx task-master-ai:*), Write, Read
description: Initialize task-master for a project with Claude Code provider
---

# Initialize Task Master

Set up task-master in the current project with Claude Code as the main provider and OpenRouter for research.

## Steps

1. **Check if already initialized:**
   ```bash
   test -d .taskmaster
   ```

2. **If not initialized, create directory:**
   ```bash
   mkdir -p .taskmaster/docs
   ```

3. **Create config.json with Claude Code provider:**
   Write to `.taskmaster/config.json`:
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
         "provider": "openrouter",
         "modelId": "anthropic/claude-sonnet-4",
         "maxTokens": 64000,
         "temperature": 0.3
       },
       "fallback": {
         "provider": "openrouter",
         "modelId": "anthropic/claude-sonnet-4",
         "maxTokens": 64000,
         "temperature": 0.2
       }
     },
     "global": {
       "logLevel": "info"
     }
   }
   ```

4. **Create empty tasks.json:**
   Write to `.taskmaster/tasks.json`:
   ```json
   {
     "tasks": [],
     "metadata": {
       "projectName": "",
       "createdAt": "",
       "version": "1.0.0"
     }
   }
   ```

5. **Report success:**
   ```
   Task-master initialized with:
   - Main model: Claude Code (sonnet)
   - Research model: OpenRouter (claude-sonnet-4)

   Next steps:
   - Add a PRD to .taskmaster/docs/prd.txt and run `parse_prd`
   - Or use `add_task` to create tasks manually
   ```

## If already initialized

If `.taskmaster` exists, ask the user:
- "Reset config?" - Overwrite config.json with defaults
- "Keep existing" - Do nothing
