function initTaskbarHeight() {
  const taskbar = document.getElementById('top-taskbar');
  if (!taskbar) return;

  let height;
  const update = () => {
    const nextHeight = taskbar.getBoundingClientRect().height;
    if (nextHeight <= 0 || nextHeight === height) return;
    height = nextHeight;
    document.documentElement.style.setProperty('--top-taskbar-height', `${height}px`);
  };
  new ResizeObserver(update).observe(taskbar);
  update();
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
  document.addEventListener('DOMContentLoaded', initTaskbarHeight);
  document.addEventListener('DOMContentLoaded', initFeedMenus);
} else {
  initTaskbarHeight();
  initFeedMenus();
}
