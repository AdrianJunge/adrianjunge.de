const MATHJAX_CDN_BASE_URL = "https://cdn.jsdelivr.net/npm/mathjax@3/es5";
const MATHJAX_STARTUP_URL = `${MATHJAX_CDN_BASE_URL}/startup.js`;

function articlePage() {
  return document.querySelector(".article-page, [data-mathjax]");
}

function updateScrollClasses() {
  document.querySelectorAll(".MathJax").forEach(element => {
    element.classList.toggle("has-scroll", element.scrollWidth > element.clientWidth);
  });
}

function configureMathJax() {
  window.MathJax = {
    loader: {
      paths: {
        mathjax: MATHJAX_CDN_BASE_URL
      },
      load: ["input/tex-full", "output/chtml", "[tex]/color"]
    },
    options: {
      skipHtmlTags: ["script", "noscript", "style", "textarea"]
    },
    tex: {
      packages: {
        "[+]": ["color"]
      },
      inlineMath: [["$", "$"], ["\\(", "\\)"]],
      displayMath: [["$$", "$$"], ["\\[", "\\]"]]
    },
    startup: {
      pageReady() {
        return window.MathJax.startup.defaultPageReady().then(() => {
          updateScrollClasses();
          window.addEventListener("resize", updateScrollClasses);
        });
      }
    }
  };
}

function loadMathJax() {
  if (!articlePage() || document.querySelector(`script[src="${MATHJAX_STARTUP_URL}"]`)) return;

  configureMathJax();

  const script = document.createElement("script");
  script.src = MATHJAX_STARTUP_URL;
  script.async = true;
  script.crossOrigin = "anonymous";
  document.head.appendChild(script);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", loadMathJax);
} else {
  loadMathJax();
}
