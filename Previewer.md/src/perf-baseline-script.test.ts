import test from 'node:test';
import assert from 'node:assert/strict';

// @ts-expect-error The perf baseline script is plain Node ESM exercised through runtime tests.
const perfBaseline = await import('../scripts/perf-baseline.mjs');

test('parseThreshold converts metric limits from CLI syntax', () => {
  assert.deepEqual(perfBaseline.parseThreshold('app.first_render=250'), {
    metricName: 'app.first_render',
    maxMs: 250,
  });
});

test('evaluateThresholds reports median regressions', () => {
  const failures = perfBaseline.evaluateThresholds(
    [
      { metrics: { 'app.first_render': 210 }, processElapsedMs: 800 },
      { metrics: { 'app.first_render': 230 }, processElapsedMs: 820 },
      { metrics: { 'app.first_render': 250 }, processElapsedMs: 840 },
    ],
    [{ metricName: 'app.first_render', maxMs: 220 }],
  );

  assert.deepEqual(failures, [
    {
      metricName: 'app.first_render',
      medianMs: 230,
      maxMs: 220,
    },
  ]);
});
