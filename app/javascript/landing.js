async function initializeTagline() {
  const element = document.getElementById('typing');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  document.querySelector('[data-scroll-to]')?.addEventListener('click', event => {
    document.getElementById(event.currentTarget.dataset.scrollTo)?.scrollIntoView({ behavior: reducedMotion.matches ? 'auto' : 'smooth' });
  });
  if (!element || reducedMotion.matches) return;

  try {
    const { default: Typed } = await import('typed.js');
    if (reducedMotion.matches) return;
    const text = element.textContent;
    const typed = new Typed(element, {
      strings: [
        'Some people collect stamps. I collect stack traces.',
        'My favorite input is the one nobody validated.',
        'Politely asking software uncomfortable questions.',
        'CTF enthusiast',
        'I like puzzles that crash systems.',
        'Turning weird behavior into writeups.',
        'Teaching machines to misbehave.',
        'CTF flags, real bugs, questionable sleep schedule.',
        'Web and PWN player',
        'Your browser knows everything - XSLeaks just politely ask',
        'Source code tells jokes in edge cases.',
        'I love breaking stuff so others can fix it.',
        'Making impossible states feel very possible.',
        'The best exploit starts with: wait, that is weird.',
        'If it runs, I poke it.',
        'If it parses, I probably want to test it.'
      ],
      typeSpeed: 50, backSpeed: 50, backDelay: 2000,
      startDelay: 600, loop: true, smartBackspace: true,
      showCursor: true, cursorChar: '|', shuffle: true
    });
    let onScreen = true;
    let disposed = false;
    const syncPlayback = () => {
      if (disposed) return;
      if (onScreen && !document.hidden) typed.start();
      else typed.stop();
    };
    const observer = new IntersectionObserver(([entry]) => {
      onScreen = entry.isIntersecting;
      syncPlayback();
    });
    observer.observe(element);
    document.addEventListener('visibilitychange', syncPlayback);
    reducedMotion.addEventListener('change', () => {
      if (!reducedMotion.matches) return;
      disposed = true;
      typed.destroy();
      observer.disconnect();
      document.removeEventListener('visibilitychange', syncPlayback);
      element.textContent = text;
    }, { once: true });
  } catch (_error) {
    // The server-rendered tagline remains readable when the optional CDN fails.
  }
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeTagline, { once: true });
else initializeTagline();
