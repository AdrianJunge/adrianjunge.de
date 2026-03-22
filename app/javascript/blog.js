// Blog search functionality
function initBlogSearch() {
  const blogSearchInput = document.getElementById('blog-search-input');
  if (!blogSearchInput) return;

  const blogPostCards = Array.from(document.querySelectorAll('.blog-post-entry'));

  function filterBlogPosts() {
    const query = blogSearchInput.value.trim().toLowerCase();

    if (query === '') {
      blogPostCards.forEach(card => {
        card.style.display = '';
        card.setAttribute('aria-hidden', 'false');
      });
      return;
    }

    blogPostCards.forEach(card => {
      const titleEl = card.querySelector('.blog-post-title');
      const descEl = card.querySelector('.blog-post-description');
      const topicEl = card.querySelector('.blog-post-topic');

      const title = titleEl ? titleEl.textContent.toLowerCase() : '';
      const desc = descEl ? descEl.textContent.toLowerCase() : '';
      const topic = topicEl ? topicEl.textContent.toLowerCase() : '';

      const matched = title.includes(query) || desc.includes(query) || topic.includes(query);

      if (matched) {
        card.style.display = '';
        card.setAttribute('aria-hidden', 'false');
      } else {
        card.style.display = 'none';
        card.setAttribute('aria-hidden', 'true');
      }
    });
  }

  blogSearchInput.addEventListener('input', filterBlogPosts);

  // Clear button functionality
  const clearBtn = document.getElementById('blog-search-clear');
  if (clearBtn) {
    clearBtn.addEventListener('click', function() {
      blogSearchInput.value = '';
      filterBlogPosts();
    });
  }
}

// Table of contents functionality for blog posts
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

  // TOC toggle
  document.querySelectorAll('[data-toc-toggle]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const targetId = btn.getAttribute('data-toc-toggle') || btn.getAttribute('aria-controls');
      const toc = document.getElementById(targetId);
      if (!toc) return;

      const nowHidden = toc.classList.toggle('hidden');
      const expanded = (!nowHidden).toString();
      btn.setAttribute('aria-expanded', expanded);
    });
  });

  // TOC toggle icon rotation
  const btn = document.getElementById("toc-toggle");
  const icon = document.getElementById("toc-toggle-icon");

  if (btn && icon) {
    btn.addEventListener("click", () => {
      const expanded = btn.getAttribute("aria-expanded") === "true";
      if (expanded) {
        icon.classList.add("rotate-180");
      } else {
        icon.classList.remove("rotate-180");
      }
    });
  }
}

// Copy code functionality
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

// Initialize all blog functionality when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    initBlogSearch();
    initBlogTOC();
    initCodeCopy();
  });
} else {
  initBlogSearch();
  initBlogTOC();
  initCodeCopy();
}

