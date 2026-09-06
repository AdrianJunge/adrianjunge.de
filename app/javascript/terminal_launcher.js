function initializeLauncher() {
  const terminal = document.getElementById('terminal-container');
  const launcher = document.getElementById('terminal-taskbar-button');
  if (!terminal || !launcher || launcher.dataset.initialized) return;
  launcher.dataset.initialized = 'true';
  const status = document.getElementById('terminal-status');
  const desktop = window.matchMedia('(min-width: 700px)');
  let implementation;
  let pending;
  let styles;
  let open = false;

  function setOpen(value, focus = true, persist = true) {
    open = value && desktop.matches;
    terminal.hidden = !open;
    terminal.inert = !open;
    terminal.classList.toggle('terminal-minimized', !open);
    launcher.setAttribute('aria-expanded', String(open));
    if (persist) {
      try { localStorage.setItem('terminal-open', String(open)); } catch (_error) { /* Storage is optional. */ }
    }
    if (!open) {
      implementation?.blur();
      if (focus && desktop.matches) launcher.focus();
    }
  }

  function loadStyles() {
    return styles ||= new Promise((resolve, reject) => {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = terminal.dataset.terminalCss;
      link.crossOrigin = 'anonymous';
      link.onload = resolve;
      link.onerror = () => { styles = null; link.remove(); reject(new Error('Terminal stylesheet unavailable')); };
      document.head.appendChild(link);
    });
  }

  async function activate(focus = true) {
    if (!desktop.matches) return;
    setOpen(true, false);
    launcher.setAttribute('aria-busy', 'true');
    if (status) status.textContent = 'Loading terminal…';
    try {
      pending ||= Promise.all([loadStyles(), import('terminal')]).then(([, module]) => module.createTerminal());
      implementation = await pending;
      if (open) implementation.show(focus);
      if (status) status.textContent = '';
    } catch (_error) {
      pending = null;
      setOpen(false, focus);
      if (status) status.textContent = 'Terminal could not load. Please try again; navigation links remain available.';
    } finally {
      launcher.removeAttribute('aria-busy');
    }
  }

  launcher.addEventListener('click', () => open ? setOpen(false) : activate());
  ['minimize-terminal', 'close-terminal'].forEach(id => document.getElementById(id)?.addEventListener('click', () => setOpen(false)));
  document.getElementById('maximize-terminal')?.addEventListener('click', () => {
    terminal.classList.toggle('terminal-maximized');
    implementation?.show(false);
  });
  ['wheel', 'touchmove'].forEach(type => terminal.addEventListener(type, event => {
    if (open) event.stopPropagation();
  }, { passive: true }));
  document.addEventListener('keydown', event => {
    if (event.repeat) return;
    if ((event.key === 'Escape' && open && terminal.contains(document.activeElement)) || (event.ctrlKey && event.key === 'Enter')) {
      event.preventDefault();
      if (open) setOpen(false);
      else activate();
    }
  });
  desktop.addEventListener('change', () => { if (!desktop.matches) setOpen(false, false, false); });
  setOpen(false, false, false);
  try {
    if (desktop.matches && localStorage.getItem('terminal-open') === 'true') activate(false);
  } catch (_error) { /* Storage is optional. */ }
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeLauncher, { once: true });
else initializeLauncher();
