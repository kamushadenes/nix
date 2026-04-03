# Tailwind CSS Setup

## CDN (No Build Step)

Quick start for prototyping — no Node.js required:

```html
<script src="https://cdn.tailwindcss.com"></script>
<script>
tailwind.config = {
  darkMode: 'class',
  theme: { extend: { colors: { /* token mappings */ } } }
}
</script>
```

## Build Step (Embedded)

Generate optimized CSS at build time:

```bash
npx tailwindcss -i input.css -o static/app.css --minify
```

For Go/Rust/etc. projects, run this as a build step and embed the output.

## Tailwind v4 Notes

- Uses `@import 'tailwindcss'` instead of `@tailwind base/components/utilities`
- CSS-first configuration via `@theme` blocks instead of `tailwind.config.js`
- `@apply` deprecated for complex selectors — use template helper functions for dynamic classes
- Zero-config content detection (no `content` array needed)

## Token Integration

Map CSS custom properties to Tailwind theme (see SKILL.md Design System section for the full token set):

```js
// tailwind.config.js (v3) or @theme block (v4)
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

This lets you write `bg-surface-secondary` instead of `bg-[hsl(var(--bg-secondary))]`.
