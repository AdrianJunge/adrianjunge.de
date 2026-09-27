import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../../app/javascript/site_search.js', import.meta.url), 'utf8');
const search = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const cases = JSON.parse(await readFile(new URL('../fixtures/site_search_cases.json', import.meta.url), 'utf8'));

test('client and server share ranking, accent handling, all-word matching and section URL contracts', () => {
  for (const example of cases.queries) {
    assert.deepEqual(search.searchSite(cases.documents, example.q).map(result => result.url), example.urls, example.q);
  }
  assert.equal(search.searchSite(cases.documents, 'needle', { limit: 2 }).length, 2);
  assert.deepEqual(search.searchSite(cases.documents, 'needle', { limit: -1 }), []);
  assert.equal(search.searchQuery(['unexpected']), '');
  assert.equal(search.searchQuery('x'.repeat(300)).length, 200);
});

test('snippets expose matching context as plain text with bounded length', () => {
  const text = 'Intro. '.repeat(80) + 'Needle <em>example</em>. ' + 'Ending. '.repeat(80);
  const snippet = search.siteSearchSnippet(text, ['needle']);
  assert.match(snippet, /Needle <em>example<\/em>/);
  assert.ok(snippet.startsWith('…') && snippet.endsWith('…'));
  assert.ok(snippet.length <= 202);
});

test('global results are not silently truncated and replace existing fragments for section destinations', () => {
  const documents = Array.from({ length: 35 }, (_, index) => ({
    title: `Needle page ${index}`, kind: 'Page', url: `/page-${index}#overview`, tags: [],
    sections: [{ heading: 'Needle notes', anchor: 'notes', text: 'A matching paragraph.' }]
  }));
  const results = search.searchSite(documents, 'notes');
  assert.equal(results.length, 35);
  assert.ok(results.every(result => result.url.endsWith('#notes')));
  assert.ok(results.every(result => !result.url.includes('#overview#')));
  assert.ok(search.searchSite(documents, 'needle').every(result => result.url.endsWith('#overview')));
});

test('the shared lazy loader deduplicates concurrent requests and can retry a failed request', async () => {
  const originalFetch = globalThis.fetch;
  let requests = 0;
  globalThis.fetch = async (url, options) => {
    requests += 1;
    assert.equal(url, '/search/index.json');
    assert.equal(options.credentials, 'same-origin');
    if (requests === 1) throw new Error('Offline');
    return { ok: true, json: async () => ({ version: '2', documents: cases.documents }) };
  };
  try {
    const first = search.loadSiteSearchIndex();
    assert.equal(first, search.loadSiteSearchIndex());
    await assert.rejects(first, /Offline/);
    assert.deepEqual(await search.loadSiteSearchIndex(), cases.documents);
    assert.deepEqual(await search.loadSiteSearchIndex(), cases.documents);
    assert.equal(requests, 2);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

class SearchNode {
  constructor(tag = 'div') {
    this.tag = tag;
    this.dataset = {};
    this.children = [];
    this.listeners = new Map();
    this.attributes = new Map();
    this.value = '';
    this.textContent = '';
    this.hidden = false;
    const classes = new Set();
    this.classList = {
      toggle(name, enabled) { if (enabled) classes.add(name); else classes.delete(name); },
      contains(name) { return classes.has(name); }
    };
  }
  set innerHTML(_) { throw new Error('Search content must be inserted as plain text'); }
  setAttribute(name, value) { this.attributes.set(name, value); }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.children = nodes; }
  addEventListener(name, listener) {
    const listeners = this.listeners.get(name) || [];
    listeners.push(listener);
    this.listeners.set(name, listeners);
  }
  dispatch(name, event = {}) {
    for (const listener of this.listeners.get(name) || []) listener(event);
  }
  querySelectorAll(tag) {
    return this.children.flatMap(child => [ ...(child.tag === tag ? [child] : []), ...child.querySelectorAll(tag) ]);
  }
  focus() { globalThis.document.activeElement = this; }
}

function searchDOM() {
  const root = new SearchNode();
  const input = new SearchNode('input');
  const results = new SearchNode('ol');
  const status = new SearchNode('p');
  const retry = new SearchNode('button');
  const wrapper = new SearchNode();
  const clear = new SearchNode('button');
  const selectors = new Map([
    ['[data-site-search-query]', input], ['[data-site-search-results]', results],
    ['[data-site-search-status]', status], ['[data-site-search-retry]', retry],
    ['.search-wrapper', wrapper], ['[data-site-search-clear]', clear]
  ]);
  root.querySelector = selector => selectors.get(selector);
  return { root, input, results, status, retry, wrapper, clear, document: { createElement: tag => new SearchNode(tag), activeElement: input } };
}

test('live search ignores stale responses, renders plain text, and keeps blank status empty', async () => {
  const engine = await import(`data:text/javascript;base64,${Buffer.from(`${source}\n// DOM lifecycle test`).toString('base64')}`);
  const originalFetch = globalThis.fetch;
  const originalDocument = globalThis.document;
  const dom = searchDOM();
  let resolveRequest;
  let requests = 0;
  globalThis.document = dom.document;
  globalThis.fetch = () => {
    requests += 1;
    return new Promise(resolve => { resolveRequest = resolve; });
  };
  try {
    const controller = engine.initializeSiteSearch(dom.root);
    assert.equal(controller, engine.initializeSiteSearch(dom.root));
    await controller.update();
    assert.equal(requests, 0);
    assert.equal(dom.status.textContent, '');
    dom.input.value = 'absent';
    const oldUpdate = controller.update();
    dom.input.value = 'needle';
    const latestUpdate = controller.update();
    resolveRequest({ ok: true, json: async () => ({ version: '2', documents: [{
      title: '<script>Needle</script>', kind: 'Page', url: '/example', tags: [],
      sections: [{ heading: 'Example', anchor: 'example', text: 'Needle <img src=x> remains plain text.' }]
    }] }) });
    await Promise.all([oldUpdate, latestUpdate]);
    assert.equal(requests, 1);
    assert.equal(dom.status.textContent, '1 result');
    assert.equal(dom.results.children.length, 1);
    const link = dom.results.querySelectorAll('a')[0];
    assert.equal(link.className, 'site-search-result-link');
    assert.deepEqual(dom.results.children[0].children, [link]);
    assert.deepEqual(link.children.map(child => child.tag), ['span', 'span', 'p']);
    assert.equal(link.children[0].className, 'site-search-result-kind');
    assert.equal(link.children[0].textContent, 'Page');
    assert.equal(link.children[1].className, 'site-search-result-title');
    assert.equal(link.children[1].textContent, '<script>Needle</script> — Example');
    assert.equal(link.href, '/example');
    assert.equal(dom.results.querySelectorAll('a').length, 1);
    assert.match(link.children[2].textContent, /<img src=x>/);
    const onKey = dom.root.listeners.get('keydown')[0];
    let prevented = false;
    onKey({ key: 'ArrowDown', preventDefault() { prevented = true; } });
    assert.equal(globalThis.document.activeElement, link);
    assert.ok(prevented);
    onKey({ key: 'ArrowUp', preventDefault() {} });
    assert.equal(globalThis.document.activeElement, dom.input);
    dom.input.value = '';
    await controller.update();
    assert.equal(dom.status.textContent, '');
    assert.equal(dom.results.children.length, 0);
    assert.equal(dom.root.attributes.get('aria-busy'), 'false');
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.document = originalDocument;
  }
});

test('custom clear resets filled state and focus while ignoring an in-flight response', async () => {
  const engine = await import(`data:text/javascript;base64,${Buffer.from(`${source}\n// Clear in-flight response test`).toString('base64')}`);
  const originalFetch = globalThis.fetch;
  const originalDocument = globalThis.document;
  const dom = searchDOM();
  let resolveRequest;
  globalThis.document = dom.document;
  globalThis.fetch = () => new Promise(resolve => { resolveRequest = resolve; });
  try {
    const controller = engine.initializeSiteSearch(dom.root);
    assert.equal(dom.clear.hidden, true);
    assert.equal(dom.clear.disabled, true);
    dom.input.value = 'needle';
    const pending = controller.update();
    assert.ok(dom.wrapper.classList.contains('is-filled'));
    assert.equal(dom.clear.hidden, false);
    assert.equal(dom.clear.disabled, false);
    dom.results.scrollTop = 120;
    dom.clear.focus();
    dom.clear.dispatch('click');
    assert.equal(dom.input.value, '');
    assert.equal(dom.status.textContent, '');
    assert.equal(dom.results.children.length, 0);
    assert.equal(dom.results.scrollTop, 0);
    assert.equal(dom.document.activeElement, dom.input);
    assert.equal(dom.wrapper.classList.contains('is-filled'), false);
    assert.equal(dom.clear.hidden, true);
    assert.equal(dom.clear.disabled, true);
    resolveRequest({ ok: true, json: async () => ({ version: '2', documents: cases.documents }) });
    await pending;
    assert.equal(dom.status.textContent, '');
    assert.equal(dom.results.children.length, 0);
    assert.equal(dom.retry.hidden, true);
    assert.equal(dom.root.attributes.get('aria-busy'), 'false');
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.document = originalDocument;
  }
});

test('typing preserves existing rows until replacement results are ready and clear cancels debounce', async () => {
  const engine = await import(`data:text/javascript;base64,${Buffer.from(`${source}\n// Stable rows test`).toString('base64')}`);
  const originalFetch = globalThis.fetch;
  const originalDocument = globalThis.document;
  const originalSetTimeout = globalThis.setTimeout;
  const originalClearTimeout = globalThis.clearTimeout;
  const dom = searchDOM();
  const timers = new Map();
  let nextTimer = 0;
  globalThis.document = dom.document;
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ version: '2', documents: cases.documents }) });
  try {
    const controller = engine.initializeSiteSearch(dom.root);
    dom.input.value = 'needle';
    await controller.update();
    const originalRows = [...dom.results.children];
    assert.ok(originalRows.length > 0);
    dom.results.scrollTop = 125;
    globalThis.setTimeout = callback => { const id = ++nextTimer; timers.set(id, callback); return id; };
    globalThis.clearTimeout = id => timers.delete(id);
    dom.input.value = 'cafe';
    dom.input.dispatch('input');
    assert.deepEqual(dom.results.children, originalRows);
    assert.equal(dom.results.scrollTop, 125);
    assert.equal(timers.size, 1);
    const update = controller.update();
    assert.deepEqual(dom.results.children, originalRows);
    await update;
    assert.equal(timers.size, 0);
    assert.notDeepEqual(dom.results.children, originalRows);
    assert.equal(dom.results.scrollTop, 0);
    dom.input.value = 'queued query';
    dom.input.dispatch('input');
    assert.equal(timers.size, 1);
    dom.clear.dispatch('click');
    assert.equal(timers.size, 0);
    assert.equal(dom.results.children.length, 0);
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.document = originalDocument;
    globalThis.setTimeout = originalSetTimeout;
    globalThis.clearTimeout = originalClearTimeout;
  }
});

const launcherSource = await readFile(new URL('../../app/javascript/site_search_launcher.js', import.meta.url), 'utf8');

test('modal scroll locking restores original styles and scroll without shifting scrollbar-free pages', () => {
  for (const options of [
    { width: 984, styles: [] },
    { width: 984, styles: [], unsupportedGutter: true },
    { width: 1000, styles: [] },
    { width: 984, styles: [['overflow-x', ['clip', 'important']]] },
    { width: 968, styles: [['overflow-x', ['clip', 'important']], ['overflow-y', ['scroll', '']], ['scrollbar-gutter', ['stable both-edges', '']]] }
  ]) {
    const properties = new Map(options.styles);
    const original = new Map(properties);
    const style = {
      getPropertyValue: name => properties.get(name)?.[0] || '',
      getPropertyPriority: name => properties.get(name)?.[1] || '',
      setProperty: (name, value, priority = '') => properties.set(name, [value, priority]),
      removeProperty: name => properties.delete(name)
    };
    const calls = [];
    const window = {
      innerWidth: 1000, scrollX: 0, scrollY: 730,
      getComputedStyle: () => ({ scrollbarGutter: options.unsupportedGutter ? undefined : style.getPropertyValue('scrollbar-gutter') || 'auto' }),
      scrollTo(position) { calls.push(position); this.scrollX = position.left; this.scrollY = position.top; }
    };
    const context = {
      window,
      document: { readyState: 'loading', addEventListener() {}, documentElement: { clientWidth: options.width, style } }
    };
    vm.runInNewContext(launcherSource, context);
    const unlock = context.lockSiteSearchPageScroll();
    assert.equal(style.getPropertyValue('overflow-x'), 'hidden');
    assert.equal(style.getPropertyValue('overflow-y'), 'hidden');
    assert.equal(style.getPropertyValue('scrollbar-gutter'), options.width === 1000 ? '' : options.width === 968 ? 'stable both-edges' : 'stable');
    assert.equal(window.scrollY, 730);
    window.scrollY = 740;
    unlock();
    assert.deepEqual(properties, original);
    assert.equal(window.scrollY, 730);
    assert.equal(calls.length, 1);
    window.scrollY = 900;
    unlock();
    assert.equal(window.scrollY, 900, 'a queued close event cannot undo result anchor navigation');
    assert.equal(calls.length, 1);
  }
});

test('outside dismissal accepts mouse and touch taps but protects padding, inside drags and cancelled gestures', () => {
  const context = { document: { readyState: 'loading', addEventListener() {} } };
  vm.runInNewContext(launcherSource, context);
  const dialog = new SearchNode('dialog');
  dialog.open = true;
  dialog.getBoundingClientRect = () => ({ left: 100, top: 100, right: 500, bottom: 500 });
  let closes = 0;
  dialog.close = () => { closes += 1; dialog.open = false; dialog.dispatch('close'); };
  context.bindSiteSearchOutsideDismissal(dialog);
  const pointer = (x, y, pointerType = 'mouse', pointerId = 1) => ({ clientX: x, clientY: y, pointerType, pointerId, isPrimary: true, button: 0 });
  const click = (x, y) => {
    let prevented = false;
    let stopped = false;
    dialog.dispatch('click', { clientX: x, clientY: y, target: dialog, preventDefault() { prevented = true; }, stopPropagation() { stopped = true; } });
    return { prevented, stopped };
  };
  const tap = (x, y, type) => {
    dialog.dispatch('pointerdown', pointer(x, y, type));
    dialog.dispatch('pointerup', pointer(x, y, type));
    return click(x, y);
  };

  assert.deepEqual(tap(104, 104, 'mouse'), { prevented: false, stopped: false });
  assert.equal(closes, 0, 'Clicks in dialog padding must remain inside');
  dialog.dispatch('pointerdown', pointer(110, 110));
  dialog.dispatch('pointerup', pointer(80, 80));
  click(80, 80);
  assert.equal(closes, 0, 'Dragging from inside must not dismiss');
  dialog.dispatch('pointerdown', pointer(50, 50, 'touch'));
  dialog.dispatch('pointercancel');
  dialog.dispatch('pointerup', pointer(50, 50, 'touch'));
  click(50, 50);
  assert.equal(closes, 0, 'Cancelled touch gestures must not dismiss');
  dialog.dispatch('pointerdown', pointer(50, 50));
  dialog.dispatch('pointerup', pointer(50, 80));
  click(50, 80);
  assert.equal(closes, 0, 'An outside drag must not act as a click');
  assert.deepEqual(tap(50, 50, 'mouse'), { prevented: true, stopped: true });
  assert.equal(closes, 1);
  dialog.open = true;
  assert.deepEqual(tap(550, 550, 'touch'), { prevented: true, stopped: true });
  assert.equal(closes, 2);
});

test('failed live search exposes a retry that can recover without navigation', async () => {
  const engine = await import(`data:text/javascript;base64,${Buffer.from(`${source}\n// DOM retry test`).toString('base64')}`);
  const originalFetch = globalThis.fetch;
  const originalDocument = globalThis.document;
  const dom = searchDOM();
  globalThis.document = dom.document;
  globalThis.fetch = async () => { throw new Error('Offline'); };
  try {
    const controller = engine.initializeSiteSearch(dom.root);
    dom.input.value = 'needle';
    await controller.update();
    assert.match(dom.status.textContent, /could not load/);
    assert.equal(dom.retry.hidden, false);
    assert.equal(dom.root.attributes.get('aria-busy'), 'false');
    globalThis.fetch = async () => ({ ok: true, json: async () => ({ version: '2', documents: cases.documents }) });
    await controller.update();
    assert.equal(dom.retry.hidden, true);
    assert.ok(dom.results.children.length > 0);
    assert.match(dom.status.textContent, /results/);
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.document = originalDocument;
  }
});
