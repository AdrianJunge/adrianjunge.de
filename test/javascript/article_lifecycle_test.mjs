import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../../app/javascript/blog.js', import.meta.url), 'utf8');

test('article layout observation resumes after every cached history restoration', () => {
  const listeners = new Map();
  const observers = [];
  const article = {};
  let updates = 0;
  const context = vm.createContext({
    document: { readyState: 'loading', addEventListener() {} },
    window: {
      addEventListener(type, callback) {
        if (!listeners.has(type)) listeners.set(type, []);
        listeners.get(type).push(callback);
      }
    },
    ResizeObserver: class {
      constructor(callback) { this.callback = callback; observers.push(this); }
      observe(target) { this.target = target; }
      disconnect() { this.target = null; }
    },
    article,
    update: () => { updates += 1; }
  });
  vm.runInContext(source, context);
  vm.runInContext('observeArticleLayout(article, update)', context);
  assert.equal(observers.length, 1);
  assert.equal(observers[0].target, article);

  const emit = (type, persisted) => listeners.get(type)?.forEach(callback => callback({ persisted }));
  emit('pageshow', false);
  assert.equal(updates, 0);
  for (let restore = 1; restore <= 3; restore += 1) {
    emit('pagehide', true);
    assert.equal(observers[0].target, null);
    emit('pageshow', true);
    assert.equal(observers[0].target, article);
    assert.equal(updates, restore * 2 - 1, 'restore refreshes geometry before a later image or math resize');
    observers[0].callback();
    assert.equal(updates, restore * 2);
  }
  assert.equal(observers.length, 1, 'restoration reuses the observer instead of multiplying callbacks');
});
