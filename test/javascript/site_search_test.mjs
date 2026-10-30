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

test('complete phrases select the result, section and snippet before scattered words', () => {
  for (const example of cases.phrase_cases) {
    const results = search.searchSite(example.documents, example.q);
    assert.deepEqual(results.map(result => result.url), example.urls, example.q);
    assert.ok(results[0].snippet.includes(example.highlight), example.q);
    const terms = search.normalizeSiteSearch(example.q).split(' ');
    const ranges = search.siteSearchHighlightRanges(results[0].snippet, terms, { phrase: example.q });
    assert.deepEqual(ranges.map(([start, end]) => results[0].snippet.slice(start, end)), [example.highlight]);
  }
});

test('long phrases stay complete in snippets and phrase-only highlights ignore isolated words', () => {
  const query = 'word '.repeat(39) + 'final';
  const text = 'Earlier word. '.repeat(30) + query + ' Later word.'.repeat(30);
  const snippet = search.siteSearchSnippet(text, ['word', 'final'], query);
  assert.equal(snippet, `…${query}…`);
  assert.deepEqual(search.siteSearchHighlightRanges('We Are The Man In The Middle', ['the', 'p'], {
    phrase: cases.phrase_cases[0].q, phraseOnly: true
  }), []);
  assert.deepEqual(search.siteSearchHighlightRanges('alphabetical beta', ['alpha', 'beta'], {
    phrase: 'alpha beta', phraseOnly: true
  }), []);
});

test('result links use original matched phrases as text fragments and retain section anchors', () => {
  for (const example of cases.phrase_cases) {
    const result = search.searchSite(example.documents, example.q)[0];
    const url = search.siteSearchResultUrl(result);
    assert.ok(url.startsWith(`${example.urls[0]}:~:text=`), url);
    assert.equal(decodeURIComponent(url.split(':~:text=')[1]), example.highlight.replace(/\s+/gu, ' '));
  }
  const result = search.searchSite(cases.documents, 'CVE-2099-0001')[0];
  assert.equal(search.siteSearchResultUrl(result), '/about#case-study:~:text=CVE%2D2099%2D0001');
  assert.equal(search.siteSearchResultUrl({ url: '/about#section' }), '/about#section');
  assert.equal(search.siteSearchResultUrl({ url: '/blog/example#section:~:text=old', textTarget: { text: 'A-B, C&D (#1) 50%' } }),
    '/blog/example#section:~:text=A%2DB%2C%20C%26D%20%28%231%29%2050%25');
});

test('text fragments expand partial words and distinguish article headings and repeated passages', () => {
  const document = { title: 'Research notes', url: '/blog/notes', kind: 'Blog post', tags: [], sections: [
    { heading: 'Repeated heading', anchor: 'heading', text: 'Inspect GuardedString for secrets.' },
    { heading: 'Later', anchor: 'later', text: 'Another GuardedString appears here.' }
  ] };
  const partial = search.searchSite([document], 'guard')[0];
  assert.deepEqual(partial.textTarget, { text: 'GuardedString', prefix: 'Inspect' });
  assert.equal(search.siteSearchResultUrl(partial), '/blog/notes#heading:~:text=Inspect-,GuardedString');
  const heading = search.searchSite([document], 'Repeated heading')[0];
  assert.deepEqual(heading.textTarget, { text: 'Repeated heading', suffix: 'Inspect GuardedString for secrets.' });
  assert.equal(search.siteSearchResultUrl(heading), '/blog/notes#heading:~:text=Repeated%20heading,-Inspect%20GuardedString%20for%20secrets.');
});

test('highlights preserve original accents and ligatures and merge overlapping matches', () => {
  const text = 'CAFÉ, cafe\u0301, \ufb01le and 👩‍💻 Café';
  const ranges = search.siteSearchHighlightRanges(text, ['cafe', 'file']);
  assert.deepEqual(ranges.map(([start, end]) => text.slice(start, end)), ['CAFÉ', 'cafe\u0301', '\ufb01le', 'Café']);
  assert.deepEqual(search.siteSearchHighlightRanges('banana', ['ana', 'nan', 'ana']), [[1, 6]]);
  assert.deepEqual(search.siteSearchHighlightRanges('CVE-2026-1234', ['cve', '2026']), [[0, 3], [4, 8]]);
  assert.deepEqual(search.siteSearchHighlightRanges('nothing matches', ['needle']), []);
  assert.deepEqual(search.siteSearchHighlightRanges('unchanged', []), []);
});

test('text fragments use displayed passage order and distinguish sibling About cards', () => {
  const record = (id, passages) => ({ title: 'Same project', kind: 'CVE', url: `/about#${id}`, tags: [],
    sections: [{ heading: '', anchor: null, text: passages.join(' '), passages }] });
  const documents = [
    record('first', ['Same project', 'High', 'Same project', 'CVE-2026-1111', 'First finding']),
    record('second', ['Same project', 'High', 'Same project', 'CVE-2026-2222', 'Second finding'])
  ];
  const targets = search.searchSite(documents, 'CVE-2026-2222');
  assert.equal(search.siteSearchResultUrl(targets[0]), '/about#second:~:text=CVE%2D2026%2D2222');
  // Identical neighboring text cannot distinguish the High badges. The
  // element anchor must win over a text fragment that selects the first card.
  assert.deepEqual(search.searchSite(documents, 'High').map(search.siteSearchResultUrl), ['/about#first', '/about#second']);
  for (const document of documents) {
    document.sections = [{ heading: 'Reported to the security team.', anchor: null,
      text: '2026-07-24 Reported to the security team.', passages: ['2026-07-24', 'Reported to the security team.'] }];
  }
  assert.deepEqual(search.searchSite(documents, 'security').map(search.siteSearchResultUrl), ['/about#first', '/about#second']);
  const milestone = record('presentation', ['2026-07-27', 'Final presentation for the course']);
  milestone.sections[0].heading = 'Final presentation for the course';
  const result = search.searchSite([milestone], 'Final presentation for the course')[0];
  assert.equal(result.textTarget.prefix, '2026-07-27');
  assert.equal(result.textTarget.suffix, undefined);
  const multiBlock = record('blocks', ['First paragraph', 'Second paragraph']);
  const crossBlock = search.searchSite([multiBlock], 'First paragraph Second paragraph')[0];
  assert.ok(multiBlock.sections[0].passages.some(text => text.includes(crossBlock.textTarget.text)));
});

test('rendered page context distinguishes filter controls and unindexed cards without becoming searchable', () => {
  const passages = ['Sep 2019–2021', 'First steps with OverTheWire', 'Beginnings', 'OverTheWire', 'Linux', 'Web', 'Pwn', 'Crypto'];
  const milestone = { title: 'First steps with OverTheWire', kind: 'Timeline', url: '/timeline#overthewire', tags: ['Pwn'],
    sections: [{ heading: '', anchor: null, text: passages.join(' '), passages }] };
  const page = { title: 'Timeline', kind: 'Page', url: '/timeline', tags: [], sections: [],
    page_text: `Contextonlylabel Pwn 2019 ${passages.join(' ')}` };
  const result = search.searchSite([page, milestone], 'Pwn')[0];
  assert.deepEqual(result.textTarget, { text: 'Pwn', prefix: 'Web' });
  assert.equal(search.siteSearchResultUrl(result), '/timeline#overthewire:~:text=Web-,Pwn');
  assert.deepEqual(search.searchSite([page, milestone], 'Contextonlylabel'), []);
  assert.deepEqual(search.searchSite([page, milestone], '2019')[0].textTarget, { text: '2019', prefix: 'Sep' });

  // Another visible timeline card need not have a /timeline search document.
  // Its matching badges still make this target ambiguous, so keep the anchor.
  page.page_text += ' Other card Web Pwn Crypto';
  assert.equal(search.siteSearchResultUrl(search.searchSite([page, milestone], 'Pwn')[0]), '/timeline#overthewire');
  // Page context is authoritative regardless of record order.
  assert.equal(search.siteSearchResultUrl(search.searchSite([milestone, page], 'Pwn')[0]), '/timeline#overthewire');
});

test('same-page timeline search preserves oldest order while clearing filters', () => {
  const result = { url: '/timeline#overthewire', textTarget: { text: 'Pwn', prefix: 'Web' } };
  const currentUrl = 'https://example.com/timeline?order=oldest&view=posts&year=2026&tag=CVE&q=unrelated';
  assert.equal(search.siteSearchResultUrl(result, { currentUrl }), '/timeline?order=oldest#overthewire:~:text=Web-,Pwn');
  assert.equal(search.siteSearchResultUrl({ url: '/timeline#overthewire' }, { currentUrl }), '/timeline?order=oldest#overthewire');
  assert.equal(search.siteSearchResultUrl({ url: '/about#research' }, { currentUrl }), '/about#research');
  for (const source of ['https://example.com/blog?order=oldest', 'https://example.com/timeline?order=invalid', 'https://example.com/timeline?view=posts']) {
    assert.equal(search.siteSearchResultUrl(result, { currentUrl: source }), '/timeline#overthewire:~:text=Web-,Pwn');
  }
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

test('multi-author searches target one rendered name instead of crossing flex items', () => {
  for (const label of ['Challenge by', 'Article by']) {
    const passages = [label, 'nrg', ',', 'the_moon_guy'];
    const document = { title: 'Fantastic Doom', kind: 'CTF writeup', url: '/ctf/ehax/Fantastic%20Doom', tags: [],
      sections: [{ heading: '', anchor: null, text: passages.join(' '), passages }] };
    for (const query of ['nrg, the_moon_guy', 'nrg the_moon_guy', 'the_moon_guy', 'the_moon']) {
      const result = search.searchSite([document], query)[0];
      assert.ok(['nrg', 'the_moon_guy'].includes(result.textTarget.text));
      assert.ok(!search.siteSearchResultUrl(result).includes('%2C%20'));
    }
  }
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
  get textContent() { return this.text + this.children.map(child => child.textContent).join(''); }
  set textContent(value) { this.text = String(value); this.children = []; }
  set innerHTML(_) { throw new Error('Search content must be inserted as plain text'); }
  setAttribute(name, value) { this.attributes.set(name, value); }
  append(...nodes) { this.children.push(...nodes); }
  replaceChildren(...nodes) { this.text = ''; this.children = nodes; }
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
  return { root, input, results, status, retry, wrapper, clear, document: {
    createElement: tag => new SearchNode(tag),
    createTextNode: text => { const node = new SearchNode('#text'); node.textContent = text; return node; },
    activeElement: input
  } };
}

test('sentence results highlight the complete sentence without stray letters in the title or kind', async () => {
  const engine = await import(`data:text/javascript;base64,${Buffer.from(`${source}\n// Sentence rendering test`).toString('base64')}`);
  const originalFetch = globalThis.fetch;
  const originalDocument = globalThis.document;
  const dom = searchDOM();
  const example = cases.phrase_cases[0];
  globalThis.document = dom.document;
  globalThis.fetch = async () => ({ ok: true, json: async () => ({ version: '2', documents: example.documents }) });
  try {
    dom.input.value = example.q;
    await engine.initializeSiteSearch(dom.root).update();
    const first = dom.results.children[0];
    assert.deepEqual(first.querySelectorAll('mark').map(mark => mark.textContent), [example.highlight]);
    assert.equal(first.querySelectorAll('a')[0].href, `${example.urls[0]}:~:text=${encodeURIComponent(example.highlight)}`);
    assert.ok(first.querySelectorAll('p')[0].classList.contains('site-search-snippet-phrase'));
  } finally {
    globalThis.fetch = originalFetch;
    globalThis.document = originalDocument;
  }
});

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
      icon: { src: '/assets/example.svg', inverted: true },
      sections: [{ heading: 'Example', anchor: 'example', text: 'Needle <img src=x> remains plain text.' }]
    }] }) });
    await Promise.all([oldUpdate, latestUpdate]);
    assert.equal(requests, 1);
    assert.equal(dom.status.textContent, '1 result');
    assert.equal(dom.results.children.length, 1);
    const link = dom.results.querySelectorAll('a')[0];
    assert.equal(link.className, 'site-search-result-link');
    assert.deepEqual(dom.results.children[0].children, [link]);
    const [icon, heading, snippet] = link.children;
    assert.equal(icon.tag, 'img');
    assert.equal(icon.src, '/assets/example.svg');
    assert.equal(icon.alt, '');
    assert.equal(icon.className, 'site-search-result-icon site-search-result-icon-inverted');
    assert.equal(heading.children[0].textContent, 'Page');
    assert.equal(heading.children[1].textContent, '<script>Needle</script> — Example');
    assert.equal(link.href, '/example#:~:text=Needle,-%3Cimg%20src%3Dx%3E%20remains%20plain');
    assert.equal(dom.results.querySelectorAll('a').length, 1);
    assert.match(snippet.textContent, /<img src=x>/);
    assert.deepEqual(dom.results.querySelectorAll('mark').map(mark => mark.textContent), ['Needle', 'Needle']);
    assert.equal(dom.results.querySelectorAll('script').length, 0);
    assert.deepEqual(dom.results.querySelectorAll('img'), [icon]);
    const onKey = dom.root.listeners.get('keydown')[0];
    let prevented = false;
    onKey({ key: 'ArrowDown', preventDefault() { prevented = true; } });
    assert.equal(globalThis.document.activeElement, link);
    assert.ok(prevented);
    onKey({ key: 'ArrowUp', preventDefault() {} });
    assert.equal(globalThis.document.activeElement, dom.input);
    dom.input.value = 'EXAMPLE';
    await controller.update();
    assert.deepEqual(dom.results.querySelectorAll('mark').map(mark => mark.textContent), ['Example']);
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
