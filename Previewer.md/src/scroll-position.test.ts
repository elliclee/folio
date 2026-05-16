import test from 'node:test';
import assert from 'node:assert/strict';

import {
  createScrollSyncController,
  resetScrollPositions,
  syncScrollPosition,
} from './scroll-position';

function createManualScheduler() {
  let nextId = 1;
  const frames = new Map<number, () => void>();
  const delays = new Map<number, () => void>();

  return {
    scheduler: {
      requestFrame(callback: () => void) {
        const id = nextId;
        nextId += 1;
        frames.set(id, callback);
        return id;
      },
      cancelFrame(id: number) {
        frames.delete(id);
      },
      setDelay(callback: () => void) {
        const id = nextId;
        nextId += 1;
        delays.set(id, callback);
        return id;
      },
      clearDelay(id: number) {
        delays.delete(id);
      },
    },
    flushFrames() {
      const callbacks = Array.from(frames.values());
      frames.clear();
      callbacks.forEach((callback) => callback());
    },
    flushDelays() {
      const callbacks = Array.from(delays.values());
      delays.clear();
      callbacks.forEach((callback) => callback());
    },
    get frameCount() {
      return frames.size;
    },
  };
}

test('resetScrollPositions sends all provided targets back to the top', () => {
  const previewPane = { scrollTop: 280 };
  const editorPane = { scrollTop: 140 };

  resetScrollPositions([previewPane, editorPane]);

  assert.equal(previewPane.scrollTop, 0);
  assert.equal(editorPane.scrollTop, 0);
});

test('resetScrollPositions safely ignores missing targets', () => {
  const previewPane = { scrollTop: 88 };

  resetScrollPositions([previewPane, null, undefined]);

  assert.equal(previewPane.scrollTop, 0);
});

test('syncScrollPosition maps scroll progress between panes with different heights', () => {
  const editorPane = {
    scrollTop: 300,
    scrollHeight: 1000,
    clientHeight: 400,
  };
  const previewPane = {
    scrollTop: 0,
    scrollHeight: 2400,
    clientHeight: 600,
  };

  syncScrollPosition(editorPane, previewPane);

  assert.equal(previewPane.scrollTop, 900);
});

test('syncScrollPosition sends the target to the top when the source cannot scroll', () => {
  const editorPane = {
    scrollTop: 0,
    scrollHeight: 400,
    clientHeight: 400,
  };
  const previewPane = {
    scrollTop: 220,
    scrollHeight: 1600,
    clientHeight: 600,
  };

  syncScrollPosition(editorPane, previewPane);

  assert.equal(previewPane.scrollTop, 0);
});

test('scroll sync controller ignores target scroll events during the active gesture', () => {
  const manualScheduler = createManualScheduler();
  const controller = createScrollSyncController({
    scheduler: manualScheduler.scheduler,
  });
  const editorPane = {
    scrollTop: 300,
    scrollHeight: 1000,
    clientHeight: 400,
  };
  const previewPane = {
    scrollTop: 0,
    scrollHeight: 2400,
    clientHeight: 600,
  };

  controller.handleScroll('editor', editorPane, previewPane);
  manualScheduler.flushFrames();
  previewPane.scrollTop = 1200;
  controller.handleScroll('preview', previewPane, editorPane);
  manualScheduler.flushFrames();

  assert.equal(previewPane.scrollTop, 1200);
  assert.equal(editorPane.scrollTop, 300);

  manualScheduler.flushDelays();
  controller.handleScroll('preview', previewPane, editorPane);
  manualScheduler.flushFrames();

  assert.equal(editorPane.scrollTop, 400);
});

test('scroll sync controller coalesces rapid scroll events into the next frame', () => {
  const manualScheduler = createManualScheduler();
  const controller = createScrollSyncController({
    scheduler: manualScheduler.scheduler,
  });
  const editorPane = {
    scrollTop: 100,
    scrollHeight: 1000,
    clientHeight: 400,
  };
  const previewPane = {
    scrollTop: 0,
    scrollHeight: 2400,
    clientHeight: 600,
  };

  controller.handleScroll('editor', editorPane, previewPane);
  editorPane.scrollTop = 200;
  controller.handleScroll('editor', editorPane, previewPane);

  assert.equal(manualScheduler.frameCount, 1);
  assert.equal(previewPane.scrollTop, 0);

  manualScheduler.flushFrames();

  assert.equal(previewPane.scrollTop, 600);
});
