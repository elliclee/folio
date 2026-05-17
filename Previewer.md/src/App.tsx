import { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import ReactMarkdown, { type Options as ReactMarkdownOptions } from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { Download, Copy, FileText, Check, LayoutPanelLeft, Palette, FolderOpen, FolderPlus, Columns, Maximize, PanelLeft, Save, ChevronDown, ChevronRight, ChevronUp, Folder, SquareTerminal, X, Search, Pin, PinOff } from 'lucide-react';
import { confirm, message, open } from '@tauri-apps/plugin-dialog';
import { WebviewWindow } from '@tauri-apps/api/webviewWindow';
import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { readDir, readTextFile, writeTextFile } from '@tauri-apps/plugin-fs';
import { dirname, homeDir, join } from '@tauri-apps/api/path';

import { hasUnsavedChanges, shouldConfirmBeforeReplacingFile } from './editor-state';
import {
  collectMarkdownTree,
  getExpandedDirectoryPaths,
  getFirstMarkdownFile,
  wrapMarkdownTreeInRootDirectory,
  type MarkdownFileItem,
  type MarkdownTreeNode,
} from './markdown-files';
import { readMarkdownFileWithFallback, writeMarkdownFileWithFallback } from './file-access';
import { readDirectoryWithFallback } from './directory-access';
import {
  createStandaloneMarkdownFile,
  filterSupportedOpenPaths,
  findTreeFileByPath,
} from './opened-files';
import { getPrintDocumentTitle } from './pdf-export';
import {
  createPrintJobId,
  getPrintJobIdFromSearch,
  getPrintJobStorageKey,
  isPrintModeSearch,
  type PrintJobPayload,
} from './print-job';
import { clearThemeClasses, getAppThemeClass, getThemeColorScheme } from './theme-class';
import { THEME_OPTIONS } from './theme-options';
import { shouldStartWindowDrag, shouldToggleWindowMaximize } from './window-drag';
import { createScrollSyncController, resetScrollPositions } from './scroll-position';
import {
  getInitialFolderPathFromSearch,
  getInitialThemeFromSearch,
} from './workspace-window';
import {
  clearRecentWorkspaceFolders,
  loadWorkspaceFolders,
  pinWorkspaceFolder,
  rememberRecentWorkspaceFolder,
  saveWorkspaceFolders,
  unpinWorkspaceFolder,
  WORKSPACE_FOLDERS_STORAGE_KEY,
  type WorkspaceFolder,
  type WorkspaceFolderState,
} from './workspace-folders';
import { resolveTerminalCwd } from './terminal-session';
import { DEFAULT_MARKDOWN } from './default-markdown';
import { createNativeApi, type PerformanceProbeConfig } from './native-api';
import {
  findMarkdownMatches,
  getNextFindMatchIndex,
} from './document-find';
import {
  isEscapeKey,
  isFindShortcut,
  isSaveShortcut,
} from './native-shortcuts';
const nativeApi = createNativeApi({ invoke });
const OPEN_RECENT_FOLDER_EVENT = 'open-recent-folder';
const CLEAR_RECENT_FOLDERS_EVENT = 'clear-recent-folders';

const DISABLED_PERFORMANCE_PROBE: PerformanceProbeConfig = {
  enabled: false,
};

function runWebviewFind(query: string, direction: 1 | -1) {
  const find = (window as Window & {
    find?: (
      query: string,
      caseSensitive?: boolean,
      backwards?: boolean,
      wrapAround?: boolean,
      wholeWord?: boolean,
      searchInFrames?: boolean,
      showDialog?: boolean,
    ) => boolean;
  }).find;

  if (!find || !query.trim()) {
    return;
  }

  find(query, false, direction === -1, true, false, false, false);
}

export default function App() {
  const isPrintMode = isPrintModeSearch(window.location.search);
  const printJobId = getPrintJobIdFromSearch(window.location.search);
  const [markdown, setMarkdown] = useState(DEFAULT_MARKDOWN);
  const [savedMarkdown, setSavedMarkdown] = useState(DEFAULT_MARKDOWN);
  const [copied, setCopied] = useState(false);
  const [isExportingPdf, setIsExportingPdf] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [theme, setTheme] = useState(() => getInitialThemeFromSearch(window.location.search) ?? 'light');
  
  // New State for Folder and View Mode
  const [viewMode, setViewMode] = useState<'preview' | 'split'>('preview');
  const [tree, setTree] = useState<MarkdownTreeNode[]>([]);
  const [activeFile, setActiveFile] = useState<MarkdownFileItem | null>(null);
  const [isSidebarOpen, setIsSidebarOpen] = useState(true);
  const [workspaceFolders, setWorkspaceFolders] = useState<WorkspaceFolderState>(() => loadWorkspaceFolders(window.localStorage));
  const [isFindOpen, setIsFindOpen] = useState(false);
  const [findQuery, setFindQuery] = useState('');
  const [findMatchIndex, setFindMatchIndex] = useState(-1);
  const [rehypePlugins, setRehypePlugins] = useState<ReactMarkdownOptions['rehypePlugins']>([]);
  const [performanceProbeConfig, setPerformanceProbeConfig] = useState<PerformanceProbeConfig>(DISABLED_PERFORMANCE_PROBE);
  const [terminalFallbackPath, setTerminalFallbackPath] = useState<string | null>(null);
  const [currentFolderPath, setCurrentFolderPath] = useState<string | null>(() => getInitialFolderPathFromSearch(window.location.search));
  const [expandedDirectories, setExpandedDirectories] = useState<Set<string>>(new Set());
  const isDirty = Boolean(activeFile && hasUnsavedChanges(markdown, savedMarkdown));
  const [printPayload, setPrintPayload] = useState<PrintJobPayload | null>(null);
  const printStartedRef = useRef(false);
  const pendingExternalPathRef = useRef<string | null>(null);
  const activeFilePathRef = useRef<string | null>(null);
  const isDirtyRef = useRef(false);
  const initialFolderPathRef = useRef(getInitialFolderPathFromSearch(window.location.search));
  const previewPaneRef = useRef<HTMLDivElement | null>(null);
  const editorTextareaRef = useRef<HTMLTextAreaElement | null>(null);
  const findInputRef = useRef<HTMLInputElement | null>(null);
  const scrollSyncControllerRef = useRef(createScrollSyncController());
  const performanceProbeConfigRef = useRef<PerformanceProbeConfig>(DISABLED_PERFORMANCE_PROBE);
  const syntaxHighlightMetricRecordedRef = useRef(false);
  const findMatches = useMemo(() => findMarkdownMatches(markdown, findQuery), [findQuery, markdown]);
  const updateWorkspaceFolders = useCallback((updater: (state: WorkspaceFolderState) => WorkspaceFolderState) => {
    setWorkspaceFolders((current) => updater(current));
  }, []);

  const rememberWorkspaceFolder = useCallback((folderPath: string) => {
    updateWorkspaceFolders((current) => rememberRecentWorkspaceFolder(current, folderPath));
  }, [updateWorkspaceFolders]);

  const recordPerformanceMetric = useCallback((name: string) => {
    if (!performanceProbeConfigRef.current.enabled) {
      return;
    }

    void nativeApi.recordPerformanceMetric(name, performance.now()).catch((error) => {
      console.error('Failed to record performance metric:', error);
    });
  }, []);

  useEffect(() => {
    performanceProbeConfigRef.current = performanceProbeConfig;
  }, [performanceProbeConfig]);

  useEffect(() => {
    clearThemeClasses(document.documentElement);
    document.documentElement.style.colorScheme = getThemeColorScheme(theme);
  }, [theme]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    saveWorkspaceFolders(window.localStorage, workspaceFolders);
  }, [isPrintMode, workspaceFolders]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    void nativeApi.setRecentWorkspaceFolders(workspaceFolders.recent).catch((error) => {
      console.error('Failed to update recent folders menu:', error);
    });
  }, [isPrintMode, workspaceFolders.recent]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    const syncWorkspaceFolders = (event: StorageEvent) => {
      if (event.key !== WORKSPACE_FOLDERS_STORAGE_KEY) {
        return;
      }

      setWorkspaceFolders(loadWorkspaceFolders(window.localStorage));
    };

    window.addEventListener('storage', syncWorkspaceFolders);
    return () => window.removeEventListener('storage', syncWorkspaceFolders);
  }, [isPrintMode]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    void nativeApi.setWindowTheme(theme);
  }, [isPrintMode, theme]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    let isMounted = true;

    void nativeApi.getPerformanceProbeConfig().then((config) => {
      if (!isMounted) {
        return;
      }

      performanceProbeConfigRef.current = config;
      setPerformanceProbeConfig(config);

      if (config.enabled) {
        window.requestAnimationFrame(() => {
          void nativeApi.recordPerformanceMetric('app.first_render', performance.now());
        });
      }
    }).catch((error) => {
      console.error('Failed to load performance probe config:', error);
    });

    return () => {
      isMounted = false;
    };
  }, [isPrintMode]);

  useEffect(() => {
    let isMounted = true;

    void import('rehype-highlight').then((module) => {
      if (isMounted) {
        setRehypePlugins([module.default]);
      }
    });

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    if (
      !performanceProbeConfig.enabled
      || !rehypePlugins?.length
      || syntaxHighlightMetricRecordedRef.current
    ) {
      return;
    }

    syntaxHighlightMetricRecordedRef.current = true;
    recordPerformanceMetric('app.syntax_highlight_ready');
  }, [performanceProbeConfig.enabled, recordPerformanceMetric, rehypePlugins]);

  const openFind = useCallback(() => {
    setIsFindOpen(true);
  }, []);

  const closeFind = useCallback(() => {
    setIsFindOpen(false);
    setFindQuery('');
    setFindMatchIndex(-1);
  }, []);

  const moveFindMatch = useCallback((direction: 1 | -1) => {
    setFindMatchIndex((currentIndex) => {
      const nextIndex = getNextFindMatchIndex(currentIndex, findMatches.length, direction);
      runWebviewFind(findQuery, direction);
      return nextIndex;
    });
  }, [findMatches.length, findQuery]);

  useEffect(() => {
    setFindMatchIndex(findMatches.length > 0 ? 0 : -1);
  }, [findMatches.length, findQuery]);

  useEffect(() => {
    if (!isFindOpen) {
      return;
    }

    const focusTimer = window.setTimeout(() => {
      findInputRef.current?.focus();
      findInputRef.current?.select();
    }, 0);

    return () => window.clearTimeout(focusTimer);
  }, [isFindOpen]);

  const handleHeaderMouseDown = (event: React.MouseEvent<HTMLElement>) => {
    if (
      !shouldStartWindowDrag(
        event.target,
        event.button,
        event.detail,
      )
    ) {
      return;
    }

    void getCurrentWindow().startDragging();
  };

  const handleHeaderDoubleClick = (event: React.MouseEvent<HTMLElement>) => {
    if (
      !shouldToggleWindowMaximize(
        event.target,
        event.button,
        event.detail,
      )
    ) {
      return;
    }

    void getCurrentWindow().toggleMaximize().catch((error) => {
      console.error('Failed to toggle window maximize state:', error);
    });
  };

  useEffect(() => {
    activeFilePathRef.current = activeFile?.path ?? null;
    isDirtyRef.current = isDirty;
  }, [activeFile?.path, isDirty]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    void homeDir()
      .then((path) => setTerminalFallbackPath(path))
      .catch(() => setTerminalFallbackPath('/'));
  }, [isPrintMode]);

  useEffect(() => () => {
    scrollSyncControllerRef.current.dispose();
  }, []);

  const syncPaneScroll = useCallback((
    sourcePane: 'editor' | 'preview',
    source: HTMLTextAreaElement | HTMLDivElement,
    target: HTMLTextAreaElement | HTMLDivElement | null,
  ) => {
    scrollSyncControllerRef.current.handleScroll(sourcePane, source, target);
  }, []);

  const resetDocumentView = () => {
    resetScrollPositions([previewPaneRef.current, editorTextareaRef.current]);
  };

  const loadTreeForFilePath = async (filePath: string) => {
    try {
      const directoryPath = await dirname(filePath);
      const entries = await readDirectoryWithFallback(
        directoryPath,
        readDir,
        nativeApi.readDirectory,
      );
      const markdownTree = await collectMarkdownTree(
        directoryPath,
        entries,
        async (path) => readDirectoryWithFallback(path, readDir, nativeApi.readDirectory),
        join,
      );
      const matchedFile = findTreeFileByPath(markdownTree, filePath);

      if (markdownTree.length > 0) {
        setTree(markdownTree);
        setExpandedDirectories(new Set(getExpandedDirectoryPaths(markdownTree)));
      }

      return matchedFile ?? createStandaloneMarkdownFile(filePath);
    } catch {
      const standaloneFile = createStandaloneMarkdownFile(filePath);
      setTree([standaloneFile]);
      setExpandedDirectories(new Set());
      return standaloneFile;
    }
  };

  const openMarkdownPathFromSystem = async (filePath: string) => {
    const [nextPath] = filterSupportedOpenPaths([filePath]);
    if (!nextPath) {
      return;
    }

    if (pendingExternalPathRef.current === nextPath) {
      return;
    }

    pendingExternalPathRef.current = nextPath;

    try {
      const externalFile = createStandaloneMarkdownFile(nextPath);
      if (
        shouldConfirmBeforeReplacingFile(
          activeFilePathRef.current,
          externalFile.path,
          isDirtyRef.current,
        )
      ) {
        const shouldContinue = await confirm(
          `You have unsaved changes. Discard them and continue opening ${externalFile.name}?`,
          {
            title: 'Unsaved changes',
            kind: 'warning',
          },
        );

        if (!shouldContinue) {
          return;
        }
      }

      const fileHandle = await loadTreeForFilePath(nextPath);
      const text = await readMarkdownFileWithFallback(
        fileHandle.path,
        readTextFile,
        nativeApi.readMarkdownFile,
      );
      resetDocumentView();
      setCurrentFolderPath(null);
      setMarkdown(text);
      setSavedMarkdown(text);
      setActiveFile(fileHandle);
    } finally {
      pendingExternalPathRef.current = null;
    }
  };

  const loadFile = async (fileHandle: MarkdownFileItem, skipConfirm = false) => {
    if (
      !skipConfirm &&
      shouldConfirmBeforeReplacingFile(activeFile?.path ?? null, fileHandle.path, isDirty)
    ) {
      const shouldContinue = await confirmDiscardChanges(`opening ${fileHandle.name}`);
      if (!shouldContinue) {
        return;
      }
    }

    try {
      const text = await readMarkdownFileWithFallback(
        fileHandle.path,
        readTextFile,
        nativeApi.readMarkdownFile,
      );
      resetDocumentView();
      setMarkdown(text);
      setSavedMarkdown(text);
      setActiveFile(fileHandle);
    } catch (err) {
      console.error('Failed to read file:', err);
    }
  };

  const loadFolder = async (selectedPath: string, skipConfirm = false) => {
    try {
      const entries = await readDirectoryWithFallback(
        selectedPath,
        readDir,
        nativeApi.readDirectory,
      );
      const markdownTree = await collectMarkdownTree(
        selectedPath,
        entries,
        async (path) => readDirectoryWithFallback(path, readDir, nativeApi.readDirectory),
        join,
      );
      const workspaceTree = wrapMarkdownTreeInRootDirectory(selectedPath, markdownTree);

      if (!skipConfirm && !(await confirmDiscardChanges('opening a different folder'))) {
        return;
      }

      setCurrentFolderPath(selectedPath);
      rememberWorkspaceFolder(selectedPath);
      setTree(workspaceTree);
      setExpandedDirectories(new Set(getExpandedDirectoryPaths(workspaceTree)));

      const firstFile = getFirstMarkdownFile(markdownTree);
      if (firstFile) {
        await loadFile(firstFile, true);
        return;
      }

      setActiveFile(null);
      setMarkdown(DEFAULT_MARKDOWN);
      setSavedMarkdown(DEFAULT_MARKDOWN);
    } catch (err) {
      console.error('Failed to open directory:', err);
      await message(String(err), {
        title: 'Open Folder',
        kind: 'error',
      });
    }
  };

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    const initialFolderPath = initialFolderPathRef.current;
    if (!initialFolderPath) {
      return;
    }

    void loadFolder(initialFolderPath, true);
  }, [isPrintMode]);

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent) => {
      if (isPrintMode) {
        return;
      }

      if (isSaveShortcut(event)) {
        event.preventDefault();
        void handleSave();
      } else if (isFindShortcut(event)) {
        event.preventDefault();
        openFind();
      } else if (isEscapeKey(event) && isFindOpen) {
        event.preventDefault();
        closeFind();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [activeFile, closeFind, isDirty, isFindOpen, isSaving, markdown, openFind]);

  useEffect(() => {
    if (!isPrintMode || !printJobId) {
      return;
    }

    const rawPayload = localStorage.getItem(getPrintJobStorageKey(printJobId));
    if (!rawPayload) {
      void getCurrentWindow().close();
      return;
    }

    try {
      const parsedPayload = JSON.parse(rawPayload) as PrintJobPayload;
      setPrintPayload(parsedPayload);
    } catch (error) {
      console.error('Failed to parse print job payload:', error);
      localStorage.removeItem(getPrintJobStorageKey(printJobId));
      void getCurrentWindow().close();
    }
  }, [isPrintMode, printJobId]);

  useEffect(() => {
    if (!isPrintMode || !printPayload || !printJobId || !rehypePlugins?.length || printStartedRef.current) {
      return;
    }

    printStartedRef.current = true;

    const originalTitle = document.title;
    const printTitle = getPrintDocumentTitle(printPayload.fileName);
    let cleanedUp = false;

    const cleanup = () => {
      if (cleanedUp) {
        return;
      }

      cleanedUp = true;
      document.body.classList.remove('printing-pdf');
      document.title = originalTitle;
      localStorage.removeItem(getPrintJobStorageKey(printJobId));
      void getCurrentWindow().close();
    };

    document.title = printTitle;
    document.body.classList.add('printing-pdf');
    window.addEventListener('afterprint', cleanup, { once: true });

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(async () => {
        try {
          await nativeApi.printCurrentWindow();
          window.setTimeout(cleanup, 15000);
        } catch (error) {
          console.error('Failed to open native print dialog:', error);
          cleanup();
        }
      });
    });
  }, [isPrintMode, printJobId, printPayload, rehypePlugins]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    let unlisten: (() => void) | null = null;

    void (async () => {
      unlisten = await listen('find-in-document', () => {
        openFind();
      });
    })();

    return () => {
      unlisten?.();
    };
  }, [isPrintMode, openFind]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    let unlisten: (() => void) | null = null;

    void (async () => {
      unlisten = await listen<string>(OPEN_RECENT_FOLDER_EVENT, (event) => {
        void loadFolder(event.payload);
      });
    })();

    return () => {
      unlisten?.();
    };
  }, [isPrintMode, markdown, savedMarkdown, activeFile?.path, isDirty]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    let unlisten: (() => void) | null = null;

    void (async () => {
      unlisten = await listen(CLEAR_RECENT_FOLDERS_EVENT, () => {
        updateWorkspaceFolders((current) => clearRecentWorkspaceFolders(current));
      });
    })();

    return () => {
      unlisten?.();
    };
  }, [isPrintMode, updateWorkspaceFolders]);

  useEffect(() => {
    if (isPrintMode) {
      return;
    }

    let isMounted = true;
    let unlisten: (() => void) | null = null;

    const openFirstSupportedPath = async (paths: string[]) => {
      const [nextPath] = filterSupportedOpenPaths(paths);
      if (!nextPath) {
        return;
      }

      await openMarkdownPathFromSystem(nextPath);
    };

    void (async () => {
      unlisten = await listen<string[]>('open-markdown-files', (event) => {
        void openFirstSupportedPath(event.payload);
      });

      const pendingPaths = await nativeApi.takePendingOpenFiles();
      if (isMounted) {
        await openFirstSupportedPath(pendingPaths);
      }
    })();

    return () => {
      isMounted = false;
      if (unlisten) {
        unlisten();
      }
    };
  }, [isPrintMode]);

  const handleCopy = () => {
    navigator.clipboard.writeText(markdown);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownloadPdf = async () => {
    if (isExportingPdf) {
      return;
    }

    setIsExportingPdf(true);

    const jobId = createPrintJobId();
    const printWindowLabel = `print-${jobId}`;
    const printWindowTitle = getPrintDocumentTitle(activeFile?.name ?? null);
    const payload: PrintJobPayload = {
      markdown,
      fileName: activeFile?.name ?? null,
    };

    localStorage.setItem(getPrintJobStorageKey(jobId), JSON.stringify(payload));

    const url = `${window.location.origin}${window.location.pathname}?printMode=1&printJob=${encodeURIComponent(jobId)}`;
    const printWindow = new WebviewWindow(printWindowLabel, {
      url,
      title: printWindowTitle,
      width: 960,
      height: 1200,
      center: true,
      focus: true,
    });

    printWindow.once('tauri://created', () => {
      setIsExportingPdf(false);
    });

    printWindow.once('tauri://error', (event) => {
      console.error('Failed to create print window:', event);
      localStorage.removeItem(getPrintJobStorageKey(jobId));
      setIsExportingPdf(false);
    });
  };

  const confirmDiscardChanges = async (nextAction: string) => {
    if (!isDirty) {
      return true;
    }

    return confirm(
      `You have unsaved changes. Discard them and continue ${nextAction}?`,
      {
        title: 'Unsaved changes',
        kind: 'warning',
      },
    );
  };

  const getResolvedTerminalCwd = () => resolveTerminalCwd({
    currentFolderPath,
    activeFilePath: activeFile?.path ?? null,
    initialFolderPath: initialFolderPathRef.current,
    fallbackPath: terminalFallbackPath ?? '/',
  });

  const handleOpenFolderInTerminal = async () => {
    try {
      await nativeApi.openFolderInTerminal(getResolvedTerminalCwd());
    } catch (error) {
      console.error('Failed to open folder in terminal:', error);
      await message(String(error), {
        title: 'Open Folder in Terminal',
        kind: 'error',
      });
    }
  };

  const handleSave = async () => {
    if (!activeFile || !isDirty || isSaving) {
      return;
    }

    try {
      setIsSaving(true);
      await writeMarkdownFileWithFallback(
        activeFile.path,
        markdown,
        writeTextFile,
        nativeApi.writeMarkdownFile,
      );
      setSavedMarkdown(markdown);
    } catch (err) {
      console.error('Failed to save file:', err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleOpenFolder = async () => {
    try {
      const selectedPath = await open({
        directory: true,
        multiple: false,
        title: 'Open Markdown Folder',
      });

      if (!selectedPath || Array.isArray(selectedPath)) {
        return;
      }

      await loadFolder(selectedPath);
    } catch (err) {
      console.error('Failed to open directory:', err);
    }
  };

  const handleOpenFolderInNewWindow = async () => {
    try {
      const selectedPath = await open({
        directory: true,
        multiple: false,
        title: 'Open Markdown Folder in New Window',
      });

      if (!selectedPath || Array.isArray(selectedPath)) {
        return;
      }

      rememberWorkspaceFolder(selectedPath);
      await nativeApi.openFolderInNewWindow(selectedPath, theme);
    } catch (err) {
      console.error('Failed to open directory in a new window:', err);
    }
  };

  const isWorkspaceFolderPinned = (folderPath: string) => (
    workspaceFolders.pinned.some((folder) => folder.path === folderPath)
  );

  const toggleWorkspaceFolderPinned = (folderPath: string) => {
    updateWorkspaceFolders((current) => (
      current.pinned.some((folder) => folder.path === folderPath)
        ? unpinWorkspaceFolder(current, folderPath)
        : pinWorkspaceFolder(current, folderPath)
    ));
  };

  const renderPinnedWorkspaceFolder = (folder: WorkspaceFolder) => {
    return (
      <div
        key={`pinned-${folder.path}`}
        className="group flex h-7 items-center rounded-sm text-secondary transition-colors hover:bg-btn-hover hover:text-primary"
      >
        <button
          type="button"
          onClick={() => void loadFolder(folder.path)}
          className="flex min-w-0 flex-1 items-center gap-1.5 px-2 py-1 text-left text-[13px] leading-none"
          title={folder.path}
        >
          <Folder className="h-3.5 w-3.5 shrink-0" />
          <span className="truncate">{folder.name}</span>
        </button>
        <button
          type="button"
          onClick={() => updateWorkspaceFolders((current) => unpinWorkspaceFolder(current, folder.path))}
          className="mr-1 rounded-sm p-1 text-secondary opacity-0 transition-opacity hover:bg-btn-hover hover:text-primary group-hover:opacity-100"
          title="Unpin folder"
          aria-label={`Unpin ${folder.name}`}
        >
          <PinOff className="h-3.5 w-3.5" />
        </button>
      </div>
    );
  };

  const toggleDirectory = (path: string) => {
    setExpandedDirectories((current) => {
      const next = new Set(current);
      if (next.has(path)) {
        next.delete(path);
      } else {
        next.add(path);
      }

      return next;
    });
  };

  const renderTreeNode = (node: MarkdownTreeNode, depth = 0) => {
    if (node.type === 'directory') {
      const isExpanded = expandedDirectories.has(node.path);
      const isPinned = isWorkspaceFolderPinned(node.path);

      return (
        <div key={node.path}>
          <div className="group flex h-7 items-center rounded-sm text-secondary transition-colors hover:bg-btn-hover hover:text-primary">
            <button
              type="button"
              onClick={() => toggleDirectory(node.path)}
              className="flex min-w-0 flex-1 items-center gap-1.5 py-1 pr-2 text-left text-[13px] leading-none"
              style={{ paddingLeft: `${8 + depth * 12}px` }}
              title={node.path}
            >
              {isExpanded ? (
                <ChevronDown className="h-3.5 w-3.5 shrink-0" />
              ) : (
                <ChevronRight className="h-3.5 w-3.5 shrink-0" />
              )}
              <Folder className="h-3.5 w-3.5 shrink-0" />
              <span className="truncate">{node.name}</span>
            </button>
            <button
              type="button"
              onClick={() => toggleWorkspaceFolderPinned(node.path)}
              className={`mr-1 rounded-sm p-1 opacity-0 transition-opacity hover:bg-btn-hover hover:text-primary group-hover:opacity-100 ${
                isPinned ? 'text-accent' : ''
              }`}
              title={isPinned ? 'Unpin folder' : 'Pin folder'}
              aria-label={isPinned ? `Unpin ${node.name}` : `Pin ${node.name}`}
            >
              {isPinned ? (
                <PinOff className="h-3.5 w-3.5" />
              ) : (
                <Pin className="h-3.5 w-3.5" />
              )}
            </button>
          </div>
          {isExpanded && (
            <div className="space-y-px">
              {node.children.map((childNode) => renderTreeNode(childNode, depth + 1))}
            </div>
          )}
        </div>
      );
    }

    return (
      <button
        key={node.path}
        type="button"
        onClick={() => void loadFile(node)}
        className={`flex h-7 w-full items-center gap-1.5 rounded-sm py-1 pr-2 text-left text-[13px] leading-none transition-colors ${
          activeFile?.path === node.path
            ? 'bg-accent text-accent-fg'
            : 'text-secondary hover:bg-btn-hover hover:text-primary'
        }`}
        style={{ paddingLeft: `${28 + depth * 12}px` }}
      >
        <FileText className="h-3.5 w-3.5 shrink-0" />
        <span className="truncate">{node.name}</span>
      </button>
    );
  };

  if (isPrintMode) {
    return (
      <div className="print-root print-root--screen">
        <div className="print-page">
          <div className="markdown-content prose max-w-none prose-h1:text-[28px] prose-headings:text-primary prose-p:text-secondary prose-p:leading-[1.7] prose-li:my-2 prose-li:text-secondary prose-strong:text-primary prose-a:text-accent prose-blockquote:text-secondary prose-blockquote:border-border prose-th:text-primary prose-td:text-secondary prose-hr:border-border">
            <ReactMarkdown
              remarkPlugins={[remarkGfm]}
              rehypePlugins={rehypePlugins}
            >
              {printPayload?.markdown ?? ''}
            </ReactMarkdown>
          </div>
        </div>
      </div>
    );
  }

  return (
    <>
      <div className={`${getAppThemeClass(theme)} h-screen bg-window flex flex-col font-sans text-primary overflow-hidden`}>
      {/* Header */}
      <header
        className="h-[58px] bg-header border-b border-border px-4 flex items-center shrink-0 select-none"
        onMouseDown={handleHeaderMouseDown}
        onDoubleClick={handleHeaderDoubleClick}
      >
        <div className="h-full w-[88px] shrink-0" />
        <div className="min-w-[160px] flex-1 h-full" />

        <div
          className="flex items-center gap-2"
          data-no-drag="true"
          data-tauri-drag-region="false"
        >
          {/* View Mode Toggle */}
          <div
            className="flex items-center bg-btn-bg border border-border rounded-md p-0.5 mr-2"
            data-view-toggle-group="true"
          >
            <button
              onClick={() => setIsSidebarOpen(!isSidebarOpen)}
              className="p-1.5 rounded-sm transition-colors text-secondary hover:text-primary"
              title="Toggle Sidebar"
              data-view-toggle="true"
              data-active={isSidebarOpen ? 'true' : 'false'}
              data-no-drag="true"
              data-tauri-drag-region="false"
            >
              <PanelLeft className="w-4 h-4" />
            </button>
            <button
              onClick={() => setViewMode('preview')}
              className={`p-1.5 rounded-sm transition-colors ${viewMode === 'preview' ? 'bg-border text-primary' : 'text-secondary hover:text-primary'}`}
              title="Full Preview"
              data-view-toggle="true"
              data-active={viewMode === 'preview' ? 'true' : 'false'}
              data-no-drag="true"
              data-tauri-drag-region="false"
            >
              <Maximize className="w-4 h-4" />
            </button>
            <button
              onClick={() => setViewMode('split')}
              className={`p-1.5 rounded-sm transition-colors ${viewMode === 'split' ? 'bg-border text-primary' : 'text-secondary hover:text-primary'}`}
              title="Split View"
              data-view-toggle="true"
              data-active={viewMode === 'split' ? 'true' : 'false'}
              data-no-drag="true"
              data-tauri-drag-region="false"
            >
              <Columns className="w-4 h-4" />
            </button>
            <button
              onClick={() => void handleOpenFolderInTerminal()}
              className="p-1.5 rounded-sm text-secondary transition-colors hover:text-primary"
              title="Open Folder in Terminal"
              data-view-toggle="true"
              data-no-drag="true"
              data-tauri-drag-region="false"
            >
              <SquareTerminal className="w-4 h-4" />
            </button>
          </div>

          <div className="flex items-center gap-2 border-r border-border pr-4 mr-2">
            <Palette className="w-4 h-4 text-secondary hidden sm:block" />
            <select
              value={theme}
              onChange={(e) => setTheme(e.target.value)}
              className="h-[34px] min-w-[160px] bg-btn-bg text-primary border border-border rounded px-3 text-[13px] focus:outline-none focus:border-accent"
              data-no-drag="true"
              data-tauri-drag-region="false"
            >
              {THEME_OPTIONS.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.label}
                </option>
              ))}
            </select>
          </div>
          {isFindOpen && (
            <div
              role="search"
              className="flex h-[34px] min-w-[220px] max-w-[300px] items-center gap-1 rounded border border-border bg-btn-bg px-2"
              data-no-drag="true"
              data-tauri-drag-region="false"
            >
              <Search className="h-4 w-4 shrink-0 text-secondary" />
              <input
                ref={findInputRef}
                value={findQuery}
                onChange={(event) => setFindQuery(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') {
                    event.preventDefault();
                    moveFindMatch(event.shiftKey ? -1 : 1);
                  } else if (event.key === 'Escape') {
                    event.preventDefault();
                    closeFind();
                  }
                }}
                className="min-w-0 flex-1 bg-transparent text-[13px] text-primary outline-none placeholder:text-muted"
                placeholder="Find"
                aria-label="Find in document"
                spellCheck="false"
              />
              <span className="min-w-[48px] text-right text-[11px] text-muted">
                {findQuery.trim()
                  ? findMatches.length > 0
                    ? `${findMatchIndex + 1}/${findMatches.length}`
                    : 'No results'
                  : ''}
              </span>
              <button
                type="button"
                onClick={() => moveFindMatch(-1)}
                disabled={findMatches.length === 0}
                className="rounded p-1 text-secondary hover:bg-btn-hover hover:text-primary disabled:opacity-40"
                title="Previous Match"
                aria-label="Previous match"
              >
                <ChevronUp className="h-3.5 w-3.5" />
              </button>
              <button
                type="button"
                onClick={() => moveFindMatch(1)}
                disabled={findMatches.length === 0}
                className="rounded p-1 text-secondary hover:bg-btn-hover hover:text-primary disabled:opacity-40"
                title="Next Match"
                aria-label="Next match"
              >
                <ChevronDown className="h-3.5 w-3.5" />
              </button>
              <button
                type="button"
                onClick={closeFind}
                className="rounded p-1 text-secondary hover:bg-btn-hover hover:text-primary"
                title="Close Find"
                aria-label="Close find"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          )}
          <button
            onClick={handleCopy}
            className="flex items-center gap-2 whitespace-nowrap px-3 py-1.5 text-[13px] text-primary bg-btn-bg border border-border rounded hover:bg-btn-hover transition-colors"
            title={copied ? 'Copied raw markdown' : 'Copy raw markdown'}
            aria-label={copied ? 'Copied raw markdown' : 'Copy raw markdown'}
            data-toolbar-action="true"
            data-no-drag="true"
            data-tauri-drag-region="false"
          >
            {copied ? <Check className="w-4 h-4 text-accent" /> : <Copy className="w-4 h-4" />}
            <span className="hidden sm:inline">{copied ? 'Copied' : 'Copy'}</span>
          </button>
          <button
            onClick={() => void handleSave()}
            disabled={!activeFile || !isDirty || isSaving}
            className="flex items-center gap-2 whitespace-nowrap px-3 py-1.5 text-[13px] text-primary bg-btn-bg border border-border rounded hover:bg-btn-hover disabled:opacity-50 transition-colors"
            data-toolbar-action="true"
            data-no-drag="true"
            data-tauri-drag-region="false"
          >
            <Save className="w-4 h-4" />
            <span className="hidden sm:inline">{isSaving ? 'Saving…' : 'Save'}</span>
          </button>
          {isDirty && (
            <span className="hidden sm:inline-flex items-center rounded-full border border-amber-400/60 bg-amber-100 px-2 py-0.5 text-[11px] font-semibold text-amber-800">
              Unsaved
            </span>
          )}
          <button
            onClick={() => void handleDownloadPdf()}
            className="flex items-center gap-2 whitespace-nowrap px-3 py-1.5 text-[13px] text-accent-fg bg-accent border border-accent rounded hover:bg-accent-hover transition-colors"
            disabled={isExportingPdf}
            title={isExportingPdf ? 'Opening print dialog' : 'Save as PDF'}
            aria-label={isExportingPdf ? 'Opening print dialog' : 'Save as PDF'}
            data-toolbar-action="true"
            data-no-drag="true"
            data-tauri-drag-region="false"
          >
            <Download className="w-4 h-4" />
            <span className="hidden sm:inline">{isExportingPdf ? 'Opening…' : 'PDF'}</span>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <div className="flex-1 flex overflow-hidden">
        
        {/* Sidebar (File Explorer) */}
        {isSidebarOpen && (
          <aside className="w-64 border-r border-border bg-editor flex flex-col shrink-0">
            <div className="px-3 py-2 border-b border-border flex items-center justify-between">
              <span className="text-[11px] font-semibold tracking-[0.05em] text-muted uppercase">Explorer</span>
              <div className="flex items-center gap-1">
                <button
                  onClick={handleOpenFolder}
                  className="p-1 text-secondary hover:text-primary hover:bg-btn-hover rounded-sm transition-colors"
                  title="Open Folder"
                >
                  <FolderOpen className="w-4 h-4" />
                </button>
                <button
                  onClick={() => void handleOpenFolderInNewWindow()}
                  className="p-1 text-secondary hover:text-primary hover:bg-btn-hover rounded-sm transition-colors"
                  title="Open Folder in New Window"
                >
                  <FolderPlus className="w-4 h-4" />
                </button>
              </div>
            </div>
            {workspaceFolders.pinned.length > 0 && (
              <div className="border-b border-border px-1.5 py-2">
                <section>
                  <div className="px-2 pb-1 text-[10px] font-semibold uppercase tracking-[0.06em] text-muted">
                    Pinned
                  </div>
                  <div className="space-y-px">
                    {workspaceFolders.pinned.map((folder) => renderPinnedWorkspaceFolder(folder))}
                  </div>
                </section>
              </div>
            )}
            <div className="flex-1 overflow-y-auto p-1.5">
              {tree.length === 0 ? (
                <div className="text-[12px] text-muted text-center mt-6 px-3">
                  <FolderOpen className="w-6 h-6 mx-auto mb-2 opacity-50" />
                  <p>No folder opened.</p>
                  <button 
                    onClick={handleOpenFolder}
                    className="mt-2 text-accent hover:underline"
                  >
                    Open a folder
                  </button>
                </div>
              ) : (
                <div className="space-y-px">
                  {tree.map((node) => renderTreeNode(node))}
                </div>
              )}
            </div>
          </aside>
        )}

        {/* Editor & Preview Panes */}
        <main className="flex-1 flex flex-col md:flex-row overflow-hidden">
          
          {/* Editor Pane (Only visible in split mode) */}
          {viewMode === 'split' && (
            <div className="flex-1 flex flex-col border-r border-border bg-editor min-w-0">
              <div className="px-5 py-2 flex items-center gap-2 text-[11px] font-semibold tracking-[0.05em] text-muted uppercase">
                <FileText className="w-3.5 h-3.5" />
                Editor {activeFile && <span className="normal-case font-normal text-secondary ml-2">- {activeFile.name}</span>}
              </div>
              <textarea
                ref={editorTextareaRef}
                value={markdown}
                onChange={(e) => setMarkdown(e.target.value)}
                onScroll={(event) => syncPaneScroll('editor', event.currentTarget, previewPaneRef.current)}
                className="flex-1 w-full px-5 pb-5 resize-none focus:outline-none font-mono text-[14px] leading-[1.55] text-primary bg-transparent"
                placeholder="Type your markdown here..."
                spellCheck="false"
              />
            </div>
          )}

          {/* Preview Pane */}
          <div
            ref={previewPaneRef}
            onScroll={(event) => syncPaneScroll('preview', event.currentTarget, editorTextareaRef.current)}
            className="flex-1 flex flex-col bg-preview min-w-0 overflow-y-auto"
          >
            <div className="px-8 py-2 flex items-center gap-2 text-[11px] font-semibold tracking-[0.05em] text-muted uppercase sticky top-0 z-10 bg-preview">
              <LayoutPanelLeft className="w-3.5 h-3.5" />
              Preview {activeFile && viewMode === 'preview' && <span className="normal-case font-normal text-secondary ml-2">- {activeFile.name}</span>}
            </div>
            <div className="px-8 pb-8 max-w-4xl mx-auto w-full">
              <div className="markdown-content prose max-w-none prose-h1:text-[28px] prose-headings:text-primary prose-p:text-secondary prose-p:leading-[1.58] prose-li:my-1 prose-li:text-secondary prose-strong:text-primary prose-a:text-accent prose-blockquote:text-secondary prose-blockquote:border-border prose-th:text-primary prose-td:text-secondary prose-hr:border-border">
                <ReactMarkdown
                  remarkPlugins={[remarkGfm]}
                  rehypePlugins={rehypePlugins}
                >
                  {markdown}
                </ReactMarkdown>
              </div>
            </div>
          </div>

        </main>
      </div>
      </div>
    </>
  );
}
