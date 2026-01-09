"""macOS Keychain integration for retrieving ClickUp OAuth token."""

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Optional


class KeychainError(Exception):
    """Error retrieving credentials from keychain."""


def get_claude_config_dir() -> Path:
    """Get the Claude config directory, respecting CLAUDE_CONFIG_DIR."""
    env_dir = os.environ.get("CLAUDE_CONFIG_DIR")
    if env_dir:
        return Path(env_dir)
    return Path.home() / ".claude"


def get_account_name() -> Optional[str]:
    """
    Extract account name from CLAUDE_CONFIG_DIR.

    If CLAUDE_CONFIG_DIR is ~/.claude/accounts/iniciador, returns "iniciador".
    If not set or not an account-specific dir, returns None.
    """
    config_dir = get_claude_config_dir()
    config_str = str(config_dir)

    # Check if this is an account-specific directory
    if "/accounts/" in config_str:
        # Extract account name (last component after /accounts/)
        match = re.search(r"/accounts/([^/]+)/?$", config_str)
        if match:
            return match.group(1)

    return None


def _list_credential_services() -> list[str]:
    """List all Claude Code credential service names from keychain."""
    result = subprocess.run(
        ["security", "dump-keychain"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise KeychainError(f"Failed to dump keychain: {result.stderr}")

    # Find all Claude Code-credentials entries
    services = []
    for line in result.stdout.splitlines():
        if '"svce"<blob>="Claude Code-credentials' in line:
            # Extract service name
            match = re.search(r'"svce"<blob>="([^"]+)"', line)
            if match:
                services.append(match.group(1))

    return list(set(services))  # Deduplicate


def _get_keychain_entry(service: str) -> Optional[dict]:
    """Read a keychain entry by service name."""
    result = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-w"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None

    try:
        return json.loads(result.stdout.strip())
    except json.JSONDecodeError:
        return None


def _find_clickup_token_for_account(
    data: dict, account: Optional[str]
) -> Optional[str]:
    """
    Extract ClickUp access token from keychain data.

    If account is provided, looks for '<account>-clickup' MCP server first.
    Otherwise searches all clickup entries.
    """
    mcp_oauth = data.get("mcpOAuth", {})

    # If we have an account name, look for that specific MCP server first
    if account:
        expected_prefix = f"{account}-clickup"
        for key, value in mcp_oauth.items():
            # Key format is like "iniciador-clickup|3e12002ef2b26de4"
            if key.lower().startswith(expected_prefix):
                token = value.get("accessToken")
                if token:
                    return token

    # Fallback: search any clickup entry
    for key, value in mcp_oauth.items():
        if "clickup" in key.lower():
            token = value.get("accessToken")
            if token:
                return token

    return None


def get_clickup_token() -> str:
    """
    Retrieve ClickUp OAuth token from macOS keychain.

    Uses the account name from CLAUDE_CONFIG_DIR to find the correct
    MCP server entry (e.g., 'iniciador-clickup' for the iniciador account).

    Returns:
        str: The OAuth access token

    Raises:
        KeychainError: If token cannot be retrieved
    """
    account = get_account_name()
    services = _list_credential_services()

    if not services:
        raise KeychainError("No Claude Code credentials found in keychain")

    # Sort services so account-specific ones come first
    # (services with hash suffix before the generic one)
    services.sort(key=lambda s: (s == "Claude Code-credentials", s))

    # Try each credential entry
    for service in services:
        data = _get_keychain_entry(service)
        if data:
            token = _find_clickup_token_for_account(data, account)
            if token:
                return token

    # Build helpful error message
    if account:
        raise KeychainError(
            f"No ClickUp OAuth token found for account '{account}'. "
            f"Expected MCP server: '{account}-clickup'. "
            "Ensure ClickUp MCP is authenticated via Claude Code."
        )
    else:
        raise KeychainError(
            "No ClickUp OAuth token found in keychain. "
            "Ensure ClickUp MCP is authenticated via Claude Code."
        )
