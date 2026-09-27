import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../../app/javascript/landing.js', import.meta.url), 'utf8');
const fallback = 'Politely asking software uncomfortable questions.';

function fixture({ hidden = false, visible = true, reduced = false, hasTagline = true } = {}) {
  const events = () => ({
    listeners: new Map(),
    addEventListener(name, callback) {
      if (!this.listeners.has(name)) this.listeners.set(name, []);
      this.listeners.get(name).push(callback);
    },
    emit(name) { (this.listeners.get(name) || []).forEach(callback => callback()); }
  });
  let now = 0;
  let id = 0;
  let seed = 137;
  let text = fallback;
  const changes = [];
  const timers = new Map();
  const cursors = [];
  const observers = [];
  const line = { getBoundingClientRect: () => visible ? { top: 100, bottom: 140 } : { top: 1200, bottom: 1240 } };
  const element = {
    dataset: {}, closest: () => line, after: cursor => cursors.push(cursor),
    get textContent() { return text; },
    set textContent(value) { if (value !== text) changes.push({ from: text, to: value, at: now }); text = value; }
  };
  const media = { ...events(), matches: reduced };
  const document = {
    ...events(), readyState: 'complete', hidden,
    getElementById: () => hasTagline ? element : null,
    querySelector: () => null,
    createElement: () => ({ style: {}, classList: { toggle() {} }, setAttribute() {} })
  };
  const window = {
    ...events(), innerHeight: 900, performance: { now: () => now }, matchMedia: () => media,
    setTimeout(callback, delay) { timers.set(++id, { callback, due: now + delay }); return id; },
    clearTimeout(timer) { timers.delete(timer); }
  };
  const context = vm.createContext({
    document, window,
    Math: Object.assign(Object.create(Math), { random() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 2 ** 32; } }),
    IntersectionObserver: class {
      constructor(callback) { this.callback = callback; observers.push(this); }
      observe(target) { this.target = target; }
    }
  });
  vm.runInContext(source, context);
  const next = () => [...timers.entries()].sort((a, b) => a[1].due - b[1].due)[0];
  function tick(milliseconds) {
    const until = now + milliseconds;
    while (next() && next()[1].due <= until) {
      const [key, timer] = next();
      now = timer.due;
      timers.delete(key);
      timer.callback();
      assert.ok(timers.size <= 1, 'animation must never schedule competing timer chains');
    }
    now = until;
  }
  return {
    element, changes, timers, cursors, observers, window, context, tick,
    delay: () => next()?.[1].due - now,
    step() { assert.equal(timers.size, 1); tick(this.delay()); },
    until(condition) {
      for (let steps = 0; !condition() && steps < 500; steps += 1) this.step();
      assert.ok(condition(), 'animation did not reach the expected visible state');
    },
    hide(value) { document.hidden = value; document.emit('visibilitychange'); },
    visible(value) { visible = value; observers[0].callback([{ isIntersecting: value }]); },
    reduce(value) { media.matches = value; media.emit('change'); }
  };
}

function assertContinuous(changes) {
  changes.forEach(({ from, to }) => {
    assert.equal(Math.abs(to.length - from.length), 1, `${from} -> ${to}`);
    assert.ok(from.startsWith(to) || to.startsWith(from), `${from} -> ${to}`);
  });
}

test('the initial sentence stays readable for two seconds before deleting one character', () => {
  const f = fixture();
  f.tick(1999);
  assert.equal(f.element.textContent, fallback);
  f.tick(1);
  assert.equal(f.element.textContent, fallback.slice(0, -1));
  assertContinuous(f.changes);
  assert.equal(f.observers[0].target, f.element.closest());
});

test('two shuffled cycles type every sentence completely and hold each for two seconds', () => {
  const f = fixture();
  const completed = [];
  for (let steps = 0; completed.length < 32 && steps < 6000; steps += 1) {
    f.step();
    if (f.delay() !== 2000) continue;
    const sentence = f.element.textContent;
    assert.notEqual(sentence, completed.at(-1));
    completed.push(sentence);
    f.tick(1999);
    assert.equal(f.element.textContent, sentence);
    f.tick(1);
    assert.equal(f.element.textContent, sentence.slice(0, -1));
  }
  assert.equal(completed.length, 32);
  assert.equal(new Set(completed.slice(0, 16)).size, 16);
  assert.deepEqual([...completed.slice(0, 16)].sort(), [...completed.slice(16)].sort());
  assert.notDeepEqual(completed.slice(0, 16), completed.slice(16));
  assertContinuous(f.changes);
});

test('rapid visibility changes preserve the current character and remaining delay in every phase', () => {
  for (const phase of ['initial hold', 'deleting', 'typing', 'sentence hold']) {
    for (const signal of ['hide', 'visible']) {
      const f = fixture();
      if (phase !== 'initial hold') f.step();
      if (phase === 'typing' || phase === 'sentence hold') {
        f.until(() => f.element.textContent === '');
        f.step();
      }
      if (phase === 'sentence hold') f.until(() => f.delay() === 2000);
      f.tick(10);
      const text = f.element.textContent;
      const delay = f.delay();
      for (let repeat = 0; repeat < 5; repeat += 1) {
        f[signal](signal === 'hide');
        f[signal](signal === 'hide');
        assert.equal(f.timers.size, 0);
        f.tick(5000);
        assert.equal(f.element.textContent, text);
        f[signal](signal !== 'hide');
        f[signal](signal !== 'hide');
        assert.equal(f.timers.size, 1);
        assert.equal(f.delay(), delay);
      }
      f.tick(delay - 1);
      assert.equal(f.element.textContent, text);
      f.tick(1);
      assert.notEqual(f.element.textContent, text);
      assertContinuous(f.changes);
    }
  }
});

test('initial suspension and restored pages retain their unfinished delay', () => {
  for (const options of [{ hidden: true }, { visible: false }]) {
    const f = fixture(options);
    assert.equal(f.timers.size, 0);
    f.tick(10000);
    f.hide(false);
    f.visible(true);
    assert.equal(f.delay(), 2000);
    f.tick(900);
    f.window.emit('pagehide');
    assert.equal(f.timers.size, 0);
    f.tick(10000);
    f.window.emit('pageshow');
    assert.equal(f.delay(), 1100);
    assert.equal(f.element.textContent, fallback);
    f.step();
    assert.equal(f.element.textContent, fallback.slice(0, -1));
  }
});

test('reduced motion is static and can be toggled without orphaned timers or cursors', () => {
  const f = fixture({ reduced: true });
  assert.equal(f.timers.size, 0);
  assert.equal(f.cursors[0].hidden, true);
  f.tick(10000);
  assert.equal(f.element.textContent, fallback);
  f.reduce(false);
  assert.equal(f.delay(), 2000);
  assert.equal(f.cursors[0].hidden, false);
  f.step();
  f.reduce(true);
  assert.equal(f.element.textContent, fallback);
  assert.equal(f.timers.size, 0);
  f.tick(10000);
  f.reduce(false);
  assert.equal(f.delay(), 2000);
  f.step();
  assert.equal(f.element.textContent, fallback.slice(0, -1));
  assert.equal(f.cursors.length, 1);
});

test('reinitialization does not duplicate animation and other pages stay untouched', () => {
  const f = fixture();
  vm.runInContext('initializeTagline()', f.context);
  assert.equal(f.cursors.length, 1);
  assert.equal(f.observers.length, 1);
  assert.equal(f.timers.size, 1);
  const other = fixture({ hasTagline: false });
  assert.equal(other.cursors.length, 0);
  assert.equal(other.timers.size, 0);
});
