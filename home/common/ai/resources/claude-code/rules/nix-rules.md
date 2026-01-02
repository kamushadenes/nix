---
paths: **/*.nix
---

# Nix Development Rules

## Flakes

- New files must be committed before nix can see them (flakes only track git-tracked files)
- Run `nix flake check` before rebuilding
- Use `nix fmt` to format nix files

## Home Manager

- Test changes with `rebuild` alias
- Check for option conflicts with existing modules
- Prefer editing existing files over creating new ones
