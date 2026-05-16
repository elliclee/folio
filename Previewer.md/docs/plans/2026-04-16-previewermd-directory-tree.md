# PreviewerMD Directory Tree Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show a collapsible directory tree in the left explorer that includes only directories and markdown/text files.

**Architecture:** Replace the current flat file collector with a recursive tree builder that keeps only directories containing markdown descendants and markdown/text file leaves. Update the sidebar to render that tree with expand/collapse state tracked by directory path, defaulting to expanded after opening a folder.

**Tech Stack:** React 19, TypeScript, Tauri plugin-fs.

---

### Task 1: Build the tree data model

**Files:**
- Modify: `Previewer.md/src/markdown-files.ts`
- Modify: `Previewer.md/src/markdown-files.test.ts`

**Step 1: Write the failing tests**

- Add tests for:
  - nested directories with markdown descendants are preserved
  - directories without markdown descendants are dropped
  - directories and files are sorted by name
  - a helper that returns all directory paths expanded by default

**Step 2: Run test to verify it fails**

Run: `npm test`
Expected: FAIL because the tree helpers do not exist yet.

**Step 3: Write minimal implementation**

- Add `MarkdownTreeNode` with `directory` and `file` variants
- Add recursive `collectMarkdownTree`
- Add `getExpandedDirectoryPaths`

**Step 4: Run test to verify it passes**

Run: `npm test`
Expected: PASS for tree tests.

### Task 2: Render the explorer tree

**Files:**
- Modify: `Previewer.md/src/App.tsx`

**Step 1: Wire state**

- Replace flat `files` state with tree state
- Add `expandedDirectories`

**Step 2: Load the tree**

- On folder open, build the tree recursively
- Reset expanded state to all directories expanded
- Auto-open the first markdown leaf if present

**Step 3: Render recursively**

- Add a small recursive sidebar renderer
- Directory rows toggle expand/collapse
- File rows open the document
- Keep active file highlighting

**Step 4: Run verification**

Run: `npm test`
Expected: PASS

### Task 3: Final verification

**Files:**
- Modify as needed: `Previewer.md/src/App.tsx`, `Previewer.md/src/markdown-files.ts`, `Previewer.md/src/markdown-files.test.ts`

**Step 1: Build**

Run: `npm run build`
Expected: PASS

**Step 2: Manual sanity**

- Open a folder with nested markdown files
- Confirm directories expand/collapse
- Confirm only markdown/text leaves show

