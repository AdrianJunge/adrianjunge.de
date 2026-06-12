// Shared taskbar initializer - retained for the import hook used on every page.
function initSidebar() {
  document.documentElement.classList.add("has-top-taskbar");
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSidebar);
} else {
  initSidebar();
}
