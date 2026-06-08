function initBlogTOC() {
  const tocLinks = document.querySelectorAll(".toc-anchor");
  const article = document.querySelector(".writeup-container > .markdown-content") || document.querySelector(".markdown-content");
  const headings = article ? article.querySelectorAll("h1, h2, h3") : [];

  if (tocLinks.length > 0) tocLinks[0].classList.add("active-anchor");

  function highlightCurrentSection() {
    let scrollPosition = window.scrollY + 10;
    let currentSection = null;

    headings.forEach((heading) => {
      const anchor = heading.querySelector("a[id]");
      if (anchor && anchor.offsetTop <= scrollPosition) {
        currentSection = anchor;
      }
    });

    if (currentSection) {
      tocLinks.forEach((link) => {
        link.classList.remove("active-anchor");
        if (link.getAttribute("href") === `#${currentSection.id}`) {
          link.classList.add("active-anchor");
        }
      });
    }
  }

  if (tocLinks.length > 0) {
    window.addEventListener("scroll", highlightCurrentSection);
    highlightCurrentSection();
  }

  function updateTocState(targetId, collapsed) {
    const toc = document.getElementById(targetId);
    if (!toc) return;

    toc.hidden = collapsed;

    const wrapper = toc.closest(".writeup-wrapper");
    if (wrapper) wrapper.classList.toggle("toc-collapsed", collapsed);

    const expanded = (!collapsed).toString();
    const label = collapsed ? "Show table of contents" : "Collapse table of contents";

    document.querySelectorAll(`[data-toc-toggle="${targetId}"]`).forEach(control => {
      control.setAttribute("aria-expanded", expanded);
      control.setAttribute("aria-label", label);
      control.setAttribute("title", label);
      control.classList.toggle("is-collapsed", collapsed);
    });
  }

  document.querySelectorAll('[data-toc-toggle]').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetId = btn.getAttribute('data-toc-toggle') || btn.getAttribute('aria-controls');
      const toc = document.getElementById(targetId);
      if (!toc) return;

      updateTocState(targetId, !toc.hidden);
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
    initCodeCopy();
    initArticleProgress();
  });
} else {
  initBlogTOC();
  initCodeCopy();
  initArticleProgress();
}
