# Frappe / ERPNext Print Format — Knowledge Base

A practical, source-referenced guide to building **elegant, print-correct**
Frappe print formats — with a deep focus on the parts that silently break:
page margins, layout engines, footers/page numbers, letter heads, and the
two PDF engines (`wkhtmltopdf` vs `chrome`).

All line references are against this bench
(`apps/frappe`, v16). Verify line numbers after upgrades; the *functions* are
stable even when line numbers drift.

---

## Index

1. [The report-PDF pipeline (who calls what)](#1-the-report-pdf-pipeline)
2. [Page margins — the definitive guide](#2-page-margins--the-definitive-guide)
   - 2.1 [Where the 15 mm comes from](#21-where-the-15-mm-default-comes-from)
   - 2.2 [How to actually set the margin](#22-how-to-actually-set-the-margin)
   - 2.3 [The real culprit: `.print-format { padding }`](#23-the-real-culprit-print-format--padding-)
   - 2.4 [The CSS cascade order that makes it work](#24-the-css-cascade-order)
   - 2.5 [Copy-paste recipe](#25-copy-paste-margin-recipe)
3. [Layout engines: flex vs div-grid vs table](#3-layout-engines-flex-vs-div-grid-vs-table)
4. [Headers, footers, page numbers, date & time](#4-headers-footers-page-numbers-date--time)
5. [Letter head display](#5-letter-head-display)
6. [Print formats for Reports (incl. multiple versions)](#6-print-formats-for-reports)
7. [The JS templating context & helpers](#7-the-js-templating-context--helpers)
8. [`wkhtmltopdf` vs `chrome` — what to keep in mind](#8-wkhtmltopdf-vs-chrome)
9. [Gotchas & pitfalls](#9-gotchas--pitfalls)
10. [Professional design tips](#10-professional-design-tips)
11. [Bootstrap & Frappe print CSS class reference](#11-bootstrap--frappe-print-css-class-reference)
12. [Sample: Sales Invoice print format (Jinja + Bootstrap)](#12-sample-sales-invoice-print-format-jinja--bootstrap)
13. [Appendix: file & function reference](#13-appendix-file--function-reference)

---

## 1. The report-PDF pipeline

When a user opens a **Query/Script Report** and clicks **Menu → PDF / Print**,
this is the chain:

```
query_report.js  get_menu_items()            → "Print" / "PDF" actions
        │          frappe.ui.get_print_settings(...)   (the dialog)
        ▼
query_report.js  pdf_report(print_settings)  / print_report(print_settings)
        │          ├─ get_custom_format()     → resolves which HTML template
        │          ├─ render_report_letterhead()
        │          ├─ frappe.render_template("print_template", {content, print_css, ...})
        │          └─ frappe.render_pdf(html, print_settings)   → POST
        ▼
frappe/utils/print_format.py  report_to_pdf(html, orientation)
        ▼
frappe/utils/pdf.py  get_pdf(html, options)
        │          ├─ prepare_options()        → default margins, page size
        │          │     └─ read_options_from_html() → get_print_format_styles()
        │          └─ pdfkit.from_string(...)   → **wkhtmltopdf** binary
        ▼
                     PDF bytes
```

**Critical fact:** the report path (`report_to_pdf` → `get_pdf`) is **hard-wired
to wkhtmltopdf**. It never calls `get_chrome_pdf`. So a report print format's
`pdf_generator: "chrome"` field is **ignored** — design reports for wkhtmltopdf.
(See [§8](#8-wkhtmltopdf-vs-chrome).)

Key functions:

| Step | File | Function |
|---|---|---|
| Menu actions | `public/js/frappe/views/reports/query_report.js` | `get_menu_items` |
| Print dialog | `public/js/frappe/form/print_utils.js` | `get_print_settings` |
| Choose template | query_report.js | `get_custom_format`, `get_print_template`, `get_report_print_format` |
| Letter head | query_report.js | `render_report_letterhead` |
| Wrap HTML | `public/html/print_template.html` | (Jinja template) |
| Ship to server | `public/js/frappe/microtemplate.js` | `frappe.render_pdf` |
| Server entry | `utils/print_format.py` | `report_to_pdf` |
| PDF engine | `utils/pdf.py` | `get_pdf`, `prepare_options`, `read_options_from_html`, `get_print_format_styles` |

---

## 2. Page margins — the definitive guide

> This is the single most confusing part of Frappe printing. Read it once,
> carefully, and you'll never fight margins again.

There are **two independent insets** that stack:

1. **PDF page margin** — the whitespace the PDF engine leaves around the page
   (a wkhtmltopdf CLI arg, e.g. `--margin-left 15mm`).
2. **`.print-format` container padding** — CSS padding *inside* the content box,
   from the framework's `print.bundle.css`.

Visible left inset = **page margin + container padding**. If you only change one,
you'll still see the other.

### 2.1 Where the 15 mm default comes from

`prepare_options` sets defaults when no margin is supplied:

```python
# frappe/utils/pdf.py  (prepare_options)
if not options.get("margin-right"):
    options["margin-right"] = "15mm"
if not options.get("margin-left"):
    options["margin-left"] = "15mm"
```

`report_to_pdf` calls `get_pdf(html, {...})` **without** margins, so reports start
at 15 mm on every side. (Top/bottom get a 15 mm default from
`prepare_header_footer` when there is no header/footer div.)

### 2.2 How to actually set the margin

The engine reads margins from **one place only**: a **top-level** CSS rule whose
selector is exactly `.print-format` (or `.print-format, p`), using **longhand**
properties. See `get_print_format_styles`:

```python
# frappe/utils/pdf.py  (get_print_format_styles)
for rule in parsed_sheet:
    if not isinstance(rule, cssutils.css.CSSStyleRule):   # ← @media blocks skipped!
        continue
    if ".print-format" in [x.strip() for x in rule.selectorText.split(",")]:
        valid_styles.extend(entry for entry in rule.style)
# only these names are honored:
attrs = ("margin-top","margin-bottom","margin-left","margin-right",
         "page-size","header-spacing","orientation","page-width","page-height")
```

Consequences — **three things that DON'T work** (common wasted hours):

| You wrote | Result |
|---|---|
| `@page { margin: 5mm }` | ❌ ignored — extractor never reads `@page` |
| `.print-format { margin: 5mm }` (shorthand) | ❌ ignored — property name is `margin`, not `margin-left` |
| `@media print { .print-format { margin-left: 5mm } }` | ❌ ignored — rule is inside a `CSSMediaRule`, skipped |

**What works** — top-level, longhand:

```css
.print-format {
    margin-top: 5mm;
    margin-bottom: 5mm;
    margin-left: 5mm;
    margin-right: 5mm;
}
```

### 2.3 The real culprit: `.print-format { padding }`

Even with the page margin at 5 mm, content still looked inset by ~24 mm. Reason —
`print.bundle.css` ships:

```css
.print-format {
    background-color: white;
    border-radius: 8px;
    max-width: 8.3in;
    min-height: 11.69in;
    padding: 0.75in;   /* ← ~19 mm inside the page */
    margin: auto;
    color: var(--gray-900);
}
```

`0.75in ≈ 19 mm` of **padding**. So `5 mm page margin + 19 mm padding ≈ 24 mm`.
Override the padding in your format:

```css
.print-format { padding: 5mm; }
```

`padding` is **not** in the extractor's `attrs`, so it only affects visual layout
(never the CLI margin) — exactly what you want.

### 2.4 The CSS cascade order

Your override wins because of load order in `print_template.html`:

```html
<head>
  <style>{{ print_css }}</style>   <!-- framework: padding: 0.75in -->
</head>
<body>
  <div class="print-format ...">
    {{ content }}                  <!-- YOUR <style> lives here, later in the doc -->
  </div>
</body>
```

Same specificity (`.print-format`), but **your block appears later** → it wins.
No `!important` needed.

### 2.5 Copy-paste margin recipe

```css
/* page margin the PDF engine will honor (top-level, longhand) */
.print-format {
    padding: 5mm;                 /* overrides framework 0.75in inset */
    margin-top: 5mm;
    margin-bottom: 5mm;
    margin-left: 5mm;
    margin-right: 5mm;
}
@page { margin: 5mm; }            /* harmless; helps the chrome engine / browser preview */
```

Net inset ≈ 10 mm (5 page + 5 padding). For an edge-to-edge dense ledger, drop
`padding` to `0` and rely on the 5 mm page margin alone.

**Verify without printing** — the server's own extractor tells you what the engine
will receive:

```python
from frappe.utils.pdf import prepare_options
from frappe.www.printview import get_print_style
h = frappe.db.get_value("Print Format", "My Format", "html")
full = f"<html><head><style>{get_print_style()}</style></head><body><div class='print-format'>{h}</div></body></html>"
_, opts = prepare_options(full, {"orientation": "Portrait"})
print({k: v for k, v in opts.items() if k.startswith("margin")})
# → {'margin-left': '5mm', 'margin-right': '5mm', ...}
```

---

## 3. Layout engines: flex vs div-grid vs table

wkhtmltopdf embeds **QtWebKit circa 2012**. Modern layout silently degrades.
Choose the engine by what actually renders:

| Technique | wkhtmltopdf | chrome | Verdict |
|---|---|---|---|
| **Flexbox** (`display:flex`) | ❌ scatters, clips, ignores `justify-content` | ✅ | **Never** for report PDFs |
| **CSS Grid** | ❌ unsupported | ✅ | Avoid for wkhtmltopdf |
| **Bootstrap grid** (`row` / `col-xs-*`) | ✅ float-based, reliable | ✅ | **Best for headers / two-column blocks** |
| **`<table>`** | ✅ rock-solid, incl. page breaks | ✅ | **Best for tabular/ledger data** |
| Absolute positioning | ⚠️ fragile across page breaks | ⚠️ | Avoid |

Practical rules:

- **Two-column header** (party on left, title/summary on right) → Bootstrap
  `row` + `col-xs-6` / `col-xs-5` + `col-xs-7`. These are float-based and print
  correctly.
- **Data grid** → real `<table class="table">` with `table-layout: fixed` and
  `%` column widths. Tables get proper page-break handling for free (see §4).
- Symptom that you used flex: the summary block **"scatters"** or overlaps in the
  PDF but looks fine on screen — screen uses a modern browser, the PDF uses
  wkhtmltopdf.

Table page-break hygiene:

```css
table { width: 100%; border-collapse: collapse; table-layout: fixed; }
@media print {
    thead { display: table-header-group; }  /* repeat header each page */
    tfoot { display: table-footer-group; }  /* repeat totals each page */
    tr    { page-break-inside: avoid; }      /* no row split across pages */
}
```

Numbers: `font-variant-numeric: tabular-nums;` for aligned digits, and
`white-space: nowrap;` on amount cells so `8,50,950.00` never wraps mid-number.

---

## 4. Headers, footers, page numbers, date & time

wkhtmltopdf renders headers/footers as **separate documents** from special divs.
`prepare_header_footer` extracts elements by id:

```python
# frappe/utils/pdf.py  (prepare_header_footer)
for html_id in ("header-html", "footer-html"):
    if content := soup.find(id=html_id):
        ...   # rendered and passed as --header-html / --footer-html
    else:
        if html_id == "header-html":  options["margin-top"]    = "15mm"
        elif html_id == "footer-html": options["margin-bottom"] = "15mm"
```

**Page numbers** are built into `print_template.html` and activate when Print
Settings → *Repeat Header and Footer* is on (`print_settings.repeat_header_footer`):

```html
<div id="footer-html" class="visible-pdf">
    ...letter-head footer...
    <p class="text-center small page-number visible-pdf">
        Page <span class="page"></span> of <span class="topage"></span>
    </p>
</div>
```

wkhtmltopdf fills `.page` / `.topage` via its footer engine — no app JS required
(important, because `get_pdf` sets `--disable-javascript` for the *body*).

**Two ways to show date/time:**

1. **Inline "Printed On" line** (simplest, non-repeating) — put it in your content:
   ```html
   <p class="text-right text-muted">
       {%= __("Printed On") %} {%= frappe.datetime.str_to_user(frappe.datetime.get_datetime_as_string()) %}
   </p>
   ```
2. **Repeating footer** — add your own `<div id="footer-html">` (or use the letter
   head footer + Repeat Header and Footer) so it appears on every page.

`class="visible-pdf"` / `hidden-pdf` toggle visibility between screen and PDF
(`toggle_visible_pdf` in pdf.py).

---

## 5. Letter head display

For reports, the print dialog offers **With Letter head** + a **Letter Head** link
(`get_print_settings`, print_utils.js). On submit:

```js
// query_report.js  render_report_letterhead()
frappe.call("frappe.utils.print_format.render_letterhead_for_print", {
    letterhead: print_settings.letter_head_name,
    doc: doc_context,     // = the report's filter values (+ company default)
}).then(r => { print_settings.letter_head = r.message; });
```

`render_letterhead_for_print` (print_format.py) resolves any Jinja placeholders in
the letter head against `doc` (your filters — so `{{ company }}` etc. work), and
returns `{header, footer}`. `print_template.html` then renders:

```html
{% if print_settings.letter_head %}
  <div {% if print_settings.repeat_header_footer %} id="header-html" class="hidden-pdf" {% endif %}>
      <div class="letter-head">{{ print_settings.letter_head.header }}</div>
  </div>
{% endif %}
```

Keep in mind:

- With **Repeat Header and Footer** on, the header goes into `#header-html` and
  repeats on every page (and reserves top margin). Off → it prints once at the top
  of the content only.
- The letter head **header/footer HTML competes for vertical space** — if it's
  tall, increase `margin-top` / `margin-bottom` so the body doesn't overlap it.
- Letter head is applied by the **caller/dialog**, not baked into your format —
  your format should not hard-code a company banner; let the letter head own it.

---

## 6. Print formats for Reports

Unlike doctype print formats, a report can't attach an arbitrary `.html`; the
Print dialog only lists **Print Format records** matching the report. The dialog's
`get_query` (print_utils.js):

```js
{ fieldtype: "Link", fieldname: "print_format", options: "Print Format",
  get_query: () => ({ filters: {
      print_format_for: "Report",
      print_format_type: "JS",
      report: frappe.query_report.report_name,
      disabled: 0,
}})}
```

So a selectable report print format is a **Print Format record** with:

| Field | Value |
|---|---|
| `print_format_for` | `Report` |
| `print_format_type` | `JS` (the `{%= %}` micro-template engine, same as report `.html`) |
| `report` | the report's name, e.g. `Party Ledger` |
| `standard` | `Yes` (ship as a module record) |
| `module` | your app module |
| `html` | the template (the `<style>` + `{%= %}` body) |
| `disabled` | `0` |

Ship it as a module record at
`your_app/<module>/print_format/<slug>/<slug>.json` — mirror
`erpnext/accounts/print_format/general_ledger_standard/` for the exact schema.

### Default vs selectable

- **Default**: a `report_name.html` sibling of the report `.py` becomes the report's
  `html_format` — used when **no** print format is picked. Only **one** default.
- **Selectable / multiple versions**: additional layouts must be **Print Format
  records** (as above). They appear in the dialog dropdown; the user picks one.
  This is how you offer *"Statement of Accounts"* and *"Statement (Compact)"* side
  by side against the same report.

### Reimport gotcha

Migrate **skips re-importing** a standard print format if the JSON `modified`
timestamp isn't newer than the DB copy. **Bump `modified`** on every change, or
the HTML won't update on `bench migrate`.

### Programmatic switch (advanced)

Report JS may define `get_pdf_format(report, current_format)` (called by
`get_custom_format`) to swap templates at print time based on a filter — but the
native record + dialog is simpler and preferred.

---

## 7. The JS templating context & helpers

Report print formats (`print_format_type: JS`) render with the `{%= expr %}` (emit)
/ `{% code %}` (logic) micro-template. Available in scope:

| Name | What |
|---|---|
| `data` | array of result rows (as returned by the report's `execute`) |
| `filters` | applied filter values |
| `report` | the report controller instance |
| `columns` | column defs |
| `subtitle` | filters-as-HTML (when *Include filters* is ticked) |

Helpers you can call: `__("...")` (translate), `format_currency(v, cur)`,
`format_number(v, null, 2)`, `frappe.datetime.str_to_user(d)`,
`frappe.datetime.get_datetime_as_string()`, `frappe.format(v, {fieldtype})`, and
plain JS (`Math.abs`, `.slice`, loops).

Common row-slicing for a ledger whose `execute` appends opening/total/closing:

```js
{%
var opening = data.slice(0, 1).pop();     // first row
var total   = data.slice(-2, -1).pop();   // second last
var closing = data.slice(-1).pop();       // last
var rows    = data.slice(1, -2);          // the entries
%}
```

Show a running balance as an accountant expects (magnitude + Dr/Cr, no sign):

```js
function bal_suffix(v){ if(v<0) return " Cr"; if(v>0) return " Dr"; return ""; }
...
{%= format_number(Math.abs(row.balance), null, 2) %}{%= bal_suffix(row.balance) %}
```

---

## 8. `wkhtmltopdf` vs `chrome`

Frappe v16 ships two PDF engines. **Know which one runs your format.**

| Aspect | wkhtmltopdf | chrome |
|---|---|---|
| Engine | QtWebKit (~2012) | headless Chromium (CDP `Page.printToPDF`) |
| Flexbox / CSS Grid | ❌ | ✅ |
| Modern CSS (`calc`, custom props, `gap`) | limited | ✅ |
| Body JavaScript | **disabled** (`get_pdf` sets `--disable-javascript`) | ✅ |
| **Report** printing | ✅ **always** (`report_to_pdf`→`get_pdf`) | ❌ never (path doesn't route to chrome) |
| **Doctype** printing | default | opt-in: Print Format `pdf_generator = "chrome"` (`printview.py` reads it) |
| Margin source | top-level `.print-format` longhand margins (`get_print_format_styles`) | **same** extractor (`browser._parse_pdf_options_from_html`) |
| Default margins | 15 mm | 15 mm |
| Header/footer | `#header-html` / `#footer-html` via CLI | merged by `PDFTransformer` |

Things to keep in mind:

**If you're building a REPORT print format**
- You get **wkhtmltopdf, period** — the record's `pdf_generator` is ignored here.
- **No flexbox, no grid, no JS.** Use Bootstrap grid + tables (§3).
- Margins via top-level `.print-format` longhand + override `padding` (§2).
- Page numbers via *Repeat Header and Footer* (§4), not custom footer JS.

**If you're building a DOCTYPE print format**
- Set `pdf_generator: "chrome"` on the Print Format to unlock flexbox/grid/JS and
  more faithful rendering (`get_chrome_pdf` → `Browser` → `ChromePDFGenerator`).
- The **same** `.print-format` longhand-margin convention still applies — chrome
  reuses `get_print_format_styles`.
- chrome sets its own CDP margins to 0 and applies the extracted values; still
  falls back to 15 mm when unset.
- chrome respects modern `@media print`, but the margin *extraction* is still
  top-level-only — don't hide margins inside `@media`.

**Portability tip:** if a format must look right under *either* engine, restrict
yourself to the wkhtmltopdf-safe subset (tables + Bootstrap grid, no JS). It will
also render perfectly under chrome.

---

## 9. Gotchas & pitfalls

- **`pdf_report` crash: `Cannot read properties of undefined (reading 'toString')`**
  (`query_report.js`). The filename builder does
  `applied_filters[key].toString()`; and `get_filter_values` does
  `if (f.df.hidden) v = f.value`. A **hidden filter with no `default`** has
  `f.value === undefined` → crash (intermittent; "fixed by hard refresh"). **Fix:**
  give every hidden non-check filter `"default": ""` in the report `.js`. `""` is
  falsy, so it's dropped from the filename — no side effects.
- **Margins ignored** → you used `@page`, the `margin` shorthand, or an `@media`
  block. Use top-level `.print-format` **longhand** (§2.2).
- **Content still inset after fixing margin** → the `.print-format { padding:
  0.75in }` default (§2.3).
- **Layout scatters in PDF, fine on screen** → flexbox under wkhtmltopdf (§3).
- **HTML doesn't update after edit** → bump the print format JSON `modified`
  (§6 reimport gotcha), and `bench clear-cache` + hard-refresh for report `.js`.
- **`pdf_generator: chrome` "not working" on a report** → expected; reports always
  use wkhtmltopdf (§8).
- **Server-side report guards affect mobile** → mobile clients call the same
  `execute` via `run_query_report`. A `frappe.throw` in the report hits mobile too;
  prefer a client `reqd: 1` filter unless you truly want it enforced everywhere.

---

## 10. Professional design tips

- **Design for the engine, not the browser.** Preview lies; always check the
  actual PDF. Or assert margins server-side with `prepare_options` (§2.5).
- **Tables for data, grid for chrome-of-page.** Never flex.
- **Fixed table layout + `%` widths** keep columns stable across pages; add
  `nowrap` to amount cells and `tabular-nums` for alignment.
- **Repeat `thead`/`tfoot`** so multi-page statements carry headers and totals.
- **`page-break-inside: avoid`** on rows/sections to prevent ugly splits.
- **Right-align money**, left-align text, and beware CSS specificity: a class like
  `.text-right` (0,1,0) loses to `table.pl th` (0,1,2). Qualify it:
  `table.pl th.text-right { text-align: right; }`.
- **Accountant conventions**: show balances as magnitude + `Dr`/`Cr`, not a minus
  sign; put "Amount in <CUR>" once as a caption.
- **Keep the letter head out of your format** — let the Letter Head doctype own the
  banner so branding stays centralized.
- **Small, readable fonts**: 10–11 px body for dense statements; a slightly smaller
  class for verbose columns (remarks) keeps rows tight without hurting totals.
- **One source of truth for content**: put narration in the data
  (e.g. GL `remarks`), not re-derived in the template, so print and screen match.
- **Ship as a standard module record** and version deliberately (a v2 alongside v1)
  rather than mutating the one everyone relies on.

---

## 11. Bootstrap & Frappe print CSS class reference

Frappe's print stylesheet ships **Bootstrap 3** grid + utilities plus a few
Frappe-specific print helpers. These are the classes that render reliably under
**both** PDF engines (crucially, they work in wkhtmltopdf where flexbox does not).

**Grid** — 12-column, float-based. Use the `xs` tier (print has one width):

| Class | Meaning |
|---|---|
| `row` | grid row (clears floats) |
| `col-xs-1` … `col-xs-12` | column spanning N/12 of the width |
| `col-xs-offset-1` … `col-xs-offset-11` | push a column right by N/12 (great for right-aligned totals/signature) |
| `column-break` | Frappe helper for a print column inside a `row` |

> Columns in a `row` should sum to 12 (e.g. `col-xs-7` + `col-xs-5`). Nest a new
> `row` inside a column for sub-grids (e.g. a label/value summary).

**Text & alignment**

| Class | Meaning |
|---|---|
| `text-left` / `text-center` / `text-right` | horizontal alignment |
| `text-muted` | grey secondary text |
| `text-bold` | bold (Frappe) |
| `small` | ~85% font size |
| `h1`…`h6` | heading sizes as inline classes |
| `pull-left` / `pull-right` | float helpers |
| `clearfix` | contain floats |

**Tables**

| Class | Meaning |
|---|---|
| `table` | base table styling |
| `table-bordered` | cell borders |
| `table-condensed` | tighter padding (ideal for dense statements) |

**Frappe print helpers**

| Class | Meaning |
|---|---|
| `print-heading` | standard print title block |
| `visible-pdf` | show only in the PDF (hidden on screen) |
| `hidden-pdf` | hide in the PDF (visible on screen) |
| `letter-head` / `letter-head-footer` | letter head slots (see §5) |

**Formatting values (Jinja doctype prints)**

- `{{ doc.get_formatted("grand_total") }}` — field formatted per its fieldtype &
  the doc's currency (**preferred** for money).
- `{{ row.get_formatted("rate", doc) }}` — child-row field, currency from parent.
- `{{ frappe.utils.formatdate(doc.posting_date) }}` — user date format.
- `{{ frappe.format_value(value, {"fieldtype": "Currency"}) }}` — ad-hoc format.

> **Template dialect differs by target.** *Doctype* print formats use **Jinja**
> (`{{ doc.field }}`, `{% for %}`). *Report* print formats use the **JS
> micro-template** (`{%= expr %}`, `{% code %}`) — see §7. The grid/utility classes
> are identical in both.

---

## 12. Sample: Sales Invoice print format (Jinja + Bootstrap)

A complete, professional **Sales Invoice** doctype print format built only with
wkhtmltopdf-safe Bootstrap classes. Paste into a Print Format
(`Doctype = Sales Invoice`, `Print Format Type = Jinja`, `Custom = 1`). The
letter head is supplied by the framework (§5) — don't hard-code a banner.

```html
<style>
    /* margins: top-level, longhand (see §2). padding overrides framework 0.75in */
    .print-format {
        padding: 8mm;
        margin-top: 8mm; margin-bottom: 8mm; margin-left: 8mm; margin-right: 8mm;
        font-size: 11px;
    }
    .inv-title { font-size: 20px; font-weight: 700; margin: 0; }
    .box { border: 1px solid #ddd; border-radius: 6px; padding: 8px 10px; }
    .table td, .table th { vertical-align: top; }
    .totals td { padding: 3px 8px; }
    .text-right { font-variant-numeric: tabular-nums; }
    @media print { tr { page-break-inside: avoid; } thead { display: table-header-group; } }
</style>

<!-- ── Header: Bill-To (left) + Invoice meta (right) ───────────────── -->
<div class="row">
    <div class="col-xs-7 column-break">
        <p class="text-muted small" style="margin:0;">{{ _("Bill To") }}</p>
        <strong>{{ doc.customer_name }}</strong><br>
        {{ doc.address_display or "" }}
        {% if doc.tax_id %}<br>{{ _("Tax Id") }}: {{ doc.tax_id }}{% endif %}
    </div>
    <div class="col-xs-5 column-break text-right">
        <p class="inv-title">{{ _("Tax Invoice") }}</p>
        <table class="table table-condensed" style="margin-bottom:0;">
            <tr><td class="text-left text-muted">{{ _("Invoice No") }}</td>
                <td class="text-right"><strong>{{ doc.name }}</strong></td></tr>
            <tr><td class="text-left text-muted">{{ _("Date") }}</td>
                <td class="text-right">{{ frappe.utils.formatdate(doc.posting_date) }}</td></tr>
            <tr><td class="text-left text-muted">{{ _("Due Date") }}</td>
                <td class="text-right">{{ frappe.utils.formatdate(doc.due_date) }}</td></tr>
            {% if doc.po_no %}
            <tr><td class="text-left text-muted">{{ _("PO No") }}</td>
                <td class="text-right">{{ doc.po_no }}</td></tr>
            {% endif %}
        </table>
    </div>
</div>

<!-- ── Items ───────────────────────────────────────────────────────── -->
<table class="table table-bordered table-condensed" style="table-layout:fixed; margin-top:10px;">
    <thead>
        <tr>
            <th class="text-right" style="width:5%;">{{ _("#") }}</th>
            <th style="width:45%;">{{ _("Item") }}</th>
            <th class="text-right" style="width:13%;">{{ _("Qty") }}</th>
            <th class="text-right" style="width:17%;">{{ _("Rate") }}</th>
            <th class="text-right" style="width:20%;">{{ _("Amount") }}</th>
        </tr>
    </thead>
    <tbody>
        {% for row in doc.items %}
        <tr>
            <td class="text-right">{{ row.idx }}</td>
            <td>
                <strong>{{ row.item_name }}</strong>
                {% if row.item_code != row.item_name %}
                    <br><span class="small text-muted">{{ row.item_code }}</span>
                {% endif %}
                {% if row.description and row.description != row.item_name %}
                    <div class="small text-muted">{{ row.description }}</div>
                {% endif %}
            </td>
            <td class="text-right">{{ row.get_formatted("qty") }} {{ row.uom }}</td>
            <td class="text-right">{{ row.get_formatted("rate", doc) }}</td>
            <td class="text-right">{{ row.get_formatted("amount", doc) }}</td>
        </tr>
        {% endfor %}
    </tbody>
</table>

<!-- ── Footer: terms (left) + totals (right) ───────────────────────── -->
<div class="row">
    <div class="col-xs-7 column-break">
        {% if doc.in_words %}
            <p><strong>{{ _("In Words") }}:</strong> {{ doc.in_words }}</p>
        {% endif %}
        {% if doc.terms %}<div class="box small">{{ doc.terms }}</div>{% endif %}
    </div>
    <div class="col-xs-5 column-break">
        <table class="table table-condensed totals">
            <tr><td class="text-left">{{ _("Net Total") }}</td>
                <td class="text-right">{{ doc.get_formatted("net_total") }}</td></tr>
            {% for tax in doc.taxes %}
            <tr><td class="text-left text-muted">{{ tax.description }}</td>
                <td class="text-right">{{ tax.get_formatted("tax_amount", doc) }}</td></tr>
            {% endfor %}
            <tr style="border-top:2px solid #000;">
                <td class="text-left"><strong>{{ _("Grand Total") }}</strong></td>
                <td class="text-right"><strong>{{ doc.get_formatted("grand_total") }}</strong></td></tr>
        </table>
    </div>
</div>

<!-- ── Signature: offset to the right half ─────────────────────────── -->
<div class="row" style="margin-top:35px;">
    <div class="col-xs-5 col-xs-offset-7 text-center">
        <div style="border-top:1px solid #000; padding-top:4px;">
            {{ _("Authorized Signatory") }}
        </div>
    </div>
</div>
```

**What this demonstrates**

- `row` + `col-xs-7` / `col-xs-5` + `column-break` → the classic two-column
  header and footer (float-based → renders in wkhtmltopdf).
- `col-xs-offset-7` → pushes the signature block to the right half.
- `table-bordered table-condensed` + `table-layout:fixed` + `%` widths → a stable,
  page-break-safe items grid.
- `text-right` + `tabular-nums` on money; `text-muted` / `small` for secondary text.
- `doc.get_formatted(...)` / `row.get_formatted(..., doc)` → correct currency &
  number formatting without manual string building.
- Margins via the §2 recipe; letter head left to the framework (§5).

---

## 13. Appendix: file & function reference

| Concern | File | Symbol |
|---|---|---|
| Report menu (Print/PDF) | `public/js/frappe/views/reports/query_report.js` | `get_menu_items` |
| Print dialog + format list | `public/js/frappe/form/print_utils.js` | `get_print_settings` |
| Build report PDF (client) | query_report.js | `pdf_report`, `print_report` |
| Resolve template | query_report.js | `get_custom_format`, `get_print_template`, `get_report_print_format` |
| Filter values (toString bug) | query_report.js | `get_filter_values` |
| Letter head (client) | query_report.js | `render_report_letterhead` |
| Send to server | `public/js/frappe/microtemplate.js` | `frappe.render_pdf` |
| HTML wrapper | `public/html/print_template.html` | Jinja: `print_css`, `content`, `letter_head`, `#footer-html` |
| Report → PDF (server) | `utils/print_format.py` | `report_to_pdf` |
| Letter head (server) | `utils/print_format.py` | `render_letterhead_for_print` |
| Doctype → PDF (generator select) | `utils/print_format.py` | `download_pdf` (`pdf_generator` param) |
| Printview generator select | `www/printview.py` | reads `print_format.pdf_generator` |
| PDF engine (wkhtmltopdf) | `utils/pdf.py` | `get_pdf`, `prepare_options` |
| Margin/@media extraction | `utils/pdf.py` | `read_options_from_html`, `get_print_format_styles` |
| Header/footer/page-number | `utils/pdf.py` | `prepare_header_footer`, `toggle_visible_pdf` |
| PDF engine (chrome) | `utils/pdf.py` | `get_chrome_pdf` |
| chrome options/margins | `utils/pdf_generator/browser.py` | `_parse_pdf_options_from_html`, `prepare_options_for_pdf` |
| Framework `.print-format` CSS | `public/scss/…` → `print.bundle.css` | `.print-format { padding: 0.75in; margin: auto; max-width: 8.3in }` |
| Print Format doctype | `printing/doctype/print_format/print_format.json` | fields: `print_format_for`, `print_format_type`, `report`, `html`, `pdf_generator`, `margin_*` |
| Example report format | `erpnext/accounts/print_format/general_ledger_standard/` | reference schema |

---

