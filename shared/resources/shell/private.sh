if [ -n "${PRIVATE_MODE:-}" ]; then
    unset PRIVATE_MODE
    unset ATUIN_HISTORY_DISABLE
    if [ -n "${BASH_VERSION:-}" ]; then
        set -o history
    elif [ -n "${ZSH_VERSION:-}" ]; then
        fc -P
    fi
    echo "history enabled"
else
    export PRIVATE_MODE=1
    export ATUIN_HISTORY_DISABLE=true
    if [ -n "${BASH_VERSION:-}" ]; then
        set +o history
    elif [ -n "${ZSH_VERSION:-}" ]; then
        fc -p /dev/null 0 0
    fi
    echo "history disabled"
fi
