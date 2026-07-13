# Frappe UI – Technical Document

**Version**: Based on main branch (commit 553d1568)  
**License**: MIT  
**Official Repository**: https://github.com/frappe/frappe-ui  
**Online Documentation**: https://ui.frappe.io  

---

## Table of Contents

1. [Overview](#1-overview)  
2. [Architecture](#2-architecture)  
3. [Installation & Configuration](#3-installation--configuration)  
4. [Component Library](#4-component-library)  
5. [Data Management Layer](#5-data-management-layer)  
6. [Styling & Theming](#6-styling--theming)  
7. [Icon System](#7-icon-system)  
8. [Build System & Toolchain](#8-build-system--toolchain)  
9. [TypeScript & Auto‑imports](#9-typescript--auto-imports)  
10. [Advanced Components](#10-advanced-components)  
11. [Frappe Integration](#11-frappe-integration)  
12. [Testing Infrastructure](#12-testing-infrastructure)  
13. [AI Assistant Skill](#13-ai-assistant-skill)  
14. [Appendix](#14-appendix)

---

## 1. Overview

### 1.1 Project Positioning

Frappe UI is a **Vue 3** and **Tailwind CSS** component library and toolset built specifically for modern frontend development within the **Frappe Framework** ecosystem. It offers a complete solution ranging from basic UI elements to complex data management systems.

### 1.2 Core Capabilities

Frappe UI serves three primary goals:

| Area | Description |
|------|-------------|
| **UI Component Library** | Provides 100+ Vue 3 components, from basic form inputs to advanced data‑visualisation controls |
| **Data Management Layer** | Offers reactive resource abstractions for API calls, caching, and real‑time updates via Socket.IO |
| **Frappe Integration** | Delivers dedicated components and utilities that integrate seamlessly with the Frappe backend |

### 1.3 History

Frappe UI originated in 2019 as reusable components (Button, Dialog, Card) within the [Frappe Books](https://github.com/frappe/books) project. In 2020, these components evolved in the [Frappe Cloud](https://github.com/frappe/press) project. In 2022, they were extracted into a standalone npm package, developed in parallel with the [Gameplan](https://github.com/frappe/gameplan) project.

### 1.4 Technology Stack

Frappe UI is built on the following core technologies:

| Technology | Purpose |
|------------|---------|
| **Vue 3** | Frontend framework |
| **Tailwind CSS** | Atomic CSS framework |
| **Headless UI** | Unstyled, accessible UI primitives |
| **TipTap** | ProseMirror‑based rich‑text editor |
| **dayjs** | Lightweight date library |
| **Vite** | Build tool and development server |
| **Vitest** | Unit testing framework |

---

## 2. Architecture

### 2.1 High‑Level Architecture

Frappe UI follows a **modular Vue 3 component library** architecture organised into four layers:

```
┌─────────────────────────────────────────────────────────┐
│                    Component Layer                       │
│   (UI components: basic inputs to complex data views)   │
├─────────────────────────────────────────────────────────┤
│                 Data Management Layer                    │
│       (Resource system: reactive data fetching)         │
├─────────────────────────────────────────────────────────┤
│                  Integration Layer                       │
│           (Frappe‑specific components & tools)          │
├─────────────────────────────────────────────────────────┤
│                     Build Layer                          │
│            (Vite build system with custom plugins)       │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Module Organisation

Frappe UI uses a **hub‑and‑spoke** architecture where `src/index.ts` acts as the central aggregator, re‑exporting all public APIs.

### 2.3 Export Categories

`src/index.ts` organises exports into logical groups:

| Category | Contents |
|----------|----------|
| **Resources** | `createResource`, `createListResource`, `createDocumentResource` |
| **Components** | 40+ components: Alert, Button, Calendar, ListView, TextEditor, etc. |
| **Utilities** | `call`, `debounce`, `FileUploadHandler`, `dayjs`, etc. |
| **Data Fetching** | Modern Composition API data‑fetching tools |
| **Plugins** | `FrappeUI`, `pageMetaPlugin`, `confirmDialog` |

### 2.4 Multiple Entry Points

Frappe UI defines several entry points in `package.json` to support selective imports:

| Import Path | Purpose | Main Exports |
|-------------|---------|--------------|
| `frappe-ui` | Main library | Components, utilities, resources, plugins |
| `frappe-ui/frappe` | Frappe‑specific | Link, DataImport components |
| `frappe-ui/icons` | Icon system | Lucide icon components |
| `frappe-ui/tailwind` | Styling | Tailwind CSS preset configuration |
| `frappe-ui/vite` | Build tools | `lucideIcons()` Vite plugin |
| `frappe-ui/style.css` | Base styles | Global CSS definitions |

---

## 3. Installation & Configuration

### 3.1 Installation

```bash
npm install frappe-ui
# or
yarn add frappe-ui
```

### 3.2 Vue Application Setup

Import the FrappeUI plugin in your `main.js`:

```javascript
import { createApp } from 'vue'
import { FrappeUI } from 'frappe-ui'
import App from './App.vue'
import './index.css'

let app = createApp(App)
app.use(FrappeUI)
app.mount('#app')
```

### 3.3 Tailwind CSS Configuration

Include the Frappe UI preset in `tailwind.config.js`:

```javascript
module.exports = {
  presets: [
    require('frappe-ui/src/utils/tailwind.config')
  ],
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}',
    './node_modules/frappe-ui/src/**/*.{vue,js,ts,jsx,tsx}',
  ],
  // your custom theme extensions
}
```

> **Important**: You must include `./node_modules/frappe-ui/src/**/*.{vue,js,ts,jsx,tsx}` to allow Tailwind to scan Frappe UI components for class names.

### 3.4 CSS Import

Import the component styles in your application's entry CSS file:

```css
@import 'frappe-ui/style.css';
```

### 3.5 Theme Provider

Wrap your application root with the `FrappeUIProvider` component to enable theming:

```vue
<template>
  <FrappeUIProvider>
    <RouterView />
  </FrappeUIProvider>
</template>

<script>
import { FrappeUIProvider } from 'frappe-ui'
export default {
  components: { FrappeUIProvider }
}
</script>
```

---

## 4. Component Library

### 4.1 Component Hierarchy

Frappe UI components are organised into three tiers based on complexity and dependencies:

#### Tier 1 – Base Components

Minimal UI elements with few dependencies:

| Component | Description |
|-----------|-------------|
| `Button` | Multi‑variant, themeable button |
| `Badge` | Label / tag component |
| `Card` | Card container with header, content, and actions |
| `Alert` | Contextual message banners |
| `Spinner` | Loading indicator |
| `Avatar` | User avatar (image / initials) |

#### Tier 2 – Form Components

User input and data‑entry interfaces:

| Component | Description |
|-----------|-------------|
| `FormControl` | Wrapper with label, input, description, and validation messages |
| `FormLabel` | Accessible form label |
| `TextInput` | Single‑line text input |
| `Textarea` | Multi‑line text input |
| `Select` | Dropdown selector |
| `Combobox` | Searchable dropdown |
| `Autocomplete` | Auto‑complete input |
| `DatePicker` | Date selector |
| `Switch` | Toggle switch |
| `Checkbox` | Checkbox |
| `FileUploader` | File upload component |

**Dependencies of form components**:
- `reka-ui` – accessibility primitives (keyboard navigation, ARIA, focus management)
- `@floating-ui/vue` – positioning logic

**Unified size system**:

| Size | Height | Font Size | Padding | Use Case |
|------|--------|-----------|---------|----------|
| `sm` | 28px | text-base | px-2 | Compact forms, tables |
| `md` | 32px | text-base | px-2.5 | Default size |
| `lg` | 40px | text-lg | px-3 | Prominent forms |
| `xl` | 40px | text-xl | px-3 | Large displays |

**Unified variant system**:

| Variant | Border | Background | Use Case |
|---------|--------|------------|----------|
| `subtle` | Gray border | Gray background | Default, blends with page |
| `outline` | Dark border | White background | Standout, card forms |
| `ghost` | Transparent | Transparent (gray on hover) | Inline editing |

#### Tier 3 – Advanced Components

Complex, feature‑rich components:

| Component | Sub‑components | Lines of Code | Description |
|-----------|----------------|---------------|-------------|
| `Calendar` | 10+ | ~3500 | Multi‑view event management with drag‑and‑drop, CRUD |
| `ListView` | 8 | ~800 | Table‑style data display with selection, sorting, custom rendering |
| `TextEditor` | 12+ | ~2500 | Rich‑text editor based on Tiptap |

### 4.2 Component Categories

Core components fall into four main categories:

1. **Form Components** – user input and data collection  
2. **Display Components** – information presentation (Avatar, Alert, Card, etc.)  
3. **Navigation Components** – routing and navigation elements  
4. **Interactive Components** – dialogs, popovers, notifications, etc.

---

## 5. Data Management Layer

### 5.1 Architecture Overview

The data management system provides reactive data fetching, caching, and state management, organised into three core abstractions:

```
┌─────────────────────────────────────────────────────────┐
│              Vue Composition API Layer                   │
│         (useResource, useListResource, etc.)             │
├─────────────────────────────────────────────────────────┤
│              Resource System Layer                       │
│    createResource | createListResource |                 │
│    createDocumentResource                                │
├─────────────────────────────────────────────────────────┤
│              HTTP Request Layer                          │
│    request() | call() | frappeRequest()                  │
├─────────────────────────────────────────────────────────┤
│               Native fetch() API                         │
└─────────────────────────────────────────────────────────┘
```

### 5.2 HTTP Layer

The HTTP layer provides three progressive API abstractions:

#### 5.2.1 `request()` Function

The lowest‑level HTTP utility, a thin wrapper around the native `fetch()` API:

```javascript
const data = await request({
  url: '/api/resource/Todo',
  method: 'GET',
  params: { fields: ['name', 'description'] }
})
```

**Configuration options**:

| Option | Type | Description |
|--------|------|-------------|
| `url` | string | Request URL (required) |
| `method` | string | HTTP method, default `'GET'` |
| `params` | object | Request parameters (query string for GET, JSON body for POST) |
| `headers` | object | HTTP headers |
| `responseType` | string | Response type, default `'json'` |
| `transformRequest` | function | Pre‑request transformation hook |
| `transformResponse` | function | Response transformation hook |
| `transformError` | function | Error handling hook |

#### 5.2.2 `call()` Function

A higher‑level API designed for calling Frappe server methods:

```javascript
const result = await call('frappe.client.get_list', {
  doctype: 'User',
  fields: ['name', 'email']
})
```

**Key features**:
- **Automatic path prefixing** – methods not starting with `/` are prefixed with `/api/method/`
- **CSRF token injection** – automatically includes the `X-Frappe-CSRF-Token` header
- **Frappe response parsing** – understands the `data.message` response format

#### 5.2.3 `frappeRequest()` Function

A request layer that applies Frappe‑specific transformations:
- Request transformation – adds headers like `Accept`, `Content-Type`
- Response transformation – handles the standard Frappe response format

### 5.3 Resource System

#### 5.3.1 `createResource` – Generic Resource

The foundational data‑fetching tool that creates a reactive resource object:

```javascript
import { createResource } from 'frappe-ui'

const userResource = createResource({
  url: 'frappe.client.get_list',
  params: {
    doctype: 'User',
    fields: ['name', 'email']
  },
  auto: true
})
```

**Configuration options**:

| Option | Type | Description |
|--------|------|-------------|
| `url` | string | API endpoint path (required) |
| `method` | string | HTTP method |
| `params` | any | Static request parameters |
| `makeParams` | function | Dynamic parameter generation function |
| `auto` | boolean | Auto‑fetch on creation, default `false` |
| `cache` | string/array | Cache key to reuse resources across components |
| `debounce` | number | Debounce delay in milliseconds |
| `initialData` | any | Initial value for the `data` property |
| `transform` | function | Response data transformation |
| `onFetch` | function | Called before the request starts |
| `beforeSubmit` | function | Called before validation |
| `validate` | function | Parameter validation before request |
| `onSuccess` | function | Success callback |
| `onError` | function | Error callback |
| `onData` | function | Data callback |

**Resource object properties**:

| Property | Type | Description |
|----------|------|-------------|
| `data` | any | Transformed fetched data |
| `loading` | boolean | `true` while request is in progress |
| `error` | Error/null | Error object if request failed |
| `fetched` | boolean | `true` after first successful fetch |
| `params` | any | Parameters used for the last fetch |
| `previousData` | any | Data from before the current fetch |

#### 5.3.2 Declarative Resource Creation

Use the `resources` option inside Vue components:

```javascript
export default {
  resources: {
    users: {
      url: 'frappe.client.get_list',
      params: {
        doctype: 'User',
        fields: ['name', 'email']
      },
      auto: true
    }
  }
}
```

Resources are accessible via `this.$resources.users` and are automatically managed by the Vue component lifecycle.

#### 5.3.3 `createListResource` – List Resource

Designed for paginated list data:
- Pagination support
- Filtering and sorting
- CRUD operations
- Row actions

#### 5.3.4 `createDocumentResource` – Document Resource

Designed for single‑document operations:
- CRUD operations
- Dirty state tracking
- Optimistic updates
- Method invocation

### 5.4 Resource Plugin Integration

The `resourcesPlugin` provides Vue component integration:

| Component Method | Parameters | Description |
|------------------|------------|-------------|
| `$resources` | - | Computed property that accesses all component resources |
| `$getResource(cacheKey)` | cache key | Gets a cached generic resource |
| `$getDocumentResource(doctype, name)` | doctype, name | Gets a cached document resource |
| `$getDoc(doctype, name)` | doctype, name | Directly fetches document data |
| `$getListResource(cacheKey)` | cache key | Gets a cached list resource |
| `$refetchResource(cache)` | cache key | Manually refetches a cached resource |

### 5.5 Real‑Time Updates

Frappe UI supports real‑time data synchronisation via Socket.IO:
- Integration with Frappe's Socket.IO server
- Supports `frappe.realtime.on` for listening to real‑time events
- Used for document changes, notifications, etc.

---

## 6. Styling & Theming

### 6.1 Design System Overview

Frappe UI uses a Tailwind CSS‑based styling system with custom presets, design tokens, and pre‑configured plugins.

### 6.2 Design Token Categories

The Tailwind preset provides the following token categories:

| Category | Prefix | Purpose | Example Classes |
|----------|--------|---------|-----------------|
| **Text Colors** | `ink-gray-*` | Text and icon colours | `text-ink-gray-9`, `text-ink-gray-5` |
| **Surface Colors** | `surface-*` | Backgrounds of UI elements | `bg-surface-modal`, `bg-surface-gray` |
| **Border Colors** | `border-*` | Border colours | `border-gray-200`, `border-gray-300` |
| **Accent Colors** | `accent-*` | Brand and interaction colours | `accent-blue`, `accent-green`, `accent-red` |
| **State Colors** | `state-*` | Status indicators | `state-success`, `state-error`, `state-warning` |
| **Typography** | `text-*`, `font-*` | Font sizes and weights | `text-sm`, `font-medium` |
| **Spacing** | Standard Tailwind | Margins, padding | `p-2`, `mt-4`, `gap-3` |

### 6.3 Theme Configuration

#### FrappeUIProvider Component

`FrappeUIProvider` establishes the theme context for the component tree:
- Propagates theme context to child components
- Injects CSS custom properties
- Enables theme switching and persistence
- Applies default configuration

#### Theme Utilities

The library exports theme utilities from `src/utils/theme`:
- Theme configuration getters/setters
- Colour manipulation helpers
- Token resolution functions
- Theme mode switching (light/dark)

### 6.4 CSS Custom Properties

The theming system uses CSS custom properties as the underlying implementation for design tokens, enabling runtime theme switching:

```
Token Type    | CSS Variable          | Tailwind Class       | Usage
--------------|-----------------------|----------------------|-------------------
surface-modal | --surface-modal       | bg-surface-modal     | Modal backgrounds
ink-gray-9    | --ink-gray-9          | text-ink-gray-9      | Primary text
accent-blue   | --accent-blue         | text-accent-blue     | Brand colour
```

### 6.5 Custom Theme Extension

```javascript
export default {
  presets: [require('frappe-ui/tailwind')],
  theme: {
    extend: {
      colors: {
        brand: {
          500: '#3B82F6',
          600: '#2563EB',
        }
      }
    }
  }
}
```

---

## 7. Icon System

### 7.1 Architecture Overview

Frappe UI implements a custom **Lucide icon integration system**:
- Processes Lucide icons from the `lucide-static` package
- Applies custom transformations
- Provides them as auto‑importable Vue components

### 7.2 Icon Transformation Pipeline

The `getIcons()` function implements a three‑stage transformation pipeline:

1. **Load icons** – imports all icons from the `lucide-static` package  
2. **Modify stroke width** – replaces all `stroke-width="2"` with `stroke-width="1.5"` for consistent visual weight  
3. **Generate name variants** – creates kebab‑cased variants for each icon name

### 7.3 Naming Convention

The `camelToDash()` function generates kebab‑cased variants from camel‑cased names:

| Input (camelCase) | Output Variants | Description |
|-------------------|-----------------|-------------|
| `AlertCircle` | `['alert-circle']` | Simple camel‑to‑kebab |
| `ArrowUp` | `['arrow-up']` | No numbers |
| `BarChart2` | `['bar-chart-2', 'bar-chart2']` | Two variants for numbered icons |
| `Clock1` | `['clock-1', 'clock1']` | Both dashed and concatenated forms |

### 7.4 Usage

Icons are available as auto‑imported Vue components and can be used in multiple naming styles:

```vue
<!-- All of these are valid -->
<AlertCircle />
<alert-circle />
<bar-chart-2 />
<bar-chart2 />
```

Icon components are registered in `components.d.ts` with the `Lucide` prefix.

---

## 8. Build System & Toolchain

### 8.1 Vite Build Tool

Frappe UI uses **Vite 5.1.8** as the primary build tool and development server.

### 8.2 NPM Scripts

| Script | Command | Purpose |
|--------|---------|---------|
| `dev` | `vite` | Starts the Vite development server |
| `story:dev` | `histoire dev` | Starts the Histoire component development environment |
| `preview` | `vite preview` | Previews the production build locally |
| `story:preview` | `histoire preview` | Previews the built Histoire stories |
| `build` | `vite build` | Compiles the library for distribution |
| `story:build` | `histoire build` | Generates a static site with all component stories |
| `test` | `vitest --run` | Runs all tests (non‑watch mode) |
| `type-check` | `tsc --noEmit` | Validates TypeScript types |
| `prettier` | `prettier -w ./src` | Formats source code with Prettier |

### 8.3 Vite Plugin Integration

The Vite configuration integrates the following key plugins:

| Plugin | Purpose |
|--------|---------|
| `@vitejs/plugin-vue` | Vue 3 SFC compilation |
| `unplugin-auto-import` | Auto‑imports Vue APIs and composables |
| `unplugin-vue-components` | Auto‑imports components on demand |
| `unplugin-icons` | Icon component generation |
| Custom Lucide plugin | Transforms Lucide icons (stroke width, naming) |

### 8.4 Histoire Integration

Frappe UI uses **Histoire** as its component development environment:
- Similar to Storybook but optimised for Vite and Vue 3
- Provides isolated component development and documentation
- Supports hot‑reloading

---

## 9. TypeScript & Auto‑imports

### 9.1 Auto‑Import Architecture

Frappe UI leverages the unplugin ecosystem to eliminate boilerplate imports:

| Plugin | Purpose |
|--------|---------|
| `unplugin-vue-components` | Globally registers Vue components automatically |
| `unplugin-auto-import` | Auto‑imports composables and utilities |
| `unplugin-icons` | On‑demand icon imports |

These plugins automatically generate TypeScript declaration files, providing full type safety and IDE autocompletion.

### 9.2 `components.d.ts`

Declares the `GlobalComponents` interface mapping component names to their types:

```typescript
declare module 'vue' {
  export interface GlobalComponents {
    Alert: typeof import('./src/components/Alert/Alert.vue')['default']
    Avatar: typeof import('./src/components/Avatar/Avatar.vue')['default']
    Button: typeof import('./src/components/Button/Button.vue')['default']
    Calendar: typeof import('./src/components/Calendar/Calendar.vue')['default']
    LucideCalendar: typeof import('~icons/lucide/calendar')['default']
    LucideCheck: typeof import('~icons/lucide/check')['default']
    // ... 150+ more components
  }
}
```

**Key features**:
- All components under `src/components/` are globally registered
- Lucide icons are registered with the `Lucide` prefix
- Includes `.vue` component files and `.story.vue` files
- Each entry maps to the component's default export type

### 9.3 Usage Example

Components can be used anywhere in the codebase without explicit imports:

```vue
<template>
  <Button>Click me</Button>
  <Calendar />
  <LucideCheck />
</template>
```

---

## 10. Advanced Components

### 10.1 Calendar Component

Provides a comprehensive event management interface:

**View modes**: Month, Week, Day

**Core features**:
- Drag‑and‑drop event manipulation
- Real‑time updates
- Keyboard navigation shortcuts

**Configuration options**:

| Config Key | Type | Default | Description |
|------------|------|---------|-------------|
| `scrollToHour` | Number | 15 | Initial scroll position (hour) |
| `disableModes` | Array | [] | Disabled views (Month/Week/Day) |
| `defaultMode` | String | 'Month' | Initial view mode |
| `isEditMode` | Boolean | false | Enables drag‑and‑drop and CRUD |
| `eventIcons` | Object | {} | Icon component for each event type |
| `hourHeight` | Number | 50 | Pixel height per hour in time view |
| `enableShortcuts` | Boolean | true | Keyboard navigation shortcuts |
| `timeFormat` | String | '12h' | Time display format (12h/24h) |
| `weekends` | Array | ['sunday'] | Weekend days (for styling) |

**Events**: `create`, `update`, `delete`, `rangeChange`

**Event data structure**:

```javascript
{
  id: String,           // Unique identifier
  title: String,        // Event title
  fromDate: String,     // YYYY-MM-DD format
  toDate: String,       // YYYY-MM-DD format
  fromTime: String,     // HH:MM:SS format
  toTime: String,       // HH:MM:SS format
  color: String,        // Colour key (green, blue, etc.)
  isFullDay: Boolean,   // All‑day event flag
  type: String,         // Optional event type (for icons)
  // any other custom properties
}
```

### 10.2 ListView Component

A flexible table‑like data display component:

**Core Props**:

| Prop | Type | Description |
|------|------|-------------|
| `columns` | Array | Defines the table structure |
| `rows` | Array | Contains the data to display |
| `rowKey` | String | Uniquely identifies each row |

**Column definition pattern**:

```javascript
columns: [
  { key: 'name', label: 'Name', width: 2 },
  { key: 'status', label: 'Status', width: 1, align: 'center' },
  { key: 'modified', label: 'Modified', width: '200px', align: 'right' }
]
```

**Features**:
- Row selection (state managed with reactive `Set`)
- Grouped display
- Custom cell rendering
- Column width adjustment
- Router integration (each row can become a `<router-link>`)

**Architecture pattern**: Uses `provide/inject` to share state between parent and child components.

### 10.3 TextEditor Component

A rich‑text editor based on **TipTap** and **ProseMirror**:
- 12+ sub‑components
- Extensive extension system
- Code highlighting based on Lowlight

---

## 11. Frappe Integration

### 11.1 Dedicated Components

Frappe UI provides specialised components deeply integrated with the Frappe framework:

| Component | Purpose |
|-----------|---------|
| `Link` | Frappe document link |
| `DataImport` | Data import component |

### 11.2 Frappe API Integration

The data management layer natively supports Frappe API conventions:
- Automatic path prefixing `/api/method/`
- Automatic CSRF token injection
- Frappe response format parsing

### 11.3 Real‑Time Updates

Integration with Frappe backend via Socket.IO:
- Listens to document change events
- Automatically updates the UI
- Supports custom real‑time event handling

---

## 12. Testing Infrastructure

### 12.1 Unit Testing

Frappe UI uses **Vitest** for unit testing:
- Fast test execution
- Native ESM support
- Vite integration

**Commands**:
```bash
yarn test        # Runs all tests
yarn type-check  # TypeScript type checking
```

### 12.2 Component Testing

Uses **Histoire** for isolated component development and visual testing.

### 12.3 UI Testing

The Frappe ecosystem uses **Cypress** for end‑to‑end UI testing:
```bash
bench --site [sitename] run-ui-tests [app]
```

---

## 13. AI Assistant Skill

Frappe UI includes an **Agent Skill** for AI coding assistants (Claude Code, Cursor, Codex, etc.).

### 13.1 Installation

```bash
npx skills add https://github.com/frappe/frappe-ui/tree/main/skills/frappe-ui
```

### 13.2 Skill Contents

The skill teaches AI agents about:
- Semantic Tailwind tokens
- The `variant` + `theme` colour axis
- `useCall` data‑fetching composables
- Common UI patterns
- Anti‑patterns to avoid

The skill resides in [`skills/frappe-ui/`](https://github.com/frappe/frappe-ui/blob/main/skills/frappe-ui).

---

## 14. Appendix

### 14.1 Products Using Frappe UI

Frappe UI is used in the following products:
- [Frappe Cloud](https://frappecloud.com)
- [Frappe Books](https://github.com/frappe/books)
- [Gameplan](https://github.com/frappe/gameplan)
- Other Frappe ecosystem projects

### 14.2 Useful Links

| Resource | Link |
|----------|------|
| Official Documentation | https://ui.frappe.io |
| GitHub Repository | https://github.com/frappe/frappe-ui |
| Vite Plugin Documentation | https://github.com/frappe/frappe-ui/blob/main/vite/README.md |
| Starter Template | https://github.com/netchampfaris/frappe-ui-starter |
| Community Discussions | https://github.com/frappe/frappe-ui/discussions |

### 14.3 Version Information

Frappe UI is distributed as an **npm package** with **tree‑shaking** support to minimise bundle size. The library follows **semantic versioning** and uses the **`bump‑and‑release`** script to automate the release process.

---

*This documentation is based on the Frappe UI main branch (commit 553d1568) and was last updated in July 2026.*

---

