# Severity Levels

Standard severity classification for all analysis agents.

## Levels

- 🔴 **Critical**: Blocks merge - security vulnerabilities, data loss, production crashes, RCE
- 🟠 **High**: Should fix - bugs, performance bottlenecks, significant logic errors
- 🟡 **Medium**: Recommended - maintainability, code clarity, potential issues, scalability concerns
- 🟢 **Low**: Optional - style improvements, minor optimizations
- ⚪ **Informational**: Best practice deviation, no direct risk (security audits only)

## Issue Format

```
[SEVERITY] file/path.ext:line
Description of the issue.
FIX: Specific remediation recommendation.
```

### Example

```
[🔴 CRITICAL] src/auth/login.py:45
SQL injection - user input directly in query string.
FIX: Use parameterized query: `cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))`
```

## Report Structure

```markdown
## [Domain] Analysis Report

### Summary
- Files analyzed: X
- Issues found: Y (critical: A, high: B, medium: C, low: D)

### Issues

[List issues by severity, highest first]

### Top Priorities
1. [Most critical item]
2. [Second most critical]

### Positive Aspects
- [What was done well]
```
