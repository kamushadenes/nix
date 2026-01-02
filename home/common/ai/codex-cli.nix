# OpenAI Codex CLI configuration
#
# Configures Codex CLI with MCP servers from shared configuration.
# Uses agenix for secrets management with TOML config file.
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

  # MCP servers to include for Codex CLI
  enabledServers = [
    "deepwiki"
    "Ref"
    "repomix"
    "godoc"
    "terraform"
    "orchestrator"
  ];

  # MCP server configurations in Codex format
  mcpConfig = {
    mcp_servers = mcpServers.toCodex enabledServers;
    features = {
      web_search_request = true;
    };
  };

  # Convert to TOML format
  mcpConfigToml = pkgs.formats.toml { };

  # Secrets configuration
  secretsDir = "${config.home.homeDirectory}/.codex/secrets";
  secretSubstitutions = mcpServers.mkSecretSubstitutions secretsDir;

  # Wrapper script for codex review with live colorized output
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

  age.secrets = mcpServers.mkAgenixSecrets {
    prefix = "codex";
    secretsDir = secretsDir;
    inherit private;
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
    run mkdir -p ${secretsDir}

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
