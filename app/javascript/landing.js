function initializeTagline() {
  const element = document.getElementById('typing');
  if (!element || element.dataset.taglineInitialized) return;
  element.dataset.taglineInitialized = 'true';

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  document.querySelector('[data-scroll-to]')?.addEventListener('click', event => {
    document.getElementById(event.currentTarget.dataset.scrollTo)?.scrollIntoView({ behavior: reducedMotion.matches ? 'auto' : 'smooth' });
  });

  const fallback = element.textContent;
  const phrases = [
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
  ];
  const line = element.closest('.landing-typed-line') || element;
  const cursor = document.createElement('span');
  cursor.className = 'typed-cursor';
  cursor.textContent = '|';
  cursor.setAttribute('aria-hidden', 'true');
  element.after(cursor);

  let phrase = fallback;
  let position = fallback.length;
  let phase = 'holding';
  let queue = [];
  let timer = null;
  let deadline = 0;
  let remaining = 2000;
  let pageActive = true;
  const inViewport = () => {
    const rect = line.getBoundingClientRect();
    return rect.bottom > 0 && rect.top < window.innerHeight;
  };
  let onScreen = inViewport();
  const canPlay = () => pageActive && onScreen && !document.hidden && !reducedMotion.matches;
  const characterDelay = () => 50 + Math.round(Math.random() * 25);

  function nextPhrase() {
    if (queue.length === 0) {
      queue = [...phrases];
      for (let index = queue.length - 1; index > 0; index -= 1) {
        const other = Math.floor(Math.random() * (index + 1));
        [queue[index], queue[other]] = [queue[other], queue[index]];
      }
    }
    if (queue[0] === phrase && queue.length > 1) [queue[0], queue[1]] = [queue[1], queue[0]];
    return queue.shift();
  }

  function syncPlayback() {
    cursor.hidden = reducedMotion.matches;
    cursor.classList.toggle('typed-cursor--blink', phase === 'holding' || !canPlay());
    cursor.style.animationPlayState = canPlay() ? 'running' : 'paused';
    if (!canPlay()) {
      if (timer !== null) {
        remaining = Math.max(0, deadline - window.performance.now());
        window.clearTimeout(timer);
        timer = null;
      }
      return;
    }
    // Resume the same step with its remaining delay, never start a second loop.
    if (timer !== null) return;
    deadline = window.performance.now() + remaining;
    timer = window.setTimeout(advance, remaining);
  }

  function advance() {
    timer = null;
    remaining = 0;
    if (!canPlay()) return;
    if (phase === 'holding') phase = 'deleting';
    if (phase === 'deleting') {
      position = Math.max(0, position - 1);
      element.textContent = phrase.slice(0, position);
      if (position === 0) {
        phrase = nextPhrase();
        phase = 'typing';
      }
      remaining = characterDelay();
    } else {
      position += 1;
      element.textContent = phrase.slice(0, position);
      if (position === phrase.length) phase = 'holding';
      remaining = phase === 'holding' ? 2000 : characterDelay();
    }
    syncPlayback();
  }

  const observer = new IntersectionObserver(([entry]) => {
    onScreen = entry.isIntersecting;
    syncPlayback();
  });
  // Observe the stable line rather than a span that shrinks while deleting.
  observer.observe(line);
  document.addEventListener('visibilitychange', syncPlayback);
  window.addEventListener('pagehide', () => {
    pageActive = false;
    syncPlayback();
  });
  window.addEventListener('pageshow', () => {
    pageActive = true;
    onScreen = inViewport();
    syncPlayback();
  });
  reducedMotion.addEventListener('change', () => {
    if (reducedMotion.matches) {
      syncPlayback();
      phrase = fallback;
      position = fallback.length;
      phase = 'holding';
      remaining = 2000;
      element.textContent = fallback;
    }
    syncPlayback();
  });
  syncPlayback();
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initializeTagline, { once: true });
else initializeTagline();
