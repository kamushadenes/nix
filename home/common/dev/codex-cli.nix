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

      # PAL - Multi-model AI assistant with clink for CLI orchestration
      pal = {
        command = "uvx";
        args = [
          "--from"
          "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
          "pal-mcp-server"
        ];
        tool_timeout_sec = 1200;
        env = {
          OPENROUTER_API_KEY = "@OPENROUTER_API_KEY@";
          # Match PAL defaults - disable heavy context tools
          DISABLED_TOOLS = "analyze,refactor,testgen,secaudit,docgen,tracer";
          # Use high thinking mode for thinkdeep tool (better deep analysis)
          DEFAULT_THINKING_MODE_THINKDEEP = "high";
        };
      };

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
    "@OPENROUTER_API_KEY@" = "${config.home.homeDirectory}/.codex/secrets/openrouter-api-key";
    "@TFE_TOKEN@" = "${config.home.homeDirectory}/.codex/secrets/tfe-token";
  };
  # Wrapper script for codex review with live colorized output
  # Usage: codex-review [codex-args...] <output-file>
  # Last argument is the output file, all others are passed to codex exec
  # Shows real-time progress with colors, saves final message to file
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
  ];

  #############################################################################
  # Agenix Secrets
  #############################################################################

  age.secrets = {
    "codex-ref-api-key" = {
      file = "${private}/home/common/dev/resources/claude/ref-api-key.age";
      path = "${config.home.homeDirectory}/.codex/secrets/ref-api-key";
    };
    "codex-openrouter-api-key" = {
      file = "${private}/home/common/dev/resources/claude/openrouter-api-key.age";
      path = "${config.home.homeDirectory}/.codex/secrets/openrouter-api-key";
    };
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
    ".codex/config.toml.template".source =
      mcpConfigToml.generate "codex-config-template.toml" mcpConfig;
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

    # Restrict permissions - config contains API keys
    run chmod 600 ${config.home.homeDirectory}/.codex/config.toml
  '';
}
