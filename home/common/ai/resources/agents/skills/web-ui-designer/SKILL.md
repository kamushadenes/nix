---
name: web-ui-designer
description: Design and implement web UIs with a design-system-first approach. Use when building dashboards, admin panels, landing pages, or any web frontend. Covers design tokens, dark/light themes, responsive layouts, chart/data visualization, component architecture, and progressive enhancement. Works with any server-rendered stack (Go/Templ, Python/Jinja, Ruby/ERB, Node/EJS) or client-rendered framework (React, Vue, Svelte). Also use when redesigning existing UIs or adding new pages/views to an existing web app.
---

# Web UI Designer

Design-system-first approach to web UI implementation. Every visual decision flows from centralized tokens — never scatter styles across components.

## Tech Stack Selection

Before building, determine the rendering approach:

1. **Check existing codebase** — look for existing templates, component files, `package.json`, `go.mod`, `requirements.txt`, `Gemfile`, or similar. If the project already has a frontend stack, use it.
2. **If no existing stack**, ask the user what they prefer. Suggest options based on the detected backend language:

| Backend | Server-Rendered Options | Client-Rendered Options |
|-|-|-|
| Go | Templ or html/template + Unpoly or HTMX | — |
| Python | Jinja2 + HTMX or Unpoly | React/Vue/Svelte via separate frontend |
| Ruby | ERB/Slim + HTMX or Turbo | React/Vue via separate frontend |
| Node/TS | EJS/Handlebars + HTMX | React/Next, Vue/Nuxt, Svelte/Kit |
| Rust | Askama/Tera + HTMX | Leptos, Yew |
| Any (static) | Plain HTML + Alpine.js | — |

3. **Load reference files** for the chosen technologies. Only read what's needed:

- **Progressive enhancement**: [references/unpoly.md](references/unpoly.md) or [references/htmx.md](references/htmx.md)
- **Client-side interactivity**: [references/alpine.md](references/alpine.md)
- **Go templating + binary embedding**: [references/go-templ.md](references/go-templ.md)
- **Tailwind CSS setup**: [references/tailwind.md](references/tailwind.md)
- **Chart configurations**: [references/chart-patterns.md](references/chart-patterns.md)
- **SEO (public-facing pages)**: [references/seo.md](references/seo.md)

## Design System Foundation

### 1. Define Tokens First

Before writing any component, establish CSS custom properties:

```css
:root {
  /* Surface hierarchy */
  --bg-primary: 222 47% 11%;      /* main background */
  --bg-secondary: 217 33% 17%;    /* cards, panels */
  --bg-tertiary: 215 28% 22%;     /* hover states, wells */
  --bg-elevated: 213 27% 15%;     /* modals, dropdowns */

  /* Text hierarchy */
  --text-primary: 210 40% 98%;    /* headings, important */
  --text-secondary: 215 20% 65%;  /* body text */
  --text-muted: 215 16% 47%;      /* labels, captions */

  /* Accent palette */
  --accent: 199 89% 48%;          /* primary actions */
  --accent-hover: 199 89% 55%;
  --success: 142 71% 45%;
  --warning: 38 92% 50%;
  --danger: 0 84% 60%;

  /* Effects */
  --shadow-sm: 0 1px 2px hsl(0 0% 0% / 0.3);
  --shadow-md: 0 4px 12px hsl(0 0% 0% / 0.4);
  --shadow-glow: 0 0 40px hsl(var(--accent) / 0.15);
  --gradient-primary: linear-gradient(135deg, hsl(var(--accent)), hsl(var(--accent-hover)));
  --radius-sm: 0.375rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}
```

For light mode, provide a matching set with inverted surface/text values:

```css
:root.light, :root:not(.dark) {
  --bg-primary: 0 0% 100%;
  --bg-secondary: 210 40% 96%;
  --text-primary: 222 47% 11%;
  --text-secondary: 215 20% 35%;
  --text-muted: 215 16% 53%;
  /* accents and effects typically stay the same */
}
```

**Watch for dark/light pitfalls**: white text on white backgrounds (or dark text on dark backgrounds) when switching modes. Test both.

### 2. Never Hardcode Colors in Components

```html
<!-- BAD: hardcoded -->
<div class="bg-gray-900 text-white">
<div class="shadow-[0_0_40px_rgba(0,120,255,0.3)]">

<!-- GOOD: token-driven -->
<div class="bg-surface-secondary text-content-primary">
<div style="box-shadow: var(--shadow-glow)">
```

For Tailwind, extend the config to map tokens — see [references/tailwind.md](references/tailwind.md).

### 3. Component Variants

Define visual variants through the design system, not inline overrides:

```css
/* Define in your CSS / design system */
.btn-primary { background: hsl(var(--accent)); color: hsl(var(--text-primary)); }
.btn-ghost { background: transparent; color: hsl(var(--text-secondary)); border: 1px solid hsl(var(--text-muted) / 0.2); }
.btn-danger { background: hsl(var(--danger)); color: hsl(var(--text-primary)); }
```

Use framework-specific variant patterns (CVA for React, template classes for server-rendered) rather than ad-hoc Tailwind class strings scattered across components.

## Component Patterns

### Stat Cards

```html
<div class="bg-surface-secondary rounded-lg border border-white/5 p-5">
  <div class="flex items-center justify-between mb-2">
    <span class="text-content-muted text-sm">Total Requests</span>
    <span class="text-emerald-400 text-xs">+12.5%</span>
  </div>
  <div class="text-3xl font-bold text-content-primary">24,531</div>
  <div class="text-content-muted text-xs mt-1">Last 24 hours</div>
</div>
```

### Data Tables

- Zebra-stripe with `bg-white/[0.02]` alternating rows
- Sticky headers with `backdrop-blur-sm`
- Row hover: `hover:bg-white/[0.04]`
- Sort indicators with subtle chevrons
- Pagination with page size selector

### Navigation

- Sidebar: fixed, dark, icon+label, collapsible
- Top bar: breadcrumbs, user menu, global actions
- Active state: accent left-border or background highlight
- Mobile: hamburger menu or bottom tabs

## Data Visualization

### Chart Library Selection

| Library | Best for | Embed? |
|-|-|-|
| Chart.js | Simple charts, small bundle | CDN or embed |
| ECharts | Rich interactive dashboards | CDN |
| D3 | Custom, unusual visualizations | CDN |
| Lightweight Charts | Financial/time-series | CDN |

### Chart Design Rules

1. **Dark theme charts**: transparent background, light gridlines at 10% opacity, accent colors for data
2. **Tooltips**: dark bg, rounded, show all relevant values
3. **Legends**: inline or below chart, interactive toggle
4. **Responsive**: charts resize with container, hide labels on small screens
5. **Animations**: subtle 300ms ease-in-out on load, no flashy transitions

See [references/chart-patterns.md](references/chart-patterns.md) for specific chart configs.

## Layout Patterns

### Dashboard Grid

```
+--sidebar--+--------main content--------+
|  nav      | stat cards (3-4 col grid)  |
|  links    |----------------------------|
|           | chart row (2 col)          |
|           |----------------------------|
|           | data table (full width)    |
+-----------+----------------------------+
```

- Use CSS Grid: `grid-template-columns: 240px 1fr`
- Content area: `max-w-screen-2xl mx-auto px-6 py-6`
- Card gaps: `gap-4` for stat cards, `gap-6` for chart sections
- Responsive: sidebar collapses to icons at `lg:`, hidden at `md:`

### Page Hierarchy

Every page follows: **Page title + filters > Summary cards > Charts > Detail table/list**

## Responsive Design

- Mobile-first: base styles for small screens, `md:`/`lg:` for larger
- Stat cards: `grid-cols-1 sm:grid-cols-2 lg:grid-cols-4`
- Charts: full-width on mobile, 2-col on desktop
- Tables: horizontal scroll wrapper on mobile
- Navigation: bottom tabs on mobile, sidebar on desktop

## Accessibility

- Color contrast: 4.5:1 minimum for text, 3:1 for large text
- Focus rings: visible, high-contrast (`ring-2 ring-accent ring-offset-2 ring-offset-surface-primary`)
- ARIA labels on interactive charts
- Keyboard navigation for all controls
- Reduced motion: `@media (prefers-reduced-motion: reduce)` to disable animations
