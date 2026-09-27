function observeArticleLayout(article, update) {
  const observer = new ResizeObserver(update);
  observer.observe(article);
  window.addEventListener('pagehide', () => observer.disconnect());
  window.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    observer.observe(article);
    update();
  });
}

function initBlogTOC() {
  const tocLinks = document.querySelectorAll(".toc-anchor");
  const article = document.querySelector(".writeup-container > .markdown-content") || document.querySelector(".markdown-content");
  const articlePage = document.querySelector(".article-page");
  if (!articlePage || articlePage.dataset.initialized) return;
  articlePage.dataset.initialized = 'true';
  const shouldControlInitialHashScroll = Boolean(articlePage && window.location.hash);
  const previousScrollRestoration = 'scrollRestoration' in window.history ? window.history.scrollRestoration : null;
  let initialHashScrollInterrupted = false;
  let activeId;
  let headingOffsets = [];
  const compactToc = window.matchMedia('(max-width: 1400px)');
  const toc = document.getElementById('toc');
  const tocDisclosure = toc?.querySelector('.article-toc-compact');
  let wideTocCollapsed = false;

  function prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  }

  if (shouldControlInitialHashScroll && 'scrollRestoration' in window.history) {
    window.history.scrollRestoration = 'manual';
  }

  function restoreInitialHashScrollRestoration() {
    if (previousScrollRestoration && 'scrollRestoration' in window.history) {
      window.history.scrollRestoration = previousScrollRestoration;
    }
  }

  function markInitialHashScrollInterrupted(event) {
    if (event.type === 'keydown') {
      const scrollKeys = new Set([ 'ArrowDown', 'ArrowUp', 'End', 'Home', 'PageDown', 'PageUp', ' ', 'Spacebar' ]);
      if (!scrollKeys.has(event.key)) return;
    }

    initialHashScrollInterrupted = true;
  }

  function addInitialHashScrollInterruptionListeners() {
    window.addEventListener('wheel', markInitialHashScrollInterrupted, { passive: true });
    window.addEventListener('touchmove', markInitialHashScrollInterrupted, { passive: true });
    window.addEventListener('keydown', markInitialHashScrollInterrupted);
  }

  function removeInitialHashScrollInterruptionListeners() {
    window.removeEventListener('wheel', markInitialHashScrollInterrupted);
    window.removeEventListener('touchmove', markInitialHashScrollInterrupted);
    window.removeEventListener('keydown', markInitialHashScrollInterrupted);
  }

  function hashToId(hash) {
    if (!hash || hash === '#') return null;

    const rawId = hash.replace(/^#/, '');
    try {
      return decodeURIComponent(rawId);
    } catch (_) {
      return rawId;
    }
  }

  function hashForLink(link) {
    const href = link.getAttribute('href');
    if (!href) return null;

    const url = new URL(href, window.location.href);
    if (
      url.origin !== window.location.origin ||
      url.pathname !== window.location.pathname ||
      url.search !== window.location.search ||
      !url.hash
    ) {
      return null;
    }

    return url.hash;
  }

  function targetForHash(hash) {
    const id = hashToId(hash);
    return id ? document.getElementById(id) : null;
  }

  function scrollTargetForAnchor(anchor) {
    return anchor.closest('h1, h2, h3, h4, h5, h6') || anchor;
  }

  function topScrollOffset() {
    const taskbar = document.getElementById('top-taskbar') || document.querySelector('.top-taskbar');
    const taskbarBottom = taskbar ? taskbar.getBoundingClientRect().bottom : 0;
    const configuredHeight = parseFloat(
      window.getComputedStyle(document.documentElement).getPropertyValue('--top-taskbar-height')
    ) || 0;

    const taskbarOffset = Math.max(taskbarBottom, configuredHeight) + 16;
    if (!compactToc.matches || !toc || toc.hidden) return taskbarOffset;

    const tocTop = parseFloat(window.getComputedStyle(toc).top) || taskbarOffset;
    return Math.max(taskbarOffset, tocTop + toc.getBoundingClientRect().height + 16);
  }

  function setActiveLinkForId(id) {
    if (activeId === id) return;
    activeId = id;
    tocLinks.forEach((link) => {
      const active = hashToId(hashForLink(link)) === id;
      link.classList.toggle('active-anchor', active);
      if (active) link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    });
  }

  function scrollToAnchor(anchor, hash = null) {
    const target = scrollTargetForAnchor(anchor);
    const targetTop = window.scrollY + target.getBoundingClientRect().top - topScrollOffset();

    window.scrollTo({
      top: Math.max(targetTop, 0),
      behavior: prefersReducedMotion() ? 'auto' : 'smooth'
    });

    if (hash && window.history && window.history.pushState) {
      window.history.pushState(null, '', hash);
    }

    // The scroll observer owns the active marker; requesting a scroll does not
    // mean the destination has been reached (or that the scroll will complete).
  }

  if (tocLinks.length > 0) setActiveLinkForId(hashToId(hashForLink(tocLinks[0])));

  function highlightCurrentSection() {
    let scrollPosition = window.scrollY + topScrollOffset() + 1;
    let currentSection = null;

    headingOffsets.forEach(({ anchor, targetTop }) => {
      if (anchor && targetTop <= scrollPosition) {
        currentSection = anchor;
      }
    });

    setActiveLinkForId(currentSection?.id || hashToId(hashForLink(tocLinks[0])));
  }

  if (tocLinks.length > 0) {
    const refreshOffsets = () => {
      headingOffsets = Array.from(article.querySelectorAll('h1, h2, h3, h4, h5, h6')).map(heading => ({
        anchor: heading.querySelector('a[id]'), targetTop: window.scrollY + heading.getBoundingClientRect().top
      }));
      highlightCurrentSection();
    };
    observeArticleLayout(article, refreshOffsets);
    window.addEventListener('resize', refreshOffsets);
    article.addEventListener('article:content-restored', refreshOffsets);
    tocDisclosure?.addEventListener('toggle', refreshOffsets);
    refreshOffsets();
    tocLinks.forEach((link) => {
      link.addEventListener('click', (event) => {
        if (event.defaultPrevented || event.button !== 0 ||
            event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
        const hash = hashForLink(link);
        const target = targetForHash(hash);
        if (!target) return;

        event.preventDefault();
        if (compactToc.matches && tocDisclosure) tocDisclosure.open = false;
        scrollToAnchor(target, hash);
        const heading = scrollTargetForAnchor(target);
        if (!heading.hasAttribute('tabindex')) heading.setAttribute('tabindex', '-1');
        heading.focus({ preventScroll: true });
      });
    });

    let scheduled = false;
    window.addEventListener("scroll", () => {
      if (scheduled) return;
      scheduled = true;
      window.requestAnimationFrame(() => { highlightCurrentSection(); scheduled = false; });
    }, { passive: true });
    highlightCurrentSection();
  }

  function correctCurrentHashScroll() {
    const target = targetForHash(window.location.hash);
    if (target) scrollToAnchor(target);
  }

  function finishInitialHashScroll() {
    if (!initialHashScrollInterrupted) {
      correctCurrentHashScroll();
    }

    removeInitialHashScrollInterruptionListeners();
    window.setTimeout(restoreInitialHashScrollRestoration, 0);
  }

  if (shouldControlInitialHashScroll) {
    addInitialHashScrollInterruptionListeners();
    window.requestAnimationFrame(() => {
      if (!initialHashScrollInterrupted) correctCurrentHashScroll();
    });

    if (document.readyState === 'complete') {
      finishInitialHashScroll();
    } else {
      window.addEventListener('load', finishInitialHashScroll, { once: true });
    }
  }

  if (articlePage) {
    window.addEventListener('hashchange', correctCurrentHashScroll);
  }

  function updateTocState(targetId, collapsed, moveFocus = false) {
    const toc = document.getElementById(targetId);
    if (!toc) return;

    const wrapper = toc.closest(".writeup-wrapper");

    const expanded = (!collapsed).toString();
    const label = collapsed ? "Show table of contents" : "Collapse table of contents";

    document.querySelectorAll(`[data-toc-toggle="${targetId}"]`).forEach(control => {
      control.setAttribute("aria-expanded", expanded);
      control.setAttribute("aria-label", label);
      control.setAttribute("title", label);
      control.classList.toggle("is-collapsed", collapsed);
    });

    if (wrapper) wrapper.classList.toggle("toc-collapsed", collapsed);
    toc.hidden = collapsed;
    if (moveFocus) {
      const focusTarget = collapsed ? wrapper?.querySelector('.writeup-toc-restore-button') : toc.querySelector('#toc-toggle');
      focusTarget?.focus({ preventScroll: true });
    }
  }

  document.querySelectorAll('[data-toc-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-toc-toggle') || btn.getAttribute('aria-controls');
      const toc = document.getElementById(targetId);
      if (!toc) return;

      const expanded = btn.getAttribute('aria-expanded') !== 'false';
      wideTocCollapsed = expanded;
      updateTocState(targetId, expanded, true);
    });
  });

  function syncTocLayout() {
    const focused = document.activeElement;
    const focusWasInToc = toc?.contains(focused) || focused?.matches('.writeup-toc-restore-button');
    updateTocState('toc', compactToc.matches ? false : wideTocCollapsed);
    if (tocDisclosure) tocDisclosure.open = !compactToc.matches;
    if (focusWasInToc) {
      const target = compactToc.matches ? tocDisclosure?.querySelector('summary') :
        document.querySelector(wideTocCollapsed ? '.writeup-toc-restore-button' : '#toc-toggle');
      target?.focus({ preventScroll: true });
    }
  }

  tocDisclosure?.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || !compactToc.matches || !tocDisclosure.open) return;
    event.preventDefault();
    tocDisclosure.open = false;
    tocDisclosure.querySelector('summary')?.focus({ preventScroll: true });
  });
  compactToc.addEventListener('change', syncTocLayout);
  syncTocLayout();
  if (toc) toc.dataset.tocEnhanced = 'true';
}

function initCodeCopy() {
  const states = new WeakMap();
  document.addEventListener('click', event => {
    const btn = event.target.closest('.copy-btn');
    if (!btn) return;

    const code = btn.closest('.code-block')?.querySelector('code');
    if (!code) return;
    const source = code.textContent;
    const status = btn.closest('.code-block').querySelector('.copy-status');
    const report = message => { if (status) status.textContent = message; };
    const feedback = value => {
      btn.dataset.copyState = value;
      btn.querySelector('.copy-icon')?.toggleAttribute('hidden', value === 'success');
      btn.querySelector('.copy-check-icon')?.toggleAttribute('hidden', value !== 'success');
    };
    const state = states.get(btn) || { request: 0 };
    states.set(btn, state);
    const request = ++state.request;
    window.clearTimeout(state.timer);
    feedback('idle');
    report('');
    Promise.resolve().then(() => {
      if (!navigator.clipboard) throw new Error('Clipboard unavailable');
      return navigator.clipboard.writeText(source);
    }).then(() => {
      if (request !== state.request) return;
      feedback('success');
      report('Code copied to clipboard.');
      state.timer = window.setTimeout(() => {
        if (request === state.request) feedback('idle');
      }, 2000);
    }).catch(() => {
      if (request !== state.request) return;
      feedback('error');
      report('Copy unavailable. Select the code and copy it manually.');
    });
  });
}

function initHintSpoilers() {
  // Serve readable hints if JavaScript is disabled or fails to load. Only apply
  // the original blur once its Expose control can actually reveal the content.
  document.querySelectorAll('[data-hint-spoiler]').forEach(spoiler => {
    if (spoiler.dataset.hintEnhanced === 'true') return;
    const content = spoiler.querySelector('.writeup-hint-spoiler-content');
    const button = spoiler.querySelector('[data-hint-spoiler-reveal]');
    if (!content || !button) return;
    spoiler.dataset.hintEnhanced = 'true';
    spoiler.classList.add('is-hidden');
    content.inert = true;
    content.setAttribute('aria-hidden', 'true');
    button.hidden = false;
  });
  document.addEventListener('click', event => {
    const btn = event.target.closest('[data-hint-spoiler-reveal]');
    if (!btn) return;

    const spoiler = btn.closest('[data-hint-spoiler]');
    if (!spoiler) return;

    const content = spoiler.querySelector('.writeup-hint-spoiler-content');
    spoiler.classList.remove('is-hidden');
    spoiler.classList.add('is-revealed');
    btn.setAttribute('aria-expanded', 'true');
    btn.hidden = true;
    if (content) {
      content.setAttribute('aria-hidden', 'false');
      content.inert = false;
      content.tabIndex = -1;
      content.focus({ preventScroll: true });
    }
  });
}

function initArticleProgress() {
  const progress = document.querySelector('[data-article-progress]');
  const article = document.querySelector('.writeup-container > .markdown-content') || document.querySelector('.markdown-content');
  if (!progress || !article) return;

  const totalWords = parseInt(progress.dataset.wordTotal || '0', 10);
  if (!Number.isFinite(totalWords) || totalWords <= 0) return;

  const currentNode = progress.querySelector('[data-article-progress-current]');
  const percentNode = progress.querySelector('[data-article-progress-percent]');
  const formatter = new Intl.NumberFormat(document.documentElement.lang || undefined);
  let ticking = false;
  let previousPercent = -1;
  let previousWords = -1;

  function clamp(value) {
    return Math.min(Math.max(value, 0), 1);
  }

  function update() {
    const rect = article.getBoundingClientRect();
    const pageTop = window.scrollY + rect.top;
    const readableHeight = Math.max(article.scrollHeight - (window.innerHeight * 0.55), 1);
    const viewportAnchor = window.scrollY + (window.innerHeight * 0.35);
    const ratio = clamp((viewportAnchor - pageTop) / readableHeight);
    const percent = Math.round(ratio * 100);
    const currentWords = Math.round(totalWords * ratio);

    if (percent !== previousPercent) {
      progress.style.setProperty('--article-progress', `${percent}%`);
      progress.setAttribute('aria-valuenow', percent.toString());
    }
    if (currentNode && currentWords !== previousWords) currentNode.textContent = formatter.format(currentWords);
    if (percentNode && percent !== previousPercent) percentNode.textContent = `${percent}%`;
    previousPercent = percent;
    previousWords = currentWords;
    ticking = false;
  }

  function scheduleUpdate() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(update);
  }

  window.addEventListener('scroll', scheduleUpdate, { passive: true });
  window.addEventListener('resize', scheduleUpdate);
  document.querySelector('.article-toc-compact')?.addEventListener('toggle', scheduleUpdate);
  observeArticleLayout(article, scheduleUpdate);
  update();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    initBlogTOC();
    initCodeCopy();
    initHintSpoilers();
    initArticleProgress();
  });
} else {
  initBlogTOC();
  initCodeCopy();
  initHintSpoilers();
  initArticleProgress();
}
