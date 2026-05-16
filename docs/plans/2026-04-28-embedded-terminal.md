# Embedded Terminal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add an embedded right-side terminal panel to Previewer.md that starts zsh in the current markdown workspace directory.

**Architecture:** React owns the terminal panel UI and xterm instance. Tauri Rust owns PTY sessions, process lifecycle, resize, and output streaming through events. Shared TypeScript helpers resolve the cwd and command metadata so UI behavior is unit-testable.

**Tech Stack:** Tauri 2, React 19, TypeScript, xterm.js, Rust, portable-pty.

---

### Task 1: Terminal Helpers

**Files:**
- Create: `Previewer.md/src/terminal-session.ts`
- Test: `Previewer.md/src/terminal-session.test.ts`
- Modify: `Previewer.md/src/App.tsx`

**Steps:**
1. Write failing tests for resolving terminal cwd from active folder, active file path, initial folder, and fallback.
2. Write failing tests for terminal launcher metadata for the app-managed zsh session.
3. Implement the helper functions.
4. Run `npm test`.

### Task 2: Rust PTY Commands

**Files:**
- Modify: `Previewer.md/src-tauri/Cargo.toml`
- Modify: `Previewer.md/src-tauri/src/lib.rs`

**Steps:**
1. Add failing Rust tests for terminal command validation and cwd validation helpers.
2. Add `portable-pty` and terminal session state.
3. Implement `terminal_start`, `terminal_write`, `terminal_resize`, and `terminal_kill`.
4. Emit terminal output events with session id and byte data.
5. Run `cargo test` from `Previewer.md/src-tauri`.

### Task 3: Right Terminal Panel

**Files:**
- Modify: `Previewer.md/src/App.tsx`
- Modify: `Previewer.md/src/index.css`
- Modify: `Previewer.md/package.json`

**Steps:**
1. Install `@xterm/xterm` and `@xterm/addon-fit`.
2. Add a right-side panel with auto-started zsh, status, cwd display, stop/restart button, close button, and draggable width.
3. Wire xterm input/output to Tauri commands/events.
4. Fit and resize PTY when panel dimensions change.
5. Run `npm test` and `npm run build`.

### Task 4: Verification

**Files:**
- No new files expected.

**Steps:**
1. Run `npm test` in `Previewer.md`.
2. Run `npm run build` in `Previewer.md`.
3. Run `cargo test` in `Previewer.md/src-tauri`.
4. Manually launch the Tauri app if needed and confirm zsh starts from the opened folder and accepts commands like `claude` or `gemini`.
