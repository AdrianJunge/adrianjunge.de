// Shared taskbar initializer - retained for the import hook used on every page.
function initSidebar() {
  document.documentElement.classList.add("has-top-taskbar");
  initFeedMenus();
}

function initFeedMenus() {
  const feedMenus = Array.from(document.querySelectorAll('.taskbar-feed-menu'));
  if (feedMenus.length === 0) return;

  document.addEventListener('click', event => {
    feedMenus.forEach(menu => {
      if (!menu.contains(event.target)) menu.open = false;
    });
  });

  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;

    feedMenus.forEach(menu => {
      if (!menu.open) return;

      menu.open = false;
      const toggle = menu.querySelector('.taskbar-feed-toggle');
      if (toggle) toggle.focus();
    });
  });
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initSidebar);
} else {
  initSidebar();
}
