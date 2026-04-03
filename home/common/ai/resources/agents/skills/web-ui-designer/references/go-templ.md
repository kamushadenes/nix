# Go + Templ Patterns

Type-safe HTML templating for Go. Components are Go functions that render HTML with compile-time checking.

## Component Pattern

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

## Layout Pattern

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

## Embedding Static Assets

```go
//go:embed static
var staticFS embed.FS

// Serve with cache headers
mux.Handle("/static/", http.StripPrefix("/static/",
  addCacheHeaders(http.FileServer(http.FS(staticFS)))))
```

## Fragment Handlers

Return partial HTML for Unpoly/HTMX — render only the fragment, not the full layout:

```go
func handleHealthFragment(w http.ResponseWriter, r *http.Request) {
  data := getHealthData()
  templates.HealthGrid(data).Render(r.Context(), w)
}
```

## Single-Binary Embedding Checklist

For Go projects shipping a single binary with embedded UI:

1. **CSS**: Tailwind output in `static/app.css` (built at compile time)
2. **JS**: Vendor libs (chart library, Unpoly/HTMX) in `static/vendor.js`
3. **Fonts**: Subset and embed, or use system font stack
4. **Icons**: Inline SVG in templates (no icon font files)
5. **Images**: SVG preferred, raster only if needed
6. **Embed**: `//go:embed static` for the entire static directory
