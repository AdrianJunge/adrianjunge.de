import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { validateBudgets, readMetrics, summarizeRuns, budgetViolations, METRIC_KEYS } from '../../scripts/performance_contract.mjs';

const config = () => ({ conditions: 'Fixture', pages: [{ path: '/about', limits: { script_bytes: 100, requests: 10 } }] });
test('budget configuration rejects typos, invalid values, duplicate pages and nonlocal paths', () => {
  assert.equal(validateBudgets(config()).pages.length, 1);
  for (const limits of [{ script_byte: 100 }, { script_bytes: '100' }, { total_bytes: 100 }, { document_bytes: 100 }, { requests: NaN }, { requests: Infinity }, { requests: -1 }, { requests: 1.5 }, {}]) {
    assert.throws(() => validateBudgets({ ...config(), pages: [{ path: '/about', limits }] }));
  }
  assert.throws(() => validateBudgets({ ...config(), pages: [...config().pages, ...config().pages] }));
  for (const path of ['https://example.test', '//example.test', '/about#x', '/about?q=x', '/bad path', '/\\example.test']) {
    assert.throws(() => validateBudgets({ ...config(), pages: [{ path, limits: { requests: 1 } }] }));
  }
});
test('missing or nonfinite Lighthouse output cannot silently pass', () => {
  const report = { audits: {
    'resource-summary': { details: { items: ['total', 'script', 'stylesheet', 'image', 'document'].map(resourceType => ({ resourceType, transferSize: 0, requestCount: 0 })) } },
    'largest-contentful-paint': { numericValue: 0 }, 'cumulative-layout-shift': { numericValue: 0 },
  } };
  assert.deepEqual(Object.values(readMetrics(report)), [0, 0, 0, 0, 0, 0, 0, 0]);
  assert.throws(() => readMetrics({ audits: {} }));
  report.audits['largest-contentful-paint'].numericValue = NaN;
  assert.throws(() => readMetrics(report));
  report.audits['largest-contentful-paint'].numericValue = 100;
  report.audits['resource-summary'].details.items.pop();
  assert.throws(() => readMetrics(report));
});
test('median and limits are independently specified and incomplete runs fail', () => {
  const run = value => Object.fromEntries(METRIC_KEYS.map(key => [key, value]));
  assert.equal(summarizeRuns([run(90), run(10), run(30)]).total_bytes, 30);
  assert.equal(summarizeRuns([run(10), run(30)]).total_bytes, 20);
  assert.throws(() => summarizeRuns([{}]));
  assert.throws(() => summarizeRuns([]));
  assert.deepEqual(budgetViolations(run(20), { script_bytes: 19, requests: 20 }), ['script_bytes: 20 > 19']);
  assert.throws(() => budgetViolations(run(20), { request: 30 }));
  assert.throws(() => budgetViolations({}, { requests: 30 }));
});

test('HTML and total size remain reported while shipped asset and request limits still fail on growth', async () => {
  const budgets = validateBudgets(JSON.parse(await readFile(new URL('../../config/performance-budgets.json', import.meta.url), 'utf8')));
  const metrics = { ...Object.fromEntries(METRIC_KEYS.map(key => [key, 0])), total_bytes: 50_000_000, document_bytes: 45_000_000 };
  const median = summarizeRuns([metrics, metrics, metrics]);
  assert.equal(median.total_bytes, 50_000_000);
  assert.equal(median.document_bytes, 45_000_000);
  for (const page of budgets.pages) {
    assert.deepEqual(Object.keys(page.limits).sort(), ['image_bytes', 'requests', 'script_bytes', 'stylesheet_bytes']);
    assert.deepEqual(budgetViolations(median, page.limits), [], page.path);
    for (const [key, maximum] of Object.entries(page.limits)) {
      assert.deepEqual(budgetViolations({ ...median, [key]: maximum + 1 }, page.limits), [`${key}: ${maximum + 1} > ${maximum}`], page.path);
    }
  }
});
