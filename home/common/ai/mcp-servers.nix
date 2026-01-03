# Unified MCP Server Configuration
#
# Provides a normalized MCP server configuration that can be transformed
# into the specific format required by each AI CLI tool:
# - Claude Code: JSON with type/url/command
# - Codex CLI: TOML with command (uses mcp-remote for HTTP)
# - Gemini CLI: JSON with httpUrl/command
#
# Each server is defined in a normalized format with:
# - transport: "http" | "stdio"
# - url: HTTP endpoint (for http transport)
# - headers: HTTP headers (for http transport)
# - command: Executable command (for stdio transport)
# - args: Command arguments (for stdio transport)
# - env: Environment variables (for stdio transport)
# - timeout: Timeout in milliseconds
{ config, lib }:
let
  homeDir = config.home.homeDirectory;
in
rec {
  #############################################################################
  # Normalized MCP Server Definitions
  #############################################################################

  servers = {
    # DeepWiki - GitHub repository documentation
    deepwiki = {
      transport = "http";
      url = "https://mcp.deepwiki.com/mcp";
    };

    # Ref - Documentation search (requires API key)
    Ref = {
      transport = "http";
      url = "https://api.ref.tools/mcp";
      headers = {
        "x-ref-api-key" = "@REF_API_KEY@";
      };
    };

    # Repomix - Codebase packaging for AI analysis
    repomix = {
      transport = "stdio";
      command = "npx";
      args = [
        "-y"
        "repomix"
        "--mcp"
      ];
    };

    # Go documentation server
    godoc = {
      transport = "stdio";
      command = "godoc-mcp";
      args = [ ];
    };

    # Terraform MCP - Terraform Cloud/Enterprise integration
    terraform = {
      transport = "stdio";
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

    # Orchestrator MCP - Terminal automation + task management
    orchestrator = {
      transport = "stdio";
      command = "uvx";
      args = [
        "--with"
        "fastmcp"
        "python"
        "${homeDir}/.config/orchestrator-mcp/server.py"
      ];
    };

    # PAL MCP - CLI-to-CLI bridge (clink + OpenRouter for fallback)
    pal = {
      transport = "stdio";
      command = "uvx";
      args = [
        "--from"
        "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
        "pal-mcp-server"
      ];
      env = {
        # Disable all tools except clink (version/listmodels cannot be disabled)
        DISABLED_TOOLS = "chat,thinkdeep,planner,consensus,codereview,precommit,debug,apilookup,challenge,analyze,refactor,testgen,secaudit,docgen,tracer";
        # OpenRouter API key for model access
        OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@";
      };
    };
  };

  #############################################################################
  # Secret Placeholders Used in Configurations
  #############################################################################

  # All secret placeholders used across MCP servers
  secretPlaceholders = [
    "@REF_API_KEY@"
    "@TFE_TOKEN@"
    "@OPENROUTER_API_KEY@"
  ];

  # Secret files (relative to private submodule)
  secretFiles = {
    "@REF_API_KEY@" = "home/common/ai/resources/claude/ref-api-key.age";
    "@TFE_TOKEN@" = "home/common/ai/resources/claude/tfe-token.age";
    "@OPENROUTER_API_KEY@" = "home/common/ai/resources/claude/openrouter-api-key.age";
  };

  #############################################################################
  # Transformation Functions
  #############################################################################

  # Transform to Claude Code format (JSON with type field)
  toClaudeCode =
    serverNames:
    lib.filterAttrs (n: _: builtins.elem n serverNames) (
      lib.mapAttrs (
        name: server:
        if server.transport == "http" then
          {
            type = "http";
            url = server.url;
          }
          // lib.optionalAttrs (server ? headers) { inherit (server) headers; }
        else
          {
            type = "stdio";
            command = server.command;
            args = server.args or [ ];
            env = server.env or { };
          }
      ) servers
    );

  # Transform to Codex CLI format (TOML - uses mcp-remote for HTTP servers)
  toCodex =
    serverNames:
    lib.filterAttrs (n: _: builtins.elem n serverNames) (
      lib.mapAttrs (
        name: server:
        if server.transport == "http" then
          {
            command = "npx";
            args = [
              "-y"
              "mcp-remote"
              server.url
            ]
            ++ lib.optionals (server ? headers) (
              lib.flatten (
                lib.mapAttrsToList (k: v: [
                  "--header"
                  "${k}:${v}"
                ]) server.headers
              )
            );
          }
        else
          {
            command = server.command;
            args = server.args or [ ];
          }
          // lib.optionalAttrs (server ? env) { inherit (server) env; }
          // lib.optionalAttrs (server ? timeout) { tool_timeout_sec = server.timeout / 1000; }
      ) servers
    );

  # Transform to Gemini CLI format (JSON with httpUrl field)
  toGemini =
    serverNames:
    lib.filterAttrs (n: _: builtins.elem n serverNames) (
      lib.mapAttrs (
        name: server:
        if server.transport == "http" then
          {
            httpUrl = server.url;
          }
          // lib.optionalAttrs (server ? headers) { inherit (server) headers; }
        else
          {
            command = server.command;
            args = server.args or [ ];
          }
          // lib.optionalAttrs (server ? env) { inherit (server) env; }
          // lib.optionalAttrs (server ? timeout) { inherit (server) timeout; }
      ) servers
    );

  #############################################################################
  # Helper Functions for Agent Modules
  #############################################################################

  # Helper to convert placeholder to path-safe name (lowercase, underscores to dashes)
  placeholderToPathName =
    placeholder:
    let
      stripped = lib.removePrefix "@" (lib.removeSuffix "@" placeholder);
      lowered = lib.toLower stripped;
    in
    builtins.replaceStrings [ "_" ] [ "-" ] lowered;

  # Generate agenix secrets configuration for an agent
  # prefix: unique prefix for secret names (e.g., "claude", "codex", "gemini")
  # secretsDir: directory where secrets should be placed
  # private: path to private submodule
  mkAgenixSecrets =
    {
      prefix,
      secretsDir,
      private,
    }:
    lib.listToAttrs (
      map (placeholder: {
        name = "${prefix}-${placeholderToPathName placeholder}";
        value = {
          file = "${private}/${secretFiles.${placeholder}}";
          path = "${secretsDir}/${placeholderToPathName placeholder}";
        };
      }) (builtins.filter (p: secretFiles ? ${p}) secretPlaceholders)
    );

  # Generate secret substitutions mapping for activation scripts
  # secretsDir: directory where secrets are placed
  mkSecretSubstitutions =
    secretsDir:
    lib.listToAttrs (
      map (placeholder: {
        name = placeholder;
        value = "${secretsDir}/${placeholderToPathName placeholder}";
      }) (builtins.filter (p: secretFiles ? ${p}) secretPlaceholders)
    );
}
