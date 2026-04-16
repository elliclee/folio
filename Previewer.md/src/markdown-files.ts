export type DirectoryEntryLike = {
  name?: string;
  isFile?: boolean;
  isDirectory?: boolean;
};

export type MarkdownFileItem = {
  name: string;
  path: string;
};

const MARKDOWN_FILE_PATTERN = /\.(md|markdown|txt)$/i;

type JoinPath = (first: string, ...rest: string[]) => Promise<string>;

export async function collectMarkdownFiles(
  directoryPath: string,
  entries: DirectoryEntryLike[],
  joinPath: JoinPath,
): Promise<MarkdownFileItem[]> {
  const markdownEntries = entries.filter((entry) => {
    return Boolean(entry.isFile && entry.name && MARKDOWN_FILE_PATTERN.test(entry.name));
  });

  const files = await Promise.all(markdownEntries.map(async (entry) => ({
    name: entry.name as string,
    path: await joinPath(directoryPath, entry.name as string),
  })));

  return files.sort((left, right) => left.name.localeCompare(right.name));
}
