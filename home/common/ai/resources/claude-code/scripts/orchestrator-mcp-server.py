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


def make_window_name(cli: str, prompt: str, job_id: str) -> str:
    """Create a human-readable window name from job details.

    Format: "cli: task_summary #id"
    Example: "claude: review auth #ab12"
    """
    # Extract first 3 words from prompt, cleaned up
    words = prompt.split()[:3]
    # Remove special chars, limit each word
    clean_words = []
    for w in words:
        # Keep only alphanumeric
        cleaned = re.sub(r'[^a-zA-Z0-9]', '', w)[:10]
        if cleaned:
            clean_words.append(cleaned.lower())

    task = " ".join(clean_words) if clean_words else "task"
    short_id = job_id[-4:]

    # Keep total length reasonable for tmux status bar
    if len(task) > 20:
        task = task[:17] + "..."

    return f"{cli}: {task} #{short_id}"


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
    task_id: Optional[str] = None  # Associated task ID


# Task Management Status Values
TASK_STATUSES = {
    "backlog", "todo", "discussing", "in_progress", "review", "qa",
    "done", "blocked", "stalled", "failed", "rejected"
}


@dataclass
class Task:
    """Represents a task in the task management system."""
    id: str
    repo_path: str
    title: str
    description: str = ""
    status: str = "backlog"  # One of TASK_STATUSES
    result: str = ""
    priority: int = 2  # 1=highest, 5=lowest
    discussion_round: int = 0  # Track idealization rounds (max 3)
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)
    completed_at: Optional[float] = None
    assigned_to: Optional[str] = None  # Current job_id
    created_by: str = ""  # user, orchestrator, or agent job_id
    parent_task_id: Optional[str] = None  # For subtasks
    tags: list = field(default_factory=list)
    acceptance_criteria: list = field(default_factory=list)
    context_files: list = field(default_factory=list)
    dependencies: list = field(default_factory=list)
    deadline: Optional[float] = None


@dataclass
class TaskComment:
    """A comment on a task from a user or agent."""
    id: str
    task_id: str
    job_id: Optional[str]  # Which agent made the comment (null if user)
    agent_type: str  # claude, codex, gemini, user
    content: str
    comment_type: str = "note"  # note, suggestion, issue, approval, rejection
    created_at: float = field(default_factory=time.time)


@dataclass
class TaskDiscussionVote:
    """Discussion phase vote from an agent."""
    id: str
    task_id: str
    job_id: str
    agent_type: str  # claude, codex, gemini
    vote: str  # ready, needs_work
    approach_summary: str = ""
    concerns: list = field(default_factory=list)
    suggestions: list = field(default_factory=list)
    created_at: float = field(default_factory=time.time)


@dataclass
class TaskQAVote:
    """QA phase vote from an agent."""
    id: str
    task_id: str
    job_id: str
    agent_type: str  # claude, codex, gemini
    vote: str  # approve, reject
    reason: str = ""
    created_at: float = field(default_factory=time.time)


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
            # Step 1: Create tables (without indexes that depend on migrated columns)
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
                    window_id TEXT
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

                -- Task Management Tables
                CREATE TABLE IF NOT EXISTS tasks (
                    id TEXT PRIMARY KEY,
                    repo_path TEXT NOT NULL,
                    title TEXT NOT NULL,
                    description TEXT DEFAULT '',
                    status TEXT DEFAULT 'backlog',
                    result TEXT DEFAULT '',
                    priority INTEGER DEFAULT 2,
                    discussion_round INTEGER DEFAULT 0,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    completed_at REAL,
                    assigned_to TEXT,
                    created_by TEXT DEFAULT '',
                    parent_task_id TEXT,
                    tags TEXT DEFAULT '[]',
                    acceptance_criteria TEXT DEFAULT '[]',
                    context_files TEXT DEFAULT '[]',
                    dependencies TEXT DEFAULT '[]',
                    deadline REAL
                );

                CREATE TABLE IF NOT EXISTS task_comments (
                    id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL,
                    job_id TEXT,
                    agent_type TEXT,
                    content TEXT NOT NULL,
                    comment_type TEXT DEFAULT 'note',
                    created_at REAL NOT NULL,
                    FOREIGN KEY (task_id) REFERENCES tasks(id)
                );

                CREATE TABLE IF NOT EXISTS task_discussion_votes (
                    id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL,
                    job_id TEXT NOT NULL,
                    agent_type TEXT NOT NULL,
                    vote TEXT NOT NULL,
                    approach_summary TEXT DEFAULT '',
                    concerns TEXT DEFAULT '[]',
                    suggestions TEXT DEFAULT '[]',
                    created_at REAL NOT NULL,
                    FOREIGN KEY (task_id) REFERENCES tasks(id)
                );

                CREATE TABLE IF NOT EXISTS task_qa_votes (
                    id TEXT PRIMARY KEY,
                    task_id TEXT NOT NULL,
                    job_id TEXT NOT NULL,
                    agent_type TEXT NOT NULL,
                    vote TEXT NOT NULL,
                    reason TEXT DEFAULT '',
                    created_at REAL NOT NULL,
                    FOREIGN KEY (task_id) REFERENCES tasks(id)
                );

                -- Indexes for existing columns only
                CREATE INDEX IF NOT EXISTS idx_jobs_session ON jobs(session_id);
                CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
                CREATE INDEX IF NOT EXISTS idx_messages_job ON messages(job_id);
                CREATE INDEX IF NOT EXISTS idx_tasks_repo ON tasks(repo_path);
                CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
                CREATE INDEX IF NOT EXISTS idx_tasks_parent ON tasks(parent_task_id);
                CREATE INDEX IF NOT EXISTS idx_comments_task ON task_comments(task_id);
                CREATE UNIQUE INDEX IF NOT EXISTS idx_discussion_vote_unique
                    ON task_discussion_votes(task_id, agent_type);
                CREATE UNIQUE INDEX IF NOT EXISTS idx_qa_vote_unique
                    ON task_qa_votes(task_id, agent_type);
            """)

            # Step 2: Migrations for existing tables (add new columns)
            migrations = [
                ("jobs", "worktree_path", "TEXT"),
                ("jobs", "task_id", "TEXT"),
            ]
            for table, column, coltype in migrations:
                try:
                    conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {coltype}")
                except sqlite3.OperationalError:
                    pass  # Column already exists

            # Step 3: Create indexes on migrated columns (after columns exist)
            try:
                conn.execute("CREATE INDEX IF NOT EXISTS idx_jobs_task ON jobs(task_id)")
            except sqlite3.OperationalError:
                pass  # Index may already exist

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
                (id, session_id, cli, prompt, status, result, output_offset, pid, created, model, files, window_id, worktree_path, task_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                job.id, job.session_id, job.cli, job.prompt, job.status,
                job.result, job.output_offset, job.pid, job.created,
                job.model, json.dumps(job.files), job.window_id, job.worktree_path,
                job.task_id
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
                    worktree_path=row['worktree_path'] if 'worktree_path' in row.keys() else None,
                    task_id=row['task_id'] if 'task_id' in row.keys() else None
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
                    worktree_path=row['worktree_path'] if 'worktree_path' in row.keys() else None,
                    task_id=row['task_id'] if 'task_id' in row.keys() else None
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
# Task Management Database Functions
# =============================================================================


def get_git_repo_path() -> Optional[str]:
    """Get the git repository root path for the current working directory."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return None
    except Exception:
        return None


def save_task(task: Task):
    """Save or update a task in the database."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute("""
                INSERT OR REPLACE INTO tasks
                (id, repo_path, title, description, status, result, priority,
                 discussion_round, created_at, updated_at, completed_at, assigned_to,
                 created_by, parent_task_id, tags, acceptance_criteria, context_files,
                 dependencies, deadline)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                task.id, task.repo_path, task.title, task.description, task.status,
                task.result, task.priority, task.discussion_round, task.created_at,
                task.updated_at, task.completed_at, task.assigned_to, task.created_by,
                task.parent_task_id, json.dumps(task.tags),
                json.dumps(task.acceptance_criteria), json.dumps(task.context_files),
                json.dumps(task.dependencies), task.deadline
            ))
            conn.commit()
        finally:
            conn.close()


def get_task(task_id: str, repo_path: Optional[str] = None) -> Optional[Task]:
    """Get a task by ID, optionally filtering by repository."""
    with _db_lock:
        conn = get_db_connection()
        try:
            if repo_path:
                row = conn.execute(
                    "SELECT * FROM tasks WHERE id = ? AND repo_path = ?",
                    (task_id, repo_path)
                ).fetchone()
            else:
                row = conn.execute(
                    "SELECT * FROM tasks WHERE id = ?",
                    (task_id,)
                ).fetchone()
            if row:
                return Task(
                    id=row['id'],
                    repo_path=row['repo_path'],
                    title=row['title'],
                    description=row['description'],
                    status=row['status'],
                    result=row['result'],
                    priority=row['priority'],
                    discussion_round=row['discussion_round'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    completed_at=row['completed_at'],
                    assigned_to=row['assigned_to'],
                    created_by=row['created_by'],
                    parent_task_id=row['parent_task_id'],
                    tags=json.loads(row['tags']),
                    acceptance_criteria=json.loads(row['acceptance_criteria']),
                    context_files=json.loads(row['context_files']),
                    dependencies=json.loads(row['dependencies']),
                    deadline=row['deadline']
                )
            return None
        finally:
            conn.close()


def list_tasks(
    repo_path: str,
    status: str = "",
    priority: Optional[int] = None,
    tag: str = "",
    parent_task_id: Optional[str] = None,
    assigned_to: Optional[str] = None
) -> list[Task]:
    """List tasks with optional filtering."""
    with _db_lock:
        conn = get_db_connection()
        try:
            query = "SELECT * FROM tasks WHERE repo_path = ?"
            params = [repo_path]

            if status:
                query += " AND status = ?"
                params.append(status)
            if priority is not None:
                query += " AND priority = ?"
                params.append(priority)
            if tag:
                # JSON array contains check
                query += " AND tags LIKE ?"
                params.append(f'%"{tag}"%')
            if parent_task_id is not None:
                query += " AND parent_task_id = ?"
                params.append(parent_task_id)
            if assigned_to is not None:
                query += " AND assigned_to = ?"
                params.append(assigned_to)

            query += " ORDER BY priority ASC, created_at DESC"

            rows = conn.execute(query, params).fetchall()
            return [
                Task(
                    id=row['id'],
                    repo_path=row['repo_path'],
                    title=row['title'],
                    description=row['description'],
                    status=row['status'],
                    result=row['result'],
                    priority=row['priority'],
                    discussion_round=row['discussion_round'],
                    created_at=row['created_at'],
                    updated_at=row['updated_at'],
                    completed_at=row['completed_at'],
                    assigned_to=row['assigned_to'],
                    created_by=row['created_by'],
                    parent_task_id=row['parent_task_id'],
                    tags=json.loads(row['tags']),
                    acceptance_criteria=json.loads(row['acceptance_criteria']),
                    context_files=json.loads(row['context_files']),
                    dependencies=json.loads(row['dependencies']),
                    deadline=row['deadline']
                )
                for row in rows
            ]
        finally:
            conn.close()


def save_task_comment(comment: TaskComment):
    """Save a comment to the database."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute("""
                INSERT INTO task_comments
                (id, task_id, job_id, agent_type, content, comment_type, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                comment.id, comment.task_id, comment.job_id, comment.agent_type,
                comment.content, comment.comment_type, comment.created_at
            ))
            conn.commit()
        finally:
            conn.close()


def get_task_comments(task_id: str) -> list[TaskComment]:
    """Get all comments for a task, ordered by creation time."""
    with _db_lock:
        conn = get_db_connection()
        try:
            rows = conn.execute(
                "SELECT * FROM task_comments WHERE task_id = ? ORDER BY created_at ASC",
                (task_id,)
            ).fetchall()
            return [
                TaskComment(
                    id=row['id'],
                    task_id=row['task_id'],
                    job_id=row['job_id'],
                    agent_type=row['agent_type'],
                    content=row['content'],
                    comment_type=row['comment_type'],
                    created_at=row['created_at']
                )
                for row in rows
            ]
        finally:
            conn.close()


def save_discussion_vote(vote: TaskDiscussionVote):
    """Save or update a discussion vote (unique per task + agent_type)."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute("""
                INSERT OR REPLACE INTO task_discussion_votes
                (id, task_id, job_id, agent_type, vote, approach_summary, concerns, suggestions, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                vote.id, vote.task_id, vote.job_id, vote.agent_type, vote.vote,
                vote.approach_summary, json.dumps(vote.concerns),
                json.dumps(vote.suggestions), vote.created_at
            ))
            conn.commit()
        finally:
            conn.close()


def get_discussion_votes(task_id: str) -> list[TaskDiscussionVote]:
    """Get all discussion votes for a task."""
    with _db_lock:
        conn = get_db_connection()
        try:
            rows = conn.execute(
                "SELECT * FROM task_discussion_votes WHERE task_id = ? ORDER BY created_at ASC",
                (task_id,)
            ).fetchall()
            return [
                TaskDiscussionVote(
                    id=row['id'],
                    task_id=row['task_id'],
                    job_id=row['job_id'],
                    agent_type=row['agent_type'],
                    vote=row['vote'],
                    approach_summary=row['approach_summary'],
                    concerns=json.loads(row['concerns']),
                    suggestions=json.loads(row['suggestions']),
                    created_at=row['created_at']
                )
                for row in rows
            ]
        finally:
            conn.close()


def clear_discussion_votes(task_id: str):
    """Clear all discussion votes for a task (for next round)."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute(
                "DELETE FROM task_discussion_votes WHERE task_id = ?",
                (task_id,)
            )
            conn.commit()
        finally:
            conn.close()


def save_qa_vote(vote: TaskQAVote):
    """Save or update a QA vote (unique per task + agent_type)."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute("""
                INSERT OR REPLACE INTO task_qa_votes
                (id, task_id, job_id, agent_type, vote, reason, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                vote.id, vote.task_id, vote.job_id, vote.agent_type,
                vote.vote, vote.reason, vote.created_at
            ))
            conn.commit()
        finally:
            conn.close()


def get_qa_votes(task_id: str) -> list[TaskQAVote]:
    """Get all QA votes for a task."""
    with _db_lock:
        conn = get_db_connection()
        try:
            rows = conn.execute(
                "SELECT * FROM task_qa_votes WHERE task_id = ? ORDER BY created_at ASC",
                (task_id,)
            ).fetchall()
            return [
                TaskQAVote(
                    id=row['id'],
                    task_id=row['task_id'],
                    job_id=row['job_id'],
                    agent_type=row['agent_type'],
                    vote=row['vote'],
                    reason=row['reason'],
                    created_at=row['created_at']
                )
                for row in rows
            ]
        finally:
            conn.close()


def clear_qa_votes(task_id: str):
    """Clear all QA votes for a task."""
    with _db_lock:
        conn = get_db_connection()
        try:
            conn.execute(
                "DELETE FROM task_qa_votes WHERE task_id = ?",
                (task_id,)
            )
            conn.commit()
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
        cmd = ["codex", "exec", "--full-auto", "--json", "--skip-git-repo-check"]
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

        # Human-readable window name
        window_name = make_window_name(job.cli, job.prompt, job.id)

        # Create window running orchestrator directly (no shell wrapper)
        # When orchestrator exits, the window closes automatically
        args = ["new-window", "-d", "-P", "-F", "#{window_id}", "-n", window_name] + runner_cmd
        output, code = run_tmux(*args)

        if code != 0:
            job.status = "failed"
            job.result = f"Error creating tmux window: {output}"
            save_job(job)
            return

        window_id = output.strip()
        job.window_id = window_id
        save_job(job)

        # Set pane title for nice display in tmux status bar
        pane_title = make_window_name(job.cli, job.prompt, job.id)
        run_tmux("select-pane", "-t", window_id, "-T", pane_title)

        # The orchestrator CLI now handles everything:
        # - Parsing JSON output
        # - Pretty-printing
        # - Updating the job status in SQLite
        # - Auto-closing the window
        #
        # We just need to wait for the window to close (if auto_close)
        # or for the command to finish.

        # Poll for window close (check every 2 seconds, timeout after 30 minutes)
        max_wait = 1800  # 30 minutes
        poll_interval = 2
        waited = 0

        while waited < max_wait:
            time.sleep(poll_interval)
            waited += poll_interval

            # Check if window still exists (closes when command exits)
            exists, _ = window_exists(window_id)
            if not exists:
                # Window closed - orchestrator CLI finished and updated job status
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
    worktree: bool = False,
    task_id: str = ""
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
        task_id: Optional task ID to associate with this job (provides context)

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

    # Get task and build enhanced prompt if task_id provided
    task = None
    enhanced_prompt = prompt
    if task_id:
        task = get_task(task_id)
        if not task:
            return json.dumps({
                "job_id": job_id,
                "status": "failed",
                "result": f"Task {task_id} not found"
            })
        # Determine role based on task status
        role = "general"
        if task.status == "discussing":
            role = "discussion"
        elif task.status == "in_progress":
            role = "dev"
        elif task.status == "review":
            role = "review"
        elif task.status == "qa":
            role = "qa"
        # Build enhanced prompt with task context
        enhanced_prompt = build_task_prompt(task, role, cli) + "\n\n" + prompt
        # Add context files to files list
        for cf in task.context_files:
            if cf not in files:
                files.append(cf)

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
        prompt=enhanced_prompt,
        status="running",
        model=model,
        files=files,
        worktree_path=str(worktree_path) if worktree_path else None,
        task_id=task_id if task_id else None
    )
    save_job(job)

    # Update task's assigned_to if task_id provided
    if task:
        task.assigned_to = job_id
        task.updated_at = time.time()
        save_task(task)

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

    # Human-readable window name
    window_name = make_window_name(cli, prompt, job_id)

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

    # Set pane title for nice display in tmux status bar
    run_tmux("select-pane", "-t", window_id, "-T", window_name)

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
    auto_close: bool = True,
    task_id: str = ""
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
        task_id: Optional task ID to associate with this job (provides context)

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

    # Get task and build enhanced prompt if task_id provided
    task = None
    enhanced_prompt = prompt
    if task_id:
        task = get_task(task_id)
        if not task:
            return json.dumps({
                "job_id": job_id,
                "status": "failed",
                "result": f"Task {task_id} not found"
            })
        # Determine role based on task status
        role = "general"
        if task.status == "discussing":
            role = "discussion"
        elif task.status == "in_progress":
            role = "dev"
        elif task.status == "review":
            role = "review"
        elif task.status == "qa":
            role = "qa"
        # Build enhanced prompt with task context
        enhanced_prompt = build_task_prompt(task, role, cli) + "\n\n" + prompt
        # Add context files to files list
        for cf in task.context_files:
            if cf not in files:
                files.append(cf)

    job = Job(
        id=job_id,
        session_id=session_id,
        cli=cli,
        prompt=enhanced_prompt,
        status="running",
        model=model,
        files=files,
        task_id=task_id if task_id else None
    )
    save_job(job)

    # Update task's assigned_to if task_id provided
    if task:
        task.assigned_to = job_id
        task.updated_at = time.time()
        save_task(task)

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
        "task_id": task_id if task_id else None,
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
# Task Management MCP Tools
# =============================================================================


@mcp.tool()
def task_create(
    title: str,
    description: str = "",
    priority: int = 2,
    tags: list = None,
    acceptance_criteria: list = None,
    context_files: list = None,
    dependencies: list = None,
    parent_task_id: str = "",
    created_by: str = "user"
) -> str:
    """
    Create a new task in the task management system.

    Args:
        title: Task title (required)
        description: Detailed task description
        priority: Priority level 1-5 (1=highest, default: 2)
        tags: List of tags for categorization
        acceptance_criteria: List of criteria for task completion
        context_files: List of relevant file paths
        dependencies: List of task IDs this task depends on
        parent_task_id: Parent task ID if this is a subtask
        created_by: Who created the task (user, orchestrator, or job_id)

    Returns:
        JSON with task_id and task details
    """
    init_db()

    repo_path = get_git_repo_path()
    if not repo_path:
        return json.dumps({"error": "Not in a git repository"})

    task_id = f"task_{uuid.uuid4().hex[:12]}"
    now = time.time()

    task = Task(
        id=task_id,
        repo_path=repo_path,
        title=title,
        description=description,
        status="backlog",
        priority=max(1, min(5, priority)),  # Clamp to 1-5
        created_at=now,
        updated_at=now,
        created_by=created_by,
        parent_task_id=parent_task_id if parent_task_id else None,
        tags=tags or [],
        acceptance_criteria=acceptance_criteria or [],
        context_files=context_files or [],
        dependencies=dependencies or []
    )
    save_task(task)

    return json.dumps({
        "task_id": task_id,
        "title": title,
        "status": "backlog",
        "priority": task.priority,
        "repo_path": repo_path,
        "message": f"Task '{title}' created successfully"
    }, indent=2)


@mcp.tool()
def task_list(
    status: str = "",
    priority: int = 0,
    tag: str = "",
    parent_task_id: str = ""
) -> str:
    """
    List tasks with optional filtering.

    Args:
        status: Filter by status (backlog, todo, discussing, in_progress, review, qa, done, blocked, stalled, failed, rejected)
        priority: Filter by priority (1-5, 0 for all)
        tag: Filter by tag
        parent_task_id: Filter by parent task ID (for subtasks)

    Returns:
        JSON list of tasks
    """
    init_db()

    repo_path = get_git_repo_path()
    if not repo_path:
        return json.dumps({"error": "Not in a git repository"})

    tasks = list_tasks(
        repo_path=repo_path,
        status=status if status else "",
        priority=priority if priority > 0 else None,
        tag=tag if tag else "",
        parent_task_id=parent_task_id if parent_task_id else None
    )

    return json.dumps([
        {
            "task_id": t.id,
            "title": t.title,
            "status": t.status,
            "priority": t.priority,
            "tags": t.tags,
            "assigned_to": t.assigned_to,
            "parent_task_id": t.parent_task_id,
            "created_at": t.created_at,
            "updated_at": t.updated_at
        }
        for t in tasks
    ], indent=2)


@mcp.tool()
def task_get(task_id: str) -> str:
    """
    Get full details of a task.

    Args:
        task_id: The task ID to retrieve

    Returns:
        JSON with complete task details including comments
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    comments = get_task_comments(task_id)
    discussion_votes = get_discussion_votes(task_id)
    qa_votes = get_qa_votes(task_id)

    return json.dumps({
        "task_id": task.id,
        "repo_path": task.repo_path,
        "title": task.title,
        "description": task.description,
        "status": task.status,
        "result": task.result,
        "priority": task.priority,
        "discussion_round": task.discussion_round,
        "created_at": task.created_at,
        "updated_at": task.updated_at,
        "completed_at": task.completed_at,
        "assigned_to": task.assigned_to,
        "created_by": task.created_by,
        "parent_task_id": task.parent_task_id,
        "tags": task.tags,
        "acceptance_criteria": task.acceptance_criteria,
        "context_files": task.context_files,
        "dependencies": task.dependencies,
        "deadline": task.deadline,
        "comments": [asdict(c) for c in comments],
        "discussion_votes": [asdict(v) for v in discussion_votes],
        "qa_votes": [asdict(v) for v in qa_votes]
    }, indent=2)


@mcp.tool()
def task_update(
    task_id: str,
    title: str = "",
    description: str = "",
    status: str = "",
    priority: int = 0,
    tags: list = None,
    acceptance_criteria: list = None,
    context_files: list = None,
    dependencies: list = None
) -> str:
    """
    Update task fields.

    Args:
        task_id: The task ID to update
        title: New title (empty to keep current)
        description: New description (empty to keep current)
        status: New status (empty to keep current)
        priority: New priority 1-5 (0 to keep current)
        tags: New tags list (None to keep current)
        acceptance_criteria: New criteria list (None to keep current)
        context_files: New files list (None to keep current)
        dependencies: New dependencies list (None to keep current)

    Returns:
        JSON with updated task details
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    # Update fields if provided
    if title:
        task.title = title
    if description:
        task.description = description
    if status:
        if status not in TASK_STATUSES:
            return json.dumps({"error": f"Invalid status: {status}. Valid: {TASK_STATUSES}"})
        task.status = status
    if priority > 0:
        task.priority = max(1, min(5, priority))
    if tags is not None:
        task.tags = tags
    if acceptance_criteria is not None:
        task.acceptance_criteria = acceptance_criteria
    if context_files is not None:
        task.context_files = context_files
    if dependencies is not None:
        task.dependencies = dependencies

    task.updated_at = time.time()
    save_task(task)

    return json.dumps({
        "task_id": task.id,
        "title": task.title,
        "status": task.status,
        "priority": task.priority,
        "message": "Task updated successfully"
    }, indent=2)


@mcp.tool()
def task_complete(
    task_id: str,
    result: str
) -> str:
    """
    Mark a task as completed with a result summary.

    Args:
        task_id: The task ID to complete
        result: Summary of what was accomplished

    Returns:
        JSON with completion status
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    # Check if all subtasks are completed
    repo_path = task.repo_path
    subtasks = list_tasks(repo_path=repo_path, parent_task_id=task_id)
    incomplete_subtasks = [st for st in subtasks if st.status != "done"]
    if incomplete_subtasks:
        return json.dumps({
            "error": "Cannot complete task with incomplete subtasks",
            "incomplete_subtasks": [{"id": st.id, "title": st.title, "status": st.status} for st in incomplete_subtasks]
        })

    task.status = "done"
    task.result = result
    task.completed_at = time.time()
    task.updated_at = time.time()
    save_task(task)

    return json.dumps({
        "task_id": task.id,
        "title": task.title,
        "status": "done",
        "result": result,
        "completed_at": task.completed_at,
        "message": "Task completed successfully"
    }, indent=2)


@mcp.tool()
def task_cancel(
    task_id: str,
    reason: str = ""
) -> str:
    """
    Cancel a task.

    Args:
        task_id: The task ID to cancel
        reason: Optional reason for cancellation

    Returns:
        JSON with cancellation status
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status == "done":
        return json.dumps({"error": "Cannot cancel a completed task"})

    task.status = "failed"
    task.result = f"Cancelled: {reason}" if reason else "Cancelled"
    task.updated_at = time.time()
    save_task(task)

    return json.dumps({
        "task_id": task.id,
        "title": task.title,
        "status": "failed",
        "message": "Task cancelled"
    }, indent=2)


@mcp.tool()
def task_comment(
    task_id: str,
    content: str,
    comment_type: str = "note",
    agent_type: str = "user",
    job_id: str = ""
) -> str:
    """
    Add a comment to a task.

    Args:
        task_id: The task ID to comment on
        content: Comment content
        comment_type: Type of comment (note, suggestion, issue, approval, rejection)
        agent_type: Who is commenting (user, claude, codex, gemini)
        job_id: Job ID if commenting from an agent

    Returns:
        JSON with comment details
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    valid_types = {"note", "suggestion", "issue", "approval", "rejection"}
    if comment_type not in valid_types:
        return json.dumps({"error": f"Invalid comment_type: {comment_type}. Valid: {valid_types}"})

    comment_id = f"comment_{uuid.uuid4().hex[:12]}"
    comment = TaskComment(
        id=comment_id,
        task_id=task_id,
        job_id=job_id if job_id else None,
        agent_type=agent_type,
        content=content,
        comment_type=comment_type,
        created_at=time.time()
    )
    save_task_comment(comment)

    return json.dumps({
        "comment_id": comment_id,
        "task_id": task_id,
        "agent_type": agent_type,
        "comment_type": comment_type,
        "message": "Comment added successfully"
    }, indent=2)


@mcp.tool()
def task_comments(task_id: str) -> str:
    """
    Get all comments for a task.

    Args:
        task_id: The task ID to get comments for

    Returns:
        JSON list of comments
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    comments = get_task_comments(task_id)

    return json.dumps([
        {
            "comment_id": c.id,
            "agent_type": c.agent_type,
            "job_id": c.job_id,
            "content": c.content,
            "comment_type": c.comment_type,
            "created_at": c.created_at
        }
        for c in comments
    ], indent=2)


# =============================================================================
# Task Workflow MCP Tools
# =============================================================================


def build_task_prompt(task: Task, role: str, agent_type: str) -> str:
    """Build a prompt with task context for an agent.

    Args:
        task: The task to build context for
        role: The role (discussion, dev, review, qa)
        agent_type: Which agent (claude, codex, gemini)

    Returns:
        A prompt string with task context
    """
    # Get previous comments for context
    comments = get_task_comments(task.id)
    comments_text = ""
    if comments:
        comments_text = "\n=== PREVIOUS COMMENTS ===\n"
        for c in comments:
            comments_text += f"[{c.agent_type}] ({c.comment_type}): {c.content}\n"

    # Get previous discussion votes if in discussion
    votes_text = ""
    if role == "discussion":
        votes = get_discussion_votes(task.id)
        if votes:
            votes_text = "\n=== PREVIOUS DISCUSSION VOTES ===\n"
            for v in votes:
                votes_text += f"[{v.agent_type}] voted '{v.vote}': {v.approach_summary}\n"
                if v.concerns:
                    votes_text += f"  Concerns: {', '.join(v.concerns)}\n"

    # Build acceptance criteria text
    criteria_text = ""
    if task.acceptance_criteria:
        criteria_text = "\n".join(f"- {c}" for c in task.acceptance_criteria)
    else:
        criteria_text = "No specific acceptance criteria defined."

    # Build context files text
    files_text = ""
    if task.context_files:
        files_text = "\n".join(f"- {f}" for f in task.context_files)
    else:
        files_text = "No specific files referenced."

    # Role-specific instructions
    role_instructions = {
        "discussion": {
            "claude": """You are participating in a DISCUSSION phase to reach consensus on implementation approach.

Your responsibilities:
1. Analyze the task requirements and acceptance criteria
2. Propose an implementation approach (architecture, patterns, file structure)
3. Raise any concerns or potential issues
4. Add comments using: task_comment(task_id, content, comment_type="suggestion")
5. When ready, vote using: task_discussion_vote(task_id, vote, approach_summary, concerns, suggestions)

Vote 'ready' if you believe the team has consensus on approach.
Vote 'needs_work' if there are unresolved concerns.

You are operating in READ-ONLY mode for this phase.""",

            "codex": """You are participating in a DISCUSSION phase to reach consensus on implementation approach.

Your responsibilities:
1. Review the task for technical feasibility
2. Identify potential edge cases and code conflicts
3. Point out any technical concerns
4. Add comments using: task_comment(task_id, content, comment_type="issue")
5. When ready, vote using: task_discussion_vote(task_id, vote, approach_summary, concerns, suggestions)

Vote 'ready' if the approach is technically sound.
Vote 'needs_work' if there are unresolved technical issues.

You are operating in READ-ONLY mode - analyze and comment only.""",

            "gemini": """You are participating in a DISCUSSION phase to reach consensus on implementation approach.

Your responsibilities:
1. Research best practices for this type of implementation
2. Find similar implementations or relevant documentation
3. Suggest industry-standard patterns that apply
4. Add comments using: task_comment(task_id, content, comment_type="suggestion")
5. When ready, vote using: task_discussion_vote(task_id, vote, approach_summary, concerns, suggestions)

Vote 'ready' if the approach follows best practices.
Vote 'needs_work' if important best practices are being ignored.

You are operating in READ-ONLY mode - research and comment only."""
        },
        "dev": """You are assigned to IMPLEMENT this task.

Your responsibilities:
1. Implement the task according to the agreed approach
2. Follow the acceptance criteria
3. Add progress comments using: task_comment(task_id, content, comment_type="note")
4. When done, submit for review using: task_submit_review(task_id)

You have FULL ACCESS to modify files and run commands.
Work on the actual repository, not a worktree.""",

        "review": """You are assigned to REVIEW the implementation of this task.

Your responsibilities:
1. Review the code changes for bugs, security issues, and quality
2. Check that acceptance criteria are met
3. Add comments with findings using: task_comment(task_id, content, comment_type="issue")
4. When done, vote using: task_review_complete(task_id, approved, feedback)

Set approved=True to move to QA, approved=False to reject back to dev.

You are operating in READ-ONLY mode.""",

        "qa": {
            "claude": """You are part of the QA phase validating this task.

Your responsibilities:
1. Check that all acceptance criteria are met
2. Look for edge cases and potential issues
3. Verify functionality works as expected
4. Add comments using: task_comment(task_id, content, comment_type="issue")
5. When done, vote using: task_qa_vote(task_id, vote, reason)

Vote 'approve' if acceptance criteria are met.
Vote 'reject' if there are issues that need fixing.

You are operating in READ-ONLY mode.""",

            "codex": """You are part of the QA phase validating this task.

Your responsibilities:
1. Check code quality and adherence to patterns
2. Look for potential bugs or edge cases
3. Verify the implementation is clean and maintainable
4. Add comments using: task_comment(task_id, content, comment_type="issue")
5. When done, vote using: task_qa_vote(task_id, vote, reason)

Vote 'approve' if code quality meets standards.
Vote 'reject' if there are quality issues.

You are operating in READ-ONLY mode.""",

            "gemini": """You are part of the QA phase validating this task.

Your responsibilities:
1. Check that documentation is adequate
2. Verify best practices are followed
3. Research if there are better approaches
4. Add comments using: task_comment(task_id, content, comment_type="suggestion")
5. When done, vote using: task_qa_vote(task_id, vote, reason)

Vote 'approve' if documentation and practices are adequate.
Vote 'reject' if important best practices are missing.

You are operating in READ-ONLY mode."""
        }
    }

    # Get the appropriate instructions
    if role == "discussion":
        instructions = role_instructions["discussion"].get(agent_type, role_instructions["discussion"]["claude"])
    elif role == "qa":
        instructions = role_instructions["qa"].get(agent_type, role_instructions["qa"]["claude"])
    else:
        instructions = role_instructions.get(role, "")

    prompt = f"""=== ASSIGNED TASK ===
Task ID: {task.id}
Title: {task.title}
Status: {task.status}
Priority: {task.priority}
Discussion Round: {task.discussion_round}

Description:
{task.description or "No description provided."}

Acceptance Criteria:
{criteria_text}

Context Files:
{files_text}
{comments_text}
{votes_text}
=== INSTRUCTIONS ===
{instructions}

=== BEGIN WORK ===
"""
    return prompt


def check_discussion_complete(task_id: str) -> Optional[str]:
    """Check if discussion phase is complete and determine next status.

    Returns:
        - "in_progress" if all 3 agents voted ready (unanimous consensus)
        - "discussing" if needs another round (some voted needs_work)
        - "stalled" if max rounds reached
        - None if still waiting for votes
    """
    task = get_task(task_id)
    if not task:
        return None

    votes = get_discussion_votes(task_id)
    if len(votes) < 3:
        return None  # Still waiting for all agents

    ready_count = sum(1 for v in votes if v.vote == "ready")

    if ready_count == 3:  # Unanimous consensus
        # Compile approach from all agents' summaries
        combined_approach = "\n\n".join([
            f"**{v.agent_type.upper()} Approach:**\n{v.approach_summary}"
            for v in votes if v.approach_summary
        ])
        # Update task description with compiled approach
        task.description = f"{task.description}\n\n=== AGREED APPROACH ===\n{combined_approach}"
        task.status = "in_progress"
        task.updated_at = time.time()
        save_task(task)
        return "in_progress"
    else:
        # Increment discussion round
        round_num = task.discussion_round + 1
        if round_num >= 3:
            task.status = "stalled"
            task.result = "Discussion could not reach consensus after 3 rounds"
            task.updated_at = time.time()
            save_task(task)
            return "stalled"
        # Clear votes for next round, keep comments
        clear_discussion_votes(task_id)
        task.discussion_round = round_num
        task.updated_at = time.time()
        save_task(task)
        return "discussing"  # Stay in discussing


def check_qa_complete(task_id: str) -> Optional[str]:
    """Check if QA phase is complete and determine next status.

    Returns:
        - "done" if majority approval (2+ approve)
        - "rejected" if majority rejection
        - None if still waiting for votes
    """
    task = get_task(task_id)
    if not task:
        return None

    votes = get_qa_votes(task_id)
    if len(votes) < 3:
        return None  # Still waiting for all agents

    approvals = sum(1 for v in votes if v.vote == "approve")

    if approvals >= 2:  # Majority approval
        task.status = "done"
        task.completed_at = time.time()
        task.updated_at = time.time()
        task.result = "QA passed with majority approval"
        save_task(task)
        return "done"
    else:
        task.status = "rejected"
        task.updated_at = time.time()
        # Compile rejection reasons
        rejections = [v.reason for v in votes if v.vote == "reject" and v.reason]
        task.result = "QA failed: " + "; ".join(rejections)
        save_task(task)
        return "rejected"


@mcp.tool()
def task_start_discussion(task_id: str) -> str:
    """
    Start the discussion phase for a task.

    Moves task to 'discussing' status and spawns 3 agents (Claude, Codex, Gemini)
    in parallel to analyze requirements and propose implementation approaches.

    Args:
        task_id: The task ID to start discussion for

    Returns:
        JSON with spawned job IDs
    """
    init_db()
    require_tmux()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    # Must be in backlog or todo to start discussion
    if task.status not in ("backlog", "todo"):
        return json.dumps({"error": f"Task must be in backlog or todo to start discussion, current: {task.status}"})

    # Move to discussing
    task.status = "discussing"
    task.discussion_round = 0
    task.updated_at = time.time()
    save_task(task)

    # Clear any existing votes from previous attempts
    clear_discussion_votes(task_id)

    # Spawn 3 agents in parallel (all read-only for discussion)
    session_id = get_current_session()
    jobs = []

    for cli in ["claude", "codex", "gemini"]:
        prompt = build_task_prompt(task, "discussion", cli)
        job_id = f"job_{uuid.uuid4().hex[:12]}"

        job = Job(
            id=job_id,
            session_id=session_id,
            cli=cli,
            prompt=prompt,
            status="running",
            task_id=task_id
        )
        save_job(job)

        # Start in background thread with tmux TUI
        thread = threading.Thread(
            target=run_job_in_tmux,
            args=(job,),
            kwargs={"log_intermediary": False, "auto_close": True},
            daemon=True
        )
        thread.start()
        jobs.append({"job_id": job_id, "cli": cli})

    return json.dumps({
        "task_id": task_id,
        "status": "discussing",
        "discussion_round": 0,
        "spawned_jobs": jobs,
        "message": "Discussion phase started with 3 agents"
    }, indent=2)


@mcp.tool()
def task_discussion_vote(
    task_id: str,
    vote: str,
    approach_summary: str = "",
    concerns: list = None,
    suggestions: list = None,
    agent_type: str = "",
    job_id: str = ""
) -> str:
    """
    Cast a vote in the discussion phase.

    Args:
        task_id: The task ID to vote on
        vote: Either 'ready' (proceed to dev) or 'needs_work' (more discussion)
        approach_summary: Summary of recommended approach
        concerns: List of concerns raised
        suggestions: List of suggestions
        agent_type: The agent type voting (claude, codex, gemini)
        job_id: The job ID of the voting agent

    Returns:
        JSON with vote status and any resolution
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status != "discussing":
        return json.dumps({"error": f"Task is not in discussing phase, current: {task.status}"})

    if vote not in ("ready", "needs_work"):
        return json.dumps({"error": "Vote must be 'ready' or 'needs_work'"})

    if not agent_type:
        return json.dumps({"error": "agent_type is required"})

    vote_id = f"vote_{uuid.uuid4().hex[:12]}"
    discussion_vote = TaskDiscussionVote(
        id=vote_id,
        task_id=task_id,
        job_id=job_id,
        agent_type=agent_type,
        vote=vote,
        approach_summary=approach_summary,
        concerns=concerns or [],
        suggestions=suggestions or [],
        created_at=time.time()
    )
    save_discussion_vote(discussion_vote)

    # Check if discussion is complete
    resolution = check_discussion_complete(task_id)

    return json.dumps({
        "vote_id": vote_id,
        "task_id": task_id,
        "vote": vote,
        "resolution": resolution,
        "message": f"Vote recorded. Resolution: {resolution or 'waiting for more votes'}"
    }, indent=2)


@mcp.tool()
def task_start_dev(task_id: str) -> str:
    """
    Start development on a task.

    Moves task to 'in_progress' and spawns a Claude agent with full access
    to implement the task. No worktree is used - works on actual repo.

    Args:
        task_id: The task ID to start development on

    Returns:
        JSON with spawned job ID
    """
    init_db()
    require_tmux()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    # Can start dev from discussing (after consensus) or todo (skipping discussion)
    if task.status not in ("discussing", "todo", "rejected"):
        return json.dumps({"error": f"Task must be in discussing, todo, or rejected to start dev, current: {task.status}"})

    # Move to in_progress
    task.status = "in_progress"
    task.updated_at = time.time()
    save_task(task)

    # Spawn Claude agent with full access (no worktree)
    session_id = get_current_session()
    prompt = build_task_prompt(task, "dev", "claude")
    job_id = f"job_{uuid.uuid4().hex[:12]}"

    job = Job(
        id=job_id,
        session_id=session_id,
        cli="claude",
        prompt=prompt,
        status="running",
        task_id=task_id
    )
    save_job(job)

    # Update task assignment
    task.assigned_to = job_id
    save_task(task)

    # Start in background with tmux TUI
    thread = threading.Thread(
        target=run_job_in_tmux,
        args=(job,),
        kwargs={"log_intermediary": False, "auto_close": True},
        daemon=True
    )
    thread.start()

    return json.dumps({
        "task_id": task_id,
        "status": "in_progress",
        "job_id": job_id,
        "message": "Development started with Claude agent"
    }, indent=2)


@mcp.tool()
def task_submit_review(task_id: str) -> str:
    """
    Submit a task for code review.

    Moves task to 'review' status and spawns a Codex agent to review changes.

    Args:
        task_id: The task ID to submit for review

    Returns:
        JSON with spawned job ID
    """
    init_db()
    require_tmux()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status != "in_progress":
        return json.dumps({"error": f"Task must be in_progress to submit for review, current: {task.status}"})

    # Move to review
    task.status = "review"
    task.updated_at = time.time()
    save_task(task)

    # Spawn Codex reviewer (read-only)
    session_id = get_current_session()
    prompt = build_task_prompt(task, "review", "codex")
    job_id = f"job_{uuid.uuid4().hex[:12]}"

    job = Job(
        id=job_id,
        session_id=session_id,
        cli="codex",
        prompt=prompt,
        status="running",
        task_id=task_id
    )
    save_job(job)

    # Start in background with tmux TUI
    thread = threading.Thread(
        target=run_job_in_tmux,
        args=(job,),
        kwargs={"log_intermediary": False, "auto_close": True},
        daemon=True
    )
    thread.start()

    return json.dumps({
        "task_id": task_id,
        "status": "review",
        "job_id": job_id,
        "message": "Review started with Codex agent"
    }, indent=2)


@mcp.tool()
def task_review_complete(
    task_id: str,
    approved: bool,
    feedback: str = ""
) -> str:
    """
    Complete a code review with approval or rejection.

    Args:
        task_id: The task ID being reviewed
        approved: True to approve and move to QA, False to reject
        feedback: Review feedback

    Returns:
        JSON with result status
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status != "review":
        return json.dumps({"error": f"Task must be in review, current: {task.status}"})

    if approved:
        task.status = "qa"
        message = "Review approved, moving to QA"
    else:
        task.status = "rejected"
        task.result = f"Review rejected: {feedback}" if feedback else "Review rejected"
        message = "Review rejected, needs rework"

    task.updated_at = time.time()
    save_task(task)

    # Add review as a comment
    if feedback:
        comment = TaskComment(
            id=f"comment_{uuid.uuid4().hex[:12]}",
            task_id=task_id,
            job_id=None,
            agent_type="codex",
            content=feedback,
            comment_type="approval" if approved else "rejection",
            created_at=time.time()
        )
        save_task_comment(comment)

    return json.dumps({
        "task_id": task_id,
        "status": task.status,
        "approved": approved,
        "message": message
    }, indent=2)


@mcp.tool()
def task_start_qa(task_id: str) -> str:
    """
    Start QA validation for a task.

    Spawns 3 agents (Claude, Codex, Gemini) in parallel to verify
    acceptance criteria are met.

    Args:
        task_id: The task ID to start QA for

    Returns:
        JSON with spawned job IDs
    """
    init_db()
    require_tmux()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status != "qa":
        return json.dumps({"error": f"Task must be in qa status, current: {task.status}"})

    # Clear any existing QA votes
    clear_qa_votes(task_id)

    # Spawn 3 agents in parallel (all read-only for QA)
    session_id = get_current_session()
    jobs = []

    for cli in ["claude", "codex", "gemini"]:
        prompt = build_task_prompt(task, "qa", cli)
        job_id = f"job_{uuid.uuid4().hex[:12]}"

        job = Job(
            id=job_id,
            session_id=session_id,
            cli=cli,
            prompt=prompt,
            status="running",
            task_id=task_id
        )
        save_job(job)

        # Start in background thread with tmux TUI
        thread = threading.Thread(
            target=run_job_in_tmux,
            args=(job,),
            kwargs={"log_intermediary": False, "auto_close": True},
            daemon=True
        )
        thread.start()
        jobs.append({"job_id": job_id, "cli": cli})

    return json.dumps({
        "task_id": task_id,
        "status": "qa",
        "spawned_jobs": jobs,
        "message": "QA phase started with 3 agents"
    }, indent=2)


@mcp.tool()
def task_qa_vote(
    task_id: str,
    vote: str,
    reason: str = "",
    agent_type: str = "",
    job_id: str = ""
) -> str:
    """
    Cast a vote in the QA phase.

    Args:
        task_id: The task ID to vote on
        vote: Either 'approve' or 'reject'
        reason: Reason for the vote
        agent_type: The agent type voting (claude, codex, gemini)
        job_id: The job ID of the voting agent

    Returns:
        JSON with vote status and any resolution
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status != "qa":
        return json.dumps({"error": f"Task is not in QA phase, current: {task.status}"})

    if vote not in ("approve", "reject"):
        return json.dumps({"error": "Vote must be 'approve' or 'reject'"})

    if not agent_type:
        return json.dumps({"error": "agent_type is required"})

    vote_id = f"vote_{uuid.uuid4().hex[:12]}"
    qa_vote = TaskQAVote(
        id=vote_id,
        task_id=task_id,
        job_id=job_id,
        agent_type=agent_type,
        vote=vote,
        reason=reason,
        created_at=time.time()
    )
    save_qa_vote(qa_vote)

    # Check if QA is complete
    resolution = check_qa_complete(task_id)

    return json.dumps({
        "vote_id": vote_id,
        "task_id": task_id,
        "vote": vote,
        "resolution": resolution,
        "message": f"Vote recorded. Resolution: {resolution or 'waiting for more votes'}"
    }, indent=2)


@mcp.tool()
def task_reopen(task_id: str) -> str:
    """
    Reopen a rejected or stalled task for rework.

    Args:
        task_id: The task ID to reopen

    Returns:
        JSON with updated status
    """
    init_db()

    task = get_task(task_id)
    if not task:
        return json.dumps({"error": f"Task {task_id} not found"})

    if task.status not in ("rejected", "stalled", "failed"):
        return json.dumps({"error": f"Can only reopen rejected, stalled, or failed tasks, current: {task.status}"})

    task.status = "todo"
    task.assigned_to = None
    task.updated_at = time.time()
    save_task(task)

    return json.dumps({
        "task_id": task_id,
        "status": "todo",
        "message": "Task reopened and ready for work"
    }, indent=2)


# =============================================================================
# Main
# =============================================================================

# Initialize database on module load
init_db()

if __name__ == "__main__":
    mcp.run()
