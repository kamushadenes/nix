"""Data models for ClickUp sync."""

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class BeadStatus(Enum):
    """Bead status values."""

    OPEN = "open"
    IN_PROGRESS = "in_progress"
    BLOCKED = "blocked"
    CLOSED = "closed"


@dataclass
class Bead:
    """Local bead issue."""

    id: str
    title: str
    status: BeadStatus
    priority: int  # 0-4 (0=critical, 4=backlog)
    created_at: datetime
    updated_at: datetime
    description: Optional[str] = None
    external_ref: Optional[str] = None
    labels: list[str] = field(default_factory=list)
    close_reason: Optional[str] = None
    issue_type: str = "task"


@dataclass
class ClickUpTask:
    """ClickUp task from API."""

    id: str
    name: str
    status: str  # Raw status name from ClickUp
    date_updated: datetime
    description: Optional[str] = None
    priority: Optional[int] = None  # 1=urgent, 2=high, 3=normal, 4=low
    tags: list[str] = field(default_factory=list)


@dataclass
class SyncConfig:
    """Configuration from .beads/clickup.yaml."""

    list_id: str
    list_name: str
    space_id: str
    account: str  # Account name for token lookup
    space_name: Optional[str] = None
    last_sync: Optional[datetime] = None


@dataclass
class SyncResult:
    """Results from a sync operation."""

    pulled_created: int = 0
    pulled_updated: int = 0
    pulled_skipped: int = 0
    pushed_created: int = 0
    pushed_updated: int = 0
    pushed_skipped: int = 0
    errors: list[str] = field(default_factory=list)

    def __str__(self) -> str:
        return (
            f"Pulled: {self.pulled_created} created, "
            f"{self.pulled_updated} updated, "
            f"{self.pulled_skipped} skipped\n"
            f"Pushed: {self.pushed_created} created, "
            f"{self.pushed_updated} updated, "
            f"{self.pushed_skipped} skipped"
        )
