# Claude Code workspace manager
# Usage: c [command] [args...]
#   c                    - Start tmux+claude in current directory
#   c <args>             - Pass args to claude
#   c danger|d [args]    - Run claude in Docker with full permissions (sandboxed)
#   c work|w <branch>    - Create worktree for branch, start claude there
#   c list|l             - List all workspaces
#   c resume|r [id]      - Resume workspace (fzf if no id)
#   c clean|x            - Interactive cleanup of old workspaces
#   c help|h             - Show help

# Helper: normalize string for directory name
_c_normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//' | sed 's/-$//'
}

# Helper: generate short UUID
_c_gen_uuid() {
    uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]'
}

# Helper: workspace base directory
_c_workspace_base() {
    echo "$HOME/.local/share/git/workspaces"
}

# Helper: ensure beads daemon is running with auto-commit/auto-push
_c_ensure_beads_daemon() {
    local target_dir="${1:-$(pwd)}"

    if test -d "$target_dir/.beads"; then
        # Restart daemon with proper flags (silent, don't fail if not running)
        bd daemon --stop 2>/dev/null
        bd daemon --start --auto-commit --auto-push 2>/dev/null
    fi
}

# Helper: get git info, sets global vars
_c_get_git_info() {
    _git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$_git_root"; then
        echo "Error: Not in a git repository"
        return 1
    fi
    _git_folder=$(basename "$_git_root")
    _parent_folder=$(basename "$(dirname "$_git_root")")
    _git_folder_norm=$(_c_normalize "$_git_folder")
    _parent_folder_norm=$(_c_normalize "$_parent_folder")
    return 0
}

# Danger mode: run claude in Docker container with full permissions
_c_danger() {
    local current_dir
    current_dir=$(pwd)
    local home_dir="$HOME"
    local image_name="claude-sandbox:latest"

    # Check if docker is available
    if ! command -v docker >/dev/null 2>&1; then
        echo "Error: Docker is not installed or not in PATH"
        return 1
    fi

    # Check if docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker daemon is not running"
        return 1
    fi

    # Check if claude-sandbox image exists, build if not
    if ! docker image inspect "$image_name" >/dev/null 2>&1; then
        echo "🔨 Building claude-sandbox image (first time only)..."
        docker build -t "$image_name" - <<'DOCKERFILE'
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root
ENV PATH="/root/.local/bin:$PATH"

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y -qq curl git xz-utils ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install devbox
RUN curl -fsSL https://get.jetify.com/devbox | bash -s -- -f

# Install claude-code and language runtimes globally via devbox
RUN /root/.local/bin/devbox global add claude-code go nodejs python3 php php83Packages.composer rustup

# Pre-warm devbox shellenv
RUN /root/.local/bin/devbox global shellenv > /root/.devbox_shellenv

# Setup rust toolchain
RUN . /root/.devbox_shellenv && rustup default stable

# Install tdd-guard tools for all languages
RUN . /root/.devbox_shellenv && \
    go install github.com/nizos/tdd-guard/reporters/go/cmd/tdd-guard-go@latest && \
    npm install -g tdd-guard tdd-guard-vitest && \
    pip install tdd-guard-pytest && \
    composer global require tdd-guard/phpunit && \
    cargo install tdd-guard-rust

ENTRYPOINT ["/bin/bash", "-c"]
DOCKERFILE
        if test $? -ne 0; then
            echo "Error: Failed to build claude-sandbox image"
            return 1
        fi
        echo "✅ Image built successfully"
        echo ""
    fi

    # Container name based on directory
    local dir_hash
    dir_hash=$(echo "$current_dir" | md5sum | cut -c1-8)
    local container_name="claude-danger-$dir_hash"

    # Build volume mounts
    local mounts=()
    # Mount current directory at same path
    mounts+=("-v" "$current_dir:$current_dir")
    # Mount claude config
    mounts+=("-v" "$home_dir/.claude:/root/.claude")
    # Mount claude.json
    if test -f "$home_dir/.claude.json"; then
        mounts+=("-v" "$home_dir/.claude.json:/root/.claude.json")
    fi
    # Mount SSH for git operations
    if test -d "$home_dir/.ssh"; then
        mounts+=("-v" "$home_dir/.ssh:/root/.ssh:ro")
    fi
    # Mount git config
    if test -f "$home_dir/.gitconfig"; then
        mounts+=("-v" "$home_dir/.gitconfig:/root/.gitconfig:ro")
    fi

    echo "🐳 Starting Claude in Docker container (danger mode)..."
    echo "   Container: $container_name"
    echo "   Workdir: $current_dir"
    echo ""

    # Run container with pre-built image
    docker run -it --rm \
        --name "$container_name" \
        --hostname "claude-sandbox" \
        -w "$current_dir" \
        -e "HOME=/root" \
        -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" \
        -e "CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK" \
        "${mounts[@]}" \
        "$image_name" \
        '
            source /root/.devbox_shellenv

            # Check if project has devbox.json - use it at runtime
            if [ -f "devbox.json" ]; then
                echo "📦 Found devbox.json - installing project dependencies..."
                devbox install 2>/dev/null
                echo "🚀 Starting Claude with --dangerously-skip-permissions..."
                echo ""
                devbox run -- claude --dangerously-skip-permissions '"$*"'
            else
                echo "🚀 Starting Claude with --dangerously-skip-permissions..."
                echo ""
                claude --dangerously-skip-permissions '"$*"'
            fi
        '
}

# Default behavior: start tmux+claude in current dir
_c_default() {
    # Find git root (closest parent with .git, or current dir)
    git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

    # Ensure beads daemon is running with proper flags
    _c_ensure_beads_daemon "$git_root"

    git_folder=$(basename "$git_root")
    parent_folder=$(basename "$(dirname "$git_root")")

    # Normalized versions for session name
    git_folder_norm=$(_c_normalize "$git_folder")
    parent_folder_norm=$(_c_normalize "$parent_folder")

    # Title: Claude: Parent/GitFolder
    title="Claude: $parent_folder/$git_folder"

    # Set Ghostty window/tab title
    printf '\033]0;%s\007' "$title"

    if test -n "$TMUX"; then
        # Already in tmux, just run claude
        claude "$@"
    else
        # Generate session name: claude-<parent>-<git_folder>-<timestamp>
        timestamp=$(date +%s)
        session_name="claude-$parent_folder_norm-$git_folder_norm-$timestamp"

        # Start tmux and run claude inside (exit tmux when claude exits)
        tmux new-session -s "$session_name" "claude $*"
    fi
}

# Work: create worktree and start claude
_c_worktree() {
    if test $# -lt 1; then
        echo "Usage: c work <branch>"
        return 1
    fi

    branch="$1"
    shift
    extra_args="$*"

    # Get git info
    if ! _c_get_git_info; then
        return 1
    fi

    # Normalize branch for directory
    norm_branch=$(_c_normalize "$branch")
    workspace_base=$(_c_workspace_base)
    workspace_parent="$workspace_base/$_parent_folder_norm/$_git_folder_norm/$norm_branch"

    # Generate unique workspace ID
    uuid=$(_c_gen_uuid)
    workspace_path="$workspace_parent/$uuid"

    # Create workspace directory
    mkdir -p "$workspace_path"

    # Check if branch exists locally
    branch_exists=$(git rev-parse --verify "$branch" 2>/dev/null)

    # Check if branch exists remotely (if not locally)
    if test -z "$branch_exists"; then
        remote_branch=$(git ls-remote --heads origin "$branch" 2>/dev/null)
        if test -n "$remote_branch"; then
            # Fetch the remote branch first
            git fetch origin "$branch:$branch" 2>/dev/null
            branch_exists="true"
        fi
    fi

    # Create worktree
    if test -n "$branch_exists"; then
        git worktree add "$workspace_path" "$branch"
    else
        # Create new branch from current HEAD
        git worktree add -b "$branch" "$workspace_path"
    fi

    if test $? -ne 0; then
        echo "Failed to create worktree"
        rmdir "$workspace_path" 2>/dev/null
        return 1
    fi

    # Write metadata
    echo "created_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$workspace_path/.workspace-meta"
    echo "original_repo=$_git_root" >> "$workspace_path/.workspace-meta"
    echo "branch=$branch" >> "$workspace_path/.workspace-meta"
    echo "id=$uuid" >> "$workspace_path/.workspace-meta"

    # Start tmux with claude in the worktree
    session_name="claude-$_parent_folder_norm-$_git_folder_norm-$norm_branch-$uuid"

    # Set terminal title
    title="Claude: $_parent_folder/$_git_folder ($branch)"
    printf '\033]0;%s\007' "$title"

    # Ensure beads daemon is running with proper flags
    _c_ensure_beads_daemon "$workspace_path"

    echo "Created workspace: $workspace_path"
    echo "Session: $session_name"

    if test -n "$TMUX"; then
        # Already in tmux, create new session and switch
        tmux new-session -d -s "$session_name" -c "$workspace_path" "claude $extra_args"
        tmux switch-client -t "$session_name"
    else
        tmux new-session -s "$session_name" -c "$workspace_path" "claude $extra_args"
    fi
}

# List: show all workspaces
_c_list() {
    workspace_base=$(_c_workspace_base)

    if ! test -d "$workspace_base"; then
        echo "No workspaces found"
        return 0
    fi

    # Header
    printf "%-20s %-30s %-10s %-6s %s\n" "PROJECT" "BRANCH" "ID" "TMUX" "PATH"
    printf '%s\n' "$(printf '%100s' | tr ' ' '-')"

    # Find all workspace metadata files
    find "$workspace_base" -name ".workspace-meta" -type f 2>/dev/null | sort | while read -r meta; do
        ws_path=$(dirname "$meta")

        # Parse metadata
        project=$(echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f1-2 | tr '/' '-')
        branch=$(grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        id=$(grep "^id=" "$meta" 2>/dev/null | cut -d= -f2-)

        # Check for tmux session (match by id)
        has_tmux="no"
        if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -q "$id"; then
            has_tmux="yes"
        fi

        printf "%-20s %-30s %-10s %-6s %s\n" "$project" "$branch" "$id" "$has_tmux" "$ws_path"
    done
}

# Resume: resume a workspace
_c_resume() {
    workspace_base=$(_c_workspace_base)
    filter_id="$1"

    if ! test -d "$workspace_base"; then
        echo "No workspaces found"
        return 1
    fi

    # Build list of workspaces
    workspace_lines=""
    while read -r meta; do
        test -z "$meta" && continue
        ws_path=$(dirname "$meta")
        branch=$(grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        id=$(grep "^id=" "$meta" 2>/dev/null | cut -d= -f2-)
        project=$(echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f1-2 | tr '/' '-')

        # Filter by id if provided
        if test -n "$filter_id"; then
            case "$id" in
                *"$filter_id"*) ;;
                *) continue ;;
            esac
        fi

        if test -n "$workspace_lines"; then
            workspace_lines="$workspace_lines
$id	$project	$branch	$ws_path"
        else
            workspace_lines="$id	$project	$branch	$ws_path"
        fi
    done <<< "$(find "$workspace_base" -name ".workspace-meta" -type f 2>/dev/null | sort)"

    if test -z "$workspace_lines"; then
        echo "No matching workspaces found"
        return 1
    fi

    # Count lines
    line_count=$(echo "$workspace_lines" | wc -l | tr -d ' ')

    # If only one match, use it directly
    if test "$line_count" -eq 1; then
        selected="$workspace_lines"
    else
        # Use fzf for selection
        selected=$(echo "$workspace_lines" | fzf --height=40% --reverse --prompt="Select workspace: " --delimiter='	' --with-nth=1,2,3)
    fi

    if test -z "$selected"; then
        echo "No workspace selected"
        return 1
    fi

    # Parse selection (tab-delimited: id, project, branch, path)
    id=$(echo "$selected" | cut -f1)
    ws_path=$(echo "$selected" | cut -f4)

    # Find or create tmux session
    existing_session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "$id" | head -1)

    if test -n "$existing_session"; then
        # Attach to existing session
        echo "Attaching to session: $existing_session"
        if test -n "$TMUX"; then
            tmux switch-client -t "$existing_session"
        else
            tmux attach-session -t "$existing_session"
        fi
    else
        # Create new session
        meta="$ws_path/.workspace-meta"
        branch=$(grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        norm_branch=$(_c_normalize "$branch")

        parent_norm=$(echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f1)
        repo_norm=$(echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f2)

        session_name="claude-$parent_norm-$repo_norm-$norm_branch-$id"

        # Ensure beads daemon is running with proper flags
        _c_ensure_beads_daemon "$ws_path"

        echo "Starting new session: $session_name"
        if test -n "$TMUX"; then
            tmux new-session -d -s "$session_name" -c "$ws_path" "claude"
            tmux switch-client -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$ws_path" "claude"
        fi
    fi
}

# Clean: interactive cleanup
_c_clean() {
    workspace_base=$(_c_workspace_base)

    if ! test -d "$workspace_base"; then
        echo "No workspaces found"
        return 0
    fi

    echo "Scanning workspaces..."
    echo ""

    removed_count=0
    find "$workspace_base" -name ".workspace-meta" -type f 2>/dev/null | sort | while read -r meta; do
        ws_path=$(dirname "$meta")
        branch=$(grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        id=$(grep "^id=" "$meta" 2>/dev/null | cut -d= -f2-)
        created_at=$(grep "^created_at=" "$meta" 2>/dev/null | cut -d= -f2-)
        original_repo=$(grep "^original_repo=" "$meta" 2>/dev/null | cut -d= -f2-)

        # Check tmux session
        has_session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "$id")

        echo "Workspace: $id"
        echo "  Branch: $branch"
        echo "  Created: $created_at"
        echo "  Path: $ws_path"
        echo "  Original repo: $original_repo"
        if test -n "$has_session"; then
            echo "  Tmux session: ACTIVE (skipping)"
            echo ""
            continue
        else
            echo "  Tmux session: none"
        fi

        printf "  Remove this workspace? [y/N] "
        read -r confirm
        if test "$confirm" = "y" -o "$confirm" = "Y"; then
            # First, remove from git worktree list
            if test -d "$original_repo"; then
                (cd "$original_repo" && git worktree remove --force "$ws_path" 2>/dev/null)
            fi

            # If that failed, manually remove
            if test -d "$ws_path"; then
                rm -rf "$ws_path"
            fi

            echo "  Removed."
            removed_count=$((removed_count + 1))
        else
            echo "  Skipped."
        fi
        echo ""
    done

    # Clean up empty directories
    find "$workspace_base" -type d -empty -delete 2>/dev/null

    echo "Cleanup complete."
}

# Help: show usage
_c_help() {
    echo "c - Claude Code workspace manager"
    echo ""
    echo "USAGE:"
    echo "  c                      Start Claude in current directory"
    echo "  c <args>               Pass args to Claude (e.g., c --help, c -p 'prompt')"
    echo "  c danger|d [args]      Run Claude in Docker with full permissions (sandboxed)"
    echo "  c work|w <branch>      Create worktree for branch, start Claude there"
    echo "  c list|l               List all workspaces"
    echo "  c resume|r [id]        Resume a workspace (fzf selection if no id)"
    echo "  c clean|x              Interactive cleanup of old workspaces"
    echo "  c help|h               Show this help"
    echo ""
    echo "WORKSPACE PATH:"
    echo "  ~/.local/share/git/workspaces/<parent>/<repo>/<branch>/<id>"
    echo ""
    echo "EXAMPLES:"
    echo "  c w feature/my-feature   Create worktree for feature/my-feature"
    echo "  c r a1b2                 Resume workspace matching 'a1b2'"
    echo "  c l                      Show all workspaces with status"
    echo "  c d                      Run Claude in Docker sandbox with full permissions"
}

# Main dispatch
case "$1" in
    "")
        _c_default
        ;;
    danger|d)
        shift
        _c_danger "$@"
        ;;
    work|w)
        shift
        _c_worktree "$@"
        ;;
    list|l)
        _c_list
        ;;
    resume|r)
        shift
        _c_resume "$@"
        ;;
    clean|x)
        _c_clean
        ;;
    help|h)
        _c_help
        ;;
    *)
        # Pass through to claude (existing behavior)
        _c_default "$@"
        ;;
esac
