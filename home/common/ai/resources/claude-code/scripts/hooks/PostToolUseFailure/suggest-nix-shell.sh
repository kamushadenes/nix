#!/usr/bin/env bash
# Suggest nix-shell when a command is not found
# Uses nix-locate to find the package that provides the missing binary
#
# Input format (stdin JSON):
# {
#   "hook_event_name": "PostToolUseFailure",
#   "tool_name": "Bash",
#   "tool_input": { "command": "cowsay hello" },
#   "tool_error": "bash: cowsay: command not found"
# }

# Read JSON input from stdin
input=$(cat)

# Extract fields
tool_error=$(echo "$input" | jq -r '.tool_error // empty')
command_str=$(echo "$input" | jq -r '.tool_input.command // empty')

# Check if this is a "command not found" error
if [[ ! "$tool_error" =~ (command\ not\ found|not\ found) ]]; then
  exit 0
fi

# Extract the missing command from error message
# Handles: "bash: foo: command not found" or "foo: not found"
binary=""
if [[ "$tool_error" =~ bash:\ ([^:]+):\ command\ not\ found ]]; then
  binary="${BASH_REMATCH[1]}"
elif [[ "$tool_error" =~ ([^:\ ]+):\ (command\ )?not\ found ]]; then
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
