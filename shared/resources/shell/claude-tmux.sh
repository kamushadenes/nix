# Claude Code workspace manager
# Usage: c [OPTIONS] [COMMAND] [ARGS...]
#
# OPTIONS:
#   -d, --danger         Run in Docker sandbox (can combine with commands)
#
# COMMANDS:
#   c                    - Start tmux+claude in current directory
#   c <args>             - Pass args to claude
#   c work|w <branch>    - Create worktree for branch, start claude there
#   c list|l             - List all workspaces
#   c resume|r [id]      - Resume workspace (fzf if no id)
#   c clean|x            - Interactive cleanup of old workspaces
#   c help|h             - Show help
#
# EXAMPLES:
#   c -d                 - Run Claude in Docker sandbox
#   c -d w feature-x     - Create worktree + run in Docker sandbox

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

# Helper: compute hash of devbox.json for project image tagging
_c_devbox_hash() {
    local devbox_file="$1"
    if test -f "$devbox_file"; then
        md5sum "$devbox_file" | cut -c1-12
    else
        echo "none"
    fi
}

# Helper: build base image if needed
_c_build_base_image() {
    local base_image="claude-sandbox:base"
    local dockerfile_dir="$HOME/.config/docker/claude-sandbox"

    if ! test -f "$dockerfile_dir/Dockerfile.base"; then
        echo "Error: Dockerfile.base not found at $dockerfile_dir"
        echo "Run 'rebuild' to deploy Docker resources"
        return 1
    fi

    # Check if base image exists
    if ! docker image inspect "$base_image" >/dev/null 2>&1; then
        echo "Building claude-sandbox base image (first time only)..." >&2
        # Copy to temp dir to resolve symlinks (Docker can't follow nix store symlinks)
        local build_ctx
        build_ctx=$(mktemp -d)
        cp -L "$dockerfile_dir/Dockerfile.base" "$build_ctx/Dockerfile"
        docker build -t "$base_image" "$build_ctx"
        local build_status=$?
        rm -rf "$build_ctx"
        if test $build_status -ne 0; then
            echo "Error: Failed to build base image" >&2
            return 1
        fi
        echo "Base image built successfully" >&2
    fi
    return 0
}

# Helper: build project-specific image if devbox.json changed
_c_build_project_image() {
    local current_dir="$1"
    local devbox_file="$current_dir/devbox.json"
    local entrypoint_src="$HOME/.config/docker/claude-sandbox/entrypoint.sh"

    # Compute project hash
    local devbox_hash
    devbox_hash=$(_c_devbox_hash "$devbox_file")
    local project_image="claude-sandbox:project-$devbox_hash"

    # Check if project image already exists
    if docker image inspect "$project_image" >/dev/null 2>&1; then
        echo "$project_image"
        return 0
    fi

    # Build base image first if needed
    if ! _c_build_base_image; then
        return 1
    fi

    # If no devbox.json, use base image directly
    if test "$devbox_hash" = "none"; then
        echo "claude-sandbox:base"
        return 0
    fi

    echo "Building project image for devbox.json (hash: $devbox_hash)..." >&2

    # Create temp build context
    local build_ctx
    build_ctx=$(mktemp -d)
    cp "$devbox_file" "$build_ctx/"
    test -f "$current_dir/devbox.lock" && cp "$current_dir/devbox.lock" "$build_ctx/"
    cp "$entrypoint_src" "$build_ctx/"

    # Generate project Dockerfile
    cat > "$build_ctx/Dockerfile" << 'DOCKERFILE'
FROM claude-sandbox:base

# Copy project's devbox.json and install deps (as root)
USER root
COPY devbox.json devbox.lock* /tmp/project/
WORKDIR /tmp/project
RUN devbox install 2>&1 || echo "devbox install completed with warnings"

# Pre-cache project shellenv
RUN devbox shellenv > /etc/devbox_project_shellenv 2>/dev/null || true && chmod 644 /etc/devbox_project_shellenv 2>/dev/null || true

# Fix permissions for non-root access
RUN chmod 755 /root 2>/dev/null || true && \
    chmod -R o+rX /root/.local /root/.nix-profile 2>/dev/null || true && \
    chmod -R o+rx /root/go 2>/dev/null || true

# Switch to non-root user
USER claude
ENV HOME=/home/claude

COPY --chmod=755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE

    # Build project image
    docker build -t "$project_image" "$build_ctx"
    local build_status=$?

    # Cleanup
    rm -rf "$build_ctx"

    if test $build_status -ne 0; then
        echo "Error: Failed to build project image" >&2
        return 1
    fi

    echo "$project_image"
    return 0
}

# Danger mode: run claude in Docker container with full permissions
_c_danger() {
    local current_dir
    current_dir=$(pwd)
    local home_dir="$HOME"

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

    # Extract Claude OAuth credentials from keychain (macOS)
    local creds_temp=""
    if command -v security >/dev/null 2>&1; then
        local keychain_creds
        keychain_creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if test -n "$keychain_creds"; then
            creds_temp=$(mktemp)
            echo "$keychain_creds" > "$creds_temp"
            echo "Extracted Claude credentials from keychain"
        else
            echo "No Claude credentials found in keychain (will use ANTHROPIC_API_KEY if set)"
        fi
    fi

    # Build project image (handles base image building too)
    local image_name
    image_name=$(_c_build_project_image "$current_dir")
    if test $? -ne 0; then
        test -n "$creds_temp" && rm -f "$creds_temp"
        return 1
    fi

    # Container name based on directory
    local dir_hash
    dir_hash=$(echo "$current_dir" | md5sum | cut -c1-8)
    local container_name="claude-danger-$dir_hash"

    # Create temp staging directory and copy configs with dereferenced symlinks
    # (home-manager creates symlinks to nix store which don't exist in container)
    # Use rsync to handle symlinks properly and exclude .git dirs
    local staging_dir
    staging_dir=$(mktemp -d)
    if test -d "$home_dir/.claude"; then
        rsync -rL --exclude='.git' --exclude='*.ipc' "$home_dir/.claude/" "$staging_dir/.claude/" 2>/dev/null || cp -r "$home_dir/.claude" "$staging_dir/.claude"
    fi
    if test -f "$home_dir/.claude.json"; then
        cp -L "$home_dir/.claude.json" "$staging_dir/.claude.json" 2>/dev/null || cp "$home_dir/.claude.json" "$staging_dir/.claude.json"
    fi

    # Build volume mounts
    local mounts=()
    # Mount current directory at SAME path (critical for path consistency)
    mounts+=("-v" "$current_dir:$current_dir")
    # Stage claude config for copying (entrypoint copies to $HOME for full rw access)
    if test -d "$staging_dir/.claude"; then
        mounts+=("-v" "$staging_dir/.claude:/tmp/claude-config-staging/.claude:ro")
    fi
    if test -f "$staging_dir/.claude.json"; then
        mounts+=("-v" "$staging_dir/.claude.json:/tmp/claude-config-staging/.claude.json:ro")
    fi
    # Mount credentials from keychain to separate path (entrypoint copies them)
    if test -n "$creds_temp" && test -f "$creds_temp"; then
        mounts+=("-v" "$creds_temp:/tmp/claude-credentials.json:ro")
    fi
    # Stage all credentials for copying (entrypoint copies to $HOME)
    # SSH
    if test -d "$home_dir/.ssh"; then
        mounts+=("-v" "$home_dir/.ssh:/tmp/creds-staging/.ssh:ro")
    fi
    # Git config
    if test -f "$home_dir/.gitconfig"; then
        mounts+=("-v" "$home_dir/.gitconfig:/tmp/creds-staging/.gitconfig:ro")
    fi
    # AWS
    if test -d "$home_dir/.aws"; then
        mounts+=("-v" "$home_dir/.aws:/tmp/creds-staging/.aws:ro")
    fi
    # Google Cloud
    if test -d "$home_dir/.config/gcloud"; then
        mounts+=("-v" "$home_dir/.config/gcloud:/tmp/creds-staging/.config/gcloud:ro")
    fi
    # Kubernetes
    if test -d "$home_dir/.kube"; then
        mounts+=("-v" "$home_dir/.kube:/tmp/creds-staging/.kube:ro")
    fi
    # Agenix secrets (macOS temp dir)
    if test -n "$DARWIN_USER_TEMP_DIR" && test -d "$DARWIN_USER_TEMP_DIR/agenix"; then
        mounts+=("-v" "$DARWIN_USER_TEMP_DIR/agenix:/tmp/creds-staging/agenix:ro")
    fi
    # Agenix secrets (Linux)
    if test -d "/run/agenix"; then
        mounts+=("-v" "/run/agenix:/tmp/creds-staging/agenix:ro")
    fi
    # Mount entrypoint script (not baked into image, allows changes without rebuild)
    local entrypoint_path="$HOME/.config/docker/claude-sandbox/entrypoint.sh"
    if test -f "$entrypoint_path"; then
        mounts+=("-v" "$entrypoint_path:/entrypoint.sh:ro")
    fi

    echo "Starting Claude in Docker container (danger mode)..."
    echo "   Container: $container_name"
    echo "   Image: $image_name"
    echo "   Workdir: $current_dir"
    echo ""

    # Run container with entrypoint script via bash to avoid command leaking
    docker run -it --rm \
        --name "$container_name" \
        --hostname "claude-sandbox" \
        -w "$current_dir" \
        -e "HOME=/home/claude" \
        -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" \
        -e "CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK" \
        "${mounts[@]}" \
        "$image_name" \
        /bin/bash -c "/entrypoint.sh $*"

    # Cleanup temp files
    if test -n "$creds_temp" && test -f "$creds_temp"; then
        rm -f "$creds_temp"
    fi
    if test -n "$staging_dir" && test -d "$staging_dir"; then
        rm -rf "$staging_dir"
    fi
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
    local use_danger=""
    if test "$1" = "--danger"; then
        use_danger="1"
        shift
    fi

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

    # If danger mode, run in Docker from the workspace
    if test -n "$use_danger"; then
        cd "$workspace_path"
        if test -n "$TMUX"; then
            tmux new-session -d -s "$session_name" -c "$workspace_path" "c -d $extra_args"
            tmux switch-client -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$workspace_path" "c -d $extra_args"
        fi
    else
        if test -n "$TMUX"; then
            # Already in tmux, create new session and switch
            tmux new-session -d -s "$session_name" -c "$workspace_path" "claude $extra_args"
            tmux switch-client -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$workspace_path" "claude $extra_args"
        fi
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
    echo "  c [OPTIONS] [COMMAND] [ARGS...]"
    echo ""
    echo "OPTIONS:"
    echo "  -d, --danger         Run in Docker sandbox (combinable with commands)"
    echo ""
    echo "COMMANDS:"
    echo "  c                    Start Claude in current directory"
    echo "  c <args>             Pass args to Claude (e.g., c --help, c -p 'prompt')"
    echo "  c work|w <branch>    Create worktree for branch, start Claude there"
    echo "  c list|l             List all workspaces"
    echo "  c resume|r [id]      Resume a workspace (fzf selection if no id)"
    echo "  c clean|x            Interactive cleanup of old workspaces"
    echo "  c help|h             Show this help"
    echo ""
    echo "EXAMPLES:"
    echo "  c                      Start Claude normally"
    echo "  c -d                   Run Claude in Docker sandbox"
    echo "  c w feature-x          Create worktree for feature-x"
    echo "  c -d w feature-x       Worktree + Docker sandbox"
    echo "  c r a1b2               Resume workspace matching 'a1b2'"
    echo "  c l                    Show all workspaces with status"
    echo ""
    echo "DOCKER SANDBOX:"
    echo "  The -d option runs Claude in a Docker container with:"
    echo "  - --dangerously-skip-permissions enabled"
    echo "  - devbox packages from project's devbox.json"
    echo "  - Cloud credentials (AWS, gcloud, kubectl)"
    echo "  - SSH keys and git config"
    echo ""
    echo "WORKSPACE PATH:"
    echo "  ~/.local/share/git/workspaces/<parent>/<repo>/<branch>/<id>"
}

# Parse options and dispatch
danger_mode=""
remaining_args=()

# Parse leading options
while test $# -gt 0; do
    case "$1" in
        -d|--danger)
            danger_mode="1"
            shift
            ;;
        *)
            # First non-option, rest are args
            remaining_args=("$@")
            break
            ;;
    esac
done

# Main dispatch
if test -n "$danger_mode"; then
    # Danger mode enabled
    case "${remaining_args[0]}" in
        "")
            _c_danger
            ;;
        work|w)
            _c_worktree --danger "${remaining_args[@]:1}"
            ;;
        list|l)
            _c_list
            ;;
        resume|r)
            _c_resume "${remaining_args[@]:1}"
            ;;
        clean|x)
            _c_clean
            ;;
        help|h)
            _c_help
            ;;
        *)
            # Pass through to danger mode
            _c_danger "${remaining_args[@]}"
            ;;
    esac
else
    # Normal mode (use original args before parsing)
    case "$1" in
        "")
            _c_default
            ;;
        work|w)
            shift
            _c_worktree "" "$@"
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
fi
