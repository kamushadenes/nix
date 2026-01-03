# Task-Based Workflow Rules

## When to Use Task Management

The task management system is for **large, complex tasks only**. Use good judgment:

### Use Task System When:

- Multi-day or multi-phase work
- Architectural changes affecting multiple components
- Features requiring design discussion before implementation
- Work that benefits from multi-model review (security-critical, complex algorithms)
- Tasks that need formal tracking for handoff or audit

### Skip Task System When:

- Simple bug fixes or typos
- Single-file changes with clear scope
- Quick refactoring or code cleanup
- Adding straightforward features with obvious implementation
- Any task you can complete in a single session without confusion

**Default behavior**: Claude Code makes its own decisions for simple tasks. Only escalate to task management when complexity warrants the overhead.

## Creating Tasks

Use `/task-add` or `task_create` MCP tool to create tasks with:

- Clear title describing the work
- Detailed description with context
- Acceptance criteria (conditions for "done")
- Relevant context files
- Priority (1=critical to 5=low)

## Task Workflow with clink

Use `clink` to query external AI models during task workflows:

```python
# Get external perspective on a task
result = clink(
    prompt=f"Review task requirements and suggest approach: {task_description}",
    cli="codex"
)
```

### Workflow Example

```python
# 1. Create task
result = task_create(
    title="Add user authentication",
    description="Implement OAuth2 login flow",
    acceptance_criteria='["Login page works", "Token refresh handles expiry", "Tests pass"]',
    priority=2
)
task_id = json.loads(result)["task_id"]

# 2. Start discussion (for complex tasks)
task_start_discussion(task_id)
# Use task-discusser sub-agent to call clink for each AI model

# 3. Development
task_update(task_id, status="in_progress")
# Implement the feature

# 4. Review
task_submit_review(task_id)
# Use code-reviewer sub-agent

# 5. QA
task_start_qa(task_id)
# Use QA sub-agents with clink for multi-model verification
```

## Task Lifecycle

```text
backlog -> todo -> discussing -> in_progress -> review -> qa -> done
                       |              |           |       |
                    stalled        blocked     failed   rejected
```

| Status        | Description                     | Who Works                           |
| ------------- | ------------------------------- | ----------------------------------- |
| `backlog`     | Not yet prioritized             | None                                |
| `todo`        | Ready to work on                | None                                |
| `discussing`  | Design/consensus phase          | Sub-agents using clink              |
| `in_progress` | Being implemented               | Claude (full access)                |
| `review`      | Code review                     | code-reviewer sub-agent             |
| `qa`          | Verification                    | QA sub-agents using clink           |
| `done`        | Completed                       | None                                |
| `blocked`     | Waiting on dependency           | None                                |
| `stalled`     | Discussion failed (needs human) | None                                |
| `failed`      | Could not complete              | None                                |
| `rejected`    | QA failed                       | None                                |

## Discussion Phase (Optional - For Very Complex Tasks Only)

The discussion phase with multi-model consensus is **expensive and slow**. Only use it when:

- Major architectural decisions with significant tradeoffs
- Security-critical implementations needing multiple perspectives
- Novel algorithms or approaches where validation is valuable
- When you're genuinely uncertain and need external input

**Most tasks should skip discussion** and go directly from `todo` to `in_progress`.

### When Using Discussion Phase:

1. Call `task_start_discussion(task_id)`
2. Use `task-discusser` sub-agent to query Claude, Codex, and Gemini via clink
3. Task-discusser parses responses and casts votes on behalf of each agent
4. **All 3 must agree "ready"** to proceed (unanimous consensus)
5. If disagreement exists, another round begins
6. After 3 failed rounds, task moves to `stalled` for human input

## Agent Responsibilities

When assigned to a task, agents MUST:

- Read and understand all acceptance criteria
- Add comments with progress/findings: `task_comment(task_id, content)`
- For discussion: vote via `task_discussion_vote(task_id, vote, approach_summary)`
- For dev: implement and call `task_submit_review(task_id)` when done
- For review: call `task_review_complete(task_id, approved, feedback)`
- For QA: vote via `task_qa_vote(task_id, vote, reason)`

## Commit Requirements

**Always commit when a task reaches a completion point:**

- After `in_progress` work is done (before submitting for review)
- After addressing review feedback
- After QA approval (before marking as done)

Commit message should reference the task:

```text
feat: implement user authentication

Task: task_abc123
Acceptance criteria met:
- Login page works
- Token refresh handles expiry
- Tests pass
```

**Do not leave uncommitted changes** when transitioning between task phases.

## Viewing Tasks

```python
# List by status
task_list(status="discussing")

# Get full details
task_get(task_id)

# Check subtasks
task_list(parent_task_id=task_id)

# View comments
task_comments(task_id)
```

## Quick Reference: MCP Tools

| Tool                    | Purpose                      |
| ----------------------- | ---------------------------- |
| `task_create`           | Create new task              |
| `task_list`             | List/filter tasks            |
| `task_get`              | Get task details             |
| `task_update`           | Update task fields           |
| `task_complete`         | Mark done with summary       |
| `task_cancel`           | Cancel task                  |
| `task_comment`          | Add comment                  |
| `task_comments`         | Get comments                 |
| `task_start_discussion` | Begin discussion phase       |
| `task_discussion_vote`  | Vote on discussion           |
| `task_start_dev`        | Begin development            |
| `task_submit_review`    | Submit for review            |
| `task_review_complete`  | Complete review              |
| `task_start_qa`         | Begin QA phase               |
| `task_qa_vote`          | Vote on QA                   |
| `task_reopen`           | Reopen rejected/stalled task |
| `clink`                 | Query external AI CLI        |
