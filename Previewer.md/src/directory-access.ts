import type { DirectoryEntryLike } from './markdown-files';

type ReadDirectoryFn = (path: string) => Promise<DirectoryEntryLike[]>;

export async function readDirectoryWithFallback(
  path: string,
  readDirectory: ReadDirectoryFn,
  readNativeDirectory: ReadDirectoryFn,
): Promise<DirectoryEntryLike[]> {
  try {
    return await readDirectory(path);
  } catch {
    return readNativeDirectory(path);
  }
}
