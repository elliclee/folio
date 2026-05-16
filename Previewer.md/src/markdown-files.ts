export type DirectoryEntryLike = {
  name?: string;
  path?: string;
  isFile?: boolean;
  isDirectory?: boolean;
};

export type MarkdownFileItem = {
  type: 'file';
  name: string;
  path: string;
};

export type MarkdownDirectoryItem = {
  type: 'directory';
  name: string;
  path: string;
  children: MarkdownTreeNode[];
};

export type MarkdownTreeNode = MarkdownDirectoryItem | MarkdownFileItem;

const MARKDOWN_FILE_PATTERN = /\.(md|markdown|txt)$/i;

type JoinPath = (first: string, ...rest: string[]) => Promise<string>;
type ReadDirectory = (path: string) => Promise<DirectoryEntryLike[]>;

async function getEntryPath(
  directoryPath: string,
  entry: DirectoryEntryLike,
  joinPath: JoinPath,
): Promise<string | null> {
  if (entry.path) {
    return entry.path;
  }

  if (!entry.name) {
    return null;
  }

  return joinPath(directoryPath, entry.name);
}

export async function collectMarkdownTree(
  directoryPath: string,
  entries: DirectoryEntryLike[],
  readDirectory: ReadDirectory,
  joinPath: JoinPath,
): Promise<MarkdownTreeNode[]> {
  const nodes = await Promise.all(entries.map(async (entry) => {
    if (!entry.name) {
      return null;
    }

    const entryPath = await getEntryPath(directoryPath, entry, joinPath);
    if (!entryPath) {
      return null;
    }

    if (entry.isDirectory) {
      let childEntries: DirectoryEntryLike[];
      try {
        childEntries = await readDirectory(entryPath);
      } catch {
        return null;
      }

      const children = await collectMarkdownTree(entryPath, childEntries, readDirectory, joinPath);
      if (children.length === 0) {
        return null;
      }

      return {
        type: 'directory',
        name: entry.name,
        path: entryPath,
        children,
      } satisfies MarkdownDirectoryItem;
    }

    if (entry.isFile && MARKDOWN_FILE_PATTERN.test(entry.name)) {
      return {
        type: 'file',
        name: entry.name,
        path: entryPath,
      } satisfies MarkdownFileItem;
    }

    return null;
  }));

  return nodes
    .filter((node): node is MarkdownTreeNode => node !== null)
    .sort((left, right) => {
      if (left.type !== right.type) {
        return left.type === 'directory' ? -1 : 1;
      }

      return left.name.localeCompare(right.name);
    });
}

export function getExpandedDirectoryPaths(tree: MarkdownTreeNode[]): string[] {
  return tree.flatMap((node) => {
    if (node.type !== 'directory') {
      return [];
    }

    return [node.path, ...getExpandedDirectoryPaths(node.children)];
  });
}

export function getFirstMarkdownFile(tree: MarkdownTreeNode[]): MarkdownFileItem | null {
  for (const node of tree) {
    if (node.type === 'file') {
      return node;
    }

    const childFile = getFirstMarkdownFile(node.children);
    if (childFile) {
      return childFile;
    }
  }

  return null;
}
