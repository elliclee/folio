# PreviewerMD

[English](README.md) | [简体中文](README.zh-CN.md) | [日本語](README.ja.md)

PreviewerMD is a local-first Markdown reader and lightweight editor built with
React, TypeScript, Vite, and Tauri. This README focuses on the desktop app.

## Screenshots

![PreviewerMD preview mode](docs/screenshots/previewermd-preview.jpg)

![PreviewerMD split editor and preview mode](docs/screenshots/previewermd-split-view.jpg)

## Status

PreviewerMD is ready for local development and packaging. The desktop app is the
current release target.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `Previewer.md/` | Main Tauri desktop app for macOS, Windows, and Linux. |
| `src/` | Legacy browser-only Markdown previewer prototype. |
| `docs/` | Planning notes and implementation records. |

## Features

- Open individual Markdown files or browse a folder of Markdown documents.
- Render GitHub Flavored Markdown with syntax-highlighted code blocks.
- Switch between preview and split editor/preview modes.
- Save intentional edits back to disk.
- Search within the current document.
- Print or export rendered Markdown.
- Preserve native-feeling window behavior and theme choices.
- Open the active folder in the system terminal.

## Requirements

- Node.js 20 or newer
- npm 10 or newer
- Rust stable toolchain
- Tauri 2 platform prerequisites for your OS

For OS-specific Tauri setup, follow the official Tauri prerequisites before
running the desktop shell.

## Desktop Development

```bash
cd Previewer.md
npm install
npm run tauri -- dev
```

Useful commands:

```bash
npm test
npm run build
npm run perf:gate
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri -- build
```

The renderer-side app code lives in `Previewer.md/src/`. Native commands and
Tauri setup live in `Previewer.md/src-tauri/`.

## Legacy Web Prototype

The repository root contains an older browser-only previewer. It can still be run
with:

```bash
npm install
npm run dev
```

This prototype is separate from the production Tauri desktop app.

## Verification Before Release

Run the desktop checks before tagging or publishing a build:

```bash
cd Previewer.md
npm test
npm run build
npm run perf:gate
cargo test --manifest-path src-tauri/Cargo.toml
```

Then smoke-test a packaged app:

- Open a Markdown file and a folder.
- Resize and reposition the window, quit, and reopen.
- Use document search with `Cmd+F` on macOS or `Ctrl+F` on Windows/Linux.
- Toggle edit mode and confirm saves are intentional.
- Print or export the current document.
- Open the current folder in the system terminal.

## Security And Privacy

- PreviewerMD is local-first and works with files selected by the user.
- Do not commit real `.env` files, signing certificates, provisioning profiles,
  generated archives, or platform-specific build output.
- `.env.example` contains placeholder values only.
- Before publishing a public release, rotate any signing material that may have
  been used in local experiments.

## Contributing

Issues and pull requests are welcome. For code changes, include focused tests
when practical and run the relevant verification commands above before opening a
pull request.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
