# Folio (Native Swift)

Folio — native macOS rewrite of the PreviewerMD Tauri app (`../Previewer.md/`),
built with SwiftUI and pure-native markdown rendering (no WebView):
[swift-markdown](https://github.com/apple/swift-markdown) parses GFM and
the renderer emits SwiftUI views / `AttributedString`.

## Status

Milestone 1 — core reading experience:

- [x] Open a folder (⌘O) or single markdown file (⌘⇧O)
- [x] Sidebar file tree (md/markdown/txt, empty dirs pruned, dirs-first
      sort, default expansion depth 2 — same rules as `markdown-files.ts`)
- [x] Auto-open first markdown file in an opened folder
- [x] GFM rendering: headings, emphasis, inline/fenced code, blockquotes,
      lists, task lists, tables (with column alignment), strikethrough,
      links, thematic breaks
- [x] Reading themes ported from `index.css`, Vercel as the default
      (Vercel / Claude / Claude Dark / Lovable / Spotify / Dark /
      High Contrast — the separate Light theme was dropped)

Milestone 2 — editing & find (native components first):

- [x] Native unified toolbar (sidebar toggle, Preview/Split segmented
      control, theme picker, find, save) + window title shows the file
- [x] Split editing with a real AppKit `NSTextView` (undo, IME, selection)
- [x] Dirty detection + ⌘S save + native `NSAlert` discard confirmation
      (same rules as `editor-state.ts`)
- [x] Editor/preview percentage scroll sync with active-pane guard
      (ported from `scroll-position.ts`)
- [x] Find in document (⌘F): case-insensitive non-overlapping matching,
      wraparound navigation (↩ / ⇧↩ / esc), all matches highlighted in the
      rendered preview, current match emphasized and scrolled into view

Milestone 3 — syntax highlighting & print/PDF (all native):

- [x] Code-block syntax highlighting via a native single-pass tokenizer
      (no highlight.js): keywords / strings / comments / numbers /
      literals / capitalized types, github-dark colors; ~30 language
      aliases (swift, js/ts, python, rust, go, bash, json, yaml, ruby,
      java/kotlin, c-family, css, sql, html, toml, …)
- [x] Print / Save-as-PDF (⌘P, toolbar button) through a real
      `NSPrintOperation` — markdown re-rendered to a paginating
      `NSAttributedString` with the print stylesheet from pdf-export.ts
      (white page, dark code bands with highlighting, `NSTextTable`
      tables, hanging list indents); job title mirrors
      `getPrintDocumentTitle`
- [x] Headless PDF export hook (`FOLIO_EXPORT_PDF=/path.pdf`)

Milestone 4 — multi-window workspaces:

- [x] Multiple workspace windows (`WindowGroup(for: WorkspaceSeed.self)`),
      each with its own document state; new windows inherit the focused
      window's theme (parity with the Tauri `?folder=…&theme=…` windows)
- [x] File menu: New Window ⌘N, Open Folder ⌘O, Open File ⌥⌘O,
      Open Folder in New Window ⌘⇧O; commands act on the focused window
      via `@FocusedValue`
- [x] Pinned + recent workspace folders (rules ported from
      `workspace-folders.ts`: 5 recents max, dedupe, unpin re-files under
      recents, recents hide pinned paths), persisted in `UserDefaults`,
      shared live across windows
- [x] Fully native sidebar: `NavigationSplitView` + `List(.sidebar)` with
      system material, native selection/disclosure, context menus for
      pin/unpin and open-in-new-window, `ContentUnavailableView` empty
      state, bottom action bar; Pinned section above the workspace tree
- [x] File > Recent Folders submenu with Clear Recent Folders
      ("No Recent Folders" placeholder when empty)
- [x] Window frame persistence via SwiftUI/AppKit autosave (replaces the
      Tauri `window-state.json` + monitor-visibility machinery)

Milestone 5 — app bundle:

- [x] `scripts/bundle.sh` builds `dist/Folio.app` (release build,
      Info.plist, ad-hoc codesign, Launch Services registration);
      `--dmg` also produces `dist/Folio.dmg`
- [x] App icon reused from the Tauri bundle (`icon.icns`)
- [x] md/markdown file associations: double-clicked files route to the
      key window via `application(_:open:)` + `OpenFileRouter` (the
      native counterpart of Tauri's `PendingOpenFiles` queue), with
      files queued when they arrive before the first window exists

Note: the bundled app stores preferences under
`com.ellic.folio.swift`, so pinned/recent folders from unbundled
`swift run` sessions don't carry over.

Planned next: open-in-terminal toolbar action; proper Developer ID
signing/notarization when distributing outside this machine.

## Build & run

```sh
swift build
swift test
swift run                  # opens with the welcome document

./scripts/bundle.sh        # → dist/Folio.app (icon + file associations)
./scripts/bundle.sh --dmg  # → also dist/Folio.dmg
```

Dev conveniences (plain executable, no bundle yet):

```sh
FOLIO_OPEN=~/notes swift run            # open folder/file at launch
FOLIO_THEME=claude-dark swift run       # seed the theme
FOLIO_VIEWMODE=split swift run          # seed preview|split
FOLIO_FIND=query swift run              # open find with a query
FOLIO_SNAPSHOT=/tmp/shot.png swift run  # write a window PNG after ~2s
FOLIO_EXPORT_PDF=/tmp/doc.pdf swift run # headless print-render to PDF
```

`FOLIO_OPEN` is an env var instead of an argv path on purpose:
AppKit treats a path argument as an open-document (odoc) event and then
suppresses the default WindowGroup window.

## Layout

| File | Purpose | Tauri counterpart |
| --- | --- | --- |
| `FolioApp.swift` | App entry, activation policy | `main.rs` / `tauri.conf.json` |
| `AppViewModel.swift` | Observable app state, file/folder loading | `App.tsx` state |
| `MarkdownTree.swift` | Tree scanning rules | `markdown-files.ts` |
| `MarkdownRenderer.swift` | GFM → blocks + AttributedString | `react-markdown` pipeline |
| `Theme.swift` | 8 theme palettes | `index.css` variables |
| `CodeHighlighter.swift` | Native syntax tokenizer | highlight.js |
| `PrintRenderer.swift` / `PrintExporter.swift` | Print/PDF via NSPrintOperation | `pdf-export.ts` + print window |
| `DocumentFind.swift` / `FindBarView.swift` | Find in document | `document-find.ts` |
| `ScrollSync.swift` / `MarkdownEditor.swift` | Split editing + scroll sync | `scroll-position.ts` + textarea |
| `ContentView.swift` / `SidebarView.swift` / `PreviewView.swift` | UI shell | `App.tsx` JSX |
| `DebugSnapshot.swift` | Self-capture debug hook | — |
