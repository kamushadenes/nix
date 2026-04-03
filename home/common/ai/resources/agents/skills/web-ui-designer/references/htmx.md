# HTMX Patterns

Progressive enhancement via HTML attributes. Server returns HTML fragments — no client-side framework needed.

## Core Attributes

```html
<!-- HTTP verbs as attributes -->
<button hx-get="/api/data" hx-target="#results">Load</button>
<form hx-post="/api/submit" hx-target="#response">...</form>
<button hx-delete="/api/item/1" hx-target="closest tr" hx-swap="outerHTML">Delete</button>
```

Key attributes:
- `hx-get/post/put/patch/delete` — HTTP verb + URL
- `hx-target` — CSS selector for where to swap response (default: current element)
- `hx-swap` — how to swap: `innerHTML` (default), `outerHTML`, `beforeend`, `afterbegin`, `delete`, `none`
- `hx-trigger` — what triggers the request: `click`, `submit`, `load`, `revealed`, `every 5s`, `keyup changed delay:500ms`

## SPA Navigation

```html
<a hx-get="/dashboard" hx-target="#main" hx-push-url="true">Dashboard</a>
```

`hx-push-url="true"` updates the browser URL bar for proper history/back-button support.

## Live Polling

```html
<div hx-get="/api/status" hx-trigger="every 5s" hx-swap="outerHTML">
  <!-- server renders updated HTML -->
</div>
```

## Form Submission

```html
<form hx-post="/api/contacts" hx-target="#contact-list" hx-swap="beforeend">
  <input name="name" />
  <button type="submit">Add</button>
</form>
```

## Infinite Scroll / Load More

```html
<tr hx-get="/api/items?page=2" hx-trigger="revealed" hx-swap="afterend">
  <td>Loading more...</td>
</tr>
```

## Response Headers

Servers can control HTMX behavior via response headers:
- `HX-Trigger: showMessage` — fire a client-side event
- `HX-Redirect: /new-page` — redirect the browser
- `HX-Reswap: outerHTML` — override the swap method
- `HX-Retarget: #other` — override the target element
- `HX-Push-Url: /new-url` — push a URL to history

## Confirmation Dialogs

```html
<button hx-delete="/api/item/1" hx-confirm="Are you sure?">Delete</button>
```

## CSS Transition Classes

HTMX adds `htmx-settling`, `htmx-swapping`, `htmx-added` classes during swaps — use them for CSS transitions.

## HTMX + Alpine.js

HTMX handles server communication; Alpine handles local UI state. They complement each other:
```html
<div x-data="{ open: false }">
  <button @click="open = !open">Filter</button>
  <div x-show="open" hx-get="/api/filters" hx-trigger="intersect once">
    <!-- filters loaded from server when panel opens -->
  </div>
</div>
```
