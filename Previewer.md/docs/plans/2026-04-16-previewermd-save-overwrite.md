# PreviewerMD Save Overwrite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add desktop-editor style save behavior that overwrites the currently open file, shows unsaved state, supports `Cmd+S` / `Ctrl+S`, and warns before replacing unsaved content.

**Architecture:** Keep file IO inside the existing Tauri frontend using `@tauri-apps/plugin-fs`, and isolate the dirty/switch-save decisions in a tiny pure helper module that can be tested with the existing `tsx --test` setup. Let `App.tsx` own UI state, but drive it with those helper functions so save and file-switch flows stay predictable.

**Tech Stack:** React, Tauri dialog/fs plugins, Node test runner via `tsx --test`

---

### Task 1: Add save-state helper coverage

**Files:**
- Create: `src/editor-state.ts`
- Create: `src/editor-state.test.ts`

**Step 1: Write the failing test**

Cover:
- dirty state when current and saved markdown differ
- no dirty state when content matches
- confirm requirement when switching from one file to another with unsaved changes
- no confirm requirement when reselecting the same file

**Step 2: Run test to verify it fails**

Run: `npm test`
Expected: FAIL because `src/editor-state.ts` does not exist yet

**Step 3: Write minimal implementation**

Implement tiny pure helpers for dirty-state and file-switch checks.

**Step 4: Run test to verify it passes**

Run: `npm test`
Expected: PASS for the new helper test

### Task 2: Wire save behavior into the editor

**Files:**
- Modify: `src/App.tsx`

**Step 1: Track saved content separately**

Add `savedMarkdown`, `isSaving`, and derived dirty state.

**Step 2: Implement overwrite save**

Use `writeTextFile(activeFile.path, markdown)` and update saved state on success.

**Step 3: Add desktop affordances**

Add:
- `Save` button
- `Unsaved` indicator
- `Cmd+S` / `Ctrl+S` keyboard shortcut

**Step 4: Guard destructive navigation**

Before opening another file or replacing the current folder selection, prompt with confirmation if there are unsaved edits.

### Task 3: Verify the feature end-to-end

**Files:**
- Modify: `package-lock.json` only if dependency metadata changes during install (not expected)

**Step 1: Run unit tests**

Run: `npm test`
Expected: PASS

**Step 2: Run production build**

Run: `npm run build`
Expected: PASS

**Step 3: Manual desktop check**

Run: `npm run tauri dev`
Expected: app starts, editing marks file dirty, save overwrites file, and switching files prompts when unsaved
