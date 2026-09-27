function loadMathJax() {
  const article = document.querySelector('[data-has-math="true"] .writeup-container > .markdown-content');
  if (!article || article.dataset.mathState) return;
  const source = article.innerHTML;
  const page = article.closest('.article-page');
  const notice = page.querySelector('[data-math-notice]');
  const componentUrl = notice.dataset.mathjaxComponentUrl;
  const fontUrl = notice.dataset.mathjaxFontUrl;
  const status = page.querySelector('[data-math-status]');
  const retry = page.querySelector('[data-math-retry]');
  let observer;
  let resizeTimer;
  let loadTimer;
  article.dataset.mathState = 'loading';

  function restoreSource() {
    article.innerHTML = source;
    article.dispatchEvent(new Event('article:content-restored'));
  }

  function fail() {
    clearTimeout(loadTimer);
    clearTimeout(resizeTimer);
    observer?.disconnect();
    const alreadyFailed = article.dataset.mathState === 'failed';
    article.dataset.mathState = 'failed';
    article.dataset.mathLoadError = 'true';
    restoreSource();
    if (!alreadyFailed) {
      notice.hidden = false;
      status.textContent = "Math formatting couldn't load. Equations are shown as TeX source; the article is still readable.";
    }
  }

  function fontFailed(event) {
    if (event.fontfaces.some(font => /MJX|MathJax/i.test(font.family))) fail();
  }
  document.fonts?.addEventListener('loadingerror', fontFailed);

  // A fresh page resets partially initialized components and keeps the URL,
  // unlike reusing a renderer whose dependencies failed halfway through.
  retry.addEventListener('click', () => window.location.reload());
  loadTimer = setTimeout(fail, 20000);
  window.MathJax = {
    loader: { load: ['[tex]/color'], paths: { 'mathjax-newcm': fontUrl }, failed: fail },
    startup: {
      elements: [article],
      pageReady() {
        if (article.dataset.mathState === 'failed') return Promise.resolve();
        return Promise.resolve().then(() => window.MathJax.startup.defaultPageReady()).then(() => {
          if (article.dataset.mathState === 'failed') {
            restoreSource();
            return;
          }
          if (article.querySelector('mjx-merror')) throw new Error('Equation formatting failed');
          clearTimeout(loadTimer);
          article.dataset.mathState = 'ready';
          let width = Math.round(article.getBoundingClientRect().width);
          observer = new ResizeObserver(([entry]) => {
            const nextWidth = Math.round(entry.contentRect.width);
            if (nextWidth === width) return;
            width = nextWidth;
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => {
              Promise.resolve().then(() => window.MathJax.whenReady(() => window.MathJax.startup.document.rerenderPromise()))
                .catch(fail);
            }, 120);
          });
          observer.observe(article);
        }).catch(fail);
      }
    },
    options: { skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code', 'annotation', 'annotation-xml'] },
    output: {
      displayOverflow: 'linebreak', linebreaks: { width: '100%' },
      fontPath: notice.dataset.mathjaxFontPath
    },
    chtml: { fontURL: `${fontUrl}/chtml/woff2`, dynamicPrefix: `${fontUrl}/chtml/dynamic` },
    tex: {
      packages: { '[+]': ['color'] },
      inlineMath: [['$', '$'], ['\\(', '\\)']],
      displayMath: [['$$', '$$'], ['\\[', '\\]']]
    }
  };
  const script = document.createElement('script');
  script.src = componentUrl;
  script.async = true;
  script.crossOrigin = 'anonymous';
  script.onerror = fail;
  script.onload = () => window.MathJax?.startup?.promise?.catch(fail);
  document.head.appendChild(script);
  window.addEventListener('pagehide', () => {
    observer?.disconnect();
    clearTimeout(resizeTimer);
    clearTimeout(loadTimer);
    document.fonts?.removeEventListener('loadingerror', fontFailed);
  });
  window.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    document.fonts?.addEventListener('loadingerror', fontFailed);
    if (article.dataset.mathState === 'loading') loadTimer = setTimeout(fail, 20000);
    if (article.dataset.mathState === 'ready') observer?.observe(article);
  });
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', loadMathJax, { once: true });
else loadMathJax();
