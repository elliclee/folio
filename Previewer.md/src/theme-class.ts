export const THEME_CLASS_NAMES = [
  'theme-dark',
  'theme-hc',
  'theme-claude',
  'theme-claude-dark',
  'theme-vercel',
  'theme-lovable',
  'theme-spotify',
] as const;

type ThemeDocumentTarget = {
  classList: {
    add: (...tokens: string[]) => void;
    remove: (...tokens: string[]) => void;
  };
};

export function applyThemeClass(target: ThemeDocumentTarget, theme: string) {
  target.classList.remove(...THEME_CLASS_NAMES);

  if (theme === 'light') {
    return;
  }

  target.classList.add(`theme-${theme}`);
}

export function clearThemeClasses(target: ThemeDocumentTarget) {
  target.classList.remove(...THEME_CLASS_NAMES);
}

export function getThemeColorScheme(theme: string) {
  return theme === 'dark' || theme === 'hc' || theme === 'claude-dark' || theme === 'spotify'
    ? 'dark'
    : 'light';
}

export function getAppThemeClass(theme: string) {
  return theme === 'light' ? 'app-shell' : `app-shell theme-${theme}`;
}
