# Testing Patterns

**Analysis Date:** 2026-02-21

## Test Framework

This is a Nix flake configuration, not a traditional software project. There are no unit tests. Validation is done through Nix evaluation, building, and deployment.

**Primary validation tools:**
- `nix flake check` - Evaluate flake and check for errors
- `rebuild` - Build and switch to the new configuration (the "test suite")
- `nixfmt` - Format Nix files (enforced via pre-commit hook)

**Run Commands:**
```bash
rebuild                    # Build and switch locally (current machine)
rebuild aether             # Deploy to single remote target
rebuild -vL moltbot        # LXC deploy: verbose + local build
rebuild @headless          # Deploy to all nodes with @headless tag
rebuild -pa                # Parallel deploy to all machines
rebuild --list             # List nodes and tags
rebuild -n @nixos          # Dry run - show what would deploy
nix flake check            # Evaluate flake for errors (rarely used standalone)
nixfmt -v file.nix         # Format a Nix file
```

## Validation Strategy

### Pre-Commit (Automated)

**Tool:** Lefthook (`lefthook.yml`)
**Config:** `/Users/kamushadenes/.config/nix/config/lefthook.yml`

```yaml
pre-commit:
  commands:
    linter:
      glob: "*.nix"
      run: nixfmt -v {all_files}
```

This ensures all committed Nix files are properly formatted with `nixfmt`.

### Build-Time Validation

The Nix build system itself is the primary "test suite." When `rebuild` runs:

1. **Flake evaluation** - Nix evaluates all module expressions, catching:
   - Type errors
   - Missing attributes
   - Invalid option values
   - Import failures (missing files)
   - Syntax errors

2. **Derivation building** - Nix builds all packages and configurations, catching:
   - Package build failures
   - Missing dependencies
   - Invalid file references

3. **Activation** - Home-manager and system activation scripts run, catching:
   - Secret decryption failures
   - File permission issues
   - Service configuration errors

### Deployment Validation

**The `rebuild` command** (`shared/resources/deploy.py`):
- Python-based deployment tool with parallel execution
- Supports tag-based filtering (`@headless`, `@nixos`, `@darwin`)
- Handles local builds, remote deployment via SSH, and Proxmox LXC targets
- Decrypts cache signing key before builds
- Uses `nh` (Nix Helper) under the hood for actual switch operations

**Local rebuild flow:**
```
rebuild → decrypt cache key → nh darwin switch --impure (macOS)
rebuild → decrypt cache key → sudo nixos-rebuild switch --flake ... --impure (NixOS)
```

**Remote rebuild flow:**
```
rebuild <target> → SSH to target → nh os switch (or nix-darwin equivalent)
rebuild -vL <lxc> → build locally → push to LXC via SSH
```

**Critical: New files must be git-tracked before Nix can see them.** Nix flakes only evaluate files tracked by git. Always `git add` new files before `rebuild` or `nix flake check`.

### Cache Validation

**Binary cache:** `ncps.hyades.io:8501` (self-hosted Nix Cache Proxy Server)
- If cache times out, the build is interrupted and must be retried
- Cache errors are NOT benign - packages may not be fully installed

## Formatting

**Formatter:** `nixfmt`
**Enforcement:** Pre-commit hook via lefthook
**Manual use:**
```bash
nixfmt file.nix          # Format single file
nixfmt -v *.nix          # Format with verbose output
nix fmt                  # Format via flake (if configured)
```

## CI/CD

**No GitHub Actions CI/CD.** There is no `.github/workflows/` directory.

Validation is entirely local:
1. Edit Nix files
2. Lefthook pre-commit runs `nixfmt` on staged `.nix` files
3. `rebuild` builds and activates the configuration
4. If rebuild succeeds, the configuration is valid

## Claude Code Hooks (AI-Assisted Development)

Claude Code hooks provide additional validation when AI agents modify files:

**PreToolUse hooks:**
- `tdd-guard` - Enforces TDD discipline for code changes
- `git-safety-guard.py` - Blocks destructive git commands
- `suggest-modern-tools.py` - Suggests modern CLI alternatives

**PostToolUse hooks (auto-formatting):**
- `format-nix.sh` - Auto-formats `.nix` files after edits
- `format-python.sh` - Auto-formats `.py` files
- `format-typescript.sh` - Auto-formats `.ts`/`.tsx` files
- `format-go.sh` - Auto-formats `.go` files
- `format-markdown.sh` - Auto-formats `.md` files

**PostToolUseFailure hooks:**
- `suggest-nix-shell.sh` - Suggests nix-shell when commands are not found

**Stop hooks:**
- `post-lint.sh` - Runs linting when session ends
- `session-cleanup.sh` - Cleanup tasks

Hook scripts live in:
- `/Users/kamushadenes/.config/nix/config/home/common/ai/resources/claude-code/scripts/hooks/`

## TDD Guard Integration

TDD Guard is installed for Go, Python, and TypeScript projects (not for Nix itself):

**Go:** `tdd-guard-go` binary in `home/common/dev/go.nix`
```bash
go test -json ./... 2>&1 | tdd-guard-go
```

**Python:** `tdd-guard-pytest` plugin in `home/common/dev/python.nix`
```bash
pytest  # Plugin activates automatically
```

**TypeScript:** `tdd-guard-vitest` reporter in `home/common/dev/node.nix`
```typescript
// vitest.config.ts
import { VitestReporter } from 'tdd-guard-vitest'
export default defineConfig({
  test: { reporters: ['default', new VitestReporter()] }
})
```

**Core TDD Guard:** Installed as npm package on Linux (`home/common/dev/node.nix`), via homebrew on macOS.

## Nix File Validation Checklist

When modifying this codebase, verify:

1. **Format check:** Run `nixfmt` on changed `.nix` files
2. **New files:** `git add` new files before `rebuild` (flakes require git tracking)
3. **Private submodule:** If modifying `private/`, commit there first, then update submodule ref
4. **Secret files:** Never commit plaintext secrets; use agenix `.age` files with `@PLACEHOLDER@` substitution
5. **Local rebuild:** Run `rebuild` to validate the full configuration builds and activates
6. **Remote targets:** Use `rebuild -vL <target>` for LXC deployments (builds locally, streams output)
7. **Cache errors:** If rebuild fails with cache timeout, retry - the build was interrupted

## Common Failure Modes

**Missing git tracking:**
```
error: getting status of '/nix/store/.../new-file.nix': No such file or directory
```
Fix: `git add new-file.nix`

**Cache timeout:**
```
error: unable to download 'http://ncps.hyades.io:8501/...': Connection timed out
```
Fix: Run `rebuild` again

**Private submodule out of sync:**
```
error: path '...' does not exist
```
Fix: Commit in `private/` submodule first, then commit submodule reference in main repo

**Impure evaluation required:**
```
error: access to absolute path '...' is forbidden in pure evaluation mode
```
Fix: Use `--impure` flag (the `rebuild` command handles this automatically)

**Option conflict:**
```
error: The option '...' is defined in both ... and ...
```
Fix: Use `lib.mkForce`, `lib.mkDefault`, or `lib.mkMerge` to resolve conflicts

---

*Testing analysis: 2026-02-21*
