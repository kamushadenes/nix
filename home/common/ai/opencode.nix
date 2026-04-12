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
    model = "anthropic/claude-opus-4-6";
    small_model = "opencode/minimax-m2.5-free";
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
  omoConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
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
      theme = "catppuccin-macchiato";
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
