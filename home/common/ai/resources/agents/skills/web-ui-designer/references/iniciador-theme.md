# Iniciador Design System

> Technology-agnostic UI/UX reference for building features on the Iniciador platform.
> Updated: 2026-04-08

---

## 1. Color System

All colors are specified in HSL format. The system uses a pure-black dark theme with no light mode.

### Core Tokens

| Token | HSL | Usage |
|-|-|-|
| `background` | `0 0% 0%` | Page background — pure black |
| `foreground` | `0 0% 93%` | Primary text |
| `card` | `0 0% 4%` | Card and panel surfaces |
| `card-foreground` | `0 0% 93%` | Text on cards |
| `popover` | `0 0% 4%` | Popover/dropdown backgrounds |
| `primary` | `234 89% 74%` | Indigo — primary actions, links, active states |
| `primary-foreground` | `0 0% 0%` | Text on primary-colored elements |
| `secondary` | `0 0% 7%` | Subtle backgrounds |
| `muted` | `0 0% 9%` | Muted backgrounds (hover, disabled areas) |
| `muted-foreground` | `0 0% 63%` | Secondary/helper text |
| `accent` | `0 0% 9%` | Accent backgrounds |
| `accent-foreground` | `0 0% 63%` | Accent text |
| `destructive` | `0 84.2% 60.2%` | Error/danger actions |
| `border` | `0 0% 12%` | Default borders |
| `border-bright` | `0 0% 17%` | Emphasized borders |
| `input` | `0 0% 12%` | Input field borders |
| `ring` | `234 89% 74%` | Focus ring (matches primary) |
| `radius` | `0.5rem` (8px) | Base border-radius |

### Brand Palette

| Token | HSL | Purpose |
|-|-|-|
| `ini-bg` | `0 0% 0%` | Base black |
| `ini-bg1` | `0 0% 4%` | Surface 1 — cards, sidebar |
| `ini-bg2` | `0 0% 7%` | Surface 2 — secondary panels |
| `ini-bg3` | `0 0% 9%` | Surface 3 — muted fills |
| `ini-text` | `0 0% 93%` | Primary text |
| `ini-text2` | `0 0% 63%` | Secondary text |
| `ini-text3` | `0 0% 40%` | Tertiary text — metadata, icons |
| `ini-text4` | `0 0% 27%` | Quaternary text — faintest |
| `ini-primary` | `234 89% 74%` | Indigo — brand primary |
| `ini-primary-v` | `229 95% 82%` | Lighter indigo variant |
| `ini-secondary` | `160 64% 55%` | Emerald green — success, completed |
| `ini-tertiary` | `292 91% 83%` | Fuchsia — accents |
| `ini-cyan` | `188 94% 69%` | Cyan — informational |
| `ini-warm` | `0 94% 82%` | Warm red — alerts, highlights |

### Sidebar Tokens

| Token | HSL |
|-|-|
| `sidebar-background` | `0 0% 4%` |
| `sidebar-foreground` | `0 0% 93%` |
| `sidebar-primary` | `234 89% 74%` |
| `sidebar-accent` | `0 0% 9%` |
| `sidebar-border` | `0 0% 12%` |

### Team Colors

Each team is assigned a unique color from a 16-color HSL palette, stored per-session. Apply via inline styles using the HSL value with full opacity for text and 8% opacity for background tinting:

- Text: `hsl({teamHSL})`
- Background: `hsl({teamHSL} / 0.08)`

### Color Application Rules

- **Primary actions**: `primary` for backgrounds, `primary-foreground` for text on top
- **Destructive actions**: `destructive` at 10% opacity as background, full opacity for text/icons
- **Hover states**: Use `muted` at 30-50% opacity
- **Active nav items**: `primary` at 10% opacity background, `primary` for text
- **Focus rings**: 2px `ring` color with 2px offset
- **Selection highlight**: `ini-primary` at 25% opacity

---

## 2. Typography

### Font Families

| Type | Family | Fallback Stack |
|-|-|-|
| Sans-serif (default) | **Geist** | -apple-system, BlinkMacSystemFont, sans-serif |
| Monospace | **Geist Mono** | SF Mono, Fira Code, monospace |

Anti-aliasing: subpixel (webkit + moz).

### Dashboard Type Scale

| Element | Size | Weight | Tracking | Notes |
|-|-|-|-|-|
| Page title (sticky header) | 14px | 600 (semibold) | tight (-0.01em) | Single line |
| Section heading | 18px | 600 | default | Tab content titles |
| Card title | 16px | 600 | default | Position card headers |
| Body text | 14px | 400 | default | General content |
| Helper / metadata | 12px | 400 | default | Timestamps, emails |
| Micro labels | 10-11px | 500-600 | default | Badges, stage labels |
| Brand wordmark | 12px mono | 600 | tight | Sidebar logo text |
| Table cells | 12px | 400 | default | Candidate tables |
| User name (sidebar) | 11px | 500 | default | Bottom of sidebar |
| Role badge (sidebar) | 8px | 500 | default | Uppercase |

### Careers Page Type Scale

| Element | Size | Weight | Tracking | Line-height |
|-|-|-|-|-|
| Hero H1 | clamp(36px, 7vw, 72px) | 600 | -0.04em | 1.02 |
| Hero subtitle | 18-20px | 400 | default | 1.5 |
| Section label | 12px mono | 400 | 0.06em | default |
| Section numbers | 14px mono | 400 | default | In team color |
| Bullet character | `>` | - | - | In team color |

---

## 3. Iconography

### Icon Set

Icons come from the **Lucide** icon family — a consistent, stroke-based set.

### Sizing Convention

| Context | Size (px) |
|-|-|
| Default inline icons | 16 x 16 |
| Small inline (badges, tabs) | 14 x 14 |
| Micro (inside tiny badges) | 10 x 10 |
| Sidebar toggle | 28 x 28 |
| Hero/feature icons | 20 x 20 |

### Icon Vocabulary

| Icon | Usage |
|-|-|
| Building2 | City/location |
| MapPin | Remote/location detail |
| Briefcase | Position/job |
| Users | Team/candidates |
| ChevronDown/Up/Right | Expand/collapse/navigate |
| X | Close/dismiss |
| Plus | Add/create |
| Search | Search input |
| Star | Score rating |
| FileText | Overview/document |
| MessageSquare | Notes/comments |
| Calendar | Dates/scheduling |
| ExternalLink | Open in new tab |
| Mail | Email contact |
| Phone | WhatsApp/phone |
| Github | GitHub profile |
| Linkedin | LinkedIn profile |
| LayoutDashboard | Dashboard navigation |
| PanelLeftClose / PanelLeft | Sidebar toggle |
| LogOut | Sign out |
| Check | Confirm/complete |
| AlertTriangle | Warning state |
| Trash2 | Delete action |
| Copy | Copy to clipboard |
| Send | Submit/send |
| UserPlus | Invite user |
| Shield | Admin/security |
| Eye / EyeOff | Show/hide |
| GripVertical | Drag handle |
| ArrowRight | Proceed/next stage |
| Globe | Language toggle |
| User | Referral/person |
| Slack | Slack integration |

---

## 4. Layout

### Dashboard Shell

```
+----------+-----------------------------------+
| Sidebar  |  Sticky header (56px h)           |
| 208px    |-----------------------------------|
| (or 52px |  Content area                     |
| collapsed|  horizontal padding: 24px         |
|          |  vertical padding: 24px           |
|          |  max-width: 64rem (1024px)        |
|          |                                    |
| -------- |                                    |
| User info|                                    |
| Sign out |                                    |
+----------+-----------------------------------+
```

- **Sidebar**: Sticky, full viewport height, `ini-bg1` background, right border
- **Header**: Sticky, blurred background at 95% opacity, bottom border, 56px tall
- **Content**: Scrollable, padded 24px, max-width 1024px for most tabs

### Careers Page Layout

- Max content width: **1200px**, centered
- Horizontal padding: `clamp(20px, 4vw, 48px)`
- Section vertical padding: 80-100px top, 80-100px bottom
- Nav: Fixed top, blurred background on scroll, z-index elevated

### Spacing Scale

| Token | Value |
|-|-|
| Micro | 4px |
| Small | 8px |
| Default | 16px |
| Medium | 24px |
| Large | 32px |
| Section | 48px |
| Hero | 80-100px |

### Breakpoints

| Name | Width |
|-|-|
| Mobile | < 640px |
| Tablet | 640-1024px |
| Desktop | > 1024px |
| Max container | 1400px |

---

## 5. Component Specifications

### 5.1 Sidebar

- **Width**: 208px expanded, 52px collapsed
- **Background**: `ini-bg1` (0 0% 4%)
- **Border**: Right, `border` color
- **Position**: Sticky, full viewport height
- **Nav items**: 13px, font-weight 500, 16x16 icons
  - Active: `primary` at 10% opacity background, `primary` text color
  - Inactive: `muted-foreground` text, hover -> `foreground` text + `muted` at 50% opacity background
- **Toggle button**: Ghost style, 28x28, uses PanelLeftClose/PanelLeft icons
- **User section** (bottom): Avatar (32px circle), name at 11px/500, role badge at 8px uppercase, team badges
- **Sign-out**: Ghost button, full width, `destructive` text on hover

### 5.2 Sticky Header

- Height: **56px**
- Background: page background at 95% opacity with backdrop blur
- Bottom border: `border` color
- Contains: Page title (14px/600/tight tracking)
- Z-index: elevated above content

### 5.3 Cards

- Background: `card` (0 0% 4%)
- Border: `border` color, `radius` corners
- Shadow: subtle (`shadow-sm`)
- Header padding: 24px
- Content padding: 24px horizontal, 0 top
- **KPI Cards**: Title in `muted-foreground` at 14px, value in 24-30px/700

### 5.4 Badges

| Variant | Style |
|-|-|
| Default | `primary` background, `primary-foreground` text |
| Outline | Transparent background, `foreground` text, 1px border |
| Secondary | `secondary` background |
| Destructive | `destructive` background |
| Team-colored | Dynamic HSL: text at full opacity, background at 8% opacity, mono font 11px |
| Micro (role) | 8px text, 14px height, outline, uppercase |
| Stage labels | 10px text, rounded-full |

### 5.5 Tables

- Container: Rounded (`radius`), `border` color border, overflow hidden
- Header: `muted` background, 12px uppercase text
- Rows: Hover at `muted` 30% opacity, pointer cursor when clickable
- Cells: 12px for metadata columns, 14px/500 for name columns
- Row height: ~48px

### 5.6 Dialogs (Modals)

- Centered overlay with dark backdrop
- Max width: ~512px (default), can vary
- Background: `card`
- Border-radius: `radius`
- Sections: Header, content body, footer with action buttons
- Close button: Top-right X icon
- Animations: Fade in + slight scale up on open, reverse on close

### 5.7 Sheets (Side Panels)

- Slide in from the right
- Width: Full on mobile, max 576px on desktop
- Background: `background`
- Used for: Candidate detail views, extended forms
- Close: X button top-right
- Content: Scrollable body, sticky header within

### 5.8 Buttons

| Variant | Background | Text | Usage |
|-|-|-|-|
| Default (primary) | `primary` | `primary-foreground` | Main actions |
| Ghost | Transparent | `foreground` | Subtle/icon buttons |
| Outline | Transparent | `foreground` | Secondary actions |
| Destructive | `destructive` | white | Delete, reject |
| Secondary | `secondary` | `secondary-foreground` | Alternatives |

**Sizes**:
- Default: 40px height, 16px horizontal padding
- Small: 36px height, 12px horizontal padding
- Icon: 40x40 (default), 28x28 (toolbar)

**States**: Disabled at 50% opacity; focus ring 2px `ring` color with 2px offset.

### 5.9 Filters Row

- Horizontal flex layout with 12px gap, wrapping
- Search input: 256px wide
- Select dropdowns: 160-176px wide
- All inputs share `border` color borders, `radius` corners

### 5.10 Tabs

- Tab list: Bottom-bordered, horizontal
- Active tab: `primary` underline/highlight
- Inactive: `muted-foreground` text
- Tab triggers: 14px text, optionally with 14px icons and 6px gap
- Content: 16px top margin from tab list

### 5.11 Score Indicator

- 5 dots in a row, 4px gap
- Filled dots: `ini-secondary` (emerald) at full opacity
- Empty dots: `ini-secondary` at 20% opacity
- Dot size: 6x6px circles
- Click/tap to set score (1-5)

### 5.12 Avatars

- Shape: Circle
- Sizes: 32px (sidebar), 40px (detail panels), 24px (inline)
- Background color: Deterministic from name — hash the name to pick a hue, apply at ~20% saturation, 30% lightness
- Text: White initials (first letter of first + last name), centered
- Font: 10-14px depending on avatar size, weight 600

### 5.13 Empty & Loading States

- **Loading**: Centered spinner or skeleton shimmer
- **Empty**: Centered text in `muted-foreground`, 14px, with optional icon above
- **Error**: Destructive-colored text or toast notification

### 5.14 Pipeline / Kanban

- Columns: One per stage, vertical layout
- Column header: Stage name (12px mono uppercase), count badge
- Cards: Draggable, `card` background, `border` border
  - Show: Name (14px/500), days-in-stage (12px/`muted-foreground`), score dots
  - Hover: `muted` at 30% opacity
  - Drag visual: Slight opacity reduction (50%), outline highlight
- Drop zone: Visual indicator on drag-over (border color change to `primary`)
- Rejected section: Collapsible, separate grid below pipeline

---

## 6. Motion & Animation

### Transitions

| Animation | Duration | Easing | Description |
|-|-|-|-|
| Fade-up | 600ms | ease (both) | Elements fade in and translate up 16px |
| Marquee | 50s | linear, infinite | Horizontal auto-scroll for client logos |
| Gradient shift | 6s | ease, infinite | Background position animation (200% size) |
| Accordion expand | 200ms | ease-out | Height from 0 -> content height |
| Accordion collapse | 200ms | ease-out | Height from content -> 0 |

### Interaction Transitions

- **Hover/focus**: 150ms default transition on color properties
- **Dialog/Sheet open**: Fade + scale/slide, ~200ms
- **Dialog/Sheet close**: Reverse of open, ~150ms
- **Page transitions**: None (instant route changes)

### Scroll-Triggered Animations

- Elements start as `opacity: 0` and animate to `opacity: 1` with `translateY(0)` when entering viewport
- Stagger: Each item in a grid adds 40-80ms delay (`0.05s + index x 0.04s`)
- Trigger: IntersectionObserver-based, fires once

---

## 7. Charts & Data Visualization

### Chart Color Palette

| Index | HSL | Name |
|-|-|-|
| 0 | `234 89% 74%` | Indigo (primary) |
| 1 | `160 64% 55%` | Emerald |
| 2 | `292 91% 73%` | Fuchsia |
| 3 | `188 94% 59%` | Cyan |
| 4 | `45 93% 58%` | Amber |

### Stage-Specific Colors

| Stage | HSL |
|-|-|
| Applied | `234 89% 74%` (indigo) |
| Screening | `188 94% 69%` (cyan) |
| First Contact | `45 93% 58%` (amber) |
| Interviewing | `292 91% 73%` (fuchsia) |
| KYE Analysis | `330 81% 60%` (pink) |
| Negotiation | `25 95% 53%` (orange) |
| Contract | `160 64% 55%` (emerald) |
| Setup | `120 40% 55%` (green) |
| Waiting to Join | `200 80% 60%` (sky) |
| Completed | `160 84% 39%` (dark emerald) |

### Chart Styling Rules

- **Axis labels**: `muted-foreground` color, 12px
- **Grid lines**: `border` color at low opacity (10-20%)
- **Tooltip**: `card` background, `border` border, `foreground` text, 8px radius
- **Bar radius**: 4px top corners
- **Pie/donut**: 2px gap between segments via stroke
- **Legend**: Below chart, `muted-foreground` text, 12px, with color dot indicators (8px circles)
- **Responsive**: Charts fill container width, minimum height 240-300px

---

## 8. Micro Details

### Scrollbar

- Width: 6px
- Track: `ini-bg` color
- Thumb: `border-bright` color, 3px radius
- Thumb hover: `ini-text4` color

### Text Selection

- Background: `ini-primary` at 25% opacity
- Text color: `ini-text`

### Toast Notifications

- Position: Top-right
- Style: `card` background, `border` border, `radius` corners
- Types: Success (default), Error (destructive styling), Info
- Auto-dismiss: ~5 seconds
- Close: X button or swipe
- Text: Title at 14px/500, description at 12px/400
- Enter: Slide in from right + fade
- Exit: Slide out right + fade

### Form Inputs

- Height: 40px
- Border: `input` color (0 0% 12%), 1px
- Border-radius: `radius` (8px)
- Background: transparent (inherits page/card bg)
- Text: `foreground`, 14px
- Placeholder: `muted-foreground`
- Focus: 2px `ring` color outline with 2px offset
- Disabled: 50% opacity, no pointer events

### Select Dropdowns

- Trigger: Same styling as inputs, with chevron-down icon
- Dropdown: `popover` background, `border` border, `radius` corners
- Items: 14px, hover at `accent` background
- Selected: Check icon prefix

### Textarea

- Same border/focus styling as inputs
- Min-height: 60px (adjustable)
- Resize: Vertical only

### Checkbox

- Size: 16x16
- Border: `primary` color
- Checked: `primary` fill, white check icon
- Radius: 4px (slightly rounded square)
- Focus: Same ring as inputs
