const QUERY_LIMIT = 200;
const SNIPPET_LENGTH = 200;
let indexPromise;

export function searchQuery(value) {
  return typeof value === 'string' ? Array.from(value.trim()).slice(0, QUERY_LIMIT).join('') : '';
}

export function normalizeSiteSearch(value) {
  return String(value || '').normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

export function siteSearchSnippet(value, terms) {
  const text = String(value || '');
  const match = [...text.matchAll(/\S+/gu)].find(word => terms.some(term => normalizeSiteSearch(word[0]).includes(term)));
  const start = Math.max((match?.index || 0) - 60, 0);
  const excerpt = text.slice(start, start + SNIPPET_LENGTH).trim();
  return `${start > 0 ? '…' : ''}${excerpt}${start + SNIPPET_LENGTH < text.length ? '…' : ''}`;
}

export function searchSite(documents, value, { limit } = {}) {
  const terms = [...new Set(normalizeSiteSearch(searchQuery(value)).split(' ').filter(Boolean))];
  if (!terms.length) return [];
  const results = documents.flatMap(document => {
    const title = normalizeSiteSearch(document.title);
    const tags = normalizeSiteSearch(document.tags.join(' '));
    const sections = document.sections.map(section => ({
      ...section, normalizedHeading: normalizeSiteSearch(section.heading), normalizedText: normalizeSiteSearch(section.text)
    }));
    const fieldsFor = term => [
      title.includes(term), tags.includes(term),
      sections.some(section => section.normalizedHeading.includes(term)),
      sections.some(section => section.normalizedText.includes(term))
    ];
    if (!terms.every(term => fieldsFor(term).some(Boolean))) return [];
    const score = terms.reduce((sum, term) => sum + fieldsFor(term).reduce((fieldSum, matches, index) => fieldSum + (matches ? [80, 60, 40, 4][index] : 0), 0), 0);
    const sectionTerms = terms.filter(term => !title.includes(term) && !tags.includes(term));
    let best;
    let bestScore = -1;
    for (const section of sections) {
      const sectionScore = sectionTerms.reduce((sum, term) => sum + (section.normalizedHeading.includes(term) ? 40 : 0) + (section.normalizedText.includes(term) ? 4 : 0), 0);
      if (sectionScore <= bestScore) continue;
      best = section;
      bestScore = sectionScore;
    }
    return [{
      title: document.title, kind: document.kind, heading: best?.heading || '',
      url: sectionTerms.length && best?.anchor ? `${document.url.split('#')[0]}#${best.anchor}` : document.url,
      snippet: siteSearchSnippet(best?.text, terms), score
    }];
  });
  const compare = (left, right) => left < right ? -1 : left > right ? 1 : 0;
  const sorted = results.sort((left, right) => right.score - left.score || compare(left.title.toLowerCase(), right.title.toLowerCase()) || compare(left.url, right.url));
  return Number.isInteger(limit) ? sorted.slice(0, Math.max(limit, 0)) : sorted;
}

export function loadSiteSearchIndex() {
  if (!indexPromise) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    indexPromise = fetch('/search/index.json', { credentials: 'same-origin', cache: 'no-cache', signal: controller.signal })
      .then(response => {
        if (!response.ok) throw new Error('Search unavailable');
        return response.json();
      }).then(payload => {
        if (payload.version !== '2' || !Array.isArray(payload.documents)) throw new Error('Invalid search index');
        return payload.documents;
      }).catch(error => {
        indexPromise = undefined;
        throw error;
      }).finally(() => clearTimeout(timeout));
  }
  return indexPromise;
}

export function initializeSiteSearch(root) {
  if (root.dataset.siteSearchBound) return root.siteSearch;
  root.dataset.siteSearchBound = 'true';
  const input = root.querySelector('[data-site-search-query]');
  const results = root.querySelector('[data-site-search-results]');
  const status = root.querySelector('[data-site-search-status]');
  const retry = root.querySelector('[data-site-search-retry]');
  const wrapper = root.querySelector('.search-wrapper');
  const clearButton = root.querySelector('[data-site-search-clear]');
  let timer;
  let revision = 0;

  function syncInputState() {
    const filled = input.value !== '';
    wrapper?.classList.toggle('is-filled', filled);
    if (clearButton) {
      clearButton.hidden = !filled;
      clearButton.disabled = !filled;
    }
  }

  function resetEmptyState() {
    clearTimeout(timer);
    revision += 1;
    syncInputState();
    results.replaceChildren();
    results.scrollTop = 0;
    status.textContent = '';
    retry.hidden = true;
    root.setAttribute('aria-busy', 'false');
  }

  function clearSearch() {
    input.value = '';
    resetEmptyState();
    input.focus({ preventScroll: true });
  }

  async function update({ prime = false } = {}) {
    clearTimeout(timer);
    const currentRevision = ++revision;
    const query = searchQuery(input.value);
    syncInputState();
    retry.hidden = true;
    if (!query) {
      results.replaceChildren();
      results.scrollTop = 0;
    }
    status.textContent = query ? 'Searching…' : '';
    root.setAttribute('aria-busy', query || prime ? 'true' : 'false');
    if (!query && !prime) return;
    try {
      const documents = await loadSiteSearchIndex();
      if (currentRevision !== revision) return;
      const matches = searchSite(documents, query);
      results.replaceChildren(...matches.map(match => {
        const row = document.createElement('li');
        const link = document.createElement('a');
        link.className = 'site-search-result-link';
        link.href = match.url;
        const title = document.createElement('span');
        title.className = 'site-search-result-title';
        title.textContent = [match.title, match.heading].filter(Boolean).join(' — ');
        const kind = document.createElement('span');
        kind.className = 'site-search-result-kind';
        kind.textContent = match.kind;
        const snippet = document.createElement('p');
        snippet.textContent = match.snippet;
        link.append(kind, title, snippet);
        row.append(link);
        return row;
      }));
      results.scrollTop = 0;
      status.textContent = !query ? '' : matches.length ? `${matches.length} ${matches.length === 1 ? 'result' : 'results'}` : 'No results match all those words.';
    } catch (_) {
      if (currentRevision !== revision) return;
      status.textContent = 'Search could not load. Please try again.';
      retry.hidden = false;
    } finally {
      if (currentRevision === revision) root.setAttribute('aria-busy', 'false');
    }
  }

  input.addEventListener('input', () => {
    revision += 1;
    clearTimeout(timer);
    syncInputState();
    if (!searchQuery(input.value)) {
      resetEmptyState();
      return;
    }
    retry.hidden = true;
    status.textContent = 'Searching…';
    root.setAttribute('aria-busy', 'true');
    timer = setTimeout(update, 120);
  });
  clearButton?.addEventListener('click', clearSearch);
  root.addEventListener('keydown', event => {
    if (!['ArrowDown', 'ArrowUp'].includes(event.key) || event.altKey || event.ctrlKey || event.metaKey || event.isComposing) return;
    const links = [...results.querySelectorAll('a')];
    const index = links.indexOf(document.activeElement);
    if (document.activeElement === input && event.key === 'ArrowDown' && links.length) {
      event.preventDefault();
      links[0].focus();
    } else if (index >= 0) {
      event.preventDefault();
      const next = event.key === 'ArrowDown' ? links[Math.min(index + 1, links.length - 1)] : links[index - 1] || input;
      next.focus();
    }
  });
  syncInputState();
  root.siteSearch = { update, input, clear: clearSearch };
  return root.siteSearch;
}
