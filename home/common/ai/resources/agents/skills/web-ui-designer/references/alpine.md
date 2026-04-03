# Alpine.js Patterns

Lightweight client-side interactivity — dropdowns, toggles, tabs, local UI state. No build step needed.

## Basic Toggle

```html
<div x-data="{ open: false }">
  <button @click="open = !open">Menu</button>
  <nav x-show="open" x-transition @click.outside="open = false">
    <!-- menu items -->
  </nav>
</div>
```

## Tabs

```html
<div x-data="{ tab: 'overview' }">
  <button @click="tab = 'overview'" :class="tab === 'overview' && 'border-b-2 border-accent'">Overview</button>
  <button @click="tab = 'details'" :class="tab === 'details' && 'border-b-2 border-accent'">Details</button>

  <div x-show="tab === 'overview'">...</div>
  <div x-show="tab === 'details'">...</div>
</div>
```

## Accordion

```html
<div x-data="{ active: null }">
  <template x-for="(item, i) in items">
    <div>
      <button @click="active = active === i ? null : i" x-text="item.title"></button>
      <div x-show="active === i" x-collapse>
        <p x-text="item.content"></p>
      </div>
    </div>
  </template>
</div>
```

## Chart Initialization

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

## Dark Mode Toggle

```html
<button @click="document.documentElement.classList.toggle('dark')">
  Toggle Theme
</button>
```

## Key Directives

- `x-data` — reactive state scope
- `x-show` / `x-if` — conditional display
- `x-for` — list rendering
- `x-bind` (`:`) — bind attributes
- `x-on` (`@`) — event listeners
- `x-transition` — enter/leave animations
- `x-collapse` — smooth height animation (plugin)
- `x-ref` / `$refs` — DOM element references
- `@click.outside` — click-outside detection
