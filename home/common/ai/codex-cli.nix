# OpenAI Codex CLI configuration
#
# Configures Codex CLI with MCP servers, agents, skills, hooks, and rules.
# Uses agenix for secrets management with TOML config file.
# AGENTS.md is generated from shared rules (resources/agents/rules/).
# Custom agents are auto-discovered from resources/codex/agents/.
# Skills are auto-discovered from resources/codex/skills/.
{
  config,
  lib,
  packages,
  pkgs,
  pkgs-unstable,
  private,
  ...
}:
let
  # Import shared MCP server configuration (with pkgs for activation script)
  mcpServers = import ./mcp-servers.nix { inherit config lib pkgs; };

  # MCP servers to include for Codex CLI (shared + codex-specific)
  enabledServers = [
    # Shared with CC/OC
    "slack"
    "aikido"
    "deepwiki"
    "Ref"
    "playwriter"
    "firecrawl-mcp"
    # Codex-specific
    "repomix"
    "godoc"
    "terraform"
    # Private
    "iniciador-vanta"
  ];

  # Resource directories
  resourcesDir = ./resources/codex;
  sharedDir = ./resources/agents;
  rulesDir = "${sharedDir}/rules";
  agentsDir = "${resourcesDir}/agents";
  skillsDir = "${resourcesDir}/skills";

  # Auto-discover shared rule files for AGENTS.md generation
  ruleFiles = builtins.attrNames (builtins.readDir rulesDir);
  agentsMdContent = lib.concatMapStringsSep "\n\n" (name: builtins.readFile "${rulesDir}/${name}") (
    builtins.sort (a: b: a < b) ruleFiles
  );

  # Auto-discover agent TOML files
  discoverFiles =
    dir: ext:
    if builtins.pathExists dir then
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ext name) (builtins.readDir dir)
    else
      { };

  agentFiles = discoverFiles agentsDir ".toml";

  # Auto-discover skill directories (each contains SKILL.md)
  discoverDirs =
    dir:
    if builtins.pathExists dir then
      lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name) (builtins.readDir dir)
    else
      { };

  skillDirs = discoverDirs skillsDir;

  # Recursively collect all files within a directory
  collectFilesRecursive =
    basePath: prefix:
    let
      entries = builtins.readDir basePath;
    in
    lib.foldl' (
      acc: name:
      let
        fullPath = "${basePath}/${name}";
        relPath = if prefix == "" then name else "${prefix}/${name}";
        type = entries.${name};
      in
      if type == "directory" then
        acc // (collectFilesRecursive fullPath relPath)
      else
        acc // { ${relPath} = fullPath; }
    ) { } (builtins.attrNames entries);

  # Collect all skill files for deployment
  skillFiles = lib.foldl' (
    acc: skillName:
    let
      skillPath = "${skillsDir}/${skillName}";
      files = collectFilesRecursive skillPath "";
    in
    acc
    // lib.mapAttrs' (relPath: srcPath: {
      name = "${skillName}/${relPath}";
      value = srcPath;
    }) files
  ) { } (builtins.attrNames skillDirs);

  # Codex CLI configuration
  mcpConfig = {
    mcp_servers = mcpServers.toCodex enabledServers;

    # Model configuration
    model = "o3";
    model_reasoning_effort = "high";

    # Approval and sandbox policy (matches CC's bypassPermissions)
    approval_policy = "never";
    sandbox_mode = "workspace-write";

    # Communication style
    personality = "pragmatic";

    # Web search
    web_search = "live";

    # Agent configuration
    agents = {
      max_threads = 6;
      max_depth = 1;
    };

    # Feature flags
    features = {
      codex_hooks = true;
      web_search_request = true;
    };
  };

  # Hooks configuration (JSON format at ~/.codex/hooks.json)
  hooksConfig = {
    hooks = {
      PreToolUse = [
        # RTK auto-rewrite: transparently prefix commands with rtk for token savings
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.codex/hooks/pre-tool-use/rtk-rewrite.sh";
            }
          ];
        }
      ];

      SessionStart = [
        # Caveman mode activation
        {
          matcher = "startup|resume";
          hooks = [
            {
              type = "command";
              command = "echo 'CAVEMAN MODE ACTIVE. Rules: Drop articles/filler/pleasantries/hedging. Fragments OK. Short synonyms. Pattern: [thing] [action] [reason]. [next step]. Not: Sure! I would be happy to help you with that. Yes: Bug in auth middleware. Fix: Code/commits/security: write normal. User says stop caveman or normal mode to deactivate.'";
              timeout = 5;
              statusMessage = "Loading caveman mode";
            }
          ];
        }
        # Devbox/direnv setup for web environments
        {
          matcher = "startup";
          hooks = [
            {
              type = "command";
              command = "~/.codex/hooks/session-start/devbox-setup.sh";
            }
          ];
        }
      ];

      Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "~/.codex/hooks/stop-format-and-lint.sh";
              timeout = 60;
              statusMessage = "Formatting modified files";
            }
          ];
        }
      ];

      PostToolUseFailure = [
        # Suggest nix-shell for missing commands
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.codex/hooks/post-tool-use-failure/suggest-nix-shell.sh";
              timeout = 10;
            }
          ];
        }
      ];

      TaskCompleted = [
        {
          hooks = [
            {
              type = "command";
              command = "~/.codex/hooks/task-completed/verify-completion.sh";
            }
          ];
        }
      ];
    };
  };

  # Convert to TOML format
  mcpConfigToml = pkgs.formats.toml { };

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.codex/secrets";

  # Wrapper script for codex review with live colorized output
  codexReview = pkgs.writeScriptBin "codex-review" ''
    #!${pkgs.python3}/bin/python3
    import subprocess
    import sys
    import json

    if len(sys.argv) < 2:
        print("Usage: codex-review [codex-args...] <output-file>", file=sys.stderr)
        print("Example: codex-review review --uncommitted /tmp/review.txt", file=sys.stderr)
        sys.exit(1)

    output_file = sys.argv[-1]
    codex_args = sys.argv[1:-1]

    # ANSI colors
    DIM = "\033[2m"
    BOLD = "\033[1m"
    CYAN = "\033[36m"
    GREEN = "\033[32m"
    RED = "\033[31m"
    RESET = "\033[0m"

    final_message = ""

    proc = subprocess.Popen(
        ["${lib.getExe pkgs-unstable.codex}", "exec", "-s", "read-only", "--json"] + codex_args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    for line in proc.stdout:
        try:
            event = json.loads(line.strip())
            event_type = event.get("type", "")

            if event_type == "item.completed":
                item = event.get("item", {})
                item_type = item.get("type", "")

                if item_type == "reasoning":
                    text = item.get("text", "")
                    print(f"{DIM}💭 {text}{RESET}", flush=True)

                elif item_type == "command_execution":
                    exit_code = item.get("exit_code")
                    ok = exit_code == 0
                    status = "✓" if ok else "✗"
                    color = GREEN if ok else RED
                    cmd = item.get("command", "")
                    output = item.get("aggregated_output", "")
                    print(f"{color}{status}{RESET} {CYAN}{cmd}{RESET}", flush=True)
                    if output:
                        print(f"{DIM}{output.rstrip()}{RESET}", flush=True)

                elif item_type == "agent_message":
                    final_message = item.get("text", "")
                    print(f"\n{BOLD}📝 Result:{RESET}\n{final_message}", flush=True)

            elif event_type == "turn.completed":
                usage = event.get("usage", {})
                inp = usage.get("input_tokens", 0)
                out = usage.get("output_tokens", 0)
                print(f"\n{DIM}Tokens: {inp} in, {out} out{RESET}", flush=True)

        except json.JSONDecodeError:
            pass

    proc.wait()

    with open(output_file, "w") as f:
        f.write(final_message)
  '';
in
{
  #############################################################################
  # Package Installation
  #############################################################################

  home.packages = [
    pkgs-unstable.codex
    codexReview
    packages.rtk # Matches the shared RTK rules in AGENTS.md.
    pkgs.nodePackages.prettier # Markdown/TypeScript formatting
    pkgs.ruff # Python formatting
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets =
    mcpServers.mkAgenixSecrets {
      prefix = "codex";
      secretsDir = secretsDir;
      inherit private;
    }
    // {
      # Iniciador Vanta credentials - needs file path, not substituted content
      "codex-iniciador-vanta-credentials" = {
        file = "${private}/home/common/ai/resources/claude/vanta-credentials.age";
        path = "${secretsDir}/iniciador-vanta-credentials";
      };
    };

  #############################################################################
  # Codex CLI Configuration, Agents, Skills, Hooks
  #############################################################################

  home.file = {
    # TOML template with @PLACEHOLDER@ values - secrets substituted at activation
    ".codex/config.toml.template".source =
      mcpConfigToml.generate "codex-config-template.toml" mcpConfig;

    # Global AGENTS.md - generated from shared rules
    ".codex/AGENTS.md".text = agentsMdContent;

    # Hooks configuration (JSON)
    ".codex/hooks.json".text = builtins.toJSON hooksConfig;

    # Hook scripts - Stop
    ".codex/hooks/stop-format-and-lint.sh" = {
      source = "${resourcesDir}/scripts/hooks/stop-format-and-lint.sh";
      executable = true;
    };

    # Hook scripts - PreToolUse
    ".codex/hooks/pre-tool-use/rtk-rewrite.sh" = {
      source = "${resourcesDir}/scripts/hooks/pre-tool-use/rtk-rewrite.sh";
      executable = true;
    };

    # Hook scripts - SessionStart
    ".codex/hooks/session-start/devbox-setup.sh" = {
      source = "${resourcesDir}/scripts/hooks/session-start/devbox-setup.sh";
      executable = true;
    };

    # Hook scripts - PostToolUseFailure
    ".codex/hooks/post-tool-use-failure/suggest-nix-shell.sh" = {
      source = "${resourcesDir}/scripts/hooks/post-tool-use-failure/suggest-nix-shell.sh";
      executable = true;
    };

    # Hook scripts - TaskCompleted
    ".codex/hooks/task-completed/verify-completion.sh" = {
      source = "${resourcesDir}/scripts/hooks/task-completed/verify-completion.sh";
      executable = true;
    };
  }
  # Agents - auto-discovered TOML files from resources/codex/agents/
  // lib.mapAttrs' (name: _: {
    name = ".codex/agents/${name}";
    value.source = "${agentsDir}/${name}";
  }) agentFiles
  # Agent references and templates (shared with CC/OC for parity)
  // {
    ".codex/agents/_references/code-smells-catalog.md".source =
      ./resources/claude-code/agents/_references/code-smells-catalog.md;
    ".codex/agents/_references/language-conventions.md".source =
      ./resources/claude-code/agents/_references/language-conventions.md;
    ".codex/agents/_templates/severity-levels.md".source =
      ./resources/claude-code/agents/_templates/severity-levels.md;
  }
  # Skills - auto-discovered from resources/codex/skills/
  // lib.mapAttrs' (name: sourcePath: {
    name = ".codex/skills/${name}";
    value =
      if lib.hasSuffix ".py" name || lib.hasSuffix ".sh" name then
        {
          source = sourcePath;
          executable = true;
        }
      else
        { source = sourcePath; };
  }) skillFiles;

  #############################################################################
  # Secret Substitution and Config Activation
  #############################################################################

  home.activation.codexCliConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    mcpServers.mkActivationScript {
      configPath = "${config.home.homeDirectory}/.codex/config.toml";
      secretsDir = secretsDir;
    }
  );
}
