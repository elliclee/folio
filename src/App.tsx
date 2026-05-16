import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeHighlight from 'rehype-highlight';
import { Download, Copy, FileText, Check, LayoutPanelLeft, Palette } from 'lucide-react';

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
  const [markdown, setMarkdown] = useState(DEFAULT_MARKDOWN);
  const [copied, setCopied] = useState(false);
  const [theme, setTheme] = useState('light');

  useEffect(() => {
    document.documentElement.className = theme === 'light' ? '' : `theme-${theme}`;
  }, [theme]);

  const handleCopy = () => {
    navigator.clipboard.writeText(markdown);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([markdown], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'document.md';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div className="h-screen bg-window flex flex-col font-sans text-primary overflow-hidden">
      {/* Header */}
      <header className="h-[50px] bg-header border-b border-border px-4 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <div className="w-7 h-7 bg-accent rounded-md text-accent-fg flex items-center justify-center font-bold text-[14px]">
            <LayoutPanelLeft className="w-4 h-4 text-accent-fg" />
          </div>
          <h1 className="text-[15px] font-semibold text-primary">Markdown Previewer</h1>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-2 border-r border-border pr-4 mr-2">
            <Palette className="w-4 h-4 text-secondary" />
            <select
              value={theme}
              onChange={(e) => setTheme(e.target.value)}
              className="bg-btn-bg text-primary border border-border rounded px-2 py-1 text-[13px] focus:outline-none focus:border-accent cursor-pointer"
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
            {copied ? 'Copied!' : 'Copy Raw'}
          </button>
          <button
            onClick={handleDownload}
            className="flex items-center gap-2 px-3 py-1.5 text-[13px] text-accent-fg bg-accent border border-accent rounded hover:bg-accent-hover cursor-pointer transition-colors"
          >
            <Download className="w-4 h-4" />
            Download .md
          </button>
        </div>
      </header>

      {/* Main Content */}
      <main className="flex-1 flex flex-col md:flex-row overflow-hidden">
        {/* Editor Pane */}
        <div className="flex-1 flex flex-col border-r border-border bg-editor min-w-0">
          <div className="px-6 py-3 flex items-center gap-2 text-[11px] font-semibold tracking-[0.05em] text-muted uppercase">
            <FileText className="w-3.5 h-3.5" />
            Editor
          </div>
          <textarea
            value={markdown}
            onChange={(e) => setMarkdown(e.target.value)}
            className="flex-1 w-full px-6 pb-6 resize-none focus:outline-none font-mono text-[14px] leading-[1.6] text-primary bg-transparent"
            placeholder="Type your markdown here..."
            spellCheck="false"
          />
        </div>

        {/* Preview Pane */}
        <div className="flex-1 flex flex-col bg-preview min-w-0 overflow-y-auto">
          <div className="px-10 py-3 flex items-center gap-2 text-[11px] font-semibold tracking-[0.05em] text-muted uppercase sticky top-0 z-10 bg-preview">
            <LayoutPanelLeft className="w-3.5 h-3.5" />
            Preview
          </div>
          <div className="px-10 pb-10 max-w-4xl mx-auto w-full">
            <div className="prose max-w-none prose-headings:border-b prose-headings:border-border prose-headings:pb-2 prose-h1:text-[28px] prose-headings:text-primary prose-p:text-secondary prose-p:leading-[1.7] prose-li:my-2 prose-li:text-secondary prose-strong:text-primary prose-a:text-accent prose-code:text-primary prose-blockquote:text-secondary prose-blockquote:border-border prose-th:text-primary prose-td:text-secondary prose-hr:border-border prose-pre:bg-[#0d1117] prose-pre:p-0">
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
  );
}
