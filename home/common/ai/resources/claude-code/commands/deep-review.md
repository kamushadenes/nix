---
allowed-tools: Bash(git status:*), Bash(git diff:*), Task
description: Comprehensive multi-agent code review using 9 specialized agents with 3-model consensus
---

Run a comprehensive deep review using all specialized review agents in parallel. Each agent uses 3 AI models (claude, codex, gemini) for thorough analysis.

## Steps

1. Check if there are changes to review:

```bash
git status --short
```

2. If there are no changes, inform the user:

> No changes detected. Run `/deep-review` after making code changes.

3. If there are changes, get the diff for context:

```bash
diff=$(git diff HEAD)
changed_files=$(git diff --name-only HEAD)
```

4. **Launch all 9 review agents in parallel** using the Task tool:

```python
# Each agent will internally spawn claude, codex, and gemini for 3-model analysis

# Code Quality Agents
code_reviewer = Task(
    subagent_type="code-reviewer",
    prompt=f"Review these changes for code quality issues:\n\n{diff}",
    description="Code quality review"
)

security_auditor = Task(
    subagent_type="security-auditor",
    prompt=f"Audit these changes for security vulnerabilities:\n\n{diff}",
    description="Security audit"
)

test_analyzer = Task(
    subagent_type="test-analyzer",
    prompt=f"Analyze test coverage for these changes:\n\nChanged files: {changed_files}\n\n{diff}",
    description="Test analysis"
)

# Performance & Reliability Agents
performance_analyzer = Task(
    subagent_type="performance-analyzer",
    prompt=f"Check these changes for performance issues:\n\n{diff}",
    description="Performance analysis"
)

silent_failure_hunter = Task(
    subagent_type="silent-failure-hunter",
    prompt=f"Hunt for silent failures in these changes:\n\n{diff}",
    description="Silent failure detection"
)

type_checker = Task(
    subagent_type="type-checker",
    prompt=f"Analyze type safety in these changes:\n\n{diff}",
    description="Type safety analysis"
)

# Architecture & Maintainability Agents
code_simplifier = Task(
    subagent_type="code-simplifier",
    prompt=f"Identify complexity issues in these changes:\n\n{diff}",
    description="Complexity analysis"
)

refactoring_advisor = Task(
    subagent_type="refactoring-advisor",
    prompt=f"Identify refactoring opportunities in these changes:\n\n{diff}",
    description="Refactoring analysis"
)

dependency_checker = Task(
    subagent_type="dependency-checker",
    prompt=f"Check dependency health for these changes:\n\nChanged files: {changed_files}",
    description="Dependency analysis"
)
```

5. Collect and aggregate results from all agents

6. Present unified findings organized by severity:

```markdown
## Deep Review Summary

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

7. Offer to help address any issues found

## Notes

- This command runs 9 agents in parallel, each spawning 3 AI models
- Total of 27 AI model invocations for comprehensive coverage
- Expect longer execution time (~2-3 minutes) due to multi-model analysis
- Results are deduplicated and aggregated by severity
