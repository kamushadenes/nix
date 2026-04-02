---
name: web-ui-designer
description: Design and implement web UIs with a design-system-first approach. Use when building dashboards, admin panels, landing pages, or any web frontend — especially server-rendered stacks (Templ, Go templates, Jinja, ERB) with Tailwind CSS. Covers design tokens, dark/light themes, responsive layouts, chart/data visualization, component architecture, and progressive enhancement. Also use when redesigning existing UIs or adding new pages/views to an existing web app.
---

# Web UI Designer

Design-system-first approach to web UI implementation. Every visual decision flows from centralized tokens — never scatter styles across components.

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
  --radius-sm: 0.375rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
}
```

### 2. Never Hardcode Colors in Components

```html
<!-- BAD: hardcoded -->
<div class="bg-gray-900 text-white">

<!-- GOOD: token-driven -->
<div class="bg-[hsl(var(--bg-secondary))] text-[hsl(var(--text-primary))]">
```

For Tailwind, extend the config to map tokens:

```js
// tailwind.config.js
colors: {
  surface: {
    primary: 'hsl(var(--bg-primary))',
    secondary: 'hsl(var(--bg-secondary))',
    tertiary: 'hsl(var(--bg-tertiary))',
  },
  content: {
    primary: 'hsl(var(--text-primary))',
    secondary: 'hsl(var(--text-secondary))',
    muted: 'hsl(var(--text-muted))',
  }
}
```

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

### Chart Configurations

See [references/chart-patterns.md](references/chart-patterns.md) for specific chart configs (time-series, bar, donut, stacked area, heatmap).

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

## Server-Rendered Stack Guide

For Go (Templ), Python (Jinja), Ruby (ERB), or similar:

1. **CSS**: Ship a single `app.css` with tokens + Tailwind utilities
2. **JS**: Minimal — chart library + Unpoly + Alpine.js for interactivity
3. **Components**: Template partials/components, not JS components
4. **Polling**: Unpoly `up-poll` with `up-source` for live-updating fragments
5. **SPA navigation**: Unpoly `up-follow`/`up-target` for seamless page transitions
6. **Modals/drawers**: Unpoly layers (`up-layer="new drawer"`) — no custom JS needed

See [references/server-rendered.md](references/server-rendered.md) for framework-specific patterns.

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
