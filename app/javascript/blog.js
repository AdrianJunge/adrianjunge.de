function initBlogTOC() {
  const tocLinks = document.querySelectorAll(".toc-anchor");
  const article = document.querySelector(".writeup-container > .markdown-content") || document.querySelector(".markdown-content");
  const articlePage = document.querySelector(".article-page");
  const headings = article ? article.querySelectorAll("h1, h2, h3") : [];
  const tocAnimationDuration = 240;

  function prefersReducedMotion() {
    return true;
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

    return Math.max(taskbarBottom, configuredHeight) + 16;
  }

  function setActiveLinkForId(id) {
    tocLinks.forEach((link) => {
      link.classList.toggle('active-anchor', hashToId(hashForLink(link)) === id);
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

    setActiveLinkForId(anchor.id);
  }

  if (tocLinks.length > 0) tocLinks[0].classList.add("active-anchor");

  function highlightCurrentSection() {
    let scrollPosition = window.scrollY + topScrollOffset() + 1;
    let currentSection = null;

    headings.forEach((heading) => {
      const anchor = heading.querySelector("a[id]");
      const target = anchor ? scrollTargetForAnchor(anchor) : null;
      const targetTop = target ? window.scrollY + target.getBoundingClientRect().top : null;
      if (anchor && targetTop <= scrollPosition) {
        currentSection = anchor;
      }
    });

    if (currentSection) {
      setActiveLinkForId(currentSection.id);
    }
  }

  if (tocLinks.length > 0) {
    tocLinks.forEach((link) => {
      link.addEventListener('click', (event) => {
        const hash = hashForLink(link);
        const target = targetForHash(hash);
        if (!target) return;

        event.preventDefault();
        scrollToAnchor(target, hash);
      });
    });

    window.addEventListener("scroll", highlightCurrentSection, { passive: true });
    highlightCurrentSection();
  }

  function correctCurrentHashScroll() {
    const target = targetForHash(window.location.hash);
    if (target) scrollToAnchor(target);
  }

  if (articlePage && window.location.hash) {
    window.requestAnimationFrame(correctCurrentHashScroll);
    window.addEventListener('load', correctCurrentHashScroll, { once: true });
  }

  if (articlePage) {
    window.addEventListener('hashchange', correctCurrentHashScroll);
  }

  function updateTocState(targetId, collapsed) {
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

    window.clearTimeout(toc.tocAnimationTimer);

    if (prefersReducedMotion()) {
      if (wrapper) wrapper.classList.toggle("toc-collapsed", collapsed);
      toc.hidden = collapsed;
      toc.classList.toggle("toc-is-collapsed", collapsed);
      toc.classList.remove("toc-is-collapsing");
      return;
    }

    if (collapsed) {
      toc.hidden = false;
      toc.classList.remove("toc-is-collapsed");
      toc.classList.add("toc-is-collapsing");
      if (wrapper) wrapper.classList.add("toc-collapsed");

      toc.tocAnimationTimer = window.setTimeout(() => {
        toc.hidden = true;
        toc.classList.remove("toc-is-collapsing");
        toc.classList.add("toc-is-collapsed");
      }, tocAnimationDuration);
      return;
    }

    toc.hidden = false;
    toc.classList.add("toc-is-collapsed");
    toc.classList.remove("toc-is-collapsing");
    if (wrapper) wrapper.classList.add("toc-collapsed");

    window.requestAnimationFrame(() => {
      toc.classList.remove("toc-is-collapsed");
      if (wrapper) wrapper.classList.remove("toc-collapsed");
    });
  }

  document.querySelectorAll('[data-toc-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-toc-toggle') || btn.getAttribute('aria-controls');
      const toc = document.getElementById(targetId);
      if (!toc) return;

      const expanded = btn.getAttribute('aria-expanded') !== 'false';
      updateTocState(targetId, expanded);
    });
  });
}

function initAnimatedDetails() {
  const detailsElements = document.querySelectorAll("details.writeup-hints, details[data-animated-details='true'], details.aboutme-finding-card");
  const duration = 240;

  function prefersReducedMotion() {
    return true;
  }

  function finishAnimation(details, open) {
    details.open = open;
    details.classList.remove("details-is-animating", "details-is-opening", "details-is-closing");
    details.style.height = "";
    details.style.overflow = "";
    window.clearTimeout(details.detailsAnimationTimer);
  }

  function animateDetails(details, open) {
    const summary = details.querySelector(":scope > summary");
    if (!summary) return;

    window.clearTimeout(details.detailsAnimationTimer);

    if (prefersReducedMotion()) {
      finishAnimation(details, open);
      return;
    }

    const startHeight = details.offsetHeight;

    if (open) details.open = true;

    const endHeight = open ? details.scrollHeight : summary.offsetHeight;
    details.style.height = `${startHeight}px`;
    details.style.overflow = "hidden";
    details.classList.add("details-is-animating");
    details.classList.toggle("details-is-opening", open);
    details.classList.toggle("details-is-closing", !open);

    window.requestAnimationFrame(() => {
      details.style.height = `${endHeight}px`;
      if (open) details.classList.remove("details-is-opening");
    });

    const onTransitionEnd = (event) => {
      if (event.target !== details || event.propertyName !== "height") return;
      details.removeEventListener("transitionend", onTransitionEnd);
      finishAnimation(details, open);
    };

    details.addEventListener("transitionend", onTransitionEnd);
    details.detailsAnimationTimer = window.setTimeout(() => {
      details.removeEventListener("transitionend", onTransitionEnd);
      finishAnimation(details, open);
    }, duration + 80);
  }

  detailsElements.forEach((details) => {
    const summary = details.querySelector(":scope > summary");
    if (!summary) return;

    summary.addEventListener("click", (event) => {
      if (event.target.closest("a, button, [role='button']")) return;

      event.preventDefault();
      animateDetails(details, !details.open);
    });
  });
}

function initCodeCopy() {
  document.addEventListener('click', event => {
    const btn = event.target.closest('.copy-btn');
    if (!btn) return;

    const code = btn.getAttribute('data-code');
    navigator.clipboard.writeText(code)
      .then(() => {
        btn.textContent = '✅';
        setTimeout(() => btn.textContent = '📋', 2000);
      })
      .catch(() => {
        btn.textContent = 'Error';
      });
  });
}

function initHintSpoilers() {
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
    if (content) content.setAttribute('aria-hidden', 'false');
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

    progress.style.setProperty('--article-progress', `${percent}%`);
    progress.setAttribute('aria-valuenow', percent.toString());
    if (currentNode) currentNode.textContent = formatter.format(currentWords);
    if (percentNode) percentNode.textContent = `${percent}%`;
    ticking = false;
  }

  function scheduleUpdate() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(update);
  }

  window.addEventListener('scroll', scheduleUpdate, { passive: true });
  window.addEventListener('resize', scheduleUpdate);
  update();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    initBlogTOC();
    initAnimatedDetails();
    initCodeCopy();
    initHintSpoilers();
    initArticleProgress();
  });
} else {
  initBlogTOC();
  initAnimatedDetails();
  initCodeCopy();
  initHintSpoilers();
  initArticleProgress();
}
