---
name: skill-creator
description: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.
license: Complete terms in LICENSE.txt
---

# Skill Creator

Create skills that extend Claude's capabilities with specialized knowledge and tools.

## Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/     - Executable code
    ├── references/  - Documentation (loaded as needed)
    └── assets/      - Output files (templates, images)
```

## Core Principles

1. **Concise is key** - Context window is shared. Only add what Claude doesn't know.
2. **Progressive disclosure** - Metadata always loaded (~100w), SKILL.md on trigger (<5k words), references as needed
3. **Keep SKILL.md under 500 lines** - Extract details to references/

## Creation Process

1. **Understand** - Gather concrete usage examples from user
2. **Plan** - Identify scripts, references, assets needed
3. **Initialize** - `scripts/init_skill.py <name> --path <dir>`
4. **Edit** - Implement resources, write SKILL.md
5. **Package** - `scripts/package_skill.py <skill-folder>`
6. **Iterate** - Refine based on real usage

## Frontmatter

```yaml
---
name: skill-name
description: What it does AND when to use it. Include triggers here - body loads AFTER triggering.
---
```

## References

- **Multi-step workflows**: See `references/workflows.md`
- **Output patterns**: See `references/output-patterns.md`
- **Creation details**: See `references/creation-guide.md`
