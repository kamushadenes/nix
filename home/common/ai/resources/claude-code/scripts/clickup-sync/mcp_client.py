"""MCP (Model Context Protocol) client for ClickUp."""

from datetime import datetime, timezone
from typing import Any, Optional

import requests

try:
    from .models import ClickUpTask
except ImportError:
    from models import ClickUpTask


# Priority mapping: numeric (1-4) -> string for MCP tool
PRIORITY_NUM_TO_STR = {
    1: "urgent",
    2: "high",
    3: "normal",
    4: "low",
}


class MCPError(Exception):
    """Error from MCP server."""


class ClickUpMCPClient:
    """Client for ClickUp MCP server using JSON-RPC 2.0 over HTTP."""

    MCP_URL = "https://mcp.clickup.com/mcp"

    def __init__(self, oauth_token: str):
        """
        Initialize MCP client.

        Args:
            oauth_token: OAuth access token from Claude Code keychain
        """
        self.oauth_token = oauth_token
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {oauth_token}",
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
            }
        )
        self._request_id = 0

    def _call(self, method: str, params: Optional[dict] = None) -> Any:
        """
        Make an MCP JSON-RPC call.

        Args:
            method: MCP method name (e.g., "tools/call")
            params: Method parameters

        Returns:
            Result from MCP server

        Raises:
            MCPError: If MCP call fails
        """
        import json as json_module

        self._request_id += 1
        payload = {
            "jsonrpc": "2.0",
            "id": self._request_id,
            "method": method,
            "params": params or {},
        }

        response = self.session.post(self.MCP_URL, json=payload, stream=True)

        if response.status_code == 401:
            raise MCPError(
                "Authentication failed. OAuth token may be expired. "
                "Re-authenticate ClickUp MCP in Claude Code."
            )

        if not response.ok:
            raise MCPError(f"MCP request failed ({response.status_code}): {response.text}")

        content_type = response.headers.get("Content-Type", "")

        # Handle SSE response
        if "text/event-stream" in content_type:
            return self._parse_sse_response(response)

        # Handle plain JSON response
        try:
            data = response.json()
        except Exception as e:
            raise MCPError(f"Invalid JSON response: {e}") from e

        if "error" in data:
            error = data["error"]
            raise MCPError(f"MCP error: {error.get('message', error)}")

        return data.get("result")

    def _parse_sse_response(self, response: requests.Response) -> Any:
        """
        Parse an SSE (Server-Sent Events) response.

        Args:
            response: The streaming response

        Returns:
            The final result from the SSE stream
        """
        import json as json_module

        result = None
        for line in response.iter_lines(decode_unicode=True):
            if not line:
                continue

            # SSE format: "data: {...json...}"
            if line.startswith("data: "):
                data_str = line[6:]  # Remove "data: " prefix
                try:
                    data = json_module.loads(data_str)
                except json_module.JSONDecodeError:
                    continue

                # Check for error
                if "error" in data:
                    error = data["error"]
                    raise MCPError(f"MCP error: {error.get('message', error)}")

                # Store result (may be updated by subsequent messages)
                if "result" in data:
                    result = data["result"]

            # SSE event type
            elif line.startswith("event: "):
                event_type = line[7:]
                # Could handle different event types here if needed

        return result

    def _call_tool(self, tool_name: str, arguments: dict) -> Any:
        """
        Call an MCP tool.

        Args:
            tool_name: Name of the tool (e.g., "clickup_search")
            arguments: Tool arguments

        Returns:
            Tool result
        """
        result = self._call(
            "tools/call",
            {"name": tool_name, "arguments": arguments},
        )
        # MCP tools return content array, extract first text content
        if isinstance(result, dict) and "content" in result:
            content = result["content"]
            if isinstance(content, list) and content:
                first = content[0]
                if isinstance(first, dict) and first.get("type") == "text":
                    import json
                    try:
                        return json.loads(first.get("text", "{}"))
                    except json.JSONDecodeError:
                        return first.get("text")
        return result

    def list_tools(self) -> list[dict]:
        """List available MCP tools."""
        result = self._call("tools/list")
        return result.get("tools", []) if isinstance(result, dict) else []

    def get_tasks(self, list_id: str) -> list[ClickUpTask]:
        """
        Get tasks from a ClickUp list.

        Args:
            list_id: ClickUp list ID

        Returns:
            List of ClickUpTask objects
        """
        result = self._call_tool("clickup_search", {"list_id": list_id})
        # MCP clickup_search returns {"overview": ..., "results": [...], "next_cursor": ...}
        tasks = result.get("results", []) if isinstance(result, dict) else []
        return [self._parse_task(t) for t in tasks]

    def get_all_tasks(self, list_id: str, full_details: bool = True) -> list[ClickUpTask]:
        """
        Get all tasks from a ClickUp list.

        Args:
            list_id: ClickUp list ID
            full_details: If True, fetch full details for each task (slower but complete)

        Returns:
            List of all ClickUpTask objects
        """
        # Get basic task list from search
        result = self._call_tool("clickup_search", {"list_id": list_id})
        search_tasks = result.get("results", []) if isinstance(result, dict) else []

        if not full_details:
            # Return basic search results
            return [self._parse_task(t) for t in search_tasks]

        # Fetch full details for each task
        full_tasks: list[ClickUpTask] = []
        for t in search_tasks:
            task_id = t.get("id")
            if task_id:
                try:
                    full_task = self.get_task(task_id)
                    full_tasks.append(full_task)
                except MCPError:
                    # Fall back to search data if get_task fails
                    full_tasks.append(self._parse_task(t))

        return full_tasks

    def get_task(self, task_id: str) -> ClickUpTask:
        """
        Get a single task by ID.

        Args:
            task_id: ClickUp task ID

        Returns:
            ClickUpTask object
        """
        result = self._call_tool("clickup_get_task", {"task_id": task_id})
        return self._parse_task(result)

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
        args: dict[str, Any] = {"list_id": list_id, "name": name}
        if description:
            args["description"] = description
        if priority is not None:
            # Convert numeric priority to string for MCP tool
            priority_str = PRIORITY_NUM_TO_STR.get(priority)
            if priority_str:
                args["priority"] = priority_str
        if tags:
            args["tags"] = tags

        result = self._call_tool("clickup_create_task", args)
        # Debug: print the raw result to understand the format
        import sys
        print(f"DEBUG create_task result: {result}", file=sys.stderr)
        # Handle various response formats from ClickUp MCP
        if isinstance(result, dict):
            # Try 'id' first, then 'task_id', then nested 'task.id'
            task_id = result.get("id") or result.get("task_id")
            if not task_id and "task" in result:
                task_id = result["task"].get("id") if isinstance(result["task"], dict) else None
            return task_id or ""
        return str(result) if result else ""

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
        args: dict[str, Any] = {"task_id": task_id}
        if name is not None:
            args["name"] = name
        if description is not None:
            args["description"] = description
        if status is not None:
            args["status"] = status
        if priority is not None:
            # Convert numeric priority to string for MCP tool
            priority_str = PRIORITY_NUM_TO_STR.get(priority)
            if priority_str:
                args["priority"] = priority_str

        if len(args) > 1:  # More than just task_id
            self._call_tool("clickup_update_task", args)

    def get_comments(self, task_id: str) -> list[dict]:
        """
        Get comments on a task.

        Args:
            task_id: ClickUp task ID

        Returns:
            List of comment dictionaries
        """
        result = self._call_tool("clickup_get_task_comments", {"task_id": task_id})
        return result.get("comments", []) if isinstance(result, dict) else []

    def create_comment(self, task_id: str, comment_text: str) -> str:
        """
        Add a comment to a task.

        Args:
            task_id: ClickUp task ID
            comment_text: Comment text

        Returns:
            New comment ID
        """
        result = self._call_tool(
            "clickup_create_task_comment",
            {"task_id": task_id, "comment_text": comment_text},
        )
        return result.get("id", "") if isinstance(result, dict) else str(result)

    def _parse_task(self, data: dict) -> ClickUpTask:
        """Parse MCP response into ClickUpTask.

        Handles both:
        - Search results (simplified: dateUpdated, status as string)
        - Full task (REST-like: date_updated, status as object)
        """
        # date_updated can be "date_updated" or "dateUpdated", Unix ms or ISO string
        date_updated_raw = data.get("date_updated") or data.get("dateUpdated")
        if isinstance(date_updated_raw, (int, float)):
            date_updated = datetime.fromtimestamp(date_updated_raw / 1000, tz=timezone.utc)
        elif isinstance(date_updated_raw, str):
            try:
                # Try Unix ms string first
                date_updated = datetime.fromtimestamp(
                    int(date_updated_raw) / 1000, tz=timezone.utc
                )
            except ValueError:
                # Try ISO format
                date_updated = datetime.fromisoformat(
                    date_updated_raw.replace("Z", "+00:00")
                )
        else:
            date_updated = datetime.now(timezone.utc)

        # Priority handling (full task only - search results don't include priority)
        priority_data = data.get("priority")
        priority: Optional[int] = None
        if priority_data:
            if isinstance(priority_data, dict):
                priority = int(priority_data.get("id", 0)) or None
            elif isinstance(priority_data, (int, str)):
                priority = int(priority_data) or None

        # Status handling - can be string (search) or object (full task)
        status_data = data.get("status", "")
        if isinstance(status_data, dict):
            status = status_data.get("status", "").lower()
        else:
            status = str(status_data).lower()

        # Tags handling (full task only)
        tags_data = data.get("tags", [])
        tags = [t.get("name", "") if isinstance(t, dict) else str(t) for t in tags_data]

        # Description (full task only)
        description = data.get("description")

        return ClickUpTask(
            id=data.get("id", ""),
            name=data.get("name", ""),
            description=description,
            status=status,
            priority=priority,
            date_updated=date_updated,
            tags=tags,
        )
