# Design: Colors and Layout (MyRewards MVP)

This document defines the **color palette** and **layout rules** for the MyRewards MVP. It aligns with the static prototype in `docs/design/prototype/` and is the single source of truth for implementation with Tailwind CSS (no daisyUI).

---

## 1. Color palette

### Rationale

- **Primary (green):** Evokes growth, rewards, and trust—fitting for loyalty and “you’re getting closer to your reward.”
- **Neutrals:** Light background and soft borders for readability and a clean, mobile-first UI.
- **Semantic colors:** Success (reward ready), warning (almost there), error (validation), info (hints).

All values are given in hex for implementation. Use Tailwind arbitrary values or CSS variables in `app.css` so classes stay consistent.

### 1.1 Primary (brand and main actions)

| Role            | Hex       | Usage |
|-----------------|-----------|--------|
| Primary         | `#1b4d3e` | Main CTAs, links, progress fill, logo. |
| Primary hover   | `#2d6a4f` | Hover for buttons and links. |
| Primary light   | `#40916c` | Light accents, “reward” text, optional backgrounds. |

### 1.2 Neutrals (backgrounds, text, borders)

| Role            | Hex       | Usage |
|-----------------|-----------|--------|
| Background      | `#f5f6f7` | Page/screen background. |
| Surface         | `#ffffff`  | Cards, inputs, modals. |
| Border          | `#e2e5e8`  | Card/input borders, dividers. |
| Border subtle   | `#eef0f2`  | Very light separators. |
| Text            | `#1a1d21`  | Headings and body. |
| Text muted      | `#6b7280`  | Secondary text, hints, empty states. |

### 1.3 Semantic

| Role      | Hex       | Usage |
|-----------|-----------|--------|
| Success   | `#0d9488` | “Reward ready”, completed state, success messages. |
| Warning   | `#d97706` | “Almost there” (e.g. 1 stamp left), attention. |
| Error     | `#dc2626` | Validation errors, destructive actions. |
| Info      | `#0284c7`  | Informational messages, optional hints. |

### 1.4 Progress bar

- **Track:** same as Border subtle `#eef0f2`.
- **Fill:** Primary `#1b4d3e` (same as main CTA).

---

## 2. CSS variables (recommended)

Define in `assets/css/app.css` so Tailwind and custom CSS share the same tokens:

```css
@theme {
  /* Primary */
  --color-primary: #1b4d3e;
  --color-primary-hover: #2d6a4f;
  --color-primary-light: #40916c;

  /* Neutrals */
  --color-bg: #f5f6f7;
  --color-surface: #ffffff;
  --color-border: #e2e5e8;
  --color-border-subtle: #eef0f2;
  --color-text: #1a1d21;
  --color-text-muted: #6b7280;

  /* Semantic */
  --color-success: #0d9488;
  --color-warning: #d97706;
  --color-error: #dc2626;
  --color-info: #0284c7;
}
```

Tailwind v4 can use `@theme` to expose these as utilities (e.g. `bg-primary`, `text-primary`). If you prefer not to extend the theme, use arbitrary values like `bg-[#1b4d3e]` and keep this doc as reference.

---

## 3. Layout rules

### 3.1 Mobile-first

- **Base:** 320px–375px (single column, full-width content).
- **Breakpoints:** `sm: 640px`, `md: 768px`, `lg: 1024px`.
- Design and build for small screens first; then add `min-width` media for larger viewports.

### 3.2 Containers and spacing

- **Page padding:** `px-4` (16px) on mobile; `sm:px-6`, `lg:px-8` on larger screens.
- **Vertical rhythm:** Sections separated by `space-y-6` or `gap-6`; blocks inside sections by `space-y-4` or `gap-4`.
- **Max width (optional):** For readability on desktop, main content can use `max-w-xl` or `max-w-2xl` and `mx-auto`.

### 3.3 Cards (loyalty cards, panels)

- Background: Surface (`#ffffff`).
- Border: 2px solid Border (`#e2e5e8`).
- Radius: 12px (`rounded-xl`).
- Padding: 16px (`p-4`).
- Shadow: subtle, e.g. `shadow-sm` or `0 2px 8px rgba(0,0,0,.06)`.

### 3.4 Buttons

- **Primary:** Background Primary, text white; hover Primary hover. Full width on mobile; optional `max-w-xs mx-auto` or fixed width on larger screens.
- **Secondary/outline:** Transparent background, Border color border, Primary text; hover light Primary tint (e.g. `rgba(27,77,62,.08)`).
- Padding: ~14px vertical, 20px horizontal; font-weight 600; border-radius 8px (`rounded-lg`).

### 3.5 Forms

- Inputs: full width, padding ~14px, border 2px Border, focus border Primary.
- Labels: above field, font-weight 500, margin below label ~6px.
- Error state: border Error, optional error text in Error color.

### 3.6 Typography

- Font stack: `system-ui, -apple-system, sans-serif`.
- **H1:** 1.5rem (24px), font-bold; **H2:** 1.25rem (20px), font-semibold.
- Body: 1rem (16px), line-height 1.5; secondary text in Text muted.

---

## 4. Summary table (quick reference)

| Token        | Hex       | Tailwind-style usage      |
|-------------|-----------|----------------------------|
| Primary     | `#1b4d3e` | Buttons, links, progress   |
| Primary hover | `#2d6a4f` | Hover states            |
| Primary light | `#40916c` | Reward label, accents   |
| Background  | `#f5f6f7` | Page bg                   |
| Surface     | `#ffffff`  | Cards, inputs             |
| Border      | `#e2e5e8`  | Cards, inputs, dividers   |
| Text        | `#1a1d21`  | Main text                 |
| Text muted  | `#6b7280`  | Secondary text            |
| Success     | `#0d9488`  | Reward ready, success      |
| Warning     | `#d97706`  | Almost there              |
| Error       | `#dc2626`  | Errors, destructive        |

---

## 5. Reference

- **Prototype:** `docs/design/prototype/` (HTML + `css/prototype.css`).
- **System design:** `docs/SYSTEM_DESIGN.md` (screens and flows).
- **Implementation:** Tailwind CSS in `assets/css/app.css`; no daisyUI. Use `<.input>` and core components from `core_components.ex`; style with Tailwind and the palette above.
