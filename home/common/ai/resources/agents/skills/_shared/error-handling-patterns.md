# Error Handling Patterns

Shared patterns for error handling across language skills.

## Principles

1. **Fail fast** - Detect errors early, report immediately
2. **Explicit errors** - Prefer explicit error types over generic exceptions
3. **Context preservation** - Include relevant context in error messages
4. **Recoverable vs fatal** - Distinguish between recoverable and fatal errors

## Pattern: Structured Error Types

```
# Define specific error types for different failure modes
ErrorType:
  - ValidationError: Input validation failed
  - NotFoundError: Resource not found
  - PermissionError: Access denied
  - TimeoutError: Operation timed out
  - NetworkError: Network/connection issues
```

## Pattern: Error Context

Include in error messages:
- What operation was attempted
- What input caused the failure
- What went wrong specifically
- How to fix it (if known)

## Pattern: Error Boundaries

Place error handling at boundaries:
- API endpoints
- External service calls
- User input processing
- File I/O operations

## Pattern: Graceful Degradation

When possible, provide fallback behavior:
1. Try primary operation
2. Log the failure with context
3. Attempt fallback if available
4. Report partial success or failure

## Language-Specific Notes

Reference language skill's SKILL.md for idiomatic error handling:
- Go: Explicit error returns, wrap with `fmt.Errorf`
- Python: Exception hierarchy, context managers
- TypeScript: Result types, try-catch with typed errors
- Rust: Result/Option types, ? operator
