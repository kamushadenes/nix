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
  packages,
  claudebox,
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

  # Read agent files from the agents directory (including subdirectories)
  agentEntries = builtins.readDir agentsDir;
  # Top-level .md files
  agentFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) agentEntries;
  # Subdirectories (like _templates, _references)
  agentSubdirs = lib.filterAttrs (name: type: type == "directory") agentEntries;
  # Recursively collect files from subdirectories
  agentSubdirFiles = lib.foldl' (
    acc: subdir:
    let
      subdirPath = "${agentsDir}/${subdir}";
      subdirEntries = builtins.readDir subdirPath;
      mdFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) subdirEntries;
    in
    acc
    // lib.mapAttrs' (name: _: {
      name = "${subdir}/${name}";
      value = "${subdirPath}/${name}";
    }) mdFiles
  ) { } (builtins.attrNames agentSubdirs);
  # Combined: top-level files + subdirectory files
  allAgentFiles =
    (lib.mapAttrs' (name: _: {
      name = name;
      value = "${agentsDir}/${name}";
    }) agentFiles)
    // agentSubdirFiles;

  # Read command files from the commands directory
  commandEntries = builtins.readDir commandsDir;
  commandFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) commandEntries;
  commandsConfig = lib.mapAttrs' (name: _: {
    # Remove .md extension for command name
    name = lib.removeSuffix ".md" name;
    value = builtins.readFile "${commandsDir}/${name}";
  }) commandFiles;

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
    packages.ccusage # Claude Code usage analysis (avoids CPU-intensive npx calls)
    claudebox # Sandboxed Claude Code execution
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
    # Darwin uses homebrew, Linux uses pkgs-unstable
    package = if pkgs.stdenv.isDarwin then null else pkgs-unstable.claude-code;

    # Note: mcpServers are NOT set here because home-manager doesn't support
    # secret substitution. They're managed separately below via ~/.claude.json

    # Global CLAUDE.md content - applies to all projects
    memory.text = builtins.readFile "${memoryDir}/global.md";

    # Custom slash commands - auto-discovered from commandsDir
    commands = commandsConfig;

    # Note: rules option is not available in this home-manager version
    # Rules are managed manually via ~/.claude/rules/ directory

    # Settings that go into ~/.claude/settings.json
    settings = {
      # Global permissions - auto-approved tools (imported from claude-code-permissions.nix)
      permissions = permissions;

      # Always enable extended thinking for better reasoning
      enableExtendedThinking = true;

      # Agent Teams - native multi-instance coordination
      env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      teammateMode = "auto"; # split panes in tmux, in-process otherwise

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
          # Block destructive git/filesystem commands and enforce worktree workflow
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PreToolUse/git-safety-guard.py";
              }
              {
                type = "command";
                command = "~/.claude/hooks/PreToolUse/suggest-modern-tools.py";
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
          # Web-only: Install devbox and initialize direnv when devbox.json exists
          {
            matcher = "startup";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/SessionStart/devbox-setup.sh";
              }
            ];
          }
        ];

        # Run when Claude stops working
        # Note: ralph-loop hook is provided by ralph-loop@claude-plugins-official plugin
        Stop = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/Stop/debug-env.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/Stop/post-lint.sh";
              }
              {
                type = "command";
                command = "~/.claude/hooks/Stop/session-cleanup.sh";
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

        # Run after tool failures
        PostToolUseFailure = [
          # Suggest nix-shell for missing commands
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/PostToolUseFailure/suggest-nix-shell.sh";
              }
            ];
          }
        ];

        # Run when a teammate finishes and goes idle
        TeammateIdle = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/TeammateIdle/quality-gate.sh";
              }
            ];
          }
        ];

        # Run when a task is being marked complete
        TaskCompleted = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "~/.claude/hooks/TaskCompleted/verify-completion.sh";
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
        "worktrunk@worktrunk" = true;
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
    ".claude/hooks/Stop/debug-env.sh" = {
      source = "${scriptsDir}/hooks/Stop/debug-env.sh";
      executable = true;
    };
    ".claude/hooks/Stop/session-cleanup.sh" = {
      source = "${scriptsDir}/hooks/Stop/session-cleanup.sh";
      executable = true;
    };
    # Note: ralph-loop.sh is provided by ralph-loop@claude-plugins-official plugin

    # SessionStart hooks
    ".claude/hooks/SessionStart/devbox-setup.sh" = {
      source = "${scriptsDir}/hooks/SessionStart/devbox-setup.sh";
      executable = true;
    };

    # PreToolUse hooks (additional)
    ".claude/hooks/PreToolUse/suggest-modern-tools.py" = {
      source = "${scriptsDir}/hooks/PreToolUse/suggest-modern-tools.py";
      executable = true;
    };

    # PostToolUse hooks (additional)
    # Suggest nix-shell for command not found (PostToolUseFailure)
    ".claude/hooks/PostToolUseFailure/suggest-nix-shell.sh" = {
      source = "${scriptsDir}/hooks/PostToolUseFailure/suggest-nix-shell.sh";
      executable = true;
    };

    # TeammateIdle hooks
    ".claude/hooks/TeammateIdle/quality-gate.sh" = {
      source = "${scriptsDir}/hooks/TeammateIdle/quality-gate.sh";
      executable = true;
    };

    # TaskCompleted hooks
    ".claude/hooks/TaskCompleted/verify-completion.sh" = {
      source = "${scriptsDir}/hooks/TaskCompleted/verify-completion.sh";
      executable = true;
    };

    # Markdownlint configuration
    ".claude/config/markdownlint.jsonc".source = "${resourcesDir}/config/markdownlint.jsonc";

    # Note: Orchestrator MCP server, CLI, and skills are now in orchestrator.nix
    # Note: Agents are auto-discovered below via lib.mapAttrs'
  }
  // lib.mapAttrs' (name: content: {
    # Rules - Manual file creation (until home-manager rules option is available)
    name = ".claude/rules/${name}";
    value = {
      text = content;
    };
  }) rulesConfig
  // lib.mapAttrs' (name: sourcePath: {
    # Agents - Auto-discovered from agentsDir (including _templates and _references)
    name = ".claude/agents/${name}";
    value = {
      source = sourcePath;
    };
  }) allAgentFiles
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
