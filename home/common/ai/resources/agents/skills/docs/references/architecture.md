# Architecture Documentation

Templates for system design docs and Architecture Decision Records.

## Architecture Overview Document

Structure for a comprehensive architecture doc:

```markdown
# Architecture

## System Overview

[2-3 sentence summary of the system's purpose and primary architectural style]

## High-Level Architecture

\`\`\`mermaid graph TD Client[Client App] --> Gateway[API Gateway] Gateway -->
Auth[Auth Service] Gateway --> A[Service A] --> DBA[(Database A)] Gateway -->
B[Service B] --> DBB[(Database B)] B --> MQ[Message Queue] --> Worker \`\`\`

## Components

### [Component Name]

- **Purpose**: What it does and why it exists
- **Technology**: Language, framework, key libraries
- **Owns**: What data/domain this component is responsible for
- **Depends on**: Other components it calls
- **API surface**: How other components interact with it

## Data Flow

### [Primary Flow Name] (e.g., "User Registration")

1. Client sends POST to /api/register
2. API Gateway validates auth headers
3. User Service validates input, checks uniqueness
4. User Service writes to PostgreSQL
5. Event published to message queue
6. Email Worker sends verification email
7. Response returned to client

## Data Model

### Core Entities

| Entity  | Storage    | Owned By     | Description              |
| ------- | ---------- | ------------ | ------------------------ |
| User    | PostgreSQL | User Service | Account and profile data |
| Session | Redis      | Auth Service | Active sessions with TTL |

### Key Relationships

[Describe entity relationships, foreign keys, references]

## Cross-Cutting Concerns

### Authentication & Authorization

[How auth works across services]

### Observability

[Logging, metrics, tracing approach]

### Error Handling

[Error propagation strategy, retry policies]
```

### Component Doc Checklist

For each major component, document:

- Purpose and responsibility boundaries
- Technology choices with rationale
- Public API / interface contract
- Data ownership
- Dependencies (upstream and downstream)
- Scaling characteristics
- Failure modes and recovery

## Architecture Decision Records (ADRs)

Use the following format for recording architectural decisions:

```markdown
# ADR-NNN: [Decision Title]

**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXX **Date**:
YYYY-MM-DD **Deciders**: [who was involved]

## Context

[What is the issue? What forces are at play? Include technical and business
context. Be specific — reference actual components, metrics, or constraints.]

## Decision

[What was decided. State clearly and concisely.]

## Consequences

### Positive

- [Benefit 1]
- [Benefit 2]

### Negative

- [Trade-off 1]
- [Trade-off 2]

### Neutral

- [Side effect that is neither good nor bad]

## Alternatives Considered

### [Alternative 1]

- **Pros**: [...]
- **Cons**: [...]
- **Why rejected**: [specific reason]

### [Alternative 2]

- **Pros**: [...]
- **Cons**: [...]
- **Why rejected**: [specific reason]
```

### ADR Conventions

- Number sequentially: ADR-001, ADR-002, etc.
- Store in `docs/adr/` directory
- Include an `index.md` listing all ADRs with status and one-line summary
- Never delete ADRs — mark as Deprecated or Superseded
- Keep context section focused on what was true at decision time
- Link to related ADRs when decisions build on each other

### ADR Index Template

```markdown
# Architecture Decision Records

| ADR                             | Title                              | Status            | Date       |
| ------------------------------- | ---------------------------------- | ----------------- | ---------- |
| [001](001-use-postgresql.md)    | Use PostgreSQL for primary storage | Accepted          | 2025-01-15 |
| [002](002-event-driven-arch.md) | Adopt event-driven architecture    | Accepted          | 2025-02-01 |
| [003](003-rest-over-grpc.md)    | Use REST instead of gRPC           | Superseded by 007 | 2025-02-10 |
```

## Content Discovery

- **Components**: List top-level directories under `src/`, `lib/`, `internal/`,
  `pkg/`, `app/` — each typically represents a component or module boundary
- **Entry points**: Grep for `main`, `app.listen`, `createServer`,
  `func main()`, `fn main()`, `if __name__` to find where the system starts
- **Data flow**: Follow the call chain from entry point through 2-3 levels;
  grep for middleware registration, router setup, event emitters, queue consumers
- **Key abstractions**: Grep for `export class`, `export interface`,
  `export type`, `trait `, `interface `, `abstract class` in source directories
- **Dependencies between components**: Read import statements in each
  component's entry file to map which components call which
- **Framework signals**: Check for `next.config.*`, `vite.config.*`,
  `webpack.config.*`, `angular.json`, `Cargo.toml` workspace members,
  `go.work` files
- **Database**: Check for `migrations/`, `prisma/schema.prisma`,
  `drizzle.config.*`, `alembic/`, `sqlalchemy`, `ent/schema/`

## Tips

- Extract architecture from actual code structure, don't invent it
- Use mermaid diagrams (`\`\`\`mermaid` blocks) for all visual representations
- Keep component descriptions focused on boundaries and contracts
- ADRs should capture the decision context at the time, not be updated
  retroactively
- Link architecture docs to relevant source directories
