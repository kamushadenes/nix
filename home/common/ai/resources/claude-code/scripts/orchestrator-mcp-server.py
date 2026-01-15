#!/usr/bin/env python3
"""
MCP server for terminal automation and AI orchestration.

Provides:
- tmux_* tools for terminal window management
- ai_* tools for parallel AI CLI orchestration
"""
import subprocess
import hashlib
import time
import os
import json
import re
import uuid
import asyncio
import threading
import shlex
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any, Literal
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("orchestrator")

# =============================================================================
# Conditional Tool Registration
# =============================================================================

# Check if running inside tmux at module load time
IN_TMUX = bool(os.environ.get("TMUX"))


def tmux_tool():
    """Decorator that only registers tool if running inside tmux.

    When not in tmux, the function is still defined but not exposed as an MCP tool.
    This prevents cluttering the tool list with unavailable tools.
    """
    if IN_TMUX:
        return mcp.tool()
    else:
        # Return identity decorator - function exists but isn't registered as MCP tool
        return lambda f: f


# =============================================================================
# Response Models (Pydantic for MCP structured output)
# =============================================================================


class AICallResult(BaseModel):
    """Response from ai_call (synchronous AI CLI invocation)."""
    status: Literal["success", "error"] = Field(description="Operation status")
    cli: str | None = Field(default=None, description="CLI that was called")
    content: str | None = Field(default=None, description="AI response content")
    error: str | None = Field(default=None, description="Error message if failed")
    metadata: dict[str, Any] = Field(default_factory=dict, description="CLI-specific metadata")


class AISpawnResult(BaseModel):
    """Response from ai_spawn (async job creation)."""
    status: Literal["spawned", "error"] = Field(description="Operation status")
    job_id: str | None = Field(default=None, description="Job ID for use with ai_fetch")
    cli: str | None = Field(default=None, description="CLI being used")
    error: str | None = Field(default=None, description="Error message if failed")
    message: str | None = Field(default=None, description="Human-readable status message")


class AIFetchResult(BaseModel):
    """Response from ai_fetch (retrieve async job result)."""
    status: Literal["completed", "failed", "timeout", "running", "not_found"] = Field(
        description="Job status"
    )
    job_id: str = Field(description="Job ID that was queried")
    cli: str | None = Field(default=None, description="CLI that ran the job")
    content: str | None = Field(default=None, description="AI response if completed")
    error: str | None = Field(default=None, description="Error message if failed")
    message: str | None = Field(default=None, description="Status message")
    metadata: dict[str, Any] = Field(default_factory=dict, description="CLI-specific metadata")


class AIJobInfo(BaseModel):
    """Information about a single AI job."""
    job_id: str = Field(description="Unique job identifier")
    cli: str = Field(description="CLI being used")
    status: str = Field(description="Job status")
    created_at: str = Field(description="ISO timestamp when job was created")
    completed_at: str | None = Field(default=None, description="ISO timestamp when job completed")


class AIListResult(BaseModel):
    """Response from ai_list (list all jobs)."""
    jobs: list[AIJobInfo] = Field(default_factory=list, description="List of all tracked jobs")
    total: int = Field(description="Total number of jobs")
    running: int = Field(description="Number of currently running jobs")


class AIReviewJobStatus(BaseModel):
    """Status of a single CLI in ai_review."""
    status: Literal["spawned", "error"] = Field(description="Spawn status")
    job_id: str | None = Field(default=None, description="Job ID if spawned")
    error: str | None = Field(default=None, description="Error if failed to spawn")


class AIReviewResult(BaseModel):
    """Response from ai_review (spawn all CLIs)."""
    status: Literal["spawned", "partial", "error"] = Field(description="Overall status")
    jobs: dict[str, AIReviewJobStatus] = Field(description="Status for each CLI")
    message: str = Field(description="Human-readable instructions")


class TmuxWindow(BaseModel):
    """Information about a tmux window."""
    id: str = Field(description="Window ID (e.g., @3)")
    index: str = Field(description="Window index")
    name: str = Field(description="Window name")
    active: bool = Field(description="Whether window is active")
    command: str = Field(description="Current command running")
    is_claude: bool = Field(description="Whether this is Claude's window")


class TmuxListResult(BaseModel):
    """Response from tmux_list."""
    windows: list[TmuxWindow] = Field(description="List of windows")
    current_window: str = Field(description="ID of current window")


# =============================================================================
# Task Worker Response Models
# =============================================================================


class CompletedSubtask(BaseModel):
    """A subtask that has been completed by a worker."""
    id: str = Field(description="Subtask ID (e.g., '5.1')")
    commit: str = Field(description="Commit SHA for this subtask")
    notes: str = Field(description="Notes about what was done")


class TaskWorkerStatus(BaseModel):
    """Status data from a worker's .orchestrator/task_status file."""
    status: Literal["working", "completed", "failed", "stuck"] = Field(
        description="Current worker status"
    )
    heartbeat: str | None = Field(default=None, description="ISO timestamp of last heartbeat")
    current_subtask: str | None = Field(default=None, description="Current subtask ID being worked on")
    progress: str | None = Field(default=None, description="Human-readable progress description")
    completed_subtasks: list[CompletedSubtask] = Field(
        default_factory=list, description="List of completed subtasks with commits"
    )
    commits: list[str] = Field(default_factory=list, description="All commit SHAs made")
    final_commit: str | None = Field(default=None, description="Final commit SHA")
    pr_url: str | None = Field(default=None, description="PR URL")
    pr_number: int | None = Field(default=None, description="PR number")
    merged: bool | None = Field(default=None, description="Whether PR was auto-merged")
    error: str | None = Field(default=None, description="Error message if failed/stuck")
    notes: str | None = Field(default=None, description="Final summary notes")


class ResultCommit(BaseModel):
    """A commit in the task result."""
    sha: str = Field(description="Commit SHA")
    message: str = Field(description="Commit message")


class ResultPR(BaseModel):
    """PR info in the task result."""
    url: str = Field(description="PR URL")
    number: int = Field(description="PR number")
    merged: bool = Field(default=False, description="Whether PR was merged")


class TaskWorkerResult(BaseModel):
    """Final result data from a worker's .orchestrator/task_result file."""
    task_id: str = Field(description="Task ID that was worked on")
    title: str = Field(description="Task title")
    status: Literal["completed", "failed", "stuck"] = Field(description="Final status")
    summary: str = Field(description="Brief summary of what was accomplished")
    actions: list[str] = Field(default_factory=list, description="List of actions taken")
    files_changed: list[str] = Field(default_factory=list, description="Files that were modified")
    commits: list[ResultCommit] = Field(default_factory=list, description="Commits made")
    pr: ResultPR | None = Field(default=None, description="PR info if created")
    error: str | None = Field(default=None, description="Error message if failed")
    duration_estimate: str | None = Field(default=None, description="Estimated duration")


class TaskWorker(BaseModel):
    """Information about a task worker Claude instance."""
    worker_id: str = Field(description="Unique worker identifier")
    task_id: str = Field(description="Task ID being worked on")
    worktree_path: str = Field(description="Path to the git worktree")
    window_id: str = Field(description="Tmux window ID")
    auto_merge: bool = Field(default=False, description="Whether to auto-merge PR")
    status: Literal["starting", "working", "completed", "failed", "stuck"] = Field(
        description="Current worker status"
    )
    created_at: str = Field(description="ISO timestamp when worker was created")
    completed_at: str | None = Field(default=None, description="ISO timestamp when worker completed")
    error: str | None = Field(default=None, description="Error message if failed")
    retry_count: int = Field(default=0, description="Number of retry attempts")


class TaskWorkerSpawnResult(BaseModel):
    """Response from task_worker_spawn."""
    status: Literal["spawned", "error"] = Field(description="Operation status")
    worker_id: str | None = Field(default=None, description="Worker ID for tracking")
    window_id: str | None = Field(default=None, description="Tmux window ID")
    error: str | None = Field(default=None, description="Error message if failed")


class TaskWorkerStatusResult(BaseModel):
    """Response from task_worker_status."""
    status: Literal["starting", "working", "completed", "failed", "stuck", "not_found", "window_closed"] = Field(
        description="Worker status"
    )
    worker_id: str = Field(description="Worker ID that was queried")
    task_id: str | None = Field(default=None, description="Task ID being worked on")
    worktree_path: str | None = Field(default=None, description="Path to worktree")
    status_data: TaskWorkerStatus | None = Field(default=None, description="Parsed .task_status file")
    result_data: TaskWorkerResult | None = Field(default=None, description="Parsed .task_result file (on completion)")
    error: str | None = Field(default=None, description="Error message")


class TaskWorkerListResult(BaseModel):
    """Response from task_worker_list."""
    workers: list[TaskWorker] = Field(default_factory=list, description="List of all tracked workers")
    total: int = Field(description="Total number of workers")
    active: int = Field(description="Number of active workers")


# =============================================================================
# Configuration
# =============================================================================

VALID_SHELLS = {"zsh", "bash", "fish", "sh"}
DEFAULT_SHELL = "zsh"
MAX_CAPTURE_LINES = 10000
MIN_CAPTURE_LINES = 1

# Pattern for valid tmux window/pane identifiers (e.g., @3, %5)
TARGET_PATTERN = re.compile(r'^[@%][0-9]+$')

# =============================================================================
# AI Agent Configuration
# =============================================================================

MAX_CONCURRENT_JOBS = 10
JOB_CLEANUP_HOURS = 1
DEFAULT_AI_TIMEOUT = 300

AI_CLIS = {
    "claude": {
        "command": ["claude", "--print", "--output-format", "json"],
        "parser": "claude_json",
        "timeout": 300,
    },
    "codex": {
        # Flags from clink: exec for non-interactive, --json for JSONL output,
        # --dangerously-bypass-approvals-and-sandbox for automated execution
        "command": [
            "codex", "exec", "--json",
            "--dangerously-bypass-approvals-and-sandbox",
        ],
        "parser": "codex_jsonl",
        "timeout": 300,
    },
    "gemini": {
        "command": ["gemini", "-o", "json"],
        "parser": "gemini_json",
        "timeout": 300,
    },
}


@dataclass
class AIJob:
    """Represents an async AI CLI job."""
    id: str
    cli: str
    prompt: str
    files: list[str]
    status: str  # "running", "completed", "failed", "timeout"
    timeout: int
    result: str | None = None
    error: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    completed_at: datetime | None = None


AI_JOBS: dict[str, AIJob] = {}
AI_JOBS_LOCK = threading.Lock()


# =============================================================================
# Task Worker Configuration
# =============================================================================

MAX_TASK_WORKERS = 5
ORCHESTRATOR_DIR = ".orchestrator"
TASK_STATUS_FILE = f"{ORCHESTRATOR_DIR}/task_status"
TASK_RESULT_FILE = f"{ORCHESTRATOR_DIR}/task_result"
CURRENT_TASK_FILE = f"{ORCHESTRATOR_DIR}/current_task.md"
WORKER_CLEANUP_HOURS = 24


@dataclass
class TaskWorkerData:
    """Internal tracking data for a task worker."""
    worker_id: str
    task_id: str
    worktree_path: str
    window_id: str
    auto_merge: bool
    status: str  # "starting", "working", "completed", "failed", "stuck"
    created_at: datetime
    completed_at: datetime | None = None
    error: str | None = None
    retry_count: int = 0
    task_data: dict[str, Any] = field(default_factory=dict)  # Full task JSON


TASK_WORKERS: dict[str, TaskWorkerData] = {}
TASK_WORKERS_LOCK = threading.Lock()


# =============================================================================
# AI Parsers (ported from clink)
# =============================================================================


class ParserError(RuntimeError):
    """Raised when CLI output cannot be parsed."""
    pass


@dataclass
class ParsedResponse:
    """Result of parsing CLI output."""
    content: str
    metadata: dict[str, Any]


def parse_claude_json(stdout: str, stderr: str) -> ParsedResponse:
    """Parse claude --output-format json output."""
    if not stdout.strip():
        raise ParserError("Claude CLI returned empty stdout")

    try:
        loaded = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise ParserError(f"Failed to decode Claude JSON: {exc}") from exc

    metadata: dict[str, Any] = {"raw": loaded}

    # Handle array of events or single result
    if isinstance(loaded, list):
        events = [item for item in loaded if isinstance(item, dict)]
        result_entry = next(
            (item for item in events if item.get("type") == "result" or "result" in item),
            None,
        )
        assistant_entry = next(
            (item for item in reversed(events) if item.get("type") == "assistant"),
            None,
        )
        payload = result_entry or assistant_entry or (events[-1] if events else {})
        metadata["raw_events"] = events
    elif isinstance(loaded, dict):
        payload = loaded
    else:
        raise ParserError("Unexpected Claude JSON structure")

    # Extract content
    result = payload.get("result")
    if isinstance(result, str) and result.strip():
        return ParsedResponse(content=result.strip(), metadata=metadata)
    if isinstance(result, list):
        joined = [p.strip() for p in result if isinstance(p, str) and p.strip()]
        if joined:
            return ParsedResponse(content="\n".join(joined), metadata=metadata)

    # Try message field
    message = payload.get("message")
    if isinstance(message, str) and message.strip():
        return ParsedResponse(content=message.strip(), metadata=metadata)

    # Check error
    error = payload.get("error", {})
    if isinstance(error, dict):
        err_msg = error.get("message")
        if isinstance(err_msg, str) and err_msg.strip():
            return ParsedResponse(content=err_msg.strip(), metadata=metadata)

    if stderr.strip():
        metadata["stderr"] = stderr.strip()
        return ParsedResponse(
            content="Claude CLI returned no textual result. Check stderr.",
            metadata=metadata
        )

    raise ParserError("Claude response did not contain textual result")


def parse_codex_jsonl(stdout: str, stderr: str) -> ParsedResponse:
    """Parse codex exec JSONL output."""
    lines = [line.strip() for line in (stdout or "").splitlines() if line.strip()]
    events: list[dict[str, Any]] = []
    agent_messages: list[str] = []
    errors: list[str] = []
    usage: dict[str, Any] | None = None

    for line in lines:
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        events.append(event)
        event_type = event.get("type")
        if event_type == "item.completed":
            item = event.get("item") or {}
            if item.get("type") == "agent_message":
                text = item.get("text")
                if isinstance(text, str) and text.strip():
                    agent_messages.append(text.strip())
        elif event_type == "error":
            message = event.get("message")
            if isinstance(message, str) and message.strip():
                errors.append(message.strip())
        elif event_type == "turn.completed":
            turn_usage = event.get("usage")
            if isinstance(turn_usage, dict):
                usage = turn_usage

    if not agent_messages and errors:
        agent_messages.extend(errors)

    if not agent_messages:
        raise ParserError("Codex JSONL output did not include agent_message")

    content = "\n\n".join(agent_messages).strip()
    metadata: dict[str, Any] = {"events_count": len(events)}
    if errors:
        metadata["errors"] = errors
    if usage:
        metadata["usage"] = usage
    if stderr and stderr.strip():
        metadata["stderr"] = stderr.strip()

    return ParsedResponse(content=content, metadata=metadata)


def parse_gemini_json(stdout: str, stderr: str) -> ParsedResponse:
    """Parse gemini -o json output."""
    if not stdout.strip():
        raise ParserError("Gemini CLI returned empty stdout")

    try:
        payload: dict[str, Any] = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise ParserError(f"Failed to decode Gemini JSON: {exc}") from exc

    metadata: dict[str, Any] = {"raw": payload}

    response = payload.get("response")
    if isinstance(response, str) and response.strip():
        # Extract stats
        stats = payload.get("stats")
        if isinstance(stats, dict):
            metadata["stats"] = stats
            models = stats.get("models")
            if isinstance(models, dict) and models:
                model_name = next(iter(models.keys()))
                metadata["model_used"] = model_name

        if stderr and stderr.strip():
            metadata["stderr"] = stderr.strip()
        return ParsedResponse(content=response.strip(), metadata=metadata)

    # Fallback for empty response
    if stderr and stderr.strip():
        metadata["stderr"] = stderr.strip()
        if "429" in stderr.lower() or "rate limit" in stderr.lower():
            return ParsedResponse(
                content="Gemini rate limited (429). Retry later.",
                metadata=metadata
            )
        return ParsedResponse(
            content="Gemini returned no response. Check stderr.",
            metadata=metadata
        )

    raise ParserError("Gemini response missing 'response' field")


def get_parser(parser_name: str):
    """Get parser function by name."""
    parsers = {
        "claude_json": parse_claude_json,
        "codex_jsonl": parse_codex_jsonl,
        "gemini_json": parse_gemini_json,
    }
    return parsers.get(parser_name)


# =============================================================================
# AI Helpers
# =============================================================================


def _build_ai_prompt(prompt: str, files: list[str]) -> str:
    """Build full prompt with embedded file contents."""
    sections = [prompt]
    if files:
        file_refs = []
        for path in files:
            try:
                content = Path(path).read_text(encoding="utf-8", errors="replace")
                file_refs.append(f"=== {path} ===\n{content}")
            except Exception as e:
                file_refs.append(f"=== {path} ===\n[Error reading: {e}]")
        if file_refs:
            sections.append("=== FILE CONTEXT ===\n" + "\n\n".join(file_refs))
    return "\n\n".join(sections)


async def _run_ai_cli(
    command: list[str],
    prompt: str,
    timeout: int,
    parser_name: str
) -> ParsedResponse:
    """Execute AI CLI and parse output."""
    proc = await asyncio.create_subprocess_exec(
        *command,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    try:
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(prompt.encode("utf-8")),
            timeout=timeout
        )
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise RuntimeError(f"CLI timed out after {timeout}s")

    stdout_text = stdout_bytes.decode("utf-8", errors="replace")
    stderr_text = stderr_bytes.decode("utf-8", errors="replace")

    parser = get_parser(parser_name)
    if parser:
        result = parser(stdout_text, stderr_text)
    else:
        result = ParsedResponse(
            content=stdout_text,
            metadata={"stderr": stderr_text, "parser": "raw"}
        )

    # Always include exit code and success status in metadata
    result.metadata["exit_code"] = proc.returncode
    result.metadata["success"] = proc.returncode == 0

    # Include stderr in metadata if not already present and there was an error
    if proc.returncode != 0 and "stderr" not in result.metadata:
        result.metadata["stderr"] = stderr_text

    return result


async def _run_ai_job_async(job_id: str):
    """Background task to run AI CLI job."""
    with AI_JOBS_LOCK:
        job = AI_JOBS.get(job_id)
        if not job:
            return
        cli_config = AI_CLIS.get(job.cli)
        if not cli_config:
            job.status = "failed"
            job.error = f"Unknown CLI: {job.cli}"
            job.completed_at = datetime.now(timezone.utc)
            return

    full_prompt = _build_ai_prompt(job.prompt, job.files)

    try:
        result = await _run_ai_cli(
            command=cli_config["command"],
            prompt=full_prompt,
            timeout=job.timeout,
            parser_name=cli_config["parser"]
        )
        with AI_JOBS_LOCK:
            job.status = "completed"
            job.result = result.content
            job.metadata = result.metadata
            job.completed_at = datetime.now(timezone.utc)
    except asyncio.TimeoutError:
        with AI_JOBS_LOCK:
            job.status = "timeout"
            job.error = f"CLI timed out after {job.timeout}s"
            job.completed_at = datetime.now(timezone.utc)
    except Exception as e:
        with AI_JOBS_LOCK:
            job.status = "failed"
            job.error = str(e)
            job.completed_at = datetime.now(timezone.utc)


def _cleanup_old_ai_jobs():
    """Remove jobs older than JOB_CLEANUP_HOURS (must hold lock)."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=JOB_CLEANUP_HOURS)
    to_remove = [
        jid for jid, job in AI_JOBS.items()
        if job.created_at < cutoff and job.status != "running"
    ]
    for jid in to_remove:
        del AI_JOBS[jid]


# =============================================================================
# tmux Helpers
# =============================================================================


def run_tmux(*args) -> tuple[str, int]:
    """Run a tmux command and return (stdout, returncode)"""
    result = subprocess.run(
        ["tmux"] + list(args),
        capture_output=True,
        text=True
    )
    return result.stdout.strip(), result.returncode


def get_current_window() -> str:
    """Get the window ID where Claude Code is running"""
    output, _ = run_tmux("display-message", "-p", "#{window_id}")
    return output


def require_tmux():
    """Raise error if not running inside tmux"""
    if not os.environ.get("TMUX"):
        raise RuntimeError(
            "tmux MCP tools require running inside a tmux session. "
            "Please restart Claude using the 'c' command."
        )


def is_shell_command(command: str) -> bool:
    """Check if command is a shell"""
    base_cmd = os.path.basename(command.split()[0])
    return base_cmd in VALID_SHELLS


def validate_target(target: str) -> None:
    """Validate that target is a safe tmux window/pane identifier.

    Raises:
        ValueError: If target doesn't match the expected pattern
    """
    if not TARGET_PATTERN.match(target):
        raise ValueError(
            f"Invalid target '{target}'. Expected format: @<number> or %<number> "
            "(e.g., '@3' for window, '%5' for pane)"
        )


# =============================================================================
# tmux Tools
# =============================================================================


@tmux_tool()
def tmux_new_window(
    command: str = "zsh",
    name: str = ""
) -> str:
    """
    Create a new tmux window and run a command in it.

    Args:
        command: Command to run in the new window (default: zsh)
        name: Optional name for the window (shown in status bar)

    Returns:
        Window ID (e.g., "@3") that persists until the window is killed
    """
    require_tmux()

    # Check if command is a shell - if not, wrap it in a shell
    needs_shell_wrap = not is_shell_command(command)
    actual_command = DEFAULT_SHELL if needs_shell_wrap else command

    # Create new window, return window ID
    # -d flag keeps focus on current window (don't switch to new one)
    args = ["new-window", "-d", "-P", "-F", "#{window_id}"]
    if name:
        args.extend(["-n", name])
    args.append(actual_command)

    output, code = run_tmux(*args)

    if code != 0:
        return f"Error creating window: {output}"

    window_id = output

    # If we wrapped, wait for shell to be ready then send the original command
    if needs_shell_wrap:
        # Use a unique marker to reliably detect when shell is ready
        # This avoids race conditions with prompt character detection
        marker = f"READY_{uuid.uuid4().hex}"

        # Send echo command to output the marker when shell is ready
        run_tmux("send-keys", "-t", window_id, f"echo {marker}", "Enter")

        # Wait for the marker to appear in output (up to 5 seconds)
        shell_ready = False
        for _ in range(50):
            time.sleep(0.1)
            content, _ = run_tmux("capture-pane", "-t", window_id, "-p")
            if marker in content:
                shell_ready = True
                break

        if not shell_ready:
            return f"Window created ({window_id}) but shell did not become ready in time"

        # Now send the actual command
        _, send_code = run_tmux("send-keys", "-t", window_id, command, "Enter")
        if send_code != 0:
            return f"Window created ({window_id}) but failed to send command"

    return window_id


@tmux_tool()
def tmux_send(target: str, text: str, enter: bool = True) -> str:
    """
    Send text/keystrokes to a tmux window.

    Args:
        target: Window identifier - use ID from tmux_new_window (e.g., "@3")
        text: Text to send
        enter: Whether to press Enter after the text

    Returns:
        Success message or error
    """
    require_tmux()
    validate_target(target)
    args = ["send-keys", "-t", target, text]
    if enter:
        args.append("Enter")

    output, code = run_tmux(*args)
    if code != 0:
        return f"Error sending keys: {output}"
    return "Text sent successfully"


@tmux_tool()
def tmux_capture(target: str, lines: int = 100) -> str:
    """
    Capture output from a tmux window.

    Args:
        target: Window identifier - use ID from tmux_new_window (e.g., "@3")
        lines: Number of lines to capture from scrollback (default: 100, max: 10000)

    Returns:
        Captured window content
    """
    require_tmux()
    validate_target(target)
    # Clamp lines to safe bounds to prevent memory exhaustion
    lines = max(MIN_CAPTURE_LINES, min(lines, MAX_CAPTURE_LINES))
    args = ["capture-pane", "-t", target, "-p", "-S", f"-{lines}"]
    output, code = run_tmux(*args)

    if code != 0:
        return f"Error capturing window: {output}"
    return output


@tmux_tool()
def tmux_list() -> TmuxListResult:
    """
    List all windows in the current session.

    Returns:
        TmuxListResult with windows and current window ID
    """
    require_tmux()
    format_str = "#{window_id}|#{window_index}|#{window_name}|#{window_active}|#{pane_current_command}"
    output, code = run_tmux("list-windows", "-F", format_str)

    if code != 0:
        raise RuntimeError(f"Error listing windows: {output}")

    windows = []
    current = get_current_window()
    for line in output.split("\n"):
        if line:
            parts = line.split("|")
            windows.append(TmuxWindow(
                id=parts[0],
                index=parts[1],
                name=parts[2],
                active=parts[3] == "1",
                command=parts[4],
                is_claude=parts[0] == current
            ))

    return TmuxListResult(windows=windows, current_window=current)


@tmux_tool()
def tmux_kill(target: str) -> str:
    """
    Kill a tmux window.

    Args:
        target: Window identifier to kill (e.g., "@3")

    Returns:
        Success message or error
    """
    require_tmux()
    validate_target(target)
    # Safety: prevent killing own window
    current = get_current_window()
    if target == current:
        return "Error: Cannot kill Claude's own window!"

    output, code = run_tmux("kill-window", "-t", target)
    if code != 0:
        return f"Error killing window: {output}"
    return "Window killed successfully"


@tmux_tool()
def tmux_interrupt(target: str) -> str:
    """
    Send Ctrl+C interrupt to a window.

    Args:
        target: Window identifier

    Returns:
        Success message
    """
    require_tmux()
    validate_target(target)
    run_tmux("send-keys", "-t", target, "C-c")
    return "Interrupt sent"


@tmux_tool()
def tmux_wait_idle(target: str, idle_seconds: float = 2.0, timeout: int = 60) -> str:
    """
    Wait for a window to become idle (no output changes).

    Args:
        target: Window identifier
        idle_seconds: Seconds of no change to consider idle
        timeout: Maximum seconds to wait

    Returns:
        "idle" when window is idle, or "timeout" if timeout reached
    """
    require_tmux()
    validate_target(target)
    start = time.time()
    last_hash = ""
    last_change = time.time()

    while time.time() - start < timeout:
        content, _ = run_tmux("capture-pane", "-t", target, "-p")
        current_hash = hashlib.md5(content.encode()).hexdigest()

        if current_hash != last_hash:
            last_hash = current_hash
            last_change = time.time()
        elif time.time() - last_change >= idle_seconds:
            return "idle"

        time.sleep(0.5)

    return "timeout"


@mcp.tool()
def notify(title: str, message: str, sound: bool = True) -> str:
    """
    Send a macOS notification (useful for long-running tasks).

    Args:
        title: Notification title
        message: Notification body text
        sound: Whether to play notification sound (default: True)

    Returns:
        Success message or error
    """
    sound_flag = 'sound name "default"' if sound else ""
    # Escape quotes in title and message for AppleScript
    safe_title = title.replace('"', '\\"')
    safe_message = message.replace('"', '\\"')
    script = f'display notification "{safe_message}" with title "{safe_title}" {sound_flag}'
    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        return f"Error sending notification: {result.stderr}"
    return "Notification sent"


@tmux_tool()
def tmux_select(target: str) -> str:
    """
    Switch to a tmux window (bring it to foreground).

    Args:
        target: Window identifier to select (e.g., "@3")

    Returns:
        Success message or error
    """
    require_tmux()
    validate_target(target)
    output, code = run_tmux("select-window", "-t", target)
    if code != 0:
        return f"Error selecting window: {output}"
    return "Window selected"


def window_exists(window_id: str) -> tuple[bool, str | None]:
    """Check if a tmux window still exists.

    Returns:
        Tuple of (exists, error_message). If error_message is not None,
        the check failed and exists should be ignored.
    """
    output, code = run_tmux("list-windows", "-F", "#{window_id}")
    if code != 0:
        return False, f"Error listing windows: {output}"
    return window_id in output.split("\n"), None


# Placeholder that will be substituted with auto-generated temp file path
OUTPUT_FILE_PLACEHOLDER = "__OUTPUT_FILE__"


@tmux_tool()
def tmux_run_and_read(
    command: str,
    name: str = "",
    timeout: int = 300
) -> str:
    """
    Run a command in a new tmux window and return the contents of an output file.

    The command should contain __OUTPUT_FILE__ placeholder which will be replaced
    with an auto-generated temp file path in /tmp. This ensures safe file handling
    without exposing arbitrary file paths.

    IMPORTANT: Unlike tmux_new_window, this does NOT spawn a shell.
    The command is executed directly via tmux new-window, so it must be
    a complete executable command (not shell syntax like pipes or redirects).

    Use this for CLI tools that support file output, like:
        my-tool --output __OUTPUT_FILE__

    Args:
        command: Command to run (must contain __OUTPUT_FILE__ placeholder)
        name: Optional window name (shown in status bar)
        timeout: Maximum seconds to wait for command to finish (default: 300)

    Returns:
        Contents of output file on success, or error message
    """
    require_tmux()

    # Validate that command contains the placeholder
    if OUTPUT_FILE_PLACEHOLDER not in command:
        raise ValueError(
            f"Command must contain the {OUTPUT_FILE_PLACEHOLDER} placeholder. "
            f"This placeholder will be replaced with an auto-generated temp file path. "
            f"Example: my-tool --output {OUTPUT_FILE_PLACEHOLDER}"
        )

    # Generate random temp file path (safe location)
    output_file = f"/tmp/tmux_output_{uuid.uuid4().hex}.txt"

    # Substitute placeholder with actual path
    actual_command = command.replace(OUTPUT_FILE_PLACEHOLDER, output_file)

    # Create new window with command running directly (no shell wrapper)
    # -d flag keeps focus on current window (don't switch to new one)
    args = ["new-window", "-d", "-P", "-F", "#{window_id}"]
    if name:
        args.extend(["-n", name])
    args.append(actual_command)

    output, code = run_tmux(*args)

    if code != 0:
        return f"Error creating window: {output}"

    window_id = output.strip()

    # Wait for window to close (command finished) or timeout
    start = time.time()
    while time.time() - start < timeout:
        exists, error = window_exists(window_id)
        if error:
            return error
        if not exists:
            # Window closed - command finished
            break
        time.sleep(0.5)
    else:
        # Timeout reached - kill the window
        run_tmux("kill-window", "-t", window_id)
        return f"Error: Command timed out after {timeout}s"

    # Read the output file
    if not os.path.exists(output_file):
        return f"Error: Output file was not created by the command"

    try:
        with open(output_file, "r") as f:
            content = f.read()
        # Clean up the output file
        os.remove(output_file)
        return content
    except Exception as e:
        return f"Error reading output file: {e}"


# =============================================================================
# Task Worker Helpers
# =============================================================================


def _cleanup_old_workers():
    """Remove workers older than WORKER_CLEANUP_HOURS (must hold lock)."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=WORKER_CLEANUP_HOURS)
    to_remove = [
        wid for wid, worker in TASK_WORKERS.items()
        if worker.created_at < cutoff and worker.status not in ("starting", "working")
    ]
    for wid in to_remove:
        del TASK_WORKERS[wid]


def _generate_task_file_content(
    task_data: dict[str, Any],
    auto_merge: bool,
    worktree_path: str,
    repo: str
) -> str:
    """Generate the .orchestrator/current_task.md content from task data."""
    task_id = task_data.get("id", "unknown")
    title = task_data.get("title", "Untitled Task")
    description = task_data.get("description", "")
    test_strategy = task_data.get("testStrategy", "")
    subtasks = task_data.get("subtasks", [])

    # Build subtasks table
    subtask_rows = []
    for st in subtasks:
        st_id = st.get("id", "")
        st_title = st.get("title", "")
        st_desc = st.get("description", "")
        subtask_rows.append(f"| {st_id} | {st_title} | {st_desc} |")

    subtask_table = "\n".join(subtask_rows) if subtask_rows else "| - | No subtasks | - |"

    # Determine branch name from worktree path
    branch = Path(worktree_path).name

    content = f"""# Task: {title}

## Metadata
- **Task ID**: {task_id}
- **Auto Merge**: {str(auto_merge).lower()}
- **Branch**: {branch}
- **Worktree**: {worktree_path}
- **Repository**: {repo}

## Description
{description}

## Subtasks
| ID | Title | Description |
|----|-------|-------------|
{subtask_table}

## Test Strategy
{test_strategy if test_strategy else "No specific test strategy defined."}

## Instructions
1. Work through all subtasks in order
2. Commit after each subtask
3. Update `.orchestrator/task_status` after each subtask completion
4. When all subtasks done: run `/commit-push-pr`{' then auto-merge' if auto_merge else ''}
5. Write final status to `.orchestrator/task_status`

**You do NOT have access to task-master. Report progress via `.orchestrator/task_status` only.**
"""
    return content


def _read_task_status(worktree_path: str) -> TaskWorkerStatus | None:
    """Read and parse the .task_status file from a worktree."""
    status_file = Path(worktree_path) / TASK_STATUS_FILE
    if not status_file.exists():
        return None

    try:
        content = status_file.read_text(encoding="utf-8")
        if not content.strip():
            return None

        data = json.loads(content)

        # Parse completed_subtasks
        completed = []
        for st in data.get("completed_subtasks", []):
            completed.append(CompletedSubtask(
                id=st.get("id", ""),
                commit=st.get("commit", ""),
                notes=st.get("notes", "")
            ))

        return TaskWorkerStatus(
            status=data.get("status", "working"),
            heartbeat=data.get("heartbeat"),
            current_subtask=data.get("current_subtask"),
            progress=data.get("progress"),
            completed_subtasks=completed,
            commits=data.get("commits", []),
            final_commit=data.get("final_commit"),
            pr_url=data.get("pr_url"),
            pr_number=data.get("pr_number"),
            merged=data.get("merged"),
            error=data.get("error"),
            notes=data.get("notes")
        )
    except (json.JSONDecodeError, Exception):
        return None


def _read_task_result(worktree_path: str) -> TaskWorkerResult | None:
    """Read and parse the .task_result file from a worktree."""
    result_file = Path(worktree_path) / TASK_RESULT_FILE
    if not result_file.exists():
        return None

    try:
        content = result_file.read_text(encoding="utf-8")
        if not content.strip():
            return None

        data = json.loads(content)

        # Parse commits
        commits = []
        for c in data.get("commits", []):
            if isinstance(c, dict):
                commits.append(ResultCommit(
                    sha=c.get("sha", ""),
                    message=c.get("message", "")
                ))

        # Parse PR info
        pr_data = data.get("pr")
        pr = None
        if pr_data and isinstance(pr_data, dict):
            pr = ResultPR(
                url=pr_data.get("url", ""),
                number=pr_data.get("number", 0),
                merged=pr_data.get("merged", False)
            )

        return TaskWorkerResult(
            task_id=data.get("task_id", ""),
            title=data.get("title", ""),
            status=data.get("status", "completed"),
            summary=data.get("summary", ""),
            actions=data.get("actions", []),
            files_changed=data.get("files_changed", []),
            commits=commits,
            pr=pr,
            error=data.get("error"),
            duration_estimate=data.get("duration_estimate")
        )
    except (json.JSONDecodeError, Exception):
        return None


# =============================================================================
# Task Worker Tools
# =============================================================================


@tmux_tool()
def task_worker_spawn(
    task_data: dict[str, Any],
    worktree_path: str,
    auto_merge: bool = False,
    repo: str = ""
) -> TaskWorkerSpawnResult:
    """
    Spawn a Claude worker instance to work on a task in a worktree.

    This creates the .orchestrator/current_task.md file, starts Claude in a new tmux window,
    and sends the /work command to begin autonomous task execution.

    Workers always use PR workflow (no direct merge mode).

    Args:
        task_data: Full task JSON from task-master (must include id, title, description, subtasks)
        worktree_path: Absolute path to the git worktree
        auto_merge: Whether to auto-merge the PR after creation
        repo: Repository in owner/repo format (for GitHub links)

    Returns:
        TaskWorkerSpawnResult with worker_id and window_id
    """
    require_tmux()

    # Validate worktree path
    if not Path(worktree_path).is_dir():
        return TaskWorkerSpawnResult(
            status="error",
            error=f"Worktree path does not exist: {worktree_path}"
        )

    # Check worker limit
    with TASK_WORKERS_LOCK:
        active = sum(1 for w in TASK_WORKERS.values() if w.status in ("starting", "working"))
        if active >= MAX_TASK_WORKERS:
            return TaskWorkerSpawnResult(
                status="error",
                error=f"Max concurrent workers ({MAX_TASK_WORKERS}) reached. "
                      f"Wait for some workers to complete."
            )

        _cleanup_old_workers()

    # Generate worker ID
    worker_id = str(uuid.uuid4())[:8]
    task_id = str(task_data.get("id", "unknown"))

    # Create .orchestrator/ directory
    orchestrator_dir = Path(worktree_path) / ORCHESTRATOR_DIR
    try:
        orchestrator_dir.mkdir(exist_ok=True)
    except Exception as e:
        return TaskWorkerSpawnResult(
            status="error",
            error=f"Failed to create orchestrator directory: {e}"
        )

    # Write .orchestrator/current_task.md
    task_file_content = _generate_task_file_content(
        task_data=task_data,
        auto_merge=auto_merge,
        worktree_path=worktree_path,
        repo=repo
    )

    task_file_path = Path(worktree_path) / CURRENT_TASK_FILE
    try:
        task_file_path.write_text(task_file_content, encoding="utf-8")
    except Exception as e:
        return TaskWorkerSpawnResult(
            status="error",
            error=f"Failed to write task file: {e}"
        )

    # Initialize empty .orchestrator/task_status
    status_file_path = Path(worktree_path) / TASK_STATUS_FILE
    try:
        status_file_path.write_text("{}", encoding="utf-8")
    except Exception as e:
        return TaskWorkerSpawnResult(
            status="error",
            error=f"Failed to write status file: {e}"
        )

    # Create tmux window with Claude
    # Use fish shell, cd to worktree, then run claude
    # Include task title in window name for better identification
    task_title = str(task_data.get("title", ""))[:25].replace(" ", "-").replace("/", "-")
    window_name = f"T{task_id}-{task_title}"

    # Create new window
    args = ["new-window", "-d", "-P", "-F", "#{window_id}", "-n", window_name, "fish"]
    output, code = run_tmux(*args)

    if code != 0:
        return TaskWorkerSpawnResult(
            status="error",
            error=f"Failed to create tmux window: {output}"
        )

    window_id = output.strip()

    # Prevent shell/programs from overwriting the window title
    run_tmux("set-window-option", "-t", window_id, "allow-rename", "off")
    run_tmux("set-window-option", "-t", window_id, "automatic-rename", "off")

    # Wait for shell to be ready using marker
    marker = f"READY_{uuid.uuid4().hex}"
    run_tmux("send-keys", "-t", window_id, f"echo {marker}", "Enter")

    shell_ready = False
    for _ in range(50):  # 5 seconds
        time.sleep(0.1)
        content, _ = run_tmux("capture-pane", "-t", window_id, "-p")
        if marker in content:
            shell_ready = True
            break

    if not shell_ready:
        run_tmux("kill-window", "-t", window_id)
        return TaskWorkerSpawnResult(
            status="error",
            error="Shell did not become ready in time"
        )

    # Send cd and claude command (with --dangerously-skip-permissions for unattended execution)
    # --add-dir prevents permission prompts for the worktree directory
    # Quote paths to handle spaces
    # Use claudebox for sandboxed execution
    # --no-monitor: Skip tmux command monitoring (we manage our own tmux)
    # --allow-ssh-agent: Enable SSH agent pass-through for git operations
    # -- separates claudebox flags from claude flags
    quoted_path = shlex.quote(worktree_path)
    run_tmux("send-keys", "-t", window_id, f"cd {quoted_path}", "Enter")
    time.sleep(0.3)
    run_tmux("send-keys", "-t", window_id, f"claudebox --no-monitor --allow-ssh-agent -- --dangerously-skip-permissions --add-dir {quoted_path}", "Enter")

    # Wait for Claude to be fully ready (look for the ❯ prompt character)
    # Claude shows "❯" when ready for input
    claude_ready = False
    for _ in range(150):  # 15 seconds - Claude can take a while to start
        time.sleep(0.1)
        content, _ = run_tmux("capture-pane", "-t", window_id, "-p")
        # Look for Claude's prompt indicator (❯) after startup banner
        if "❯" in content and "Claude Code" in content:
            claude_ready = True
            break

    if not claude_ready:
        run_tmux("kill-window", "-t", window_id)
        return TaskWorkerSpawnResult(
            status="error",
            error="Claude did not start in time"
        )

    # Wait a bit more for Claude to fully initialize UI
    time.sleep(1.0)

    # Send /work command - send the text first, then Enter separately
    # This ensures the slash command picker has time to show
    run_tmux("send-keys", "-t", window_id, "/work")
    time.sleep(0.3)  # Let the slash command picker appear
    run_tmux("send-keys", "-t", window_id, "Enter")

    # Wait for /work command to be accepted (look for skill loading or tool activity)
    work_started = False
    for _ in range(100):  # 10 seconds
        time.sleep(0.1)
        content, _ = run_tmux("capture-pane", "-t", window_id, "-p")
        # Check if /work was accepted - look for:
        # - Tool calls starting (Read, Write, etc.)
        # - "Starting work" or similar
        # - The prompt moving past /work
        if any(indicator in content for indicator in [
            "Read(",
            "Write(",
            "Edit(",
            "Bash(",
            "Starting work",
            "task",
            "subtask",
            "⏺",  # Claude's activity indicator
        ]):
            work_started = True
            break

    if not work_started:
        # Check if we're still at the slash command picker
        content, _ = run_tmux("capture-pane", "-t", window_id, "-p")
        if "/work" in content and "Autonomous task" in content:
            # Slash command picker is showing, send Enter again
            run_tmux("send-keys", "-t", window_id, "Enter")
            time.sleep(0.5)

    # Track the worker
    with TASK_WORKERS_LOCK:
        TASK_WORKERS[worker_id] = TaskWorkerData(
            worker_id=worker_id,
            task_id=task_id,
            worktree_path=worktree_path,
            window_id=window_id,
            auto_merge=auto_merge,
            status="starting",
            created_at=datetime.now(timezone.utc),
            task_data=task_data
        )

    return TaskWorkerSpawnResult(
        status="spawned",
        worker_id=worker_id,
        window_id=window_id
    )


@tmux_tool()
def task_worker_status(worker_id: str) -> TaskWorkerStatusResult:
    """
    Get the status of a task worker.

    Reads the .task_status file from the worker's worktree and checks
    if the tmux window is still running.

    Args:
        worker_id: Worker ID from task_worker_spawn

    Returns:
        TaskWorkerStatusResult with current status and parsed status data
    """
    with TASK_WORKERS_LOCK:
        worker = TASK_WORKERS.get(worker_id)

    if not worker:
        return TaskWorkerStatusResult(
            status="not_found",
            worker_id=worker_id,
            error="Worker not found"
        )

    # Check if window still exists
    exists, error = window_exists(worker.window_id)
    if error:
        return TaskWorkerStatusResult(
            status="not_found",
            worker_id=worker_id,
            task_id=worker.task_id,
            error=error
        )

    # Read status and result files
    status_data = _read_task_status(worker.worktree_path)
    result_data = _read_task_result(worker.worktree_path)

    # Determine status
    if not exists:
        # Window closed
        if status_data:
            final_status = status_data.status
            # Map status file status to worker status
            if final_status == "completed":
                with TASK_WORKERS_LOCK:
                    worker.status = "completed"
                    worker.completed_at = datetime.now(timezone.utc)
            elif final_status in ("failed", "stuck"):
                with TASK_WORKERS_LOCK:
                    worker.status = final_status
                    worker.error = status_data.error
                    worker.completed_at = datetime.now(timezone.utc)
            else:
                # Window closed without proper status - mark as stuck
                with TASK_WORKERS_LOCK:
                    worker.status = "stuck"
                    worker.error = "Window closed without completion status"
                    worker.completed_at = datetime.now(timezone.utc)

            return TaskWorkerStatusResult(
                status=worker.status,  # type: ignore
                worker_id=worker_id,
                task_id=worker.task_id,
                worktree_path=worker.worktree_path,
                status_data=status_data,
                result_data=result_data
            )
        else:
            # No status file and window closed
            with TASK_WORKERS_LOCK:
                worker.status = "stuck"
                worker.error = "Window closed without status file"
                worker.completed_at = datetime.now(timezone.utc)

            return TaskWorkerStatusResult(
                status="stuck",
                worker_id=worker_id,
                task_id=worker.task_id,
                worktree_path=worker.worktree_path,
                result_data=result_data,
                error="Window closed without status file"
            )

    # Window still running
    if status_data:
        current_status = status_data.status
        with TASK_WORKERS_LOCK:
            if current_status == "working":
                worker.status = "working"
            elif current_status == "completed":
                worker.status = "completed"
                worker.completed_at = datetime.now(timezone.utc)
            elif current_status in ("failed", "stuck"):
                worker.status = current_status
                worker.error = status_data.error
                worker.completed_at = datetime.now(timezone.utc)

        return TaskWorkerStatusResult(
            status=worker.status,  # type: ignore
            worker_id=worker_id,
            task_id=worker.task_id,
            worktree_path=worker.worktree_path,
            status_data=status_data,
            result_data=result_data
        )

    # Window running but no status yet - still starting
    return TaskWorkerStatusResult(
        status="starting",
        worker_id=worker_id,
        task_id=worker.task_id,
        worktree_path=worker.worktree_path,
        result_data=result_data
    )


@tmux_tool()
def task_worker_list() -> TaskWorkerListResult:
    """
    List all tracked task workers.

    Returns:
        TaskWorkerListResult with list of workers and counts
    """
    with TASK_WORKERS_LOCK:
        workers = []
        active_count = 0

        for worker in TASK_WORKERS.values():
            if worker.status in ("starting", "working"):
                active_count += 1

            workers.append(TaskWorker(
                worker_id=worker.worker_id,
                task_id=worker.task_id,
                worktree_path=worker.worktree_path,
                window_id=worker.window_id,
                auto_merge=worker.auto_merge,
                status=worker.status,  # type: ignore
                created_at=worker.created_at.isoformat(),
                completed_at=worker.completed_at.isoformat() if worker.completed_at else None,
                error=worker.error,
                retry_count=worker.retry_count
            ))

        return TaskWorkerListResult(
            workers=workers,
            total=len(workers),
            active=active_count
        )


@tmux_tool()
def task_worker_kill(worker_id: str) -> str:
    """
    Kill a task worker's tmux window.

    This does NOT clean up the worktree - that must be done manually
    so the user can investigate failures.

    Args:
        worker_id: Worker ID to kill

    Returns:
        Success message or error
    """
    with TASK_WORKERS_LOCK:
        worker = TASK_WORKERS.get(worker_id)

    if not worker:
        return f"Worker not found: {worker_id}"

    # Kill the window
    output, code = run_tmux("kill-window", "-t", worker.window_id)

    if code != 0:
        return f"Error killing window: {output}"

    with TASK_WORKERS_LOCK:
        worker.status = "failed"
        worker.error = "Killed by orchestrator"
        worker.completed_at = datetime.now(timezone.utc)

    return f"Worker {worker_id} killed. Worktree preserved at: {worker.worktree_path}"


# =============================================================================
# AI Tools
# =============================================================================


@mcp.tool()
async def ai_call(
    cli: str,
    prompt: str,
    files: list[str] | None = None,
    timeout: int = 300
) -> AICallResult:
    """
    Call an AI CLI synchronously and return its response.

    This is a blocking call - use ai_spawn/ai_fetch for parallel execution.

    Args:
        cli: CLI to use (claude, codex, gemini)
        prompt: Prompt to send to the CLI
        files: Optional list of file paths to include as context
        timeout: Maximum seconds to wait (default: 300)

    Returns:
        AICallResult with status, content, and metadata
    """
    if cli not in AI_CLIS:
        available = ", ".join(AI_CLIS.keys())
        return AICallResult(
            status="error",
            error=f"Unknown CLI: {cli}. Available: {available}"
        )

    config = AI_CLIS[cli]
    full_prompt = _build_ai_prompt(prompt, files or [])

    try:
        result = await _run_ai_cli(
            command=config["command"],
            prompt=full_prompt,
            timeout=timeout,
            parser_name=config["parser"]
        )
        return AICallResult(
            status="success",
            cli=cli,
            content=result.content,
            metadata=result.metadata
        )
    except ParserError as e:
        return AICallResult(
            status="error",
            cli=cli,
            error=f"Parse error: {e}"
        )
    except Exception as e:
        return AICallResult(
            status="error",
            cli=cli,
            error=str(e)
        )


@mcp.tool()
def ai_spawn(
    cli: str,
    prompt: str,
    files: list[str] | None = None,
    timeout: int = 300
) -> AISpawnResult:
    """
    Spawn an AI CLI asynchronously and return a job ID.

    Use ai_fetch to retrieve results. This allows running multiple AIs in parallel.

    Args:
        cli: CLI to use (claude, codex, gemini)
        prompt: Prompt to send to the CLI
        files: Optional list of file paths to include as context
        timeout: Maximum seconds for CLI to complete (default: 300)

    Returns:
        AISpawnResult with job_id for use with ai_fetch
    """
    if cli not in AI_CLIS:
        available = ", ".join(AI_CLIS.keys())
        return AISpawnResult(
            status="error",
            error=f"Unknown CLI: {cli}. Available: {available}"
        )

    with AI_JOBS_LOCK:
        # Check concurrent job limit
        running = sum(1 for j in AI_JOBS.values() if j.status == "running")
        if running >= MAX_CONCURRENT_JOBS:
            return AISpawnResult(
                status="error",
                error=f"Max concurrent jobs ({MAX_CONCURRENT_JOBS}) reached. "
                      f"Wait for some jobs to complete or use ai_fetch to retrieve results."
            )

        # Cleanup old jobs
        _cleanup_old_ai_jobs()

        # Create job
        job_id = str(uuid.uuid4())[:8]
        job = AIJob(
            id=job_id,
            cli=cli,
            prompt=prompt,
            files=files or [],
            status="running",
            timeout=timeout
        )
        AI_JOBS[job_id] = job

    # Start background task
    asyncio.create_task(_run_ai_job_async(job_id))

    return AISpawnResult(
        status="spawned",
        job_id=job_id,
        cli=cli,
        message=f"Job spawned. Use ai_fetch(job_id='{job_id}') to get results."
    )


@mcp.tool()
async def ai_fetch(
    job_id: str,
    timeout: int = 30
) -> AIFetchResult:
    """
    Fetch the result of a spawned AI job.

    Args:
        job_id: Job ID from ai_spawn
        timeout: Seconds to wait if job still running (default: 30, 0 = no wait)

    Returns:
        AIFetchResult with status and result. Status can be:
        - "completed": Job finished, content available
        - "failed": Job errored, error message available
        - "timeout": CLI timed out
        - "running": Job still running (call ai_fetch again)
        - "not_found": Job ID not found
    """
    start = time.time()

    while True:
        with AI_JOBS_LOCK:
            job = AI_JOBS.get(job_id)

        if job is None:
            return AIFetchResult(
                status="not_found",
                job_id=job_id,
                error="Job not found. It may have expired or never existed."
            )

        if job.status == "completed":
            return AIFetchResult(
                status="completed",
                job_id=job_id,
                cli=job.cli,
                content=job.result,
                metadata=job.metadata
            )

        if job.status in ("failed", "timeout"):
            return AIFetchResult(
                status=job.status,  # type: ignore[arg-type]
                job_id=job_id,
                cli=job.cli,
                error=job.error
            )

        # Still running - check timeout
        elapsed = time.time() - start
        if elapsed >= timeout:
            return AIFetchResult(
                status="running",
                job_id=job_id,
                cli=job.cli,
                message="Job still running. Call ai_fetch again to check status."
            )

        await asyncio.sleep(0.5)


@mcp.tool()
def ai_list() -> AIListResult:
    """
    List all active AI jobs.

    Returns:
        AIListResult with array of jobs and counts
    """
    with AI_JOBS_LOCK:
        jobs = []
        running_count = 0
        for job in AI_JOBS.values():
            if job.status == "running":
                running_count += 1
            jobs.append(AIJobInfo(
                job_id=job.id,
                cli=job.cli,
                status=job.status,
                created_at=job.created_at.isoformat(),
                completed_at=job.completed_at.isoformat() if job.completed_at else None
            ))
    return AIListResult(
        jobs=jobs,
        total=len(jobs),
        running=running_count
    )


@mcp.tool()
def ai_review(
    prompt: str,
    files: list[str] | None = None,
    timeout: int = 300
) -> AIReviewResult:
    """
    Spawn all three AI CLIs in parallel for multi-model review.

    Convenience tool that spawns claude, codex, and gemini with the same prompt.
    Use ai_fetch with each job_id to retrieve results.

    Args:
        prompt: Prompt to send to all CLIs
        files: Optional list of file paths to include as context
        timeout: Maximum seconds for each CLI (default: 300)

    Returns:
        AIReviewResult with job_ids for each CLI
    """
    results: dict[str, AIReviewJobStatus] = {}
    error_count = 0

    for cli in ["claude", "codex", "gemini"]:
        with AI_JOBS_LOCK:
            # Check concurrent job limit
            running = sum(1 for j in AI_JOBS.values() if j.status == "running")
            if running >= MAX_CONCURRENT_JOBS:
                results[cli] = AIReviewJobStatus(
                    status="error",
                    error="Max concurrent jobs reached"
                )
                error_count += 1
                continue

            # Cleanup old jobs
            _cleanup_old_ai_jobs()

            # Create job
            job_id = str(uuid.uuid4())[:8]
            job = AIJob(
                id=job_id,
                cli=cli,
                prompt=prompt,
                files=files or [],
                status="running",
                timeout=timeout
            )
            AI_JOBS[job_id] = job

        # Start background task
        asyncio.create_task(_run_ai_job_async(job_id))

        results[cli] = AIReviewJobStatus(
            status="spawned",
            job_id=job_id
        )

    # Determine overall status
    if error_count == 3:
        overall_status: Literal["spawned", "partial", "error"] = "error"
    elif error_count > 0:
        overall_status = "partial"
    else:
        overall_status = "spawned"

    return AIReviewResult(
        status=overall_status,
        jobs=results,
        message="Use ai_fetch(job_id=...) to retrieve each result."
    )


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    mcp.run()
