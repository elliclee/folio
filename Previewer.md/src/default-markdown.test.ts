import test from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_MARKDOWN } from './default-markdown';

test('default markdown introduces how to use PreviewerMD', () => {
  assert.match(DEFAULT_MARKDOWN, /^# PreviewerMD Usage Guide/);
  assert.match(DEFAULT_MARKDOWN, /Open or create Markdown files/);
  assert.match(DEFAULT_MARKDOWN, /Live preview/);
  assert.doesNotMatch(DEFAULT_MARKDOWN, /How to run this locally/);
  assert.doesNotMatch(DEFAULT_MARKDOWN, /使用介绍|实时预览/);
});
