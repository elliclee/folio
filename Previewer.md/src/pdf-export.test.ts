import test from 'node:test';
import assert from 'node:assert/strict';

import { getDefaultPdfSavePath, getPdfExportStyles, getPrintDocumentTitle } from './pdf-export';

test('getDefaultPdfSavePath uses the active file directory and swaps extension to pdf', async () => {
  const path = await getDefaultPdfSavePath(
    '/tmp/notes/guide.markdown',
    async (input) => input.slice(0, input.lastIndexOf('/')),
    async (input) => input.slice(input.lastIndexOf('.')),
    async (input, ext) => {
      const name = input.slice(input.lastIndexOf('/') + 1);
      return ext && name.endsWith(ext) ? name.slice(0, -ext.length) : name;
    },
    async (...parts) => parts.join('/'),
  );

  assert.equal(path, '/tmp/notes/guide.pdf');
});

test('getDefaultPdfSavePath falls back to document.pdf when no active file exists', async () => {
  const path = await getDefaultPdfSavePath(
    null,
    async () => '',
    async () => '',
    async () => '',
    async (...parts) => parts.join('/'),
  );

  assert.equal(path, 'document.pdf');
});

test('getPdfExportStyles removes heading dividers and keeps inline code aligned', () => {
  const styles = getPdfExportStyles();

  assert.match(styles, /\.markdown-content h1,\s*\.markdown-content h2,/);
  assert.match(styles, /border-bottom:\s*none\s*!important;/);
  assert.match(styles, /\.markdown-content :not\(pre\) > code/);
  assert.match(styles, /display:\s*inline-block;/);
  assert.match(styles, /vertical-align:\s*baseline;/);
});

test('getPdfExportStyles adds page-break protection for rich markdown blocks', () => {
  const styles = getPdfExportStyles();

  assert.match(styles, /\.markdown-content pre,\s*\.markdown-content blockquote,/);
  assert.match(styles, /break-inside:\s*avoid;/);
  assert.match(styles, /page-break-inside:\s*avoid;/);
  assert.match(styles, /\.markdown-content h1,\s*\.markdown-content h2,[\s\S]*page-break-after:\s*avoid;/);
});

test('getPrintDocumentTitle removes the markdown extension for system print save name', () => {
  assert.equal(getPrintDocumentTitle('weekly-review.markdown'), 'weekly-review');
  assert.equal(getPrintDocumentTitle('notes.md'), 'notes');
});

test('getPrintDocumentTitle falls back to PreviewerMD when no file is open', () => {
  assert.equal(getPrintDocumentTitle(null), 'PreviewerMD');
});
