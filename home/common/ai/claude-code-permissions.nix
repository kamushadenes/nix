# Claude Code permissions configuration
# Extracted from claude-code.nix for maintainability
#
# This file defines the auto-approved tools for Claude Code.
# Categories are organized by tool type for easy maintenance.
{
  # Deny reading TDD guard internal files to prevent circumvention
  deny = [
    "Read(.claude/tdd-guard/**)"
  ];

  allow = [
    # Core tools
    "AskUserQuestion"

    # Basic commands
    "Bash(curl:*)"
    "Bash(tree:*)"
    "Bash(cat:*)"
    "Bash(wc:*)"
    "Bash(grep:*)"
    "Bash(ls:*)"
    "Bash(stat:*)"
    "Bash(rg:*)"
    "Bash(fd:*)"
    "Bash(mkdir:*)"
    "Bash(test:*)"
    # Let's hope Claude doesn't use find's exec to run dangerous commands
    "Bash(find:*)"
    "Search"

    # Text processing
    "Bash(sort:*)"
    "Bash(head:*)"
    "Bash(tail:*)"
    "Bash(cut:*)"
    "Bash(paste:*)"
    "Bash(xxd:*)"
    "Bash(readlink:*)"
    "Bash(jq:*)"
    "Bash(yq:*)"

    # Modern Unix tools (rust/go replacements)
    "Bash(bat:*)"
    "Bash(eza:*)"
    "Bash(exa:*)"
    "Bash(dust:*)"
    "Bash(duf:*)"
    "Bash(procs:*)"
    "Bash(hyperfine:*)"
    "Bash(tokei:*)"
    "Bash(delta:*)"
    "Bash(difft:*)"
    "Bash(doggo:*)"
    "Bash(xh:*)"
    "Bash(httpie:*)"
    "Bash(http:*)"
    "Bash(curlie:*)"
    "Bash(glow:*)"
    "Bash(fzf:*)"
    "Bash(zoxide:*)"

    # Nix commands
    "Bash(nix flake check:*)"
    "Bash(nix flake show:*)"
    "Bash(nix flake metadata:*)"
    "Bash(nix eval:*)"
    "Bash(nix-instantiate:*)"
    "Bash(nix path-info:*)"
    "Bash(nix fmt:*)"
    "Bash(nix search:*)"
    "Bash(nixfmt:*)"
    "Bash(alejandra:*)"
    "Bash(nix-prefetch-github:*)"
    "Bash(rebuild:*)"
    "Bash(nh darwin switch:*)"

    # Go commands
    "Bash(go mod:*)"
    "Bash(go list:*)"
    "Bash(go test:*)"
    "Bash(go build:*)"
    "Bash(go run:*)"
    "Bash(go doc:*)"
    "Bash(go get:*)"
    "Bash(go version:*)"
    "Bash(go tool cover:*)"
    "Bash(go generate:*)"
    "Bash(golangci-lint run:*)"
    "Bash(gofmt:*)"
    "Bash(goimports:*)"

    # Just task runner
    "Bash(just lint:*)"
    "Bash(just test:*)"
    "Bash(just build:*)"
    "Bash(just gen:*)"
    "Bash(just static:*)"
    "Bash(just md-fmt:*)"
    "Bash(just md-lint:*)"
    "Bash(just md-lint-fix:*)"
    "Bash(just go-lint:*)"
    "Bash(just test-all:*)"
    "Bash(just test-single:*)"
    "Bash(just test-integration-short:*)"

    # Git commands
    "Bash(git ls-files:*)"
    "Bash(git ls-tree:*)"
    "Bash(git submodule status:*)"
    "Bash(git add:*)"
    "Bash(git commit:*)"
    "Bash(git describe:*)"
    "Bash(git tag:*)"
    "Bash(git log:*)"
    "Bash(git push:*)"
    "Bash(git fetch:*)"
    "Bash(git pull:*)"
    "Bash(git clone:*)"
    "Bash(gh pr:*)"
    "Bash(gh run:*)"
    "Bash(gh release:*)"
    "Bash(gh issue:*)"

    # Terraform / Terragrunt
    "Bash(terraform plan:*)"
    "Bash(terraform show:*)"
    "Bash(terraform fmt:*)"
    "Bash(terraform validate:*)"
    "Bash(terragrunt plan:*)"
    "Bash(terragrunt show:*)"
    "Bash(terragrunt validate:*)"
    "Bash(terragrunt init:*)"
    "Bash(terragrunt state list:*)"
    "Bash(terragrunt state show:*)"

    # GCloud - read-only operations
    "Bash(gcloud config:*)"
    "Bash(gcloud auth list:*)"
    "Bash(gcloud projects list:*)"
    "Bash(gcloud projects describe:*)"
    "Bash(gcloud services list:*)"
    "Bash(gcloud compute instances list:*)"
    "Bash(gcloud compute instances describe:*)"
    "Bash(gcloud compute disks list:*)"
    "Bash(gcloud compute networks list:*)"
    "Bash(gcloud compute zones list:*)"
    "Bash(gcloud compute regions list:*)"
    "Bash(gcloud container clusters list:*)"
    "Bash(gcloud container clusters describe:*)"
    "Bash(gcloud run services list:*)"
    "Bash(gcloud run services describe:*)"
    "Bash(gcloud run services logs read:*)"
    "Bash(gcloud run jobs list:*)"
    "Bash(gcloud run revisions list:*)"
    "Bash(gcloud functions list:*)"
    "Bash(gcloud functions describe:*)"
    "Bash(gcloud storage buckets list:*)"
    "Bash(gcloud storage buckets describe:*)"
    "Bash(gcloud storage ls:*)"
    "Bash(gcloud iam service-accounts list:*)"
    "Bash(gcloud logging read:*)"
    "Bash(gcloud logging logs list:*)"
    "Bash(gcloud secrets list:*)"
    "Bash(gcloud secrets versions list:*)"
    "Bash(gcloud secrets versions access:*)"
    "Bash(gcloud sql instances list:*)"
    "Bash(gcloud sql instances describe:*)"
    "Bash(gcloud pubsub topics list:*)"
    "Bash(gcloud pubsub subscriptions list:*)"
    "Bash(gsutil ls:*)"
    "Bash(gsutil cat:*)"
    "Bash(gsutil stat:*)"

    # Tmux commands
    "Bash(tmux list-commands:*)"
    "Bash(tmux list-panes:*)"
    "Bash(tmux list-sessions:*)"
    "Bash(tmux display-message:*)"
    "Bash(tmux capture-pane:*)"
    "Bash(tmux show-options:*)"
    "Bash(tmux -V:*)"
    "Bash(tmux source-file:*)"

    # GSD framework
    "Bash(node ~/.claude/get-shit-done/bin/gsd-tools.cjs:*)"
    "Bash(node *gsd-tools.cjs:*)"
    "Bash(npx get-shit-done-cc:*)"
    "Bash(~/.claude/scripts/gsd-update.sh:*)"

    # Node/NPM - read-only
    "Bash(npm view:*)"
    "Bash(npm ls:*)"

    # Protobuf/Build tools
    "Bash(buf generate:*)"
    "Bash(buf dep update:*)"
    "Bash(buf lint:*)"
    "Bash(goreleaser check:*)"
    "Bash(templ fmt:*)"

    # DevBox
    "Bash(devbox search:*)"
    "Bash(devbox add:*)"

    # Network tools
    "Bash(nslookup:*)"
    "Bash(dig:*)"

    # Misc read-only tools
    "Bash(hcloud server-type:*)"
    "Bash(tdd-guard-go:*)"
    "Bash(launchctl list:*)"
    "Bash(sqlite3:*)"
    "Bash(openssl x509:*)"

    # Web access
    "WebSearch"
    "WebFetch"

    # MCP: DeepWiki
    "mcp__deepwiki__ask_question"
    "mcp__deepwiki__read_wiki_contents"

    # MCP: Ref
    "mcp__ref__ref_search_documentation"
    "mcp__Ref__ref_read_url"

    # MCP: Terraform
    "mcp__terraform__search_providers"
    "mcp__terraform__get_provider_details"
    "mcp__terraform__get_provider_capabilities"

    # MCP: GitHub
    "mcp__github__list_issues"

    # MCP: IDE
    "mcp__ide__getDiagnostics"

    # MCP: Orchestrator - tmux
    "mcp__orchestrator__tmux_new_window"
    "mcp__orchestrator__tmux_send"
    "mcp__orchestrator__tmux_wait_idle"
    "mcp__orchestrator__tmux_capture"
    "mcp__orchestrator__tmux_list"
    "mcp__orchestrator__tmux_select"
    "mcp__orchestrator__tmux_kill"
    "mcp__orchestrator__tmux_interrupt"
    "mcp__orchestrator__notify"

    # MCP: Claude-in-Chrome browser automation
    "mcp__claude-in-chrome__javascript_tool"
    "mcp__claude-in-chrome__read_page"
    "mcp__claude-in-chrome__find"
    "mcp__claude-in-chrome__form_input"
    "mcp__claude-in-chrome__computer"
    "mcp__claude-in-chrome__navigate"
    "mcp__claude-in-chrome__resize_window"
    "mcp__claude-in-chrome__gif_creator"
    "mcp__claude-in-chrome__upload_image"
    "mcp__claude-in-chrome__get_page_text"
    "mcp__claude-in-chrome__tabs_context_mcp"
    "mcp__claude-in-chrome__tabs_create_mcp"
    "mcp__claude-in-chrome__update_plan"
    "mcp__claude-in-chrome__read_console_messages"
    "mcp__claude-in-chrome__read_network_requests"
    "mcp__claude-in-chrome__shortcuts_list"
    "mcp__claude-in-chrome__shortcuts_execute"

    # MCP: ClickUp - Task management
    "mcp__iniciador-clickup__clickup_search"
    "mcp__iniciador-clickup__clickup_get_workspace_hierarchy"
    "mcp__iniciador-clickup__clickup_create_task"
    "mcp__iniciador-clickup__clickup_get_task"
    "mcp__iniciador-clickup__clickup_update_task"
    "mcp__iniciador-clickup__clickup_get_task_comments"
    "mcp__iniciador-clickup__clickup_create_task_comment"
    "mcp__iniciador-clickup__clickup_attach_task_file"
    "mcp__iniciador-clickup__clickup_get_task_time_entries"
    "mcp__iniciador-clickup__clickup_start_time_tracking"
    "mcp__iniciador-clickup__clickup_stop_time_tracking"
    "mcp__iniciador-clickup__clickup_add_time_entry"
    "mcp__iniciador-clickup__clickup_get_current_time_entry"
    "mcp__iniciador-clickup__clickup_create_list"
    "mcp__iniciador-clickup__clickup_create_list_in_folder"
    "mcp__iniciador-clickup__clickup_get_list"
    "mcp__iniciador-clickup__clickup_update_list"
    "mcp__iniciador-clickup__clickup_create_folder"
    "mcp__iniciador-clickup__clickup_get_folder"
    "mcp__iniciador-clickup__clickup_update_folder"
    "mcp__iniciador-clickup__clickup_add_tag_to_task"
    "mcp__iniciador-clickup__clickup_remove_tag_from_task"
    "mcp__iniciador-clickup__clickup_get_workspace_members"
    "mcp__iniciador-clickup__clickup_find_member_by_name"
    "mcp__iniciador-clickup__clickup_resolve_assignees"
    "mcp__iniciador-clickup__clickup_get_chat_channels"
    "mcp__iniciador-clickup__clickup_send_chat_message"
    "mcp__iniciador-clickup__clickup_create_document"
    "mcp__iniciador-clickup__clickup_list_document_pages"
    "mcp__iniciador-clickup__clickup_get_document_pages"
    "mcp__iniciador-clickup__clickup_create_document_page"
    "mcp__iniciador-clickup__clickup_update_document_page"

    # MCP: Vanta - Compliance monitoring and control tracking
    "mcp__iniciador-vanta__frameworks"
    "mcp__iniciador-vanta__list_framework_controls"
    "mcp__iniciador-vanta__controls"
    "mcp__iniciador-vanta__tests"
    "mcp__iniciador-vanta__list_test_entities"
    "mcp__iniciador-vanta__list_control_tests"
    "mcp__iniciador-vanta__list_control_documents"
    "mcp__iniciador-vanta__documents"
    "mcp__iniciador-vanta__document_resources"
    "mcp__iniciador-vanta__vulnerabilities"
    "mcp__iniciador-vanta__risks"
    "mcp__iniciador-vanta__integrations"
    "mcp__iniciador-vanta__integration_resources"
    "mcp__iniciador-vanta__people"

    # Skills
    "Skill(hookify:writing-rules)"
    "Skill(deep-review)"
    "Skill(ralph-loop:*)"
    "Skill(plan-to-tasks)"
    "Skill(commit)"
    "Skill(next-task)"

    # Plugin scripts - ralph-loop
    "Bash(~/.claude/plugins/cache/claude-plugins-official/ralph-loop:*)"

    # Read paths
    "Read(//Users/kamushadenes/**)"
  ];
}
