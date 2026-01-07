---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git rev-parse:*), Task, AskUserQuestion
description: Comprehensive multi-agent code review using 9 specialized agents with 3-model consensus
---

Run a comprehensive deep review using all specialized review agents in parallel. Each agent uses 3 AI models (claude, codex, gemini) for thorough analysis.

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

5. **Launch all 9 review agents in parallel** using the Task tool:

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

6. Collect and aggregate results from all agents

7. Present unified findings organized by severity:

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
```

8. Offer to help address any issues found

## Notes

- This command runs 9 agents in parallel, each spawning 3 AI models
- Total of 27 AI model invocations for comprehensive coverage
- Expect longer execution time (~2-3 minutes for changes, ~5+ minutes for full codebase)
- Results are deduplicated and aggregated by severity
- For large codebases, agents will focus on main source directories
