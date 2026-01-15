# SSH wrapper that tries mosh first for simple connections
# Falls back to ssh if mosh fails or for complex commands

# Get the real ssh path (bypass function)
set real_ssh (command -v ssh)

# If no arguments, just run ssh (shows usage)
if test (count $argv) -eq 0
    command ssh
    return $status
end

# Check if this looks like a simple connection (no options starting with -)
set has_options 0
for arg in $argv
    if string match -q -- '-*' $arg
        set has_options 1
        break
    end
end

# If there are options or multiple non-option args (command to run), use ssh directly
if test $has_options -eq 1; or test (count $argv) -gt 1
    command ssh $argv
    return $status
end

# Simple case: just a hostname - try mosh first
set host $argv[1]

# Check if mosh is available
if command -q mosh
    # Try mosh, suppress stderr for connection errors
    mosh $host 2>/dev/null
    set mosh_status $status

    if test $mosh_status -eq 0
        return 0
    end
end

# Mosh failed or unavailable, fall back to ssh
command ssh $host
