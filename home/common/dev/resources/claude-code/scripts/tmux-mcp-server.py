#!/usr/bin/env python3
"""MCP server for tmux terminal automation - uses windows for full-screen output"""
import subprocess
import hashlib
import time
import os
import json
import re
import uuid
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("tmux")

VALID_SHELLS = {"zsh", "bash", "fish", "sh"}
DEFAULT_SHELL = "zsh"
MAX_CAPTURE_LINES = 10000
MIN_CAPTURE_LINES = 1

# Pattern for valid tmux window/pane identifiers (e.g., @3, %5)
TARGET_PATTERN = re.compile(r'^[@%][0-9]+$')


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


def window_exists(window_id: str) -> bool:
    """Check if a tmux window still exists"""
    output, code = run_tmux("list-windows", "-F", "#{window_id}")
    if code != 0:
        return False
    return window_id in output.split("\n")


@mcp.tool()
def tmux_run_and_read(
    command: str,
    output_file: str,
    name: str = "",
    timeout: int = 300
) -> str:
    """
    Run a command in a new tmux window and return the contents of an output file.

    IMPORTANT: Unlike tmux_new_window, this does NOT spawn a shell.
    The command is executed directly via tmux new-window, so it must be
    a complete executable command (not shell syntax like pipes or redirects).

    The command is expected to write its output to output_file.
    The window is automatically cleaned up after reading.

    Use this for CLI tools that support file output, like:
        codex exec -o /tmp/output.txt review --uncommitted

    Args:
        command: Command to run directly (should write to output_file)
        output_file: Path to file that command will create
        name: Optional window name (shown in status bar)
        timeout: Maximum seconds to wait for command to finish (default: 300)

    Returns:
        Contents of output_file on success, or error message
    """
    require_tmux()

    # Remove any existing output file to avoid reading stale data
    if os.path.exists(output_file):
        os.remove(output_file)

    # Create new window with command running directly (no shell wrapper)
    # -d flag keeps focus on current window (don't switch to new one)
    args = ["new-window", "-d", "-P", "-F", "#{window_id}"]
    if name:
        args.extend(["-n", name])
    args.append(command)

    output, code = run_tmux(*args)

    if code != 0:
        return f"Error creating window: {output}"

    window_id = output

    # Wait for window to close (command finished) or timeout
    start = time.time()
    while time.time() - start < timeout:
        if not window_exists(window_id):
            # Window closed - command finished
            break
        time.sleep(0.5)
    else:
        # Timeout reached - kill the window
        run_tmux("kill-window", "-t", window_id)
        return f"Error: Command timed out after {timeout}s"

    # Read the output file
    if not os.path.exists(output_file):
        return f"Error: Output file '{output_file}' was not created by the command"

    try:
        with open(output_file, "r") as f:
            content = f.read()
        # Clean up the output file
        os.remove(output_file)
        return content
    except Exception as e:
        return f"Error reading output file: {e}"


if __name__ == "__main__":
    mcp.run()
