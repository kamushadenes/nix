# Unpoly Patterns

Progressive enhancement library for server-rendered apps. Provides SPA-like navigation, polling, modals, and fragment updates — no client-side framework needed.

## SPA Navigation

```html
<!-- Links update only the main content area -->
<a href="/dashboard/analytics" up-follow up-target=".main-content">Analytics</a>

<!-- Forms submit without full reload -->
<form up-submit up-target=".result-area">
```

## Live Polling

```html
<!-- Poll every 5 seconds, update this element -->
<div id="health-grid" up-poll="5000" up-source="/api/health-fragment">
  <!-- server renders updated HTML -->
</div>
```

## Fragment Updates

Server returns partial HTML — no JSON API needed. Any backend language works: render just the fragment template and return it.

```
GET /api/health-fragment → returns raw HTML snippet
```

The server handler renders only the fragment template (not the full page layout) and writes it to the response. Unpoly swaps the matching element in the DOM.

## Layers (Modal/Drawer)

```html
<a href="/accounts/new" up-layer="new drawer" up-size="medium">
  Add Account
</a>
```

Layer types: `modal`, `drawer`, `popup`, `cover`. Server renders the content as a normal page — Unpoly extracts the target fragment and displays it in the layer.

## Inline Editing

```html
<a href="/accounts/1/edit" up-target=".account-name" up-layer="new popup">
  Edit
</a>
```

## Transitions

```html
<!-- Animate content swaps -->
<main class="main-content" up-main>
  <!-- content -->
</main>

<!-- Custom transition -->
<a href="/page" up-follow up-transition="cross-fade">Link</a>
```

## Hungry Elements

Elements with `up-hungry` update themselves whenever any navigation occurs, even if they're outside the targeted fragment.

```html
<!-- Notification count updates alongside any page navigation -->
<span id="notif-count" up-hungry>3</span>
```

## Key Concepts

- `up-follow` / `up-target`: which DOM element to replace
- `up-submit`: AJAX form submission
- `up-poll` + `up-source`: periodic refresh of a fragment
- `up-layer`: open content in modal/drawer/popup without custom JS
- `up-hungry`: auto-update elements outside the main target
- `up-transition`: animate content swaps
