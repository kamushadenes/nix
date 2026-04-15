# OpenCode configuration
#
# Configures OpenCode with MCP servers from shared configuration.
# Uses agenix for secrets management with JSON config file.
#
# Darwin installs via homebrew, Linux uses nixpkgs.
# Resources are auto-discovered from resources/opencode/.
{
  config,
  lib,
  packages,
  pkgs,
  private,
  ...
}:
let
  # Import shared MCP server configuration (with pkgs for activation script)
  mcpServers = import ./mcp-servers.nix { inherit config lib pkgs; };

  # MCP servers to include for OpenCode
  enabledServers = [
    "slack"
    "aikido"
    "deepwiki"
    "Ref"
    "playwriter"
    "firecrawl-mcp"
    "iniciador-vanta"
  ];

  # Resource directories
  resourcesDir = ./resources/opencode;
  sharedDir = ./resources/agents;
  sharedRulesDir = "${sharedDir}/rules";
  pluginsDir = "${resourcesDir}/plugins";
  agentsDir = "${resourcesDir}/agents";
  commandsDir = "${resourcesDir}/commands";

  # Auto-discover files from a directory (with existence guard)
  discoverFiles =
    dir:
    if builtins.pathExists dir then
      lib.filterAttrs (name: type: type == "regular") (builtins.readDir dir)
    else
      { };

  sharedRuleFiles = discoverFiles sharedRulesDir;
  agentFiles = discoverFiles agentsDir;
  commandFiles = discoverFiles commandsDir;

  # OpenCode config as Nix attrset
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    model = "opencode/claude-opus-4-6";
    small_model = "opencode/minimax-m2.5-free";
    provider = {
      anthropic = {
        baseUrl = "http://localhost:8787";
      };
    };
    instructions = [ "~/.config/opencode/rules/*.md" ];
    mcp = mcpServers.toOpenCode enabledServers;
    permission = {
      edit = "allow";
      read = "allow";
      write = "allow";
      grep = "allow";
      glob = "allow";
      list = "allow";
      webfetch = "allow";
      websearch = "allow";
      bash = {
        "*" = "allow";
      };
    };
    formatter = {
      python-ruff = {
        command = [
          "ruff"
          "format"
          "$FILE"
        ];
        extensions = [ ".py" ];
      };
      typescript-prettier = {
        command = [
          "prettier"
          "--write"
          "$FILE"
        ];
        extensions = [
          ".ts"
          ".tsx"
          ".js"
          ".jsx"
        ];
      };
      nix-nixfmt = {
        command = [
          "nixfmt"
          "$FILE"
        ];
        extensions = [ ".nix" ];
      };
      go-goimports = {
        command = [
          "goimports"
          "-w"
          "$FILE"
        ];
        extensions = [ ".go" ];
      };
      markdown-prettier = {
        command = [
          "prettier"
          "--write"
          "--prose-wrap"
          "always"
          "$FILE"
        ];
        extensions = [ ".md" ];
      };
    };
    plugin = [
      "oh-my-opencode@3.13.1"
      "cc-safety-net"
      "@simonwjackson/opencode-direnv"
      "envsitter-guard"
      "opentmux"
      "opencode-vibeguard"
      "opencode-wakatime"
      "@devtheops/opencode-plugin-otel"
    ];
  };

  # oh-my-opencode plugin configuration (v3.13.1)
  # Agent models configured for available providers: anthropic, github-copilot,
  # opencode (zen), openai, opencode-go, google, ollama-cloud.
  # Chains derived from: https://github.com/code-yeongyu/oh-my-openagent/blob/dev/docs/guide/installation.md#step-5-understand-your-model-setup
  omoConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      # ── Claude-optimized agents (prompts tuned for Claude-family models) ──
      sisyphus = {
        model = "anthropic/claude-opus-4-6";
        fallback_models = [
          "github-copilot/claude-opus-4.6"
          "opencode-go/kimi-k2.5"
          "ollama-cloud/kimi-k2.5"
          {
            model = "openai/gpt-5.4";
            variant = "medium";
          }
          "anthropic/glm-5"
          "anthropic/big-pickle"
        ];
      };
      metis = {
        model = "anthropic/claude-opus-4-6";
        fallback_models = [
          "github-copilot/claude-opus-4.6"
          {
            model = "openai/gpt-5.4";
            variant = "high";
          }
          "opencode-go/glm-5"
        ];
      };
      # ── Dual-prompt agents (auto-switch between Claude/GPT prompts) ──
      prometheus = {
        model = "anthropic/claude-opus-4-6";
        fallback_models = [
          "github-copilot/claude-opus-4.6"
          {
            model = "openai/gpt-5.4";
            variant = "high";
          }
          "opencode-go/glm-5"
          "google/gemini-3.1-pro"
          "github-copilot/gemini-3.1-pro"
        ];
      };
      atlas = {
        model = "github-copilot/claude-sonnet-4.6";
        fallback_models = [
          "opencode-go/kimi-k2.5"
          {
            model = "openai/gpt-5.4";
            variant = "medium";
          }
          "opencode-go/minimax-m2.7"
        ];
      };
      # ── GPT-native agents (built for GPT, don't override to Claude) ──
      hephaestus = {
        model = "openai/gpt-5.4";
      };
      oracle = {
        model = "openai/gpt-5.4";
        fallback_models = [
          "github-copilot/gpt-5.4"
          {
            model = "google/gemini-3.1-pro";
            variant = "high";
          }
          {
            model = "github-copilot/gemini-3.1-pro";
            variant = "high";
          }
          "anthropic/claude-opus-4-6"
          "opencode-go/glm-5"
        ];
      };
      momus = {
        model = "openai/gpt-5.4";
        fallback_models = [
          "github-copilot/gpt-5.4"
          "anthropic/claude-opus-4-6"
          {
            model = "google/gemini-3.1-pro";
            variant = "high";
          }
          {
            model = "github-copilot/gemini-3.1-pro";
            variant = "high";
          }
          "opencode-go/glm-5"
        ];
      };
      # ── Utility agents (speed over intelligence — don't "upgrade" to Opus) ──
      explore = {
        model = "github-copilot/grok-code-fast-1";
        fallback_models = [
          "opencode-go/minimax-m2.7-highspeed"
          "anthropic/minimax-m2.7"
          "anthropic/claude-haiku-4-5"
          "anthropic/gpt-5-nano"
        ];
      };
      librarian = {
        model = "opencode-go/minimax-m2.7";
        fallback_models = [
          "anthropic/minimax-m2.7-highspeed"
          "anthropic/claude-haiku-4-5"
          "anthropic/gpt-5-nano"
        ];
      };
      "multimodal-looker" = {
        model = "openai/gpt-5.4";
        fallback_models = [
          "anthropic/gpt-5.4"
          "opencode-go/kimi-k2.5"
          "anthropic/gpt-5-nano"
        ];
      };
    };
    lsp = {
      templ = {
        command = [
          "templ"
          "lsp"
        ];
        extensions = [ ".templ" ];
      };
    };
  };

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.config/opencode/secrets";

  # Template file for config (with placeholders)
  configTemplate = builtins.toJSON opencodeConfig;
in
{
  #############################################################################
  # Package Installation
  #############################################################################

  # Darwin uses homebrew (added in brew.nix), Linux uses nixpkgs
  home.packages = [
    packages.rtk # Enables the bundled RTK OpenCode plugin.
  ]
  ++ lib.optionals (!pkgs.stdenv.isDarwin) [
    pkgs.opencode
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets =
    mcpServers.mkAgenixSecrets {
      prefix = "opencode";
      secretsDir = secretsDir;
      inherit private;
    }
    // {
      # Iniciador Vanta credentials - needs file path, not substituted content
      "opencode-iniciador-vanta-credentials" = {
        file = "${private}/home/common/ai/resources/claude/vanta-credentials.age";
        path = "${secretsDir}/iniciador-vanta-credentials";
      };

      # OTEL telemetry secrets (endpoint + auth headers)
      "opencode-otel-endpoint" = {
        file = "${private}/home/common/ai/resources/claude/otel-endpoint.age";
        path = "${secretsDir}/otel-endpoint";
      };
      "opencode-otel-headers" = {
        file = "${private}/home/common/ai/resources/claude/otel-headers.age";
        path = "${secretsDir}/otel-headers";
      };
    };

  #############################################################################
  # OpenCode Configuration
  #############################################################################
  home.file = {
    # JSON template with @PLACEHOLDER@ values - secrets substituted at activation
    ".config/opencode/config.json.template".text = configTemplate;

    # oh-my-opencode plugin configuration
    ".config/opencode/oh-my-opencode.json".text = builtins.toJSON omoConfig;

    # TUI configuration (theme + keybinds aligned with Claude Code)
    ".config/opencode/tui.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      theme = "conductor";
      keybinds = {
        # Align with Claude Code muscle memory
        editor_open = "ctrl+g"; # CC: ctrl+g opens external editor
        status_view = "ctrl+t"; # CC: ctrl+t toggles task list
        session_child_first = "shift+down"; # CC: shift+down opens subtasks
        # Remap displaced defaults
        input_select_down = "ctrl+shift+down"; # was shift+down, displaced by session_child_first
        input_select_up = "ctrl+shift+up"; # symmetric remap
        input_select_left = "ctrl+shift+left"; # symmetric remap
        input_select_right = "ctrl+shift+right"; # symmetric remap
        variant_cycle = "<leader>v"; # was ctrl+t, displaced by status_view
        messages_first = "home"; # was ctrl+g,home — ctrl+g now opens editor
      };
    };

  }
  # Themes - custom theme files
  // {
    ".config/opencode/themes" = {
      source = ./resources/opencode/themes;
      recursive = true;
    };
  }
  # Rules - from shared resources/agents/ (all OC rules are now global)
  // lib.mapAttrs' (name: _: {
    name = ".config/opencode/rules/${name}";
    value.source = "${sharedRulesDir}/${name}";
  }) sharedRuleFiles
  # Plugins - recursive directory deployment (supports multi-file plugins)
  // {
    ".config/opencode/plugins" = {
      source = pluginsDir;
      recursive = true;
    };
  }
  # Agents - auto-discovered from agentsDir (flat .md files)
  // lib.mapAttrs' (name: _: {
    name = ".config/opencode/agents/${name}";
    value.source = "${agentsDir}/${name}";
  }) agentFiles
  # Agent subdirectories (_references, _templates) - recursive deployment
  //
    lib.mapAttrs'
      (name: _: {
        name = ".config/opencode/agents/${name}";
        value = {
          source = "${agentsDir}/${name}";
          recursive = true;
        };
      })
      (
        lib.filterAttrs (name: type: type == "directory" && lib.hasPrefix "_" name) (
          if builtins.pathExists agentsDir then builtins.readDir agentsDir else { }
        )
      )
  # Commands - auto-discovered from commandsDir
  // lib.mapAttrs' (name: _: {
    name = ".config/opencode/commands/${name}";
    value.source = "${commandsDir}/${name}";
  }) commandFiles;

  #############################################################################
  # Secret Substitution and Config Activation
  #############################################################################

  home.activation.opencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    mcpServers.mkActivationScript {
      configPath = "${config.home.homeDirectory}/.config/opencode/config.json";
      secretsDir = secretsDir;
    }
  );

  # Install npm dependencies for local plugins (opencode-notify needs these)
  home.activation.opencodePluginDeps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    OPENCODE_DIR="${config.home.homeDirectory}/.config/opencode"
    if ! [ -d "$OPENCODE_DIR/node_modules/node-notifier" ] || ! [ -d "$OPENCODE_DIR/node_modules/detect-terminal" ]; then
      run ${lib.getExe pkgs.bun} install --cwd "$OPENCODE_DIR" node-notifier detect-terminal 2>/dev/null || true
    fi
  '';
}
