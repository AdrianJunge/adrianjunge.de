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

function initYearDropdown(panel, scope, select, onChange) {
  const wrap = panel.querySelector(`[data-year-dropdown="${scope}"]`);
  const button = panel.querySelector(`[data-year-dropdown-button="${scope}"]`);
  const label = panel.querySelector(`[data-year-dropdown-label="${scope}"]`);
  const menu = panel.querySelector(`[data-year-dropdown-menu="${scope}"]`);
  const options = Array.from(panel.querySelectorAll(`[data-year-dropdown-option="${scope}"]`));
  if (!wrap || !button || !label || !menu || !select || options.length === 0) return null;

  function sync() {
    const selectedOption = select.selectedOptions[0];
    label.textContent = selectedOption ? selectedOption.textContent : 'All years';
    options.forEach(option => {
      const active = option.dataset.yearValue === select.value;
      option.classList.toggle('is-active', active);
      option.setAttribute('aria-selected', active.toString());
    });
  }

  function close() {
    menu.hidden = true;
    wrap.classList.remove('is-open');
    button.setAttribute('aria-expanded', 'false');
  }

  function open() {
    menu.hidden = false;
    wrap.classList.add('is-open');
    button.setAttribute('aria-expanded', 'true');
    (options.find(option => option.dataset.yearValue === select.value) || options[0]).focus();
  }

  function choose(option) {
    select.value = option.dataset.yearValue || '';
    sync();
    close();
    button.focus();
    onChange();
  }

  button.addEventListener('click', event => {
    event.stopPropagation();
    if (menu.hidden) {
      open();
    } else {
      close();
    }
  });

  button.addEventListener('keydown', event => {
    if (event.key !== 'ArrowDown' && event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    open();
  });

  options.forEach((option, index) => {
    option.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();
      choose(option);
    });

    option.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        event.preventDefault();
        close();
        button.focus();
      } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        const direction = event.key === 'ArrowDown' ? 1 : -1;
        const nextIndex = (index + direction + options.length) % options.length;
        options[nextIndex].focus();
      } else if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        choose(option);
      }
    });
  });

  document.addEventListener('click', event => {
    if (!wrap.contains(event.target)) close();
  });

  sync();
  return { sync, close };
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
  let yearDropdown = null;

  function applyFilters() {
    const query = normalizeToken(search && search.value);
    const selectedYear = normalizeToken(year && year.value);
    let visible = 0;

    cards.forEach(card => {
      const displayTarget = card.closest('.blog-post-entry') || card.closest('.timeline-item') || card.closest('.search-result-entry') || card;
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

    document.querySelectorAll(`[data-filter-group="${scope}"]`).forEach(group => {
      const groupCards = Array.from(group.querySelectorAll(`[data-filter-card="${scope}"]`));
      const groupVisible = groupCards.filter(card => card.getAttribute('aria-hidden') !== 'true').length;
      const groupCount = group.querySelector(`[data-filter-group-count="${scope}"]`);
      group.hidden = groupCards.length > 0 && groupVisible === 0;
      group.setAttribute('aria-hidden', group.hidden.toString());

      if (groupCount) {
        groupCount.textContent = `${groupVisible} ${groupVisible === 1 ? 'item' : 'items'}`;
      }
    });

    setChipState(scope, activeTags);

    if (count) {
      const label = cards.length === 1 ? 'item' : 'items';
      count.textContent = `${visible} / ${cards.length} ${label}`;
    }

    if (empty) empty.hidden = visible !== 0;
    if (reset) reset.hidden = query === '' && selectedYear === '' && activeTags.size === 0;
    if (yearDropdown) yearDropdown.sync();
    document.dispatchEvent(new CustomEvent('content:filters-applied', {
      detail: { scope, visible, total: cards.length }
    }));
  }

  if (search) search.addEventListener('input', applyFilters);
  if (year) year.addEventListener('change', applyFilters);
  yearDropdown = initYearDropdown(panel, scope, year, applyFilters);
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
      if (yearDropdown) yearDropdown.close();
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
