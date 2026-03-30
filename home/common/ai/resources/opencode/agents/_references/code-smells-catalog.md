# Code Smells Catalog

Reference catalog of anti-patterns for analysis agents.

## Size Violations

### Thresholds

| Component | Evaluate | Critical (Must Decompose) |
|-----------|----------|---------------------------|
| Files | >5,000 LOC | >15,000 LOC |
| Classes | >1,000 LOC | >3,000 LOC |
| Functions | >150 LOC | >500 LOC |
| Parameters | >4 params | >8 params |
| Nesting | >3 levels | >5 levels |

## Structural Smells

### Long Methods/Functions

```python
# BAD: 50+ lines of mixed logic
def process_order(order):
    # 50 lines of validation
    # 30 lines of calculation
    # 40 lines of persistence

# GOOD: Extract logical chunks
def process_order(order):
    validate_order(order)
    totals = calculate_totals(order)
    save_order(order, totals)
```

### Deep Nesting

```python
# BAD: >3 levels
if user:
    if user.active:
        if user.permissions:
            if "admin" in user.permissions:
                do_thing()

# GOOD: Early returns
if not user or not user.active:
    return
if not user.permissions or "admin" not in user.permissions:
    return
do_thing()
```

### Feature Envy

Method uses another class's data more than its own - move the method.

## Performance Anti-Patterns

### N+1 Queries

```python
# BAD: 1 query per user
for user in users:
    orders = db.query(f"SELECT * FROM orders WHERE user_id = {user.id}")

# GOOD: Batch query
orders = db.query("SELECT * FROM orders WHERE user_id IN (...)")
orders_by_user = group_by(orders, 'user_id')
```

### Memory Issues

```python
# BAD: Load all into memory
all_records = list(db.query("SELECT * FROM huge_table"))

# GOOD: Stream/paginate
for chunk in db.query_chunked(sql, chunk_size=1000):
    process(chunk)

# BAD: String concat in loop (O(n^2))
result = ""
for item in items:
    result += str(item)

# GOOD: Use join
result = "".join(str(item) for item in items)
```

### Blocking Operations

```python
# BAD: Sync I/O in async context
async def handler():
    data = requests.get(url)  # Blocks event loop!

# GOOD: Use async client
async def handler():
    async with httpx.AsyncClient() as client:
        data = await client.get(url)
```

### Resource Leaks

```python
# BAD: Connection not closed
conn = db.connect()
result = conn.query(sql)
return result  # Leaked!

# GOOD: Use context manager
with db.connect() as conn:
    return conn.query(sql)
```

## Duplication

### Copy-Paste Code

Similar logic in multiple places - extract to shared function.

### Repeated Conditionals

Same if/switch in multiple methods - use polymorphism or strategy pattern.

## Coupling Issues

### Message Chains

```python
# BAD
value = a.getB().getC().getD().getValue()

# GOOD: Law of Demeter
value = a.get_value()  # A delegates internally
```

### Inappropriate Intimacy

Classes knowing too much about each other's internals.

## Abstraction Problems

### Primitive Obsession

Using strings/ints for domain concepts - create value objects.

### Data Clumps

Same groups of data passed together - create a class.

## Security Anti-Patterns

### Injection Vulnerabilities

```python
# BAD: SQL injection
query = f"SELECT * FROM users WHERE id = {user_id}"

# GOOD: Parameterized
cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
```

### Broad Exception Catch

```python
# BAD: Hides specific errors
try:
    risky_operation()
except Exception:
    pass  # Swallowed!

# GOOD: Catch specific, log others
try:
    risky_operation()
except ValueError as e:
    handle_validation(e)
except Exception as e:
    logger.error(f"Unexpected: {e}")
    raise
```

## Legitimate Exemptions

Do NOT flag these as issues:
- **Performance-critical**: Avoiding method call overhead
- **Algorithmic cohesion**: State machines, parsers, unified domain logic
- **Legacy/generated**: Well-tested, stable code
- **Framework constraints**: ORM entities, configuration objects
- **Complex state**: Requires unified handling
