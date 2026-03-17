# Unified MCP Server Configuration
#
# Provides a normalized MCP server configuration that can be transformed
# into the specific format required by each AI CLI tool:
# - Claude Code: JSON with type/url/command
# - Codex CLI: TOML with command (uses mcp-remote for HTTP)
# - Gemini CLI: JSON with httpUrl/command
# - OpenCode: JSON with type (local/remote), command array
#
# Each server is defined in a normalized format with:
# - transport: "http" | "stdio"
# - url: HTTP endpoint (for http transport)
# - headers: HTTP headers (for http transport)
# - command: Executable command (for stdio transport)
# - args: Command arguments (for stdio transport)
# - env: Environment variables (for stdio transport)
# - timeout: Timeout in milliseconds
{ config, lib, pkgs ? null, private ? null }:
let
  homeDir = config.home.homeDirectory;

  # Import private MCP servers if available
  privateMcp =
    if private != null && builtins.pathExists "${private}/home/common/ai/mcp-servers-private.nix" then
      import "${private}/home/common/ai/mcp-servers-private.nix" { inherit config lib; }
    else
      {
        servers = { };
        enabledServers = [ ];
        secretPlaceholders = [ ];
        secretFiles = { };
      };

  #############################################################################
  # Public MCP Server Definitions
  #############################################################################

  publicServers = {
    # Slack MCP - Workspace messaging, search, channels
    slack = {
      transport = "http";
      url = "https://mcp.slack.com/mcp";
      oauth = {
        clientId = "1601185624273.8899143856786";
        callbackPort = 3118;
      };
    };

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

    # Aikido - SAST + secrets scanning
    aikido = {
      transport = "stdio";
      command = "npx";
      args = [
        "-y"
        "@aikidosec/mcp"
      ];
      env = {
        AIKIDO_API_KEY = "@AIKIDO_API_KEY@";
      };
    };

    # Playwriter - Control existing Chrome via Playwright
    playwriter = {
      transport = "stdio";
      command = "npx";
      args = [
        "-y"
        "playwriter@latest"
      ];
    };

    # Orchestrator MCP - Terminal automation
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

    # Note: clickup and vanta moved to private/home/common/ai/mcp-servers-private.nix
    # as iniciador-clickup and iniciador-vanta (workspace-scoped)
  };

  #############################################################################
  # Public Enabled Servers (for Claude Code)
  #############################################################################

  publicEnabledServers = [
    "slack"
    "aikido"
    "deepwiki"
    "Ref"
    "playwriter"
    "orchestrator"
  ];

  #############################################################################
  # Public Secret Placeholders
  #############################################################################

  publicSecretPlaceholders = [
    "@AIKIDO_API_KEY@"
    "@REF_API_KEY@"
    "@TFE_TOKEN@"
    "@OPENROUTER_API_KEY@"
  ];

  # Secret files (relative to private submodule)
  publicSecretFiles = {
    "@AIKIDO_API_KEY@" = "home/common/ai/resources/claude/aikido-api-key.age";
    "@REF_API_KEY@" = "home/common/ai/resources/claude/ref-api-key.age";
    "@TFE_TOKEN@" = "home/common/ai/resources/claude/tfe-token.age";
    "@OPENROUTER_API_KEY@" = "home/common/ai/resources/claude/openrouter-api-key.age";
  };
in
rec {
  #############################################################################
  # Merged Configurations (Public + Private)
  #############################################################################

  # Merge public + private servers
  servers = publicServers // privateMcp.servers;

  # Merge enabled servers lists
  enabledServers = publicEnabledServers ++ privateMcp.enabledServers;

  # Merge secret placeholders and files
  secretPlaceholders = publicSecretPlaceholders ++ privateMcp.secretPlaceholders;
  secretFiles = publicSecretFiles // privateMcp.secretFiles;

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
          // lib.optionalAttrs (server ? oauth) { inherit (server) oauth; }
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

  # Transform to OpenCode format (JSON with type/command array)
  toOpenCode =
    serverNames:
    lib.filterAttrs (n: _: builtins.elem n serverNames) (
      lib.mapAttrs (
        name: server:
        if server.transport == "http" then
          {
            type = "remote";
            url = server.url;
            enabled = true;
          }
          // lib.optionalAttrs (server ? headers) { inherit (server) headers; }
        else
          {
            type = "local";
            command = [ server.command ] ++ (server.args or [ ]);
            enabled = true;
          }
          // lib.optionalAttrs (server ? env) { environment = server.env; }
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
      }) (builtins.filter (p: lib.hasAttr p secretFiles) secretPlaceholders)
    );

  # Generate secret substitutions mapping for activation scripts
  # secretsDir: directory where secrets are placed
  mkSecretSubstitutions =
    secretsDir:
    lib.listToAttrs (
      map (placeholder: {
        name = placeholder;
        value = "${secretsDir}/${placeholderToPathName placeholder}";
      }) (builtins.filter (p: lib.hasAttr p secretFiles) secretPlaceholders)
    );

  # Generate MCP config JSON for a specific list of servers
  # Used for account-specific configurations
  mkMcpConfig =
    serverNames:
    builtins.toJSON {
      mcpServers = toClaudeCode serverNames;
      claudeInChromeDefaultEnabled = true;
      hasCompletedClaudeInChromeOnboarding = true;
    };

  # Generate activation script for secret substitution
  # Used by claude-code, codex-cli, and gemini-cli
  # Requires pkgs to be passed when importing this module
  # configPath: path to the config file to modify (e.g., ~/.codex/config.toml)
  # secretsDir: directory where secrets are placed
  mkActivationScript =
    {
      configPath,
      secretsDir,
    }:
    assert pkgs != null;
    let
      subs = mkSecretSubstitutions secretsDir;
    in
    ''
      run mkdir -p ${secretsDir}

      # Remove existing config if it exists
      run rm -f ${configPath}

      # Copy template to working file
      run cp ${configPath}.template ${configPath}

      # Substitute each @PLACEHOLDER@ with its decrypted secret value
      ${lib.concatMapStrings (
        ph:
        let
          secretPath = subs.${ph};
        in
        ''
          if [ -f "${secretPath}" ]; then
            run ${lib.getExe pkgs.gnused} -i "s|${ph}|$(cat ${secretPath})|g" ${configPath}
          fi
        ''
      ) (lib.attrNames subs)}

      # Restrict permissions - config contains API keys
      run chmod 600 ${configPath}
    '';
}
