#!/usr/bin/env python3
"""
Orchestrator CLI - Monitor and manage AI jobs from outside tmux.

Commands:
    sessions    List all tmux sessions with active jobs
    jobs        List jobs in a session
    status      Get details for a specific job
    kill        Terminate a running job
    messages    Show messages for a job
    stream      Tail streaming output from a job
    cleanup     Remove expired/completed jobs
    run         Run an AI CLI with TUI output (for tmux windows)
"""
import argparse
import asyncio
import json
import os
import shlex
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Optional

# TUI imports (required)
from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Static, RichLog
from textual.reactive import reactive
from rich.text import Text
from rich.markdown import Markdown
from rich.console import Console

DB_PATH = Path.home() / ".config" / "orchestrator-mcp" / "state.db"

# Catppuccin Macchiato color palette (256-color approximations)
# https://github.com/catppuccin/catppuccin
COLORS = {
    "reset": "\033[0m",
    "bold": "\033[1m",
    "dim": "\033[2m",
    # Catppuccin Macchiato colors using 24-bit/truecolor
    "rosewater": "\033[38;2;244;219;214m",   # #f4dbd6
    "flamingo": "\033[38;2;240;198;198m",    # #f0c6c6
    "pink": "\033[38;2;245;189;230m",        # #f5bde6
    "mauve": "\033[38;2;198;160;246m",       # #c6a0f6
    "red": "\033[38;2;237;135;150m",         # #ed8796
    "maroon": "\033[38;2;238;153;160m",      # #ee99a0
    "peach": "\033[38;2;245;169;127m",       # #f5a97f
    "yellow": "\033[38;2;238;212;159m",      # #eed49f
    "green": "\033[38;2;166;218;149m",       # #a6da95
    "teal": "\033[38;2;139;213;202m",        # #8bd5ca
    "sky": "\033[38;2;145;215;227m",         # #91d7e3
    "sapphire": "\033[38;2;125;196;228m",    # #7dc4e4
    "blue": "\033[38;2;138;173;244m",        # #8aadf4
    "lavender": "\033[38;2;183;189;248m",    # #b7bdf8
    "text": "\033[38;2;202;211;245m",        # #cad3f5
    "subtext1": "\033[38;2;184;192;224m",    # #b8c0e0
    "subtext0": "\033[38;2;165;173;203m",    # #a5adcb
    "overlay2": "\033[38;2;147;154;183m",    # #939ab7
    "overlay1": "\033[38;2;128;135;162m",    # #8087a2
    "overlay0": "\033[38;2;110;115;141m",    # #6e738d
    "surface2": "\033[38;2;91;96;120m",      # #5b6078
    "surface1": "\033[38;2;73;77;100m",      # #494d64
    "surface0": "\033[38;2;54;58;79m",       # #363a4f
}

AUTO_CLOSE_DELAY = 5  # seconds to wait before closing window


@dataclass
class ParsedMessage:
    """Parsed message from CLI JSON output."""
    cli: str                    # Source CLI
    msg_type: str              # "final", "reasoning", "assistant", "system", "tool"
    content: str               # Message text
    is_final: bool             # True for final result
    role: str = ""             # Role (assistant, user, system)
    tool_name: str = ""        # Current tool being used (if any)
    timestamp: float = field(default_factory=time.time)
    raw: dict = field(default_factory=dict)  # Original JSON for debugging


def _parse_claude_json(data: dict) -> Optional[ParsedMessage]:
    """Parse Claude JSON output.

    Claude format:
    - type: "result" with result field -> final
    - type: "assistant" -> intermediary
    - type: "tool_use" -> tool being used
    """
    msg_type = data.get("type", "")

    if msg_type == "result":
        # Final result
        result = data.get("result", "")
        if isinstance(result, dict):
            result = result.get("text", str(result))
        return ParsedMessage(
            cli="claude",
            msg_type="final",
            content=str(result),
            is_final=True,
            role="assistant",
            raw=data
        )

    elif msg_type == "assistant":
        # Intermediary assistant message
        content = data.get("message", {})
        if isinstance(content, dict):
            content = content.get("content", "")
            if isinstance(content, list):
                # Extract text from content blocks
                texts = []
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            texts.append(block.get("text", ""))
                        elif block.get("type") == "tool_use":
                            texts.append(f"[Using tool: {block.get('name', 'unknown')}]")
                content = "\n".join(texts)
        return ParsedMessage(
            cli="claude",
            msg_type="assistant",
            content=str(content),
            is_final=False,
            role="assistant",
            raw=data
        )

    elif msg_type == "tool_use":
        # Tool being used
        tool_name = data.get("name", "unknown")
        return ParsedMessage(
            cli="claude",
            msg_type="tool",
            content=f"Using: {tool_name}",
            is_final=False,
            tool_name=tool_name,
            raw=data
        )

    elif msg_type == "content_block_delta":
        # Streaming content
        delta = data.get("delta", {})
        if delta.get("type") == "text_delta":
            return ParsedMessage(
                cli="claude",
                msg_type="assistant",
                content=delta.get("text", ""),
                is_final=False,
                role="assistant",
                raw=data
            )

    return None


def _extract_text_from_content(content) -> str:
    """Extract text from various content structures."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = []
        for block in content:
            if isinstance(block, str):
                texts.append(block)
            elif isinstance(block, dict):
                # Try various text fields
                text = (
                    block.get("text") or
                    block.get("output_text") or
                    block.get("content") or
                    block.get("summary") or
                    ""
                )
                if text:
                    texts.append(str(text))
        return "\n".join(texts)
    if isinstance(content, dict):
        return content.get("text") or content.get("content") or content.get("summary") or ""
    return str(content) if content else ""


def _parse_codex_json(data: dict) -> Optional[ParsedMessage]:
    """Parse Codex JSON output (JSONL format).

    Actual Codex format (from codex --json):
    - type: "thread.started" -> session start
    - type: "turn.started" -> turn start
    - type: "item.completed" with item.type: "reasoning", item.text -> thinking
    - type: "item.completed" with item.type: "agent_message", item.text -> assistant
    - type: "item.completed" with item.type: "function_call" -> tool use
    - type: "turn.completed" -> final marker with usage stats
    """
    msg_type = data.get("type", "")

    # Session/turn markers (informational)
    if msg_type == "thread.started":
        thread_id = data.get("thread_id", "")
        return ParsedMessage(
            cli="codex",
            msg_type="system",
            content=f"Session started: {thread_id[:8]}..." if thread_id else "Session started",
            is_final=False,
            raw=data
        )

    if msg_type == "turn.started":
        return ParsedMessage(
            cli="codex",
            msg_type="system",
            content="Processing...",
            is_final=False,
            raw=data
        )

    # Item completed - main message format
    if msg_type == "item.completed":
        item = data.get("item", {})
        item_type = item.get("type", "")
        # NOTE: Codex uses "text" field, not "content"!
        item_text = item.get("text", "") or _extract_text_from_content(item.get("content", ""))

        if item_type == "agent_message":
            if item_text:
                return ParsedMessage(
                    cli="codex",
                    msg_type="assistant",
                    content=item_text,
                    is_final=False,
                    role="assistant",
                    raw=data
                )

        elif item_type == "reasoning":
            if item_text:
                return ParsedMessage(
                    cli="codex",
                    msg_type="reasoning",
                    content=item_text,
                    is_final=False,
                    role="assistant",
                    raw=data
                )

        elif item_type == "message":
            role = item.get("role", "assistant")
            if item_text:
                return ParsedMessage(
                    cli="codex",
                    msg_type="assistant" if role == "assistant" else "system",
                    content=item_text,
                    is_final=False,
                    role=role,
                    raw=data
                )

        elif item_type in ("function_call", "tool_use"):
            tool_name = item.get("name", item.get("call_id", "unknown"))
            return ParsedMessage(
                cli="codex",
                msg_type="tool",
                content=f"Using: {tool_name}",
                is_final=False,
                tool_name=tool_name,
                raw=data
            )

        elif item_type == "function_call_output":
            output = item_text or str(item.get("output", ""))
            if output:
                return ParsedMessage(
                    cli="codex",
                    msg_type="output",
                    content=output[:500] + "..." if len(output) > 500 else output,
                    is_final=False,
                    raw=data
                )

    # Turn completed - marks end of response
    if msg_type == "turn.completed":
        usage = data.get("usage", {})
        tokens = usage.get("output_tokens", 0)
        return ParsedMessage(
            cli="codex",
            msg_type="system",
            content=f"Completed ({tokens} tokens)",
            is_final=True,  # Mark as final to trigger result capture
            raw=data
        )

    # Handle streaming deltas (if any)
    if msg_type == "response.output_text.delta":
        text = data.get("delta", "")
        if text:
            return ParsedMessage(
                cli="codex",
                msg_type="assistant",
                content=text,
                is_final=False,
                role="assistant",
                raw=data
            )

    if msg_type == "response.reasoning_summary_text.delta":
        text = data.get("delta", "")
        if text:
            return ParsedMessage(
                cli="codex",
                msg_type="reasoning",
                content=text,
                is_final=False,
                role="assistant",
                raw=data
            )

    return None


def _parse_gemini_json(data: dict) -> Optional[ParsedMessage]:
    """Parse Gemini JSON output (stream-json format).

    Actual Gemini stream-json format:
    - type: "init" -> session start with model info
    - type: "message" with role: "user"/"assistant" and content -> messages
    - type: "result" with status and stats -> completion marker (no content)
    - type: "tool_call" / "tool_result" -> tool use
    """
    msg_type = data.get("type", "")

    # Session init
    if msg_type == "init":
        model = data.get("model", "unknown")
        session_id = data.get("session_id", "")
        return ParsedMessage(
            cli="gemini",
            msg_type="system",
            content=f"Model: {model}" + (f" | Session: {session_id[:8]}..." if session_id else ""),
            is_final=False,
            raw=data
        )

    # Messages (user or assistant)
    if msg_type == "message":
        role = data.get("role", "assistant")
        content = data.get("content", "")

        # Skip user messages in output
        if role == "user":
            return None

        if isinstance(content, list):
            texts = []
            for block in content:
                if isinstance(block, dict):
                    texts.append(block.get("text", ""))
                elif isinstance(block, str):
                    texts.append(block)
            content = "\n".join(texts)

        if content:
            # Check if this is a delta (streaming)
            is_delta = data.get("delta", False)
            return ParsedMessage(
                cli="gemini",
                msg_type="assistant",
                content=str(content),
                is_final=False,
                role=role,
                raw=data
            )

    # Result - completion marker (content is in previous messages)
    if msg_type == "result":
        status = data.get("status", "unknown")
        stats = data.get("stats", {})
        tokens = stats.get("output_tokens", stats.get("total_tokens", 0))
        duration = stats.get("duration_ms", 0)
        return ParsedMessage(
            cli="gemini",
            msg_type="system",
            content=f"Completed: {status} ({tokens} tokens, {duration}ms)",
            is_final=True,  # Mark as final to trigger result capture
            raw=data
        )

    # Tool calls
    if msg_type in ("tool_call", "tool_use", "function_call"):
        tool_name = data.get("name", data.get("tool", "unknown"))
        return ParsedMessage(
            cli="gemini",
            msg_type="tool",
            content=f"Using: {tool_name}",
            is_final=False,
            tool_name=tool_name,
            raw=data
        )

    # Tool results
    if msg_type in ("tool_result", "function_result"):
        output = _extract_text_from_content(data.get("output", data.get("result", "")))
        if output:
            return ParsedMessage(
                cli="gemini",
                msg_type="output",
                content=output[:500] + "..." if len(output) > 500 else output,
                is_final=False,
                raw=data
            )

    return None


class JsonBuffer:
    """Buffer for accumulating multiline JSON."""

    def __init__(self):
        self.buffer = ""
        self.brace_count = 0
        self.bracket_count = 0
        self.in_string = False
        self.escape_next = False

    def add_line(self, line: str) -> Optional[str]:
        """Add a line to the buffer. Returns complete JSON if found."""
        self.buffer += line

        # Track JSON structure
        for char in line:
            if self.escape_next:
                self.escape_next = False
                continue

            if char == '\\' and self.in_string:
                self.escape_next = True
                continue

            if char == '"' and not self.escape_next:
                self.in_string = not self.in_string
                continue

            if self.in_string:
                continue

            if char == '{':
                self.brace_count += 1
            elif char == '}':
                self.brace_count -= 1
            elif char == '[':
                self.bracket_count += 1
            elif char == ']':
                self.bracket_count -= 1

        # Check if we have a complete JSON object
        if self.brace_count == 0 and self.bracket_count == 0 and self.buffer.strip():
            result = self.buffer
            self.buffer = ""
            return result

        return None

    def reset(self):
        """Reset the buffer."""
        self.buffer = ""
        self.brace_count = 0
        self.bracket_count = 0
        self.in_string = False
        self.escape_next = False


def parse_cli_json_line(cli: str, line: str, json_buffer: Optional[JsonBuffer] = None) -> Optional[ParsedMessage]:
    """Parse a single JSON line from CLI output.

    For Gemini, use json_buffer to handle multiline JSON.
    Returns ParsedMessage or None if line should be skipped.
    """
    line = line.strip()
    if not line:
        return None

    # For Gemini, use buffer to handle multiline JSON
    if cli == "gemini" and json_buffer is not None:
        complete_json = json_buffer.add_line(line + "\n")
        if complete_json:
            try:
                data = json.loads(complete_json)
                return _parse_gemini_json(data)
            except json.JSONDecodeError:
                json_buffer.reset()
                return None
        return None

    # For JSONL formats (Claude, Codex), parse line by line
    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        # Not JSON, return as plain text only if it looks meaningful
        if line and not line.startswith('{') and not line.startswith('['):
            return ParsedMessage(
                cli=cli,
                msg_type="output",
                content=line,
                is_final=False,
                raw={}
            )
        return None

    if cli == "claude":
        return _parse_claude_json(data)
    elif cli == "codex":
        return _parse_codex_json(data)
    elif cli == "gemini":
        return _parse_gemini_json(data)

    return None


def format_message_for_display(msg: ParsedMessage) -> str:
    """Format a parsed message with Catppuccin Macchiato colors for terminal display."""
    c = COLORS

    if msg.is_final:
        # Final result: bold green header, text color content
        header = f"{c['bold']}{c['green']}[FINAL]{c['reset']}"
        content = f"{c['text']}{msg.content}{c['reset']}"
    elif msg.msg_type == "reasoning":
        # Reasoning/thinking: overlay color (dimmed)
        header = f"{c['overlay1']}[thinking]{c['reset']}"
        content = f"{c['overlay1']}{msg.content}{c['reset']}"
    elif msg.msg_type == "tool":
        # Tool use: peach color
        header = f"{c['peach']}[tool]{c['reset']}"
        content = f"{c['peach']}{msg.content}{c['reset']}"
    elif msg.msg_type == "assistant":
        # Assistant: sapphire header, text content
        header = f"{c['sapphire']}[assistant]{c['reset']}"
        content = f"{c['text']}{msg.content}{c['reset']}"
    elif msg.msg_type == "system":
        # System messages: overlay (dimmed)
        header = f"{c['overlay0']}[system]{c['reset']}"
        content = f"{c['overlay0']}{msg.content}{c['reset']}"
    else:
        # Other: lavender header
        header = f"{c['lavender']}[{msg.msg_type}]{c['reset']}"
        content = f"{c['subtext0']}{msg.content}{c['reset']}"

    # Indent content lines
    content_lines = content.split('\n')
    formatted_content = '\n  '.join(content_lines)

    return f"{header}\n  {formatted_content}\n"


def build_cli_command(cli: str, prompt: str, model: str = "", files: list = None) -> list[str]:
    """Build command arguments for an AI CLI with JSON output enabled."""
    files = files or []

    if cli == "claude":
        # --verbose is required for stream-json to show content
        cmd = ["claude", "--print", "--verbose", "--output-format", "stream-json"]
        if model:
            cmd.extend(["--model", model])
        # Claude only supports --add-dir for directories
        dirs_added = set()
        for f in files:
            dir_path = os.path.dirname(f) if os.path.isfile(f) else f
            if dir_path and dir_path not in dirs_added:
                cmd.extend(["--add-dir", dir_path])
                dirs_added.add(dir_path)
        cmd.append(prompt)
        return cmd

    elif cli == "codex":
        # ENFORCE read-only mode
        cmd = ["codex", "exec", "-s", "read-only", "--json", "--skip-git-repo-check"]
        if model:
            cmd.extend(["--model", model])
        cmd.append(prompt)
        return cmd

    elif cli == "gemini":
        # ENFORCE sandbox mode - use stream-json for structured parsing
        cmd = ["gemini", "--sandbox", "--output-format", "stream-json"]
        if model:
            cmd.extend(["--model", model])
        # Gemini uses @ syntax for files
        file_refs = " ".join(f"@{f}" for f in files)
        full_prompt = f"{file_refs} {prompt}".strip() if file_refs else prompt
        cmd.append(full_prompt)
        return cmd

    else:
        raise ValueError(f"Unsupported CLI: {cli}")


def save_parsed_message_to_db(job_id: str, msg: ParsedMessage, conn: sqlite3.Connection):
    """Save a parsed message to SQLite."""
    msg_id = f"msg_{uuid.uuid4().hex[:12]}"
    conn.execute("""
        INSERT INTO messages (id, job_id, sender, content, msg_type, timestamp)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (msg_id, job_id, msg.cli, msg.content, msg.msg_type, msg.timestamp))
    conn.commit()


def get_db_connection():
    """Get a database connection."""
    if not DB_PATH.exists():
        print(f"Error: Database not found at {DB_PATH}", file=sys.stderr)
        print("No jobs have been created yet.", file=sys.stderr)
        sys.exit(1)

    conn = sqlite3.connect(str(DB_PATH), timeout=10.0)
    conn.row_factory = sqlite3.Row
    return conn


def format_age(timestamp: float) -> str:
    """Format a timestamp as a human-readable age."""
    age = time.time() - timestamp
    if age < 60:
        return f"{int(age)}s"
    elif age < 3600:
        return f"{int(age / 60)}m"
    elif age < 86400:
        return f"{int(age / 3600)}h"
    else:
        return f"{int(age / 86400)}d"


def truncate(text: str, length: int = 40) -> str:
    """Truncate text with ellipsis."""
    if len(text) <= length:
        return text
    return text[:length - 3] + "..."


# =============================================================================
# Commands
# =============================================================================


def cmd_sessions(args):
    """List all sessions with job counts."""
    conn = get_db_connection()
    try:
        rows = conn.execute("""
            SELECT
                session_id,
                COUNT(*) as total,
                SUM(CASE WHEN status = 'running' THEN 1 ELSE 0 END) as running,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
                SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed
            FROM jobs
            GROUP BY session_id
            ORDER BY session_id
        """).fetchall()

        if not rows:
            print("No sessions found.")
            return

        # Print header
        print(f"{'SESSION':<20} {'JOBS':>6} {'RUNNING':>8} {'COMPLETED':>10} {'FAILED':>7}")
        print("-" * 55)

        for row in rows:
            print(f"{row['session_id']:<20} {row['total']:>6} {row['running']:>8} {row['completed']:>10} {row['failed']:>7}")

    finally:
        conn.close()


def cmd_jobs(args):
    """List jobs in a session."""
    conn = get_db_connection()
    try:
        query = "SELECT * FROM jobs"
        params = []

        if args.session:
            query += " WHERE session_id = ?"
            params.append(args.session)

        if args.status:
            if params:
                query += " AND status = ?"
            else:
                query += " WHERE status = ?"
            params.append(args.status)

        query += " ORDER BY created DESC"

        if args.limit:
            query += f" LIMIT {args.limit}"

        rows = conn.execute(query, params).fetchall()

        if not rows:
            print("No jobs found.")
            return

        # Print header
        print(f"{'JOB_ID':<20} {'CLI':<8} {'STATUS':<10} {'AGE':>6}  {'PROMPT'}")
        print("-" * 80)

        for row in rows:
            age = format_age(row['created'])
            prompt = truncate(row['prompt'], 35)
            print(f"{row['id']:<20} {row['cli']:<8} {row['status']:<10} {age:>6}  {prompt}")

    finally:
        conn.close()


def cmd_status(args):
    """Get details for a specific job."""
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT * FROM jobs WHERE id = ?", (args.job_id,)).fetchone()

        if not row:
            print(f"Error: Job {args.job_id} not found", file=sys.stderr)
            sys.exit(1)

        # Get message count
        msg_count = conn.execute(
            "SELECT COUNT(*) as count FROM messages WHERE job_id = ?",
            (args.job_id,)
        ).fetchone()['count']

        created = datetime.fromtimestamp(row['created']).strftime("%Y-%m-%d %H:%M:%S")

        print(f"Job:      {row['id']}")
        print(f"Session:  {row['session_id']}")
        print(f"CLI:      {row['cli']}")
        print(f"Model:    {row['model'] or '(default)'}")
        print(f"Status:   {row['status']}")
        print(f"Created:  {created} ({format_age(row['created'])} ago)")
        print(f"PID:      {row['pid'] or 'N/A'}")
        print(f"Messages: {msg_count}")
        print()
        print("Prompt:")
        print("-" * 40)
        print(row['prompt'])

        if row['result'] and args.result:
            print()
            print("Result:")
            print("-" * 40)
            print(row['result'])

    finally:
        conn.close()


def cmd_kill(args):
    """Terminate a running job."""
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT * FROM jobs WHERE id = ?", (args.job_id,)).fetchone()

        if not row:
            print(f"Error: Job {args.job_id} not found", file=sys.stderr)
            sys.exit(1)

        if row['status'] != 'running':
            print(f"Job {args.job_id} is not running (status: {row['status']})")
            return

        if not row['pid']:
            print(f"Job {args.job_id} has no PID recorded", file=sys.stderr)
            sys.exit(1)

        try:
            os.kill(row['pid'], signal.SIGTERM)
            print(f"Sent SIGTERM to PID {row['pid']}")

            # Update status in database
            conn.execute(
                "UPDATE jobs SET status = 'failed', result = 'Killed by user' WHERE id = ?",
                (args.job_id,)
            )
            conn.commit()
            print(f"Job {args.job_id} marked as failed")

        except ProcessLookupError:
            print(f"Process {row['pid']} not found (may have already exited)")
            # Update status anyway
            conn.execute(
                "UPDATE jobs SET status = 'failed', result = 'Process not found' WHERE id = ?",
                (args.job_id,)
            )
            conn.commit()

    finally:
        conn.close()


def cmd_messages(args):
    """Show messages for a job."""
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT id FROM jobs WHERE id = ?", (args.job_id,)).fetchone()
        if not row:
            print(f"Error: Job {args.job_id} not found", file=sys.stderr)
            sys.exit(1)

        messages = conn.execute(
            "SELECT * FROM messages WHERE job_id = ? ORDER BY timestamp",
            (args.job_id,)
        ).fetchall()

        if not messages:
            print("No messages.")
            return

        for msg in messages:
            ts = datetime.fromtimestamp(msg['timestamp']).strftime("%H:%M:%S")
            type_indicator = "[FINAL]" if msg['msg_type'] == 'final' else ""
            sender = msg['sender'] or "anonymous"
            print(f"[{ts}] {sender} {type_indicator}")
            print(f"  {msg['content']}")
            print()

    finally:
        conn.close()


def cmd_stream(args):
    """Tail streaming output from a job."""
    conn = get_db_connection()
    try:
        row = conn.execute("SELECT * FROM jobs WHERE id = ?", (args.job_id,)).fetchone()
        if not row:
            print(f"Error: Job {args.job_id} not found", file=sys.stderr)
            sys.exit(1)

        output_path = Path("/tmp") / f"orchestrator_{args.job_id}.out"

        if not output_path.exists():
            if row['result']:
                print(row['result'])
            else:
                print("No output available yet.")
            return

        # Tail the file
        offset = 0
        if args.follow:
            print(f"Following output for {args.job_id} (Ctrl+C to stop)...")
            print("-" * 40)

        try:
            while True:
                with open(output_path, 'r') as f:
                    f.seek(offset)
                    new_data = f.read()
                    if new_data:
                        print(new_data, end='', flush=True)
                        offset = f.tell()

                if not args.follow:
                    break

                # Check if job is still running
                row = conn.execute(
                    "SELECT status FROM jobs WHERE id = ?",
                    (args.job_id,)
                ).fetchone()

                if row['status'] != 'running':
                    # Read any remaining output
                    time.sleep(0.5)
                    with open(output_path, 'r') as f:
                        f.seek(offset)
                        remaining = f.read()
                        if remaining:
                            print(remaining, end='', flush=True)
                    print(f"\n[Job {row['status']}]")
                    break

                time.sleep(0.5)

        except KeyboardInterrupt:
            print("\n[Stopped]")

    finally:
        conn.close()


def cmd_cleanup(args):
    """Remove expired/completed jobs."""
    conn = get_db_connection()
    try:
        if args.all:
            # Delete all completed/failed jobs
            result = conn.execute(
                "SELECT id FROM jobs WHERE status IN ('completed', 'failed')"
            ).fetchall()
            job_ids = [row['id'] for row in result]
        else:
            # Delete jobs older than max_age
            cutoff = time.time() - (args.age * 3600)
            result = conn.execute(
                "SELECT id FROM jobs WHERE status IN ('completed', 'failed') AND created < ?",
                (cutoff,)
            ).fetchall()
            job_ids = [row['id'] for row in result]

        if not job_ids:
            print("No jobs to clean up.")
            return

        # Delete messages first
        placeholders = ','.join('?' * len(job_ids))
        conn.execute(f"DELETE FROM messages WHERE job_id IN ({placeholders})", job_ids)

        # Delete jobs
        conn.execute(f"DELETE FROM jobs WHERE id IN ({placeholders})", job_ids)
        conn.commit()

        print(f"Cleaned up {len(job_ids)} job(s).")

        # Clean up output files
        for job_id in job_ids:
            output_path = Path("/tmp") / f"orchestrator_{job_id}.out"
            if output_path.exists():
                output_path.unlink()

    finally:
        conn.close()


# =============================================================================
# TUI Runner
# =============================================================================


def cmd_run(args):
    """Run an AI CLI with TUI output."""
    app = AIRunnerApp(
        cli=args.cli,
        prompt=args.prompt,
        job_id=args.job_id,
        model=args.model or "",
        files=args.files or [],
        log_intermediary=args.log_intermediary,
        auto_close=args.auto_close
    )
    app.run()


# Catppuccin Macchiato colors for Rich/Textual (hex format)
# Verified against official palette: https://catppuccin.com/palette/
RICH_COLORS = {
    "rosewater": "#f4dbd6",
    "flamingo": "#f0c6c6",
    "pink": "#f5bde6",
    "mauve": "#c6a0f6",
    "red": "#ed8796",
    "maroon": "#ee99a0",
    "peach": "#f5a97f",
    "yellow": "#eed49f",
    "green": "#a6da95",
    "teal": "#8bd5ca",
    "sky": "#91d7e3",
    "sapphire": "#7dc4e4",
    "blue": "#8aadf4",
    "lavender": "#b7bdf8",
    "text": "#cad3f5",
    "subtext1": "#b8c0e0",
    "subtext0": "#a5adcb",
    "overlay2": "#939ab7",
    "overlay1": "#8087a2",
    "overlay0": "#6e738d",
    "surface2": "#5b6078",
    "surface1": "#494d64",
    "surface0": "#363a4f",
    "base": "#24273a",
    "mantle": "#1e2030",
    "crust": "#181926",
}


# Textual TUI App
class AIRunnerApp(App):
    """TUI for AI CLI output with sticky header and scrollable output."""

    CSS = f"""
    Screen {{
        background: {RICH_COLORS['base']};
    }}
    #header-box {{
        dock: top;
        height: 4;
        background: {RICH_COLORS['surface0']};
        border-bottom: solid {RICH_COLORS['surface1']};
        padding: 0 1;
    }}
    #cli-line {{
        color: {RICH_COLORS['text']};
    }}
    #status-line {{
        color: {RICH_COLORS['subtext0']};
    }}
    #prompt-line {{
        color: {RICH_COLORS['overlay1']};
    }}
    #output {{
        height: 1fr;
        background: {RICH_COLORS['base']};
        scrollbar-gutter: stable;
    }}
    """

    status = reactive("running")
    role = reactive("assistant")
    current_tool = reactive("")
    duration = reactive(0)

    def __init__(
        self,
        cli: str,
        prompt: str,
        job_id: str,
        model: str = "",
        files: list = None,
        log_intermediary: bool = False,
        auto_close: bool = True,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.cli = cli
        self.prompt = prompt
        self.job_id = job_id
        self.model = model
        self.files = files or []
        self.log_intermediary = log_intermediary
        self.auto_close = auto_close
        self.start_time = time.time()
        self.final_result = ""
        self.assistant_messages = []  # Collect all assistant messages
        self.exit_code = None
        self.json_buffer = JsonBuffer()

    def compose(self) -> ComposeResult:
        # CLI-specific emojis and colors
        cli_info = {
            "claude": {"emoji": "🟣", "style": f"bold {RICH_COLORS['mauve']}"},
            "codex": {"emoji": "🟢", "style": f"bold {RICH_COLORS['green']}"},
            "gemini": {"emoji": "🔵", "style": f"bold {RICH_COLORS['blue']}"}
        }
        info = cli_info.get(self.cli, {"emoji": "⚪", "style": "bold"})

        # Build context info
        model_info = f" │ 🤖 {self.model}" if self.model else ""
        files_info = f" │ 📁 {len(self.files)} files" if self.files else ""

        # Header layout: CLI+job+context, status, prompt (dimmer)
        yield Container(
            Static(
                f"{info['emoji']} [{info['style']}]{self.cli.upper()}[/{info['style']}] "
                f"│ 🏷️ {self.job_id[:8]}{model_info}{files_info}",
                id="cli-line"
            ),
            Static("", id="status-line"),
            Static(f"💬 {self.prompt}", id="prompt-line"),
            id="header-box"
        )
        yield RichLog(id="output", highlight=True, markup=True)

    def on_mount(self):
        # Show starting message immediately
        output_log = self.query_one("#output", RichLog)
        cli_emoji = {"claude": "🟣", "codex": "🟢", "gemini": "🔵"}.get(self.cli, "⚪")
        output_log.write(Text.assemble(
            (f"\n  {cli_emoji} Starting {self.cli.upper()} agent...\n", f"{RICH_COLORS['subtext0']}")
        ))

        # Start CLI subprocess in background worker
        self.run_worker(self._run_cli, thread=True)
        # Update header every second
        self.set_interval(1, self._update_header)

    def _update_header(self):
        self.duration = int(time.time() - self.start_time)
        status_line = self.query_one("#status-line", Static)

        # Status emoji
        status_emoji = {
            "running": "🔄",
            "completed": "✅",
            "failed": "❌"
        }.get(self.status, "❓")

        tool_info = f" │ 🔧 {self.current_tool}" if self.current_tool else ""
        status_color = RICH_COLORS['green'] if self.status == "running" else (
            RICH_COLORS['green'] if self.status == "completed" else RICH_COLORS['red']
        )
        status_line.update(
            f"{status_emoji} [{status_color}]{self.status.upper()}[/{status_color}]{tool_info} │ ⏱️ {self.duration}s"
        )

    def _run_cli(self):
        """Run the CLI command and stream output."""
        cmd = build_cli_command(self.cli, self.prompt, self.model, self.files)
        output_log = self.query_one("#output", RichLog)

        # Open DB connection
        conn = None
        if DB_PATH.exists():
            conn = sqlite3.connect(str(DB_PATH), timeout=10.0)
            conn.row_factory = sqlite3.Row

        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            # Parse JSON output from all CLIs
            for line in proc.stdout:
                msg = parse_cli_json_line(self.cli, line, self.json_buffer)
                if msg:
                    # Update reactive properties
                    if msg.role:
                        self.role = msg.role
                    if msg.tool_name:
                        self.current_tool = msg.tool_name
                    elif msg.msg_type != "tool":
                        self.current_tool = ""

                    # Collect assistant messages for final result
                    if msg.msg_type == "assistant" and msg.content:
                        self.assistant_messages.append(msg.content)

                    # Format and display with markdown support
                    formatted = self._format_for_rich(msg)
                    self.call_from_thread(output_log.write, formatted)

                    # Log to SQLite
                    if conn and (msg.is_final or self.log_intermediary):
                        save_parsed_message_to_db(self.job_id, msg, conn)

            proc.wait()
            self.exit_code = proc.returncode
            self.status = "completed" if self.exit_code == 0 else "failed"

            # Combine all assistant messages as final result
            if self.assistant_messages:
                self.final_result = "\n\n".join(self.assistant_messages)

            # Update job in database
            if conn:
                conn.execute(
                    "UPDATE jobs SET status = ?, result = ? WHERE id = ?",
                    (self.status, self.final_result, self.job_id)
                )
                conn.commit()

        except Exception as e:
            self.status = "failed"
            self.call_from_thread(output_log.write, Text(f"❌ Error: {e}", style=f"bold {RICH_COLORS['red']}"))

        finally:
            if conn:
                conn.close()

        # Wait then exit if auto_close
        if self.auto_close:
            text = Text()
            text.append(f"\n  ⏳ Window closing in {AUTO_CLOSE_DELAY}s...\n", style=RICH_COLORS['subtext0'])
            self.call_from_thread(output_log.write, text)
            time.sleep(AUTO_CLOSE_DELAY)
            self.call_from_thread(self.exit)

    def _format_for_rich(self, msg: ParsedMessage):
        """Format message for the TUI with Catppuccin colors and markdown support."""
        # Use Markdown for assistant messages, Text for others
        if msg.msg_type == "assistant" and not msg.is_final:
            # Render markdown for assistant content
            try:
                md = Markdown(msg.content)
                return md
            except Exception:
                pass  # Fall back to Text if markdown fails

        text = Text()

        if msg.is_final:
            text.append("✅ [FINAL]", style=f"bold {RICH_COLORS['green']}")
            # Try markdown for final result too
            try:
                return Text.assemble(
                    ("✅ [FINAL]", f"bold {RICH_COLORS['green']}"),
                    "\n",
                    Markdown(msg.content)
                )
            except Exception:
                text.append("\n  " + msg.content.replace("\n", "\n  "), style=RICH_COLORS['text'])
        elif msg.msg_type == "reasoning":
            text.append("💭 [thinking]", style=RICH_COLORS['overlay1'])
            text.append("\n  " + msg.content.replace("\n", "\n  "), style=RICH_COLORS['overlay1'])
        elif msg.msg_type == "tool":
            text.append("🔧 [tool]", style=RICH_COLORS['peach'])
            text.append("\n  " + msg.content.replace("\n", "\n  "), style=RICH_COLORS['peach'])
        elif msg.msg_type == "output":
            text.append("📤 [output]", style=RICH_COLORS['teal'])
            text.append("\n  " + msg.content.replace("\n", "\n  "), style=RICH_COLORS['teal'])
        elif msg.msg_type == "system":
            text.append("⚙️ [system]", style=RICH_COLORS['overlay0'])
            text.append("\n  " + msg.content.replace("\n", "\n  "), style=RICH_COLORS['overlay0'])
        else:
            text.append(f"💬 [{msg.msg_type}]", style=RICH_COLORS['subtext0'])
            text.append("\n  " + msg.content.replace("\n", "\n  "), style=RICH_COLORS['subtext0'])

        text.append("\n")
        return text


# =============================================================================
# Main
# =============================================================================


def main():
    parser = argparse.ArgumentParser(
        description="Orchestrator CLI - Monitor and manage AI jobs",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    subparsers = parser.add_subparsers(dest='command', help='Commands')

    # sessions
    sessions_parser = subparsers.add_parser('sessions', help='List sessions with job counts')
    sessions_parser.set_defaults(func=cmd_sessions)

    # jobs
    jobs_parser = subparsers.add_parser('jobs', help='List jobs')
    jobs_parser.add_argument('session', nargs='?', help='Session name (optional)')
    jobs_parser.add_argument('-s', '--status', help='Filter by status')
    jobs_parser.add_argument('-n', '--limit', type=int, help='Limit results')
    jobs_parser.set_defaults(func=cmd_jobs)

    # status
    status_parser = subparsers.add_parser('status', help='Get job details')
    status_parser.add_argument('job_id', help='Job ID')
    status_parser.add_argument('-r', '--result', action='store_true', help='Show result')
    status_parser.set_defaults(func=cmd_status)

    # kill
    kill_parser = subparsers.add_parser('kill', help='Terminate a running job')
    kill_parser.add_argument('job_id', help='Job ID')
    kill_parser.set_defaults(func=cmd_kill)

    # messages
    messages_parser = subparsers.add_parser('messages', help='Show job messages')
    messages_parser.add_argument('job_id', help='Job ID')
    messages_parser.set_defaults(func=cmd_messages)

    # stream
    stream_parser = subparsers.add_parser('stream', help='Tail job output')
    stream_parser.add_argument('job_id', help='Job ID')
    stream_parser.add_argument('-f', '--follow', action='store_true', help='Follow output')
    stream_parser.set_defaults(func=cmd_stream)

    # cleanup
    cleanup_parser = subparsers.add_parser('cleanup', help='Remove old jobs')
    cleanup_parser.add_argument('--all', action='store_true', help='Remove all completed/failed')
    cleanup_parser.add_argument('--age', type=int, default=1, help='Max age in hours (default: 1)')
    cleanup_parser.set_defaults(func=cmd_cleanup)

    # run (TUI runner for tmux windows)
    run_parser = subparsers.add_parser('run', help='Run AI CLI with TUI output')
    run_parser.add_argument('prompt', help='Prompt to send to the AI')
    run_parser.add_argument('--cli', required=True, choices=['claude', 'codex', 'gemini'],
                           help='Which AI CLI to use')
    run_parser.add_argument('--job-id', required=True, help='Job ID for tracking')
    run_parser.add_argument('--model', help='Model override')
    run_parser.add_argument('--files', action='append', help='Files to include (can repeat)')
    run_parser.add_argument('--log-intermediary', action='store_true',
                           help='Log intermediary messages to SQLite')
    run_parser.add_argument('--auto-close', action='store_true', default=True,
                           help='Auto-close window after completion (default: true)')
    run_parser.add_argument('--no-auto-close', action='store_false', dest='auto_close',
                           help='Keep window open after completion')
    run_parser.set_defaults(func=cmd_run)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
