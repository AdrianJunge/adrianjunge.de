function normalizeToken(value) {
  return String(value || '').trim().toLowerCase();
}

function tokensFrom(value) {
  return String(value || '')
    .split('|')
    .map(normalizeToken)
    .filter(Boolean);
}

function setChipState(scope, activeTags) {
  document.querySelectorAll(`[data-filter-tag][data-filter-scope="${scope}"]`).forEach(chip => {
    const tag = normalizeToken(chip.dataset.filterTag);
    const active = activeTags.has(tag);
    chip.classList.toggle('is-active', active);
    chip.setAttribute('aria-pressed', active.toString());
  });
}

function initFilterPanel(panel) {
  const scope = panel.dataset.filterScope;
  if (!scope) return;

  const search = panel.querySelector(`[data-filter-search="${scope}"]`);
  const year = panel.querySelector(`[data-filter-year="${scope}"]`);
  const clear = panel.querySelector(`[data-filter-clear="${scope}"]`);
  const reset = panel.querySelector(`[data-filter-reset="${scope}"]`);
  const count = panel.querySelector(`[data-filter-count="${scope}"]`);
  const empty = document.querySelector(`[data-filter-empty="${scope}"]`);
  const cards = Array.from(document.querySelectorAll(`[data-filter-card="${scope}"]`));
  const activeTags = new Set();

  function applyFilters() {
    const query = normalizeToken(search && search.value);
    const selectedYear = normalizeToken(year && year.value);
    let visible = 0;

    cards.forEach(card => {
      const displayTarget = card.closest('.blog-post-entry') || card;
      const text = normalizeToken(card.dataset.filterText);
      const cardTags = tokensFrom(card.dataset.filterTags);
      const cardYears = tokensFrom(card.dataset.filterYears || card.dataset.filterYear);

      const matchesText = query === '' || text.includes(query);
      const matchesYear = selectedYear === '' || cardYears.includes(selectedYear);
      const matchesTags = [...activeTags].every(tag => cardTags.includes(tag));
      const matched = matchesText && matchesYear && matchesTags;

      displayTarget.hidden = !matched;
      card.setAttribute('aria-hidden', (!matched).toString());
      displayTarget.setAttribute('aria-hidden', (!matched).toString());
      if (matched) visible += 1;
    });

    setChipState(scope, activeTags);

    if (count) {
      const label = cards.length === 1 ? 'item' : 'items';
      count.textContent = `${visible} / ${cards.length} ${label}`;
    }

    if (empty) empty.hidden = visible !== 0;
    if (reset) reset.hidden = query === '' && selectedYear === '' && activeTags.size === 0;
  }

  if (search) search.addEventListener('input', applyFilters);
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

  document.querySelectorAll(`[data-filter-tag][data-filter-scope="${scope}"]`).forEach(chip => {
    chip.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();

      const tag = normalizeToken(chip.dataset.filterTag);
      if (activeTags.has(tag)) {
        activeTags.delete(tag);
      } else {
        activeTags.add(tag);
      }
      applyFilters();
    });

    chip.addEventListener('keydown', event => {
      if (event.key !== 'Enter' && event.key !== ' ') return;
      event.preventDefault();
      chip.click();
    });
  });

  applyFilters();
}

function initContentFilters() {
  document.querySelectorAll('.content-filter-panel[data-filter-scope]').forEach(initFilterPanel);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initContentFilters);
} else {
  initContentFilters();
}
