# Frappe — Desk Landing, `/desk` Rendering & Launcher (Framework Reference)

## About this document

A framework-level reference explaining **how a Frappe user ends up where they do after login and
what the `/desk` page shows them** — the login redirect chain, the `/desk` render pipeline, the
Desktop Icon launcher, workspaces, per-user Desktop Layouts, and desk access — plus the
**supported levers an app can use to shape that experience** (§9 Recipes).

- **Scope:** Frappe framework only. No product/app-specific configuration or code.
- **Audience:** developers and administrators customising desk navigation, landing pages, or the
  launcher for a role/persona; and anyone debugging "why did this user land here / see these icons".
- **Answers questions like:** Why did a user land on `/desk` instead of a workspace? Why does
  `redirect-to` override the configured home page? Why don't blocked modules hide launcher icons?
  Where is the one place to intercept a bare `/desk` hit? What's the difference between
  `default_workspace`, `Role.home_page`, `default_app`, and `desk_access`?
- **How to read it:** §1–§8 describe the mechanisms and their source of truth; §9 is a task-oriented
  "how do I…" recipe list; §10 maps the client- and server-side symbols involved.
- **Conventions:** file paths are relative to the `frappe` app. Line numbers are indicative and
  drift across versions — grep the named symbol instead.

---

## Index

1. [Concepts at a glance](#1-concepts-at-a-glance)
2. [`/desk` render pipeline](#2-desk-render-pipeline)
3. [Post-login landing & redirect resolution](#3-post-login-landing--redirect-resolution)
4. [The `/desk` launcher — Desktop Icons](#4-the-desk-launcher--desktop-icons)
5. [Desktop Layout (per-user customisation)](#5-desktop-layout-per-user-customisation)
6. [Workspaces & Module Profile](#6-workspaces--module-profile)
7. [Desk Access (`Role.desk_access`)](#7-desk-access-roledesk_access)
8. [Caching model](#8-caching-model)
9. [Recipes — shaping the desk from an app](#9-recipes--shaping-the-desk-from-an-app)
10. [Client-side code reference](#10-client-side-code-reference)

---

## 1. Concepts at a glance

| Concept | Owned by | Controls | Honours blocked modules? | Honours roles? |
|---|---|---|---|---|
| **Login redirect** | `www/login.py`, `auth.py`, `login.js` | where you land after login | — | via `home_page` / `default_workspace` |
| **Desktop Icons** (`/desk` grid) | `Desktop Icon` doctype | launcher tiles | **No** | Yes (`has_permission`) |
| **Desktop Layout** | `Desktop Layout` doctype | per-user launcher arrangement | No | — |
| **Workspaces** (sidebar) | `Workspace` doctype | left sidebar + `/desk/<ws>` | **Yes** (`get_workspaces`) | Yes |
| **Module Profile** | `User.block_modules` | workspace sidebar + awesomebar/nav | is the source | — |
| **Desk Access** | `Role.desk_access` | System User vs Website User | — | is the source |

Key non-obvious fact: **blocked modules (Module Profile) only trim the workspace sidebar, not the
Desktop Icon launcher.** The launcher is permission-driven (§4). And **`User.default_workspace`
is read only by `get_home_page()`** (login/website), **not** by the in-desk workspace router.

---

## 2. `/desk` render pipeline

### Server (per request)
1. Route: `hooks.py` `website_route_rules` maps `/desk/<path:app_path>` → the `desk` www page;
   `/app`, `/apps`, `/app/*` redirect to `/desk`.
2. Controller: **`www/desk.py` `get_context`** — the SPA shell.
   - Guest → redirect to `/login?redirect-to=<path>`; Website User → `PermissionError`.
   - `boot = frappe.sessions.get()` assembles bootinfo (§8), embedded in the page.
3. Template: **`www/desk.html`** injects `frappe.boot = {{ boot }}` and loads `app_include_js`
   (`desk.bundle.js`, plus any app bundles).

### Client (SPA boot)
4. **`public/js/frappe/desk.js`** `frappe.Desk`:
   - `load_bootinfo()` → `setup_workspaces()` builds `frappe.workspaces` from
     `frappe.boot.workspaces.pages`; sets `frappe.boot.allowed_workspaces`.
   - `frappe.router.setup()` → `set_route()` → `frappe.router.route()`.
5. **`public/js/frappe/router.js`** `render()`:
   - Non-empty route → `render_page()` → view factory / Page (a workspace → `Workspaces` view).
   - **Empty route (bare `/desk`)** → `frappe.views.pageview.show("")` → the **Desktop launcher
     Page** (`desk/page/desktop/`).
6. Launcher render: **`desk/page/desktop/desktop.js`** `prepare()` reads
   `frappe.boot.desktop_icons`, drops `hidden == 1` icons (moved to the edit-mode tray), nests
   children under parents, renders the grid via `desktop.html`.

### Workspace route (`/desk/<ws>`)
`router.js convert_to_standard_route` maps `/desk/<ws>` → `["Workspaces", <ws>]`;
`views/workspace/workspace.js get_page_to_show` picks the page (URL segment, else
`localStorage.current_page`, else `workspaces[0]` by `sequence_id`). It **does not read
`User.default_workspace`.**

---

## 3. Post-login landing & redirect resolution

### The two redirect paths
- **Already-authenticated user hits `/login`** → `www/login.py` `get_context`:
  `redirect_to = <redirect-to param> or get_default_path() or get_home_page()` (Website) /
  `or "/desk"` (System).
- **Form POST login** → `auth.py` `set_user_info`:
  - System User → `response.home_page = get_home_page() or "/desk"`.
  - Website User → `response.home_page = get_default_path() or "/" + get_home_page()`.
  - Client **`templates/includes/login/login.js`** (200 handler):
    `window.location.href = sanitise_redirect(get_url_arg("redirect-to")) || data.home_page;`
    → **the `redirect-to` URL param wins over `home_page`.**

### `get_home_page()` — `website/utils.py`
Order for a signed-in user: **Role `home_page`** (first role with one) → Portal default → hooks
(`get_website_user_home_page` / `role_home_page` / `home_page`) → Website Settings home →
`"me"`→`"desk"` for System Users → finally **`User.default_workspace`** overrides all if set.
Redis-cached (`home_page` hash); recomputed live only when `frappe._dev_server` is truthy.

### `get_default_path()` — `apps.py`
Drives the `/apps` screen and the authenticated-`/login` path: honours `User.default_app` /
System Settings `default_app`, else single-app route, else `/desk` or `/apps`. **Does not affect
the System-User POST-login redirect** (that uses `get_home_page`).

### Lever summary (System Users)
| Lever | Effect |
|---|---|
| `User.default_workspace` | overrides `get_home_page` → workspace URL; **not** read by the desk router |
| `Role.home_page` | first lever inside `get_home_page` |
| `role_home_page` hook | fallback inside `get_home_page` when no Role has a home page |
| `default_app` (User / System Settings) | `/apps` + authenticated-`/login` only |
| explicit `redirect-to=<path>` | **beats all of the above** (client `login.js`) |

---

## 4. The `/desk` launcher — Desktop Icons

### Source
- Doctype/logic: **`desk/doctype/desktop_icon/desktop_icon.py`**.
- Built into boot: `boot.py` `bootinfo.desktop_icons = get_desktop_icons(bootinfo=bootinfo)`.

### `get_desktop_icons(user, bootinfo)` permission model
Per icon, by `icon_type`:
- **Folder** → **always shown** (no check).
- **App** → `check_app_permission(label, app)` (each app's `add_to_apps_screen.has_permission`).
- **Link** (workspace sidebar link) → permitted if `bootinfo.workspace_sidebar_item[label]` has a
  non-Section-Break item, i.e. `Workspace Sidebar.is_item_allowed(...)` (`desk/desk_views.py`) →
  doctype/report items resolve to **`frappe.has_permission(...)`** (role-driven); `workspace`
  items to membership in `allowed_workspaces`.
- Optional per-icon **`Has Role`** child table further restricts a permitted icon.
- A child icon is kept only if its parent icon is also permitted.

Consequence: the launcher reflects **what a user can access (roles)** — it **ignores blocked
modules**. Broad roles (e.g. `System Manager`) reveal nearly everything; Folder icons show
regardless of roles. To identify a specific app's icons, match `app == "<app>"` or
`link_to ∈ <app's workspaces>` — **not the label** (users can rename icons).

### `workspace_sidebar_item`
`boot.py` `get_sidebar_items(allowed_pages)` → keyed by sidebar (module) name; a sidebar is
included when at least one item passes `is_item_allowed`. It aggregates **all** module sidebars,
so its keys are not limited to the user's allowed workspaces.

---

## 5. Desktop Layout (per-user customisation)

- Doctype: **`desk/doctype/desktop_layout/`** — one per user (`autoname: field:user`), a single
  `layout` (Code/JSON).
- API: `desktop_layout.py` `save_layout(user, layout, new_icons)` (writes the **session** user's
  layout) and `delete_layout()`.
- UI: **Edit Layout** on `/desk` (drag / hide / **+ Workspace**) → Save; **Reset Desktop Layout**
  (avatar menu) → `delete_layout()`.
- Precedence: with **no** `Desktop Layout`, the launcher uses `frappe.boot.desktop_icons`
  (`desktop.js sync_layout` else-branch); with one, it uses the saved layout. A user's manual
  arrangement wins over the boot default. Icons removed from the boot payload upstream cannot be
  re-added via Edit Layout (only `hidden` icons already in the layout appear in the tray).

---

## 6. Workspaces & Module Profile

- **`get_workspaces()`** (`desk/desktop.py`) builds the sidebar pages, filtered by:
  `Workspace.module ∉ User.get_blocked_modules()`, `restrict_to_domain`, `is_hidden`, and
  `Workspace.roles` (Has Role) via `is_permitted()`. The `Workspace Manager` role bypasses the
  filter (shows everything).
- **Module Profile** (`User.block_modules`, populated from a `Module Profile`) removes a module's
  workspace **and** its doctypes from awesomebar/nav — but **not** the Desktop Icon launcher (§4).
- Ordering: `sequence_id asc` (NULLs first). `workspaces[0]` is the fallback landing for the
  Workspaces view.

---

## 7. Desk Access (`Role.desk_access`)

- **`Role.desk_access`** (Check) determines a user's **`user_type`**: `User.has_desk_access()` is
  true if **any** role has `desk_access = 1` → `set_system_user()` sets
  `user_type = "System User"` else `"Website User"` (`core/doctype/user/user.py`). Toggling it
  re-evaluates all users with that role (`role.py update_user_type_on_change`).
- **Website User** effect: blocked from the desk — `www/desk.py` throws `PermissionError`; login
  routes them to the **website/portal** home page (`auth.py` "No App" branch); `has_desk_access()`
  also gates whitelisted calls/uploads (`handler.py`).
- **Not a declutter lever.** Turning it off removes the desk entirely (forms, lists, workspaces,
  reports). Use it only to convert a user to a portal-only (Website) user.

---

## 8. Caching model

All server-side, per user (Redis); browser reloads do not clear them — a **re-login or
`bench clear-cache`** is required after changing roles / settings.

| Cache key | Holds | Cleared by |
|---|---|---|
| `bootinfo` hash | full boot payload incl. `desktop_icons`, `workspaces` | `clear_cache(user)`, `clear_desktop_icons_cache` |
| `home_page` hash | `get_home_page()` result | `clear_cache(user)`; recomputed live only when `_dev_server` |
| `desktop_icons` hash | `get_desktop_icons` result | `clear_desktop_icons_cache` (Desktop Icon `on_update`) |

`extend_bootinfo` hooks run in `sessions.py` **after** `get_bootinfo()` — so a boot-time hook sees
a fully-populated `bootinfo.desktop_icons` / `bootinfo.workspaces`.

---

## 9. Recipes — shaping the desk from an app

Framework-supported techniques (no core edits) for common goals:

- **Land a role on a specific workspace after login:** set the **Role `home_page`** to
  `/desk/<workspace>`, or register a `role_home_page = {"<Role>": ["/desk/<ws>"]}` hook, or set
  `User.default_workspace`. All feed `get_home_page()`; `redirect-to` in the URL still overrides.
- **Make an app selectable as a user's default app:** `add_to_apps_screen` (with a
  `has_permission` callable) + set `default_app` on the user / System Settings. Drives `/apps` and
  the authenticated-`/login` path (not the System-User POST-login redirect).
- **Trim the workspace sidebar for a persona:** a **Module Profile** (blocked modules), and/or
  `Workspace.roles` (Has Role) / `is_hidden` / `restrict_to_domain` on the workspaces.
- **Trim the Desktop Icon launcher (presentation-only, keeps access/search):** an
  **`extend_bootinfo`** hook that filters `bootinfo.desktop_icons` (match icons by `app` /
  `link_to`, never label); or set `hidden = 1` on standard Desktop Icons; or seed a per-user
  `Desktop Layout`. Blocked modules do **not** affect the launcher.
- **Forward a bare `/desk` hit to a workspace (covers `redirect-to=/desk`):** there is **no**
  declarative hook — `/desk` is a core www page and `redirect-to` is consumed client-side. The
  only clean choke point is wrapping `www/desk.py get_context` (a monkey-patch): when
  `request.path == "/desk"`, `frappe.redirect()` to the user's `get_home_page()` (guard against a
  `/desk` loop). Exempt Administrator / privileged roles.
- **Convert a user to portal-only (no desk):** ensure none of their roles has `Role.desk_access`.

Exemptions to respect in any of the above: **Administrator** and typically **System Manager**
should keep the full, role-based desk.

---

## 10. Client-side code reference

| File | Symbol | Role |
|---|---|---|
| `templates/includes/login/login.js` | `login_handlers[200]` | post-login redirect; `redirect-to` param beats `home_page` |
| `www/desk.html` | `frappe.boot = {{ boot }}` | embeds boot into the SPA shell |
| `public/js/frappe/desk.js` | `Desk.load_bootinfo` / `setup_workspaces` | boots the SPA, builds `frappe.workspaces` |
| `public/js/frappe/router.js` | `render` / `convert_to_standard_route` | empty route → launcher, `/desk/<ws>` → Workspaces |
| `desk/page/desktop/desktop.js` | `prepare` | filters `hidden` icons, renders the grid |
| `public/js/frappe/views/workspace/workspace.js` | `get_page_to_show` | picks the workspace to show (ignores `default_workspace`) |

## Server-side symbol reference

| File | Symbol |
|---|---|
| `www/desk.py` | `get_context` (SPA shell + boot) |
| `www/login.py` | `get_context`, `sanitize_redirect` |
| `auth.py` | `LoginManager.set_user_info` |
| `website/utils.py` | `get_home_page`, `get_home_page_via_hooks` |
| `apps.py` | `get_default_path`, `get_apps`, `get_route` |
| `boot.py` | `get_bootinfo`, `load_desktop_data`, `get_sidebar_items`, `add_home_page` |
| `desk/desktop.py` | `get_workspaces` |
| `desk/desk_views.py` | `is_item_allowed` |
| `desk/doctype/desktop_icon/desktop_icon.py` | `get_desktop_icons`, `check_app_permission`, `clear_desktop_icons_cache` |
| `desk/doctype/desktop_layout/desktop_layout.py` | `save_layout`, `delete_layout` |
| `core/doctype/user/user.py` | `has_desk_access`, `set_system_user`, `get_blocked_modules` |
| `core/doctype/role/role.py` | `desk_access`, `update_user_type_on_change` |
