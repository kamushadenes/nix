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

  # OpenCode config as Nix attrset
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    model = "anthropic/claude-opus-4-6";
    small_model = "anthropic/claude-haiku-4-5";
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
        "*" = "ask";
        "git *" = "allow";
        "gh *" = "allow";
        "go *" = "allow";
        "nix *" = "allow";
        "nixfmt *" = "allow";
        "rg *" = "allow";
        "fd *" = "allow";
        "just *" = "allow";
        "terraform *" = "allow";
        "curl *" = "allow";
        "jq *" = "allow";
        "rebuild *" = "allow";
        "cat *" = "allow";
        "ls *" = "allow";
        "test *" = "allow";
        "sort *" = "allow";
        "head *" = "allow";
        "tail *" = "allow";
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
    plugin = [ ];
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

  home.file =
    {
      # JSON template with @PLACEHOLDER@ values - secrets substituted at activation
      ".config/opencode/config.json.template".text = configTemplate;

      # Global AGENTS.md - workflow instructions for OpenCode
    }
    // lib.optionalAttrs (builtins.pathExists "${resourcesDir}/OPENCODE.md") {
      ".config/opencode/AGENTS.md".source = "${resourcesDir}/OPENCODE.md";
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
