const QUERY_LIMIT = 200;
const SNIPPET_LENGTH = 200;
const searchSegmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' });
const searchWordSegmenter = new Intl.Segmenter(undefined, { granularity: 'word' });
let indexPromise;

export function searchQuery(value) {
  return typeof value === 'string' ? Array.from(value.trim()).slice(0, QUERY_LIMIT).join('') : '';
}

function foldSiteSearch(value) {
  return String(value || '').normalize('NFKD').replace(/\p{M}/gu, '').toLowerCase();
}

export function normalizeSiteSearch(value) {
  return foldSiteSearch(value).replace(/[^\p{L}\p{N}]+/gu, ' ').trim();
}

function siteSearchTerms(value) {
  return [...new Set(normalizeSiteSearch(searchQuery(value)).split(' ').filter(Boolean))];
}

function siteSearchPhrasePattern(value) {
  const query = searchQuery(value);
  if (normalizeSiteSearch(query).split(' ').length < 2) return null;
  const phrase = foldSiteSearch(query).split(/\s+/u)
    .map(word => word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('\\s+');
  return new RegExp(`(?<![\\p{L}\\p{N}])${phrase}(?![\\p{L}\\p{N}])`, 'u');
}

function matchesSiteSearchPhrase(value, pattern) {
  return pattern?.test(foldSiteSearch(value)) || false;
}

export function siteSearchHighlightRanges(value, terms, { phrase = '', phraseOnly = false } = {}) {
  const text = String(value || '');
  if (!text) return [];
  const normalized = foldSiteSearch(text);
  const pattern = siteSearchPhrasePattern(phrase);
  const matches = pattern ? [...normalized.matchAll(new RegExp(pattern, 'gu'))]
    .map(match => [match.index, match.index + match[0].length]) : [];
  if (!matches.length && !phraseOnly) {
    for (const term of terms) {
      if (!term) continue;
      for (let index = normalized.indexOf(term); index !== -1; index = normalized.indexOf(term, index + 1)) {
        matches.push([index, index + term.length]);
      }
    }
  }
  if (!matches.length) return [];
  const offsets = [];
  // Map folded characters back to the original accents, ligatures and graphemes.
  for (const { segment, index } of searchSegmenter.segment(text)) {
    const length = foldSiteSearch(segment).length;
    for (let offset = 0; offset < length; offset += 1) {
      offsets.push([index, index + segment.length]);
    }
  }
  const ranges = [];
  for (const [from, to] of matches.sort((left, right) => left[0] - right[0])) {
    const [start, end] = [offsets[from][0], offsets[to - 1][1]];
    const previous = ranges.at(-1);
    if (previous && start <= previous[1]) previous[1] = Math.max(previous[1], end);
    else ranges.push([start, end]);
  }
  return ranges;
}

function appendHighlightedText(element, value, terms, options) {
  const text = String(value || '');
  let offset = 0;
  for (const [start, end] of siteSearchHighlightRanges(text, terms, options)) {
    element.append(document.createTextNode(text.slice(offset, start)));
    const mark = document.createElement('mark');
    mark.textContent = text.slice(start, end);
    element.append(mark);
    offset = end;
  }
  element.append(document.createTextNode(text.slice(offset)));
}

export function siteSearchSnippet(value, terms, phrase = '') {
  const text = String(value || '');
  const phraseRange = siteSearchHighlightRanges(text, [], { phrase })[0];
  const word = phraseRange ? null : [...text.matchAll(/\S+/gu)].find(word => terms.some(term => normalizeSiteSearch(word[0]).includes(term)));
  const [from, to] = phraseRange || [word?.index || 0, (word?.index || 0) + (word?.[0].length || 0)];
  // Keep the whole match visible, including queries near the snippet limit.
  const length = Math.max(SNIPPET_LENGTH, to - from);
  const context = Math.min(60, Math.floor((length - (to - from)) / 2));
  const start = Math.max(from - context, 0);
  const excerpt = text.slice(start, start + length).trim();
  return `${start > 0 ? '…' : ''}${excerpt}${start + length < text.length ? '…' : ''}`;
}

function siteSearchTextTarget(document, section, query, terms, pageText) {
  const passages = section?.passages;
  const fields = Array.isArray(passages)
    ? passages.map((text, index) => ({ text, before: passages[index - 1], after: passages[index + 1] }))
    : [section?.text, section?.heading, document.title, ...document.tags].map(text => ({ text: String(text || '') }));
  if (section?.heading && !passages?.includes(section.heading)) {
    fields.push({ text: section.heading, after: passages?.[0] || section.text });
  }
  const foldedPage = foldSiteSearch(pageText).replace(/\s+/gu, ' ');
  const unique = value => foldedPage.split(foldSiteSearch(value)).length === 2;
  const surroundingWords = (value, last = false) => {
    const words = String(value || '').trim().split(/\s+/u);
    return (last ? words.slice(-4) : words.slice(0, 4)).join(' ');
  };
  // Use the original matched text, preserving accents and punctuation. A text
  // fragment must also include whole words when the query matches a substring.
  for (const phraseOnly of [true, false]) {
    let fallback;
    for (const field of fields) {
      const text = field.text;
      const ranges = siteSearchHighlightRanges(text, terms, { phrase: query, phraseOnly });
      const range = ranges.sort((left, right) => (right[1] - right[0]) - (left[1] - left[0]))[0];
      if (!range) continue;
      let [start, end] = range;
      for (const word of searchWordSegmenter.segment(text)) {
        if (!word.isWordLike || word.index >= end || word.index + word.segment.length <= start) continue;
        start = Math.min(start, word.index);
        end = Math.max(end, word.index + word.segment.length);
      }
      const target = { text: text.slice(start, end).replace(/\s+/gu, ' ') };
      // Headings can also occur in the contents list. Other duplicates must
      // be disambiguated against the entire page, including sibling cards.
      const heading = text === section?.heading;
      if (!heading && unique(target.text)) return target;
      const prefix = surroundingWords(text.slice(0, start).trim() || field.before, true);
      const suffix = surroundingWords(text.slice(end).trim() || field.after);
      if (prefix && unique(`${prefix} ${target.text}`)) return { ...target, prefix };
      if (suffix && unique(`${target.text} ${suffix}`)) return { ...target, suffix };
      if (prefix && suffix && unique(`${prefix} ${target.text} ${suffix}`)) return { ...target, prefix, suffix };
      fallback ||= { ...target, ...(prefix ? { prefix } : {}), ...(suffix ? { suffix } : {}) };
    }
    // Native text fragments search the whole page, even with an element hash.
    // An indistinguishable repeated label must keep its card anchor rather
    // than silently highlight the same label in a different card.
    if (fallback) return passages ? undefined : fallback;
  }
}

export function siteSearchResultUrl(result, { currentUrl } = {}) {
  let url = result.url;
  if (currentUrl) {
    const current = new URL(currentUrl);
    const destination = new URL(url, current);
    if (current.origin === destination.origin && current.pathname === '/timeline' &&
        destination.pathname === '/timeline' && current.searchParams.get('order') === 'oldest') {
      // A global result must clear filters that could hide its card, while
      // keeping the reader's selected chronological direction.
      destination.search = '?order=oldest';
      url = `${destination.pathname}${destination.search}${destination.hash}`;
    }
  }
  if (!result.textTarget?.text) return url;
  // Hyphens are text-fragment syntax, even though encodeURIComponent leaves
  // them untouched. Encode all punctuation that could act as a delimiter.
  const encode = value => encodeURIComponent(value).replace(/[!'()*-]/g, character => `%${character.charCodeAt(0).toString(16).toUpperCase()}`);
  const { text, prefix, suffix } = result.textTarget;
  const directive = [prefix ? `${encode(prefix)}-` : null, encode(text), suffix ? `-${encode(suffix)}` : null].filter(Boolean).join(',');
  url = url.split(':~:')[0];
  return `${url}${url.includes('#') ? '' : '#'}:~:text=${directive}`;
}

export function searchSite(documents, value, { limit } = {}) {
  const terms = siteSearchTerms(value);
  if (!terms.length) return [];
  const phrase = siteSearchPhrasePattern(value);
  const pageTexts = new Map();
  for (const document of documents) {
    const path = document.url.split('#')[0];
    const text = [document.title, ...document.sections.flatMap(section => [section.heading, ...(section.passages || [section.text])])].join(' ');
    pageTexts.set(path, `${pageTexts.get(path) || ''} ${text}`);
  }
  // The rendered page can also contain filter labels, navigation, and cards
  // indexed at another destination. They must count when disambiguating a
  // text fragment, without becoming additional searchable fields or results.
  for (const document of documents) {
    if (typeof document.page_text === 'string') {
      pageTexts.set(document.url.split('#')[0], document.page_text);
    }
  }
  const results = documents.flatMap(document => {
    const title = normalizeSiteSearch(document.title);
    const tags = normalizeSiteSearch(document.tags.join(' '));
    const sections = document.sections.map(section => ({
      ...section, normalizedHeading: normalizeSiteSearch(section.heading), normalizedText: normalizeSiteSearch(section.text),
      phraseMatch: matchesSiteSearchPhrase(section.heading, phrase) || matchesSiteSearchPhrase(section.text, phrase)
    }));
    const fieldsFor = term => [
      title.includes(term), tags.includes(term),
      sections.some(section => section.normalizedHeading.includes(term)),
      sections.some(section => section.normalizedText.includes(term))
    ];
    if (!terms.every(term => fieldsFor(term).some(Boolean))) return [];
    const score = terms.reduce((sum, term) => sum + fieldsFor(term).reduce((fieldSum, matches, index) => fieldSum + (matches ? [80, 60, 40, 4][index] : 0), 0), 0);
    const metadataPhrase = matchesSiteSearchPhrase(document.title, phrase) || matchesSiteSearchPhrase(document.tags.join(' '), phrase);
    const sectionTerms = terms.filter(term => !title.includes(term) && !tags.includes(term));
    let best;
    let bestScore = -1;
    for (const section of sections) {
      const sectionScore = sectionTerms.reduce((sum, term) => sum + (section.normalizedHeading.includes(term) ? 40 : 0) + (section.normalizedText.includes(term) ? 4 : 0), 0);
      if (best && (best.phraseMatch && !section.phraseMatch || best.phraseMatch === section.phraseMatch && sectionScore <= bestScore)) continue;
      best = section;
      bestScore = sectionScore;
    }
    return [{
      title: document.title, kind: document.kind, icon: document.icon, heading: best?.heading || '',
      url: (sectionTerms.length || !metadataPhrase && best?.phraseMatch) && best?.anchor ? `${document.url.split('#')[0]}#${best.anchor}` : document.url,
      snippet: siteSearchSnippet(best?.text, terms, value), score,
      textTarget: siteSearchTextTarget(document, best, value, terms, pageTexts.get(document.url.split('#')[0])),
      phraseMatch: metadataPhrase || sections.some(section => section.phraseMatch)
    }];
  });
  const compare = (left, right) => left < right ? -1 : left > right ? 1 : 0;
  const sorted = results.sort((left, right) => Number(right.phraseMatch) - Number(left.phraseMatch) || right.score - left.score || compare(left.title.toLowerCase(), right.title.toLowerCase()) || compare(left.url, right.url));
  const limited = Number.isInteger(limit) ? sorted.slice(0, Math.max(limit, 0)) : sorted;
  return limited.map(({ phraseMatch, ...result }) => result);
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
      const terms = siteSearchTerms(query);
      const phrase = siteSearchPhrasePattern(query);
      results.replaceChildren(...matches.map(match => {
        const row = document.createElement('li');
        const link = document.createElement('a');
        link.className = 'site-search-result-link';
        link.href = siteSearchResultUrl(match, { currentUrl: globalThis.location?.href });
        const title = document.createElement('span');
        title.className = 'site-search-result-title';
        const titleText = [match.title, match.heading].filter(Boolean).join(' — ');
        const highlightOptions = { phrase: query, phraseOnly: [titleText, match.kind, match.snippet].some(text => matchesSiteSearchPhrase(text, phrase)) };
        appendHighlightedText(title, titleText, terms, highlightOptions);
        const kind = document.createElement('span');
        kind.className = 'site-search-result-kind';
        appendHighlightedText(kind, match.kind, terms, highlightOptions);
        const snippet = document.createElement('p');
        snippet.classList.toggle('site-search-snippet-phrase', matchesSiteSearchPhrase(match.snippet, phrase));
        appendHighlightedText(snippet, match.snippet, terms, highlightOptions);
        if (match.icon?.src) {
          const icon = document.createElement('img');
          icon.className = `site-search-result-icon${match.icon.inverted ? ' site-search-result-icon-inverted' : ''}`;
          icon.src = match.icon.src;
          icon.alt = '';
          icon.width = 44;
          icon.height = 44;
          icon.loading = 'lazy';
          icon.decoding = 'async';
          link.append(icon);
        }
        const heading = document.createElement('div');
        heading.className = 'site-search-result-heading';
        heading.append(kind, title);
        link.append(heading, snippet);
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
