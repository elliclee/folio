type ScrollableTarget = {
  scrollTop: number;
  scrollHeight?: number;
  clientHeight?: number;
};

type ScrollSyncPane = 'editor' | 'preview';

type ScrollSyncScheduler = {
  requestFrame: (callback: () => void) => number;
  cancelFrame: (id: number) => void;
  setDelay: (callback: () => void, delayMs: number) => number;
  clearDelay: (id: number) => void;
};

const SCROLL_SYNC_RELEASE_DELAY_MS = 180;

function createBrowserScrollSyncScheduler(): ScrollSyncScheduler {
  return {
    requestFrame: (callback) => window.requestAnimationFrame(callback),
    cancelFrame: (id) => window.cancelAnimationFrame(id),
    setDelay: (callback, delayMs) => window.setTimeout(callback, delayMs),
    clearDelay: (id) => window.clearTimeout(id),
  };
}

export function resetScrollPositions(targets: Array<ScrollableTarget | null | undefined>) {
  targets.forEach((target) => {
    if (target) {
      target.scrollTop = 0;
    }
  });
}

function getScrollableDistance(target: ScrollableTarget) {
  return Math.max(0, (target.scrollHeight ?? 0) - (target.clientHeight ?? 0));
}

export function syncScrollPosition(
  source: ScrollableTarget,
  target: ScrollableTarget | null | undefined,
) {
  if (!target) {
    return;
  }

  const sourceScrollableDistance = getScrollableDistance(source);
  const targetScrollableDistance = getScrollableDistance(target);

  if (sourceScrollableDistance === 0 || targetScrollableDistance === 0) {
    target.scrollTop = 0;
    return;
  }

  target.scrollTop = (source.scrollTop / sourceScrollableDistance) * targetScrollableDistance;
}

export function createScrollSyncController({
  scheduler = createBrowserScrollSyncScheduler(),
  releaseDelayMs = SCROLL_SYNC_RELEASE_DELAY_MS,
}: {
  scheduler?: ScrollSyncScheduler;
  releaseDelayMs?: number;
} = {}) {
  let activePane: ScrollSyncPane | null = null;
  let frameId: number | null = null;
  let releaseDelayId: number | null = null;
  let pendingSync: {
    source: ScrollableTarget;
    target: ScrollableTarget;
  } | null = null;

  const clearReleaseDelay = () => {
    if (releaseDelayId === null) {
      return;
    }

    scheduler.clearDelay(releaseDelayId);
    releaseDelayId = null;
  };

  const clearFrame = () => {
    if (frameId === null) {
      return;
    }

    scheduler.cancelFrame(frameId);
    frameId = null;
  };

  const releaseActivePane = () => {
    activePane = null;
    releaseDelayId = null;
  };

  return {
    handleScroll(
      sourcePane: ScrollSyncPane,
      source: ScrollableTarget,
      target: ScrollableTarget | null | undefined,
    ) {
      if (!target) {
        return;
      }

      if (activePane && activePane !== sourcePane) {
        return;
      }

      activePane = sourcePane;
      pendingSync = { source, target };

      if (frameId === null) {
        frameId = scheduler.requestFrame(() => {
          frameId = null;

          if (!pendingSync) {
            return;
          }

          const nextSync = pendingSync;
          pendingSync = null;
          syncScrollPosition(nextSync.source, nextSync.target);
        });
      }

      clearReleaseDelay();
      releaseDelayId = scheduler.setDelay(releaseActivePane, releaseDelayMs);
    },
    dispose() {
      clearFrame();
      clearReleaseDelay();
      activePane = null;
      pendingSync = null;
    },
  };
}
