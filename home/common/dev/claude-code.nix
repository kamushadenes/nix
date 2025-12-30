# Claude Code (claude.ai/code) configuration module
#
# This module manages ~/.claude/settings.json declaratively with support for:
# - Hooks (PreToolUse, PostToolUse, SessionStart, Stop, UserPromptSubmit)
# - Status line customization
# - Plugin management
# - MCP (Model Context Protocol) servers with secret substitution
#
# Secrets are encrypted with agenix and substituted at activation time.
# Use @PLACEHOLDER@ syntax in configs, map them in secretSubstitutions.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Build the final settings.json content from configured options
  # Only includes non-empty sections to keep the output clean
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
  #############################################################################
  # Option Definitions
  #############################################################################

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

  #############################################################################
  # Module Implementation
  #############################################################################

  config = lib.mkIf config.programs.claude-code.enable {
    # Decrypt secrets to ~/.claude/secrets/ at activation
    age.secrets = {
      "claude-ref-api-key" = {
        file = ./resources/claude/ref-api-key.age;
        path = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
      };
      "claude-openrouter-api-key" = {
        file = ./resources/claude/openrouter-api-key.age;
        path = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
      };
      "claude-tfe-token" = {
        file = ./resources/claude/tfe-token.age;
        path = "${config.home.homeDirectory}/.claude/secrets/tfe-token";
      };
    };

    # Write template file with @PLACEHOLDER@ values (will be substituted later)
    home.file.".claude/settings.json.template".text = builtins.toJSON settingsContent;

    # Activation script: copy template and substitute secrets
    home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${config.home.homeDirectory}/.claude
      run mkdir -p ${config.home.homeDirectory}/.claude/secrets

      # Copy template to final location
      run cp ${config.home.homeDirectory}/.claude/settings.json.template \
             ${config.home.homeDirectory}/.claude/settings.json

      # Substitute each @PLACEHOLDER@ with its decrypted secret value
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

  #############################################################################
  # Default Configuration
  #############################################################################

  programs.claude-code = {
    enable = true;

    # Hooks - commands that run at various points in Claude Code's lifecycle
    hooks = {
      # Run before file modifications - TDD guard ensures tests exist
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

      # Run on every user prompt submission
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

      # Run at session start/resume/clear
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

      # Run when Claude stops working
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

      # Run after file modifications - security scanning for IaC files
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

    # Custom status line command
    statusLine = {
      type = "command";
      command = "bash ${config.home.homeDirectory}/.claude/statusline-command.sh";
    };

    # Enabled plugins from various marketplaces
    enabledPlugins = {
      # Official plugins
      "gopls-lsp@claude-plugins-official" = true;
      "github@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      "pyright-lsp@claude-plugins-official" = true;
      "commit-commands@claude-plugins-official" = true;
      "security-guidance@claude-plugins-official" = true;
      "pr-review-toolkit@claude-plugins-official" = true;

      # Claude Code Workflows
      "backend-api-security@claude-code-workflows" = true;
      "backend-development@claude-code-workflows" = true;
      "dependency-management@claude-code-workflows" = true;
      "full-stack-orchestration@claude-code-workflows" = true;
      "python-development@claude-code-workflows" = true;
      "security-scanning@claude-code-workflows" = true;
      "cloud-infrastructure@claude-code-workflows" = true;
      "cicd-automation@claude-code-workflows" = true;

      # Third-party
      "fullstack-dev-skills@fullstack-dev-skills" = true;
      "superpowers@superpowers-marketplace" = true;
    };

    # MCP (Model Context Protocol) servers
    # These provide additional tools and context to Claude Code
    mcpServers = {
      # DeepWiki - GitHub repository documentation
      deepwiki = {
        type = "http";
        url = "https://mcp.deepwiki.com/mcp";
      };

      # Ref - Documentation search (requires API key)
      Ref = {
        type = "http";
        url = "https://api.ref.tools/mcp";
        headers = {
          "x-ref-api-key" = "@REF_API_KEY@"; # Substituted from agenix secret
        };
      };

      # Repomix - Codebase packaging for AI analysis
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

      # PAL - Multi-model AI assistant
      pal = {
        type = "stdio";
        command = "uvx";
        args = [
          "--from"
          "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
          "pal-mcp-server"
        ];
        env = {
          OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@"; # Substituted from agenix secret
          DISABLED_TOOLS = "tracer";
        };
      };

      # Go documentation server
      godoc = {
        type = "stdio";
        command = "godoc-mcp";
        args = [ ];
        env = { };
      };

      # Terraform MCP - Terraform Cloud/Enterprise integration
      terraform = {
        type = "stdio";
        command = "docker";
        args = [
          "run"
          "-i"
          "--rm"
          "-e"
          "TFE_TOKEN=@TFE_TOKEN@" # Substituted from agenix secret
          "-e"
          "TFE_ADDRESS=https://app.terraform.io"
          "hashicorp/terraform-mcp-server"
        ];
        env = { };
      };
    };

    # Map placeholders to their decrypted secret paths
    secretSubstitutions = {
      "@REF_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
      "@OPENROUTER_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
      "@TFE_TOKEN@" = "${config.home.homeDirectory}/.claude/secrets/tfe-token";
    };
  };
}
