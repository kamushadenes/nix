# Server-Rendered Stack Patterns

Patterns for building rich UIs with server-rendered templates instead of JS frameworks.

## Go + Templ

### Component Pattern

```go
// components/stat_card.templ
templ StatCard(label string, value string, trend string, trendUp bool) {
  <div class="bg-surface-secondary rounded-lg border border-white/5 p-5">
    <div class="flex items-center justify-between mb-2">
      <span class="text-content-muted text-sm">{ label }</span>
      if trend != "" {
        <span class={ trendClass(trendUp) }>{ trend }</span>
      }
    </div>
    <div class="text-3xl font-bold text-content-primary">{ value }</div>
  </div>
}
```

### Layout Pattern

```go
templ Layout(title string, activePage string) {
  <!DOCTYPE html>
  <html lang="en" class="dark">
  <head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>{ title }</title>
    <link rel="stylesheet" href="/static/app.css"/>
    <script src="/static/vendor.js"></script>
  </head>
  <body class="bg-surface-primary min-h-screen text-content-secondary">
    @Sidebar(activePage)
    <main class="ml-60 p-6">
      { children... }
    </main>
  </body>
  </html>
}
```

### Embedding Static Assets

```go
//go:embed static
var staticFS embed.FS

// Serve with cache headers
mux.Handle("/static/", http.StripPrefix("/static/",
  addCacheHeaders(http.FileServer(http.FS(staticFS)))))
```

## Unpoly (Progressive Enhancement)

### SPA Navigation

```html
<!-- Links update only the main content area -->
<a href="/dashboard/analytics" up-follow up-target=".main-content">Analytics</a>

<!-- Forms submit without full reload -->
<form up-submit up-target=".result-area">
```

### Live Polling

```html
<!-- Poll every 5 seconds, update this element -->
<div id="health-grid" up-poll="5000" up-source="/api/health-fragment">
  <!-- server renders updated HTML -->
</div>
```

### Fragment Updates

Return partial HTML from server endpoints (no JSON needed):

```go
func handleHealthFragment(w http.ResponseWriter, r *http.Request) {
  data := getHealthData()
  templates.HealthFragment(data).Render(r.Context(), w)
}
```

### Layer (Modal/Drawer)

```html
<a href="/accounts/new" up-layer="new drawer" up-size="medium">
  Add Account
</a>
```

### Inline Editing

```html
<a href="/accounts/1/edit" up-target=".account-name" up-layer="new popup">
  Edit
</a>
```

### Transitions

```html
<!-- Animate content swaps -->
<main class="main-content" up-main>
  { children... }
</main>

<!-- Custom transition classes -->
<a href="/page" up-follow up-transition="cross-fade">Link</a>
```

### Hungry Elements (Auto-Update Multiple Fragments)

```html
<!-- Sidebar notification count updates alongside main content -->
<span id="notif-count" up-hungry>3</span>
```

## Alpine.js for Client-Side Logic

Minimal JS for dropdowns, toggles, tabs — without a build step.

```html
<div x-data="{ open: false }">
  <button @click="open = !open">Menu</button>
  <nav x-show="open" x-transition @click.outside="open = false">
    <!-- menu items -->
  </nav>
</div>
```

### Chart Initialization with Alpine

```html
<div x-data="chartWidget('/api/metrics')" x-init="load()">
  <canvas x-ref="chart" class="h-64"></canvas>
</div>

<script>
function chartWidget(endpoint) {
  return {
    chart: null,
    async load() {
      const res = await fetch(endpoint);
      const data = await res.json();
      this.chart = new Chart(this.$refs.chart, buildConfig(data));
    }
  }
}
</script>
```

## Tailwind CSS Integration

### With CDN (No Build Step)

```html
<script src="https://cdn.tailwindcss.com"></script>
<script>
tailwind.config = {
  darkMode: 'class',
  theme: { extend: { colors: { /* token mappings */ } } }
}
</script>
```

### With Build Step (Embedded)

Generate CSS at build time, embed the output:

```bash
npx tailwindcss -i input.css -o static/app.css --minify
```

### Tailwind v4 Notes

- Uses `@import 'tailwindcss'` instead of `@tailwind base/components/utilities`
- `@apply` is deprecated for complex selectors — use Go/template helper functions for dynamic classes
- CSS-first configuration via `@theme` blocks instead of `tailwind.config.js`

## Single-Binary Embedding Checklist

For Go projects shipping a single binary with embedded UI:

1. CSS: Tailwind output in `static/app.css` (built at compile time)
2. JS: Vendor libs (chart library, Unpoly) in `static/vendor.js`
3. Fonts: Subset and embed, or use system font stack
4. Icons: Inline SVG in templates (no icon font files)
5. Images: SVG preferred, raster only if needed
6. Embed: `//go:embed static` for the entire static directory
