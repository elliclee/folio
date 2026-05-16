#!/usr/bin/env node
import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { fileURLToPath, pathToFileURL } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(scriptDir, '..');
const defaultAppPath = resolve(
  projectRoot,
  'src-tauri/target/release/bundle/macos/PreviewerMD.app',
);
const requiredMetrics = [
  'app.first_render',
  'app.syntax_highlight_ready',
];

export function parseThreshold(value) {
  const [metricName, maxValue, ...rest] = value.split('=');
  const maxMs = Number.parseFloat(maxValue);

  if (!metricName || rest.length > 0 || !Number.isFinite(maxMs) || maxMs < 0) {
    throw new Error(`Invalid threshold: ${value}. Expected metric=maxMs`);
  }

  return { metricName, maxMs };
}

function parseArgs(argv) {
  const options = {
    appPath: defaultAppPath,
    runs: 3,
    timeoutMs: 10000,
    thresholds: [],
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--app') {
      options.appPath = resolve(argv[++index]);
    } else if (arg === '--runs') {
      options.runs = Number.parseInt(argv[++index], 10);
    } else if (arg === '--timeout-ms') {
      options.timeoutMs = Number.parseInt(argv[++index], 10);
    } else if (arg === '--max') {
      options.thresholds.push(parseThreshold(argv[++index]));
    } else if (arg === '--help') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!Number.isInteger(options.runs) || options.runs < 1) {
    throw new Error('--runs must be a positive integer');
  }
  if (!Number.isInteger(options.timeoutMs) || options.timeoutMs < 1000) {
    throw new Error('--timeout-ms must be an integer >= 1000');
  }

  return options;
}

function printHelp() {
  console.log(`Usage: npm run perf:baseline -- [--runs 3] [--app path/to/PreviewerMD.app]

Measures release app startup and first-render timings.

Options:
  --app          Path to PreviewerMD.app. Defaults to the release bundle.
  --runs         Number of repeated launches. Defaults to 3.
  --timeout-ms   Per-run timeout. Defaults to 10000.
  --max          Fail when a metric median exceeds metric=maxMs. Repeatable.`);
}

function resolveExecutable(appPath) {
  const executable = appPath.endsWith('.app')
    ? resolve(appPath, 'Contents/MacOS/previewermd')
    : appPath;

  if (!existsSync(executable)) {
    throw new Error(`App executable not found: ${executable}`);
  }

  return executable;
}

function parseMetricLine(line) {
  const prefix = 'PREVIEWERMD_PERF ';
  if (!line.startsWith(prefix)) {
    return null;
  }

  const payload = JSON.parse(line.slice(prefix.length));
  if (typeof payload.name !== 'string' || typeof payload.elapsed_ms !== 'number') {
    throw new Error(`Malformed performance payload: ${line}`);
  }

  return payload;
}

function hasAllRequiredMetrics(metrics) {
  return requiredMetrics.every((name) => Object.hasOwn(metrics, name));
}

function terminate(child) {
  if (child.exitCode !== null || child.killed) {
    return;
  }

  child.kill('SIGTERM');
  setTimeout(() => {
    if (child.exitCode === null && !child.killed) {
      child.kill('SIGKILL');
    }
  }, 1000).unref();
}

function runOnce(executable, timeoutMs) {
  return new Promise((resolveRun, rejectRun) => {
    spawnSync('pkill', ['-f', executable], { stdio: 'ignore' });

    const startedAt = performance.now();
    const metrics = {};
    const child = spawn(executable, [], {
      env: {
        ...process.env,
        PREVIEWERMD_PERF_PROBE: '1',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdoutBuffer = '';
    let stderrBuffer = '';
    let resolved = false;

    const timeout = setTimeout(() => {
      terminate(child);
      rejectRun(new Error(`Timed out after ${timeoutMs}ms waiting for ${requiredMetrics.join(', ')}`));
    }, timeoutMs);

    function finish() {
      if (resolved || !hasAllRequiredMetrics(metrics)) {
        return;
      }

      resolved = true;
      clearTimeout(timeout);
      const processElapsedMs = performance.now() - startedAt;
      terminate(child);
      resolveRun({ metrics, processElapsedMs });
    }

    function ingestLine(line) {
      const trimmed = line.trim();
      if (!trimmed) {
        return;
      }

      const metric = parseMetricLine(trimmed);
      if (!metric) {
        return;
      }

      metrics[metric.name] = metric.elapsed_ms;
      finish();
    }

    child.stdout.on('data', (chunk) => {
      stdoutBuffer += chunk.toString('utf8');
      const lines = stdoutBuffer.split(/\r?\n/);
      stdoutBuffer = lines.pop() ?? '';
      for (const line of lines) {
        ingestLine(line);
      }
    });

    child.stderr.on('data', (chunk) => {
      stderrBuffer += chunk.toString('utf8');
    });

    child.on('error', (error) => {
      clearTimeout(timeout);
      rejectRun(error);
    });

    child.on('exit', (code, signal) => {
      if (resolved) {
        return;
      }

      clearTimeout(timeout);
      rejectRun(new Error(`App exited before metrics completed. code=${code} signal=${signal} stderr=${stderrBuffer.trim()}`));
    });
  });
}

export function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 1) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

export function evaluateThresholds(results, thresholds) {
  return thresholds.flatMap(({ metricName, maxMs }) => {
    const values = results
      .map((result) => result.metrics[metricName])
      .filter((value) => typeof value === 'number');

    if (values.length !== results.length) {
      return [{
        metricName,
        medianMs: Number.NaN,
        maxMs,
      }];
    }

    const medianMs = median(values);
    if (medianMs <= maxMs) {
      return [];
    }

    return [{
      metricName,
      medianMs,
      maxMs,
    }];
  });
}

function formatMs(value) {
  return `${value.toFixed(1)}ms`;
}

function printResults(results) {
  console.log('\nPreviewerMD performance baseline');
  console.log(`runs: ${results.length}`);
  console.log('');
  console.log('| metric | median | runs |');
  console.log('| --- | ---: | --- |');

  for (const metricName of requiredMetrics) {
    const values = results.map((result) => result.metrics[metricName]);
    console.log(`| ${metricName} | ${formatMs(median(values))} | ${values.map(formatMs).join(', ')} |`);
  }

  const processValues = results.map((result) => result.processElapsedMs);
  console.log(`| process.until_all_metrics | ${formatMs(median(processValues))} | ${processValues.map(formatMs).join(', ')} |`);
}

function printThresholdFailures(failures) {
  if (failures.length === 0) {
    return;
  }

  console.log('');
  console.log('Performance threshold failures');
  console.log('| metric | median | max |');
  console.log('| --- | ---: | ---: |');
  for (const failure of failures) {
    const medianValue = Number.isFinite(failure.medianMs)
      ? formatMs(failure.medianMs)
      : 'missing';
    console.log(`| ${failure.metricName} | ${medianValue} | ${formatMs(failure.maxMs)} |`);
  }
}

async function main() {
  if (process.platform !== 'darwin') {
    throw new Error('perf:baseline currently measures the macOS release app bundle only');
  }

  const options = parseArgs(process.argv.slice(2));
  const executable = resolveExecutable(options.appPath);
  const results = [];

  for (let run = 1; run <= options.runs; run += 1) {
    process.stdout.write(`Run ${run}/${options.runs}... `);
    const result = await runOnce(executable, options.timeoutMs);
    results.push(result);
    console.log('ok');
  }

  printResults(results);
  const thresholdFailures = evaluateThresholds(results, options.thresholds);
  printThresholdFailures(thresholdFailures);

  if (thresholdFailures.length > 0) {
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
