# Skill Creation Guide

## Step 1: Understanding with Examples

Ask users for concrete usage examples:
- "What functionality should this skill support?"
- "Can you give examples of how it would be used?"
- "What would trigger this skill?"

## Step 2: Planning Resources

For each example, identify what would help:
- **Scripts**: Code rewritten repeatedly or needs deterministic reliability
- **References**: Documentation Claude should reference while working
- **Assets**: Files used in output (templates, images, boilerplate)

## Step 3: Initialize

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

Creates: SKILL.md template, example directories (scripts/, references/, assets/)

## Step 4: Edit

**Resources first**: Implement scripts, references, assets. Test scripts.

**SKILL.md guidelines**:
- Use imperative form
- Description = primary triggering mechanism
- Include "when to use" in description, not body
- Reference bundled resources with clear "when to read" guidance

## Step 5: Package

```bash
scripts/package_skill.py <path/to/skill-folder>
```

Validates then creates .skill file (zip with .skill extension).

## Resource Guidelines

### Scripts
- Test by running them
- Token efficient, deterministic
- May still be read for patching

### References
- Keeps SKILL.md lean
- For large files (>10k words), include grep patterns in SKILL.md
- Avoid duplication with SKILL.md

### Assets
- Not loaded into context
- Used in output: templates, images, fonts

## Progressive Disclosure Patterns

**Pattern 1: High-level guide with references**
```markdown
## Quick start
[essential example]

## Advanced
- **Feature A**: See [FEATURE_A.md](references/feature_a.md)
```

**Pattern 2: Domain-specific organization**
```
references/
├── finance.md
├── sales.md
└── product.md
```

**Pattern 3: Conditional details**
```markdown
## Basic usage
[simple content]

**For advanced feature**: See [ADVANCED.md](references/advanced.md)
```

## Do NOT Include

- README.md
- INSTALLATION_GUIDE.md
- CHANGELOG.md
- Any auxiliary documentation
