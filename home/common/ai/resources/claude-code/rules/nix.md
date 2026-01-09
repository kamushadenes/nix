---
paths: **/*.nix
---

# Nix Rules

## Flakes

- New files must be committed before nix can see them
- Run `nix flake check` before rebuilding
- Use `nix fmt` to format

## Home Manager

- Test with `rebuild` alias
- Check for option conflicts
- Prefer editing existing files

## Secrets (Agenix)

- Never commit plaintext secrets
- Use agenix for encryption
- Secrets use @PLACEHOLDER@ substitution syntax
