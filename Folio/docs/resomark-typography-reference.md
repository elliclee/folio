# Resomark typography — reverse-engineered reference

Extracted locally from `Resomark.app/Contents/Resources/ResoEditor/chunks/`
(a CodeMirror-based live-preview editor; WebKit/WKWebView shell). Recorded
here only as a **design reference** for tuning Folio's own renderer.

## How Resomark is built

- Native Swift app that renders Markdown in a **CodeMirror 6 live preview**
  (WYSIWYG, like Typora) — not a separate HTML preview pane.
- Markdown layout lives in CodeMirror line-decoration classes (`.cm-lp-*`)
  in `mdThemes-C22CtjKJ.css`.
- Themes (`mdThemes-01JbW1k7.js`) only swap **colors** (syntax + heading +
  link). The typographic layout below is shared across all 18 themes
  (github-light/dark, nord, dracula, one-dark, solarized, material,
  tokyo-night, forest, ink-blue, and the signature `resomark-light/dark`).

## Body / base

| Token | Value |
| --- | --- |
| Body font | `-apple-system, BlinkMacSystemFont, …` (system sans) |
| Body size | `15px` (`--editor-font-size`) |
| Body line-height | **1.6** |
| Content vertical padding | `25px` top |
| Code font size | `0.867em` of body, line-height `1.5` |

## Heading scale (the key bit)

Resomark uses a **1.0667 → larger ratio**, all headings at `line-height: 1.2`:

| Level | font-size | weight | padding-top / bottom |
| --- | --- | --- | --- |
| h1 | `1.867em` | 700 | 24 / 12 |
| h2 | `1.6em`   | 700 | 20 / 10 |
| h3 | `1.4em`   | 600 | 16 / 8 |
| h4 | `1.2em`   | 600 | 12 / 6 |
| h5 | `1.067em` | 600 | 12 / 6 |
| h6 | `1.067em` | 600 | 12 / 6 |

(At 15px body: h1≈28px, h2≈24px, h3≈21px, h4≈18px, h5/h6≈16px.)

Notes vs. Folio's current scale (30.5/22.5/18.5/16.5 px, serif on warm
themes): Resomark's h1 is a touch smaller, the steps are tighter and more
even, headings keep a snug `1.2` leading, and **spacing is asymmetric**
(more padding above than below — pulls a heading toward the text it
introduces). No serif; no underline rules.

## Blocks

- **Blockquote**: left padding `--bq-pad`; no heavy bar — the color/box
  comes from theme tokens (`--md-*`), kept subtle.
- **Callouts** (note/tip/important/warning/caution): tinted background
  blocks with `6px` radius, `--card-padding-x/y`, first/last rows round the
  corners — a richer admonition style than plain blockquotes.
- **Code fences**: `--md-code-bg` background, `6px` top radius, an `8px`
  transparent top border as breathing room, meta in `--md-meta`.
- **HR**: `12px` vertical padding, a single `1px` center line via a
  `linear-gradient` background (not a `border`).
- **Lists**: list marker `margin-right: 6px`, color inherits.
- **Paragraphs/divs** (HTML blocks): `margin: 10px 0`.

## Color tokens — `resomark-light` / `resomark-dark`

Syntax + heading/link colors only (layout is shared):

```
resomark-light  heading #1d1d1f  link #0a84ff
  keyword #7c3aed  string #9a3412  number #b45309  type #0f766e
  function #0369a1  comment #6e7781  variable #1f2937  punctuation #545458

resomark-dark   heading #f5f5f7  link #64d2ff
  keyword #c4b5fd  string #fca5a5  number #fdba74  type #5eead4
  function #7dd3fc  comment #9898a0  variable #e5e7eb  punctuation #b8b8c0
```

## If we want to borrow this for Folio

Cheap, high-impact tweaks to `MarkdownTypography` / `PreviewView`:

1. Adopt the **even heading ratios** (1.867 / 1.6 / 1.4 / 1.2 / 1.067 × body)
   instead of the current hand-picked px sizes.
2. Heading **line-height 1.2** + **asymmetric padding** (top > bottom).
3. Body **line-height 1.6** (Folio is ~1.66 — already close).
4. Optional: Resomark's **callout blocks** for `> [!NOTE]`-style admonitions
   (Folio currently renders those as plain blockquotes).
