type Dirname = (path: string) => Promise<string>;
type Extname = (path: string) => Promise<string>;
type Basename = (path: string, ext?: string) => Promise<string>;
type Join = (...paths: string[]) => Promise<string>;

export function getPrintDocumentTitle(activeFileName: string | null): string {
  if (!activeFileName) {
    return 'PreviewerMD';
  }

  const extensionIndex = activeFileName.lastIndexOf('.');
  if (extensionIndex <= 0) {
    return activeFileName;
  }

  return activeFileName.slice(0, extensionIndex);
}

export function getPdfExportStyles(): string {
  return `
    .pdf-export-root {
      background: #ffffff;
      color: #111827;
      padding: 24px;
      font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
      line-height: 1.7;
    }

    .pdf-export-root .markdown-content {
      max-width: 840px;
      margin: 0 auto;
      padding: 32px;
      color: #111827;
      background: #ffffff;
    }

    .markdown-content h1,
    .markdown-content h2,
    .markdown-content h3,
    .markdown-content h4,
    .markdown-content h5,
    .markdown-content h6 {
      color: #111827 !important;
      border-bottom: none !important;
      padding-bottom: 0 !important;
      page-break-after: avoid;
      break-after: avoid-page;
      orphans: 3;
      widows: 3;
    }

    .markdown-content p,
    .markdown-content li,
    .markdown-content blockquote,
    .markdown-content td,
    .markdown-content th {
      color: #374151 !important;
    }

    .markdown-content ul,
    .markdown-content ol {
      padding-left: 1.5rem;
    }

    .markdown-content li + li {
      margin-top: 0.35rem;
    }

    .markdown-content :not(pre) > code {
      display: inline-block;
      vertical-align: baseline;
      background: #dbeafe !important;
      color: #1e3a8a !important;
      border: 1px solid #bfdbfe !important;
      border-radius: 0.55rem;
      padding: 0.12rem 0.5rem;
      font-weight: 600;
      line-height: 1.35;
    }

    .markdown-content pre,
    .markdown-content blockquote,
    .markdown-content table,
    .markdown-content figure,
    .markdown-content ul,
    .markdown-content ol {
      break-inside: avoid;
      page-break-inside: avoid;
    }

    .markdown-content pre {
      background: #0f172a !important;
      color: #e2e8f0 !important;
      border: 1px solid #1e293b !important;
      border-radius: 1rem;
      padding: 1rem 1.25rem;
      overflow: hidden;
      box-shadow: none !important;
    }

    .markdown-content pre code,
    .markdown-content pre .hljs {
      color: inherit !important;
      background: transparent !important;
      line-height: 1.7;
    }

    .markdown-content table {
      width: 100%;
      border-collapse: collapse;
    }

    .markdown-content img,
    .markdown-content svg {
      max-width: 100%;
      height: auto;
      break-inside: avoid;
      page-break-inside: avoid;
    }

    .markdown-content hr {
      border-color: #e5e7eb !important;
      margin: 2rem 0;
    }
  `;
}

export async function getDefaultPdfSavePath(
  activeFilePath: string | null,
  dirnameFn: Dirname,
  extnameFn: Extname,
  basenameFn: Basename,
  joinFn: Join,
): Promise<string> {
  if (!activeFilePath) {
    return 'document.pdf';
  }

  const directory = await dirnameFn(activeFilePath);
  const extension = await extnameFn(activeFilePath);
  const fileName = await basenameFn(activeFilePath, extension);
  return joinFn(directory, `${fileName}.pdf`);
}
