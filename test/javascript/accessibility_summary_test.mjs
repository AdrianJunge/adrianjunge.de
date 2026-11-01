import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeAccessibility, accessibilityMarkdown } from '../../scripts/accessibility-summary.mjs';

const options = { requiredStates: ['home', 'search'], expectedAxeVersion: '4.14.0' };
const report = (incomplete = [], violations = []) => ({ schema: 1, axeVersion: '4.14.0', incomplete, violations });
const node = (message = "Element's background color could not be determined due to a pseudo element") => ({
  target: ['.sample'], any: [{ message }], all: [], none: [],
});
const summarize = reports => summarizeAccessibility(reports, options);

test('incomplete checks remain visible without a count gate', () => {
  const result = summarize({
    home: report([{ id: 'color-contrast', nodes: Array.from({ length: 701 }, () => node()) }]),
    search: report(),
  });
  assert.equal(result.passed, true);
  assert.equal(result.states[0].incomplete[0].nodes, 701);
  assert.deepEqual(result.states[0].incomplete[0].reasons, [node().any[0].message]);
  assert.match(accessibilityMarkdown(result), /color-contrast: 701/);
  assert.match(accessibilityMarkdown(result), /Manual inspection still required/);
  assert.doesNotMatch(accessibilityMarkdown(result), /envelope|baseline/i);
});

test('confirmed violations still fail the summary', () => {
  const result = summarize({
    home: report([], [{ id: 'button-name', nodes: [node()] }]),
    search: report(),
  });
  assert.equal(result.passed, false);
  assert.match(result.issues.join('\n'), /confirmed violations: button-name/);
  assert.match(accessibilityMarkdown(result), /## Issues/);
});

test('missing, invalid, and stale reports cannot produce a pass', () => {
  assert.equal(summarize({ home: report() }).passed, false);
  assert.equal(summarize({}).passed, false);
  assert.equal(summarize({ home: { error: 'Timed out' }, search: report() }).passed, false);
  assert.equal(summarize({ home: { ...report(), incomplete: [{ id: 'color-contrast' }] }, search: report() }).passed, false);
  assert.equal(summarize({ home: { ...report(), axeVersion: '4.13.0' }, search: report() }).passed, false);
});

test('the required state list and expected axe version must be valid', () => {
  assert.throws(() => summarizeAccessibility({}, { requiredStates: [] }), /Required accessibility states/);
  assert.throws(() => summarizeAccessibility({}, { requiredStates: ['home', 'home'], expectedAxeVersion: '4.14.0' }), /Required accessibility states/);
});
