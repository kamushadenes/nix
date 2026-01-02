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
"""
import argparse
import json
import os
import signal
import sqlite3
import sys
import time
from datetime import datetime
from pathlib import Path

DB_PATH = Path.home() / ".config" / "orchestrator-mcp" / "state.db"


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

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    args.func(args)


if __name__ == "__main__":
    main()
