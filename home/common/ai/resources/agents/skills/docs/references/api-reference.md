# API Reference Documentation

Templates and patterns for documenting APIs. Adapt to the project's actual API
style — these are starting points.

## REST API Documentation

Structure each endpoint consistently:

```markdown
## Endpoints

### Create Resource

`POST /api/v1/resources`

Create a new resource with the given parameters.

**Authentication**: Bearer token required

**Request Body**:

| Field      | Type   | Required | Description                |
| ---------- | ------ | -------- | -------------------------- |
| `name`     | string | yes      | Display name (1-255 chars) |
| `type`     | string | yes      | One of: `basic`, `premium` |
| `metadata` | object | no       | Arbitrary key-value pairs  |

**Example Request**:

\`\`\`bash curl -X POST https://api.example.com/v1/resources \
 -H "Authorization: Bearer $TOKEN" \
 -H "Content-Type: application/json" \
 -d '{"name": "my-resource", "type": "basic"}' \`\`\`

**Response** (`201 Created`):

\`\`\`json { "id": "res_abc123", "name": "my-resource", "type": "basic",
"created_at": "2025-01-15T10:30:00Z" } \`\`\`

**Error Responses**:

| Status | Code               | Description                    |
| ------ | ------------------ | ------------------------------ |
| 400    | `invalid_request`  | Missing or invalid fields      |
| 401    | `unauthorized`     | Invalid or expired token       |
| 409    | `conflict`         | Resource with this name exists |
| 422    | `validation_error` | Field validation failed        |
```

### Per-Endpoint Checklist

For each endpoint, document:

- HTTP method and path
- Brief description of what it does
- Authentication requirements
- Request parameters (path, query, body) with types and constraints
- Example request (curl or language-specific)
- Success response with example body
- Error responses with status codes and descriptions
- Rate limiting (if applicable)
- Pagination format (if list endpoint)

## Library / SDK Documentation

For libraries with public APIs:

```markdown
## `createClient(options)`

Initialize a new client instance.

**Parameters**:

| Name              | Type     | Default | Description             |
| ----------------- | -------- | ------- | ----------------------- |
| `options.baseUrl` | `string` | —       | API base URL (required) |
| `options.timeout` | `number` | `30000` | Request timeout in ms   |
| `options.retries` | `number` | `3`     | Max retry attempts      |

**Returns**: `Client`

**Throws**: `ConfigError` if `baseUrl` is missing

**Example**:

\`\`\`typescript const client = createClient({ baseUrl:
'https://api.example.com', timeout: 5000, }); \`\`\`
```

### Per-Function Checklist

- Function signature with parameter types
- Parameter table with types, defaults, constraints
- Return type and shape
- Exceptions/errors thrown
- Concrete example showing typical usage
- Edge cases or gotchas (if any)

## GraphQL Documentation

For GraphQL APIs, document by domain rather than by query:

```markdown
## Users

### Queries

#### `user(id: ID!): User`

Fetch a single user by ID.

\`\`\`graphql query GetUser($id: ID!) { user(id: $id) { id name email role } }
\`\`\`

### Mutations

#### `createUser(input: CreateUserInput!): User!`

\`\`\`graphql mutation CreateUser($input: CreateUserInput!) { createUser(input:
$input) { id name } } \`\`\`

### Types

#### `User`

| Field   | Type      | Description                  |
| ------- | --------- | ---------------------------- |
| `id`    | `ID!`     | Unique identifier            |
| `name`  | `String!` | Display name                 |
| `email` | `String!` | Email address                |
| `role`  | `Role!`   | `ADMIN`, `USER`, or `VIEWER` |
```

## API Documentation Structure

Organize the full document:

1. **Overview** — What the API does, base URL, versioning scheme
2. **Authentication** — How to obtain and use credentials
3. **Common Patterns** — Pagination, filtering, sorting, error format
4. **Rate Limiting** — Limits, headers, backoff strategy
5. **Endpoints by Domain** — Grouped logically (Users, Resources, etc.)
6. **Webhooks** — Event types, payload format, verification (if applicable)
7. **SDKs and Tools** — Official clients, Postman collections, OpenAPI spec link

## Content Discovery

- **Route files**: Check `src/routes/`, `src/api/`, `app/api/`, `pages/api/`,
  `routes/`, `handlers/`, `controllers/` directories
- **Endpoint definitions**: Grep for `router.get`, `router.post`, `app.get`,
  `app.post`, `@Get`, `@Post`, `@app.route`, `http.HandleFunc`, `#[get`
- **OpenAPI/Swagger specs**: Check for `openapi.yaml`, `openapi.json`,
  `swagger.json`, `swagger.yaml`, `docs/openapi.*`
- **Auth middleware**: Grep for `passport`, `jsonwebtoken`, `Authorization`,
  `Bearer`, `apiKey`, `x-api-key`, `@auth`, `authenticate` in middleware files
- **Request/response types**: Grep for `interface.*Request`, `interface.*Response`,
  `type.*Payload`, Zod/Joi/Yup schema definitions near route files
- **Error handling**: Grep for error handler middleware patterns, `errors.ts`,
  `error-codes.*`, custom error classes
- **Rate limiting**: Check dependencies for `express-rate-limit`,
  `rate-limiter-flexible`, `@upstash/ratelimit`, `throttle`

## Tips

- Extract endpoint definitions from route files, not from memory
- Check for OpenAPI/Swagger specs — generate from those if available
- Include authentication setup as the very first section
- Use real response shapes from the codebase's types/models
- Document error response format once, then reference it per endpoint
