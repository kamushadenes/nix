# SSH wrapper that tries mosh first for simple connections
# Falls back to ssh if mosh fails or for complex commands

# If no arguments, just run ssh (shows usage)
if [ $# -eq 0 ]; then
    command ssh
    return $?
fi

# Check if this looks like a simple connection (no options starting with -)
has_options=0
for arg in "$@"; do
    case "$arg" in
        -*) has_options=1; break ;;
    esac
done

# If there are options or multiple args (command to run), use ssh directly
if [ $has_options -eq 1 ] || [ $# -gt 1 ]; then
    command ssh "$@"
    return $?
fi

# Simple case: just a hostname - try mosh first
host="$1"

# Check if mosh is available
if command -v mosh >/dev/null 2>&1; then
    # Try mosh, suppress stderr for connection errors
    mosh "$host" 2>/dev/null
    mosh_status=$?

    if [ $mosh_status -eq 0 ]; then
        return 0
    fi
fi

# Mosh failed or unavailable, fall back to ssh
command ssh "$host"
