"""ClickUp REST API client."""

from datetime import datetime, timezone
from typing import Optional

import requests

try:
    from .models import ClickUpTask
except ImportError:
    from models import ClickUpTask


class ClickUpAPIError(Exception):
    """Error from ClickUp API."""


class ClickUpAPI:
    """Client for ClickUp REST API v2."""

    BASE_URL = "https://api.clickup.com/api/v2"

    def __init__(self, token: str):
        """
        Initialize API client.

        Args:
            token: OAuth access token
        """
        self.token = token
        self.session = requests.Session()
        # ClickUp OAuth requires "Bearer" prefix
        auth_header = token if token.startswith("Bearer ") else f"Bearer {token}"
        self.session.headers.update(
            {
                "Authorization": auth_header,
                "Content-Type": "application/json",
            }
        )

    def _request(
        self,
        method: str,
        endpoint: str,
        params: Optional[dict] = None,
        json_data: Optional[dict] = None,
    ) -> dict:
        """Make an API request."""
        url = f"{self.BASE_URL}{endpoint}"
        response = self.session.request(
            method, url, params=params, json=json_data
        )

        if not response.ok:
            try:
                error = response.json()
                msg = error.get("err", response.text)
            except Exception:
                msg = response.text
            raise ClickUpAPIError(
                f"ClickUp API error ({response.status_code}): {msg}"
            )

        return response.json()

    def get_tasks(self, list_id: str, page: int = 0) -> list[ClickUpTask]:
        """
        Get tasks from a list.

        Args:
            list_id: ClickUp list ID
            page: Page number (0-indexed, 100 tasks per page)

        Returns:
            List of ClickUpTask objects
        """
        data = self._request(
            "GET",
            f"/list/{list_id}/task",
            params={"page": page, "include_closed": "true"},
        )
        return [self._parse_task(t) for t in data.get("tasks", [])]

    def get_all_tasks(
        self, list_id: str, full_details: bool = False  # noqa: ARG002
    ) -> list[ClickUpTask]:
        """
        Get all tasks from a list (handles pagination).

        Args:
            list_id: ClickUp list ID
            full_details: Ignored (REST API always returns full details)

        Returns:
            List of all ClickUpTask objects
        """
        all_tasks: list[ClickUpTask] = []
        page = 0

        while True:
            tasks = self.get_tasks(list_id, page)
            if not tasks:
                break
            all_tasks.extend(tasks)
            page += 1
            # Safety limit
            if page > 100:
                break

        return all_tasks

    def get_task(self, task_id: str) -> ClickUpTask:
        """
        Get a single task by ID.

        Args:
            task_id: ClickUp task ID

        Returns:
            ClickUpTask object
        """
        data = self._request("GET", f"/task/{task_id}")
        return self._parse_task(data)

    def create_task(
        self,
        list_id: str,
        name: str,
        description: Optional[str] = None,
        priority: Optional[int] = None,
        tags: Optional[list[str]] = None,
    ) -> str:
        """
        Create a new task.

        Args:
            list_id: ClickUp list ID
            name: Task name
            description: Task description
            priority: Priority (1=urgent, 2=high, 3=normal, 4=low)
            tags: List of tag names

        Returns:
            New task ID
        """
        payload: dict = {"name": name}
        if description:
            payload["description"] = description
        if priority is not None:
            payload["priority"] = priority
        if tags:
            payload["tags"] = tags

        data = self._request("POST", f"/list/{list_id}/task", json_data=payload)
        return data["id"]

    def update_task(
        self,
        task_id: str,
        name: Optional[str] = None,
        description: Optional[str] = None,
        status: Optional[str] = None,
        priority: Optional[int] = None,
    ) -> None:
        """
        Update an existing task.

        Args:
            task_id: ClickUp task ID
            name: New task name
            description: New description
            status: New status name
            priority: New priority
        """
        payload: dict = {}
        if name is not None:
            payload["name"] = name
        if description is not None:
            payload["description"] = description
        if status is not None:
            payload["status"] = status
        if priority is not None:
            payload["priority"] = priority

        if payload:
            self._request("PUT", f"/task/{task_id}", json_data=payload)

    def delete_task(self, task_id: str) -> None:
        """
        Delete/archive a task by setting status to Closed.

        Note: We don't truly delete, just close the task.

        Args:
            task_id: ClickUp task ID
        """
        self._request("PUT", f"/task/{task_id}", json_data={"status": "Closed"})

    def get_comments(self, task_id: str) -> list[dict]:
        """
        Get comments on a task.

        Args:
            task_id: ClickUp task ID

        Returns:
            List of comment dictionaries
        """
        data = self._request("GET", f"/task/{task_id}/comment")
        return data.get("comments", [])

    def create_comment(self, task_id: str, comment_text: str) -> str:
        """
        Add a comment to a task.

        Args:
            task_id: ClickUp task ID
            comment_text: Comment text

        Returns:
            New comment ID
        """
        data = self._request(
            "POST",
            f"/task/{task_id}/comment",
            json_data={"comment_text": comment_text},
        )
        return data["id"]

    def _parse_task(self, data: dict) -> ClickUpTask:
        """Parse API response into ClickUpTask."""
        # date_updated is in Unix milliseconds
        date_updated_ms = int(data.get("date_updated") or 0)
        date_updated = datetime.fromtimestamp(
            date_updated_ms / 1000, tz=timezone.utc
        )

        # Priority can be null or an object with "id" field
        priority_data = data.get("priority")
        priority: Optional[int] = None
        if priority_data and isinstance(priority_data, dict):
            priority = int(priority_data.get("id", 0)) or None

        # Status is an object with "status" field
        status_data = data.get("status", {})
        status = (
            status_data.get("status", "").lower() if status_data else ""
        )

        # Tags are a list of objects with "name" field
        tags = [t.get("name", "") for t in data.get("tags", [])]

        return ClickUpTask(
            id=data["id"],
            name=data.get("name", ""),
            description=data.get("description"),
            status=status,
            priority=priority,
            date_updated=date_updated,
            tags=tags,
        )
