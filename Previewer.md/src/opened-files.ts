import type { MarkdownFileItem, MarkdownTreeNode } from './markdown-files';

const SUPPORTED_OPEN_PATH_PATTERN = /\.(md|markdown)$/i;

export function filterSupportedOpenPaths(paths: string[]): string[] {
  return paths.filter((path) => SUPPORTED_OPEN_PATH_PATTERN.test(path));
}

export function findTreeFileByPath(
  tree: MarkdownTreeNode[],
  targetPath: string,
): MarkdownFileItem | null {
  for (const node of tree) {
    if (node.type === 'file' && node.path === targetPath) {
      return node;
    }

    if (node.type === 'directory') {
      const nested = findTreeFileByPath(node.children, targetPath);
      if (nested) {
        return nested;
      }
    }
  }

  return null;
}

export function createStandaloneMarkdownFile(path: string): MarkdownFileItem {
  const segments = path.split(/[\\/]/);
  const name = segments.at(-1) ?? path;

  return {
    type: 'file',
    name,
    path,
  };
}
