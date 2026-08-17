# Building a Custom Desk Theme in Frappe / ERPNext (v16)

A complete, battle-tested guide to shipping a branded Desk theme as a standalone
Frappe app — covering the theming architecture, the CSS variable contract, the
exact component classes to override, the client-side theme switcher, making a
theme the default, the build/cache workflow, and the gotchas that cost hours.

> Written against **Frappe v16**. Class names and tokens differ from v13/v14 —
> always `grep` your own `apps/frappe/frappe/public/scss` before copying.

---

## Index

1. [How Frappe theming works](#1-how-frappe-theming-works)
2. [The CSS variable contract](#2-the-css-variable-contract)
3. [App folder structure](#3-app-folder-structure)
4. [hooks.py wiring](#4-hookspy-wiring)
5. [The SCSS bundle](#5-the-scss-bundle)
6. [Variables to override (the semantic layer)](#6-variables-to-override-the-semantic-layer)
7. [Component classes to override](#7-component-classes-to-override)
8. [Client-side theme switcher](#8-client-side-theme-switcher)
9. [Persisting the choice: `switch_theme` override](#9-persisting-the-choice-switch_theme-override)
10. [Making your theme the default (patch)](#10-making-your-theme-the-default-patch)
11. [Build & cache workflow](#11-build--cache-workflow)
12. [Gotchas & lessons learned](#12-gotchas--lessons-learned)
13. [Reference: core files used for theming](#13-reference-core-files-used-for-theming)

---

## 1. How Frappe theming works

A Desk theme is **not** a stylesheet swap. It is a set of CSS custom properties
(variables) that are activated by an attribute on `<html>`:

```html
<!-- frappe/www/desk.html -->
<html data-theme-mode="{{ desk_theme.lower() }}" data-theme="{{ desk_theme.lower() }}">
```

- **Boot** — `frappe/sessions.py` reads `User.desk_theme` (default `"Light"`) into
  `bootinfo["desk_theme"]`; `desk.html` renders it (lower-cased) into the two
  attributes.
- **Two attributes**:
  - `data-theme-mode` — the *stored* choice (`light`, `dark`, `automatic`, or your custom name).
  - `data-theme` — the *effective* theme the CSS keys on. For `automatic` this
    resolves to `light`/`dark` via the OS media query.
- **Runtime switching** — `frappe/public/js/frappe/desk.js` installs a
  `MutationObserver` on `data-theme-mode`; whenever it changes, it calls
  `frappe.ui.set_theme()`, which writes `data-theme`. Core light/dark "just work"
  because of this observer.

**Therefore a new theme = a new `[data-theme="yourname"]` block that re-maps the
same CSS variables**, plus a switcher entry, plus persistence. That is the entire
model. (This is why the working reference themes are tiny and the broken ones
invented their own variables that nothing reads.)

```
User picks "Custom"  ─►  toggle_theme("custom")
                         ├─ data-theme-mode = "custom"   ─► MutationObserver ─► set_theme() ─► data-theme = "custom"
                         └─ xcall switch_theme("Custom")  ─► User.desk_theme = "Custom" (persisted)
Next login ─► sessions.py ─► desk.html renders data-theme="custom" ─► your CSS applies
```

---

## 2. The CSS variable contract

Core declares ~100 semantic variables under `:root, [data-theme="light"]` and
**re-declares the same names** under `[data-theme="dark"]`. Because `:root`
always matches, every light default is globally present; a theme only needs to
override the subset it wants.

Three layers exist in v16 — know which one a component reads:

| Layer | Examples | Defined in |
|---|---|---|
| **Primitive palette** | `--gray-50…900`, `--blue-500`, `--red-100` | `espresso/_colors.scss` |
| **v16 "espresso" tokens** | `--surface-menu-bar`, `--surface-white`, `--ink-gray-6`, `--sidebar-active-color` | `espresso/_colors.scss`, `desk/sidebar.scss` |
| **Classic semantic tokens** | `--bg-color`, `--fg-color`, `--control-bg`, `--highlight-color`, `--btn-primary`, `--border-color` | `common/css_variables.scss`, `desk/css_variables.scss` |

> **Critical:** many v16 components (the left sidebar rail, workspace widgets)
> read the **espresso tokens**, not the classic ones. Overriding only the classic
> tokens leaves those components unthemed. See [§12](#12-gotchas--lessons-learned).

Your job: pick a **light** variant (override the classic + espresso tokens you
care about) and, optionally, a **dark** variant (either brand-tint core dark or
leave it stock).

---

## 3. App folder structure

Themes ship as a normal Frappe app (`bench new-app my_theme`). Minimal layout:

```
my_theme/
├── my_theme/
│   ├── hooks.py                          # wiring (app_include_css/js, overrides)
│   ├── patches.txt                       # register the default-theme patch
│   ├── overrides/
│   │   └── user.py                       # switch_theme override
│   ├── patches/
│   │   └── v1_0/
│   │       └── set_default_theme.py      # option + default + adopt users
│   └── public/
│       ├── js/
│       │   ├── my_theme.bundle.js        # imports the switcher
│       │   └── theme_switcher.js         # extends frappe.ui.ThemeSwitcher
│       └── scss/
│           ├── my-theme.bundle.scss      # entrypoint (@import partials)
│           └── theme/
│               ├── my_theme_variables.scss    # [data-theme="x"] var maps
│               └── my_theme_components.scss    # class overrides
```

**Naming**: the compile entrypoint **must** end in `.bundle.scss` (esbuild only
builds those). Imported partials are just plain `.scss` — Frappe core uses
`css_variables.scss`, `dark.scss` (underscore as a *word separator*, **no**
leading `_`). Avoid the Dart-Sass `_partial.scss` leading underscore; it works
but it isn't the framework convention.

---

## 4. hooks.py wiring

```python
# Inject the compiled CSS into every Desk page
app_include_css = "my-theme.bundle.css"

# Inject the switcher JS (or import it inside your existing app bundle)
app_include_js = "my-theme.bundle.js"

# Persist the custom theme value (core switch_theme rejects unknown values)
override_whitelisted_methods = {
    "frappe.core.doctype.user.user.switch_theme": "my_theme.overrides.user.switch_theme",
}
```

`app_include_css = "my-theme.bundle.css"` resolves through `sites/assets/assets.json`
to the hashed build output. No path, no extension gymnastics — just the bundle name.

---

## 5. The SCSS bundle

**Entrypoint** — `public/scss/my-theme.bundle.scss`:

```scss
@import "theme/my_theme_variables";
@import "theme/my_theme_components";
```

**Bundle JS** — `public/js/my-theme.bundle.js`:

```js
import "./theme_switcher";
```

Everything else lives in the two partials, described next.

---

## 6. Variables to override (the semantic layer)

Put these in `theme/my_theme_variables.scss`. Override only what you need; the
rest inherits core. A **tinted surface-elevation** model (page → panel → control,
each a step darker) looks more cohesive than stark white cards:

```scss
[data-theme="mytheme"] {
    /* Brand */
    --primary:        #4c662b;   /* drives progress bars, checkboxes, btn-primary-light text */
    --primary-color:  #4c662b;   /* focus rings, theme-switcher preview check */
    --brand-color:    var(--primary);

    /* Surface elevation: page -> panel/card -> control */
    --bg-color:       #f9faef;   /* page background */
    --fg-color:       #f3f4e9;   /* cards, form-page, sticky grid cells, modals-surface */
    --card-bg:        var(--fg-color);
    --navbar-bg:      #eeefe3;
    --subtle-accent:  #eeefe3;   /* grid body, subtle fills */
    --subtle-fg:      #e8e9de;   /* list/grid HEADER row, grid-heading */
    --fg-hover-color: #e2e3d8;

    /* Inputs */
    --control-bg:           #e8e9de;   /* editable input background */
    --control-bg-on-gray:   #e2e3d8;
    --disabled-control-bg:  #e8e9de;   /* READ-ONLY / .like-disabled-input fields */
    --input-disabled-bg:    #e2e3d8;   /* disabled editable inputs */
    --awesomebar-focus-bg:  #ffffff;

    /* Interaction */
    --highlight-color:      #dce7c8;   /* list/tab/widget HOVER + selected */
    --awesomplete-hover-bg: #dce7c8;

    /* Borders */
    --border-color:       #e1e4d5;
    --dark-border-color:  #c5c8ba;
    --table-border-color: #e1e4d5;

    /* Buttons (see common/buttons.scss for how each is consumed) */
    --btn-primary:           #4c662b;  /* .btn-primary background; text = var(--neutral) */
    --btn-default-bg:        #eeefe3;  /* .btn-default background = var(--control-bg) too */
    --btn-default-hover-bg:  #dce7c8;
    --btn-ghost-hover-bg:    #e8e9de;

    /* Dialogs (kept bright as the highest elevation tier) */
    --modal-bg:   #ffffff;
    --popover-bg: #ffffff;
    --toast-bg:   var(--modal-bg);

    /* v16 sidebar tokens (desk/sidebar.scss) — NOT covered by classic tokens */
    --surface-menu-bar:    #ecefe1;   /* the left rail background */
    --sidebar-hover-color: #dde6cd;
    --sidebar-active-color:#ffffff;    /* active item pill (core adds shadow + radius) */
    --sidebar-border-color:#d7dbc7;
    --divider-color:       #d7dbc7;

    /* Custom token you invent for alt-row striping */
    --mytheme-row-alt: #eaefdc;
}
```

### What each key variable actually controls

| Variable | Controls |
|---|---|
| `--bg-color` | Page/desk background |
| `--fg-color` / `--card-bg` | Cards, `.form-page`, modals surface, sticky grid cells |
| `--control-bg` | Editable input backgrounds, `.btn-default` |
| `--disabled-control-bg` | **Read-only form fields** (`.like-disabled-input`) |
| `--highlight-color` | List-row hover/selected, tab hover, widget hover, focus fill |
| `--subtle-fg` | List/grid header rows, grid-heading background |
| `--btn-primary` | Primary button fill (text uses `--neutral`) |
| `--surface-menu-bar` | v16 left sidebar rail background |
| `--sidebar-active-color` / `--sidebar-hover-color` | Sidebar item selected / hover |
| `--border-color` | Field, card, table borders |

### Dark variant — two strategies

1. **Leave core dark stock** — ship only a light brand theme; users pick core
   "Timeless Night" for dark. Cleanest, zero maintenance. *(Recommended unless you
   need a branded dark.)*
2. **Brand-tint core dark in place** — layer a few accents onto `[data-theme="dark"]`
   so it inherits *all* of `desk/dark.scss`:
   ```scss
   [data-theme="dark"] {
       --primary: #b1d18a;
       --highlight-color: #354e16;
       --btn-primary: #b1d18a;
   }
   ```
   Do **not** duplicate `dark.scss` into a separate `[data-theme="mydark"]` — it
   will drift from core on every upgrade (checkbox/grid/chart nested rules).

---

## 7. Component classes to override

Variables cover ~80%. The rest are class-level tweaks in
`theme/my_theme_components.scss`, all scoped to `[data-theme="mytheme"] { … }`.
These are the v16 selectors and the traps behind each.

### Sidebar (v16 `.body-sidebar` rail)

```scss
/* Rail bg / hover / active are driven by the tokens in §6. Extras: */
.body-sidebar .standard-sidebar-item:not(.active-sidebar) {
    border-bottom: 1px solid var(--divider-color);      /* item dividers */
}
.body-sidebar .active-sidebar {
    .item-anchor, .sidebar-item-label {
        color: var(--primary); font-weight: 600;         /* brand label on the pill */
    }
}
/* Collapse toggle — high specificity needed (core = .body-sidebar .sidebar-toggle-btn) */
.body-sidebar .sidebar-toggle-btn.collapse-sidebar-link {
    background: var(--fg-color);
    border: 1px solid var(--dark-border-color);
    box-shadow: 0 2px 8px rgba(76, 102, 43, 0.22);
    color: var(--primary);
    .icon use { stroke: var(--primary); }
}
/* Sidebar search button uses btn-reset (no chrome) — rebuild it */
.desktop-search-wrapper .desktop-navbar-modal-search {
    width: 100%; background: var(--control-bg);
    border: 1px solid var(--border-color); border-radius: 8px; padding: 6px 10px;
    &:hover { background: var(--fg-color); border-color: var(--primary); }
}
.desktop-keyboard-shortcut {
    background: var(--fg-color); border: 1px solid var(--border-color);
    border-radius: 4px; padding: 1px 6px;
}
```

> The old `.desk-sidebar-item.standard-sidebar-item` selectors are **v13/v14**.
> v16 is `.body-sidebar … .standard-sidebar-item` / `.active-sidebar`.

### Child-table grid — alternate rows

Core paints **every data cell** `.grid-static-col { background: var(--fg-color) }`,
so recoloring only the row leaves the cells white. Every cell carries `.col`, so:

```scss
.grid-body .rows .grid-row:nth-of-type(even) {
    &, .col { background-color: var(--mytheme-row-alt); }
}
```

### List view — alternate rows + hover + tighter height

Core has **no** striping, and the sticky `.level-right` cell is painted
`--bg-color`, so it must be recolored too. Re-assert hover so it wins over the
stripe (equal specificity, declared after):

```scss
.frappe-list .result .list-row-container:nth-child(even) {
    &, .level-right { background-color: var(--mytheme-row-alt); }
}
.frappe-list .result .list-row-container:hover {
    &, .level-right { background-color: var(--highlight-color); }
}
.list-row .level-left  { padding: 2px 0; }     /* reduce row height */
.list-row .level-right { padding: 5px 10px; }
```

### Form tabs — hover + active background

Put the background on the `.nav-link` (not `.nav-item`) — the link has horizontal
margin, so a `.nav-item` background bleeds into the gaps as ugly side-blocks:

```scss
.form-tabs-list .form-tabs .nav-item .nav-link {
    margin: 0 4px; padding: 10px 12px;
    border-radius: var(--border-radius-md) var(--border-radius-md) 0 0;
    &:hover  { background-color: var(--highlight-color); }
    &.active { background-color: var(--highlight-color);
               border-bottom: 2px solid var(--primary); padding-bottom: 8px; }
}
```

### Workspace — themed panel + cards

Core hard-sets the workspace panel white via
`[data-page-route="Workspaces"] .layout-main-section { background: var(--fg-color) }`.
Theme it, and let the widgets sit on it as cards:

```scss
[data-page-route="Workspaces"] .layout-main-section {
    background-color: var(--bg-color);                   /* cream workspace body */
}
.widget.links-widget-box, .widget.shortcut-widget-box,
.widget.number-widget-box {
    background-color: var(--card-bg);                    /* themed cards */
    border: 1px solid var(--border-color);
}
.links-widget-box .link-item {
    border-radius: 0; border-bottom: 1px solid var(--dark-border-color);
    &:last-child { border-bottom: 0; }
    &:hover { background-color: var(--highlight-color); }
}
.shortcut-widget-box:hover { background-color: var(--highlight-color); }
```

### Forms — focus + read-only fields

```scss
.form-control:focus { background-color: var(--highlight-color); }
/* read-only fields are themed purely via --disabled-control-bg (see §6) */
```

### Report datatable (`.dt-scrollable`)

```scss
.dt-scrollable .dt-row {
    &:nth-of-type(even) > .dt-cell { background-color: var(--mytheme-row-alt); }
    &:hover > .dt-cell            { background-color: var(--highlight-color); }
}
```

### Buttons

Buttons are almost entirely variable-driven (`--btn-primary`, `--btn-default-bg`,
`--btn-default-hover-bg`, `--btn-ghost-hover-bg`) — no per-type rules needed. See
`common/buttons.scss` to confirm which variable each button class consumes
(`.btn-primary` bg = `--btn-primary`, text = `--neutral`).

---

## 8. Client-side theme switcher

Extend `frappe.ui.ThemeSwitcher` and override `fetch_themes()` to add your entry.
Also override `toggle_theme()` to call `set_theme()` so custom themes reflect
**live** (the core observer works, but this makes it deterministic):

```js
// public/js/theme_switcher.js
frappe.provide("frappe.ui");

frappe.ui.ThemeSwitcher = class MyThemeSwitcher extends frappe.ui.ThemeSwitcher {
    fetch_themes() {
        return new Promise((resolve) => {
            this.themes = [
                { name: "mytheme",   label: __("My Theme"),  info: __("Brand theme") },
                { name: "light",     label: __("Frappe Light"), info: __("Light Theme") },
                { name: "dark",      label: __("Timeless Night"), info: __("Dark Theme") },
                { name: "automatic", label: __("Automatic"), info: __("Follow system") },
            ];
            resolve(this.themes);
        });
    }

    toggle_theme(theme) {
        super.toggle_theme(theme);              // sets data-theme-mode + persists
        frappe.ui.set_theme(this.current_theme); // apply data-theme immediately
    }
};
```

**Casing contract**: the switcher stores `toTitle(name)` in `desk_theme`
(`"mytheme"` → `"Mytheme"`) and emits it lower-cased as `data-theme`. So your SCSS
selector is always lower-case: `[data-theme="mytheme"]`.

The switcher preview swatches in the dialog read your CSS variables automatically
(they render a scoped `data-theme=…` node) — no extra work.

---

## 9. Persisting the choice: `switch_theme` override

Core's `switch_theme` only accepts `Dark/Light/Automatic` and silently ignores
anything else, so a custom theme won't persist without this override:

```python
# my_theme/overrides/user.py
import frappe

ALLOWED_THEMES = ("Mytheme", "Light", "Dark", "Automatic")

@frappe.whitelist()
def switch_theme(theme):
    if theme in ALLOWED_THEMES:
        frappe.db.set_value("User", frappe.session.user, "desk_theme", theme)
```

Wire it via `override_whitelisted_methods` (§4).

---

## 10. Making your theme the default (patch)

`User.desk_theme` is a Select with options `Light\nDark\nAutomatic` and no
default. To add your option, make it the default for new users, and move existing
users off the implicit default — use an **idempotent patch** (a data change →
patch, not `after_install`):

```python
# my_theme/patches/v1_0/set_default_theme.py
import frappe
from frappe.custom.doctype.property_setter.property_setter import delete_property_setter

DOCTYPE, FIELDNAME, THEME = "User", "desk_theme", "Mytheme"

def execute():
    _add_option()
    _set_default()
    _adopt_users()
    frappe.clear_cache(doctype=DOCTYPE)

def _add_option():
    delete_property_setter(DOCTYPE, "options", FIELDNAME)
    existing = frappe.get_meta(DOCTYPE).get_options(FIELDNAME).split("\n")
    if THEME in existing:
        return
    frappe.make_property_setter({
        "doctype": DOCTYPE, "doctype_or_field": "DocField", "fieldname": FIELDNAME,
        "property": "options", "property_type": "Text",
        "value": "\n".join(dict.fromkeys(existing + [THEME])),
    }, ignore_validate=True)

def _set_default():
    delete_property_setter(DOCTYPE, "default", FIELDNAME)
    frappe.make_property_setter({
        "doctype": DOCTYPE, "doctype_or_field": "DocField", "fieldname": FIELDNAME,
        "property": "default", "property_type": "Text", "value": THEME,
    }, ignore_validate=True)

def _adopt_users():
    user = frappe.qb.DocType(DOCTYPE)
    (frappe.qb.update(user).set(user.desk_theme, THEME)
        .where(user.desk_theme.isnull() | user.desk_theme.isin(["", "Light"]))).run()
```

Register it:

```
# patches.txt
[post_model_sync]
my_theme.patches.v1_0.set_default_theme
```

> The `default` Property Setter covers **new** users; `_adopt_users()` moves
> existing users on the implicit default (`null`/`""`/`Light`) — it deliberately
> keeps users who explicitly chose Dark/Automatic.

---

## 11. Build & cache workflow

```bash
# 1. Compile the SCSS/JS bundles (Desk assets = bench build, NOT a Vite/SPA build)
bench build --app my_theme

# 2. Force the running web process to pick up the new asset-map hash
bench --site <site> clear-cache
bench --site <site> clear-website-cache

# 3. Apply the default-theme patch (or `bench migrate` runs it via patches.txt)
bench --site <site> execute my_theme.patches.v1_0.set_default_theme.execute

# 4. Hard-refresh the browser (Cmd/Ctrl+Shift+R)
```

- `bench build` writes hashed files (`…bundle.<HASH>.css`) and updates
  `sites/assets/assets.json`.
- **The running process caches `assets.json`** — after a rebuild, `desk.html` can
  keep referencing the *old* hash until you `clear-cache`. "No change visible" is
  almost always this, not a CSS bug.

---

## 12. Gotchas & lessons learned

1. **v16 token layer.** The sidebar rail and workspace widgets read espresso
   tokens (`--surface-menu-bar`, `--sidebar-active-color`), not classic tokens.
   Override those too or those areas stay unthemed.
2. **Grid cells overpaint the row.** `.grid-static-col { background: var(--fg-color) }`
   is on every cell — stripe the `.col`s, not just the `.grid-row`.
3. **List sticky cell.** `.level-right` is painted `--bg-color`; recolor it for
   stripes *and* hover, or the right edge won't match.
4. **Read-only fields** are `--disabled-control-bg` (default `--gray-50`), a
   *separate* variable from `--control-bg`. Remap it or read-only docs look gray.
5. **Workspace panel is force-white** via `[data-page-route="Workspaces"] .layout-main-section`.
   Override with `[data-theme] [data-page-route="Workspaces"] …` (higher specificity).
6. **Tab side-blocks.** Background belongs on `.nav-link` (has margins), never
   `.nav-item`.
7. **Toggle specificity.** The collapse toggle needs
   `.body-sidebar .sidebar-toggle-btn.collapse-sidebar-link` to beat core.
8. **`btn-reset` elements** (sidebar search) have zero chrome — you must build the
   whole control.
9. **Contrast, not selectors.** If a stripe "doesn't work," check the color delta
   first (`#eeefe3` vs `#ffffff` is invisible) before assuming the selector missed.
10. **Don't fork `dark.scss`.** Brand-tint `[data-theme="dark"]` in place; a
    duplicated dark theme drifts on every upgrade.
11. **Specificity math.** `[data-theme="x"]` adds one class-level unit (0,1,0).
    Your override generally beats core by prefixing it, but count carefully for
    deep core selectors.

---

## 13. Reference: core files used for theming

All paths relative to `apps/frappe/frappe/`.

### Variable definitions
| File | What it defines |
|---|---|
| `public/scss/common/css_variables.scss` | Base semantic tokens under `:root, [data-theme="light"]` (`--bg-color`, `--fg-color`, `--control-bg`, `--btn-*`, `--highlight-color`, `--border-color`, …) |
| `public/scss/desk/css_variables.scss` | Desk-only tokens (breakpoints, `--list-row-height`, timeline, date-picker) |
| `public/scss/desk/dark.scss` | Full `[data-theme="dark"]` re-map — the template for a complete theme |
| `public/scss/espresso/_colors.scss` | Primitive palette + v16 tokens (`--surface-*`, `--ink-*`, `--surface-menu-bar`) |

### Component styles (selectors to override)
| File | Components |
|---|---|
| `public/scss/desk/sidebar.scss` | `.body-sidebar` rail, `--sidebar-*` tokens, `.active-sidebar`, `.sidebar-toggle-btn`, hover-mixin |
| `public/scss/common/grid.scss` | Child-table grid, `.grid-row`, `.grid-static-col`, `.grid-heading-row` |
| `public/scss/desk/list.scss` | `.list-row-container`, `.list-row`, `.list-row-head`, `--list-row-height` |
| `public/scss/desk/form.scss` | `.form-tabs-list`/`.nav-link`, `.std-form-layout`/`.form-page`, form messages |
| `public/scss/common/form.scss` | `.like-disabled-input` (read-only fields → `--disabled-control-bg`) |
| `public/scss/common/buttons.scss` | `.btn-primary/.btn-default/.btn-ghost` variable consumption |
| `public/scss/desk/desktop.scss` | Workspace `.widget`, `.links-widget-box`, `.shortcut-widget-box`, `[data-page-route="Workspaces"] .layout-main-section` |
| `public/scss/desk/page.scss` | `.layout-main-section(-wrapper)`, page-head backgrounds |
| `public/scss/desk/theme_switcher.scss` | The Switch-Theme dialog grid + preview swatches |

### JS & boot flow
| File | Role |
|---|---|
| `public/js/frappe/ui/theme_switcher.js` | `frappe.ui.ThemeSwitcher` class, `fetch_themes`, `toggle_theme`, `frappe.ui.set_theme` |
| `public/js/frappe/desk.js` | `MutationObserver` on `data-theme-mode` → `set_theme()`; system dark-mode listener |
| `www/desk.html` | Renders `data-theme-mode` / `data-theme` from `desk_theme` |
| `sessions.py` | `bootinfo["desk_theme"] = User.desk_theme or "Light"` |
| `core/doctype/user/user.py` | `switch_theme()` whitelisted method (override target) |

---

*Reference implementation: the **Custom** theme app (`apps/custom`) —
`public/scss/custom-theme.bundle.scss`, `public/scss/theme/custom_variables.scss`,
`public/scss/theme/custom_components.scss`, `public/js/theme_switcher.js`,
`overrides/core/user.py`, `patches/v1_0/set_custom_desk_theme_default.py`.*
