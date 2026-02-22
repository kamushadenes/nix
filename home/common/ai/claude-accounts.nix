# Claude Code Multi-Account Configuration
#
# Defines accounts with their matching patterns and MCP server lists.
# Accounts are matched by git remote URL (primary) or path prefix (fallback).
#
# Pattern matching priority:
# 1. Git remote URL regex match
# 2. Path prefix match (if git remote doesn't match)
# 3. Default (no CLAUDE_CONFIG_DIR set)
{ config, lib }:
let
  homeDir = config.home.homeDirectory;
in
rec {
  #############################################################################
  # Account Definitions
  #############################################################################

  accounts = {
    # Iniciador - Payment initiation platform
    iniciador = {
      # Git remote patterns (regex, case-sensitive)
      gitRemotePatterns = [
        "github\\.com[:/]Iniciador-de-Pagamentos/"
      ];
      # Path prefixes (literal match, expands ~)
      pathPrefixes = [
        "${homeDir}/Dropbox/Projects/Iniciador"
      ];
      # Additional MCP servers for this account (beyond common)
      mcpServers = [
        "iniciador-clickup"
        "iniciador-slack"
      ];
    };
  };

  #############################################################################
  # Common MCP Servers (all accounts get these)
  #############################################################################

  commonMcpServers = [
    "deepwiki"
    "github"
    "Ref"
    "orchestrator"
    "iniciador-vanta"
  ];

  #############################################################################
  # Helper Functions
  #############################################################################

  # Get all MCP servers for an account (common + account-specific)
  getAccountMcps = accountName:
    commonMcpServers ++ accounts.${accountName}.mcpServers;

  # Get all account names
  accountNames = lib.attrNames accounts;

  # Generate bash pattern variables for an account
  # Output: ACCOUNT_PATTERNS_<name>_GIT="pattern1|pattern2"
  #         ACCOUNT_PATTERNS_<name>_PATH="prefix1:prefix2"
  mkAccountPatternVars = name:
    let
      account = accounts.${name};
      gitPatterns = lib.concatStringsSep "|" account.gitRemotePatterns;
      pathPrefixes = lib.concatStringsSep ":" account.pathPrefixes;
    in
    ''
      ACCOUNT_PATTERNS_${name}_GIT="${gitPatterns}"
      ACCOUNT_PATTERNS_${name}_PATH="${pathPrefixes}"
    '';

  # Generate all account pattern variables
  allAccountPatternVars = lib.concatMapStringsSep "\n" mkAccountPatternVars accountNames;

  # Generate bash detection logic for an account
  mkAccountDetectionCase = name: ''
    # ${name}
    if [ -n "$git_remote" ]; then
        if echo "$git_remote" | grep -qE "$ACCOUNT_PATTERNS_${name}_GIT"; then
            echo "${name}"
            return 0
        fi
    fi
    IFS=':' read -ra paths <<< "$ACCOUNT_PATTERNS_${name}_PATH"
    for prefix in "''${paths[@]}"; do
        if [[ "$target_dir" == "$prefix"* ]]; then
            echo "${name}"
            return 0
        fi
    done
  '';

  # Generate all account detection logic
  allAccountDetectionLogic = lib.concatMapStringsSep "\n" mkAccountDetectionCase accountNames;
}
