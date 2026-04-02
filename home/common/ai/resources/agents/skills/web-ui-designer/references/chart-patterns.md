# Chart Patterns

Reusable chart configurations for common dashboard visualizations. All examples use Chart.js syntax but patterns apply to ECharts/D3.

## Time-Series Line Chart

Request volume, cost over time, latency trends.

```js
new Chart(ctx, {
  type: 'line',
  data: {
    labels: timestamps,
    datasets: [{
      label: 'Requests',
      data: values,
      borderColor: 'hsl(199, 89%, 48%)',
      backgroundColor: 'hsla(199, 89%, 48%, 0.1)',
      fill: true,
      tension: 0.3,
      pointRadius: 0,
      pointHoverRadius: 4,
      borderWidth: 2,
    }]
  },
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { display: false },
      tooltip: {
        backgroundColor: 'hsl(222, 47%, 14%)',
        borderColor: 'hsla(0, 0%, 100%, 0.1)',
        borderWidth: 1,
        titleColor: 'hsl(210, 40%, 98%)',
        bodyColor: 'hsl(215, 20%, 65%)',
        padding: 12,
        cornerRadius: 8,
      }
    },
    scales: {
      x: {
        grid: { color: 'hsla(0, 0%, 100%, 0.05)' },
        ticks: { color: 'hsl(215, 16%, 47%)', maxTicksLimit: 8 }
      },
      y: {
        grid: { color: 'hsla(0, 0%, 100%, 0.05)' },
        ticks: { color: 'hsl(215, 16%, 47%)' },
        beginAtZero: true,
      }
    }
  }
});
```

## Multi-Series Line Chart

Comparing providers, models, or accounts over time.

- Use distinct hue-shifted colors: blue, teal, amber, rose
- Set `pointRadius: 0` for clean lines, show points on hover
- Interactive legend to toggle series

```js
const palette = [
  'hsl(199, 89%, 48%)',  // blue
  'hsl(142, 71%, 45%)',  // green
  'hsl(38, 92%, 50%)',   // amber
  'hsl(326, 80%, 55%)',  // pink
  'hsl(262, 83%, 58%)',  // purple
];
```

## Stacked Area Chart

Cost breakdown, token usage by model.

```js
{
  type: 'line',
  data: {
    datasets: series.map((s, i) => ({
      label: s.name,
      data: s.values,
      fill: true,
      borderColor: palette[i],
      backgroundColor: palette[i].replace(')', ', 0.3)'),
      borderWidth: 1.5,
    }))
  },
  options: {
    scales: { y: { stacked: true } },
    plugins: { filler: { propagate: true } }
  }
}
```

## Bar Chart

Latency distribution, model comparison, status code breakdown.

```js
{
  type: 'bar',
  data: {
    labels: categories,
    datasets: [{
      data: values,
      backgroundColor: values.map(v =>
        v > threshold ? 'hsl(0, 84%, 60%)' : 'hsl(199, 89%, 48%)'
      ),
      borderRadius: 4,
      maxBarThickness: 40,
    }]
  },
  options: {
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: { display: false } },
      y: { grid: { color: 'hsla(0, 0%, 100%, 0.05)' } }
    }
  }
}
```

## Donut/Pie Chart

Distribution of requests by provider, model usage share.

```js
{
  type: 'doughnut',
  data: {
    labels: categories,
    datasets: [{
      data: values,
      backgroundColor: palette,
      borderColor: 'hsl(222, 47%, 11%)',
      borderWidth: 2,
      hoverOffset: 4,
    }]
  },
  options: {
    cutout: '65%',
    plugins: {
      legend: {
        position: 'right',
        labels: { color: 'hsl(215, 20%, 65%)', padding: 16 }
      }
    }
  }
}
```

## Sparkline (Mini Charts)

Inline trend indicators in stat cards or table cells.

```js
{
  type: 'line',
  data: { labels: Array(points.length), datasets: [{
    data: points,
    borderColor: trend > 0 ? 'hsl(142, 71%, 45%)' : 'hsl(0, 84%, 60%)',
    borderWidth: 1.5,
    pointRadius: 0,
    tension: 0.4,
  }]},
  options: {
    responsive: true,
    maintainAspectRatio: false,
    plugins: { legend: { display: false }, tooltip: { enabled: false } },
    scales: { x: { display: false }, y: { display: false } },
  }
}
```

Place in a small container: `<canvas class="h-8 w-24"></canvas>`

## Heatmap (via matrix plugin or custom)

Activity by hour/day, error hotspots.

- Use color gradient from `--bg-tertiary` (low) to `--accent` (high)
- Round cells with small gap
- Tooltip shows exact value

## Common Patterns

### Time Range Selector

Standard ranges: 1h, 6h, 24h, 7d, 30d, 90d. Store in URL params for shareability.

### Auto-Refresh

Poll data every 5-30s depending on range. Shorter ranges = more frequent polling. Update charts without full redraw using `chart.data = newData; chart.update('none')` for smooth transitions.

### Empty States

When no data: show the chart container with a centered message "No data for this period" in muted text. Keep chart axes visible for context.

### Loading States

Skeleton pulse animation on chart containers while fetching. Match container dimensions to avoid layout shift.
