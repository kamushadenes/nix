#!/usr/bin/env bash
# Suggest nix-shell when a command is not found
# Uses nix-locate to find the package that provides the missing binary
#
# Runs as a PostToolUse hook and checks tool_response for "command not found" errors.
#
# TODO: When PostToolUseFailure hook becomes available in Claude Code,
# migrate this to PostToolUseFailure for efficiency (only runs on failures).
# See: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
#
# Input format (stdin JSON):
# {
#   "hook_event_name": "PostToolUse",
#   "tool_name": "Bash",
#   "tool_input": { "command": "cowsay hello" },
#   "tool_response": { "stdout": "", "stderr": "cowsay: command not found", ... }
# }

# Read JSON input from stdin
input=$(cat)

# Extract tool response - could be string or object with stdout/stderr
tool_response=$(echo "$input" | jq -r '.tool_response // empty')
command_str=$(echo "$input" | jq -r '.tool_input.command // empty')

# Handle both string and object responses
if echo "$tool_response" | jq -e 'type == "object"' &>/dev/null; then
  # Object with stdout/stderr fields
  stderr=$(echo "$tool_response" | jq -r '.stderr // empty')
  stdout=$(echo "$tool_response" | jq -r '.stdout // empty')
  error_text="$stderr $stdout"
else
  # Plain string response
  error_text="$tool_response"
fi

# Check if this is a "command not found" error
if [[ ! "$error_text" =~ (command\ not\ found|not\ found) ]]; then
  exit 0
fi

# Extract the missing command from error message
# Handles: "bash: foo: command not found" or "foo: not found" or "foo: command not found"
binary=""
if [[ "$error_text" =~ bash:\ ([^:]+):\ command\ not\ found ]]; then
  binary="${BASH_REMATCH[1]}"
elif [[ "$error_text" =~ ([^:\ ]+):\ command\ not\ found ]]; then
  binary="${BASH_REMATCH[1]}"
elif [[ "$error_text" =~ ([^:\ ]+):\ not\ found ]]; then
  binary="${BASH_REMATCH[1]}"
fi

[[ -z "$binary" ]] && exit 0

# Use nix-locate to find the package
if ! command -v nix-locate &>/dev/null; then
  exit 0
fi

packages=$(nix-locate --minimal --whole-name --at-root "/bin/$binary" 2>/dev/null | head -3)

if [[ -n "$packages" ]]; then
  # Get first package (remove .out/.bin suffix)
  pkg=$(echo "$packages" | head -1 | sed 's/\.\(out\|bin\)$//')

  echo ""
  echo "Command '$binary' not found. Available in nixpkgs:"
  echo "$packages" | sed 's/\.\(out\|bin\)$//' | sed 's/^/   - /'
  echo ""
  echo "   Run with: nix-shell -p $pkg --run \"$command_str\""
  echo ""
fi

exit 0
