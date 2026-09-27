import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeAccessibility, accessibilityMarkdown } from '../../scripts/accessibility-summary.mjs';

const baseline = {
  schema: 1, axeVersion: '4.13.0', triagedOn: '2026-09-27', reviewPolicy: 'Manual review is still required.',
  rules: { 'color-contrast': { messageKeys: ['pseudoContent'], reason: 'Layered background.', manualStatus: 'pending' } },
  states: { home: { 'color-contrast': 2 }, search: {} },
};
const report = (incomplete = [], violations = []) => ({ schema: 1, axeVersion: '4.13.0', incomplete, violations });
const node = (reason = 'pseudoContent') => ({ target: ['.sample'], any: [{ data: { messageKey: reason } }], all: [], none: [] });

test('reviewed incomplete limitations stay visible without becoming confirmed failures', () => {
  const result = summarizeAccessibility({ home: report([{ id: 'color-contrast', nodes: [node()] }]), search: report() }, baseline);
  assert.equal(result.passed, true);
  assert.equal(result.states[0].incomplete[0].nodes, 1);
  assert.match(accessibilityMarkdown(result), /Manual checks below remain unresolved/);
  assert.match(accessibilityMarkdown(result), /Layered background/);
});

test('confirmed violations, unknown reasons and growing envelopes need attention', () => {
  for (const [incomplete, violations, expected] of [
    [[], [{ id: 'button-name', nodes: [node()] }], /confirmed violations/],
    [[{ id: 'color-contrast', nodes: [node('bgImage')] }], [], /unreviewed reason/],
    [[{ id: 'color-contrast', nodes: [node(), node(), node()] }], [], /exceed envelope/],
    [[{ id: 'unknown-rule', nodes: [node()] }], [], /unreviewed incomplete rule/],
  ]) {
    const result = summarizeAccessibility({ home: report(incomplete, violations), search: report() }, baseline);
    assert.equal(result.passed, false);
    assert.match(result.issues.join('\n'), expected);
  }
});

test('missing reports and a changed axe engine cannot produce a complete pass', () => {
  assert.equal(summarizeAccessibility({ home: report() }, baseline).passed, false);
  assert.equal(summarizeAccessibility({ home: report() }, baseline, { allowPartial: true }).passed, true);
  assert.equal(summarizeAccessibility({}, baseline, { allowPartial: true }).passed, false);
  assert.equal(summarizeAccessibility({ home: { ...report(), axeVersion: 'new' }, search: report() }, baseline).passed, false);
  assert.equal(summarizeAccessibility({ home: { error: 'Timed out' }, search: report() }, baseline).passed, false);
});

test('invalid baseline entries fail before reports can be accepted', () => {
  for (const maximum of [NaN, Infinity, -1, '2']) {
    assert.throws(() => summarizeAccessibility({}, { ...baseline, states: { home: { 'color-contrast': maximum } } }), /invalid node envelope/);
  }
  assert.throws(() => summarizeAccessibility({}, { ...baseline, states: { home: { unknown: 1 } } }), /Missing reviewed rule/);
});

test('a reviewed dialog reference cannot hide a different unresolved target', () => {
  const dialogBaseline = {
    ...baseline,
    rules: { controls: { messageKeys: ['controlsWithinPopup'], targets: [['#search']], reason: 'Native closed dialog.', manualStatus: 'DOM verified' } },
    states: { home: { controls: 1 } },
  };
  const incomplete = [{ id: 'controls', nodes: [{ ...node('controlsWithinPopup'), target: ['#other'] }] }];
  assert.equal(summarizeAccessibility({ home: report(incomplete) }, dialogBaseline).passed, false);
  incomplete[0].nodes[0].target = ['#search'];
  assert.equal(summarizeAccessibility({ home: report(incomplete) }, dialogBaseline).passed, true);
});
