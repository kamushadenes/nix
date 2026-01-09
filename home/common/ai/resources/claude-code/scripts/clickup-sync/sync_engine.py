"""Core sync engine for bidirectional ClickUp-Beads synchronization."""

from datetime import datetime, timezone

try:
    from .beads_client import BeadsClient
    from .mcp_client import ClickUpMCPClient
    from .models import Bead, BeadStatus, ClickUpTask, SyncConfig, SyncResult
except ImportError:
    from beads_client import BeadsClient
    from mcp_client import ClickUpMCPClient
    from models import Bead, BeadStatus, ClickUpTask, SyncConfig, SyncResult

# Status mapping: Beads -> ClickUp
STATUS_BEAD_TO_CLICKUP = {
    BeadStatus.OPEN: "open",
    BeadStatus.IN_PROGRESS: "in progress",
    BeadStatus.BLOCKED: "blocked",
    BeadStatus.CLOSED: "complete",
}

# Status mapping: ClickUp -> Beads (case-insensitive)
STATUS_CLICKUP_TO_BEAD = {
    "to do": BeadStatus.OPEN,
    "open": BeadStatus.OPEN,
    "backlog": BeadStatus.OPEN,
    "in progress": BeadStatus.IN_PROGRESS,
    "doing": BeadStatus.IN_PROGRESS,
    "blocked": BeadStatus.BLOCKED,
    "on hold": BeadStatus.BLOCKED,
    "complete": BeadStatus.CLOSED,
    "done": BeadStatus.CLOSED,
    "closed": BeadStatus.CLOSED,
}

# Priority mapping: Beads (0-4) -> ClickUp (1-4 or None)
PRIORITY_BEAD_TO_CLICKUP = {
    0: 1,  # Critical -> Urgent
    1: 2,  # High -> High
    2: 3,  # Medium -> Normal
    3: 4,  # Low -> Low
    4: None,  # Backlog -> No priority
}

# Priority mapping: ClickUp (1-4 or None) -> Beads (0-4)
PRIORITY_CLICKUP_TO_BEAD = {
    1: 0,  # Urgent -> Critical
    2: 1,  # High -> High
    3: 2,  # Normal -> Medium
    4: 3,  # Low -> Low
    None: 4,  # No priority -> Backlog
}


def compare_timestamps(
    ts1: datetime,
    ts2: datetime,
    tolerance_seconds: float = 1.0,
) -> str:
    """
    Compare two timestamps.

    Args:
        ts1: First timestamp
        ts2: Second timestamp
        tolerance_seconds: Tolerance for "equal" comparison

    Returns:
        "first" if ts1 is newer
        "second" if ts2 is newer
        "equal" if within tolerance
    """
    # Ensure both are timezone-aware (assume UTC if naive)
    if ts1.tzinfo is None:
        ts1 = ts1.replace(tzinfo=timezone.utc)
    if ts2.tzinfo is None:
        ts2 = ts2.replace(tzinfo=timezone.utc)

    diff = (ts1 - ts2).total_seconds()

    if abs(diff) < tolerance_seconds:
        return "equal"
    elif diff > 0:
        return "first"
    else:
        return "second"


class SyncEngine:
    """Bidirectional sync engine for ClickUp and Beads."""

    def __init__(
        self,
        api: ClickUpMCPClient,
        beads: BeadsClient,
        config: SyncConfig,
        verbose: bool = False,
    ):
        """
        Initialize sync engine.

        Args:
            api: ClickUp MCP client
            beads: Beads CLI client
            config: Sync configuration
            verbose: Enable verbose output
        """
        self.api = api
        self.beads = beads
        self.config = config
        self.verbose = verbose

    def log(self, msg: str) -> None:
        """Log a message if verbose mode is enabled."""
        if self.verbose:
            print(f"  {msg}")

    def sync(self) -> SyncResult:
        """
        Run full bidirectional sync.

        Phase 1 (PULL): ClickUp -> Beads
        Phase 2 (PUSH): Beads -> ClickUp

        Returns:
            SyncResult with counts and errors
        """
        result = SyncResult()

        # Phase 1: PULL
        self.log("=== PULL Phase (ClickUp -> Beads) ===")
        self._pull(result)

        # Phase 2: PUSH
        self.log("=== PUSH Phase (Beads -> ClickUp) ===")
        self._push(result)

        return result

    def _pull(self, result: SyncResult) -> None:
        """Pull tasks from ClickUp to beads."""
        # Get all ClickUp tasks
        clickup_tasks = self.api.get_all_tasks(self.config.list_id)
        self.log(f"Fetched {len(clickup_tasks)} tasks from ClickUp")

        # Get all beads with external refs
        all_beads = self.beads.list_issues(include_closed=True)
        bead_by_clickup_id: dict[str, Bead] = {}

        for b in all_beads:
            if b.external_ref and b.external_ref.startswith("clickup-"):
                clickup_id = b.external_ref[8:]  # Remove "clickup-" prefix
                bead_by_clickup_id[clickup_id] = b

        self.log(f"Found {len(bead_by_clickup_id)} beads with ClickUp refs")

        for task in clickup_tasks:
            try:
                existing_bead = bead_by_clickup_id.get(task.id)

                if existing_bead is None:
                    # Create new bead
                    self._create_bead_from_task(task)
                    self.log(f"Created bead for task: {task.name}")
                    result.pulled_created += 1
                else:
                    # Compare timestamps
                    cmp = compare_timestamps(
                        task.date_updated, existing_bead.updated_at
                    )

                    if cmp == "first":  # ClickUp is newer
                        self._update_bead_from_task(existing_bead, task)
                        self.log(f"Updated bead {existing_bead.id}: {task.name}")
                        result.pulled_updated += 1
                    else:  # Bead is newer or equal
                        self.log(f"Skipped (local newer): {task.name}")
                        result.pulled_skipped += 1

            except Exception as e:
                error = f"Pull error for task {task.id}: {e}"
                self.log(f"ERROR: {error}")
                result.errors.append(error)

    def _push(self, result: SyncResult) -> None:
        """Push beads to ClickUp."""
        all_beads = self.beads.list_issues(include_closed=True)
        self.log(f"Processing {len(all_beads)} beads for push")

        for bead in all_beads:
            try:
                if bead.external_ref and bead.external_ref.startswith(
                    "clickup-"
                ):
                    # Existing link - check if bead is newer
                    task_id = bead.external_ref[8:]
                    task = self.api.get_task(task_id)

                    cmp = compare_timestamps(bead.updated_at, task.date_updated)

                    if cmp == "first":  # Bead is newer
                        self._update_task_from_bead(task_id, bead)
                        self.log(f"Updated ClickUp task: {bead.title}")
                        result.pushed_updated += 1

                        # Post close_reason as comment if closed
                        if (
                            bead.status == BeadStatus.CLOSED
                            and bead.close_reason
                        ):
                            self._post_close_reason(task_id, bead.close_reason)
                    else:
                        self.log(f"Skipped (remote newer): {bead.title}")
                        result.pushed_skipped += 1

                else:
                    # No external ref - create in ClickUp
                    task_id = self._create_task_from_bead(bead)
                    self.log(f"Created ClickUp task: {bead.title}")

                    # Update bead with external ref
                    self.beads.update_issue(
                        bead.id, external_ref=f"clickup-{task_id}"
                    )
                    result.pushed_created += 1

            except Exception as e:
                error = f"Push error for bead {bead.id}: {e}"
                self.log(f"ERROR: {error}")
                result.errors.append(error)

    def _create_bead_from_task(self, task: ClickUpTask) -> str:
        """Create a new bead from a ClickUp task."""
        status = STATUS_CLICKUP_TO_BEAD.get(task.status.lower(), BeadStatus.OPEN)
        priority = PRIORITY_CLICKUP_TO_BEAD.get(task.priority, 2)

        # Determine issue type from tags
        issue_type = "task"
        for tag in task.tags:
            tag_lower = tag.lower()
            if tag_lower in ("bug", "feature", "epic"):
                issue_type = tag_lower
                break

        bead_id = self.beads.create_issue(
            title=task.name,
            description=task.description,
            priority=priority,
            external_ref=f"clickup-{task.id}",
            labels=task.tags,
            issue_type=issue_type,
        )

        # If task is closed, close the bead
        if status == BeadStatus.CLOSED:
            self.beads.close_issue(bead_id)
        elif status == BeadStatus.IN_PROGRESS:
            self.beads.update_issue(bead_id, status="in_progress")
        elif status == BeadStatus.BLOCKED:
            self.beads.update_issue(bead_id, status="blocked")

        return bead_id

    def _update_bead_from_task(self, bead: Bead, task: ClickUpTask) -> None:
        """Update an existing bead from a ClickUp task."""
        status = STATUS_CLICKUP_TO_BEAD.get(task.status.lower(), BeadStatus.OPEN)
        priority = PRIORITY_CLICKUP_TO_BEAD.get(task.priority, 2)

        # Update basic fields
        self.beads.update_issue(
            bead.id,
            title=task.name,
            description=task.description,
            priority=priority,
        )

        # Handle status change
        if status == BeadStatus.CLOSED and bead.status != BeadStatus.CLOSED:
            self.beads.close_issue(bead.id)
        elif status != BeadStatus.CLOSED and bead.status == BeadStatus.CLOSED:
            # Reopen - update status
            self.beads.update_issue(bead.id, status=status.value)
        elif status != bead.status:
            self.beads.update_issue(bead.id, status=status.value)

    def _create_task_from_bead(self, bead: Bead) -> str:
        """Create a new ClickUp task from a bead."""
        priority = PRIORITY_BEAD_TO_CLICKUP.get(bead.priority, 3)

        task_id = self.api.create_task(
            self.config.list_id,
            name=bead.title,
            description=bead.description,
            priority=priority,
            tags=bead.labels if bead.labels else None,
        )

        # If bead is closed, update task status
        if bead.status == BeadStatus.CLOSED:
            self.api.update_task(task_id, status="complete")
        elif bead.status == BeadStatus.IN_PROGRESS:
            self.api.update_task(task_id, status="in progress")

        return task_id

    def _update_task_from_bead(self, task_id: str, bead: Bead) -> None:
        """Update an existing ClickUp task from a bead."""
        status = STATUS_BEAD_TO_CLICKUP.get(bead.status, "open")
        priority = PRIORITY_BEAD_TO_CLICKUP.get(bead.priority, 3)

        self.api.update_task(
            task_id,
            name=bead.title,
            description=bead.description,
            status=status,
            priority=priority,
        )

    def _post_close_reason(self, task_id: str, reason: str) -> None:
        """Post close reason as a comment on ClickUp task."""
        # Check if we already posted this reason
        comments = self.api.get_comments(task_id)
        prefix = "[Closed]"

        for comment in comments:
            comment_text = comment.get("comment_text", "")
            if comment_text.startswith(prefix) and reason in comment_text:
                # Already posted
                return

        self.api.create_comment(task_id, f"{prefix} {reason}")
