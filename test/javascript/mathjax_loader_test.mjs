import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../../app/javascript/mathjax_loader.js', import.meta.url), 'utf8');

function loaderFixture({ hasMath = true } = {}) {
  const timers = new Map();
  const scripts = [];
  const events = [];
  const windowListeners = {};
  const fontListeners = {};
  const notice = {
    hidden: true,
    dataset: {
      mathjaxComponentUrl: 'https://cdn.jsdelivr.net/npm/mathjax@9.2.1/tex-chtml.js',
      mathjaxFontUrl: 'https://cdn.jsdelivr.net/npm/@mathjax/mathjax-newcm-font@8.3.2',
      mathjaxFontPath: 'https://cdn.jsdelivr.net/npm/@mathjax/%%FONT%%-font@8.3.2'
    }
  };
  const status = { textContent: '' };
  const retry = { addEventListener(name, callback) { this[name] = callback; } };
  const page = { querySelector(selector) { return { '[data-math-notice]': notice, '[data-math-status]': status, '[data-math-retry]': retry }[selector]; } };
  const original = '<h2><a id="example"></a>Example</h2><p>Equation: $x + 1$.</p><pre><code>$unformatted$</code></pre>';
  const article = {
    innerHTML: original, dataset: {}, closest: () => page, querySelector: () => null,
    getBoundingClientRect: () => ({ width: 800 }), dispatchEvent: event => events.push(event.type)
  };
  const observers = [];
  let reloads = 0;
  const window = { location: { reload() { reloads += 1; } }, addEventListener(name, callback) { windowListeners[name] = callback; } };
  const context = vm.createContext({
    window, Event, Promise,
    document: {
      readyState: 'complete', querySelector: () => hasMath ? article : null,
      createElement: () => ({}), head: { appendChild: script => scripts.push(script) },
      fonts: { addEventListener(name, callback) { fontListeners[name] = callback; }, removeEventListener(name) { delete fontListeners[name]; } }
    },
    setTimeout(callback, delay) { const id = Symbol(); timers.set(id, { callback, delay }); return id; },
    clearTimeout(id) { timers.delete(id); },
    ResizeObserver: class {
      constructor(callback) { this.callback = callback; observers.push(this); }
      observe() { this.disconnected = false; }
      disconnect() { this.disconnected = true; }
    }
  });
  vm.runInContext(source, context);
  return { article, original, notice, status, retry, scripts, timers, window, windowListeners, fontListeners, observers, events, context, reloads: () => reloads };
}

test('unflagged articles do not request or configure the optional renderer', () => {
  const fixture = loaderFixture({ hasMath: false });
  assert.equal(fixture.scripts.length, 0);
  assert.equal(fixture.window.MathJax, undefined);
});

test('component and font URLs use the independently pinned page configuration', () => {
  const { notice, scripts, window } = loaderFixture();
  assert.equal(scripts[0].src, notice.dataset.mathjaxComponentUrl);
  assert.equal(window.MathJax.loader.paths['mathjax-newcm'], notice.dataset.mathjaxFontUrl);
  assert.equal(window.MathJax.output.fontPath, notice.dataset.mathjaxFontPath);
  assert.equal(window.MathJax.chtml.fontURL, `${notice.dataset.mathjaxFontUrl}/chtml/woff2`);
  assert.equal(window.MathJax.chtml.dynamicPrefix, `${notice.dataset.mathjaxFontUrl}/chtml/dynamic`);
});

test('network failure exposes source and a usable retry without duplicate initialization', () => {
  const fixture = loaderFixture();
  fixture.scripts[0].onerror();
  assert.equal(fixture.article.dataset.mathState, 'failed');
  assert.equal(fixture.article.innerHTML, fixture.original);
  assert.equal(fixture.notice.hidden, false);
  assert.match(fixture.status.textContent, /TeX source/);
  assert.equal(fixture.timers.size, 0);
  vm.runInContext('loadMathJax()', fixture.context);
  assert.equal(fixture.scripts.length, 1);
  fixture.retry.click();
  assert.equal(fixture.reloads(), 1);
});

test('component and math font failures restore partially changed content', () => {
  for (const failure of ['component', 'font']) {
    const fixture = loaderFixture();
    fixture.article.innerHTML = '<mjx-container>partial</mjx-container>';
    if (failure === 'component') fixture.window.MathJax.loader.failed(new Error('Blocked component'));
    else fixture.fontListeners.loadingerror({ fontfaces: [{ family: 'MJX-NCM' }] });
    assert.equal(fixture.article.innerHTML, fixture.original);
    assert.equal(fixture.article.dataset.mathState, 'failed');
    assert.deepEqual(fixture.events, ['article:content-restored']);
  }
  const fixture = loaderFixture();
  fixture.fontListeners.loadingerror({ fontfaces: [{ family: 'Unrelated website font' }] });
  assert.equal(fixture.article.dataset.mathState, 'loading');
});

test('rejected typesetting restores article markup and handles the rejection', async () => {
  const fixture = loaderFixture();
  fixture.window.MathJax.startup.defaultPageReady = () => {
    fixture.article.innerHTML = '<mjx-container>partial</mjx-container>';
    return Promise.reject(new Error('Typesetting failed'));
  };
  await fixture.window.MathJax.startup.pageReady();
  assert.equal(fixture.article.innerHTML, fixture.original);
  assert.equal(fixture.notice.hidden, false);
});

test('a late successful renderer cannot replace fallback source after its timeout', async () => {
  const fixture = loaderFixture();
  let finish;
  fixture.window.MathJax.startup.defaultPageReady = () => new Promise(resolve => { finish = resolve; });
  const loading = fixture.window.MathJax.startup.pageReady();
  await Promise.resolve();
  [...fixture.timers.values()].find(timer => timer.delay === 20000).callback();
  fixture.article.innerHTML = '<mjx-container>late output</mjx-container>';
  finish();
  await loading;
  assert.equal(fixture.article.innerHTML, fixture.original);
  assert.equal(fixture.article.dataset.mathState, 'failed');
});

test('successful rendering observes widths and a resize failure returns to source', async () => {
  const fixture = loaderFixture();
  fixture.window.MathJax.startup.defaultPageReady = () => Promise.resolve();
  await fixture.window.MathJax.startup.pageReady();
  assert.equal(fixture.article.dataset.mathState, 'ready');
  assert.equal(fixture.notice.hidden, true);
  assert.equal(fixture.timers.size, 0);
  fixture.window.MathJax.whenReady = callback => callback();
  fixture.window.MathJax.startup.document = { rerenderPromise: () => Promise.reject(new Error('Resize failed')) };
  fixture.observers[0].callback([{ contentRect: { width: 320 } }]);
  [...fixture.timers.values()].find(timer => timer.delay === 120).callback();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(fixture.article.dataset.mathState, 'failed');
  assert.equal(fixture.observers[0].disconnected, true);
});
