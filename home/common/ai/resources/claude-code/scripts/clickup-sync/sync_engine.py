"""Core sync engine for bidirectional ClickUp-Beads synchronization."""

from pathlib import Path

try:
    from .beads_client import BeadsClient
    from .clickup_api import ClickUpAPI
    from .models import Bead, BeadStatus, ClickUpTask, SyncConfig, SyncResult
    from .sync_state import (
        compute_bead_hash,
        compute_task_hash,
        load_sync_state,
        save_sync_state,
        should_sync,
        update_sync_state,
    )
except ImportError:
    from beads_client import BeadsClient
    from clickup_api import ClickUpAPI
    from models import Bead, BeadStatus, ClickUpTask, SyncConfig, SyncResult
    from sync_state import (
        compute_bead_hash,
        compute_task_hash,
        load_sync_state,
        save_sync_state,
        should_sync,
        update_sync_state,
    )

# Status mapping: Beads -> ClickUp
# NOTE: These are common ClickUp status names. If your list uses different
# status names (e.g., "backlog", "done"), update these mappings accordingly.
# The sync will skip status updates for statuses that don't exist in the list.
STATUS_BEAD_TO_CLICKUP = {
    BeadStatus.OPEN: "to do",
    BeadStatus.IN_PROGRESS: "in progress",
    BeadStatus.BLOCKED: "on hold",
    BeadStatus.CLOSED: "closed",
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


class SyncEngine:
    """Bidirectional sync engine for ClickUp and Beads."""

    def __init__(
        self,
        api: ClickUpAPI,
        beads: BeadsClient,
        config: SyncConfig,
        verbose: bool = False,
        beads_dir: Path = Path(".beads"),
    ):
        """
        Initialize sync engine.

        Args:
            api: ClickUp REST API client
            beads: Beads CLI client
            config: Sync configuration
            verbose: Enable verbose output
            beads_dir: Path to .beads directory
        """
        self.api = api
        self.beads = beads
        self.config = config
        self.verbose = verbose
        self.beads_dir = beads_dir
        self.sync_state = load_sync_state(beads_dir)

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

        # Save sync state
        save_sync_state(self.sync_state, self.beads_dir)

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
                    # Create new bead (first-time import from ClickUp)
                    bead_id = self._create_bead_from_task(task)
                    self.log(f"[PULL: New] Created bead {bead_id} from ClickUp task: {task.name}")
                    result.pulled_created += 1

                    # Record sync state for new bead
                    task_hash = compute_task_hash(task)
                    update_sync_state(
                        self.sync_state, bead_id, task_hash, task_hash
                    )
                else:
                    # Use hash-based sync decision
                    do_sync, direction = should_sync(
                        existing_bead, task, self.sync_state
                    )

                    if do_sync and direction == "pull":
                        self._update_bead_from_task(existing_bead, task)
                        self.log(f"[PULL: Update] Updated bead {existing_bead.id}: {task.name}")
                        result.pulled_updated += 1

                        # Update sync state
                        bead_hash = compute_task_hash(task)  # After update, bead matches task
                        task_hash = compute_task_hash(task)
                        update_sync_state(
                            self.sync_state, existing_bead.id, bead_hash, task_hash
                        )
                    else:
                        self.log(f"[PULL: Skip] No change or push pending: {task.name}")
                        result.pulled_skipped += 1

            except Exception as e:
                error = f"Pull error for task {task.id}: {e}"
                self.log(f"ERROR: {error}")
                result.errors.append(error)

    def _push(self, result: SyncResult) -> None:
        """Push beads to ClickUp."""
        all_beads = self.beads.list_issues(include_closed=True)
        self.log(f"Processing {len(all_beads)} beads for push")

        # Detect potential duplicates by title
        beads_by_title: dict[str, list[Bead]] = {}
        for bead in all_beads:
            title_normalized = bead.title.strip().lower()
            if title_normalized not in beads_by_title:
                beads_by_title[title_normalized] = []
            beads_by_title[title_normalized].append(bead)

        duplicates = {title: beads for title, beads in beads_by_title.items() if len(beads) > 1}
        if duplicates:
            self.log("⚠️  Warning: Potential duplicate beads detected (same title):")
            for title, beads in duplicates.items():
                bead_ids = ", ".join(b.id for b in beads)
                self.log(f"   '{title}': {bead_ids}")

        for bead in all_beads:
            try:
                if bead.external_ref and bead.external_ref.startswith(
                    "clickup-"
                ):
                    # Existing link - use hash-based sync decision
                    task_id = bead.external_ref[8:]
                    task = self.api.get_task(task_id)

                    do_sync, direction = should_sync(bead, task, self.sync_state)

                    if do_sync and direction == "push":
                        self._update_task_from_bead(task_id, bead)
                        self.log(f"[PUSH: Update] Updated ClickUp task {task_id}: {bead.title}")
                        result.pushed_updated += 1

                        # Post close_reason as comment if closed
                        if (
                            bead.status == BeadStatus.CLOSED
                            and bead.close_reason
                        ):
                            self._post_close_reason(task_id, bead.close_reason)

                        # Update sync state
                        bead_hash = compute_bead_hash(bead)
                        update_sync_state(
                            self.sync_state, bead.id, bead_hash, bead_hash
                        )
                    else:
                        self.log(f"[PUSH: Skip] No change or pull pending: {bead.title}")
                        result.pushed_skipped += 1

                else:
                    # No external ref - create in ClickUp (first-time link)
                    task_id = self._create_task_from_bead(bead)
                    self.log(f"[PUSH: Link] Created ClickUp task {task_id} from bead {bead.id}: {bead.title}")

                    # Update bead with external ref
                    self.beads.update_issue(
                        bead.id, external_ref=f"clickup-{task_id}"
                    )
                    result.pushed_created += 1

                    # Record sync state for new task
                    bead_hash = compute_bead_hash(bead)
                    update_sync_state(
                        self.sync_state, bead.id, bead_hash, bead_hash
                    )

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

        # Try to update status if not open (may fail if status doesn't exist)
        status = STATUS_BEAD_TO_CLICKUP.get(bead.status)
        if status and bead.status != BeadStatus.OPEN:
            try:
                self.api.update_task(task_id, status=status)
            except Exception as e:
                self.log(f"  Warning: Could not set status to '{status}': {e}")

        return task_id

    def _update_task_from_bead(self, task_id: str, bead: Bead) -> None:
        """Update an existing ClickUp task from a bead."""
        priority = PRIORITY_BEAD_TO_CLICKUP.get(bead.priority, 3)

        # First update name, description, priority (these always work)
        self.api.update_task(
            task_id,
            name=bead.title,
            description=bead.description,
            priority=priority,
        )

        # Try to update status separately - may fail if status doesn't exist in list
        status = STATUS_BEAD_TO_CLICKUP.get(bead.status)
        if status:
            try:
                self.api.update_task(task_id, status=status)
            except Exception as e:
                # Status update failed - likely status doesn't exist in this list
                self.log(f"  Warning: Could not update status to '{status}': {e}")

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
