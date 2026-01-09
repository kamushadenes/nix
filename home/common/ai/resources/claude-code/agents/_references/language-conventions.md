# Language Conventions Reference

Per-language patterns for type checking, testing, and documentation.

## Type Safety by Language

### TypeScript

```typescript
// GOOD: Strict mode, explicit types
function processUser(user: User): ProcessedUser {
  return { ...user, processed: true };
}

// BAD: any, implicit any, type assertions
const data: any = fetchData();
const user = data as User;  // Unsafe cast
```

**Rules:**
- Enable `strict: true` in tsconfig
- Avoid `any` - use `unknown` with type guards
- Use discriminated unions over type assertions
- Prefer `readonly` for immutable data

### Python

```python
# GOOD: Type hints, strict mypy
def process_user(user: User) -> ProcessedUser:
    return ProcessedUser(name=user.name, processed=True)

# BAD: No hints, dynamic typing
def process(data):  # What is data?
    return data.do_thing()  # AttributeError waiting to happen
```

**Rules:**
- Use type hints on public APIs
- Enable mypy strict mode
- Use `TypeVar` and `Generic` for reusable types
- Prefer `Optional[T]` over `None` unions

### Go

```go
// GOOD: Explicit error handling
func ProcessUser(user *User) (*ProcessedUser, error) {
    if user == nil {
        return nil, errors.New("user cannot be nil")
    }
    return &ProcessedUser{Name: user.Name}, nil
}

// BAD: Ignored errors
result, _ := riskyOperation()  // Error ignored!
```

**Rules:**
- Always handle errors explicitly
- Use pointer receivers for mutations
- Prefer interfaces for flexibility
- Use context for cancellation

### Rust

```rust
// GOOD: Result types, explicit handling
fn process_user(user: &User) -> Result<ProcessedUser, ProcessError> {
    Ok(ProcessedUser { name: user.name.clone() })
}

// BAD: Unwrap in library code
let result = risky_operation().unwrap();  // Panics on error!
```

**Rules:**
- Return `Result` instead of panicking
- Use `?` for error propagation
- Prefer `&str` over `String` for parameters
- Implement `From` for error conversion

---

## Testing Patterns

### Unit Test Structure

```python
def test_should_describe_behavior():
    # Arrange
    user = create_test_user()

    # Act
    result = process_user(user)

    # Assert
    assert result.processed is True
```

### Test Frameworks

| Language | Framework | Command |
|----------|-----------|---------|
| Python | pytest | `pytest tests/` |
| TypeScript | Jest | `npm test` |
| Go | testing | `go test ./...` |
| Rust | cargo test | `cargo test` |

### Coverage Expectations

| Type | Target |
|------|--------|
| New code | 80%+ |
| Critical paths | 95%+ |
| Bug fixes | Regression test required |

---

## Documentation Styles

### Python (Google Style)

```python
def process(data: dict, options: Options) -> Result:
    """Process input data with given options.

    Args:
        data: Input dictionary to process.
        options: Processing options.

    Returns:
        Result object containing processed data.

    Raises:
        ValueError: If data is malformed.
    """
```

### TypeScript (TSDoc)

```typescript
/**
 * Process input data with given options.
 * @param data - Input object to process
 * @param options - Processing options
 * @returns Result object containing processed data
 * @throws {ValidationError} If data is malformed
 */
function process(data: InputData, options: Options): Result {
```

### Go (GoDoc)

```go
// ProcessUser transforms a User into a ProcessedUser.
// It returns an error if the user is nil or invalid.
func ProcessUser(user *User) (*ProcessedUser, error) {
```

---

## Error Handling Patterns

### Python

```python
# Custom exceptions for domain errors
class ValidationError(Exception):
    pass

# Specific catches, not bare except
try:
    process(data)
except ValidationError as e:
    logger.warning(f"Validation failed: {e}")
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    raise
```

### TypeScript

```typescript
// Result types for recoverable errors
type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

// Never swallow errors
try {
  await process(data);
} catch (e) {
  if (e instanceof ValidationError) {
    return { ok: false, error: e };
  }
  throw e;  // Re-throw unexpected
}
```

### Go

```go
// Wrap errors with context
if err != nil {
    return fmt.Errorf("processing user %s: %w", user.ID, err)
}

// Check specific error types
if errors.Is(err, ErrNotFound) {
    return nil, nil  // Expected case
}
```
