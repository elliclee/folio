type ReadTextFileFn = (path: string) => Promise<string>;
type WriteTextFileFn = (path: string, contents: string) => Promise<void>;
type ReadMarkdownFileFn = (path: string) => Promise<string>;
type WriteMarkdownFileFn = (path: string, contents: string) => Promise<void>;

export async function readMarkdownFileWithFallback(
  path: string,
  readTextFile: ReadTextFileFn,
  readMarkdownFile: ReadMarkdownFileFn,
): Promise<string> {
  try {
    return await readTextFile(path);
  } catch {
    return readMarkdownFile(path);
  }
}

export async function writeMarkdownFileWithFallback(
  path: string,
  contents: string,
  writeTextFile: WriteTextFileFn,
  writeMarkdownFile: WriteMarkdownFileFn,
): Promise<void> {
  try {
    await writeTextFile(path, contents);
  } catch {
    await writeMarkdownFile(path, contents);
  }
}
