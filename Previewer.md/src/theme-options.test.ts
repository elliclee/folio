import test from 'node:test';
import assert from 'node:assert/strict';

import { THEME_OPTIONS } from './theme-options';

test('theme options expose Claude Dark next to Claude', () => {
  assert.deepEqual(
    THEME_OPTIONS.map((theme) => theme.value),
    ['light', 'claude', 'claude-dark', 'lovable', 'vercel', 'spotify', 'dark', 'hc'],
  );

  const claudeDark = THEME_OPTIONS.find((theme) => theme.value === 'claude-dark');
  assert.equal(claudeDark?.label, 'Claude Dark');

  const spotify = THEME_OPTIONS.find((theme) => theme.value === 'spotify');
  assert.equal(spotify?.label, 'Spotify');
});
