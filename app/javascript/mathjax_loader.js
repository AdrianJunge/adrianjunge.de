const MATHJAX_COMPONENT_URL = 'https://cdn.jsdelivr.net/npm/mathjax@4.1.3/tex-chtml.js';
const MATHJAX_FONT_URL = 'https://cdn.jsdelivr.net/npm/@mathjax/mathjax-newcm-font@4.1.3';

function loadMathJax() {
  const article = document.querySelector('[data-has-math="true"] .writeup-container > .markdown-content');
  if (!article || window.MathJax) return;
  window.MathJax = {
    loader: { load: ['[tex]/color'], paths: { 'mathjax-newcm': MATHJAX_FONT_URL } },
    startup: {
      elements: [article],
      pageReady() {
        return window.MathJax.startup.defaultPageReady().then(() => {
          let width = Math.round(article.getBoundingClientRect().width);
          let timer;
          const observer = new ResizeObserver(([entry]) => {
            const nextWidth = Math.round(entry.contentRect.width);
            if (nextWidth === width) return;
            width = nextWidth;
            clearTimeout(timer);
            timer = setTimeout(() => {
              window.MathJax.whenReady(() => window.MathJax.startup.document.rerenderPromise())
                .catch(() => { /* Existing equations and article text remain available. */ });
            }, 120);
          });
          observer.observe(article);
          window.addEventListener('pagehide', () => { observer.disconnect(); clearTimeout(timer); }, { once: true });
        });
      }
    },
    options: { skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'annotation', 'annotation-xml'] },
    output: {
      displayOverflow: 'linebreak', linebreaks: { width: '100%' },
      fontPath: 'https://cdn.jsdelivr.net/npm/@mathjax/%%FONT%%-font@4.1.3'
    },
    chtml: { fontURL: `${MATHJAX_FONT_URL}/chtml/woff2`, dynamicPrefix: `${MATHJAX_FONT_URL}/chtml/dynamic` },
    tex: {
      packages: { '[+]': ['color'] },
      inlineMath: [['$', '$'], ['\\(', '\\)']],
      displayMath: [['$$', '$$'], ['\\[', '\\]']]
    }
  };
  const script = document.createElement('script');
  script.src = MATHJAX_COMPONENT_URL;
  script.async = true;
  script.crossOrigin = 'anonymous';
  script.onerror = () => { article.dataset.mathLoadError = 'true'; };
  document.head.appendChild(script);
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', loadMathJax, { once: true });
else loadMathJax();
