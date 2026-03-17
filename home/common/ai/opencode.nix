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
  pkgs,
  private,
  ...
}:
let
  # Import shared MCP server configuration (with pkgs for activation script)
  mcpServers = import ./mcp-servers.nix { inherit config lib pkgs; };

  # MCP servers to include for OpenCode
  enabledServers = [
    "aikido"
    "deepwiki"
    "Ref"
    "playwriter"
    "orchestrator"
  ];

  # Resource directories
  resourcesDir = ./resources/opencode;
  rulesDir = "${resourcesDir}/rules";
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

  ruleFiles = discoverFiles rulesDir;
  pluginFiles = discoverFiles pluginsDir;
  agentFiles = discoverFiles agentsDir;
  commandFiles = discoverFiles commandsDir;

  # Private provider configurations (internal endpoints, not in public repo)
  privateProviders =
    let
      path = "${private}/home/common/ai/opencode-providers.nix";
    in
    if builtins.pathExists path then import path else { };

  # OpenCode config as Nix attrset
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    model = "ccflare/claude-opus-4-6"; # was: anthropic/claude-opus-4-6
    small_model = "ccflare/claude-haiku-4-5"; # was: anthropic/claude-haiku-4-5
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
    provider = privateProviders;
    plugin = [ "oh-my-opencode" ];
  };

  # oh-my-opencode plugin configuration
  omoConfig = {
    "$schema" =
      "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
    agents = {
      sisyphus = {
        model = "ccflare/claude-opus-4-6"; # was: anthropic/claude-opus-4-6
        variant = "max";
      };
      hephaestus = {
        model = "opencode/gpt-5.3-codex";
        variant = "medium";
      };
      oracle = {
        model = "github-copilot/gpt-5.4";
        variant = "high";
      };
      librarian = {
        model = "opencode/glm-4.7-free";
      };
      explore = {
        model = "ccflare/claude-haiku-4-5"; # was: anthropic/claude-haiku-4-5
      };
      multimodal-looker = {
        model = "opencode/gpt-5.4";
        variant = "medium";
      };
      prometheus = {
        model = "ccflare/claude-opus-4-6"; # was: anthropic/claude-opus-4-6
        variant = "max";
      };
      metis = {
        model = "ccflare/claude-opus-4-6"; # was: anthropic/claude-opus-4-6
        variant = "max";
      };
      momus = {
        model = "github-copilot/gpt-5.4";
        variant = "xhigh";
      };
      atlas = {
        model = "ccflare/claude-sonnet-4-5"; # was: anthropic/claude-sonnet-4-5
      };
    };
    categories = {
      visual-engineering = {
        model = "google/gemini-3.1-pro-preview";
        variant = "high";
      };
      ultrabrain = {
        model = "opencode/gpt-5.3-codex";
        variant = "xhigh";
      };
      deep = {
        model = "opencode/gpt-5.3-codex";
        variant = "medium";
      };
      artistry = {
        model = "google/gemini-3.1-pro-preview";
        variant = "high";
      };
      quick = {
        model = "ccflare/claude-haiku-4-5"; # was: anthropic/claude-haiku-4-5
      };
      unspecified-low = {
        model = "ccflare/claude-sonnet-4-5"; # was: anthropic/claude-sonnet-4-5
      };
      unspecified-high = {
        model = "github-copilot/gpt-5.4";
        variant = "high";
      };
      writing = {
        model = "google/gemini-3-flash-preview";
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
  home.packages = lib.optionals (!pkgs.stdenv.isDarwin) [
    pkgs.opencode
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = mcpServers.mkAgenixSecrets {
    prefix = "opencode";
    secretsDir = secretsDir;
    inherit private;
  };

  #############################################################################
  # OpenCode Configuration
  #############################################################################
  home.file = {
    # JSON template with @PLACEHOLDER@ values - secrets substituted at activation
    ".config/opencode/config.json.template".text = configTemplate;

    # oh-my-opencode plugin configuration
    ".config/opencode/oh-my-opencode.json".text = builtins.toJSON omoConfig;

    # TUI configuration (theme)
    ".config/opencode/tui.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/tui.json";
      theme = "catppuccin-macchiato";
    };

  }
  # Rules - auto-discovered from rulesDir
  // lib.mapAttrs' (name: _: {
    name = ".config/opencode/rules/${name}";
    value.source = "${rulesDir}/${name}";
  }) ruleFiles
  # Plugins - auto-discovered from pluginsDir
  // lib.mapAttrs' (name: _: {
    name = ".config/opencode/plugins/${name}";
    value.source = "${pluginsDir}/${name}";
  }) pluginFiles
  # Agents - auto-discovered from agentsDir
  // lib.mapAttrs' (name: _: {
    name = ".config/opencode/agents/${name}";
    value.source = "${agentsDir}/${name}";
  }) agentFiles
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
}
