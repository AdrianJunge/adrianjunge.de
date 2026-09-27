import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function validateBaseline(baseline) {
  if (baseline?.schema !== 1 || typeof baseline.axeVersion !== 'string' || !baseline.states || !baseline.rules) {
    throw new Error('Invalid accessibility baseline schema.');
  }
  if (!Object.keys(baseline.states).length) throw new Error('Accessibility baseline must name at least one state.');
  for (const [state, limits] of Object.entries(baseline.states)) {
    if (!/^[a-z0-9-]+$/.test(state)) throw new Error(`Invalid accessibility state: ${state}`);
    for (const [id, maximum] of Object.entries(limits)) {
      const rule = baseline.rules[id];
      if (!Number.isInteger(maximum) || maximum < 0 || !rule?.reason || !rule.manualStatus ||
          !Array.isArray(rule.messageKeys) || !rule.messageKeys.length) {
        throw new Error(`Missing reviewed rule or invalid node envelope: ${state}/${id}`);
      }
    }
  }
}

export function summarizeAccessibility(reports, baseline, { allowPartial = false } = {}) {
  validateBaseline(baseline);
  const issues = [];
  const states = [];
  for (const [state, limits] of Object.entries(baseline.states)) {
    const report = reports[state];
    if (!report) {
      if (!allowPartial) issues.push(`${state}: report missing; run the full accessibility suite.`);
      continue;
    }
    if (report.error || report.schema !== 1 || !Array.isArray(report.violations) || !Array.isArray(report.incomplete)) {
      issues.push(`${state}: invalid or failed axe report (${report.error || 'schema/arrays missing'}).`);
      continue;
    }
    if (report.axeVersion !== baseline.axeVersion) {
      issues.push(`${state}: axe ${report.axeVersion} differs from reviewed ${baseline.axeVersion}; review the baseline.`);
    }
    const violations = report.violations.map(rule => ({ id: rule.id, nodes: rule.nodes?.length || 0 }));
    if (violations.length) issues.push(`${state}: confirmed violations: ${violations.map(rule => rule.id).join(', ')}.`);
    const incomplete = report.incomplete.map(rule => {
      const review = baseline.rules[rule.id];
      const maximum = limits[rule.id];
      const nodes = rule.nodes || [];
      const unexpected = nodes.filter(node => {
        const checks = [...(node.any || []), ...(node.all || []), ...(node.none || [])];
        const knownReason = checks.length > 0 && checks.every(check => review?.messageKeys.includes(check.data?.messageKey));
        const knownTarget = !review?.targets || review.targets.some(target => JSON.stringify(target) === JSON.stringify(node.target));
        return !knownReason || !knownTarget;
      });
      if (maximum === undefined || !review) issues.push(`${state}: unreviewed incomplete rule ${rule.id}.`);
      else if (nodes.length > maximum) issues.push(`${state}: ${rule.id} needs review (${nodes.length} nodes exceed envelope ${maximum}).`);
      if (unexpected.length) issues.push(`${state}: ${rule.id} has ${unexpected.length} node(s) with an unreviewed reason or target.`);
      return {
        id: rule.id, nodes: nodes.length, maximum: maximum ?? null,
        reason: review?.reason || 'Not triaged', manualStatus: review?.manualStatus || 'Needs triage',
        unexpectedTargets: unexpected.map(node => node.target),
      };
    });
    states.push({ state, path: report.path, viewport: report.viewport, capturedAt: report.capturedAt, violations, incomplete });
  }
  if (!states.length) issues.push('No valid accessibility reports found.');
  return { schema: 1, baselineTriagedOn: baseline.triagedOn, policy: baseline.reviewPolicy, allowPartial, states, issues, passed: issues.length === 0 };
}

export function accessibilityMarkdown(summary) {
  const lines = [
    '# Accessibility evidence', '',
    summary.passed ? 'Confirmed violations and baseline checks passed. Manual checks below remain unresolved.' : 'Accessibility evidence needs attention; see the issues below.', '',
    summary.policy, '',
    '| State | Confirmed violations | Incomplete checks |', '| --- | ---: | --- |',
    ...summary.states.map(state => `| ${state.state} | ${state.violations.reduce((total, rule) => total + rule.nodes, 0)} | ${state.incomplete.map(rule => `${rule.id}: ${rule.nodes}${rule.maximum === null ? '' : ` / ${rule.maximum} envelope`}`).join('; ') || 'None'} |`),
    '', '## Manual inspection still required', '',
  ];
  const rules = new Map(summary.states.flatMap(state => state.incomplete.map(rule => [rule.id, rule])));
  for (const [id, rule] of rules) lines.push(`- **${id}** — ${rule.reason} Status: ${rule.manualStatus}.`);
  lines.push('', 'Use the raw per-state JSON to review every affected selector manually. Incomplete nodes are not confirmed violations.', '');
  if (summary.issues.length) lines.push('## Issues', '', ...summary.issues.map(issue => `- ${issue}`), '');
  if (summary.allowPartial) lines.push('Partial reporting was requested; this does not establish coverage of every configured state.', '');
  return lines.join('\n');
}

async function main() {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--allow-partial')) throw new Error('Usage: node scripts/accessibility-summary.mjs [--allow-partial]');
  const root = path.resolve(import.meta.dirname, '..');
  const directory = path.join(root, 'tmp/a11y');
  const baseline = JSON.parse(await fs.readFile(path.join(root, 'config/accessibility-baseline.json'), 'utf8'));
  validateBaseline(baseline);
  const reports = {};
  for (const state of Object.keys(baseline.states)) {
    try {
      reports[state] = JSON.parse(await fs.readFile(path.join(directory, `${state}.json`), 'utf8'));
    } catch (error) {
      if (error.code !== 'ENOENT') reports[state] = { error: error.message };
    }
  }
  const summary = summarizeAccessibility(reports, baseline, { allowPartial: args.includes('--allow-partial') });
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
