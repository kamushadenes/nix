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
  # Import shared MCP server configuration
  mcpServers = import ./mcp-servers.nix { inherit config lib; };

  # Resource directories
  resourcesDir = ./resources/claude-code;
  scriptsDir = "${resourcesDir}/scripts";
  rulesDir = "${resourcesDir}/rules";
  memoryDir = "${resourcesDir}/memory";
  commandsDir = "${resourcesDir}/commands";
  agentsDir = "${resourcesDir}/agents";

  # Read rule files from the rules directory
  ruleFiles = builtins.attrNames (builtins.readDir rulesDir);
  rulesConfig = lib.listToAttrs (
    map (name: {
      name = name;
      value = builtins.readFile "${rulesDir}/${name}";
    }) ruleFiles
  );

  # MCP servers to include for Claude Code
  enabledServers = [
    "deepwiki"
    "github"
    "Ref"
    "orchestrator"
    "pal"
    "clickup"
  ];

  # Transform to Claude Code format
  mcpServersConfig = mcpServers.toClaudeCode enabledServers;

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.claude/secrets";
  secretSubstitutions = mcpServers.mkSecretSubstitutions secretsDir;

  # Template file for MCP servers (with placeholders) and additional settings
  mcpConfigTemplate = builtins.toJSON {
    mcpServers = mcpServersConfig;
    claudeInChromeDefaultEnabled = true;
    hasCompletedClaudeInChromeOnboarding = true;
  };
in
{
  #############################################################################
  # Hook Dependencies
  #############################################################################

  home.packages = with pkgs; [
    nodePackages.prettier # Markdown/TypeScript formatting
    ruff # Python formatting
    github-mcp-server # GitHub MCP server binary
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = mcpServers.mkAgenixSecrets {
    prefix = "claude";
    secretsDir = secretsDir;
    inherit private;
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
      test-altinity-cloud = builtins.readFile "${private}/home/common/ai/resources/claude/commands/test-altinity-cloud.md";
      code-review = builtins.readFile "${commandsDir}/code-review.md";
      commit = builtins.readFile "${commandsDir}/commit.md";
      commit-push-pr = builtins.readFile "${commandsDir}/commit-push-pr.md";
      architecture-review = builtins.readFile "${commandsDir}/architecture-review.md";
      dependency-audit = builtins.readFile "${commandsDir}/dependency-audit.md";
    };

    # Note: rules option is not available in this home-manager version
    # Rules are managed manually via ~/.claude/rules/ directory

    # Settings that go into ~/.claude/settings.json
    settings = {
      # Global permissions - auto-approved tools
      permissions = {
        # Deny reading TDD guard internal files to prevent circumvention
        deny = [
          "Read(.claude/tdd-guard/**)"
        ];
        allow = [
          # Basic commands
          "Bash(curl:*)"
          "Bash(tree:*)"
          "Bash(cat:*)"
          "Bash(wc:*)"
          "Bash(grep:*)"
          "Bash(ls:*)"
          "Bash(stat:*)"
          "Bash(rg:*)"
          "Bash(fd:*)"
          "Bash(mkdir:*)"
          "Search"

          # Nix commands
          "Bash(nix flake check:*)"
          "Bash(nix flake show:*)"
          "Bash(nix flake metadata:*)"
          "Bash(nix eval:*)"
          "Bash(nix-instantiate:*)"
          "Bash(nix path-info:*)"
          "Bash(nix fmt:*)"
          "Bash(nix search:*)"
          "Bash(nixfmt:*)"
          "Bash(rebuild:*)"
          "Bash(nh darwin switch:*)"

          # Go commands
          "Bash(go mod:*)"
          "Bash(go list:*)"
          "Bash(go test:*)"
          "Bash(go build:*)"
          "Bash(go run:*)"

          # Git commands
          "Bash(git ls-files:*)"
          "Bash(git ls-tree:*)"
          "Bash(git submodule status:*)"
          "Bash(git add:*)"
          "Bash(git commit:*)"
          "Bash(git describe:*)"
          "Bash(git tag:*)"
          "Bash(git log:*)"
          "Bash(git push:*)"
          "Bash(git fetch:*)"
          "Bash(git pull:*)"
          "Bash(git clone:*)"
          "Bash(gh pr:*)"
          "Bash(gh run:*)"
          "Bash(gh release:*)"

          # Terraform
          "Bash(terraform plan:*)"
          "Bash(terraform show:*)"
          "Bash(terragrunt plan:*)"
          "Bash(terragrunt show:*)"

          # Tmux commands
          "Bash(tmux list-commands:*)"
          "Bash(tmux list-panes:*)"
          "Bash(tmux list-sessions:*)"
          "Bash(tmux display-message:*)"
          "Bash(tmux capture-pane:*)"
          "Bash(tmux show-options:*)"

          # Web access
          "WebSearch"
          "WebFetch"

          # MCP: DeepWiki
          "mcp__deepwiki__ask_question"
          "mcp__deepwiki__read_wiki_contents"

          # Ref
          "mcp__ref__ref_search_documentation"

          # MCP: Orchestrator - tmux
          "mcp__orchestrator__tmux_new_window"
          "mcp__orchestrator__tmux_send"
          "mcp__orchestrator__tmux_wait_idle"
          "mcp__orchestrator__tmux_capture"
          "mcp__orchestrator__tmux_list"
          "mcp__orchestrator__tmux_select"
          "mcp__orchestrator__tmux_kill"
          "mcp__orchestrator__tmux_interrupt"
          "mcp__orchestrator__notify"

          # MCP: PAL - CLI-to-CLI bridge (version/listmodels auto-allowed)
          "mcp__pal__clink"
          "mcp__pal__listmodels"
          "mcp__pal__version"

          # MCP: ClickUp - Restricted to Iniciador projects via PreToolUse hook
          # Note: Tools are approved on first use. Add specific permissions here after
          # running /mcp to authenticate and discover available tools.

          # Skills
          "Skill(codex-cli)"
        ];
      };

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
          # Block destructive git/filesystem commands
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/git-safety-guard.py";
              }
            ];
          }
          # Restrict ClickUp MCP to Iniciador project directories
          {
            matcher = "mcp__clickup__.*";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/restrict-clickup.sh";
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

        # Run after file modifications - security scanning and auto-formatting
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
          # Auto-format Python files
          {
            matcher = "Edit(*.py)|Write(*.py)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/format-python.sh";
              }
            ];
          }
          # Auto-format TypeScript files
          {
            matcher = "Edit(*.ts)|Write(*.ts)|Edit(*.tsx)|Write(*.tsx)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/format-typescript.sh";
              }
            ];
          }
          # Auto-format Nix files
          {
            matcher = "Edit(*.nix)|Write(*.nix)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/format-nix.sh";
              }
            ];
          }
          # Auto-format Markdown files
          {
            matcher = "Edit(*.md)|Write(*.md)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/format-markdown.sh";
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
        #"playwright@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = true;
        "pyright-lsp@claude-plugins-official" = true;
        "ralph-wiggum@claude-plugins-official" = true;
        "hookify@claude-plugins-official" = true;
        #"commit-commands@claude-plugins-official" = true;
        #"security-guidance@claude-plugins-official" = true;
        #"pr-review-toolkit@claude-plugins-official" = true;

        # Claude Code Workflows
        #"backend-api-security@claude-code-workflows" = true;
        #"backend-development@claude-code-workflows" = true;
        #"dependency-management@claude-code-workflows" = true;
        #"full-stack-orchestration@claude-code-workflows" = true;
        #"python-development@claude-code-workflows" = true;
        #"security-scanning@claude-code-workflows" = true;
        #"cloud-infrastructure@claude-code-workflows" = true;
        #"cicd-automation@claude-code-workflows" = true;

        # Third-party
        #"fullstack-dev-skills@fullstack-dev-skills" = true;
        #"superpowers@superpowers-marketplace" = true;
        "secrets-scanner@agent-security" = true;
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

    # Auto-format hooks
    ".claude/hooks/format-python.sh" = {
      source = "${scriptsDir}/hooks/format-python.sh";
      executable = true;
    };
    ".claude/hooks/format-typescript.sh" = {
      source = "${scriptsDir}/hooks/format-typescript.sh";
      executable = true;
    };
    ".claude/hooks/format-nix.sh" = {
      source = "${scriptsDir}/hooks/format-nix.sh";
      executable = true;
    };
    ".claude/hooks/format-markdown.sh" = {
      source = "${scriptsDir}/hooks/format-markdown.sh";
      executable = true;
    };
    ".claude/hooks/post-lint.sh" = {
      source = "${scriptsDir}/hooks/post-lint.sh";
      executable = true;
    };
    ".claude/hooks/restrict-clickup.sh" = {
      source = "${scriptsDir}/hooks/restrict-clickup.sh";
      executable = true;
    };
    ".claude/hooks/git-safety-guard.py" = {
      source = "${scriptsDir}/hooks/git-safety-guard.py";
      executable = true;
    };

    # Note: Orchestrator MCP server, CLI, and skills are now in orchestrator.nix

    # Sub-agents for specialized workflows
    ".claude/agents/code-reviewer.md".source = "${agentsDir}/code-reviewer.md";
    ".claude/agents/security-auditor.md".source = "${agentsDir}/security-auditor.md";
    ".claude/agents/test-analyzer.md".source = "${agentsDir}/test-analyzer.md";
    ".claude/agents/documentation-writer.md".source = "${agentsDir}/documentation-writer.md";
    ".claude/agents/silent-failure-hunter.md".source = "${agentsDir}/silent-failure-hunter.md";
    ".claude/agents/performance-analyzer.md".source = "${agentsDir}/performance-analyzer.md";
    ".claude/agents/type-checker.md".source = "${agentsDir}/type-checker.md";
    ".claude/agents/refactoring-advisor.md".source = "${agentsDir}/refactoring-advisor.md";
    ".claude/agents/code-simplifier.md".source = "${agentsDir}/code-simplifier.md";
    ".claude/agents/comment-analyzer.md".source = "${agentsDir}/comment-analyzer.md";
    ".claude/agents/dependency-checker.md".source = "${agentsDir}/dependency-checker.md";
    # Sub-agents for multi-model workflows
    ".claude/agents/consensus.md".source = "${agentsDir}/consensus.md";
    ".claude/agents/debugger.md".source = "${agentsDir}/debugger.md";
    ".claude/agents/planner.md".source = "${agentsDir}/planner.md";
    ".claude/agents/precommit.md".source = "${agentsDir}/precommit.md";
    ".claude/agents/thinkdeep.md".source = "${agentsDir}/thinkdeep.md";
    ".claude/agents/tracer.md".source = "${agentsDir}/tracer.md";
    # Query and architecture agents
    ".claude/agents/query-clarifier.md".source = "${agentsDir}/query-clarifier.md";
    ".claude/agents/architecture-reviewer.md".source = "${agentsDir}/architecture-reviewer.md";
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
    run mkdir -p ${secretsDir}

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
