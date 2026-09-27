export const RESOURCE_KEYS = Object.freeze(['total_bytes', 'script_bytes', 'stylesheet_bytes', 'image_bytes', 'document_bytes', 'requests']);
export const METRIC_KEYS = Object.freeze([...RESOURCE_KEYS, 'lcp_ms', 'cls']);

function finiteNonnegative(value, label) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error(`${label} must be a finite nonnegative number`);
  return value;
}

export function validateBudgets(budgets) {
  if (!budgets || typeof budgets.conditions !== 'string' || !Array.isArray(budgets.pages) || !budgets.pages.length) throw new Error('Budgets need conditions and at least one page');
  const paths = new Set();
  for (const page of budgets.pages) {
    if (!page || typeof page.path !== 'string' || !page.path.startsWith('/') || page.path.startsWith('//') || /[\s?#\\]/.test(page.path)) throw new Error('Budget paths must be local absolute paths without queries or fragments');
    if (paths.has(page.path)) throw new Error(`Duplicate budget path: ${page.path}`);
    paths.add(page.path);
    if (!page.limits || Array.isArray(page.limits) || typeof page.limits !== 'object' || !Object.keys(page.limits).length) throw new Error(`Missing limits: ${page.path}`);
    for (const [key, limit] of Object.entries(page.limits)) {
      if (!RESOURCE_KEYS.includes(key)) throw new Error(`Unknown budget key: ${key}`);
      finiteNonnegative(limit, `${page.path} ${key}`);
      if (!Number.isSafeInteger(limit)) throw new Error(`Resource limit ${key} must be an integer`);
    }
  }
  return budgets;
}

export function readMetrics(lhr) {
  if (lhr.runtimeError) throw new Error(lhr.runtimeError.message);
  const rows = lhr.audits?.['resource-summary']?.details?.items;
  if (!Array.isArray(rows)) throw new Error('Lighthouse resource summary is missing');
  const metric = (kind, field) => finiteNonnegative(rows.find(row => row.resourceType === kind)?.[field], `${kind}.${field}`);
  return {
    total_bytes: metric('total', 'transferSize'), script_bytes: metric('script', 'transferSize'),
    stylesheet_bytes: metric('stylesheet', 'transferSize'), image_bytes: metric('image', 'transferSize'),
    document_bytes: metric('document', 'transferSize'), requests: metric('total', 'requestCount'),
    lcp_ms: finiteNonnegative(lhr.audits?.['largest-contentful-paint']?.numericValue, 'LCP'),
    cls: finiteNonnegative(lhr.audits?.['cumulative-layout-shift']?.numericValue, 'CLS'),
  };
}

export function summarizeRuns(runs) {
  if (!Array.isArray(runs) || !runs.length) throw new Error('No performance samples');
  return Object.fromEntries(METRIC_KEYS.map(key => {
    const values = runs.map(run => finiteNonnegative(run[key], key)).sort((a, b) => a - b);
    const middle = Math.floor(values.length / 2);
    return [key, values.length % 2 ? values[middle] : (values[middle - 1] + values[middle]) / 2];
  }));
}

export function budgetViolations(metrics, limits) {
  return Object.entries(limits).flatMap(([key, maximum]) => {
    if (!RESOURCE_KEYS.includes(key)) throw new Error(`Unknown budget key: ${key}`);
    const actual = finiteNonnegative(metrics[key], key);
    finiteNonnegative(maximum, `limit ${key}`);
    return actual > maximum ? [`${key}: ${actual} > ${maximum}`] : [];
  });
}
