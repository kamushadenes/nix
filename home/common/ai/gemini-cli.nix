# Google Gemini CLI configuration
#
# Configures Gemini CLI with MCP servers from shared configuration.
# Uses agenix for secrets management with JSON config file.
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  private,
  ...
}:
let
  # Import shared MCP server configuration (with pkgs for activation script)
  mcpServers = import ./mcp-servers.nix { inherit config lib pkgs; };

  # MCP servers to include for Gemini CLI
  enabledServers = [
    "deepwiki"
    "Ref"
    "repomix"
    "godoc"
    "terraform"
    "orchestrator"
  ];

  # MCP server configurations in Gemini format
  mcpConfig = {
    mcpServers = mcpServers.toGemini enabledServers;
    security = {
      auth = {
        selectedType = "oauth-personal";
      };
    };
  };

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.gemini/secrets";

  # Template file for MCP servers (with placeholders)
  mcpConfigTemplate = builtins.toJSON mcpConfig;
in
{
  #############################################################################
  # Package Installation
  #############################################################################

  home.packages = [
    pkgs-unstable.gemini-cli
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = mcpServers.mkAgenixSecrets {
    prefix = "gemini";
    secretsDir = secretsDir;
    inherit private;
  };

  #############################################################################
  # Gemini CLI Configuration Template
  #############################################################################

  home.file = {
    # JSON template with @PLACEHOLDER@ values - secrets substituted at activation
    ".gemini/settings.json.template".text = mcpConfigTemplate;

    # Global GEMINI.md - workflow instructions for Gemini agents
    ".gemini/GEMINI.md".source = ./resources/gemini/GEMINI.md;
  };

  #############################################################################
  # Secret Substitution and Config Activation
  #############################################################################

  home.activation.geminiCliConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    mcpServers.mkActivationScript {
      configPath = "${config.home.homeDirectory}/.gemini/settings.json";
      secretsDir = secretsDir;
    }
  );
}
