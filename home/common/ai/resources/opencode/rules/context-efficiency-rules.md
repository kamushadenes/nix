## Context Efficiency

### File Reading

- Read files with purpose — know what you're looking for before reading.
- Use Grep to locate relevant sections before reading entire large files.
- For files over 500 lines, use offset/limit to read only the relevant section.

### Tables — STRICT RULES

- Markdown tables: use minimum separator (`|-|-|`). Never pad with repeated
  hyphens (`|---|---|`).
- NEVER use box-drawing / ASCII-art tables (`┌`, `┬`, `─`, `│`, `└`, `┘`, `├`,
  `┤`, `┼`). Completely banned.
- No exceptions. Not for "clarity", not for alignment, not for terminal output.
