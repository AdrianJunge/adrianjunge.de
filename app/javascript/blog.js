function initBlogTOC() {
  const tocLinks = document.querySelectorAll(".toc-anchor");
  const headings = document.querySelectorAll(".markdown-content h1, .markdown-content h2, .markdown-content h3");

  if (tocLinks.length === 0) return;

  tocLinks[0].classList.add("active-anchor");

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

  window.addEventListener("scroll", highlightCurrentSection);
  highlightCurrentSection();

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

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    initBlogTOC();
    initCodeCopy();
  });
} else {
  initBlogTOC();
  initCodeCopy();
}
