# GitHub Wiki Documentation

Workflow and conventions for writing documentation to a GitHub Wiki.

## How GitHub Wikis Work

- Each repo's wiki is a separate git repo at `github.com/OWNER/REPO.wiki.git`
- Pages are markdown files — the filename (minus `.md`) becomes the page title
- Flat structure — subdirectories are not rendered as pages in the web UI
- `Home.md` is the landing page (shown when visiting the wiki root)
- `_Sidebar.md` controls the navigation sidebar on every page
- `_Footer.md` adds a footer to every page
- Changes are pushed with regular git commits

## Workflow

### Step 1: Check Wiki Availability

```bash
# Verify the repo has a wiki (may need to be enabled in repo settings)
gh api repos/OWNER/REPO --jq '.has_wiki'
```

If the wiki has never been initialized, create a `Home.md` page via the GitHub
web UI first — the wiki git repo doesn't exist until the first page is created.

### Step 2: Clone the Wiki

```bash
# Clone alongside the main repo
gh repo clone OWNER/REPO.wiki -- ../REPO.wiki

# Or with full URL
git clone https://github.com/OWNER/REPO.wiki.git ../REPO.wiki
```

### Step 3: Write Pages

Create markdown files in the cloned wiki repo. Use the naming conventions below.

### Step 4: Build Navigation

Create or update `_Sidebar.md` with links to all pages:

```markdown
**[Home](Home)**

**Getting Started**

- [Installation](Installation)
- [Configuration](Configuration)
- [Quick Start](Quick-Start)

**Guides**

- [Developer Guide](Developer-Guide)
- [API Reference](API-Reference)
- [Deployment](Deployment)

**Reference**

- [Architecture](Architecture)
- [Configuration Reference](Configuration-Reference)
- [Troubleshooting](Troubleshooting)
```

### Step 5: Push

```bash
git add -A
git commit -m "docs: update wiki documentation"
git push
```

## Page Naming Conventions

GitHub Wiki converts filenames to page titles and URL slugs:

| Filename                           | Page Title                    | URL Path                              |
| ---------------------------------- | ----------------------------- | ------------------------------------- |
| `Home.md`                          | Home                          | `/wiki` (root)                        |
| `API-Reference.md`                 | API Reference                 | `/wiki/API-Reference`                 |
| `Getting-Started.md`               | Getting Started               | `/wiki/Getting-Started`               |
| `Architecture-Decision-Records.md` | Architecture Decision Records | `/wiki/Architecture-Decision-Records` |

Rules:

- Use **Title-Case-With-Hyphens** for filenames
- Hyphens become spaces in the displayed title
- No subdirectories — use prefixes for grouping if needed (e.g.,
  `Guide-Developer.md`, `Guide-Deployment.md`)
- Keep names concise — they appear in the sidebar and URL

## Linking Between Pages

Use the page name without `.md` and without path:

```markdown
See the [API Reference](API-Reference) for endpoint details.

For setup, start with [Installation](Installation).
```

For linking to a specific section within a page:

```markdown
See [Configuration Reference > Database](Configuration-Reference#database).
```

## Special Pages

### Home.md

The wiki landing page. Structure it as a navigation hub:

```markdown
# Project Name

Brief project description.

## Documentation

| Topic                              | Description                         |
| ---------------------------------- | ----------------------------------- |
| [Installation](Installation)       | Set up your development environment |
| [Quick Start](Quick-Start)         | Get running in 5 minutes            |
| [API Reference](API-Reference)     | Complete endpoint documentation     |
| [Architecture](Architecture)       | System design and decision records  |
| [Deployment](Deployment)           | Production deployment guide         |
| [Troubleshooting](Troubleshooting) | Common issues and solutions         |
```

### \_Sidebar.md

Keep the sidebar concise — group pages logically, use bold for section headings.
The sidebar appears on every page, so it should provide quick navigation without
overwhelming.

### \_Footer.md

Optional. Use for links back to the main repo, contribution info, or license:

```markdown
---

[Main Repository](https://github.com/OWNER/REPO) |
[Report an Issue](https://github.com/OWNER/REPO/issues/new) |
[Contributing](https://github.com/OWNER/REPO/blob/main/CONTRIBUTING.md)
```

## Mapping Doc Types to Wiki Pages

| Doc Type        | Wiki Page(s)                                                              |
| --------------- | ------------------------------------------------------------------------- |
| API Reference   | `API-Reference.md` (or split: `API-Users.md`, `API-Resources.md`)         |
| Architecture    | `Architecture.md` + individual ADRs as `ADR-001-Title.md`                 |
| Developer Guide | `Developer-Guide.md`, `Coding-Conventions.md`                             |
| Operations      | `Deployment.md`, `Runbook.md`, `Migration-Guide.md`                       |
| Configuration   | `Configuration-Reference.md`                                              |
| Changelog       | Link to `CHANGELOG.md` in main repo instead (changelogs belong with code) |

## Tips

- Initialize the wiki via the web UI before cloning — the git repo won't exist
  otherwise
- Always update `_Sidebar.md` when adding new pages
- Use the `Home.md` page as a table of contents, not as documentation itself
- Keep individual pages focused — split large topics into multiple pages
- Changelogs and ADRs often work better in the main repo where they're versioned
  with the code
- Images can be added by committing them to the wiki repo and referencing with
  relative paths
