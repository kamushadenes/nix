# SEO Checklist

For public-facing pages (landing pages, marketing sites, blogs). Skip for internal dashboards/admin panels.

## Essential Tags

- **Title**: include main keyword, under 60 characters
- **Meta description**: max 160 characters, natural keyword integration
- **Single H1**: matches page's primary intent
- **Canonical tag**: `<link rel="canonical" href="...">` to prevent duplicate content

## Semantic HTML

Use semantic elements instead of generic divs:

```html
<header>     <!-- site header, nav -->
<nav>        <!-- navigation -->
<main>       <!-- primary content -->
<article>    <!-- self-contained content -->
<section>    <!-- thematic grouping -->
<aside>      <!-- related/sidebar content -->
<footer>     <!-- site footer -->
```

## Images

- All images must have descriptive `alt` attributes
- Use `loading="lazy"` for below-fold images
- Provide `width` and `height` to prevent layout shift

## Structured Data

Add JSON-LD in `<head>` for products, articles, FAQs, organizations:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": "Page Title",
  "description": "Page description"
}
</script>
```

## Performance

- Lazy load images and non-critical scripts
- Defer non-essential JS: `<script defer src="...">`
- Preload critical assets: `<link rel="preload" href="..." as="style">`

## URLs and Links

- Use descriptive, readable URLs (`/products/widget` not `/p?id=123`)
- Internal links should be crawlable `<a href="...">` (not JS-only navigation)
- Add `rel="noopener"` to external links with `target="_blank"`
