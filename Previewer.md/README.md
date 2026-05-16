# PreviewerMD

PreviewerMD is a Tauri desktop app for reading and lightly editing Markdown files with a native-feeling shell. It keeps the main workflow focused on Markdown preview, folder navigation, native file access, print/export, document search, and hand-off actions such as opening the current folder in the system terminal.

## Development

```bash
npm install
npm run tauri -- dev
```

The app is built with React, TypeScript, Vite, and Tauri. Rust commands live in `src-tauri/src/lib.rs`; renderer-side native IPC is wrapped by `src/native-api.ts`.

## Verification Checklist

Run this checklist before tagging, sharing, or packaging a new desktop build:

1. Run unit and renderer contract tests.
   ```bash
   npm test
   ```
2. Run Rust command and lifecycle tests.
   ```bash
   cargo test --manifest-path src-tauri/Cargo.toml
   ```
3. Build the web renderer.
   ```bash
   npm run build
   ```
4. Check the performance budget.
   ```bash
   npm run perf:gate
   ```
5. Build the signed local app bundle and installer artifacts.
   ```bash
   npm run tauri -- build
   ```
6. Smoke-test the generated app manually:
   - Open a Markdown file and a folder.
   - Resize and reposition the window, quit, and reopen to confirm window state is restored.
   - Use document search with `Cmd+F` on macOS or `Ctrl+F` on Windows/Linux.
   - Toggle edit mode and verify file changes are intentional.
   - Use print/export from the app menu.
   - Click the terminal action while a folder is open and confirm the system terminal starts in that folder.

## Release Artifacts

On macOS, `npm run tauri -- build` writes the local app bundle and DMG here:

- `src-tauri/target/release/bundle/macos/PreviewerMD.app`
- `src-tauri/target/release/bundle/dmg/PreviewerMD_0.4.1_aarch64.dmg`

The first macOS terminal hand-off may ask for Automation permission because PreviewerMD asks Terminal to open directly in the selected folder.
