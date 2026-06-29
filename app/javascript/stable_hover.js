const HOVER_CLASS = "is-hover-intent";
const HOVER_SELECTOR = [
  ".ui-hover-lift",
  ".ui-card-surface",
  ".back-button",
  ".collapse-toc-button",
  ".ui-article-action",
  ".content-link-button",
  ".content-page .content-filter-year-button",
  ".content-page .download-btn",
  ".content-page .open-pdf-btn",
  ".content-page .previous-writeup-btn",
  ".content-page .next-writeup-btn",
  ".content-page .ctf-rss-feed",
  ".content-page .ctf-atom-feed",
  ".content-page .blog-rss-feed",
  ".content-page .blog-atom-feed",
  ".content-page .content-hero-feed-link",
  ".landing-page .landing-action",
  ".landing-page .landing-affiliation-link",
  ".footer-link",
  ".terminal-button",
  ".content-hero-title-link",
  ".content-page .content-tag-action",
  ".landing-page .landing-writeup-cards .content-tag-action",
  ".aboutme-card-tag.aboutme-tag-action",
  ".aboutme-stat",
  ".landing-page .landing-metric",
  ".taskbar-link",
  ".taskbar-button-container",
  ".top-taskbar .taskbar-feed-option",
  ".content-page .markdown-content a"
].join(", ");

const fineHoverQuery = window.matchMedia("(hover: hover) and (pointer: fine)");
const activeTargets = new Map();

const supportsFineHover = (event) => {
  return fineHoverQuery.matches && (!event.pointerType || event.pointerType === "mouse" || event.pointerType === "pen");
};

const pageRectFor = (element) => {
  const rect = element.getBoundingClientRect();

  return {
    top: rect.top + window.scrollY,
    right: rect.right + window.scrollX,
    bottom: rect.bottom + window.scrollY,
    left: rect.left + window.scrollX
  };
};

const isInsideRect = (rect, event) => {
  return event.pageX >= rect.left && event.pageX <= rect.right && event.pageY >= rect.top && event.pageY <= rect.bottom;
};

const hoverTargetsFor = (event) => {
  const targets = [];
  let element = event.target instanceof Element ? event.target : event.target.parentElement;

  while (element && element !== document.documentElement) {
    if (element.matches(HOVER_SELECTOR)) targets.push(element);
    element = element.parentElement;
  }

  return targets;
};

const activate = (element, event) => {
  const rect = pageRectFor(element);
  if (!isInsideRect(rect, event)) return;

  activeTargets.set(element, rect);
  element.classList.add(HOVER_CLASS);
};

const deactivate = (element) => {
  activeTargets.delete(element);
  element.classList.remove(HOVER_CLASS);
};

const deactivateAll = () => {
  activeTargets.forEach((_rect, element) => element.classList.remove(HOVER_CLASS));
  activeTargets.clear();
};

document.addEventListener("pointerover", (event) => {
  if (!supportsFineHover(event)) return;

  hoverTargetsFor(event).forEach((target) => {
    if (!activeTargets.has(target)) activate(target, event);
  });
}, true);

document.addEventListener("pointermove", (event) => {
  if (!activeTargets.size) return;

  activeTargets.forEach((rect, element) => {
    if (!supportsFineHover(event) || !document.documentElement.contains(element) || !isInsideRect(rect, event)) {
      deactivate(element);
    }
  });
}, true);

document.addEventListener("pointerout", (event) => {
  if (!activeTargets.size) return;

  activeTargets.forEach((rect, element) => {
    if (!supportsFineHover(event) || !isInsideRect(rect, event)) {
      deactivate(element);
    }
  });
}, true);

document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") deactivateAll();
});

window.addEventListener("blur", deactivateAll);
window.addEventListener("resize", deactivateAll);

if (fineHoverQuery.addEventListener) {
  fineHoverQuery.addEventListener("change", deactivateAll);
} else {
  fineHoverQuery.addListener(deactivateAll);
}
