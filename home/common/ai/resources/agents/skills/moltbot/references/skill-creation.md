# Moltbot Skill Creation Guide

Moltbot skills follow the same structure as Claude Code skills. This reference covers the complete skill authoring format.

## SKILL.md Format

Every skill requires a `SKILL.md` file with YAML frontmatter and markdown body.

### Frontmatter (Required)

```yaml
---
name: skill-name
description: What it does and when to use it. Be comprehensive - this is the trigger mechanism.
---
```

### Optional Frontmatter Fields

```yaml
---
name: skill-name
description: Description with triggers
license: License info

# Metadata gating - skill only loads if conditions met
requires:
  bins:           # Required binaries in PATH
    - ffmpeg
    - imagemagick
  env:            # Required environment variables
    - OPENAI_API_KEY
  config:         # Required config files
    - ~/.config/myapp/config.json
os:               # Restrict to specific OS
  - darwin
  - linux
---
```

## Directory Structure

```
skill-name/
├── SKILL.md              # Required: metadata + instructions
├── scripts/              # Executable code
│   ├── process.py
│   └── validate.sh
├── references/           # Documentation loaded on-demand
│   ├── advanced.md
│   └── troubleshooting.md
└── assets/               # Files for output (templates, images)
    └── template.html
```

## Loading Precedence

When the same skill exists in multiple locations:

1. **Workspace skills** (`./skills/` in project) - Highest priority
2. **Managed skills** (`~/.moltbot/skills/`) - User installed
3. **Bundled skills** (built into moltbot) - Lowest priority

This allows project-specific overrides of global skills.

## Per-Skill Configuration

Skills can accept configuration via `moltbot.json`:

```json
{
  "skills": {
    "config": {
      "my-skill": {
        "apiEndpoint": "https://api.example.com",
        "maxRetries": 3
      }
    }
  }
}
```

Access in skill via environment or config injection (skill-specific).

## Best Practices

### Description Writing

The description is the primary trigger mechanism. Include:

- What the skill does
- When to use it (specific triggers)
- Key capabilities

**Example:**
```yaml
description: PDF document processing with extraction, rotation, merging, and form filling. Use when working with PDF files for: (1) extracting text or images, (2) rotating pages, (3) merging multiple PDFs, (4) filling form fields.
```

### Progressive Disclosure

Keep SKILL.md under 500 lines. Move detailed content to `references/`:

```markdown
## Quick Start
[Essential workflow]

## Advanced
- **Topic A**: See `references/topic-a.md`
- **Topic B**: See `references/topic-b.md`
```

### Scripts

Include scripts when:
- Same code would be rewritten repeatedly
- Deterministic reliability is required
- Complex operations need precise implementation

```markdown
## Processing
Run the included script:
\`\`\`bash
scripts/process.py input.pdf --output result.pdf
\`\`\`
```

### Assets

Include assets for:
- Output templates
- Boilerplate code
- Images or icons needed in output

## Example Skill

```
image-optimizer/
├── SKILL.md
├── scripts/
│   └── optimize.py
└── references/
    └── formats.md
```

**SKILL.md:**
```yaml
---
name: image-optimizer
description: Image optimization and format conversion. Use when optimizing images for web, converting formats, or batch processing images.
requires:
  bins:
    - imagemagick
---

# Image Optimizer

Optimize images for web use or convert between formats.

## Quick Start

\`\`\`bash
scripts/optimize.py input.jpg --quality 80 --output optimized.jpg
\`\`\`

## Supported Formats

See `references/formats.md` for format-specific options.
```
