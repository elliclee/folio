export type PrintJobPayload = {
  markdown: string;
  fileName: string | null;
};

const PRINT_JOB_PREFIX = 'previewermd-print-job:';

export function createPrintJobId(): string {
  return `print-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export function getPrintJobStorageKey(jobId: string): string {
  return `${PRINT_JOB_PREFIX}${jobId}`;
}

export function isPrintModeSearch(search: string): boolean {
  return new URLSearchParams(search).get('printMode') === '1';
}

export function getPrintJobIdFromSearch(search: string): string | null {
  return new URLSearchParams(search).get('printJob');
}
