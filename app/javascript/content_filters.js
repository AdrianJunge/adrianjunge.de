function normalizeToken(value) {
  return String(value || '').trim().toLowerCase();
}

function normalizeSearchValue(value) {
  return normalizeToken(value)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '');
}

function normalizeSearchWords(value) {
  return normalizeToken(value)
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

function orderedCharacterMatch(queryTerm, valueTerm) {
  if (queryTerm === '') return true;

  const valueText = normalizeSearchValue(valueTerm);
  let queryIndex = 0;

  for (const character of valueText) {
    if (character === queryTerm[queryIndex]) queryIndex += 1;
    if (queryIndex === queryTerm.length) return true;
  }

  return false;
}

function searchTermsFrom(text, tags) {
  const terms = normalizeSearchWords(text);

  tags.forEach(tag => {
    const tagWords = normalizeSearchWords(tag);
    terms.push(...tagWords);

    const compactTag = tagWords.join('');
    if (compactTag) terms.push(compactTag);
  });

  return [...new Set(terms)];
}

function matchesSearchQuery(query, terms) {
  return matchesSearchTerms(normalizeSearchWords(query), terms);
}

function matchesSearchTerms(queryTerms, terms) {
  if (queryTerms.length === 0) return true;

  return queryTerms.every(queryTerm => terms.some(term => orderedCharacterMatch(queryTerm, term)));
}

function tokensFrom(value) {
  return String(value || '')
    .split('|')
    .map(normalizeToken)
    .filter(Boolean);
}

function buildCardRecord(card) {
  const record = {
    card,
    displayTarget: card.closest('.blog-post-entry') || card.closest('.timeline-item') || card,
    rawText: null,
    rawTags: null,
    rawYears: null,
    tags: [],
    tagSet: new Set(),
    yearSet: new Set(),
    searchTerms: []
  };

  syncCardRecord(record);
  return record;
}

function syncCardRecord(record) {
  const { card } = record;
  const rawText = card.dataset.filterText || '';
  const rawTags = card.dataset.filterTags || '';
  const rawYears = card.dataset.filterYears || card.dataset.filterYear || '';

  if (rawText === record.rawText && rawTags === record.rawTags && rawYears === record.rawYears) return;

  record.rawText = rawText;
  record.rawTags = rawTags;
  record.rawYears = rawYears;
  record.tags = tokensFrom(rawTags);
  record.tagSet = new Set(record.tags);
  record.yearSet = new Set(tokensFrom(rawYears));
  record.searchTerms = searchTermsFrom(rawText, record.tags);
}

function matchesCardRecord(record, queryTerms, selectedYear, activeTagList) {
  return matchesSearchTerms(queryTerms, record.searchTerms) &&
    (selectedYear === '' || record.yearSet.has(selectedYear)) &&
    activeTagList.every(tag => record.tagSet.has(tag));
}

function uncombinableTagsFor(records, activeTags, chips) {
  if (chips.length === 0) return new Set();

  const candidateTags = new Set(chips.map(chip => normalizeToken(chip.dataset.filterTag)).filter(Boolean));
  const availableTags = new Set();

  records.forEach(record => {
    record.tags.forEach(tag => {
      if (candidateTags.has(tag)) availableTags.add(tag);
    });
  });

  const unavailableTags = new Set();
  candidateTags.forEach(tag => {
    if (!activeTags.has(tag) && !availableTags.has(tag)) unavailableTags.add(tag);
  });

  return unavailableTags;
}

function storeOriginalChipAttribute(chip, key, attribute) {
  if (!Object.prototype.hasOwnProperty.call(chip.dataset, key)) {
    chip.dataset[key] = chip.getAttribute(attribute) || '';
  }

  return chip.dataset[key];
}

function restoreChipAttribute(chip, attribute, value) {
  if (value) {
    chip.setAttribute(attribute, value);
  } else {
    chip.removeAttribute(attribute);
  }
}

function setChipCombinability(chip, uncombinable) {
  const originalTitle = storeOriginalChipAttribute(chip, 'filterOriginalTitle', 'title');
  const originalAriaLabel = storeOriginalChipAttribute(chip, 'filterOriginalAriaLabel', 'aria-label');
  const originalTabIndex = storeOriginalChipAttribute(chip, 'filterOriginalTabIndex', 'tabindex');

  chip.classList.toggle('is-uncombinable', uncombinable);
  chip.dataset.filterCombinable = (!uncombinable).toString();
  chip.setAttribute('aria-disabled', uncombinable.toString());

  if (uncombinable) {
    const baseLabel = originalAriaLabel || chip.textContent.trim() || 'Filter';
    chip.setAttribute('aria-label', `${baseLabel} (no results with current filters)`);
    chip.setAttribute('title', 'No results with current filters');
    chip.tabIndex = -1;
    return;
  }

  restoreChipAttribute(chip, 'title', originalTitle);
  restoreChipAttribute(chip, 'aria-label', originalAriaLabel);
  restoreChipAttribute(chip, 'tabindex', originalTabIndex);
}

function setChipState(scope, activeTags, uncombinableTags = new Set(), panelChips = []) {
  document.querySelectorAll(`[data-filter-tag][data-filter-scope="${scope}"]`).forEach(chip => {
    const tag = normalizeToken(chip.dataset.filterTag);
    const active = activeTags.has(tag);
    chip.classList.toggle('is-active', active);
    chip.setAttribute('aria-pressed', active.toString());
  });

  panelChips.forEach(chip => {
    const tag = normalizeToken(chip.dataset.filterTag);
    setChipCombinability(chip, !activeTags.has(tag) && uncombinableTags.has(tag));
  });
}

function shouldReleaseChipFocus(pointerType) {
  if (pointerType === 'keyboard') return false;
  if (pointerType === 'touch' || pointerType === 'pen') return true;
  if (!window.matchMedia) return false;

  return window.matchMedia('(hover: none), (pointer: coarse)').matches;
}

function splitParamTags(value) {
  return String(value || '')
    .split(/[|,]/)
    .map(token => token.trim())
    .filter(Boolean);
}

function tagValuesFromParams(params) {
  const values = params.getAll('tag').flatMap(splitParamTags);
  values.push(...splitParamTags(params.get('tags')));

  return values.map(normalizeToken).filter(Boolean);
}

function validSelectValue(select, value) {
  if (!select || value === '') return value;

  return Array.from(select.options).some(option => option.value === value) ? value : '';
}

function initFilterPanel(panel) {
  const scope = panel.dataset.filterScope;
  if (!scope || panel.dataset.initialized) return;
  panel.dataset.initialized = 'true';
  panel.inert = false;

  const search = panel.querySelector(`[data-filter-search="${scope}"]`);
  const searchWrapper = search && search.closest('.search-wrapper');
  const year = panel.querySelector(`[data-filter-year="${scope}"]`);
  const clear = panel.querySelector(`[data-filter-clear="${scope}"]`);
  const reset = panel.querySelector(`[data-filter-reset="${scope}"]`);
  const count = panel.querySelector(`[data-filter-count="${scope}"]`);
  const empty = document.querySelector(`[data-filter-empty="${scope}"]`);
  const resultContainers = Array.from(document.querySelectorAll(`[data-filter-results="${scope}"]`));
  const cards = Array.from(document.querySelectorAll(`[data-filter-card="${scope}"]`));
  const cardRecords = cards.map(buildCardRecord);
  const chips = Array.from(document.querySelectorAll(`[data-filter-tag][data-filter-scope="${scope}"]`));
  const panelChips = Array.from(panel.querySelectorAll(`[data-filter-tag][data-filter-scope="${scope}"]`));
  const moreFilters = panel.querySelector('.content-filter-more');
  const moreFilterChips = moreFilters ? panelChips.filter(chip => moreFilters.contains(chip)) : [];
  const tagLabels = new Map(chips.map(chip => [normalizeToken(chip.dataset.filterTag), chip.dataset.filterTag]));
  const activeTags = new Set();
  const groups = Array.from(document.querySelectorAll(`[data-filter-group="${scope}"]`)).map(group => ({
    group, cards: Array.from(group.querySelectorAll(`[data-filter-card="${scope}"]`)),
    count: group.querySelector(`[data-filter-group-count="${scope}"]`)
  }));
  function legacyTag(tag) {
    const typed = `difficulty:${tag === 'introductory' ? 'intro' : tag}`;
    return tagLabels.has(typed) ? typed : tag;
  }
  function readStateFromUrl() {
    const params = new URLSearchParams(window.location.search);
    if (search) search.value = params.get('q') || '';
    if (year) year.value = validSelectValue(year, params.get('year') || '');

    activeTags.clear();
    tagValuesFromParams(params).forEach(tag => activeTags.add(legacyTag(tag)));
  }

  function writeStateToUrl(query, selectedYear, replace = false) {
    if (!window.history || !window.history.replaceState) return;

    const url = new URL(window.location.href);
    const params = url.searchParams;
    params.delete('q');
    params.delete('year');
    params.delete('tag');
    params.delete('tags');

    const rawQuery = search ? search.value.trim() : query;
    if (rawQuery) params.set('q', rawQuery);
    if (selectedYear) params.set('year', selectedYear);
    [...activeTags].sort().forEach(tag => {
      params.append('tag', tagLabels.get(tag) || tag);
    });

    const nextUrl = `${url.pathname}${url.search}${url.hash}`;
    const currentUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`;
    if (nextUrl !== currentUrl) window.history[replace ? 'replaceState' : 'pushState']({}, '', nextUrl);
  }

  function applyFilters(options = {}) {
    const updateUrl = options.updateUrl !== false;
    const query = normalizeToken(search && search.value);
    const queryTerms = normalizeSearchWords(query);
    const selectedYear = normalizeToken(year && year.value);
    const activeTagList = [...activeTags];
    const visibleRecords = [];
    let visible = 0;

    cardRecords.forEach(record => {
      syncCardRecord(record);

      const { card, displayTarget } = record;
      const matched = matchesCardRecord(record, queryTerms, selectedYear, activeTagList);

      displayTarget.hidden = !matched;
      card.setAttribute('aria-hidden', (!matched).toString());
      displayTarget.setAttribute('aria-hidden', (!matched).toString());
      if (matched) {
        visible += 1;
        visibleRecords.push(record);
      }
    });

    groups.forEach(({ group, cards: groupCards, count: groupCount }) => {
      const groupVisible = groupCards.filter(card => card.getAttribute('aria-hidden') !== 'true').length;
      group.hidden = groupCards.length > 0 && groupVisible === 0;
      if (groupCount) {
        const value = `${groupVisible} ${groupVisible === 1 ? 'item' : 'items'}`;
        if (groupCount.textContent !== value) groupCount.textContent = value;
      }
    });

    setChipState(scope, activeTags, uncombinableTagsFor(visibleRecords, activeTags, panelChips), panelChips);
    // Keep the original toggle visible when a URL, result tag, or history entry
    // selects a filter outside the compact common group. Never close a group
    // the reader has opened themselves when a filter is removed.
    if (moreFilters && moreFilterChips.some(chip => activeTags.has(normalizeToken(chip.dataset.filterTag)))) {
      moreFilters.open = true;
    }

    if (count) {
      const label = cards.length === 1 ? 'item' : 'items';
      const value = `${visible} / ${cards.length} ${label}`;
      if (count.textContent !== value) count.textContent = value;
    }

    if (searchWrapper) searchWrapper.classList.toggle('is-filled', query !== '');
    if (empty) empty.hidden = visible !== 0;
    resultContainers.forEach(container => {
      const hideResults = cards.length > 0 && visible === 0;
      container.hidden = hideResults;
      container.setAttribute('aria-hidden', hideResults.toString());
    });
    if (reset) {
      const resetVisible = query !== '' || selectedYear !== '' || activeTags.size > 0;
      reset.classList.toggle('is-visible', resetVisible);
      reset.setAttribute('aria-hidden', (!resetVisible).toString());
      reset.tabIndex = resetVisible ? 0 : -1;
    }
    if (updateUrl) writeStateToUrl(query, selectedYear, options.replace === true);
    document.dispatchEvent(new CustomEvent('content:filters-applied', {
      detail: { scope, visible, total: cards.length }
    }));
  }

  readStateFromUrl();
  if (search) search.addEventListener('input', () => applyFilters({ replace: true }));
  if (year) year.addEventListener('change', applyFilters);
  if (clear && search) {
    clear.addEventListener('click', () => {
      search.value = '';
      applyFilters();
      search.focus();
    });
  }
  if (reset) {
    reset.addEventListener('click', () => {
      if (search) search.value = '';
      if (year) year.value = '';
      activeTags.clear();
      applyFilters();
    });
  }

  chips.forEach(chip => {
    let pointerType = '';

    chip.addEventListener('pointerdown', event => {
      pointerType = event.pointerType;
    });

    chip.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();

      if (chip.classList.contains('is-uncombinable')) {
        if (shouldReleaseChipFocus(pointerType)) chip.blur();
        pointerType = '';
        return;
      }

      const tag = normalizeToken(chip.dataset.filterTag);
      if (activeTags.has(tag)) {
        activeTags.delete(tag);
      } else {
        activeTags.add(tag);
      }
      applyFilters();

      if (shouldReleaseChipFocus(pointerType)) chip.blur();
      pointerType = '';
    });

    chip.addEventListener('keydown', event => {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      event.preventDefault();
      pointerType = 'keyboard';
      chip.click();
    });
  });

  window.addEventListener('popstate', () => {
    readStateFromUrl();
    applyFilters({ updateUrl: false });
  });
  window.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    readStateFromUrl();
    applyFilters({ updateUrl: false });
  });

  applyFilters({ replace: true });
}

function initContentFilters() {
  document.querySelectorAll('.content-filter-panel[data-filter-scope]').forEach(initFilterPanel);
}

if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initContentFilters);
  } else {
    initContentFilters();
  }
}

export {
  matchesCardRecord,
  matchesSearchQuery,
  matchesSearchTerms,
  normalizeSearchValue,
  normalizeSearchWords,
  normalizeToken,
  orderedCharacterMatch,
  searchTermsFrom,
  splitParamTags,
  tagValuesFromParams,
  tokensFrom,
  uncombinableTagsFor,
  validSelectValue
};
