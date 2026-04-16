# PreviewerMD Branding And DMG Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename the desktop app to `PreviewerMD`, replace the app icon with a minimal blue brand icon, and produce a distributable macOS `.dmg`.

**Architecture:** Keep the existing Tauri build pipeline intact and only update branding surfaces that affect packaging and runtime presentation. Generate all icon sizes from a single SVG source via the local `tauri icon` command so the asset set stays consistent across bundle targets.

**Tech Stack:** Tauri 2, Vite, React, SVG asset generation, macOS Tauri bundling

---

### Task 1: Record the branded packaging surfaces

**Files:**
- Modify: `src-tauri/tauri.conf.json`
- Modify: `index.html`
- Modify: `src/App.tsx`

**Step 1: Update the Tauri-facing product name**

Set `productName` and window title to `PreviewerMD`.

**Step 2: Update web-facing titles**

Set the document title and in-app header title to `PreviewerMD`.

**Step 3: Verify no stale public-facing names remain**

Search for `previewermd` and `Markdown Previewer` outside build artifacts.

### Task 2: Create the icon source

**Files:**
- Create: `src-tauri/app-icon.svg`

**Step 1: Build a single-source icon**

Create a 1024×1024 SVG with a minimal blue rounded-square badge and a simple document/preview motif.

**Step 2: Keep the icon packaging-safe**

Use bold shapes and avoid thin details so the icon remains legible at Dock and Finder sizes.

### Task 3: Generate Tauri icon assets

**Files:**
- Modify: `src-tauri/icons/*`

**Step 1: Run Tauri icon generation**

Run `npm run tauri icon src-tauri/app-icon.svg -- --output src-tauri/icons`.

**Step 2: Verify icon outputs**

Confirm that `.icns`, `.ico`, and PNG targets were regenerated.

### Task 4: Build the macOS bundle

**Files:**
- Output: `src-tauri/target/release/bundle/**`

**Step 1: Run the production bundle**

Run `npm run tauri build`.

**Step 2: Verify the macOS deliverable**

Find the generated `.dmg` and record its exact path.
