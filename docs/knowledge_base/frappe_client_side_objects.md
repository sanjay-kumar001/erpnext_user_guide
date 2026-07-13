# Frappe Client-Side Objects: Comprehensive Reference

This document provides a complete, consolidated reference for the core client-side objects in the Frappe Framework: `frappe`, `frappe.boot`, and `cur_frm`. It includes all properties, methods, and internal structures as derived from official documentation, source code analysis, and browser runtime inspection. The information is organized to serve as a definitive guide for developers working with client-side scripting, custom Desk pages, and debugging.

---

## Table of Contents

1. [Introduction](#introduction)  
2. [The `frappe` Object](#the-frappe-object)  
   - [Definition and Purpose](#definition-and-purpose)  
   - [Complete List of Properties and Methods](#complete-list-of-properties-and-methods)  
3. [The `frappe.boot` Object](#the-frappe-boot-object)  
   - [Purpose and Source](#purpose-and-source)  
   - [Complete List of Contents](#complete-list-of-contents)  
   - [How It Is Populated](#how-it-is-populated)  
4. [The `cur_frm` Object](#the-cur_frm-object)  
   - [Definition and Purpose](#definition-and-purpose-1)  
   - [Relationship to `frappe.ui.form.Form`](#relationship-to-frappeuiformform)  
   - [Complete List of Properties and Methods](#complete-list-of-properties-and-methods-1)  
   - [Form Events and Child Table Events](#form-events-and-child-table-events)  
5. [Client‑Side Rendering and Loading Process](#client-side-rendering-and-loading-process)  
   - [Step‑by‑Step Process](#step-by-step-process)  
   - [Role of Key Files](#role-of-key-files)  
   - [Form Initialization Sequence](#form-initialization-sequence)  
6. [Important Notes](#important-notes)  
7. [Conclusion](#conclusion)

---

## Introduction

Frappe is a full‑stack web framework with a client‑side single‑page application (SPA) that manages the Desk interface. The runtime environment exposes three primary global objects:

- **`frappe`** – the main namespace and API hub for all client‑side operations.
- **`frappe.boot`** – the configuration and state object injected from the server, containing user details, system settings, permissions, and more.
- **`cur_frm`** – the active form controller (an instance of `frappe.ui.form.Form`), providing access to the current document, its fields, and manipulation methods.

Understanding these objects is essential for writing efficient client scripts, debugging, building custom extensions, and tracing data flow from the server to the browser.

---

## The `frappe` Object

### Definition and Purpose

The `frappe` object is the primary global namespace for all client‑side Frappe functionality. It is initially created as an empty object in `base.html` (`window.frappe = {};`) and later extended by the framework and installed apps. It serves as the central API for:

- Routing (`frappe.set_route`, `frappe.get_route`)
- Data formatting (`frappe.format`)
- Namespace creation (`frappe.provide`)
- Asynchronous asset loading (`frappe.require`)
- Server calls (`frappe.call`)
- Document management (`frappe.get_doc`, `frappe.new_doc`)
- UI and form handling (`frappe.ui`, `frappe.ui.form`)
- Real‑time events (`frappe.realtime`)

### Complete List of Properties and Methods

> *Note: The exact contents can vary by Frappe version and installed apps. This list is compiled from official documentation and runtime inspection.*

| Method / Property | Description |
| :--- | :--- |
| **Core Utilities** | |
| `frappe.require(asset_path, callback)` | Asynchronously loads one or more JS/CSS assets; accepts a string or array. |
| `frappe.provide(namespace)` | Creates a nested namespace on the `window` object if it does not exist. |
| `frappe.get_route()` | Returns the current route as an array of strings. |
| `frappe.set_route(route)` | Navigates to the given route (can be parts, array, or a string). |
| `frappe.format(value, df, options, doc)` | Formats a raw value based on a field definition (`df`) for user display. |
| `frappe._(string)` | Translates a string into the user’s language. |
| `frappe.ready_events` | An array of functions queued to execute when the page is ready. |
| `frappe.ready(fn)` | Adds a function to the `ready_events` queue. |
| `frappe.get_meta(doctype)` | Fetches the DocType metadata (field definitions, permissions, etc.). |
| `frappe.datetime` | Namespace for date and time utilities. |
| `frappe.perm` | Namespace for permissions management. |
| `frappe.meta` | Namespace for DocType metadata (alternative to `get_meta`). |
| **Server Communication (RPC / AJAX)** | |
| `frappe.call({ method, args, callback, freeze, ... })` | Primary method for whitelisted server calls. |
| `frappe.db` | Namespace for database operations, wrapping `frappe.call`. |
| `frappe.db.get_value(doctype, filters, fieldname, callback)` | Retrieves a specific field value from a document. |
| `frappe.db.get_doc(doctype, name)` | Fetches a complete document. |
| `frappe.db.getAll({ doctype, filters, fields })` | Retrieves a list of documents matching filters. |
| `frappe.client` | Namespace with standard CRUD methods (`get_value`, `get_list`, `insert`, etc.). |
| **UI & Forms** | |
| `frappe.ui` | Primary namespace for all UI components. |
| `frappe.ui.form` | Namespace for the form system. |
| `frappe.ui.form.on(doctype, event_map)` | Attaches event handlers to forms and fields. |
| `frappe.ui.form.Form` | The class (aliased as `FrappeForm`) for a form instance. |
| `frappe.msgprint(msg, title, ...)` | Displays a modal message to the user. |
| `frappe.throw(msg, exc, title, ...)` | Raises an exception and shows a message (wrapper around `msgprint`). |
| `frappe.ui.Dialog` | Class for creating custom modal dialogs. |
| **Realtime Events** | |
| `frappe.realtime` | Namespace for WebSocket‑based realtime communication. |
| `frappe.realtime.on(event_name, callback)` | Listens for a server‑emitted realtime event. |
| `frappe.realtime.off(event_name)` | Stops listening to a realtime event. |
| `frappe.realtime.emit(event_name, ...args)` | Sends a realtime event to the server. |
| **Document Management (ORM)** | |
| `frappe.getDoc(doctype, name)` | Fetches a document from the backend. |
| `frappe.newDoc({ doctype, ... })` | Creates a new, unsaved document instance. |
| `frappe.document` | Namespace for the `Document` class (base for all documents). |
| **Routing** | |
| `frappe.router` | Namespace for client‑side routing. |
| `frappe.router.add(route, handler)` | Registers a custom route handler. |
| `frappe.router.current_page` | Maintains the currently displayed page. |
| `frappe.router.slug` | Function to generate a URL slug from a string. |
| **Boot & Configuration** | |
| `frappe.boot` | Contains all boot‑time configuration (detailed below). |
| `frappe.sys_defaults` | Alias to `frappe.boot.sysdefaults` for backward compatibility. |

---

## The `frappe.boot` Object

### Purpose and Source

`frappe.boot` is a JavaScript object that holds essential runtime information about the current site, user, system settings, and available features. It is generated server‑side by the `get_bootinfo()` function in `frappe/boot.py` and injected into the client via the `base.html` template before any other scripts run. This ensures that the entire Desk environment is configured from the start.

### Complete List of Contents

The following properties are typically present in `frappe.boot`. They are grouped by functional category.

| Category | Property | Description |
| :--- | :--- | :--- |
| **User & Session** | `user` | Object with user details: `name`, `email`, `roles`, `home_page`, `desk_theme`, `language`, etc. |
| | `user_info` | Additional user data: `time_zone`, `full_name`, `user_image`, etc. |
| | `csrf_token` | CSRF token required for secure AJAX calls. |
| **System & Site** | `sitename` | Name of the current site (e.g., `test.local`). |
| | `sysdefaults` | Global defaults: `country`, `currency`, `time_zone`, `setup_complete`, etc. |
| | `server_date` | Current server date in `YYYY-MM-DD` format. |
| | `time_zone` | Object with `system` and `user` time zone information. |
| | `lang` | User language code (e.g., `en`). |
| | `lang_dict` | Dictionary of translated strings for the user’s language. |
| | `translations_version` | Version identifier for translation files. |
| | `versions` | Mapping of app names to version numbers. |
| | `developer_mode` | Boolean indicating developer mode. |
| | `socketio_port` | Port used for Socket.IO (WebSocket) connections. |
| **Domains & Modules** | `active_domains` | List of active domain names (e.g., `['Agriculture']`). |
| | `all_domains` | List of all available domains. |
| | `modules` | Object with module details. |
| | `module_list` | List of all module names. |
| | `module_app` | Mapping from module to its parent app. |
| **DocType & Metadata** | `single_types` | List of DocTypes that are "Single" (only one record). |
| | `nested_set_doctypes` | DocTypes using the nested‑set model (tree structures). |
| | `tree_view_doctypes` | DocTypes that have a Tree view. |
| | `doctype_layouts` | Defined DocType layouts for print and email. |
| | `translated_doctypes` | DocTypes with available translations. |
| | `doctype_ptype_map` | Mapping of DocTypes to their permission types. |
| | `link_preview_doctypes` | DocTypes with link preview enabled. |
| | `link_title_doctypes` | DocTypes that show title fields in links. |
| **Desk & UI** | `workspaces` | Object with all permitted workspace links and their pages. |
| | `user_workspaces` | User’s curated workspace selection (in order). |
| | `workspace_sidebar_item` | Sidebar items for each workspace. |
| | `default_workspace_map` | Mapping of default workspaces. |
| | `module_wise_workspaces` | Workspaces organized by module. |
| | `app_data` | List of installed app objects: `app_name`, `app_title`, `app_logo_url`, `modules`, `workspaces`. |
| | `desktop_icon_urls` | URLs for desktop icons. |
| | `desktop_icon_style` | Style of desktop icons (e.g., "Subtle" or "Solid"). |
| | `navbar_settings` | Settings for the top navigation bar. |
| | `app_logo_url` | URL of the application logo. |
| | `home_folder` | Name of the home folder in the file manager. |
| | `home_page` | Name of the user’s home page. |
| | `success_action` | List of configured success actions. |
| | `desk_settings` | User‑specific desk properties (e.g., `desk_theme`). |
| **Notifications** | `notification_settings` | User’s notification preferences. |
| | `notification_unread_count` | Number of unread notifications. |
| | `email_accounts` | List of the user’s configured email accounts. |
| | `sms_gateway_enabled` | Boolean indicating if SMS gateway is enabled. |
| | `error_report_email` | Email address for error reports. |
| **Calendars & Views** | `calendars` | List of calendar doctypes (e.g., `['Event', 'Task']`). |
| | `treeviews` | List of available tree view configurations. |
| **Printing & Files** | `letter_heads` | Object with available letterheads (header/footer content). |
| | `print_css` | CSS string for print styles. |
| | `max_file_size` | Maximum allowed file upload size. |
| | `file_chunk_size` | Chunk size for file uploads. |
| **Additional** | `additional_filters_config` | Extra filter configurations from hooks. |
| | `frequently_visited_links` | List of frequently visited links for the user. |
| | `onboarding_tours` | List of available onboarding tours. |
| | `setup_wizard_requires` | Requirements for the setup wizard. |
| | `setup_wizard_completed_apps` | Apps for which the setup wizard has been completed. |
| | `docs` | Additional document objects (e.g., Country, Currency) loaded on the client. |
| | `ipinfo` | IP information for the user (if available). |
| | `is_fc_site` | Boolean indicating if the site is hosted on Frappe Cloud. |
| | `subscription_conf` | Frappe Cloud subscription configuration. |
| | `sentry_dsn` | Sentry DSN for error tracking (if telemetry enabled). |

### How It Is Populated

1. **Server‑Side Generation** – The `get_bootinfo()` function in `frappe/boot.py` gathers user details, system defaults, desktop data, permissions, app‑specific hooks (via `boot_session` hook), and assembles a dictionary.

2. **Client‑Side Injection** – In `base.html`, the dictionary is rendered as JSON and assigned to `frappe.boot`:

   ```html
   <script>
       frappe.boot = {{ boot | json }};
       // backward compatibility
       frappe.sys_defaults = frappe.boot.sysdefaults;
   </script>
   ```

This injection occurs before any other JavaScript bundles, ensuring `frappe.boot` is available globally from the start.

---

## The `cur_frm` Object

### Definition and Purpose

`cur_frm` is a global variable that holds the currently active form instance. It is an instance of `frappe.ui.form.Form` (also aliased as `FrappeForm`). In form event handlers, the same object is passed as the `frm` parameter. `cur_frm` provides full control over the document, its fields, layout, and actions.

> **Note:** While `cur_frm` is still widely used, newer versions of Frappe recommend using `frm` in event handlers for consistency. The two are identical in functionality.

### Relationship to `frappe.ui.form.Form`

The `Form` class manages:

- Document state (`cur_frm.doc`)
- DocType metadata (`cur_frm.meta`)
- Layout rendering (`cur_frm.layout`)
- Toolbar actions (`cur_frm.toolbar`)
- Script execution (`cur_frm.script`)
- Dashboard display (`cur_frm.dashboard`)

### Complete List of Properties and Methods

| Category | Property / Method | Description |
| :--- | :--- | :--- |
| **Core Properties** | `cur_frm.doc` | The current document data object (field values). |
| | `cur_frm.doctype` | Name of the current DocType. |
| | `cur_frm.docname` | Name (ID) of the current document. |
| | `cur_frm.meta` | DocType metadata (fields, permissions, etc.). |
| | `cur_frm.fields_dict` | Object mapping field names to their control objects. |
| | `cur_frm.layout` | Layout manager for sections, tabs, columns. |
| | `cur_frm.dashboard` | Dashboard component for related documents and analytics. |
| | `cur_frm.toolbar` | Toolbar manager for Save, Submit, Cancel actions. |
| | `cur_frm.script` | ScriptManager orchestrating client scripts. |
| | `cur_frm.$wrapper` | jQuery‑wrapped DOM element of the entire form. |
| | `cur_frm.custom_buttons` | Custom buttons added to the toolbar. |
| | `cur_frm.assign_to` | Assignment component. |
| | `cur_frm.attachments` | Attachments manager. |
| | `cur_frm.action_perm_type_map` | Mapping of actions to permission types. |
| | `cur_frm.active_tab_map` | Tracks active tabs. |
| | `cur_frm.beforeUnloadListener` | Event listener for page unload. |
| | `cur_frm.debounced_reload_doc` | Debounced function to reload the document. |
| **Document State** | `cur_frm.is_new()` | Returns `true` if document is unsaved (`__islocal == 1`). |
| | `cur_frm.doc.__islocal` | Property indicating new (1) or saved (0). |
| **Field Access** | `cur_frm.set_value(fieldname, value)` | Sets field value and triggers change event. |
| | `cur_frm.get_value(fieldname)` | Returns current value of a field. |
| | `cur_frm.set_df_property(fieldname, property, value)` | Dynamically changes `read_only`, `hidden`, `reqd`, etc. |
| | `cur_frm.toggle_enable(fieldname, enable)` | Enables/disables a field. |
| | `cur_frm.toggle_display(fieldname, show)` | Shows/hides a field. |
| | `cur_frm.toggle_reqd(fieldname, required)` | Makes a field required or optional. |
| | `cur_frm.fields_dict[fieldname].get_query` | Function to dynamically filter Link field options. |
| **Child Table (Grid)** | `cur_frm.fields_dict[child_table].grid` | Grid control for child table. |
| | `...grid.set_column_disp(fieldname, show)` | Shows/hides a grid column. |
| | `...grid.get_field(fieldname)` | Returns field control for a grid column. |
| | `...grid.data` | Array of row data objects in the child table. |
| **Document Actions** | `cur_frm.save()` | Saves the current document. |
| | `cur_frm.save_or_update()` | Saves or updates the document. |
| | `cur_frm.reload_doc()` | Reloads document from server. |
| | `cur_frm.print_doc()` | Opens the print dialog. |
| | `cur_frm.email_doc()` | Opens the email dialog to send the document. |
| | `cur_frm.submit()` | Submits the document (for workflow‑enabled DocTypes). |
| | `cur_frm.cancel()` | Cancels a submitted document. |
| | `cur_frm.amend_doc()` | Creates an amended version of a submitted document. |
| **Data Fetching** | `cur_frm.add_fetch(link_field, source_field, target_field)` | Auto‑copies a value from linked document when link is selected. |
| | `cur_frm.call(method, args, callback)` | Calls a server‑side method with the current document context. |
| | `cur_frm.get_doc()` | Returns the document object. |
| | `cur_frm.get_doclist()` | Returns document as a list of row objects (legacy). |

### Form Events and Child Table Events

Events are attached using `frappe.ui.form.on(doctype, event_map)`. The handlers receive `frm` (or `cur_frm`) as the first argument.

| Event | Trigger |
| :--- | :--- |
| `setup` | Called when the form is first initialized. |
| `onload` | After document is loaded. |
| `refresh` | After the form is rendered or refreshed. |
| `validate` | Before the document is saved. |
| `before_save` | Just before saving. |
| `after_save` | After saving. |
| `on_submit` | After submission. |
| `on_cancel` | After cancellation. |
| `fieldname` (e.g., `customer`) | When a specific field changes. |

**Child Table Events** (triggered on child table DocType):

| Event | Description |
| :--- | :--- |
| `fieldname_add` | When a new row is added. |
| `fieldname_remove` | After a row is removed. |
| `fieldname_before_remove` | Before a row is removed. |

---

## Client‑Side Rendering and Loading Process

### Step‑by‑Step Process

1. **Initial Page Load** – The user navigates to `/desk`; the server renders `base.html`.
2. **Global Object Initialization** – `window.frappe = {};` and `frappe.ready_events = []` are created.
3. **Boot Information Injection** – `frappe.boot` is populated with the server‑generated JSON (from `get_bootinfo()`).
4. **Core JavaScript Bundle Loading** – `frappe-web.bundle.js` is loaded, providing the framework (form system, routing, utilities).
5. **Desk Initialization** – `desk.js` runs, calls `init.startup()`, loads boot info, and starts the app.
6. **Form Loading and Rendering** – When a route like `Form/Flock/new-flock-ucdjobqnr` is triggered:
   - Metadata is fetched with `frappe.get_meta(doctype)`.
   - A page chrome is created via `frappe.ui.make_app_page`.
   - `frappe.ui.form.Layout` instantiates and renders fields.
   - Toolbar, ScriptManager, and Dashboard are attached.
   - Document data is loaded or created.
   - Form events (`setup`, `onload`, `refresh`) are fired.

### Role of Key Files

| File | Role |
| :--- | :--- |
| `frappe/templates/base.html` | Initializes `window.frappe`, injects `frappe.boot`. |
| `frappe/public/js/frappe-web.bundle.js` | Core framework (form, UI, routing). |
| `frappe/public/js/desk.js` | Desk startup and bootinfo loading. |
| `frappe/public/js/frappe/form/form.js` | Defines `frappe.ui.form.Form` (FrappeForm). |
| `frappe/public/js/frappe/form/layout.js` | Manages form layout rendering. |
| `frappe/public/js/frappe/router.js` | Handles client‑side routing. |

### Form Initialization Sequence

1. **Metadata Setup** – Fetch DocType metadata and permissions.
2. **Page Creation** – Build the application page chrome.
3. **Layout Construction** – Render fields into sections, tabs, columns.
4. **Component Attachment** – Attach Toolbar, ScriptManager, Dashboard.
5. **Document Loading** – Load existing document or create new one.
6. **Event Triggers** – Fire `setup`, `onload`, `refresh`, etc.

---

## Important Notes

- **`cur_frm` vs `frm`** – They are the same object; `frm` is preferred in event handlers.
- **Deprecation** – Older properties like `cur_frm.cscript` are legacy and should not be used.
- **Browser Console** – `cur_frm` is invaluable for debugging forms directly.
- **Scope** – `cur_frm` is only available when a form is open. Use `cur_list` for list views and `cur_dialog` for dialogs.
- **Extensibility** – Apps can extend `frappe.boot` via the `boot_session` hook to add custom data.
- **Dynamic Nature** – The exact contents of all objects depend on Frappe version, installed apps, and user permissions.

---

## Conclusion

The Frappe client‑side architecture is built upon three foundational objects:

1. **`frappe`** – The global API namespace for utilities, communication, UI, and more.
2. **`frappe.boot`** – The server‑injected configuration hub, providing all runtime state.
3. **`cur_frm`** – The active form controller, granting full control over documents, fields, and actions.

These objects are initialized in a well‑defined sequence, starting from `base.html`, through core bundle loading, to Desk startup and form rendering. Mastering their contents and lifecycle is essential for any Frappe developer writing client scripts, building custom views, or debugging complex Desk behaviours.

---
