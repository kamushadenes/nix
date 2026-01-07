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
from dataclasses import dataclass, field
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Any, Literal
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("orchestrator")


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

    # Check for non-zero exit
    if proc.returncode != 0:
        # Try to parse anyway (some CLIs exit non-zero but have valid output)
        pass

    parser = get_parser(parser_name)
    if parser:
        return parser(stdout_text, stderr_text)
    else:
        return ParsedResponse(
            content=stdout_text,
            metadata={"stderr": stderr_text, "parser": "raw"}
        )


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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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


@mcp.tool()
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
