"""Configuration handling for .beads/clickup.yaml."""

from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

import yaml

try:
    from .models import SyncConfig
except ImportError:
    from models import SyncConfig


class ConfigError(Exception):
    """Configuration error."""


def load_config(beads_dir: Path = Path(".beads")) -> SyncConfig:
    """
    Load ClickUp sync configuration from .beads/clickup.yaml.

    Args:
        beads_dir: Path to .beads directory

    Returns:
        SyncConfig with linked list information

    Raises:
        ConfigError: If config file doesn't exist or is invalid
    """
    config_path = beads_dir / "clickup.yaml"

    if not config_path.exists():
        raise ConfigError(
            f"ClickUp not linked. Config file not found: {config_path}\n"
            "Run the setup wizard first to link a ClickUp list."
        )

    with open(config_path) as f:
        data = yaml.safe_load(f)

    if not data:
        raise ConfigError(f"Empty config file: {config_path}")

    linked_list = data.get("linked_list", {})
    if not linked_list.get("list_id"):
        raise ConfigError("Invalid config: missing list_id")

    account = data.get("account")
    if not account:
        raise ConfigError(
            "Invalid config: missing account.\n"
            "Add 'account: <name>' to .beads/clickup.yaml"
        )

    last_sync: Optional[datetime] = None
    if data.get("last_sync"):
        try:
            last_sync = datetime.fromisoformat(
                data["last_sync"].replace("Z", "+00:00")
            )
        except (ValueError, AttributeError):
            pass  # Ignore invalid timestamps

    return SyncConfig(
        list_id=linked_list["list_id"],
        list_name=linked_list.get("list_name", ""),
        space_id=linked_list.get("space_id", ""),
        account=account,
        space_name=linked_list.get("space_name"),
        last_sync=last_sync,
    )


def save_config(config: SyncConfig, beads_dir: Path = Path(".beads")) -> None:
    """
    Save configuration with updated last_sync timestamp.

    Args:
        config: SyncConfig to save
        beads_dir: Path to .beads directory
    """
    config_path = beads_dir / "clickup.yaml"

    data = {
        "account": config.account,
        "linked_list": {
            "list_id": config.list_id,
            "list_name": config.list_name,
            "space_id": config.space_id,
        },
        "last_sync": datetime.now(timezone.utc).isoformat(),
    }

    if config.space_name:
        data["linked_list"]["space_name"] = config.space_name

    with open(config_path, "w") as f:
        yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False)
