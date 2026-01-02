#!/usr/bin/env python3
"""
MCP server for terminal automation and AI CLI orchestration.

Provides:
- tmux_* tools: Terminal window management (existing)
- ai_* tools: AI CLI wrappers for claude, codex, gemini (new)

Job system features:
- Session-scoped jobs (isolated per tmux session)
- SQLite persistence for concurrent access
- Streaming output support
- Inter-agent messaging
"""
import subprocess
import hashlib
import time
import os
import json
import re
import uuid
import shutil
import shlex
import sqlite3
import threading
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("orchestrator")

# =============================================================================
# Configuration
# =============================================================================

VALID_SHELLS = {"zsh", "bash", "fish", "sh"}
DEFAULT_SHELL = "zsh"
MAX_CAPTURE_LINES = 10000
MIN_CAPTURE_LINES = 1
JOB_EXPIRY_SECONDS = 3600  # 1 hour
DB_PATH = Path.home() / ".config" / "orchestrator-mcp" / "state.db"

# Pattern for valid tmux window/pane identifiers (e.g., @3, %5)
TARGET_PATTERN = re.compile(r'^[@%][0-9]+$')

# Supported AI CLIs
SUPPORTED_CLIS = {"claude", "codex", "gemini"}

# =============================================================================
# Data Classes
# =============================================================================


@dataclass
class Message:
    """Inter-job message."""
    id: str
    job_id: str
    sender: str
    content: str
    msg_type: str  # "intermediate" or "final"
    timestamp: float


@dataclass
class Job:
    """Represents an AI CLI job."""
    id: str
    session_id: str
    cli: str  # "claude", "codex", or "gemini"
    prompt: str
    status: str  # "running", "completed", "failed"
    result: Optional[str] = None
    output_offset: int = 0  # Current offset in output file
    pid: Optional[int] = None
    created: float = field(default_factory=time.time)
    model: str = ""
    files: list = field(default_factory=list)
    window_id: Optional[str] = None  # tmux window ID for monitoring
    worktree_path: Optional[str] = None  # Isolated git worktree path


# =============================================================================
# SQLite Database Layer
# =============================================================================

_db_lock = threading.Lock()


def get_db_connection() -> sqlite3.Connection:
    """Get a database connection with proper settings."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), timeout=30.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=5000")
    return conn


def init_db():
    """Initialize the database schema."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.executescript("""
                CREATE TABLE IF NOT EXISTS jobs (
                    id TEXT PRIMARY KEY,
                    session_id TEXT NOT NULL,
                    cli TEXT NOT NULL,
                    prompt TEXT NOT NULL,
                    status TEXT NOT NULL,
                    result TEXT,
                    output_offset INTEGER DEFAULT 0,
                    pid INTEGER,
                    created REAL NOT NULL,
                    model TEXT DEFAULT '',
                    files TEXT DEFAULT '[]',
                    window_id TEXT,
                    worktree_path TEXT
                );

                CREATE TABLE IF NOT EXISTS messages (
                    id TEXT PRIMARY KEY,
                    job_id TEXT NOT NULL,
                    sender TEXT NOT NULL,
                    content TEXT NOT NULL,
                    msg_type TEXT NOT NULL,
                    timestamp REAL NOT NULL,
                    FOREIGN KEY (job_id) REFERENCES jobs(id)
                );

                CREATE INDEX IF NOT EXISTS idx_jobs_session ON jobs(session_id);
                CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
                CREATE INDEX IF NOT EXISTS idx_messages_job ON messages(job_id);
            """)
            # Add worktree_path column if it doesn't exist (migration)
            try:
                conn.execute("ALTER TABLE jobs ADD COLUMN worktree_path TEXT")
            except sqlite3.OperationalError:
                pass  # Column already exists
            conn.commit()
        finally:
            conn.close()


def save_job(job: Job):
    """Save or update a job in the database."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute("""
                INSERT OR REPLACE INTO jobs
                (id, session_id, cli, prompt, status, result, output_offset, pid, created, model, files, window_id, worktree_path)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                job.id, job.session_id, job.cli, job.prompt, job.status,
                job.result, job.output_offset, job.pid, job.created,
                job.model, json.dumps(job.files), job.window_id, job.worktree_path
            ))
            conn.commit()
        finally:
            conn.close()


def get_job(job_id: str, session_id: Optional[str] = None) -> Optional[Job]:
    """Get a job by ID, optionally filtering by session."""
    with _db_lock:
        conn = get_db_connection()
        try:
            if session_id:
                row = conn.execute(
                    "SELECT * FROM jobs WHERE id = ? AND session_id = ?",
                    (job_id, session_id)
                ).fetchone()
            else:
                row = conn.execute(
                    "SELECT * FROM jobs WHERE id = ?",
                    (job_id,)
                ).fetchone()
            if row:
                return Job(
                    id=row['id'],
                    session_id=row['session_id'],
                    cli=row['cli'],
                    prompt=row['prompt'],
                    status=row['status'],
                    result=row['result'],
                    output_offset=row['output_offset'],
                    pid=row['pid'],
                    created=row['created'],
                    model=row['model'],
                    files=json.loads(row['files']),
                    window_id=row['window_id'],
                    worktree_path=row['worktree_path'] if 'worktree_path' in row.keys() else None
                )
            return None
        finally:
            conn.close()


def list_jobs(session_id: Optional[str] = None, status: str = "") -> list[Job]:
    """List jobs, optionally filtering by session and/or status."""
    with _db_lock:
        conn = get_db_connection()
        try:
            query = "SELECT * FROM jobs WHERE 1=1"
            params = []
            if session_id:
                query += " AND session_id = ?"
                params.append(session_id)
            if status:
                query += " AND status = ?"
                params.append(status)
            query += " ORDER BY created DESC"

            rows = conn.execute(query, params).fetchall()
            return [
                Job(
                    id=row['id'],
                    session_id=row['session_id'],
                    cli=row['cli'],
                    prompt=row['prompt'],
                    status=row['status'],
                    result=row['result'],
                    output_offset=row['output_offset'],
                    pid=row['pid'],
                    created=row['created'],
                    model=row['model'],
                    files=json.loads(row['files']),
                    window_id=row['window_id'],
                    worktree_path=row['worktree_path'] if 'worktree_path' in row.keys() else None
                )
                for row in rows
            ]
        finally:
            conn.close()


def save_message(msg: Message):
    """Save a message to the database."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute("""
                INSERT INTO messages (id, job_id, sender, content, msg_type, timestamp)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (msg.id, msg.job_id, msg.sender, msg.content, msg.msg_type, msg.timestamp))
            conn.commit()
        finally:
            conn.close()


def get_messages(job_id: str, since_index: int = 0) -> list[Message]:
    """Get messages for a job since a given index."""
    with _db_lock:
        conn = get_db_connection()
        try:
            rows = conn.execute(
                "SELECT * FROM messages WHERE job_id = ? ORDER BY timestamp LIMIT -1 OFFSET ?",
                (job_id, since_index)
            ).fetchall()
            return [
                Message(
                    id=row['id'],
                    job_id=row['job_id'],
                    sender=row['sender'],
                    content=row['content'],
                    msg_type=row['msg_type'],
                    timestamp=row['timestamp']
                )
                for row in rows
            ]
        finally:
            conn.close()


def cleanup_expired_jobs(max_age_seconds: int = JOB_EXPIRY_SECONDS):
    """Remove completed/failed jobs older than max_age_seconds."""
    cutoff = time.time() - max_age_seconds
    with _db_lock:
        conn = get_db_connection()
        try:
            # Get expired job IDs
            rows = conn.execute(
                "SELECT id FROM jobs WHERE status IN ('completed', 'failed') AND created < ?",
                (cutoff,)
            ).fetchall()
            job_ids = [row['id'] for row in rows]

            if job_ids:
                # Delete messages first (foreign key)
                placeholders = ','.join('?' * len(job_ids))
                conn.execute(f"DELETE FROM messages WHERE job_id IN ({placeholders})", job_ids)
                conn.execute(f"DELETE FROM jobs WHERE id IN ({placeholders})", job_ids)
                conn.commit()

            return len(job_ids)
        finally:
            conn.close()


# =============================================================================
# Session and CLI Helpers
# =============================================================================


def get_current_session() -> str:
    """Get the current tmux session identifier."""
    tmux_env = os.environ.get("TMUX", "")
    if tmux_env:
        # TMUX format: /path/to/socket,pid,session_number
        # Get session name from tmux
        try:
            result = subprocess.run(
                ["tmux", "display-message", "-p", "#{session_name}"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
    return "default"


def check_cli_available(cli: str) -> bool:
    """Check if an AI CLI is available."""
    return shutil.which(cli) is not None


def get_output_file_path(job_id: str) -> Path:
    """Get the path to a job's output file."""
    return Path("/tmp") / f"orchestrator_{job_id}.out"


WORKTREE_BASE = Path("/tmp/orchestrator-worktrees")


def create_worktree(job_id: str) -> Optional[Path]:
    """Create a git worktree for isolated agent execution.

    Returns the worktree path on success, None on failure.
    """
    worktree_path = WORKTREE_BASE / job_id

    try:
        # Ensure base directory exists
        WORKTREE_BASE.mkdir(parents=True, exist_ok=True)

        # Get current branch/commit
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            return None
        commit = result.stdout.strip()

        # Create worktree at current commit (detached HEAD)
        result = subprocess.run(
            ["git", "worktree", "add", "--detach", str(worktree_path), commit],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            return None

        return worktree_path
    except Exception:
        return None


def cleanup_worktree(job_id: str):
    """Remove a git worktree after job completion."""
    worktree_path = WORKTREE_BASE / job_id

    try:
        # Remove the worktree from git
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(worktree_path)],
            capture_output=True, text=True, timeout=30
        )
    except Exception:
        pass

    # Also try to remove the directory if it still exists
    try:
        if worktree_path.exists():
            import shutil
            shutil.rmtree(worktree_path)
    except Exception:
        pass


# =============================================================================
# tmux Helpers (existing)
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
# tmux Tools (existing)
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
def tmux_list() -> str:
    """
    List all windows in the current session.

    Returns:
        JSON-formatted list of windows with their IDs, names, and status
    """
    require_tmux()
    format_str = "#{window_id}|#{window_index}|#{window_name}|#{window_active}|#{pane_current_command}"
    output, code = run_tmux("list-windows", "-F", format_str)

    if code != 0:
        return f"Error listing windows: {output}"

    windows = []
    current = get_current_window()
    for line in output.split("\n"):
        if line:
            parts = line.split("|")
            windows.append({
                "id": parts[0],
                "index": parts[1],
                "name": parts[2],
                "active": parts[3] == "1",
                "command": parts[4],
                "is_claude": parts[0] == current
            })

    return json.dumps(windows, indent=2)


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
# AI CLI Tools (new)
# =============================================================================


READ_ONLY_INSTRUCTION = """
IMPORTANT: You are running as a READ-ONLY agent. You MUST NOT:
- Execute any commands that modify files (no writes, edits, or deletions)
- Run build commands, install packages, or execute scripts
- Make any changes to the filesystem or git repository

You MAY only:
- Read files and directories
- Run read-only commands (git diff, git log, git status, ls, cat, grep, etc.)
- Analyze and review code

If you need to suggest changes, describe them in text - do NOT execute them.
---
"""


def build_cli_command(cli: str, prompt: str, model: str = "", files: list = None) -> list[str]:
    """Build command arguments for an AI CLI.

    All agents run in full-auto/YOLO mode but with strict read-only instructions
    in the prompt for codex and gemini.
    """
    files = files or []

    if cli == "claude":
        cmd = ["claude", "--print"]
        if model:
            cmd.extend(["--model", model])
        # Claude only supports --add-dir for directories, extract parent dirs from files
        dirs_added = set()
        for f in files:
            dir_path = os.path.dirname(f) if os.path.isfile(f) else f
            if dir_path and dir_path not in dirs_added:
                cmd.extend(["--add-dir", dir_path])
                dirs_added.add(dir_path)
        cmd.append(prompt)
        return cmd

    elif cli == "codex":
        # Full-auto mode with read-only instruction in prompt
        cmd = ["codex", "exec", "-a", "full-auto"]
        if model:
            cmd.extend(["--model", model])
        cmd.append(READ_ONLY_INSTRUCTION + prompt)
        return cmd

    elif cli == "gemini":
        # YOLO mode with read-only instruction in prompt
        cmd = ["gemini", "--yolo"]
        if model:
            cmd.extend(["--model", model])
        # Gemini uses @ syntax for files, prepend to prompt
        file_refs = " ".join(f"@{f}" for f in files)
        full_prompt = f"{file_refs} {READ_ONLY_INSTRUCTION}{prompt}".strip() if file_refs else READ_ONLY_INSTRUCTION + prompt
        cmd.append(full_prompt)
        return cmd

    else:
        raise ValueError(f"Unsupported CLI: {cli}")


def is_window_idle(window_id: str, idle_seconds: float = 2.0) -> bool:
    """Check if a tmux window's command has finished (shell is idle).

    Uses pane_current_command to detect if we're back at the shell prompt.
    """
    output, code = run_tmux("display-message", "-t", window_id, "-p", "#{pane_current_command}")
    if code != 0:
        return False

    current_cmd = output.strip().lower()
    # If we're back at a shell, the command finished
    shell_names = {"bash", "zsh", "fish", "sh", "dash", "ksh", "tcsh", "csh"}
    return current_cmd in shell_names


def run_job_in_tmux(job: Job, log_intermediary: bool = False, auto_close: bool = True):
    """Run a job's CLI command in a tmux window using orchestrator TUI runner.

    The orchestrator CLI handles:
    - JSON output parsing
    - Pretty-printing with colors
    - TUI with sticky header and scrollable output
    - SQLite logging of messages
    - Auto-closing the window on completion
    """
    try:
        # Build orchestrator run command
        runner_cmd = [
            "orchestrator", "run",
            "--cli", job.cli,
            "--job-id", job.id,
        ]
        if log_intermediary:
            runner_cmd.append("--log-intermediary")
        if not auto_close:
            runner_cmd.append("--no-auto-close")
        if job.model:
            runner_cmd.extend(["--model", job.model])
        for f in (job.files or []):
            runner_cmd.extend(["--files", f])
        # Prompt goes last
        runner_cmd.append(job.prompt)

        # Shell-escape for tmux send-keys
        cmd_str = " ".join(shlex.quote(part) for part in runner_cmd)

        # Simple window name: "cli:id"
        window_name = f"{job.cli}:{job.id[-8:]}"

        # Create window running a shell
        args = ["new-window", "-d", "-P", "-F", "#{window_id}", "-n", window_name, DEFAULT_SHELL]
        output, code = run_tmux(*args)

        if code != 0:
            job.status = "failed"
            job.result = f"Error creating tmux window: {output}"
            save_job(job)
            return

        window_id = output.strip()
        job.window_id = window_id
        save_job(job)

        # Wait for shell to be ready
        marker = f"READY_{uuid.uuid4().hex}"
        run_tmux("send-keys", "-t", window_id, f"echo {marker}", "Enter")

        shell_ready = False
        for _ in range(50):  # 5 seconds max
            time.sleep(0.1)
            content, _ = run_tmux("capture-pane", "-t", window_id, "-p")
            if marker in content:
                shell_ready = True
                break

        if not shell_ready:
            job.status = "failed"
            job.result = f"Shell did not become ready in window {window_id}"
            save_job(job)
            return

        # Send the orchestrator run command
        run_tmux("send-keys", "-t", window_id, cmd_str, "Enter")

        # The orchestrator CLI now handles everything:
        # - Parsing JSON output
        # - Pretty-printing
        # - Updating the job status in SQLite
        # - Auto-closing the window
        #
        # We just need to wait for the window to close (if auto_close)
        # or for the command to finish.

        # Poll for completion (check every 2 seconds, timeout after 30 minutes)
        max_wait = 1800  # 30 minutes
        poll_interval = 2
        waited = 0

        while waited < max_wait:
            time.sleep(poll_interval)
            waited += poll_interval

            # Check if window still exists
            list_output, list_code = run_tmux("list-windows", "-F", "#{window_id}")
            if window_id not in list_output:
                # Window was closed (either by auto_close or manually)
                # The orchestrator CLI already updated the job status
                break

            # Check if command finished (back to shell prompt)
            if is_window_idle(window_id):
                # Command finished, wait a moment for final DB updates
                time.sleep(1)
                break

        # Refresh job status from database (orchestrator CLI updated it)
        updated_job = get_job(job.id, job.session_id)
        if updated_job:
            job.status = updated_job.status
            job.result = updated_job.result

    except Exception as e:
        job.status = "failed"
        job.result = f"Error: {e}"
        save_job(job)


@mcp.tool()
def ai_run(
    prompt: str,
    cli: str = "claude",
    model: str = "",
    files: list = None,
    timeout: int = 600,
    worktree: bool = False
) -> str:
    """
    Run an AI CLI job synchronously and return the result.

    Creates a tmux window, runs orchestrator directly (no shell), waits for
    completion, and returns the result. This is the recommended way to run
    AI jobs from Claude Code.

    Args:
        prompt: The question/task for the AI
        cli: Which CLI to use - "claude", "codex", or "gemini"
        model: Optional model override (CLI-specific)
        files: Optional list of files to include as context
        timeout: Max seconds to wait for completion (default: 600)
        worktree: If True, create an isolated git worktree for the agent (safer)

    Returns:
        JSON with job_id, status, and result
    """
    files = files or []

    if cli not in SUPPORTED_CLIS:
        raise ValueError(f"Unsupported CLI: {cli}. Use one of: {SUPPORTED_CLIS}")

    if not check_cli_available(cli):
        raise RuntimeError(f"CLI '{cli}' not found in PATH")

    require_tmux()
    init_db()

    session_id = get_current_session()
    job_id = f"job_{uuid.uuid4().hex[:12]}"

    # SAFETY: codex and gemini ALWAYS run in isolated worktree
    if cli in ("codex", "gemini"):
        worktree = True

    # Create worktree if requested/required
    worktree_path = None
    if worktree:
        worktree_path = create_worktree(job_id)
        if not worktree_path:
            return json.dumps({
                "job_id": job_id,
                "status": "failed",
                "result": "Failed to create git worktree"
            })

    # Create job entry first
    job = Job(
        id=job_id,
        session_id=session_id,
        cli=cli,
        prompt=prompt,
        status="running",
        model=model,
        files=files,
        worktree_path=str(worktree_path) if worktree_path else None
    )
    save_job(job)

    # Build orchestrator run command
    runner_cmd = [
        "orchestrator", "run",
        "--cli", cli,
        "--job-id", job_id,
    ]
    if model:
        runner_cmd.extend(["--model", model])
    for f in files:
        runner_cmd.extend(["--files", f])
    if worktree_path:
        runner_cmd.extend(["--worktree", str(worktree_path)])
    runner_cmd.append(prompt)

    # Simple window name: "cli:id"
    window_name = f"{cli}:{job_id[-8:]}"

    # Create tmux window running orchestrator directly (no shell wrapper)
    # orchestrator run will exit when done, closing the window
    args = ["new-window", "-d", "-P", "-F", "#{window_id}", "-n", window_name] + runner_cmd
    output, code = run_tmux(*args)

    if code != 0:
        job.status = "failed"
        job.result = f"Error creating tmux window: {output}"
        save_job(job)
        return json.dumps({
            "job_id": job_id,
            "status": "failed",
            "result": job.result
        })

    window_id = output.strip()
    job.window_id = window_id
    save_job(job)

    # Wait for window to close (orchestrator exits on completion)
    start = time.time()
    while time.time() - start < timeout:
        exists, error = window_exists(window_id)
        if error:
            # tmux error - try to continue
            break
        if not exists:
            # Window closed - command finished
            break
        time.sleep(1)
    else:
        # Timeout - kill window and return error
        run_tmux("kill-window", "-t", window_id)
        job.status = "failed"
        job.result = f"Timeout after {timeout}s"
        save_job(job)
        return json.dumps({
            "job_id": job_id,
            "status": "timeout",
            "result": job.result
        })

    # Small delay to ensure orchestrator CLI has written final results
    time.sleep(0.5)

    # Fetch result from database (orchestrator CLI updated it)
    updated_job = get_job(job_id, session_id)

    # Cleanup worktree if it was created
    if worktree_path:
        cleanup_worktree(job_id)

    if updated_job:
        messages = get_messages(job_id)
        return json.dumps({
            "job_id": job_id,
            "status": updated_job.status,
            "result": updated_job.result,
            "worktree_path": str(worktree_path) if worktree_path else None,
            "messages": [asdict(m) for m in messages]
        }, indent=2)
    else:
        return json.dumps({
            "job_id": job_id,
            "status": "unknown",
            "result": "Job not found after completion"
        })


@mcp.tool()
def ai_spawn(
    prompt: str,
    cli: str = "claude",
    model: str = "",
    files: list = None,
    log_intermediary: bool = False,
    auto_close: bool = True
) -> str:
    """
    Start an async AI CLI job and return immediately.

    Args:
        prompt: The question/task for the AI
        cli: Which CLI to use - "claude", "codex", or "gemini"
        model: Optional model override (CLI-specific)
        files: Optional list of files to include as context
        log_intermediary: Log intermediary messages to SQLite (default: False)
        auto_close: Auto-close tmux window on completion (default: True)

    Returns:
        Job ID (e.g., "job_abc123") for use with ai_fetch/ai_stream
    """
    files = files or []

    if cli not in SUPPORTED_CLIS:
        raise ValueError(f"Unsupported CLI: {cli}. Use one of: {SUPPORTED_CLIS}")

    if not check_cli_available(cli):
        raise RuntimeError(f"CLI '{cli}' not found in PATH")

    # Initialize DB if needed
    init_db()

    session_id = get_current_session()
    job_id = f"job_{uuid.uuid4().hex[:12]}"

    job = Job(
        id=job_id,
        session_id=session_id,
        cli=cli,
        prompt=prompt,
        status="running",
        model=model,
        files=files
    )
    save_job(job)

    # Start background thread - runs in tmux window with TUI for visibility
    thread = threading.Thread(
        target=run_job_in_tmux,
        args=(job,),
        kwargs={"log_intermediary": log_intermediary, "auto_close": auto_close},
        daemon=True
    )
    thread.start()

    return json.dumps({
        "job_id": job_id,
        "window_id": None,  # Will be set once tmux window is created
        "message": f"Job started in background. Use ai_fetch('{job_id}') to get results, or switch to tmux window to watch."
    })


@mcp.tool()
def ai_fetch(
    job_id: str,
    block: bool = True,
    timeout: int = 300
) -> str:
    """
    Get the result of an AI job.

    Args:
        job_id: Job ID from ai_spawn
        block: Whether to wait for completion (default: True)
        timeout: Max seconds to wait if blocking (default: 300)

    Returns:
        JSON with status, result, and messages
    """
    init_db()
    session_id = get_current_session()

    start = time.time()
    while True:
        job = get_job(job_id, session_id)
        if not job:
            return json.dumps({"error": f"Job {job_id} not found in session {session_id}"})

        if job.status != "running" or not block:
            messages = get_messages(job_id)
            return json.dumps({
                "job_id": job.id,
                "status": job.status,
                "result": job.result,
                "window_id": job.window_id,
                "messages": [asdict(m) for m in messages]
            }, indent=2)

        if time.time() - start > timeout:
            return json.dumps({
                "job_id": job.id,
                "status": "timeout",
                "result": None,
                "window_id": job.window_id,
                "messages": []
            })

        time.sleep(1)


@mcp.tool()
def ai_stream(
    job_id: str,
    offset: int = 0
) -> str:
    """
    Get streaming output from a running job.

    Args:
        job_id: Job ID to stream from
        offset: Byte offset to start reading from (for incremental reads)

    Returns:
        JSON with new output, new offset, and done flag
    """
    init_db()
    session_id = get_current_session()

    job = get_job(job_id, session_id)
    if not job:
        return json.dumps({"error": f"Job {job_id} not found"})

    output_path = get_output_file_path(job_id)

    new_output = ""
    new_offset = offset

    if output_path.exists():
        with open(output_path, 'r') as f:
            f.seek(offset)
            new_output = f.read()
            new_offset = f.tell()

    return json.dumps({
        "output": new_output,
        "offset": new_offset,
        "done": job.status != "running"
    })


@mcp.tool()
def ai_ask(
    prompt: str,
    cli: str = "claude",
    model: str = "",
    files: list = None,
    log_intermediary: bool = False
) -> str:
    """
    Synchronous AI query - spawns job and waits for result.

    Args:
        prompt: The question/task for the AI
        cli: Which CLI to use - "claude", "codex", or "gemini"
        model: Optional model override
        files: Optional list of files to include as context
        log_intermediary: Log intermediary messages to SQLite (default: False)

    Returns:
        JSON with job_id and result
    """
    spawn_result = json.loads(ai_spawn(prompt, cli, model, files, log_intermediary, auto_close=True))
    job_id = spawn_result["job_id"]
    return ai_fetch(job_id, block=True, timeout=300)


@mcp.tool()
def ai_send(
    job_id: str,
    message: str,
    sender: str = "",
    msg_type: str = "intermediate"
) -> str:
    """
    Send a message to a job (for inter-agent communication).

    Args:
        job_id: Target job ID
        message: Message content
        sender: Optional sender identifier
        msg_type: Message type - "intermediate" or "final"

    Returns:
        Success message or error
    """
    init_db()
    session_id = get_current_session()

    job = get_job(job_id, session_id)
    if not job:
        return f"Error: Job {job_id} not found"

    msg = Message(
        id=f"msg_{uuid.uuid4().hex[:12]}",
        job_id=job_id,
        sender=sender or session_id,
        content=message,
        msg_type=msg_type,
        timestamp=time.time()
    )
    save_message(msg)

    return "Message sent"


@mcp.tool()
def ai_receive(
    job_id: str,
    since: int = 0
) -> str:
    """
    Get messages for a job.

    Args:
        job_id: Job ID to get messages for
        since: Message index to start from (for pagination)

    Returns:
        JSON list of messages
    """
    init_db()
    session_id = get_current_session()

    job = get_job(job_id, session_id)
    if not job:
        return json.dumps({"error": f"Job {job_id} not found"})

    messages = get_messages(job_id, since)
    return json.dumps([asdict(m) for m in messages], indent=2)


@mcp.tool()
def ai_list(
    status: str = ""
) -> str:
    """
    List AI jobs in the current session.

    Args:
        status: Filter by status - "running", "completed", "failed", or "" for all

    Returns:
        JSON list of jobs
    """
    init_db()
    session_id = get_current_session()

    jobs = list_jobs(session_id, status)
    return json.dumps([
        {
            "job_id": j.id,
            "cli": j.cli,
            "status": j.status,
            "created": j.created,
            "window_id": j.window_id,
            "prompt": j.prompt[:50] + "..." if len(j.prompt) > 50 else j.prompt
        }
        for j in jobs
    ], indent=2)


@mcp.tool()
def ai_review(
    cli: str = "codex",
    uncommitted: bool = True,
    base: str = "",
    focus: str = ""
) -> str:
    """
    Run a code review using an AI CLI.

    Args:
        cli: Which CLI to use - "codex" (native), "claude", or "gemini"
        uncommitted: Review uncommitted changes (default: True)
        base: Branch to compare against (for committed changes)
        focus: Review focus - "security", "performance", "quality", or ""

    Returns:
        JSON with job_id and result
    """
    if cli == "codex":
        # Codex has native review command
        cmd = ["codex", "exec", "review"]
        if uncommitted:
            cmd.append("--uncommitted")
        elif base:
            cmd.extend(["--base", base])

        init_db()
        session_id = get_current_session()
        job_id = f"job_{uuid.uuid4().hex[:12]}"

        # Run directly (simpler for codex review)
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
            output = result.stdout + result.stderr
            status = "completed" if result.returncode == 0 else "failed"
        except Exception as e:
            output = str(e)
            status = "failed"

        job = Job(
            id=job_id,
            session_id=session_id,
            cli=cli,
            prompt="code review",
            status=status,
            result=output
        )
        save_job(job)

        return json.dumps({"job_id": job_id, "result": output}, indent=2)

    else:
        # For claude/gemini, get diff and prompt
        try:
            if uncommitted:
                diff_result = subprocess.run(
                    ["git", "diff", "HEAD"],
                    capture_output=True, text=True
                )
            else:
                diff_result = subprocess.run(
                    ["git", "diff", base or "origin/main", "HEAD"],
                    capture_output=True, text=True
                )
            diff = diff_result.stdout
        except Exception as e:
            return json.dumps({"error": f"Failed to get diff: {e}"})

        focus_instruction = ""
        if focus:
            focus_instruction = f"Focus especially on {focus} aspects. "

        prompt = f"""Please review the following code changes. {focus_instruction}
Provide feedback on:
- Code quality and best practices
- Potential bugs or issues
- Suggestions for improvement

```diff
{diff[:10000]}
```
"""
        return ai_ask(prompt, cli)


@mcp.tool()
def ai_search(
    query: str,
    cli: str = "gemini"
) -> str:
    """
    Perform a web search using an AI CLI.

    Args:
        query: Search query
        cli: Which CLI to use - "gemini" (native --search) or "claude"

    Returns:
        JSON with job_id and result
    """
    if cli == "gemini":
        # Gemini has native search
        cmd = ["gemini", "--search", query]

        init_db()
        session_id = get_current_session()
        job_id = f"job_{uuid.uuid4().hex[:12]}"

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            output = result.stdout
            status = "completed" if result.returncode == 0 else "failed"
        except Exception as e:
            output = str(e)
            status = "failed"

        job = Job(
            id=job_id,
            session_id=session_id,
            cli=cli,
            prompt=f"search: {query}",
            status=status,
            result=output
        )
        save_job(job)

        return json.dumps({"job_id": job_id, "result": output}, indent=2)

    else:
        # For claude, use prompt with web search request
        prompt = f"Please search the web and answer: {query}"
        return ai_ask(prompt, cli)


# =============================================================================
# Main
# =============================================================================

# Initialize database on module load
init_db()

if __name__ == "__main__":
    mcp.run()
