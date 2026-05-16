import test from 'node:test';
import assert from 'node:assert/strict';

import { applyThemeClass, clearThemeClasses, getAppThemeClass, getThemeColorScheme, THEME_CLASS_NAMES } from './theme-class';

test('applyThemeClass preserves unrelated document classes while replacing theme classes', () => {
  const classList = new Set<string>(['app-ready', 'theme-dark']);

  const target = {
    get className() {
      return Array.from(classList).join(' ');
    },
    set className(value: string) {
      classList.clear();
      value
        .split(/\s+/)
        .filter(Boolean)
        .forEach((token) => classList.add(token));
    },
    classList: {
      add: (...tokens: string[]) => tokens.forEach((token) => classList.add(token)),
      remove: (...tokens: string[]) => tokens.forEach((token) => classList.delete(token)),
    },
  };

  applyThemeClass(target, 'claude-dark');

  assert.deepEqual(Array.from(classList).sort(), ['app-ready', 'theme-claude-dark']);
});

test('applyThemeClass removes theme classes entirely for light theme', () => {
  const classList = new Set<string>(['theme-claude', 'theme-dark', 'other']);

  const target = {
    classList: {
      add: (...tokens: string[]) => tokens.forEach((token) => classList.add(token)),
      remove: (...tokens: string[]) => tokens.forEach((token) => classList.delete(token)),
    },
  };

  applyThemeClass(target, 'light');

  assert.deepEqual(Array.from(classList).sort(), ['other']);
});

test('clearThemeClasses removes any stale global theme classes while preserving unrelated classes', () => {
  const classList = new Set<string>(['theme-claude', 'theme-lovable', 'app-ready']);

  const target = {
    classList: {
      add: (...tokens: string[]) => tokens.forEach((token) => classList.add(token)),
      remove: (...tokens: string[]) => tokens.forEach((token) => classList.delete(token)),
    },
  };

  clearThemeClasses(target);

  assert.deepEqual(Array.from(classList).sort(), ['app-ready']);
});

test('theme class registry includes every custom theme class', () => {
  assert.deepEqual(THEME_CLASS_NAMES, [
    'theme-dark',
    'theme-hc',
    'theme-claude',
    'theme-claude-dark',
    'theme-vercel',
    'theme-lovable',
    'theme-spotify',
  ]);
});

test('getThemeColorScheme treats claude-dark as dark chrome', () => {
  assert.equal(getThemeColorScheme('light'), 'light');
  assert.equal(getThemeColorScheme('claude-dark'), 'dark');
  assert.equal(getThemeColorScheme('spotify'), 'dark');
  assert.equal(getThemeColorScheme('dark'), 'dark');
  assert.equal(getThemeColorScheme('hc'), 'dark');
});

test('getAppThemeClass localizes theme classes to the app shell', () => {
  assert.equal(getAppThemeClass('light'), 'app-shell');
  assert.equal(getAppThemeClass('lovable'), 'app-shell theme-lovable');
  assert.equal(getAppThemeClass('claude-dark'), 'app-shell theme-claude-dark');
});
