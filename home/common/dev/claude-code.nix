# Claude Code (claude.ai/code) configuration
#
# Uses the built-in home-manager programs.claude-code module for settings.
# MCP servers are managed separately to support secret substitution.
# Secrets are encrypted with agenix and substituted at activation time.
#
# Memory (CLAUDE.md) is managed via the module's memory.text option.
# Rules are organized in ~/.claude/rules/ for modular configuration.
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  private,
  ...
}:
let
  # Resource directories
  resourcesDir = ./resources/claude-code;
  scriptsDir = "${resourcesDir}/scripts";
  skillsDir = "${resourcesDir}/skills";
  rulesDir = "${resourcesDir}/rules";
  memoryDir = "${resourcesDir}/memory";
  commandsDir = "${resourcesDir}/commands";

  # Read rule files from the rules directory
  ruleFiles = builtins.attrNames (builtins.readDir rulesDir);
  rulesConfig = lib.listToAttrs (
    map (name: {
      name = name;
      value = builtins.readFile "${rulesDir}/${name}";
    }) ruleFiles
  );

  # MCP server configurations with @PLACEHOLDER@ for secrets
  # These get written to ~/.claude.json with secrets substituted at activation
  mcpServersConfig = {
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
        "x-ref-api-key" = "@REF_API_KEY@";
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

    # PAL - Multi-model AI assistant (disabled - using alternative approach)
    # pal = {
    #   type = "stdio";
    #   command = "uvx";
    #   args = [
    #     "--from"
    #     "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
    #     "pal-mcp-server"
    #   ];
    #   env = {
    #     OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@";
    #     DISABLED_TOOLS = "tracer";
    #   };
    # };

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
        "TFE_TOKEN=@TFE_TOKEN@"
        "-e"
        "TFE_ADDRESS=https://app.terraform.io"
        "hashicorp/terraform-mcp-server"
      ];
      env = { };
    };

    # tmux MCP - Terminal automation for pane management
    # Uses uvx to run with fastmcp dependency automatically installed
    tmux = {
      type = "stdio";
      command = "uvx";
      args = [
        "--with"
        "fastmcp"
        "python"
        "${config.home.homeDirectory}/.config/tmux-mcp/server.py"
      ];
      env = { };
    };
  };

  # Placeholders to secret paths mapping for substitution
  secretSubstitutions = {
    "@REF_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
    "@OPENROUTER_API_KEY@" = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
    "@TFE_TOKEN@" = "${config.home.homeDirectory}/.claude/secrets/tfe-token";
  };

  # Template file for MCP servers (with placeholders)
  mcpConfigTemplate = builtins.toJSON { mcpServers = mcpServersConfig; };
in
{
  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = {
    "claude-ref-api-key" = {
      file = "${private}/home/common/dev/resources/claude/ref-api-key.age";
      path = "${config.home.homeDirectory}/.claude/secrets/ref-api-key";
    };
    "claude-openrouter-api-key" = {
      file = "${private}/home/common/dev/resources/claude/openrouter-api-key.age";
      path = "${config.home.homeDirectory}/.claude/secrets/openrouter-api-key";
    };
    "claude-tfe-token" = {
      file = "${private}/home/common/dev/resources/claude/tfe-token.age";
      path = "${config.home.homeDirectory}/.claude/secrets/tfe-token";
    };
  };

  #############################################################################
  # Claude Code Configuration (uses home-manager built-in module)
  #############################################################################

  programs.claude-code = {
    enable = true;
    package = pkgs-unstable.claude-code;

    # Note: mcpServers are NOT set here because home-manager doesn't support
    # secret substitution. They're managed separately below via ~/.claude.json

    # Global CLAUDE.md content - applies to all projects
    memory.text = builtins.readFile "${memoryDir}/global.md";

    # Custom slash commands (stored in private submodule for sensitive content)
    commands = {
      test-altinity-cloud = builtins.readFile "${private}/home/common/dev/resources/claude/commands/test-altinity-cloud.md";
      code-review = builtins.readFile "${commandsDir}/code-review.md";
    };

    # Note: rules option is not available in this home-manager version
    # Rules are managed manually via ~/.claude/rules/ directory

    # Settings that go into ~/.claude/settings.json
    settings = {
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
    };
  };

  #############################################################################
  # MCP Server Configuration Template + Rules
  # Uses lib.mapAttrs' to generate home.file entries from rulesConfig
  #############################################################################

  home.file = {
    # MCP template with @PLACEHOLDER@ values - secrets substituted at activation
    ".claude/mcp-servers.json.template".text = mcpConfigTemplate;

    # Statusline script - executable bash script for custom status display
    ".claude/statusline-command.sh" = {
      source = "${scriptsDir}/statusline.sh";
      executable = true;
    };

    # tmux MCP server - terminal automation for Claude Code
    ".config/tmux-mcp/server.py" = {
      source = "${scriptsDir}/tmux-mcp-server.py";
      executable = true;
    };

    # Skills - teach Claude Code how to use MCP tools
    ".claude/skills/automating-tmux-windows/SKILL.md".source =
      "${skillsDir}/automating-tmux-windows.md";
    ".claude/skills/pal-multi-model/SKILL.md".source = "${skillsDir}/pal-multi-model.md";

    # AI CLI skills via tmux - run Claude/Codex in separate instances
    ".claude/skills/claude-cli/SKILL.md".source = "${skillsDir}/claude-cli.md";
    ".claude/skills/codex-cli/SKILL.md".source = "${skillsDir}/codex-cli.md";
  }
  // lib.mapAttrs' (name: content: {
    # Rules - Manual file creation (until home-manager rules option is available)
    name = ".claude/rules/${name}";
    value = {
      text = content;
    };
  }) rulesConfig;

  #############################################################################
  # Secret Substitution and MCP Config Activation
  #############################################################################

  home.activation.claudeCodeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.home.homeDirectory}/.claude/secrets

    # Remove existing mcp-servers.json if it exists (may be a symlink or locked file)
    run rm -f ${config.home.homeDirectory}/.claude/mcp-servers.json

    # Copy MCP template to working file
    run cp ${config.home.homeDirectory}/.claude/mcp-servers.json.template \
           ${config.home.homeDirectory}/.claude/mcp-servers.json

    # Substitute each @PLACEHOLDER@ with its decrypted secret value
    ${lib.concatMapStrings (
      ph:
      let
        secretPath = secretSubstitutions.${ph};
      in
      ''
        if [ -f "${secretPath}" ]; then
          run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" \
              ${config.home.homeDirectory}/.claude/mcp-servers.json
        fi
      ''
    ) (lib.attrNames secretSubstitutions)}

    # Merge MCP servers into ~/.claude.json using jq
    # This preserves existing user settings while updating mcpServers
    if [ -f "${config.home.homeDirectory}/.claude.json" ]; then
      run ${lib.getExe pkgs.jq} -s '.[0] * .[1]' \
          ${config.home.homeDirectory}/.claude.json \
          ${config.home.homeDirectory}/.claude/mcp-servers.json \
          > ${config.home.homeDirectory}/.claude.json.tmp
      run mv ${config.home.homeDirectory}/.claude.json.tmp \
             ${config.home.homeDirectory}/.claude.json
    else
      run cp ${config.home.homeDirectory}/.claude/mcp-servers.json \
             ${config.home.homeDirectory}/.claude.json
    fi
  '';
}
