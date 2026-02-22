# Post-Plan Execution

After a plan is accepted (exiting plan mode):

**If .planning/ exists:** Suggest `/gsd:execute-phase` for structured execution
**If no .planning/:** For 3+ independent steps, suggest `/gsd:quick`
**Simple tasks (<3 steps):** Execute directly, no orchestration needed
