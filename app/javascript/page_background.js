const BACKGROUND_HEIGHT_PROPERTY = "--page-background-height";

function pageHeight() {
  const documentElement = document.documentElement;
  const body = document.body;

  return Math.max(
    documentElement.scrollHeight,
    documentElement.offsetHeight,
    body ? body.scrollHeight : 0,
    body ? body.offsetHeight : 0,
    window.innerHeight
  );
}

function setBackgroundHeight() {
  document.documentElement.style.setProperty(BACKGROUND_HEIGHT_PROPERTY, "100dvh");
  document.documentElement.style.setProperty(BACKGROUND_HEIGHT_PROPERTY, `${pageHeight()}px`);
}

function initPageBackground() {
  let frame = null;

  function scheduleUpdate() {
    if (frame) return;

    frame = requestAnimationFrame(() => {
      frame = null;
      setBackgroundHeight();
    });
  }

  setBackgroundHeight();

  window.addEventListener("load", scheduleUpdate);
  window.addEventListener("resize", scheduleUpdate);
  window.addEventListener("orientationchange", scheduleUpdate);
  document.addEventListener("content:filters-applied", scheduleUpdate);

  if ("ResizeObserver" in window && document.body) {
    const observer = new ResizeObserver(scheduleUpdate);
    observer.observe(document.body);
    observer.observe(document.documentElement);
  }

  if ("MutationObserver" in window && document.body) {
    const observer = new MutationObserver(scheduleUpdate);
    observer.observe(document.body, {
      attributes: true,
      childList: true,
      subtree: true
    });
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initPageBackground);
} else {
  initPageBackground();
}
