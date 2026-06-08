const MATHJAX_CDN_BASE_URL = "https://cdn.jsdelivr.net/npm/mathjax@4";
const MATHJAX_COMPONENT_URL = `${MATHJAX_CDN_BASE_URL}/tex-chtml.js`;
const MATHJAX_RELAYOUT_DELAY_MS = 120;

let relayoutTimerId = null;
let resizeListenerRegistered = false;
let mathLayoutObserver = null;
let observedMathWidth = null;

function articlePage() {
  return document.querySelector(".article-page, [data-mathjax]");
}

function mathLayoutContainer() {
  return document.querySelector(".writeup-container, .markdown-content, .article-page, [data-mathjax]");
}

function rerenderMathForViewport() {
  if (!window.MathJax?.startup?.document || !window.MathJax?.typesetPromise) return Promise.resolve();

  return window.MathJax.whenReady(() => {
    window.MathJax.startup.document.state(0);
    window.MathJax.texReset?.();

    return window.MathJax.typesetPromise();
  }).catch(error => {
    console.error("MathJax relayout failed", error);
  });
}

function scheduleMathRelayout() {
  if (relayoutTimerId) window.clearTimeout(relayoutTimerId);

  relayoutTimerId = window.setTimeout(() => {
    relayoutTimerId = null;
    rerenderMathForViewport();
  }, MATHJAX_RELAYOUT_DELAY_MS);
}

function ensureResizeListener() {
  if (resizeListenerRegistered) return;

  window.addEventListener("resize", scheduleMathRelayout);
  resizeListenerRegistered = true;
}

function ensureMathLayoutObserver() {
  if (mathLayoutObserver || !window.ResizeObserver) return;

  const container = mathLayoutContainer();
  if (!container) return;

  observedMathWidth = Math.round(container.getBoundingClientRect().width);
  mathLayoutObserver = new window.ResizeObserver((entries) => {
    const nextWidth = Math.round(entries[0].contentRect.width);
    if (nextWidth === observedMathWidth) return;

    observedMathWidth = nextWidth;
    scheduleMathRelayout();
  });
  mathLayoutObserver.observe(container);
}

function configureMathJax() {
  window.MathJax = {
    loader: {
      load: ["[tex]/color"]
    },
    options: {
      skipHtmlTags: ["script", "noscript", "style", "textarea"]
    },
    output: {
      displayOverflow: "linebreak",
      linebreaks: {
        width: "100%"
      }
    },
    tex: {
      packages: {
        "[+]": ["color"]
      },
      inlineMath: [["$", "$"], ["\\(", "\\)"]],
      displayMath: [["$$", "$$"], ["\\[", "\\]"]]
    }
  };
}

function loadMathJax() {
  if (!articlePage() || document.querySelector(`script[src="${MATHJAX_COMPONENT_URL}"]`)) return;

  configureMathJax();
  ensureResizeListener();
  ensureMathLayoutObserver();

  const script = document.createElement("script");
  script.src = MATHJAX_COMPONENT_URL;
  script.async = true;
  script.crossOrigin = "anonymous";
  document.head.appendChild(script);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", loadMathJax);
} else {
  loadMathJax();
}
