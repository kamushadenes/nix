# README Structure Reference

Detailed templates for each README section. Adapt to the actual project — these
are starting points, not rigid templates.

## 1. Title and Overview

```markdown
# Project Name

Brief description of what the project does and who it's for. 2-3 sentences max.

## Key Features

- Feature 1
- Feature 2
- Feature 3
```

## 2. Tech Stack

```markdown
## Tech Stack

- **Language**: Go 1.22+ / TypeScript 5.x / Python 3.12+ / etc.
- **Framework**: [detected framework]
- **Database**: PostgreSQL / SQLite / etc.
- **Deployment**: [detected platform]
```

## 3. Prerequisites

List everything that must be installed. Be specific about versions.

```markdown
## Prerequisites

- Go 1.22 or higher
- PostgreSQL 15 or higher (or Docker)
- Make (for build commands)
```

## 4. Getting Started

The complete local development guide. Every step must be copy-pasteable.

```markdown
## Getting Started

### 1. Clone the Repository

### 2. Install Dependencies

### 3. Environment Setup

Copy the example environment file:

\`\`\`bash cp .env.example .env \`\`\`

Configure the following variables:

| Variable       | Description                | Example                            |
| -------------- | -------------------------- | ---------------------------------- |
| `DATABASE_URL` | Database connection string | `postgresql://localhost/myapp_dev` |

### 4. Database Setup

### 5. Start Development Server
```

## 5. Architecture

Go deep here. Include:

- **Directory structure** with descriptions for each top-level directory
- **Request lifecycle** or data flow diagram (ASCII art)
- **Key components** with brief explanations
- **Database schema** for the most important tables/models

```markdown
## Architecture

### Directory Structure

\`\`\` ├── cmd/ # Application entry points ├── internal/ # Private application
code │ ├── handler/ # HTTP handlers │ ├── service/ # Business logic │ └──
repository/ # Data access layer ├── pkg/ # Public library code ├── migrations/ #
Database migrations └── config/ # Configuration files \`\`\`

### Data Flow

\`\`\` Request → Router → Middleware → Handler → Service → Repository → Database
↓ Response ← Handler ← Service ← \`\`\`
```

## 6. Environment Variables

Two tables: required and optional.

```markdown
## Environment Variables

### Required

| Variable       | Description                | How to Get             |
| -------------- | -------------------------- | ---------------------- |
| `DATABASE_URL` | Database connection string | Your database provider |

### Optional

| Variable    | Description       | Default |
| ----------- | ----------------- | ------- |
| `LOG_LEVEL` | Logging verbosity | `info`  |
```

## 7. Available Scripts

```markdown
## Available Scripts

| Command      | Description              |
| ------------ | ------------------------ |
| `make dev`   | Start development server |
| `make test`  | Run test suite           |
| `make build` | Build for production     |
| `make lint`  | Run linters              |
```

## 8. Testing

Include how to run, test structure, and a minimal example.

```markdown
## Testing

\`\`\`bash

# Run all tests

make test

# Run with coverage

make test-coverage

# Run specific test

go test ./internal/handler/... -run TestCreateUser \`\`\`

### Test Structure

\`\`\` tests/ ├── unit/ # Unit tests ├── integration/ # Integration tests └──
e2e/ # End-to-end tests \`\`\`
```

## 9. Deployment

Detect the platform from config files and tailor instructions:

- `Dockerfile` / `docker-compose.yml` → Docker instructions
- `fly.toml` → Fly.io instructions
- `*.tf` / `terraform/` → Terraform/IaC instructions
- `flake.nix` → NixOS deployment instructions
- `Procfile` → Heroku-like instructions
- `k8s/` → Kubernetes instructions
- No config → General guidance with Docker as recommended approach

## 10. Troubleshooting

Cover the most common issues:

```markdown
## Troubleshooting

### Database Connection Issues

**Error:** `could not connect to server: Connection refused`

**Solution:**

1. Verify database is running
2. Check connection string format
3. Ensure database exists
```

## Nix/Flake Projects

For Nix-based projects, include:

- `nix develop` or `nix-shell` for development environment
- `nix build` for building
- `nix flake check` for validation
- Flake inputs and their purposes
- How to add new packages or modules
- Machine-specific configuration (if multi-machine flake)
