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
  # Import shared MCP server configuration (with private merge support)
  mcpServers = import ./mcp-servers.nix { inherit config lib private; };

  # Import account configuration for multi-account support
  accountsConfig = import ./claude-accounts.nix { inherit config lib; };

  # Import permissions configuration (extracted for maintainability)
  permissions = import ./claude-code-permissions.nix;

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

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.claude/secrets";
  secretSubstitutions = mcpServers.mkSecretSubstitutions secretsDir;

  # Default MCP config (common servers only, for non-account directories)
  # Account-specific directories get their own configs with additional servers
  defaultMcpConfigTemplate = mcpServers.mkMcpConfig accountsConfig.commonMcpServers;

  # Generate account directory entries for home.file
  # Each account gets:
  # - mcp-servers.json.template (with account-specific servers)
  # - Symlinks to shared resources (settings.json, rules/, hooks/, etc.)
  accountFileEntries = lib.foldl' (
    acc: name:
    let
      accountMcps = accountsConfig.getAccountMcps name;
      accountDir = ".claude/accounts/${name}";
      homeDir = config.home.homeDirectory;
    in
    acc
    // {
      # Account-specific MCP servers template
      "${accountDir}/mcp-servers.json.template".text = mcpServers.mkMcpConfig accountMcps;

      # Symlinks to shared resources
      "${accountDir}/settings.json".source =
        config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/settings.json";
      "${accountDir}/rules".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/rules";
      "${accountDir}/hooks".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/hooks";
      "${accountDir}/agents".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/agents";
      "${accountDir}/commands".source =
        config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/commands";
      "${accountDir}/secrets".source =
        config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/secrets";
      "${accountDir}/config".source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/config";
      "${accountDir}/statusline-command.sh".source =
        config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/statusline-command.sh";
    }
  ) { } accountsConfig.accountNames;
in
{
  #############################################################################
  # Hook Dependencies
  #############################################################################

  home.packages = with pkgs; [
    nodePackages.prettier # Markdown/TypeScript formatting
    # markdownlint-cli is installed in emacs.nix
    ruff # Python formatting
    github-mcp-server # GitHub MCP server binary
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets =
    mcpServers.mkAgenixSecrets {
      prefix = "claude";
      secretsDir = secretsDir;
      inherit private;
    }
    // {
      # Iniciador Vanta credentials - needs file path, not substituted content
      # Referenced directly in iniciador-vanta server config
      "claude-iniciador-vanta-credentials" = {
        file = "${private}/home/common/ai/resources/claude/vanta-credentials.age";
        path = "${secretsDir}/iniciador-vanta-credentials";
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
      test-altinity-cloud = builtins.readFile "${private}/home/common/ai/resources/claude/commands/test-altinity-cloud.md";
      code-review = builtins.readFile "${commandsDir}/code-review.md";
      commit = builtins.readFile "${commandsDir}/commit.md";
      commit-push-pr = builtins.readFile "${commandsDir}/commit-push-pr.md";
      architecture-review = builtins.readFile "${commandsDir}/architecture-review.md";
      dependency-audit = builtins.readFile "${commandsDir}/dependency-audit.md";
      deep-review = builtins.readFile "${commandsDir}/deep-review.md";
      beads-init = builtins.readFile "${commandsDir}/beads-init.md";
      beads-merge = builtins.readFile "${commandsDir}/beads-merge.md";
      sync-ai-dev = builtins.readFile "${commandsDir}/sync-ai-dev.md";
      clickup-sync = builtins.readFile "${commandsDir}/clickup-sync.md";
      vanta-sync = builtins.readFile "${commandsDir}/vanta-sync.md";
      plan-to-beads = builtins.readFile "${commandsDir}/plan-to-beads.md";
    };

    # Note: rules option is not available in this home-manager version
    # Rules are managed manually via ~/.claude/rules/ directory

    # Settings that go into ~/.claude/settings.json
    settings = {
      # Global permissions - auto-approved tools (imported from claude-code-permissions.nix)
      permissions = permissions;

      # Hooks - commands that run at various points in Claude Code's lifecycle
      hooks = {
        # Run before file modifications - TDD guard ensures tests exist
        PreToolUse = [
          {
            matcher = "Write|Edit|MultiEdit|TodoWrite|Update";
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
                command = "~/.claude/hooks/PreToolUse/git-safety-guard.py";
              }
            ];
          }
          # Workspace-scoped ClickUp restrictions
          # Each workspace MCP is restricted to its project directories
          {
            matcher = "mcp__iniciador-clickup__.*";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PreToolUse/restrict-clickup.sh iniciador";
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
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "bd prime";
              }
            ];
          }
        ];

        # Run before context compaction
        PreCompact = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "bd prime";
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
                command = "~/.claude/hooks/Stop/post-lint.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/Stop/clickup-sync.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/Stop/vanta-sync.sh";
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
            matcher = "Edit(*.tf)|Write(*.tf)|Update(*.tf)";
            hooks = [
              {
                type = "command";
                command = ".claude/hooks/trivy-tf.sh";
              }
            ];
          }
          {
            matcher = "Edit(*.hcl)|Write(*.hcl)|Update(*.hcl)";
            hooks = [
              {
                type = "command";
                command = ".claude/hooks/trivy-tf.sh";
              }
            ];
          }
          # Auto-format Python files
          {
            matcher = "Edit(*.py)|Write(*.py)|Update(*.py)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PostToolUse/format-python.sh";
              }
            ];
          }
          # Auto-format TypeScript files
          {
            matcher = "Edit(*.ts)|Write(*.ts)|Update(*.ts)|Edit(*.tsx)|Write(*.tsx)|Update(*.tsx)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PostToolUse/format-typescript.sh";
              }
            ];
          }
          # Auto-format Nix files
          {
            matcher = "Edit(*.nix)|Write(*.nix)|Update(*.nix)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PostToolUse/format-nix.sh";
              }
            ];
          }
          # Auto-format Markdown files
          {
            matcher = "Edit(*.md)|Write(*.md)|Update(*.md)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PostToolUse/format-markdown.sh";
              }
            ];
          }
          # Auto-format Go files
          {
            matcher = "Edit(*.go)|Write(*.go)|Update(*.go)";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PostToolUse/format-go.sh";
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
      #
      # Marketplace sources (added via /plugin marketplace add <repo>):
      #   claude-plugins-official  -> anthropics/claude-code-plugins (built-in)
      #   claude-code-workflows    -> modelcontextprotocol/workflows
      #   agent-security           -> (third-party security plugins)
      #
      # Plugin format: "plugin-name@marketplace-name" = true|false
      enabledPlugins = {
        # Official plugins (anthropics/claude-code-plugins)
        "gopls-lsp@claude-plugins-official" = true;
        #"playwright@claude-plugins-official" = true;
        "typescript-lsp@claude-plugins-official" = true;
        "pyright-lsp@claude-plugins-official" = true;
        "ralph-loop@claude-plugins-official" = true;
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
    # Default config only includes common MCP servers (account-specific dirs add their own)
    ".claude/mcp-servers.json.template".text = defaultMcpConfigTemplate;

    # Statusline script - executable bash script for custom status display
    ".claude/statusline-command.sh" = {
      source = "${scriptsDir}/statusline.sh";
      executable = true;
    };

    # PreToolUse hooks
    ".claude/hooks/PreToolUse/git-safety-guard.py" = {
      source = "${scriptsDir}/hooks/PreToolUse/git-safety-guard.py";
      executable = true;
    };
    ".claude/hooks/PreToolUse/restrict-clickup.sh" = {
      source = "${scriptsDir}/hooks/PreToolUse/restrict-clickup.sh";
      executable = true;
    };

    # PostToolUse hooks
    ".claude/hooks/PostToolUse/format-python.sh" = {
      source = "${scriptsDir}/hooks/PostToolUse/format-python.sh";
      executable = true;
    };
    ".claude/hooks/PostToolUse/format-typescript.sh" = {
      source = "${scriptsDir}/hooks/PostToolUse/format-typescript.sh";
      executable = true;
    };
    ".claude/hooks/PostToolUse/format-nix.sh" = {
      source = "${scriptsDir}/hooks/PostToolUse/format-nix.sh";
      executable = true;
    };
    ".claude/hooks/PostToolUse/format-markdown.sh" = {
      source = "${scriptsDir}/hooks/PostToolUse/format-markdown.sh";
      executable = true;
    };
    ".claude/hooks/PostToolUse/format-go.sh" = {
      source = "${scriptsDir}/hooks/PostToolUse/format-go.sh";
      executable = true;
    };

    # Stop hooks
    ".claude/hooks/Stop/post-lint.sh" = {
      source = "${scriptsDir}/hooks/Stop/post-lint.sh";
      executable = true;
    };
    ".claude/hooks/Stop/clickup-sync.sh" = {
      source = "${scriptsDir}/hooks/Stop/clickup-sync.sh";
      executable = true;
    };
    ".claude/hooks/Stop/vanta-sync.sh" = {
      source = "${scriptsDir}/hooks/Stop/vanta-sync.sh";
      executable = true;
    };

    # Markdownlint configuration
    ".claude/config/markdownlint.jsonc".source = "${resourcesDir}/config/markdownlint.jsonc";

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
    # Compliance and certification agents
    ".claude/agents/compliance-specialist.md".source = "${agentsDir}/compliance-specialist.md";
    # Task automation agent (beads workflow)
    ".claude/agents/task-agent.md".source = "${agentsDir}/task-agent.md";
  }
  // lib.mapAttrs' (name: content: {
    # Rules - Manual file creation (until home-manager rules option is available)
    name = ".claude/rules/${name}";
    value = {
      text = content;
    };
  }) rulesConfig
  // accountFileEntries;

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
    # IMPORTANT: Replace mcpServers entirely (removes stale entries)
    # but preserve all other user settings including OAuth state
    if [ -f "${config.home.homeDirectory}/.claude.json" ]; then
      run ${lib.getExe pkgs.jq} -s '
        # Start with existing config, delete old mcpServers
        (.[0] | del(.mcpServers))
        # Merge with new config (which has fresh mcpServers)
        * .[1]
      ' ${config.home.homeDirectory}/.claude.json \
        ${config.home.homeDirectory}/.claude/mcp-servers.json \
        > ${config.home.homeDirectory}/.claude.json.tmp
      # Remove target first (may be read-only), then move
      run rm -f ${config.home.homeDirectory}/.claude.json
      run mv ${config.home.homeDirectory}/.claude.json.tmp \
             ${config.home.homeDirectory}/.claude.json
    else
      run cp ${config.home.homeDirectory}/.claude/mcp-servers.json \
             ${config.home.homeDirectory}/.claude.json
    fi

    #############################################################################
    # Process Account-Specific MCP Configurations
    #############################################################################

    ${lib.concatMapStrings (name: ''
      # Process ${name} account MCP config
      run mkdir -p ${config.home.homeDirectory}/.claude/accounts/${name}
      run rm -f ${config.home.homeDirectory}/.claude/accounts/${name}/mcp-servers.json

      # Copy account template to working file
      run cp ${config.home.homeDirectory}/.claude/accounts/${name}/mcp-servers.json.template \
             ${config.home.homeDirectory}/.claude/accounts/${name}/mcp-servers.json

      # Substitute @PLACEHOLDER@ values in account config
      ${lib.concatMapStrings (
        ph:
        let
          secretPath = secretSubstitutions.${ph};
        in
        ''
          if [ -f "${secretPath}" ]; then
            run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" \
                ${config.home.homeDirectory}/.claude/accounts/${name}/mcp-servers.json
          fi
        ''
      ) (lib.attrNames secretSubstitutions)}

      # Merge into account-specific .claude.json
      # Replace mcpServers entirely but preserve other settings (OAuth, etc.)
      if [ -f "${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json" ]; then
        run ${lib.getExe pkgs.jq} -s '
          (.[0] | del(.mcpServers)) * .[1]
        ' ${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json \
          ${config.home.homeDirectory}/.claude/accounts/${name}/mcp-servers.json \
          > ${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json.tmp
        # Remove target first (may be read-only), then move
        run rm -f ${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json
        run mv ${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json.tmp \
               ${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json
      else
        run cp ${config.home.homeDirectory}/.claude/accounts/${name}/mcp-servers.json \
               ${config.home.homeDirectory}/.claude/accounts/${name}/.claude.json
      fi
    '') accountsConfig.accountNames}
  '';
}
