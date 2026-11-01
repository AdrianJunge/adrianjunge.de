import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const REQUIRED_STATES = Object.freeze([
  'home-default-mobile',
  'timeline-default-mobile',
  'about-default-mobile',
  'blog-java-strings-default-mobile',
  'blog-java-strngs-default-mobile',
  'timeline-more-filters-open-selected-mobile',
  'about-supporting-details-open-mobile',
  'site-search-dialog-results-mobile',
]);

const REVIEW_POLICY = 'Automated axe checks cannot establish full accessibility. Incomplete checks are unresolved and require manual review; inspect the raw per-state JSON.';

function validRule(rule) {
  return typeof rule?.id === 'string' && Array.isArray(rule.nodes) &&
    rule.nodes.every(node => node && Array.isArray(node.target));
}

function incompleteReasons(rule) {
  const messages = rule.nodes.flatMap(node => {
    const checks = [...(node.any || []), ...(node.all || []), ...(node.none || [])];
    return checks.length ? checks.map(check => check.message) : [node.failureSummary];
  });
  return [...new Set(messages.filter(message => typeof message === 'string' && message.trim())
    .map(message => message.replace(/\s+/g, ' ').trim()))];
}

export function summarizeAccessibility(reports, { requiredStates = REQUIRED_STATES, expectedAxeVersion } = {}) {
  if (!Array.isArray(requiredStates) || requiredStates.length === 0 ||
      requiredStates.some(state => typeof state !== 'string' || !/^[a-z0-9-]+$/.test(state)) ||
      new Set(requiredStates).size !== requiredStates.length ||
      typeof expectedAxeVersion !== 'string' || !expectedAxeVersion) {
    throw new Error('Required accessibility states and expected axe version must be provided.');
  }

  const issues = [];
  const states = [];
  for (const state of requiredStates) {
    const report = reports[state];
    if (!report) {
      issues.push(`${state}: report missing; run the full accessibility suite.`);
      continue;
    }
    if (report.error || report.schema !== 1 || typeof report.axeVersion !== 'string' ||
        !Array.isArray(report.violations) || !Array.isArray(report.incomplete) ||
        ![...report.violations, ...report.incomplete].every(validRule)) {
      issues.push(`${state}: invalid or failed axe report (${report.error || 'schema/rules missing'}).`);
      continue;
    }
    if (report.axeVersion !== expectedAxeVersion) {
      issues.push(`${state}: axe ${report.axeVersion} differs from pinned axe-core version ${expectedAxeVersion}.`);
    }
    const violations = report.violations.map(rule => ({ id: rule.id, nodes: rule.nodes.length }));
    if (violations.length) issues.push(`${state}: confirmed violations: ${violations.map(rule => rule.id).join(', ')}.`);
    const incomplete = report.incomplete.map(rule => ({
      id: rule.id, nodes: rule.nodes.length, reasons: incompleteReasons(rule),
    }));
    states.push({ state, path: report.path, viewport: report.viewport, capturedAt: report.capturedAt, violations, incomplete });
  }
  if (!states.length) issues.push('No valid accessibility reports found.');
  return { schema: 1, axeVersion: expectedAxeVersion, policy: REVIEW_POLICY, states, issues, passed: issues.length === 0 };
}

export function accessibilityMarkdown(summary) {
  const lines = [
    '# Accessibility evidence', '',
    summary.passed ? 'No confirmed axe violations were found in the required states.' : 'Accessibility evidence needs attention; see the issues below.', '',
    summary.policy, '',
    '| State | Confirmed violations | Incomplete checks |', '| --- | ---: | --- |',
    ...summary.states.map(state => `| ${state.state} | ${state.violations.reduce((total, rule) => total + rule.nodes, 0)} | ${state.incomplete.map(rule => `${rule.id}: ${rule.nodes}`).join('; ') || 'None'} |`),
    '', '## Manual inspection still required', '',
  ];
  const reasonsByRule = new Map();
  for (const state of summary.states) {
    for (const rule of state.incomplete) {
      const reasons = reasonsByRule.get(rule.id) || new Set();
      rule.reasons.forEach(reason => reasons.add(reason));
      reasonsByRule.set(rule.id, reasons);
    }
  }
  if (reasonsByRule.size === 0) lines.push('No incomplete axe checks were reported.');
  for (const [id, reasons] of reasonsByRule) {
    lines.push(`- **${id}** — ${[...reasons].join('; ') || 'Axe did not provide a reason.'}`);
  }
  lines.push('', 'Use the raw per-state JSON to review every affected selector. Incomplete nodes are not confirmed violations.', '');
  if (summary.issues.length) lines.push('## Issues', '', ...summary.issues.map(issue => `- ${issue}`), '');
  return lines.join('\n');
}

async function main() {
  if (process.argv.length > 2) throw new Error('Usage: node scripts/accessibility-summary.mjs');
  const root = path.resolve(import.meta.dirname, '..');
  const directory = path.join(root, 'tmp/a11y');
  const manifest = JSON.parse(await fs.readFile(path.join(root, 'package.json'), 'utf8'));
  const expectedAxeVersion = manifest.devDependencies?.['axe-core'];
  const reports = {};
  for (const state of REQUIRED_STATES) {
    try {
      reports[state] = JSON.parse(await fs.readFile(path.join(directory, `${state}.json`), 'utf8'));
    } catch (error) {
      if (error.code !== 'ENOENT') reports[state] = { error: error.message };
    }
  }
  const summary = summarizeAccessibility(reports, { expectedAxeVersion });
  const markdown = accessibilityMarkdown(summary);
  await fs.mkdir(directory, { recursive: true });
  await fs.writeFile(path.join(directory, 'summary.json'), `${JSON.stringify(summary, null, 2)}\n`);
  await fs.writeFile(path.join(directory, 'summary.md'), markdown);
  if (process.env.GITHUB_STEP_SUMMARY) await fs.appendFile(process.env.GITHUB_STEP_SUMMARY, markdown);
  console.log(markdown);
  if (!summary.passed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
