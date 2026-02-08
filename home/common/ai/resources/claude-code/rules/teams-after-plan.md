# Post-Plan Team Suggestion

After a plan is accepted by the user (exiting plan mode), proactively evaluate whether the plan would benefit from an Agent Team:

**Suggest a team when:**
- Plan has 3+ independent implementation steps
- Steps can be parallelized across different files/modules
- Work would take significant time sequentially

**How to suggest:**
Use AskUserQuestion to ask:
"This plan has N independent steps that could run in parallel. Would you like me to create an agent team to execute them?"
- "Yes, create a team" - Spawn teammates for parallel execution
- "No, I'll work through it sequentially" - Execute steps one by one

**Do NOT suggest when:**
- Plan has <3 steps
- Steps are sequential/dependent
- Plan is simple (single file, trivial changes)
