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
function _c_normalize
    echo $argv[1] | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//' | sed 's/-$//'
end

# Helper: generate short UUID
function _c_gen_uuid
    uuidgen | cut -c1-8 | tr '[:upper:]' '[:lower:]'
end

# Helper: workspace base directory
function _c_workspace_base
    echo "$HOME/.local/share/git/workspaces"
end

# Helper: ensure beads daemon is running with auto-commit/auto-push
function _c_ensure_beads_daemon
    set target_dir $argv[1]
    if test -z "$target_dir"
        set target_dir (pwd)
    end

    if test -d "$target_dir/.beads"
        # Restart daemon with proper flags (silent, don't fail if not running)
        bd daemon --stop 2>/dev/null
        bd daemon --start --auto-commit --auto-push 2>/dev/null
    end
end

# Helper: get git info, sets global vars
function _c_get_git_info
    set -g _git_root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$_git_root"
        echo "Error: Not in a git repository"
        return 1
    end
    set -g _git_folder (basename "$_git_root")
    set -g _parent_folder (basename (dirname "$_git_root"))
    set -g _git_folder_norm (_c_normalize "$_git_folder")
    set -g _parent_folder_norm (_c_normalize "$_parent_folder")
    return 0
end

# Helper: compute hash of devbox.json for project image tagging
function _c_devbox_hash
    set devbox_file $argv[1]
    if test -f "$devbox_file"
        md5sum "$devbox_file" | cut -c1-12
    else
        echo "none"
    end
end

# Helper: build base image if needed
function _c_build_base_image
    set base_image "claude-sandbox:base"
    set dockerfile_dir "$HOME/.config/docker/claude-sandbox"

    if not test -f "$dockerfile_dir/Dockerfile.base"
        echo "Error: Dockerfile.base not found at $dockerfile_dir"
        echo "Run 'rebuild' to deploy Docker resources"
        return 1
    end

    # Check if base image exists
    if not docker image inspect $base_image >/dev/null 2>&1
        echo "Building claude-sandbox base image (first time only)..." >&2
        # Copy to temp dir to resolve symlinks (Docker can't follow nix store symlinks)
        set build_ctx (mktemp -d)
        cp -L "$dockerfile_dir/Dockerfile.base" "$build_ctx/Dockerfile"
        docker build -t $base_image "$build_ctx"
        set build_status $status
        rm -rf "$build_ctx"
        if test $build_status -ne 0
            echo "Error: Failed to build base image" >&2
            return 1
        end
        echo "Base image built successfully" >&2
    end
    return 0
end

# Helper: build project-specific image if devbox.json changed
function _c_build_project_image
    set current_dir $argv[1]
    set devbox_file "$current_dir/devbox.json"
    set entrypoint_src "$HOME/.config/docker/claude-sandbox/entrypoint.sh"

    # Compute project hash
    set devbox_hash (_c_devbox_hash "$devbox_file")
    set project_image "claude-sandbox:project-$devbox_hash"

    # Check if project image already exists
    if docker image inspect $project_image >/dev/null 2>&1
        echo $project_image
        return 0
    end

    # Build base image first if needed
    if not _c_build_base_image
        return 1
    end

    # If no devbox.json, use base image directly
    if test "$devbox_hash" = "none"
        echo "claude-sandbox:base"
        return 0
    end

    echo "Building project image for devbox.json (hash: $devbox_hash)..." >&2

    # Create temp build context
    set build_ctx (mktemp -d)
    cp "$devbox_file" "$build_ctx/"
    test -f "$current_dir/devbox.lock" && cp "$current_dir/devbox.lock" "$build_ctx/"
    cp "$entrypoint_src" "$build_ctx/"

    # Generate project Dockerfile
    printf '%s\n' \
        'FROM claude-sandbox:base' \
        '' \
        '# Copy project'\''s devbox.json and install deps (as root)' \
        'USER root' \
        'COPY devbox.json devbox.lock* /tmp/project/' \
        'WORKDIR /tmp/project' \
        'RUN devbox install 2>&1 || echo "devbox install completed with warnings"' \
        '' \
        '# Pre-cache project shellenv' \
        'RUN devbox shellenv > /etc/devbox_project_shellenv 2>/dev/null || true && chmod 644 /etc/devbox_project_shellenv 2>/dev/null || true' \
        '' \
        '# Fix permissions for non-root access' \
        'RUN chmod 755 /root 2>/dev/null || true && \\' \
        '    chmod -R o+rX /root/.local /root/.nix-profile 2>/dev/null || true && \\' \
        '    chmod -R o+rx /root/go 2>/dev/null || true' \
        '' \
        '# Switch to non-root user' \
        'USER claude' \
        'ENV HOME=/home/claude' \
        '' \
        'COPY --chmod=755 entrypoint.sh /entrypoint.sh' \
        'ENTRYPOINT ["/entrypoint.sh"]' \
        > "$build_ctx/Dockerfile"

    # Build project image
    docker build -t $project_image "$build_ctx"
    set build_status $status

    # Cleanup
    rm -rf "$build_ctx"

    if test $build_status -ne 0
        echo "Error: Failed to build project image" >&2
        return 1
    end

    echo $project_image
    return 0
end

# Danger mode: run claude in Docker container with full permissions
function _c_danger
    set extra_args $argv
    set current_dir (pwd)
    set home_dir $HOME

    # Check if docker is available
    if not command -q docker
        echo "Error: Docker is not installed or not in PATH"
        return 1
    end

    # Check if docker daemon is running
    if not docker info >/dev/null 2>&1
        echo "Error: Docker daemon is not running"
        return 1
    end

    # Extract Claude OAuth credentials from keychain (macOS)
    set -l creds_temp ""
    if command -q security
        set -l keychain_creds (security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if test -n "$keychain_creds"
            set creds_temp (mktemp)
            echo "$keychain_creds" > "$creds_temp"
            echo "Extracted Claude credentials from keychain"
        else
            echo "No Claude credentials found in keychain (will use ANTHROPIC_API_KEY if set)"
        end
    end

    # Build project image (handles base image building too)
    set image_name (_c_build_project_image "$current_dir")
    if test $status -ne 0
        test -n "$creds_temp" && rm -f "$creds_temp"
        return 1
    end

    # Container name based on directory
    set dir_hash (echo "$current_dir" | md5sum | cut -c1-8)
    set container_name "claude-danger-$dir_hash"

    # Create temp staging directory and copy configs with dereferenced symlinks
    # (home-manager creates symlinks to nix store which don't exist in container)
    # Use rsync to handle symlinks properly and exclude .git dirs
    set -l staging_dir (mktemp -d)
    if test -d "$home_dir/.claude"
        rsync -rL --exclude='.git' --exclude='*.ipc' "$home_dir/.claude/" "$staging_dir/.claude/" 2>/dev/null || cp -r "$home_dir/.claude" "$staging_dir/.claude"
    end
    if test -f "$home_dir/.claude.json"
        cp -L "$home_dir/.claude.json" "$staging_dir/.claude.json" 2>/dev/null || cp "$home_dir/.claude.json" "$staging_dir/.claude.json"
    end

    # Build volume mounts
    set -l mounts
    # Mount current directory at SAME path (critical for path consistency)
    set mounts $mounts "-v" "$current_dir:$current_dir"
    # Stage claude config for copying (entrypoint copies to $HOME for full rw access)
    if test -d "$staging_dir/.claude"
        set mounts $mounts "-v" "$staging_dir/.claude:/tmp/claude-config-staging/.claude:ro"
    end
    if test -f "$staging_dir/.claude.json"
        set mounts $mounts "-v" "$staging_dir/.claude.json:/tmp/claude-config-staging/.claude.json:ro"
    end
    # Mount credentials from keychain to separate path (entrypoint copies them)
    if test -n "$creds_temp" -a -f "$creds_temp"
        set mounts $mounts "-v" "$creds_temp:/tmp/claude-credentials.json:ro"
    end
    # Stage all credentials for copying (entrypoint copies to $HOME)
    # SSH
    if test -d "$home_dir/.ssh"
        set mounts $mounts "-v" "$home_dir/.ssh:/tmp/creds-staging/.ssh:ro"
    end
    # Git config
    if test -f "$home_dir/.gitconfig"
        set mounts $mounts "-v" "$home_dir/.gitconfig:/tmp/creds-staging/.gitconfig:ro"
    end
    # AWS
    if test -d "$home_dir/.aws"
        set mounts $mounts "-v" "$home_dir/.aws:/tmp/creds-staging/.aws:ro"
    end
    # Google Cloud
    if test -d "$home_dir/.config/gcloud"
        set mounts $mounts "-v" "$home_dir/.config/gcloud:/tmp/creds-staging/.config/gcloud:ro"
    end
    # Kubernetes
    if test -d "$home_dir/.kube"
        set mounts $mounts "-v" "$home_dir/.kube:/tmp/creds-staging/.kube:ro"
    end
    # Agenix secrets (macOS temp dir)
    if test -n "$DARWIN_USER_TEMP_DIR" -a -d "$DARWIN_USER_TEMP_DIR/agenix"
        set mounts $mounts "-v" "$DARWIN_USER_TEMP_DIR/agenix:/tmp/creds-staging/agenix:ro"
    end
    # Agenix secrets (Linux)
    if test -d "/run/agenix"
        set mounts $mounts "-v" "/run/agenix:/tmp/creds-staging/agenix:ro"
    end
    # Mount entrypoint script (not baked into image, allows changes without rebuild)
    set entrypoint_path "$HOME/.config/docker/claude-sandbox/entrypoint.sh"
    if test -f "$entrypoint_path"
        set mounts $mounts "-v" "$entrypoint_path:/entrypoint.sh:ro"
    end

    echo "Starting Claude in Docker container (danger mode)..."
    echo "   Container: $container_name"
    echo "   Image: $image_name"
    echo "   Workdir: $current_dir"
    echo ""

    # Run container with entrypoint script
    docker run -it --rm \
        --name "$container_name" \
        --hostname "claude-sandbox" \
        -w "$current_dir" \
        -e "HOME=/home/claude" \
        -e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" \
        -e "CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK" \
        $mounts \
        $image_name \
        /entrypoint.sh $extra_args

    # Cleanup temp files
    if test -n "$creds_temp" -a -f "$creds_temp"
        rm -f "$creds_temp"
    end
    if test -n "$staging_dir" -a -d "$staging_dir"
        rm -rf "$staging_dir"
    end
end

# Default behavior: start tmux+claude in current dir
function _c_default
    set extra_args $argv

    # Find git root (closest parent with .git, or current dir)
    set git_root (git rev-parse --show-toplevel 2>/dev/null || pwd)

    # Ensure beads daemon is running with proper flags
    _c_ensure_beads_daemon "$git_root"
    set git_folder (basename "$git_root")
    set parent_folder (basename (dirname "$git_root"))

    # Normalized versions for session name
    set git_folder_norm (_c_normalize "$git_folder")
    set parent_folder_norm (_c_normalize "$parent_folder")

    # Title: Claude: Parent/GitFolder
    set title "Claude: $parent_folder/$git_folder"

    # Set Ghostty window/tab title
    printf '\033]0;%s\007' "$title"

    if test -n "$TMUX"
        # Already in tmux, just run claude
        claude $extra_args
    else
        # Generate session name: claude-<parent>-<git_folder>-<timestamp>
        set timestamp (date +%s)
        set session_name "claude-$parent_folder_norm-$git_folder_norm-$timestamp"

        # Start tmux and run claude inside (exit tmux when claude exits)
        tmux new-session -s "$session_name" "claude $extra_args"
    end
end

# Work: create worktree and start claude
function _c_worktree
    set use_danger $argv[1]
    if test "$use_danger" = "--danger"
        set -e argv[1]
    else
        set use_danger ""
    end

    if test (count $argv) -lt 1
        echo "Usage: c work <branch>"
        return 1
    end

    set branch $argv[1]
    set extra_args $argv[2..-1]

    # Get git info
    if not _c_get_git_info
        return 1
    end

    # Normalize branch for directory
    set norm_branch (_c_normalize "$branch")
    set workspace_base (_c_workspace_base)
    set workspace_parent "$workspace_base/$_parent_folder_norm/$_git_folder_norm/$norm_branch"

    # Generate unique workspace ID
    set uuid (_c_gen_uuid)
    set workspace_path "$workspace_parent/$uuid"

    # Create workspace directory
    mkdir -p "$workspace_path"

    # Check if branch exists locally
    set branch_exists (git rev-parse --verify "$branch" 2>/dev/null)

    # Check if branch exists remotely (if not locally)
    if test -z "$branch_exists"
        set remote_branch (git ls-remote --heads origin "$branch" 2>/dev/null)
        if test -n "$remote_branch"
            # Fetch the remote branch first
            git fetch origin "$branch:$branch" 2>/dev/null
            set branch_exists "true"
        end
    end

    # Create worktree
    if test -n "$branch_exists"
        git worktree add "$workspace_path" "$branch"
    else
        # Create new branch from current HEAD
        git worktree add -b "$branch" "$workspace_path"
    end

    if test $status -ne 0
        echo "Failed to create worktree"
        rmdir "$workspace_path" 2>/dev/null
        return 1
    end

    # Write metadata
    echo "created_at="(date -u +%Y-%m-%dT%H:%M:%SZ) > "$workspace_path/.workspace-meta"
    echo "original_repo=$_git_root" >> "$workspace_path/.workspace-meta"
    echo "branch=$branch" >> "$workspace_path/.workspace-meta"
    echo "id=$uuid" >> "$workspace_path/.workspace-meta"

    # Start tmux with claude in the worktree
    set session_name "claude-$_parent_folder_norm-$_git_folder_norm-$norm_branch-$uuid"

    # Set terminal title
    set title "Claude: $_parent_folder/$_git_folder ($branch)"
    printf '\033]0;%s\007' "$title"

    # Ensure beads daemon is running with proper flags
    _c_ensure_beads_daemon "$workspace_path"

    echo "Created workspace: $workspace_path"
    echo "Session: $session_name"

    # If danger mode, run in Docker from the workspace
    if test -n "$use_danger"
        cd "$workspace_path"
        if test -n "$TMUX"
            tmux new-session -d -s "$session_name" -c "$workspace_path" "c -d $extra_args"
            tmux switch-client -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$workspace_path" "c -d $extra_args"
        end
    else
        if test -n "$TMUX"
            # Already in tmux, create new session and switch
            tmux new-session -d -s "$session_name" -c "$workspace_path" "claude $extra_args"
            tmux switch-client -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$workspace_path" "claude $extra_args"
        end
    end
end

# List: show all workspaces
function _c_list
    set workspace_base (_c_workspace_base)

    if not test -d "$workspace_base"
        echo "No workspaces found"
        return 0
    end

    # Header
    printf "%-20s %-30s %-10s %-6s %s\n" "PROJECT" "BRANCH" "ID" "TMUX" "PATH"
    printf "%s\n" (string repeat -n 100 "-")

    # Find all workspace metadata files
    for meta in (find "$workspace_base" -name ".workspace-meta" -type f 2>/dev/null | sort)
        set ws_path (dirname "$meta")

        # Parse metadata
        set project (echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f1-2 | tr '/' '-')
        set branch (grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        set id (grep "^id=" "$meta" 2>/dev/null | cut -d= -f2-)

        # Check for tmux session (match by id)
        set has_tmux "no"
        if tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -q "$id"
            set has_tmux "yes"
        end

        printf "%-20s %-30s %-10s %-6s %s\n" "$project" "$branch" "$id" "$has_tmux" "$ws_path"
    end
end

# Resume: resume a workspace
function _c_resume
    set workspace_base (_c_workspace_base)
    set filter_id $argv[1]

    if not test -d "$workspace_base"
        echo "No workspaces found"
        return 1
    end

    # Build list of workspaces
    set workspace_lines
    for meta in (find "$workspace_base" -name ".workspace-meta" -type f 2>/dev/null | sort)
        set ws_path (dirname "$meta")
        set branch (grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        set id (grep "^id=" "$meta" 2>/dev/null | cut -d= -f2-)
        set project (echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f1-2 | tr '/' '-')

        # Filter by id if provided
        if test -n "$filter_id"
            if not string match -q "*$filter_id*" "$id"
                continue
            end
        end

        set workspace_lines $workspace_lines "$id\t$project\t$branch\t$ws_path"
    end

    if test (count $workspace_lines) -eq 0
        echo "No matching workspaces found"
        return 1
    end

    # If only one match, use it directly
    if test (count $workspace_lines) -eq 1
        set selected $workspace_lines[1]
    else
        # Use fzf for selection
        set selected (printf "%s\n" $workspace_lines | fzf --height=40% --reverse --prompt="Select workspace: " --delimiter='\t' --with-nth=1,2,3)
    end

    if test -z "$selected"
        echo "No workspace selected"
        return 1
    end

    # Parse selection (tab-delimited: id, project, branch, path)
    set id (echo $selected | cut -f1)
    set ws_path (echo $selected | cut -f4)

    # Find or create tmux session
    set existing_session (tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "$id" | head -1)

    if test -n "$existing_session"
        # Attach to existing session
        echo "Attaching to session: $existing_session"
        if test -n "$TMUX"
            tmux switch-client -t "$existing_session"
        else
            tmux attach-session -t "$existing_session"
        end
    else
        # Create new session
        set meta "$ws_path/.workspace-meta"
        set branch (grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        set norm_branch (_c_normalize "$branch")

        set parent_norm (echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f1)
        set repo_norm (echo "$ws_path" | sed "s|$workspace_base/||" | cut -d/ -f2)

        set session_name "claude-$parent_norm-$repo_norm-$norm_branch-$id"

        # Ensure beads daemon is running with proper flags
        _c_ensure_beads_daemon "$ws_path"

        echo "Starting new session: $session_name"
        if test -n "$TMUX"
            tmux new-session -d -s "$session_name" -c "$ws_path" "claude"
            tmux switch-client -t "$session_name"
        else
            tmux new-session -s "$session_name" -c "$ws_path" "claude"
        end
    end
end

# Clean: interactive cleanup
function _c_clean
    set workspace_base (_c_workspace_base)

    if not test -d "$workspace_base"
        echo "No workspaces found"
        return 0
    end

    echo "Scanning workspaces..."
    echo ""

    set removed_count 0
    for meta in (find "$workspace_base" -name ".workspace-meta" -type f 2>/dev/null | sort)
        set ws_path (dirname "$meta")
        set branch (grep "^branch=" "$meta" 2>/dev/null | cut -d= -f2-)
        set id (grep "^id=" "$meta" 2>/dev/null | cut -d= -f2-)
        set created_at (grep "^created_at=" "$meta" 2>/dev/null | cut -d= -f2-)
        set original_repo (grep "^original_repo=" "$meta" 2>/dev/null | cut -d= -f2-)

        # Check tmux session
        set has_session (tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "$id")

        echo "Workspace: $id"
        echo "  Branch: $branch"
        echo "  Created: $created_at"
        echo "  Path: $ws_path"
        echo "  Original repo: $original_repo"
        if test -n "$has_session"
            echo "  Tmux session: ACTIVE (skipping)"
            echo ""
            continue
        else
            echo "  Tmux session: none"
        end

        read -P "  Remove this workspace? [y/N] " confirm
        if test "$confirm" = "y" -o "$confirm" = "Y"
            # First, remove from git worktree list
            if test -d "$original_repo"
                cd "$original_repo" && git worktree remove --force "$ws_path" 2>/dev/null
            end

            # If that failed, manually remove
            if test -d "$ws_path"
                rm -rf "$ws_path"
            end

            echo "  Removed."
            set removed_count (math $removed_count + 1)
        else
            echo "  Skipped."
        end
        echo ""
    end

    # Clean up empty directories
    find "$workspace_base" -type d -empty -delete 2>/dev/null

    echo "Cleanup complete. Removed $removed_count workspace(s)."
end

# Help: show usage
function _c_help
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
end

# Parse options and dispatch
set -l danger_mode ""
set -l remaining_args

# Parse leading options
set -l i 1
while test $i -le (count $argv)
    switch $argv[$i]
        case "-d" "--danger"
            set danger_mode "1"
        case "*"
            # First non-option, rest are args
            set remaining_args $argv[$i..-1]
            break
    end
    set i (math $i + 1)
end

# Main dispatch
if test -n "$danger_mode"
    # Danger mode enabled
    switch "$remaining_args[1]"
        case ""
            _c_danger
        case "work" "w"
            _c_worktree --danger $remaining_args[2..-1]
        case "list" "l"
            _c_list
        case "resume" "r"
            _c_resume $remaining_args[2..-1]
        case "clean" "x"
            _c_clean
        case "help" "h"
            _c_help
        case "*"
            # Pass through to danger mode
            _c_danger $remaining_args
    end
else
    # Normal mode
    switch "$argv[1]"
        case ""
            _c_default
        case "work" "w"
            _c_worktree "" $argv[2..-1]
        case "list" "l"
            _c_list
        case "resume" "r"
            _c_resume $argv[2..-1]
        case "clean" "x"
            _c_clean
        case "help" "h"
            _c_help
        case "*"
            # Pass through to claude (existing behavior)
            _c_default $argv
    end
end
