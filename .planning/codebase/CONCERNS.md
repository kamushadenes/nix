# Codebase Concerns

**Analysis Date:** 2026-02-21

## Tech Debt

**LXC Hardware Config Boilerplate Duplication:**
- Issue: 14 LXC hardware configs (`nixos/hardware/*.nix`) repeat identical boilerplate: `boot.isContainer = true`, `getty@tty1` disable, `autovt@` disable, `console-getty` enable, and `nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux"`. Each file differs only in hostname and machine import.
- Files: `nixos/hardware/atuin.nix`, `nixos/hardware/mqtt.nix`, `nixos/hardware/cloudflared-pve1.nix`, `nixos/hardware/cloudflared-pve2.nix`, `nixos/hardware/cloudflared-pve3.nix`, `nixos/hardware/esphome.nix`, `nixos/hardware/haos.nix`, `nixos/hardware/moltbot.nix`, `nixos/hardware/ncps.nix`, `nixos/hardware/waha.nix`, `nixos/hardware/zigbee2mqtt.nix`, `nixos/hardware/tailscale-pve1.nix`, `nixos/hardware/tailscale-pve2.nix`, `nixos/hardware/tailscale-pve3.nix`
- Impact: Adding new LXC containers requires copying boilerplate and risks inconsistencies. The `nixos/proxmox/lxc.nix` template already sets most of this, but individual hardware files still repeat it.
- Fix approach: Create a `mkLxcHardware` helper in `flake.nix` or `shared/` that generates hardware configs from just `{ machine, hostname }` parameters, reducing each file to a single function call.

**Repeated `networking.networkmanager.enable = lib.mkForce false` Across All LXC Machines:**
- Issue: Every LXC machine config forces NetworkManager off with `lib.mkForce false`. This pattern is duplicated in 10 machine files.
- Files: `nixos/machines/tailscale.nix`, `nixos/machines/moltbot.nix`, `nixos/machines/zigbee2mqtt.nix`, `nixos/machines/atuin.nix`, `nixos/machines/mqtt.nix`, `nixos/machines/esphome.nix`, `nixos/machines/waha.nix`, `nixos/machines/cloudflared.nix`, `nixos/machines/ncps.nix`, `nixos/machines/haos.nix`
- Impact: If NetworkManager default changes, all 10 files need updating. Easy to forget when adding new machines.
- Fix approach: Move `networking.networkmanager.enable = lib.mkForce false` into `nixos/proxmox/common.nix` or the persistence module, so all Proxmox guests inherit it automatically.

**Repeated `DynamicUser = lib.mkForce false` Pattern for LXC Services:**
- Issue: Four LXC machine configs override `DynamicUser = false` because DynamicUser does not work with bind mounts. Each creates a static user manually with similar boilerplate.
- Files: `nixos/machines/zigbee2mqtt.nix`, `nixos/machines/atuin.nix`, `nixos/machines/mqtt.nix`, `nixos/machines/haos.nix`
- Impact: New services on LXCs will hit the same issue and need the same workaround. Pattern is undocumented as a general rule.
- Fix approach: Document DynamicUser limitation in a comment in `nixos/proxmox/common.nix`. Optionally create a `mkLxcService` helper that wraps the override pattern.

**`applySubst` Function Duplicated:**
- Issue: The `applySubst` string substitution helper is defined independently in both `shared/helpers.nix` (line 115) and `shared/shell-common.nix` (line 40) with identical logic.
- Files: `shared/helpers.nix`, `shared/shell-common.nix`
- Impact: Maintenance risk if logic needs updating. Minor but indicates missing reuse.
- Fix approach: Import `applySubst` from `helpers.nix` into `shell-common.nix` instead of redefining it.

**Disabled Distributed Build Infrastructure:**
- Issue: `shared/build.nix` defines `mkDarwinBuildMachine` and `mkLinuxBuildMachine` helpers, but both machine config lists are empty (lines 33-38). The entire distributed build machinery is unused dead code.
- Files: `shared/build.nix`
- Impact: Configuration complexity for no benefit. Readers may think distributed builds are active.
- Fix approach: Remove the dead helper functions and empty lists, or add a comment explaining when/why they were disabled and under what conditions to re-enable.

**Emacs Disabled but Still Importing Packages:**
- Issue: `programs.emacs.enable = false` (temporarily disabled per comment), but `home/common/editors/emacs.nix` still installs ~30 packages via `home.packages` and fetches Doom Emacs via `builtins.fetchGit`. These packages are installed even though Emacs is disabled.
- Files: `home/common/editors/emacs.nix`
- Impact: Wasted disk space and build time on every system rebuild. The `home.packages` block is unconditional.
- Fix approach: Wrap `home.packages` and `xdg.configFile` entries with `lib.mkIf config.programs.emacs.enable` to skip them when Emacs is disabled.

**Incomplete Tailscale pve2/pve3 Configurations:**
- Issue: `nixos/hardware/tailscale-pve2.nix` and `nixos/hardware/tailscale-pve3.nix` have all secrets and systemd configuration commented out with TODO markers. These are included in `flake.nix` via `mkDaemonLXCs` and will attempt to build but lack secret provisioning.
- Files: `nixos/hardware/tailscale-pve2.nix`, `nixos/hardware/tailscale-pve3.nix`, `private/nixos/secrets/cloudflared/secrets.nix`
- Impact: Deploying to these nodes will fail silently (no Tailscale auth state). The `mkDaemonLXCs` pattern generates configurations even when they cannot successfully deploy.
- Fix approach: Either provision the secrets and uncomment the configuration, or guard the Tailscale daemon LXCs with a conditional that skips pve2/pve3 until ready.

## Security Considerations

**`Bash(find:*)` Auto-Approved with exec Concern:**
- Risk: The Claude Code permissions file auto-approves `Bash(find:*)` with the comment "Let's hope Claude doesn't use find's exec to run dangerous commands" (line 28-29). `find -exec` can execute arbitrary commands, bypassing all other Bash permission restrictions.
- Files: `home/common/ai/claude-code-permissions.nix`
- Current mitigation: Only the comment acknowledges the risk.
- Recommendations: Remove `Bash(find:*)` from auto-approved list and let Claude use `fd` (already approved). Alternatively, add a PreToolUse hook that inspects `find` commands for `-exec` or `-delete` flags and blocks them.

**Hardcoded UID/GID in Persistence Script:**
- Risk: `nixos/proxmox/persistence.nix` (line 43) uses `chown 1000:995` for the `kamushadenes` user. If UID/GID assignments change (e.g., different NixOS version or user creation order), the home directory will have wrong ownership.
- Files: `nixos/proxmox/persistence.nix`
- Current mitigation: None.
- Recommendations: Use `id -u kamushadenes` and `id -g kamushadenes` in the script, or reference the NixOS user configuration to dynamically determine the correct UID/GID. Note: this runs early in boot, so the user may not exist yet in the current boot.

**`builtins.getEnv "HOME"` in flake.nix:**
- Risk: The private submodule fetch uses `builtins.getEnv "HOME"` (line 61), requiring `--impure` for all builds. This ties the flake to the local filesystem state.
- Files: `flake.nix`
- Current mitigation: The `rebuild` alias always passes `--impure`. Documented in `AGENTS.md`.
- Recommendations: This is a known Nix flake limitation with submodules. Document the requirement prominently if not already. Consider using `builtins.fetchGit` with a fixed path or exploring the `nix flake lock --override-input` pattern.

**Proxmox Node IPs Hardcoded in flake.nix:**
- Risk: Proxmox host IPs (`10.23.5.10`, `10.23.5.11`, `10.23.5.12`) are hardcoded in `flake.nix` (lines 69-72). These are internal network addresses, not secrets, but changing infrastructure requires editing the flake.
- Files: `flake.nix`
- Current mitigation: None. IPs only used by the deploy script for SSH access.
- Recommendations: Move to a separate data file or to the private submodule for easier infrastructure changes.

**HAOS Trusted Proxies Use Wide CIDR Ranges:**
- Risk: Home Assistant's `trusted_proxies` includes `172.16.0.0/12` (all Docker networks) and `10.0.0.0/8` (entire private range), meaning any host on those networks can set X-Forwarded-For headers.
- Files: `nixos/machines/haos.nix` (lines 186-190)
- Current mitigation: Home Assistant is only accessible on the internal network.
- Recommendations: Narrow trusted_proxies to specific Cloudflare tunnel IPs or the exact proxy host IP.

## Fragile Areas

**Claude Code Activation Script:**
- Files: `home/common/ai/claude-code.nix` (lines 564-653)
- Why fragile: The activation script performs JSON manipulation of `~/.claude.json` using `jq -s` and `gnused` substitution of secrets. It handles multiple account directories, each with their own template. Race conditions are possible if Claude Code is running during `rebuild`. The `rm -f` / `mv` dance for read-only files adds complexity.
- Safe modification: Test changes on a non-primary machine first. Ensure `.claude.json.tmp` cleanup happens on failure.
- Test coverage: No automated tests. Manual verification by running `rebuild` and checking `~/.claude.json` contents.

**Private Submodule Dependency:**
- Files: `flake.nix` (line 60-64), every module using `private` parameter
- Why fragile: The entire configuration depends on `builtins.fetchGit` with `submodules = true` from the local filesystem. If the private submodule is not checked out, out of date, or has uncommitted changes, builds fail with opaque errors. New files in private must be committed in the submodule first, then the submodule reference updated in the main repo.
- Safe modification: Always commit in private first, then in the main repo. Use `git submodule status` to verify.
- Test coverage: No CI. Only caught during local rebuild.

**Home Assistant Config Deployment:**
- Files: `nixos/machines/haos.nix` (lines 278-290)
- Why fragile: YAML config files are copied via `system.activationScripts.haosConfig` using `install` commands. If file names change in the private submodule, the activation script silently fails (install to nonexistent source). The `configWritable = true` setting means UI edits can diverge from the Nix-managed config on next rebuild.
- Safe modification: Verify all source YAML files exist in `private/nixos/haos-config/` before deploying.
- Test coverage: None. Only caught by Home Assistant failing to start.

**Proxmox Persistence Module Boot Ordering:**
- Files: `nixos/proxmox/persistence.nix`
- Why fragile: The `create-persist-dirs` systemd service must run before `local-fs-pre.target` to create directories that will be bind-mounted. If boot ordering changes (NixOS update), the bind mounts may fail, leaving the system with an empty tmpfs root and no persistent state.
- Safe modification: Test NixOS version upgrades on a non-critical LXC first.
- Test coverage: None.

## Scaling Limits

**Number of LXC Machines:**
- Current capacity: 14 LXC containers across 3 Proxmox nodes, plus 3 daemon LXCs per node pattern.
- Limit: Each new LXC requires 2-3 new files (hardware config, machine config, optional secrets). With 16+ hardware files already, the directory is getting crowded.
- Scaling path: The `mkDaemonLXCs` helper addresses daemon scaling well. For non-daemon LXCs, consider a data-driven approach where machine parameters are defined in a single file and configs are generated.

**Claude Code Configuration Complexity:**
- Current capacity: 654 lines in `claude-code.nix`, 334 lines in `claude-code-permissions.nix`, 331 lines in `mcp-servers.nix`.
- Limit: Adding new MCP servers, hooks, or permissions requires touching multiple files and understanding the activation script flow.
- Scaling path: Already well-factored into separate files. The permissions file could benefit from grouping by feature with comments, which is partially done.

## Dependencies at Risk

**Forked agenix (ragenix):**
- Risk: Uses `github:kamushadenes/ragenix` instead of the upstream `github:ryantm/agenix`. Personal fork may fall behind upstream.
- Impact: Missing security fixes or new features from upstream agenix.
- Migration plan: Periodically rebase fork on upstream, or switch to upstream when the fork's changes are merged.

**Forked claudebox:**
- Risk: Uses `github:kamushadenes/claudebox` (fork with macOS write permission fix). PR submitted upstream but not yet merged.
- Impact: If upstream changes significantly, fork may diverge.
- Migration plan: Switch to `github:numtide/claudebox` once PR #1 is merged.

**Pinned nixpkgs to 25.11-darwin Branch:**
- Risk: Using `nixpkgs-25.11-darwin` which is a pre-release branch. Darwin-specific branches can have packaging issues.
- Impact: Packages may be missing or broken compared to stable release.
- Migration plan: None needed -- this is the standard darwin branch naming convention. Monitor for the official 25.11 release.

**Doom Emacs Pinned to Specific Git Rev:**
- Risk: `home/common/editors/emacs.nix` (line 94-97) pins Doom Emacs to commit `7bc39f2c1402794e76ea10b781dfe586fed7253b` via `builtins.fetchGit`. This will never update unless manually bumped.
- Impact: Stale Doom Emacs installation if re-enabled. Currently Emacs is disabled so impact is minimal.
- Migration plan: Update the rev when re-enabling Emacs, or use a flake input for proper version tracking.

## Missing Critical Features

**No CI/CD Pipeline:**
- Problem: There is no CI/CD pipeline to validate the flake. `nix flake check` is only run manually.
- Blocks: Catching configuration errors before deployment. Breaking changes in nixpkgs can go unnoticed until `rebuild` fails.

**No Automated Testing of LXC Configurations:**
- Problem: LXC configurations can only be tested by deploying to actual Proxmox nodes. There are no NixOS VM tests for the machine configurations.
- Blocks: Confident refactoring of shared modules. Catch-all changes (like moving `networkmanager.enable = false` to a shared location) cannot be validated without deploying to all machines.

## Test Coverage Gaps

**No Tests for Nix Configuration:**
- What's not tested: The entire Nix configuration has no automated tests. No `nix flake check`, no NixOS VM tests, no home-manager activation tests.
- Files: All `.nix` files.
- Risk: Configuration errors are only caught at `rebuild` time on the target machine. Breaking changes in nixpkgs, module renames, or option deprecations are discovered late.
- Priority: Medium. The configuration is relatively stable and changes are tested manually.

**Activation Scripts Not Tested:**
- What's not tested: The Claude Code MCP server activation script (`home/common/ai/claude-code.nix` lines 564-653) performs complex JSON manipulation and secret substitution with no tests.
- Files: `home/common/ai/claude-code.nix`
- Risk: Malformed JSON, missing secrets, or incorrect substitution patterns could break Claude Code's MCP server connections silently.
- Priority: Medium. Failures are visible when MCP servers fail to connect.

## Commented-Out Code

**Claude Code Plugins (Tentative):**
- Files: `home/common/ai/claude-code.nix` (lines 420-440)
- 15+ commented-out plugin entries representing plugins that were tried but not enabled. These are intentional "available but disabled" markers, not dead code.
- Recommendation: Acceptable as-is. These serve as a reference for available plugins.

**Tailscale pve2/pve3 Secrets:**
- Files: `nixos/hardware/tailscale-pve2.nix`, `nixos/hardware/tailscale-pve3.nix`
- Entire secret and systemd blocks are commented out with detailed TODO instructions.
- Recommendation: Either provision and uncomment, or move the commented config into a separate template file to keep hardware configs clean.

**Private Cloudflared Secrets:**
- Files: `private/nixos/secrets/cloudflared/secrets.nix` (lines 5-6)
- Two secrets for pve2/pve3 cloudflared keys are commented out with TODO markers.
- Recommendation: Same as tailscale -- provision or remove.

---

*Concerns audit: 2026-02-21*
