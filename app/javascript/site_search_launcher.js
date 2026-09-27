function lockSiteSearchPageScroll() {
  const root = document.documentElement;
  const position = { left: window.scrollX, top: window.scrollY };
  const properties = ['overflow-x', 'overflow-y', 'scrollbar-gutter'];
  const previous = properties.map(name => [name, root.style.getPropertyValue(name), root.style.getPropertyPriority(name)]);
  // Reserve an existing desktop scrollbar's space so opening search cannot
  // shift the underlying page or its fixed navigation.
  if (window.innerWidth > root.clientWidth && !window.getComputedStyle(root).scrollbarGutter?.includes('stable')) {
    root.style.setProperty('scrollbar-gutter', 'stable');
  }
  root.style.setProperty('overflow-x', 'hidden');
  root.style.setProperty('overflow-y', 'hidden');
  let locked = true;
  return () => {
    if (!locked) return;
    locked = false;
    previous.forEach(([name, value, priority]) => {
      if (value) root.style.setProperty(name, value, priority);
      else root.style.removeProperty(name);
    });
    if (window.scrollX !== position.left || window.scrollY !== position.top) {
      window.scrollTo({ ...position, behavior: 'instant' });
    }
  };
}

function bindSiteSearchOutsideDismissal(dialog, dismiss = () => dialog.close()) {
  let start;
  let outsideTap = false;
  const outside = event => {
    const rect = dialog.getBoundingClientRect();
    return event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom;
  };
  const reset = () => { start = undefined; outsideTap = false; };
  dialog.addEventListener('pointerdown', event => {
    if (!dialog.open || event.isPrimary === false || event.button !== 0) return;
    outsideTap = false;
    start = { id: event.pointerId, outside: outside(event), x: event.clientX, y: event.clientY };
  });
  dialog.addEventListener('pointerup', event => {
    if (!start || event.pointerId !== start.id) return;
    outsideTap = start.outside && outside(event) && Math.hypot(event.clientX - start.x, event.clientY - start.y) <= 8;
    start = undefined;
  });
  dialog.addEventListener('pointercancel', reset);
  dialog.addEventListener('click', event => {
    const shouldDismiss = dialog.open && outsideTap && event.target === dialog && outside(event);
    reset();
    if (!shouldDismiss) return;
    event.preventDefault();
    event.stopPropagation();
    dismiss();
  });
  dialog.addEventListener('close', reset);
}

function siteSearchDestinationFocus(link) {
  const destination = new URL(link.href, window.location.href);
  if (destination.origin !== window.location.origin || destination.pathname !== window.location.pathname ||
      destination.search !== window.location.search || !destination.hash) return;
  let id;
  try { id = decodeURIComponent(destination.hash.slice(1)); }
  catch (_) { id = destination.hash.slice(1); }
  const target = document.getElementById(id);
  if (!target) return;

  // Reveal before native fragment navigation, including when the URL already
  // contains this hash and therefore will not emit another hashchange.
  for (let ancestor = target; ancestor; ancestor = ancestor.parentElement) {
    if (ancestor.matches('details')) ancestor.open = true;
  }
  const disclosure = target.matches('details') ? target : target.querySelector(':scope > details');
  if (disclosure) disclosure.open = true;
  const focusTarget = disclosure?.querySelector(':scope > summary') || target.closest('h1, h2, h3, h4, h5, h6') || target;
  if (!focusTarget.matches('a[href], button, input, select, textarea, summary, [tabindex]')) {
    focusTarget.setAttribute('tabindex', '-1');
  }
  return focusTarget;
}

function initializeSiteSearchLauncher() {
  const dialog = document.querySelector('[data-site-search-dialog]');
  if (!dialog || typeof dialog.showModal !== 'function' || dialog.dataset.siteSearchLauncherBound) return;
  dialog.dataset.siteSearchLauncherBound = 'true';
  const triggers = [...document.querySelectorAll('[data-site-search-open]')];
  const status = dialog.querySelector('[data-site-search-status]');
  const retry = dialog.querySelector('[data-site-search-retry]');
  let opener;
  let resultFocusTarget;
  let releasePageScroll;
  let engine;
  let request = 0;
  const loadEngine = () => engine ||= import('site_search').catch(error => { engine = undefined; throw error; });
  function closeSearch() {
    releasePageScroll?.();
    releasePageScroll = undefined;
    dialog.close();
  }
  bindSiteSearchOutsideDismissal(dialog, closeSearch);

  async function updateSearch() {
    const currentRequest = ++request;
    retry.hidden = true;
    try {
      const search = await loadEngine();
      if (currentRequest !== request || !dialog.open) return;
      await search.initializeSiteSearch(dialog).update({ prime: true });
    } catch (_) {
      if (currentRequest !== request || !dialog.open) return;
      status.textContent = 'Search could not load. Please try again.';
      retry.hidden = false;
    }
  }

  function openSearch(trigger) {
    if (dialog.open) return;
    resultFocusTarget = undefined;
    opener = trigger || document.activeElement;
    releasePageScroll = lockSiteSearchPageScroll();
    dialog.showModal();
    triggers.forEach(button => button.setAttribute('aria-expanded', 'true'));
    dialog.querySelector('[data-site-search-query]').focus();
    updateSearch();
  }

  triggers.forEach(trigger => {
    trigger.disabled = false;
    trigger.setAttribute('aria-keyshortcuts', 'Control+k Meta+k');
    trigger.addEventListener('click', () => openSearch(trigger));
  });
  document.addEventListener('keydown', event => {
    if (event.key.toLowerCase() !== 'k' || !(event.ctrlKey || event.metaKey) || event.altKey || event.repeat || event.isComposing) return;
    if (event.target.closest?.('input, textarea, select, [contenteditable]:not([contenteditable="false"])')) return;
    event.preventDefault();
    openSearch();
  });
  dialog.querySelector('[data-site-search-form]').addEventListener('submit', event => {
    event.preventDefault();
    updateSearch();
  });
  retry.addEventListener('click', updateSearch);
  dialog.querySelector('[data-site-search-close]').addEventListener('click', closeSearch);
  dialog.querySelector('[data-site-search-results]').addEventListener('click', event => {
    const link = event.target.closest('a[href]');
    if (event.defaultPrevented || event.button !== 0 ||
        event.altKey || event.ctrlKey || event.metaKey || event.shiftKey ||
        !link) return;
    // Same-page result anchors do not load a new document. Close and unlock
    // before native navigation, then let the destination own keyboard focus.
    opener = undefined;
    resultFocusTarget = siteSearchDestinationFocus(link);
    closeSearch();
  });
  dialog.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || event.isComposing || !dialog.open) return;
    // Search inputs otherwise consume the first Escape to clear their value.
    event.preventDefault();
    event.stopPropagation();
    closeSearch();
  });
  dialog.addEventListener('close', () => {
    releasePageScroll?.();
    releasePageScroll = undefined;
    request += 1;
    triggers.forEach(button => button.setAttribute('aria-expanded', 'false'));
    const destination = resultFocusTarget;
    resultFocusTarget = undefined;
    if (destination?.isConnected) {
      window.requestAnimationFrame(() => {
        if (!dialog.open && destination.isConnected) destination.focus({ preventScroll: true });
      });
    } else if (opener?.isConnected) opener.focus({ preventScroll: true });
  });
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeSiteSearchLauncher, { once: true });
else initializeSiteSearchLauncher();
