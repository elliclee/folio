import test from 'node:test';
import assert from 'node:assert/strict';

import { getPrintJobIdFromSearch, getPrintJobStorageKey, isPrintModeSearch } from './print-job';

test('isPrintModeSearch returns true only for print routes', () => {
  assert.equal(isPrintModeSearch('?printMode=1&printJob=abc'), true);
  assert.equal(isPrintModeSearch('?printJob=abc'), false);
  assert.equal(isPrintModeSearch(''), false);
});

test('getPrintJobIdFromSearch reads the print job id from search params', () => {
  assert.equal(getPrintJobIdFromSearch('?printMode=1&printJob=job-123'), 'job-123');
  assert.equal(getPrintJobIdFromSearch('?printMode=1'), null);
});

test('getPrintJobStorageKey namespaces the print job payload in storage', () => {
  assert.equal(getPrintJobStorageKey('job-123'), 'previewermd-print-job:job-123');
});
