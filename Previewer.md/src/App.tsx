import { useState, useEffect, useRef } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeHighlight from 'rehype-highlight';
import { Download, Copy, FileText, Check, LayoutPanelLeft, Palette, FolderOpen, Columns, Maximize, PanelLeft, Save } from 'lucide-react';
import { confirm, open } from '@tauri-apps/plugin-dialog';
import { WebviewWindow } from '@tauri-apps/api/webviewWindow';
import { invoke } from '@tauri-apps/api/core';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { readDir, readTextFile, writeTextFile } from '@tauri-apps/plugin-fs';
import { join } from '@tauri-apps/api/path';

import { hasUnsavedChanges, shouldConfirmBeforeReplacingFile } from './editor-state';
import { collectMarkdownFiles, type MarkdownFileItem } from './markdown-files';
import { getPrintDocumentTitle } from './pdf-export';
import {
  createPrintJobId,
  getPrintJobIdFromSearch,
  getPrintJobStorageKey,
  isPrintModeSearch,
  type PrintJobPayload,
} from './print-job';

const DEFAULT_MARKDOWN = `# Welcome to Markdown Previewer

This is a fast, real-time Markdown editor and previewer.

## How to run this locally (Offline)

Since this is a pure web application built with React and Vite, you have a few excellent options to run it completely offline on your local machine:

### Option 1: PWA (Progressive Web App) - Easiest
You can install this website directly as a local app if your browser supports it (Chrome, Edge, Safari):
1. Look for the **"Install App"** icon in your browser's address bar (usually on the right side).
2. Click it to install. It will now run in its own window and work completely offline!

### Option 2: Electron (Desktop App)
If you want a true native desktop application (.exe, .dmg, .app):
1. Download the source code.
2. Install \`electron\` and \`electron-builder\`.
3. Wrap this Vite build output inside an Electron browser window.

### Option 3: Tauri (Lightweight Desktop App)
Similar to Electron but uses Rust for a much smaller file size:
1. Initialize a Tauri project in this directory: \`npm create tauri-app@latest\`
2. Point Tauri's \`distDir\` to your Vite build output folder (\`dist\`).
3. Run \`npm run tauri build\` to get your native executable.

---

## Features

- **Live Preview:** See your changes instantly.
- **GitHub Flavored Markdown:** Supports tables, task lists, and more.
- **Syntax Highlighting:** Beautiful code blocks.

### Code Example

\`\`\`javascript
function greet(name) {
  console.log(\`Hello, \${name}!\`);
}
greet('World');
\`\`\`
`;

export default function App() {
  const isPrintMode = isPrintModeSearch(window.location.search);
  const printJobId = getPrintJobIdFromSearch(window.location.search);
  const [markdown, setMarkdown] = useState(DEFAULT_MARKDOWN);
  const [savedMarkdown, setSavedMarkdown] = useState(DEFAULT_MARKDOWN);
  const [copied, setCopied] = useState(false);
  const [isExportingPdf, setIsExportingPdf] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [theme, setTheme] = useState('light');
  
  // New State for Folder and View Mode
  const [viewMode, setViewMode] = useState<'preview' | 'split'>('preview');
  const [files, setFiles] = useState<MarkdownFileItem[]>([]);
  const [activeFile, setActiveFile] = useState<MarkdownFileItem | null>(null);
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const isDirty = Boolean(activeFile && hasUnsavedChanges(markdown, savedMarkdown));
  const [printPayload, setPrintPayload] = useState<PrintJobPayload | null>(null);
  const printStartedRef = useRef(false);

  useEffect(() => {
    document.documentElement.className = theme === 'light' ? '' : `theme-${theme}`;
  }, [theme]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (isPrintMode) {
        return;
      }

      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') {
        event.preventDefault();
        void handleSave();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeFile, isDirty, isSaving, markdown]);

  useEffect(() => {
    if (!isPrintMode || !printJobId) {
      return;
    }

    const rawPayload = localStorage.getItem(getPrintJobStorageKey(printJobId));
    if (!rawPayload) {
      void getCurrentWindow().close();
      return;
    }

    try {
      const parsedPayload = JSON.parse(rawPayload) as PrintJobPayload;
      setPrintPayload(parsedPayload);
    } catch (error) {
      console.error('Failed to parse print job payload:', error);
      localStorage.removeItem(getPrintJobStorageKey(printJobId));
      void getCurrentWindow().close();
    }
  }, [isPrintMode, printJobId]);

  useEffect(() => {
    if (!isPrintMode || !printPayload || !printJobId || printStartedRef.current) {
      return;
    }

    printStartedRef.current = true;

    const originalTitle = document.title;
    const printTitle = getPrintDocumentTitle(printPayload.fileName);
    let cleanedUp = false;

    const cleanup = () => {
      if (cleanedUp) {
        return;
      }

      cleanedUp = true;
      document.body.classList.remove('printing-pdf');
      document.title = originalTitle;
      localStorage.removeItem(getPrintJobStorageKey(printJobId));
      void getCurrentWindow().close();
    };

    document.title = printTitle;
    document.body.classList.add('printing-pdf');
    window.addEventListener('afterprint', cleanup, { once: true });

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(async () => {
        try {
          await invoke('print_current_window');
          window.setTimeout(cleanup, 15000);
        } catch (error) {
          console.error('Failed to open native print dialog:', error);
          cleanup();
        }
      });
    });
  }, [isPrintMode, printJobId, printPayload]);

  const handleCopy = () => {
    navigator.clipboard.writeText(markdown);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadPdf = async () => {
    if (isExportingPdf) {
      return;
    }

    setIsExportingPdf(true);

    const jobId = createPrintJobId();
    const printWindowLabel = `print-${jobId}`;
    const printWindowTitle = getPrintDocumentTitle(activeFile?.name ?? null);
    const payload: PrintJobPayload = {
      markdown,
      fileName: activeFile?.name ?? null,
    };

    localStorage.setItem(getPrintJobStorageKey(jobId), JSON.stringify(payload));

    const url = `${window.location.origin}${window.location.pathname}?printMode=1&printJob=${encodeURIComponent(jobId)}`;
    const printWindow = new WebviewWindow(printWindowLabel, {
      url,
      title: printWindowTitle,
      width: 960,
      height: 1200,
      center: true,
      focus: true,
    });

    printWindow.once('tauri://created', () => {
      setIsExportingPdf(false);
    });

    printWindow.once('tauri://error', (event) => {
      console.error('Failed to create print window:', event);
      localStorage.removeItem(getPrintJobStorageKey(jobId));
      setIsExportingPdf(false);
    });
  };

  const confirmDiscardChanges = async (nextAction: string) => {
    if (!isDirty) {
      return true;
    }

    return confirm(
      `You have unsaved changes. Discard them and continue ${nextAction}?`,
      {
        title: 'Unsaved changes',
        kind: 'warning',
      },
    );
  };

  const handleSave = async () => {
    if (!activeFile || !isDirty || isSaving) {
      return;
    }

    try {
      setIsSaving(true);
      await writeTextFile(activeFile.path, markdown);
      setSavedMarkdown(markdown);
    } catch (err) {
      console.error('Failed to save file:', err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleOpenFolder = async () => {
    try {
      const selectedPath = await open({
        directory: true,
        multiple: false,
        title: 'Open Markdown Folder',
      });

      if (!selectedPath || Array.isArray(selectedPath)) {
        return;
      }

      const entries = await readDir(selectedPath);
      const mdFiles = await collectMarkdownFiles(selectedPath, entries, join);

      if (!(await confirmDiscardChanges('opening a different folder'))) {
        return;
      }

      setFiles(mdFiles);
      if (mdFiles.length > 0) {
        await loadFile(mdFiles[0], true);
      } else {
        setActiveFile(null);
        setMarkdown(DEFAULT_MARKDOWN);
        setSavedMarkdown(DEFAULT_MARKDOWN);
      }
    } catch (err) {
      console.error('Failed to open directory:', err);
    }
  };

  const loadFile = async (fileHandle: MarkdownFileItem, skipConfirm = false) => {
    if (
      !skipConfirm &&
      shouldConfirmBeforeReplacingFile(activeFile?.path ?? null, fileHandle.path, isDirty)
    ) {
      const shouldContinue = await confirmDiscardChanges(`opening ${fileHandle.name}`);
      if (!shouldContinue) {
        return;
      }
    }

    try {
      const text = await readTextFile(fileHandle.path);
      setMarkdown(text);
      setSavedMarkdown(text);
      setActiveFile(fileHandle);
    } catch (err) {
      console.error('Failed to read file:', err);
    }
  };

  if (isPrintMode) {
    return (
      <div className="print-root print-root--screen">
        <div className="print-page">
          <div className="markdown-content prose max-w-none prose-h1:text-[28px] prose-headings:text-primary prose-p:text-secondary prose-p:leading-[1.7] prose-li:my-2 prose-li:text-secondary prose-strong:text-primary prose-a:text-accent prose-blockquote:text-secondary prose-blockquote:border-border prose-th:text-primary prose-td:text-secondary prose-hr:border-border">
            <ReactMarkdown
              remarkPlugins={[remarkGfm]}
              rehypePlugins={[rehypeHighlight]}
            >
              {printPayload?.markdown ?? ''}
            </ReactMarkdown>
          </div>
        </div>
      </div>
    );
  }

  return (
    <>
      <div className="app-shell h-screen bg-window flex flex-col font-sans text-primary overflow-hidden">
      {/* Header */}
      <header className="h-[50px] bg-header border-b border-border px-4 flex items-center justify-between shrink-0">
        <div className="flex items-center">
          <button 
            onClick={() => setIsSidebarOpen(!isSidebarOpen)}
            className="p-1.5 text-secondary hover:bg-btn-hover rounded-md transition-colors"
            title="Toggle Sidebar"
          >
            <PanelLeft className="w-5 h-5" />
          </button>
          {isDirty && (
            <span className="ml-3 hidden sm:inline-flex items-center rounded-full border border-amber-400/60 bg-amber-100 px-2 py-0.5 text-[11px] font-semibold text-amber-800">
              Unsaved
            </span>
          )}
        </div>
        
        <div className="flex items-center gap-2">
          {/* View Mode Toggle */}
          <div className="flex items-center bg-btn-bg border border-border rounded-md p-0.5 mr-2">
            <button
              onClick={() => setViewMode('preview')}
              className={`p-1.5 rounded-sm transition-colors ${viewMode === 'preview' ? 'bg-border text-primary' : 'text-secondary hover:text-primary'}`}
              title="Full Preview"
            >
              <Maximize className="w-4 h-4" />
            </button>
            <button
              onClick={() => setViewMode('split')}
              className={`p-1.5 rounded-sm transition-colors ${viewMode === 'split' ? 'bg-border text-primary' : 'text-secondary hover:text-primary'}`}
              title="Split View"
            >
              <Columns className="w-4 h-4" />
            </button>
          </div>

          <div className="flex items-center gap-2 border-r border-border pr-4 mr-2">
            <Palette className="w-4 h-4 text-secondary hidden sm:block" />
            <select
              value={theme}
              onChange={(e) => setTheme(e.target.value)}
              className="h-[34px] min-w-[160px] bg-btn-bg text-primary border border-border rounded px-3 text-[13px] focus:outline-none focus:border-accent cursor-pointer"
            >
              <option value="light">Light</option>
              <option value="dark">Dark</option>
              <option value="hc">High Contrast</option>
            </select>
          </div>
          <button
            onClick={handleCopy}
            className="flex items-center gap-2 px-3 py-1.5 text-[13px] text-primary bg-btn-bg border border-border rounded hover:bg-btn-hover cursor-pointer transition-colors"
          >
            {copied ? <Check className="w-4 h-4 text-accent" /> : <Copy className="w-4 h-4" />}
            <span className="hidden sm:inline">{copied ? 'Copied!' : 'Copy Raw'}</span>
          </button>
          <button
            onClick={() => void handleSave()}
            disabled={!activeFile || !isDirty || isSaving}
            className="flex items-center gap-2 px-3 py-1.5 text-[13px] text-primary bg-btn-bg border border-border rounded hover:bg-btn-hover disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer transition-colors"
          >
            <Save className="w-4 h-4" />
            <span className="hidden sm:inline">{isSaving ? 'Saving…' : 'Save'}</span>
          </button>
          <button
            onClick={() => void handleDownloadPdf()}
            className="flex items-center gap-2 px-3 py-1.5 text-[13px] text-accent-fg bg-accent border border-accent rounded hover:bg-accent-hover cursor-pointer transition-colors"
            disabled={isExportingPdf}
          >
            <Download className="w-4 h-4" />
            <span className="hidden sm:inline">{isExportingPdf ? 'Opening print dialog…' : 'Save as PDF'}</span>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <div className="flex-1 flex overflow-hidden">
        
        {/* Sidebar (File Explorer) */}
        {isSidebarOpen && (
          <aside className="w-64 border-r border-border bg-editor flex flex-col shrink-0">
            <div className="px-4 py-3 border-b border-border flex items-center justify-between">
              <span className="text-[11px] font-semibold tracking-[0.05em] text-muted uppercase">Explorer</span>
              <button 
                onClick={handleOpenFolder}
                className="p-1 text-secondary hover:text-primary hover:bg-btn-hover rounded transition-colors"
                title="Open Folder"
              >
                <FolderOpen className="w-4 h-4" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto p-2">
              {files.length === 0 ? (
                <div className="text-[13px] text-muted text-center mt-10 px-4">
                  <FolderOpen className="w-8 h-8 mx-auto mb-3 opacity-50" />
                  <p>No folder opened.</p>
                  <button 
                    onClick={handleOpenFolder}
                    className="mt-3 text-accent hover:underline"
                  >
                    Open a folder
                  </button>
                </div>
              ) : (
                <div className="space-y-0.5">
                  {files.map(f => (
                    <div
                      key={f.name}
                      onClick={() => loadFile(f)}
                      className={`px-3 py-2 text-[13px] rounded cursor-pointer flex items-center gap-2 transition-colors ${
                        activeFile?.name === f.name 
                          ? 'bg-accent text-accent-fg' 
                          : 'text-secondary hover:bg-btn-hover hover:text-primary'
                      }`}
                    >
                      <FileText className="w-4 h-4 shrink-0" />
                      <span className="truncate">{f.name}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </aside>
        )}

        {/* Editor & Preview Panes */}
        <main className="flex-1 flex flex-col md:flex-row overflow-hidden">
          
          {/* Editor Pane (Only visible in split mode) */}
          {viewMode === 'split' && (
            <div className="flex-1 flex flex-col border-r border-border bg-editor min-w-0">
              <div className="px-6 py-3 flex items-center gap-2 text-[11px] font-semibold tracking-[0.05em] text-muted uppercase">
                <FileText className="w-3.5 h-3.5" />
                Editor {activeFile && <span className="normal-case font-normal text-secondary ml-2">- {activeFile.name}</span>}
              </div>
              <textarea
                value={markdown}
                onChange={(e) => setMarkdown(e.target.value)}
                className="flex-1 w-full px-6 pb-6 resize-none focus:outline-none font-mono text-[14px] leading-[1.6] text-primary bg-transparent"
                placeholder="Type your markdown here..."
                spellCheck="false"
              />
            </div>
          )}

          {/* Preview Pane */}
          <div className="flex-1 flex flex-col bg-preview min-w-0 overflow-y-auto">
            <div className="px-10 py-3 flex items-center gap-2 text-[11px] font-semibold tracking-[0.05em] text-muted uppercase sticky top-0 z-10 bg-preview">
              <LayoutPanelLeft className="w-3.5 h-3.5" />
              Preview {activeFile && viewMode === 'preview' && <span className="normal-case font-normal text-secondary ml-2">- {activeFile.name}</span>}
            </div>
            <div className="px-10 pb-10 max-w-4xl mx-auto w-full">
              <div className="markdown-content prose max-w-none prose-headings:border-b prose-headings:border-border prose-headings:pb-2 prose-h1:text-[28px] prose-headings:text-primary prose-p:text-secondary prose-p:leading-[1.7] prose-li:my-2 prose-li:text-secondary prose-strong:text-primary prose-a:text-accent prose-blockquote:text-secondary prose-blockquote:border-border prose-th:text-primary prose-td:text-secondary prose-hr:border-border">
                <ReactMarkdown
                  remarkPlugins={[remarkGfm]}
                  rehypePlugins={[rehypeHighlight]}
                >
                  {markdown}
                </ReactMarkdown>
              </div>
            </div>
          </div>

        </main>
      </div>
      </div>
    </>
  );
}
