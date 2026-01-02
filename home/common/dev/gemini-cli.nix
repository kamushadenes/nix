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
  # Import shared MCP server configuration
  mcpServers = import ./mcp-servers.nix { inherit config lib; };

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
  };

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.gemini/secrets";
  secretSubstitutions = mcpServers.mkSecretSubstitutions secretsDir;

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
  };

  #############################################################################
  # Secret Substitution and Config Activation
  #############################################################################

  home.activation.geminiCliConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${secretsDir}

    # Remove existing settings.json if it exists
    run rm -f ${config.home.homeDirectory}/.gemini/settings.json

    # Copy template to working file
    run cp ${config.home.homeDirectory}/.gemini/settings.json.template \
           ${config.home.homeDirectory}/.gemini/settings.json

    # Substitute each @PLACEHOLDER@ with its decrypted secret value
    ${lib.concatMapStrings (
      ph:
      let
        secretPath = secretSubstitutions.${ph};
      in
      ''
        if [ -f "${secretPath}" ]; then
          run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" \
              ${config.home.homeDirectory}/.gemini/settings.json
        fi
      ''
    ) (lib.attrNames secretSubstitutions)}

    # Restrict permissions - config contains API keys
    run chmod 600 ${config.home.homeDirectory}/.gemini/settings.json
  '';
}
