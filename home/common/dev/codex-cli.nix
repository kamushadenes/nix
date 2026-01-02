# OpenAI Codex CLI configuration
#
# Configures Codex CLI with MCP servers matching Claude Code setup.
# Uses agenix for secrets management with TOML config file.
#
# MCP servers provide:
# - DeepWiki: GitHub repository documentation
# - Ref: Documentation search
# - Repomix: Codebase packaging for AI analysis
# - PAL: Multi-model AI collaboration
# - godoc: Go documentation
# - Terraform: Terraform Cloud/Enterprise integration
# - tmux: Terminal automation
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  private,
  ...
}:
let
  # MCP server configurations matching Claude Code setup
  # Uses TOML format for Codex CLI config
  mcpConfig = {
    mcp_servers = {
      # DeepWiki - GitHub repository documentation (HTTP-based, no secrets)
      # Note: Codex CLI uses stdio-based servers, so we use mcp-remote for HTTP
      deepwiki = {
        command = "npx";
        args = [
          "-y"
          "mcp-remote"
          "https://mcp.deepwiki.com/mcp"
        ];
      };

      # Ref - Documentation search (requires API key via header)
      Ref = {
        command = "npx";
        args = [
          "-y"
          "mcp-remote"
          "https://api.ref.tools/mcp"
          "--header"
          "x-ref-api-key:@REF_API_KEY@"
        ];
      };

      # Repomix - Codebase packaging for AI analysis
      repomix = {
        command = "npx";
        args = [
          "-y"
          "repomix"
          "--mcp"
        ];
      };

      # PAL - Multi-model AI assistant (disabled - using alternative approach)
      # pal = {
      #   command = "uvx";
      #   args = [
      #     "--from"
      #     "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
      #     "pal-mcp-server"
      #   ];
      #   tool_timeout_sec = 1200;
      #   env = {
      #     OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@";
      #     DISABLED_TOOLS = "tracer";
      #   };
      # };

      # Go documentation server
      godoc = {
        command = "godoc-mcp";
        args = [ ];
      };

      # Terraform MCP - Terraform Cloud/Enterprise integration
      terraform = {
        command = "docker";
        args = [
          "run"
          "-i"
          "--rm"
          "-e"
          "TFE_TOKEN=@TFE_TOKEN@"
          "-e"
          "TFE_ADDRESS=https://app.terraform.io"
          "hashicorp/terraform-mcp-server"
        ];
      };

      # tmux MCP - Terminal automation for pane management
      tmux = {
        command = "uvx";
        args = [
          "--with"
          "fastmcp"
          "python"
          "${config.home.homeDirectory}/.config/tmux-mcp/server.py"
        ];
      };
    };

    features = {
      web_search_request = true;
    };
  };

  # Convert to TOML format
  mcpConfigToml = pkgs.formats.toml { };

  # Placeholders to secret paths mapping for substitution
  secretSubstitutions = {
    "@REF_API_KEY@" = "${config.home.homeDirectory}/.codex/secrets/ref-api-key";
    # "@OPENROUTER_API_KEY@" = "${config.home.homeDirectory}/.codex/secrets/openrouter-api-key";  # PAL disabled
    "@TFE_TOKEN@" = "${config.home.homeDirectory}/.codex/secrets/tfe-token";
  };
in
{
  #############################################################################
  # Package Installation
  #############################################################################

  home.packages = [
    pkgs-unstable.codex
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = {
    "codex-ref-api-key" = {
      file = "${private}/home/common/dev/resources/claude/ref-api-key.age";
      path = "${config.home.homeDirectory}/.codex/secrets/ref-api-key";
    };
    # PAL disabled - openrouter key not needed
    # "codex-openrouter-api-key" = {
    #   file = "${private}/home/common/dev/resources/claude/openrouter-api-key.age";
    #   path = "${config.home.homeDirectory}/.codex/secrets/openrouter-api-key";
    # };
    "codex-tfe-token" = {
      file = "${private}/home/common/dev/resources/claude/tfe-token.age";
      path = "${config.home.homeDirectory}/.codex/secrets/tfe-token";
    };
  };

  #############################################################################
  # Codex CLI Configuration Template
  #############################################################################

  home.file = {
    # TOML template with @PLACEHOLDER@ values - secrets substituted at activation
    ".codex/config.toml.template".source = mcpConfigToml.generate "codex-config-template.toml" mcpConfig;
  };

  #############################################################################
  # Secret Substitution and Config Activation
  #############################################################################

  home.activation.codexCliConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p ${config.home.homeDirectory}/.codex/secrets

    # Remove existing config.toml if it exists
    run rm -f ${config.home.homeDirectory}/.codex/config.toml

    # Copy template to working file
    run cp ${config.home.homeDirectory}/.codex/config.toml.template \
           ${config.home.homeDirectory}/.codex/config.toml

    # Substitute each @PLACEHOLDER@ with its decrypted secret value
    ${lib.concatMapStrings (
      ph:
      let
        secretPath = secretSubstitutions.${ph};
      in
      ''
        if [ -f "${secretPath}" ]; then
          run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" \
              ${config.home.homeDirectory}/.codex/config.toml
        fi
      ''
    ) (lib.attrNames secretSubstitutions)}
  '';
}
