export type NativeInvoke = <T>(
  command: string,
  args?: Record<string, unknown>,
) => Promise<T>;

export type PerformanceProbeConfig = {
  enabled: boolean;
};

export type NativeWorkspaceFolder = {
  name: string;
  path: string;
};

export type NativeDirectoryEntry = {
  name: string;
  path: string;
  isFile: boolean;
  isDirectory: boolean;
};

export type NativeApi = {
  setWindowTheme(theme: string): Promise<void>;
  setRecentWorkspaceFolders(folders: NativeWorkspaceFolder[]): Promise<void>;
  takePendingOpenFiles(): Promise<string[]>;
  printCurrentWindow(): Promise<void>;
  openFolderInNewWindow(folderPath: string, theme: string): Promise<string>;
  openFolderInTerminal(folderPath: string): Promise<void>;
  readDirectory(path: string): Promise<NativeDirectoryEntry[]>;
  readMarkdownFile(path: string): Promise<string>;
  writeMarkdownFile(path: string, contents: string): Promise<void>;
  getPerformanceProbeConfig(): Promise<PerformanceProbeConfig>;
  recordPerformanceMetric(name: string, elapsedMs: number): Promise<void>;
};

export function createNativeApi({ invoke }: { invoke: NativeInvoke }): NativeApi {
  return {
    setWindowTheme(theme) {
      return invoke('set_window_theme', { theme });
    },
    setRecentWorkspaceFolders(folders) {
      return invoke('set_recent_workspace_folders', { folders });
    },
    takePendingOpenFiles() {
      return invoke('take_pending_open_files');
    },
    printCurrentWindow() {
      return invoke('print_current_window');
    },
    openFolderInNewWindow(folderPath, theme) {
      return invoke('open_folder_in_new_window', { folderPath, theme });
    },
    openFolderInTerminal(folderPath) {
      return invoke('open_folder_in_terminal', { folderPath });
    },
    readDirectory(path) {
      return invoke('read_directory', { path });
    },
    readMarkdownFile(path) {
      return invoke('read_markdown_file', { path });
    },
    writeMarkdownFile(path, contents) {
      return invoke('write_markdown_file', { path, contents });
    },
    getPerformanceProbeConfig() {
      return invoke('get_performance_probe_config');
    },
    recordPerformanceMetric(name, elapsedMs) {
      return invoke('record_performance_metric', { name, elapsedMs });
    },
  };
}
