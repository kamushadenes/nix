#!/usr/bin/env python3
"""
MCP server for terminal automation.

Provides:
- tmux_* tools for terminal window management
- notify tool for macOS notifications
"""
import subprocess
import hashlib
import time
import os
import uuid
import re
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
        return "Error: Output file was not created by the command"

    try:
        with open(output_file, "r") as f:
            content = f.read()
        # Clean up the output file
        os.remove(output_file)
        return content
    except Exception as e:
        return f"Error reading output file: {e}"


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    mcp.run()
