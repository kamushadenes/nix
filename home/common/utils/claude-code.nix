{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Build settings.json content
  settingsContent =
    { }
    // lib.optionalAttrs (config.programs.claude-code.hooks != { }) {
      hooks = lib.filterAttrs (n: v: v != [ ]) config.programs.claude-code.hooks;
    }
    // lib.optionalAttrs (config.programs.claude-code.statusLine != null) {
      statusLine = config.programs.claude-code.statusLine;
    }
    // lib.optionalAttrs (config.programs.claude-code.enabledPlugins != { }) {
      enabledPlugins = config.programs.claude-code.enabledPlugins;
    }
    // lib.optionalAttrs (config.programs.claude-code.mcpServers != { }) {
      mcpServers = config.programs.claude-code.mcpServers;
    };
in
{
  options.programs.claude-code = {
    enable = lib.mkEnableOption "Claude Code settings management";

    hooks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.attrs);
      default = { };
      description = "Hook configurations (PreToolUse, PostToolUse, SessionStart, Stop, UserPromptSubmit)";
    };

    statusLine = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      default = null;
      description = "Status line configuration";
    };

    enabledPlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = { };
      description = "Map of plugin names to enabled status";
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "MCP server configurations. Use @PLACEHOLDER@ syntax for secrets.";
    };

    secretSubstitutions = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Map of @PLACEHOLDER@ patterns to agenix secret file paths for substitution";
    };
  };

  config = lib.mkIf config.programs.claude-code.enable {
    # Agenix secrets for Claude Code
    age.secrets = {
      "claude-ref-api-key" = {
        file = ./resources/claude/ref-api-key.age;
        path = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
      };
      "claude-openrouter-api-key" = {
        file = ./resources/claude/openrouter-api-key.age;
        path = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
      };
    };

    # Write template with placeholders
    home.file.".claude/settings.json.template".text = builtins.toJSON settingsContent;

    # Activation script to substitute secrets
    home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${config.home.homeDirectory}/.claude
      run mkdir -p ${config.home.homeDirectory}/.claude/secrets
      run cp ${config.home.homeDirectory}/.claude/settings.json.template \
             ${config.home.homeDirectory}/.claude/settings.json
      ${lib.concatMapStrings (
        ph:
        let
          secretPath = config.programs.claude-code.secretSubstitutions.${ph};
        in
        ''
          if [ -f "${secretPath}" ]; then
            run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" \
                ${config.home.homeDirectory}/.claude/settings.json
          fi
        ''
      ) (lib.attrNames config.programs.claude-code.secretSubstitutions)}
    '';
  };

  # Default configuration - enable and set current values
  programs.claude-code = {
    enable = true;

    hooks = {
      PreToolUse = [
        {
          matcher = "Write|Edit|MultiEdit|TodoWrite";
          hooks = [
            {
              type = "command";
              command = "tdd-guard";
            }
          ];
        }
      ];
      UserPromptSubmit = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "tdd-guard";
            }
          ];
        }
      ];
      SessionStart = [
        {
          matcher = "startup|resume|clear";
          hooks = [
            {
              type = "command";
              command = "tdd-guard";
            }
          ];
        }
      ];
      Stop = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "~/.claude/hooks/post-lint.sh";
            }
            {
              type = "command";
              command = "echo \"Make sure to update AGENTS.md and README.md\"";
            }
          ];
        }
      ];
      PostToolUse = [
        {
          matcher = "Edit(*.tf)|Write(*.tf)";
          hooks = [
            {
              type = "command";
              command = ".claude/hooks/trivy-tf.sh";
            }
          ];
        }
        {
          matcher = "Edit(*.hcl)|Write(*.hcl)";
          hooks = [
            {
              type = "command";
              command = ".claude/hooks/trivy-tf.sh";
            }
          ];
        }
      ];
    };

    statusLine = {
      type = "command";
      command = "bash ${config.home.homeDirectory}/.claude/statusline-command.sh";
    };

    enabledPlugins = {
      "gopls-lsp@claude-plugins-official" = true;
      "github@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "backend-api-security@claude-code-workflows" = true;
      "backend-development@claude-code-workflows" = true;
      "dependency-management@claude-code-workflows" = true;
      "full-stack-orchestration@claude-code-workflows" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "python-development@claude-code-workflows" = true;
      "security-scanning@claude-code-workflows" = true;
      "fullstack-dev-skills@fullstack-dev-skills" = true;
      "commit-commands@claude-plugins-official" = true;
      "security-guidance@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;
      "superpowers@superpowers-marketplace" = true;
      "cloud-infrastructure@claude-code-workflows" = true;
      "cicd-automation@claude-code-workflows" = true;
    };

    mcpServers = {
      deepwiki = {
        type = "http";
        url = "https://mcp.deepwiki.com/mcp";
      };
      Ref = {
        type = "http";
        url = "https://api.ref.tools/mcp";
        headers = {
          "x-ref-api-key" = "@REF_API_KEY@";
        };
      };
      repomix = {
        type = "stdio";
        command = "npx";
        args = [
          "-y"
          "repomix"
          "--mcp"
        ];
        env = { };
      };
      pal = {
        type = "stdio";
        command = "uvx";
        args = [
          "--from"
          "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
          "pal-mcp-server"
        ];
        env = {
          OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@";
          DISABLED_TOOLS = "tracer";
        };
      };
      godoc = {
        type = "stdio";
        command = "godoc-mcp";
        args = [ ];
        env = { };
      };
    };

    secretSubstitutions = {
      "@REF_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
      "@OPENROUTER_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
    };
  };
}
