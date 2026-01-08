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

  # Use merged enabled servers from mcp-servers.nix (public + private)
  enabledServers = mcpServers.enabledServers;

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

          # Text processing
          "Bash(sort:*)"
          "Bash(head:*)"
          "Bash(tail:*)"
          "Bash(cut:*)"
          "Bash(paste:*)"
          "Bash(xxd:*)"
          "Bash(readlink:*)"
          "Bash(jq:*)"
          "Bash(yq:*)"

          # Modern Unix tools (rust/go replacements)
          "Bash(bat:*)"
          "Bash(eza:*)"
          "Bash(exa:*)"
          "Bash(dust:*)"
          "Bash(duf:*)"
          "Bash(procs:*)"
          "Bash(hyperfine:*)"
          "Bash(tokei:*)"
          "Bash(delta:*)"
          "Bash(difft:*)"
          "Bash(doggo:*)"
          "Bash(xh:*)"
          "Bash(httpie:*)"
          "Bash(http:*)"
          "Bash(curlie:*)"
          "Bash(glow:*)"
          "Bash(fzf:*)"
          "Bash(zoxide:*)"

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
          "Bash(alejandra:*)"
          "Bash(nix-prefetch-github:*)"
          "Bash(rebuild:*)"
          "Bash(nh darwin switch:*)"

          # Go commands
          "Bash(go mod:*)"
          "Bash(go list:*)"
          "Bash(go test:*)"
          "Bash(go build:*)"
          "Bash(go run:*)"
          "Bash(go doc:*)"
          "Bash(go get:*)"
          "Bash(go version:*)"
          "Bash(go tool cover:*)"
          "Bash(go generate:*)"
          "Bash(golangci-lint run:*)"
          "Bash(gofmt:*)"
          "Bash(goimports:*)"

          # Just task runner
          "Bash(just lint:*)"
          "Bash(just test:*)"
          "Bash(just build:*)"
          "Bash(just gen:*)"
          "Bash(just static:*)"
          "Bash(just md-fmt:*)"
          "Bash(just md-lint:*)"
          "Bash(just md-lint-fix:*)"
          "Bash(just go-lint:*)"
          "Bash(just test-all:*)"
          "Bash(just test-single:*)"
          "Bash(just test-integration-short:*)"

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

          # Beads issue tracking
          "Bash(bd:*)"

          # Terraform / Terragrunt
          "Bash(terraform plan:*)"
          "Bash(terraform show:*)"
          "Bash(terraform fmt:*)"
          "Bash(terraform validate:*)"
          "Bash(terragrunt plan:*)"
          "Bash(terragrunt show:*)"
          "Bash(terragrunt validate:*)"
          "Bash(terragrunt init:*)"
          "Bash(terragrunt state list:*)"
          "Bash(terragrunt state show:*)"

          # GCloud - read-only operations
          "Bash(gcloud config:*)"
          "Bash(gcloud auth list:*)"
          "Bash(gcloud projects list:*)"
          "Bash(gcloud projects describe:*)"
          "Bash(gcloud services list:*)"
          "Bash(gcloud compute instances list:*)"
          "Bash(gcloud compute instances describe:*)"
          "Bash(gcloud compute disks list:*)"
          "Bash(gcloud compute networks list:*)"
          "Bash(gcloud compute zones list:*)"
          "Bash(gcloud compute regions list:*)"
          "Bash(gcloud container clusters list:*)"
          "Bash(gcloud container clusters describe:*)"
          "Bash(gcloud run services list:*)"
          "Bash(gcloud run services describe:*)"
          "Bash(gcloud run services logs read:*)"
          "Bash(gcloud run jobs list:*)"
          "Bash(gcloud run revisions list:*)"
          "Bash(gcloud functions list:*)"
          "Bash(gcloud functions describe:*)"
          "Bash(gcloud storage buckets list:*)"
          "Bash(gcloud storage buckets describe:*)"
          "Bash(gcloud storage ls:*)"
          "Bash(gcloud iam service-accounts list:*)"
          "Bash(gcloud logging read:*)"
          "Bash(gcloud logging logs list:*)"
          "Bash(gcloud secrets list:*)"
          "Bash(gcloud secrets versions list:*)"
          "Bash(gcloud secrets versions access:*)"
          "Bash(gcloud sql instances list:*)"
          "Bash(gcloud sql instances describe:*)"
          "Bash(gcloud pubsub topics list:*)"
          "Bash(gcloud pubsub subscriptions list:*)"
          "Bash(gsutil ls:*)"
          "Bash(gsutil cat:*)"
          "Bash(gsutil stat:*)"

          # Tmux commands
          "Bash(tmux list-commands:*)"
          "Bash(tmux list-panes:*)"
          "Bash(tmux list-sessions:*)"
          "Bash(tmux display-message:*)"
          "Bash(tmux capture-pane:*)"
          "Bash(tmux show-options:*)"
          "Bash(tmux -V:*)"
          "Bash(tmux source-file:*)"

          # Node/NPM - read-only
          "Bash(npm view:*)"
          "Bash(npm ls:*)"

          # Protobuf/Build tools
          "Bash(buf generate:*)"
          "Bash(buf dep update:*)"
          "Bash(buf lint:*)"
          "Bash(goreleaser check:*)"
          "Bash(templ fmt:*)"

          # DevBox
          "Bash(devbox search:*)"
          "Bash(devbox add:*)"

          # Network tools
          "Bash(nslookup:*)"
          "Bash(dig:*)"

          # Misc read-only tools
          "Bash(hcloud server-type:*)"
          "Bash(tdd-guard-go:*)"
          "Bash(launchctl list:*)"
          "Bash(sqlite3:*)"
          "Bash(openssl x509:*)"

          # Web access
          "WebSearch"
          "WebFetch"

          # MCP: DeepWiki
          "mcp__deepwiki__ask_question"
          "mcp__deepwiki__read_wiki_contents"

          # MCP: Ref
          "mcp__ref__ref_search_documentation"
          "mcp__Ref__ref_read_url"

          # MCP: Terraform
          "mcp__terraform__search_providers"
          "mcp__terraform__get_provider_details"
          "mcp__terraform__get_provider_capabilities"

          # MCP: GitHub
          "mcp__github__list_issues"

          # MCP: IDE
          "mcp__ide__getDiagnostics"

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

          # MCP: Orchestrator - AI (parallel AI CLI orchestration)
          "mcp__orchestrator__ai_call"
          "mcp__orchestrator__ai_spawn"
          "mcp__orchestrator__ai_fetch"
          "mcp__orchestrator__ai_list"
          "mcp__orchestrator__ai_review"

          # MCP: Claude-in-Chrome browser automation
          "mcp__claude-in-chrome__javascript_tool"
          "mcp__claude-in-chrome__read_page"
          "mcp__claude-in-chrome__find"
          "mcp__claude-in-chrome__form_input"
          "mcp__claude-in-chrome__computer"
          "mcp__claude-in-chrome__navigate"
          "mcp__claude-in-chrome__resize_window"
          "mcp__claude-in-chrome__gif_creator"
          "mcp__claude-in-chrome__upload_image"
          "mcp__claude-in-chrome__get_page_text"
          "mcp__claude-in-chrome__tabs_context_mcp"
          "mcp__claude-in-chrome__tabs_create_mcp"
          "mcp__claude-in-chrome__update_plan"
          "mcp__claude-in-chrome__read_console_messages"
          "mcp__claude-in-chrome__read_network_requests"
          "mcp__claude-in-chrome__shortcuts_list"
          "mcp__claude-in-chrome__shortcuts_execute"

          # MCP: ClickUp - Restricted to Iniciador projects via PreToolUse hook
          # Note: Tools are approved on first use. Add specific permissions here after
          # running /mcp to authenticate and discover available tools.

          # Skills
          "Skill(codex-cli)"
          "Skill(hookify:writing-rules)"
          "Skill(deep-review)"
          "Skill(ralph-loop:*)"

          # Plugin scripts - ralph-loop
          "Bash(~/.claude/plugins/cache/claude-plugins-official/ralph-loop:*)"

          # Read paths
          "Read(//Users/kamushadenes/**)"
        ];
      };

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
    ".claude/mcp-servers.json.template".text = mcpConfigTemplate;

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
