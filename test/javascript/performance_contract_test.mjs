import test from 'node:test';
import assert from 'node:assert/strict';
import { validateBudgets, readMetrics, summarizeRuns, budgetViolations, METRIC_KEYS } from '../../scripts/performance_contract.mjs';

const config = () => ({ conditions: 'Fixture', pages: [{ path: '/about', limits: { total_bytes: 100, requests: 10 } }] });
test('budget configuration rejects typos, invalid values, duplicate pages and nonlocal paths', () => {
  assert.equal(validateBudgets(config()).pages.length, 1);
  for (const limits of [{ total_byte: 100 }, { total_bytes: '100' }, { requests: NaN }, { requests: Infinity }, { requests: -1 }, { requests: 1.5 }, {}]) {
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
  assert.deepEqual(budgetViolations(run(20), { total_bytes: 19, requests: 20 }), ['total_bytes: 20 > 19']);
  assert.throws(() => budgetViolations(run(20), { request: 30 }));
  assert.throws(() => budgetViolations({}, { requests: 30 }));
});
