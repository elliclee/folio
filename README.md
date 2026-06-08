# Folio

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

Folio is a local-first, native macOS Markdown reader and lightweight editor.
It is built entirely with SwiftUI and renders Markdown without a WebView:
[swift-markdown](https://github.com/apple/swift-markdown) parses GitHub
Flavored Markdown and the renderer emits native SwiftUI views and
`AttributedString`s. The focus is comfortable long-form reading, with several
visual themes for different writing styles and lighting conditions.

Folio is the current app and is macOS-only. The original cross-platform
implementation (a React + Tauri app named **PreviewerMD**) still lives in this
repository under [`Previewer.md/`](#previous-version-previewermd-tauri).

## Features

- Open individual Markdown files or browse a folder of Markdown documents.
- Native sidebar file tree with pinned and recent workspace folders.
- Render GitHub Flavored Markdown — headings, lists, task lists, tables,
  blockquotes, strikethrough, links, and fenced code blocks.
- Native syntax highlighting for code blocks (~30 languages, no highlight.js).
- Switch between preview and split editor/preview modes; edits save to disk.
- Find within the current document (⌘F) with highlight and wraparound.
- Print or export to PDF through the native print pipeline (⌘P).
- Multiple workspace windows, each with its own document and theme.
- Open `.md`/`.markdown` files directly from Finder (file associations).
- Choose from several reading themes — Vercel (default), Claude, Claude Dark,
  Lovable, Spotify, Dark, and High Contrast. Warm editorial themes set their
  headings in a serif face.
- Window position and size are restored across launches.

## Requirements

- macOS 15 or newer
- Swift 6 toolchain (Xcode 16 or the matching command-line tools)

## Build & Run

```bash
cd Folio
swift build          # compile
swift test           # run the test suite
swift run            # launch with the welcome document
```

To produce a distributable app bundle (icon + file associations, ad-hoc
signed):

```bash
cd Folio
./scripts/bundle.sh        # → dist/Folio.app
./scripts/bundle.sh --dmg  # → also dist/Folio.dmg
```

Install with `cp -R dist/Folio.app /Applications/`.

Dev conveniences (plain executable, no bundle needed):

```bash
FOLIO_OPEN=~/notes swift run            # open a folder/file at launch
FOLIO_THEME=claude swift run            # seed the reading theme
FOLIO_EXPORT_PDF=/tmp/doc.pdf swift run # headless print-render to PDF
```

## Repository Layout

| Path | Purpose |
| --- | --- |
| `Folio/` | The native macOS SwiftUI app (current). |
| `Previewer.md/` | Original React + Tauri app, **PreviewerMD** (cross-platform). |
| `src/` | Legacy browser-only Markdown previewer prototype. |
| `docs/` | Planning notes and implementation records. |

Inside `Folio/`, the Swift modules map closely to the behavior of the Tauri
app's TypeScript modules (each has tests); see
[`Folio/README.md`](Folio/README.md) for the file-by-file map and milestone
history.

## Previous Version: PreviewerMD (Tauri)

The cross-platform React + TypeScript + Vite + Tauri app remains available for
macOS, Windows, and Linux.

```bash
cd Previewer.md
npm install
npm run tauri -- dev     # develop
npm run tauri -- build   # package
```

Renderer-side code lives in `Previewer.md/src/`; native commands and Tauri
setup live in `Previewer.md/src-tauri/`.

## Security and Privacy

- Folio is local-first and only works with files the user selects.
- Do not commit signing certificates, provisioning profiles, generated
  archives, or platform-specific build output.

## Contributing

Issues and pull requests are welcome. For code changes, include focused tests
when practical and run `swift test` (and, for the Tauri app, its own checks)
before opening a pull request.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
