import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

const tauriLibPath = join(process.cwd(), 'src-tauri', 'src', 'lib.rs');

test('native Edit menu exposes Find with a platform shortcut', () => {
  const source = readFileSync(tauriLibPath, 'utf8');

  assert.match(source, /FIND_IN_DOCUMENT_MENU_ID/);
  assert.match(source, /"Find"/);
  assert.match(source, /"CmdOrCtrl\+F"/);
  assert.match(source, /find-in-document/);
});
