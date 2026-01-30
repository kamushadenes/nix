---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Bash(gh pr:*), Bash(test:*), Task, AskUserQuestion, MCPSearch, mcp__task-master-ai__*, Skill
description: Comprehensive multi-agent code review using 9 specialized agents with 3-model consensus
---

Run a comprehensive deep review using all specialized review agents in parallel. Each agent uses 3 AI models (claude, codex, gemini) for thorough analysis. Optionally create task-master tasks for findings at the end.

## Steps

1. **Ask the user what to review** using AskUserQuestion:

```
Question: "What scope would you like to review?"
Options:
- "Uncommitted changes" - Review only uncommitted changes (git diff)
- "Branch changes" - Review all changes on this branch vs main/master
- "Entire codebase" - Review the full project
```

2. **If reviewing uncommitted changes:**

   a. Check if there are changes:

   ```bash
   git status --short
   ```

   b. If no changes, inform the user and stop:

   > No uncommitted changes detected. Either make changes first, or run `/deep-review` and select a different scope.

   c. Get the diff for context:

   ```bash
   diff=$(git diff HEAD)
   changed_files=$(git diff --name-only HEAD)
   ```

   d. Set the review context for agents:

   ```
   review_context = f"Review these uncommitted changes:\n\nChanged files: {changed_files}\n\n{diff}"
   review_scope = "uncommitted"
   ```

3. **If reviewing branch changes:**

   a. Determine the base branch (main or master):

   ```bash
   # Check which base branch exists
   git rev-parse --verify main 2>/dev/null && base_branch="main" || base_branch="master"
   ```

   b. Get the current branch name:

   ```bash
   current_branch=$(git branch --show-current)
   ```

   c. Check if there are branch changes:

   ```bash
   git log ${base_branch}..HEAD --oneline
   ```

   d. If no changes, inform the user and stop:

   > No changes found between current branch and ${base_branch}. You may already be on the base branch, or all changes have been merged.

   e. Get the diff for context:

   ```bash
   diff=$(git diff ${base_branch}...HEAD)
   changed_files=$(git diff --name-only ${base_branch}...HEAD)
   commit_count=$(git rev-list --count ${base_branch}..HEAD)
   ```

   f. Set the review context for agents:

   ```
   review_context = f"Review branch changes ({commit_count} commits on {current_branch} vs {base_branch}):\n\nChanged files: {changed_files}\n\n{diff}"
   review_scope = "branch"
   ```

4. **If reviewing entire codebase:**

   a. Identify key directories and files to review:

   ```bash
   # Get project structure
   find . -type f -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" | head -100
   ```

   b. Set the review context for agents:

   ```
   review_context = "Review the entire codebase for issues. Focus on: src/, lib/, app/, or equivalent main source directories."
   review_scope = "codebase"
   target_files = ["src/", "lib/", "app/", "."]  # Agent will explore
   ```

5. **Check if task-master is initialized:**

   ```bash
   # Check if task-master is available for issue tracking
   if test -d .taskmaster; then
       taskmaster_available=true
   else
       taskmaster_available=false
   fi
   ```

6. **Launch all 9 review agents in parallel** using the Task tool:

```python
# Each agent will internally spawn claude, codex, and gemini for 3-model analysis
# Prompts are adjusted based on review_scope

if review_scope == "uncommitted":
    context_intro = "Review these uncommitted changes"
elif review_scope == "branch":
    context_intro = "Review these branch changes"
else:
    context_intro = "Review the entire codebase"

# Code Quality Agents
code_reviewer = Task(
    subagent_type="code-reviewer",
    prompt=f"{context_intro} for code quality issues:\n\n{review_context}",
    description="Code quality review"
)

security_auditor = Task(
    subagent_type="security-auditor",
    prompt=f"{context_intro} for security vulnerabilities:\n\n{review_context}",
    description="Security audit"
)

test_analyzer = Task(
    subagent_type="test-analyzer",
    prompt=f"{context_intro} - analyze test coverage:\n\n{review_context}",
    description="Test analysis"
)

# Performance & Reliability Agents
performance_analyzer = Task(
    subagent_type="performance-analyzer",
    prompt=f"{context_intro} for performance issues:\n\n{review_context}",
    description="Performance analysis"
)

silent_failure_hunter = Task(
    subagent_type="silent-failure-hunter",
    prompt=f"{context_intro} for silent failures:\n\n{review_context}",
    description="Silent failure detection"
)

type_checker = Task(
    subagent_type="type-checker",
    prompt=f"{context_intro} for type safety issues:\n\n{review_context}",
    description="Type safety analysis"
)

# Architecture & Maintainability Agents
code_simplifier = Task(
    subagent_type="code-simplifier",
    prompt=f"{context_intro} for complexity issues:\n\n{review_context}",
    description="Complexity analysis"
)

refactoring_advisor = Task(
    subagent_type="refactoring-advisor",
    prompt=f"{context_intro} for refactoring opportunities:\n\n{review_context}",
    description="Refactoring analysis"
)

dependency_checker = Task(
    subagent_type="dependency-checker",
    prompt=f"{context_intro} - check dependency health:\n\n{review_context}",
    description="Dependency analysis"
)
```

7. Collect and aggregate results from all agents

7.5. **Validate findings with suggestion-critic:**

Before presenting findings, run them through the critic agent to filter false positives and validate suggestions:

```python
critic = Task(
    subagent_type="suggestion-critic",
    prompt=f"""Validate these aggregated findings from 9 review agents:

Review scope: {review_scope}
Changed files: {changed_files}

## Aggregated Findings

{aggregated_findings_from_all_agents}

Evaluate each finding for:
1. **Existence** - Does the issue actually exist at the reported location?
2. **Scope** - Is it within the review scope (changed files)?
3. **Actionability** - Can it be fixed without major refactoring?
4. **Necessity** - Is it a real problem, not theoretical?
5. **False Positive** - Is there explicit justification in code?
6. **Duplication** - Same issue from multiple agents?
7. **Scope Creep** - Would fixing this expand beyond the PR's original intent?
   - Reject "while you're here" improvements to unrelated code
   - Reject cleanup suggestions for files with minimal changes
   - Reject refactoring of code not directly affected by the changes

Return:
- Validated findings organized by severity
- Filtered findings with rejection reasons
- Task creation recommendations (P0/P1/P2/P3)""",
    description="Validating findings"
)
```

Use the critic's filtered output for the remaining steps. Only validated findings should be presented to the user and considered for task creation.

8. Present validated findings organized by severity:

```markdown
## Deep Review Summary

**Scope**: [Uncommitted changes | Branch changes | Entire codebase]

### 🔴 Critical Issues (Must Fix)

[Aggregated critical findings from all agents]

### 🟠 High Priority (Should Fix)

[Aggregated high severity findings]

### 🟡 Medium Priority (Recommended)

[Aggregated medium severity findings]

### 🟢 Low Priority (Optional)

[Aggregated low severity findings]

### Agent-Specific Insights

#### Code Quality

[Summary from code-reviewer]

#### Security

[Summary from security-auditor]

#### Testing

[Summary from test-analyzer]

#### Performance

[Summary from performance-analyzer]

#### Error Handling

[Summary from silent-failure-hunter]

#### Type Safety

[Summary from type-checker]

#### Complexity

[Summary from code-simplifier]

#### Refactoring

[Summary from refactoring-advisor]

#### Dependencies

[Summary from dependency-checker]

### Consensus Analysis

- **All agents agree**: [High confidence issues]
- **Most agents agree**: [Good confidence issues]
- **Divergent views**: [Issues needing human judgment]

### Filtered by Critic

- **Total findings received**: X
- **Validated (shown above)**: Y
- **Filtered out**: Z
  - False positives: A
  - Out of scope: B
  - Duplicates: C
  - Not actionable: D
  - Scope creep: E
```

9. Offer to help address any issues found

10. **If task-master is available, create tasks for validated findings:**

    a. If `taskmaster_available` is true and there are validated Critical or High severity findings:

    b. Use AskUserQuestion to let user select which validated findings to track:

    ```
    Question: "Which findings would you like to track as tasks?"
    Header: "Track tasks"
    Options: [List each Critical/High finding with brief description as label]
    MultiSelect: true
    ```

    c. For each selected finding, create a task-master task using MCP tools:

    | Flag            | Content                                                                     |
    | --------------- | --------------------------------------------------------------------------- |
    | `--title`       | Brief identifier: `[SEVERITY] agent: issue summary`                         |
    | `--type`        | `bug` for defects, `task` for improvements                                  |
    | `--priority`    | 0-3 based on severity (see table below)                                     |
    | `--labels`      | Agent source + category: `agent:<name>,<category>[,<subcategory>]`          |
    | `--notes`       | Confidence level: "All 3 models agree" / "2 of 3 agree" / "Divergent views" |
    | `--acceptance`  | Criteria for when the issue is considered fixed                             |
    | `--description` | Detailed context (see template below)                                       |

    **Priority mapping:**

    | Severity | Priority |
    | -------- | -------- |
    | Critical | 0 (P0)   |
    | High     | 1 (P1)   |
    | Medium   | 2 (P2)   |
    | Low      | 3 (P3)   |

    **Description template:**

    ```markdown
    ## Issue

    [Brief description of the problem]

    ## Location

    - **File**: [file path]
    - **Line**: [line number]
    - **Function**: `[function_name()]`

    ## Problem

    [Detailed explanation of why this is a problem, including impact/risk]
    [Code snippet showing the issue]

    ## Related Files

    - [Other files that may need similar fixes]

    ## References

    - [Links to OWASP, docs, best practices, etc.]

    ## Recommendation

    [Suggested fix with code example if applicable]
    ```

    **Example for a critical security finding:**
    Use `mcp__task-master-ai__add_task` with:

    - title: "[CRITICAL] security: SQL injection vulnerability"
    - description: Full details including location, problem, recommendation
    - priority: "high"
    - status: "backlog"

    d. Report created tasks:

    > Created X task-master tasks for the selected findings. Use `next_task` to view them.

11. **If reviewing branch changes, offer to post findings as PR review comments:**

    a. Check if there's an open PR for the current branch:

    ```bash
    gh pr view --json number --jq '.number' 2>/dev/null
    ```

    b. If a PR exists, ask the user:

    ```
    Question: "Post these findings as inline PR review comments?"
    Header: "PR review"
    Options:
    - "Yes, submit review" - Post validated findings as GitHub PR review with inline comments
    - "No, skip" - Don't post to GitHub
    ```

    c. If user selects "Yes", invoke the github-pr-review skill with the PR number:

    ```python
    Skill(skill="github-pr-review", args=str(pr_number))
    ```

    The skill will use the findings already in context to create inline review comments with code suggestions.

12. **Commit the changes** (if reviewing uncommitted changes):

    If `review_scope == "uncommitted"` and there are staged/unstaged changes:

    a. Use AskUserQuestion to confirm:

    ```
    Question: "Would you like to commit these changes now?"
    Header: "Commit"
    Options:
    - "Yes, commit" - Run /commit to create a commit
    - "No, skip" - Skip committing
    ```

    b. If user selects "Yes, commit", invoke the commit skill:

    ```python
    Skill(skill="commit")
    ```

## Handling Subagent User Input Requests

Subagents cannot use AskUserQuestion directly (filtered at system level). When a subagent returns a response indicating it needs user input (structured options list), you must:

1. **Detect the pattern**: Look for responses containing phrases like "Options:", "Select one:", "Choose:", or formatted option lists (A/B/C or numbered lists)

2. **Present via AskUserQuestion**: Convert the subagent's options into an AskUserQuestion call:

```python
# If subagent returned:
# "Options:
#  - Option A: Link to existing list (recommended)
#  - Option B: Create new list
#  - Option C: Choose different space"

# Present to user:
AskUserQuestion(
    question="Which option would you like?",
    header="Selection",
    options=[
        {"label": "Link to existing list (Recommended)", "description": "Use the existing list found"},
        {"label": "Create new list", "description": "Create a fresh list"},
        {"label": "Choose different space", "description": "Browse other spaces"}
    ]
)
```

3. **Relay the choice**: If the subagent needs to continue with the user's selection, spawn it again with the choice included in the prompt.

## Notes

- This command runs 9 agents in parallel, each spawning 3 AI models
- Total of 27 AI model invocations for comprehensive coverage
- Expect longer execution time (~2-3 minutes for changes, ~5+ minutes for full codebase)
- Results are deduplicated and aggregated by severity
- For large codebases, agents will focus on main source directories
- If task-master is initialized (`.taskmaster/` directory exists), offer to create tasks for findings
- Optionally sync tasks to ClickUp for team collaboration
