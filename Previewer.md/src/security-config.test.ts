import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

type TauriConfig = {
  app?: {
    security?: {
      csp?: string | null;
    };
  };
};

const sourceDir = dirname(fileURLToPath(import.meta.url));

function readDesktopTauriConfig(): TauriConfig {
  return JSON.parse(
    readFileSync(join(sourceDir, '..', 'src-tauri', 'tauri.conf.json'), 'utf8'),
  ) as TauriConfig;
}

test('desktop Tauri config uses an explicit CSP instead of disabling it', () => {
  const csp = readDesktopTauriConfig().app?.security?.csp;

  assert.equal(typeof csp, 'string');
  assert.notEqual(csp, null);
  assert.match(csp ?? '', /default-src 'self'/);
  assert.match(csp ?? '', /script-src 'self'/);
});

test('desktop CSP does not allow eval or arbitrary remote code', () => {
  const csp = readDesktopTauriConfig().app?.security?.csp ?? '';

  assert.equal(csp.includes("'unsafe-eval'"), false);
  assert.equal(csp.includes('https:'), false);
  assert.equal(csp.includes('*'), false);
});
