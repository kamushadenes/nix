"""Beads (bd) CLI wrapper."""

import json
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional, Union

try:
    from .models import Bead, BeadStatus
except ImportError:
    from models import Bead, BeadStatus


class BeadsError(Exception):
    """Error from bd CLI."""


class BeadsClient:
    """Client for bd CLI operations."""

    def __init__(self, cwd: Union[str, Path] = "."):
        """
        Initialize client.

        Args:
            cwd: Working directory for bd commands
        """
        self.cwd = str(cwd)

    def _run(
        self,
        *args: str,
        capture_json: bool = True,
    ) -> Union[dict, list, str]:
        """
        Run bd command and return output.

        Args:
            *args: Command arguments
            capture_json: Whether to parse output as JSON

        Returns:
            Parsed JSON or raw output string

        Raises:
            BeadsError: If command fails
        """
        cmd = ["bd", *args]
        if capture_json:
            cmd.append("--json")

        result = subprocess.run(
            cmd,
            cwd=self.cwd,
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            error_msg = result.stderr or result.stdout
            raise BeadsError(f"bd {' '.join(args)} failed: {error_msg}")

        if capture_json:
            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError as e:
                raise BeadsError(f"Invalid JSON from bd: {e}") from e

        return result.stdout.strip()

    def list_issues(
        self,
        status: Optional[str] = None,
        include_closed: bool = False,
    ) -> list[Bead]:
        """
        List issues matching criteria.

        Args:
            status: Filter by status (open, in_progress, closed)
            include_closed: Include closed issues

        Returns:
            List of Bead objects
        """
        args = ["list", "--limit", "0"]  # 0 = unlimited
        if status:
            args.extend(["--status", status])
        elif include_closed:
            args.append("--all")

        data = self._run(*args)
        if isinstance(data, list):
            return [self._parse_bead(d) for d in data]
        return []

    def get_issue(self, issue_id: str) -> Bead:
        """
        Get a single issue by ID.

        Args:
            issue_id: Bead issue ID

        Returns:
            Bead object

        Raises:
            BeadsError: If issue not found
        """
        data = self._run("show", issue_id)
        if isinstance(data, dict):
            return self._parse_bead(data)
        if isinstance(data, list) and data:
            return self._parse_bead(data[0])
        raise BeadsError(f"Issue not found: {issue_id}")

    def create_issue(
        self,
        title: str,
        description: Optional[str] = None,
        priority: int = 2,
        external_ref: Optional[str] = None,
        labels: Optional[list[str]] = None,
        issue_type: str = "task",
    ) -> str:
        """
        Create a new issue.

        Args:
            title: Issue title
            description: Issue description
            priority: Priority (0-4)
            external_ref: External reference
            labels: List of labels
            issue_type: Issue type (task, bug, feature)

        Returns:
            New issue ID
        """
        args = [
            "create",
            "--title",
            title,
            "--priority",
            str(priority),
            "--type",
            issue_type,
        ]

        if description:
            args.extend(["--description", description])
        if external_ref:
            args.extend(["--external-ref", external_ref])
        if labels:
            args.extend(["--labels", ",".join(labels)])

        # Run without JSON, parse ID from output
        result = subprocess.run(
            ["bd", *args],
            cwd=self.cwd,
            capture_output=True,
            text=True,
        )

        if result.returncode != 0:
            raise BeadsError(f"bd create failed: {result.stderr}")

        # Extract ID from output (format: "Created issue <id>")
        output = result.stdout.strip()
        for line in output.splitlines():
            if line.startswith("Created"):
                # Extract ID - last word or bracketed ID
                parts = line.split()
                if parts:
                    return parts[-1].strip("[]")

        # Try parsing as JSON if available
        try:
            data = json.loads(output)
            if isinstance(data, dict) and "id" in data:
                return data["id"]
        except json.JSONDecodeError:
            pass

        # Return the raw output as fallback
        return output.split()[-1] if output else ""

    def update_issue(
        self,
        issue_id: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        status: Optional[str] = None,
        priority: Optional[int] = None,
        external_ref: Optional[str] = None,
    ) -> None:
        """
        Update an existing issue.

        Args:
            issue_id: Issue ID
            title: New title
            description: New description
            status: New status
            priority: New priority
            external_ref: New external reference
        """
        args = ["update", issue_id]

        if title:
            args.extend(["--title", title])
        if description:
            args.extend(["--description", description])
        if status:
            args.extend(["--status", status])
        if priority is not None:
            args.extend(["--priority", str(priority)])
        if external_ref:
            args.extend(["--external-ref", external_ref])

        if len(args) > 2:  # Only run if we have updates
            self._run(*args, capture_json=False)

    def close_issue(
        self, issue_id: str, reason: Optional[str] = None
    ) -> None:
        """
        Close an issue.

        Args:
            issue_id: Issue ID
            reason: Close reason
        """
        args = ["close", issue_id]
        if reason:
            args.extend(["--reason", reason])

        self._run(*args, capture_json=False)

    def get_comments(self, issue_id: str) -> list[dict]:
        """
        Get comments on an issue.

        Args:
            issue_id: Issue ID

        Returns:
            List of comment dictionaries
        """
        data = self._run("comments", issue_id)
        if isinstance(data, list):
            return data
        return []

    def add_comment(self, issue_id: str, text: str) -> None:
        """
        Add a comment to an issue.

        Args:
            issue_id: Issue ID
            text: Comment text
        """
        self._run("comments", "add", issue_id, text, capture_json=False)

    def _parse_bead(self, data: dict) -> Bead:
        """Parse bd JSON output into Bead."""

        def parse_dt(s: str) -> datetime:
            """Parse ISO 8601 datetime string."""
            return datetime.fromisoformat(s.replace("Z", "+00:00"))

        # Handle status
        status_str = data.get("status", "open")
        try:
            status = BeadStatus(status_str)
        except ValueError:
            status = BeadStatus.OPEN

        return Bead(
            id=data["id"],
            title=data.get("title", ""),
            description=data.get("description"),
            status=status,
            priority=int(data.get("priority", 2)),
            external_ref=data.get("external_ref"),
            created_at=parse_dt(data["created_at"]),
            updated_at=parse_dt(data["updated_at"]),
            labels=data.get("labels", []),
            close_reason=data.get("close_reason"),
            issue_type=data.get("issue_type", "task"),
        )
