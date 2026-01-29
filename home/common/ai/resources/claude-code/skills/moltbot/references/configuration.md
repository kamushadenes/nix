# Moltbot Configuration Reference

Complete reference for `moltbot.json` configuration.

**Official docs:** https://docs.molt.bot/

## File Location

- Development: `~/.moltbot/moltbot.json`
- This repo: `private/nixos/machines/resources/moltbot/moltbot.json`
- LXC runtime: `/var/lib/moltbot/.moltbot/moltbot.json`

## Top-Level Structure

```json
{
  "meta": { ... },
  "auth": { ... },
  "agents": { ... },
  "messages": { ... },
  "commands": { ... },
  "hooks": { ... },
  "channels": { ... },
  "gateway": { ... },
  "skills": { ... },
  "plugins": { ... },
  "tools": { ... }
}
```

## Auth Section

Defines authentication profiles for LLM providers.

```json
{
  "auth": {
    "profiles": {
      "anthropic:default": {
        "provider": "anthropic",
        "mode": "token"
      },
      "google:default": {
        "provider": "google",
        "mode": "api_key"
      },
      "openai:default": {
        "provider": "openai",
        "mode": "api_key"
      }
    }
  }
}
```

**Modes:**
- `token` - Bearer token authentication
- `api_key` - API key authentication

Actual credentials are stored in `agents/<agent-id>/agent/auth-profiles.json`:

```json
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "token",
      "provider": "anthropic",
      "token": "sk-ant-..."
    },
    "google:default": {
      "type": "api_key",
      "provider": "google",
      "key": "AIza..."
    }
  }
}
```

## Agents Section

Configures LLM agents.

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "google/gemini-3-pro-preview"
      },
      "models": {
        "anthropic/claude-sonnet-4-5": { "alias": "sonnet" },
        "google/gemini-3-pro-preview": { "alias": "gemini" }
      },
      "workspace": "/var/lib/moltbot/workspace",
      "thinkingDefault": "medium",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    },
    "list": [
      {
        "id": "main",
        "default": true
      }
    ]
  }
}
```

**Fields:**
- `model.primary` - Default model for requests
- `models` - Available models with aliases
- `workspace` - Directory for agent file operations
- `thinkingDefault` - Thinking mode: `none`, `low`, `medium`, `high`
- `maxConcurrent` - Max concurrent requests per agent
- `subagents.maxConcurrent` - Max concurrent subagent tasks

## Channels Section

Configures messaging platform integrations.

### Telegram

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "allowFrom": [28814201],
      "groupPolicy": "allowlist",
      "groups": {},
      "streamMode": "partial"
    }
  }
}
```

**Fields:**
- `dmPolicy` - DM handling: `pairing`, `open`, `closed`
- `allowFrom` - Array of allowed Telegram user IDs
- `groupPolicy` - Group handling: `allowlist`, `blocklist`, `open`
- `groups` - Group-specific configurations
- `streamMode` - Response streaming: `partial`, `full`, `none`

### Discord

```json
{
  "channels": {
    "discord": {
      "enabled": true,
      "dmPolicy": "pairing",
      "serverPolicy": "allowlist",
      "allowedServers": ["server-id"]
    }
  }
}
```

### WhatsApp

Requires the whatsapp plugin enabled.

```json
{
  "channels": {
    "whatsapp": {
      "enabled": true
    }
  }
}
```

## Messages Section

Controls message handling behavior.

```json
{
  "messages": {
    "queue": {
      "mode": "interrupt",
      "byChannel": {
        "telegram": "interrupt",
        "discord": "queue",
        "webchat": "queue"
      }
    },
    "ackReactionScope": "group-mentions"
  }
}
```

**Queue modes:**
- `interrupt` - New messages interrupt current processing
- `queue` - Messages queue and process sequentially

## Gateway Section

HTTP gateway configuration.

```json
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token"
    },
    "controlUi": {
      "enabled": true,
      "dangerouslyDisableDeviceAuth": true
    },
    "tailscale": {
      "mode": "off"
    }
  }
}
```

**Fields:**
- `port` - HTTP port for gateway API
- `mode` - Gateway mode: `local`, `remote`
- `bind` - Network binding: `localhost`, `lan`, `all`
- `auth.mode` - Authentication: `token`, `none`
- `controlUi` - Web control panel settings

## Hooks Section

Internal behavior hooks.

```json
{
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": { "enabled": true },
        "command-logger": { "enabled": true },
        "session-memory": { "enabled": true }
      }
    }
  }
}
```

## Tools Section

Built-in tool configuration.

```json
{
  "tools": {
    "web": {
      "search": { "enabled": true },
      "fetch": { "enabled": true }
    }
  }
}
```

## Skills Section

Skill installation and configuration.

```json
{
  "skills": {
    "install": {
      "nodeManager": "pnpm"
    },
    "config": {
      "my-skill": {
        "setting": "value"
      }
    }
  }
}
```

## Plugins Section

Platform plugin configuration.

```json
{
  "plugins": {
    "slots": {
      "memory": "none"
    },
    "entries": {
      "telegram": { "enabled": true },
      "whatsapp": { "enabled": true },
      "discord": { "enabled": true }
    }
  }
}
```

## Commands Section

Native command configuration.

```json
{
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  }
}
```

**Values:**
- `auto` - Automatically register commands
- `manual` - Manually configure commands
- `disabled` - Disable native commands

## Environment Variables

Some settings can be overridden via environment:

- `TELEGRAM_BOT_TOKEN` - Telegram bot token
- `ANTHROPIC_API_KEY` - Anthropic API key
- `GOOGLE_API_KEY` - Google API key
- `BRAVE_SEARCH_API_KEY` - Brave search API key
- `GATEWAY_TOKEN` - Gateway authentication token
- `MOLTBOT_DIR` - Base directory for moltbot data
- `MOLTBOT_THINKING_DEFAULT` - Default thinking mode
