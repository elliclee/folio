import test from 'node:test';
import assert from 'node:assert/strict';

import { createNativeApi } from './native-api';

test('native api opens a folder in the system terminal', async () => {
  const calls: Array<{ command: string; args?: Record<string, unknown> }> = [];
  const api = createNativeApi({
    invoke: async <T>(command: string, args?: Record<string, unknown>) => {
      calls.push({ command, args });
      return undefined as T;
    },
  });

  await api.openFolderInTerminal('/Users/ellic/docs');

  assert.deepEqual(calls, [
    {
      command: 'open_folder_in_terminal',
      args: {
        folderPath: '/Users/ellic/docs',
      },
    },
  ]);
});

test('native api wraps file and window commands behind named methods', async () => {
  const calls: Array<{ command: string; args?: Record<string, unknown> }> = [];
  const api = createNativeApi({
    invoke: async <T>(command: string, args?: Record<string, unknown>) => {
      calls.push({ command, args });
      if (command === 'take_pending_open_files') {
        return ['/tmp/readme.md'] as T;
      }
      if (command === 'open_folder_in_new_window') {
        return 'workspace-1' as T;
      }
      if (command === 'read_markdown_file') {
        return '# doc' as T;
      }
      return undefined as T;
    },
  });

  assert.deepEqual(await api.takePendingOpenFiles(), ['/tmp/readme.md']);
  assert.equal(await api.openFolderInNewWindow('/tmp/docs', 'dark'), 'workspace-1');
  await api.openFolderInTerminal('/tmp/docs');
  assert.equal(await api.readMarkdownFile('/tmp/readme.md'), '# doc');
  await api.writeMarkdownFile('/tmp/readme.md', '# updated');
  await api.printCurrentWindow();

  assert.deepEqual(calls, [
    { command: 'take_pending_open_files', args: undefined },
    {
      command: 'open_folder_in_new_window',
      args: { folderPath: '/tmp/docs', theme: 'dark' },
    },
    { command: 'open_folder_in_terminal', args: { folderPath: '/tmp/docs' } },
    { command: 'read_markdown_file', args: { path: '/tmp/readme.md' } },
    {
      command: 'write_markdown_file',
      args: { path: '/tmp/readme.md', contents: '# updated' },
    },
    { command: 'print_current_window', args: undefined },
  ]);
});

test('native api wraps performance probe commands', async () => {
  const calls: Array<{ command: string; args?: Record<string, unknown> }> = [];
  const api = createNativeApi({
    invoke: async <T>(command: string, args?: Record<string, unknown>) => {
      calls.push({ command, args });
      if (command === 'get_performance_probe_config') {
        return { enabled: true } as T;
      }
      return undefined as T;
    },
  });

  assert.deepEqual(await api.getPerformanceProbeConfig(), {
    enabled: true,
  });
  await api.recordPerformanceMetric('app.first_render', 42.5);

  assert.deepEqual(calls, [
    { command: 'get_performance_probe_config', args: undefined },
    {
      command: 'record_performance_metric',
      args: { name: 'app.first_render', elapsedMs: 42.5 },
    },
  ]);
});
