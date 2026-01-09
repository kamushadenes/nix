# Commit Message Template

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting (no code change)
- `refactor`: Code restructure (no behavior change)
- `perf`: Performance improvement
- `test`: Adding/fixing tests
- `chore`: Maintenance tasks

## Rules

- Subject: imperative, lowercase, no period, <50 chars
- Body: explain what and why (not how), wrap at 72 chars
- Footer: references (Fixes #123, Closes #456)

## Examples

```
feat(auth): add OAuth2 support for GitHub

Enables users to authenticate via GitHub OAuth2 flow.
Tokens stored securely using agenix.

Fixes #42
```

```
fix(api): handle nil pointer in user lookup

Check for nil before dereferencing user struct.
```
