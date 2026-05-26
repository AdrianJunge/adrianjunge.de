window.MathJax = {
  loader: {
    paths: {
      mathjax: 'https://cdn.jsdelivr.net/npm/mathjax@3/es5'
    },
    load: ['input/tex-full', 'output/chtml', '[tex]/color']
  },
  options: {
    skipHtmlTags: ["script","noscript","style","textarea"]
  },
  tex: {
    packages: {
      '[+]': ['color']
    },
    inlineMath: [['$','$'], ['\\(','\\)']],
    displayMath: [['$$','$$'], ['\\[','\\]']]
  },
  startup: {
    pageReady() {
      function updateScrollClasses() {
        document.querySelectorAll('.MathJax').forEach(el => {
          if (el.scrollWidth > el.clientWidth) {
            el.classList.add('has-scroll');
          } else {
            el.classList.remove('has-scroll');
          }
        });
      }
      return MathJax.startup.defaultPageReady().then(() => {
        updateScrollClasses();
        window.addEventListener('resize', updateScrollClasses);
      });
    }
  }
};

document.querySelectorAll('.ctf-card:not([data-expandable="false"])').forEach(card => {
  card.addEventListener('transitionend', event => {
    if (!card.classList.contains('expanded')) {
      card.style.zIndex = '';
    }
  });
  card.addEventListener('click', function () {
    document.querySelectorAll('.ctf-card').forEach(otherCard => {
      if (otherCard !== card) {
        otherCard.classList.remove('expanded');
        otherCard.style.transform = '';
        otherCard.style.transition = 'transform 0.3s ease-in-out';
      }
    });

    if (!card.classList.contains('expanded')) {
      card.classList.add('expanded');
      card.style.zIndex = '10';

      const rect = card.getBoundingClientRect();
      const centerX = rect.left + rect.width / 2;
      const centerY = rect.top + rect.height / 2;
      const viewportWidth = window.innerWidth;
      const viewportHeight = window.innerHeight;

      const translateY = (viewportHeight / 2) - centerY;
      const translateX = (viewportWidth / 2) - centerX;

      const minDimension = Math.min(rect.width, rect.height);
      const minViewport = Math.min(viewportWidth, viewportHeight);
      const targetScale = minViewport / minDimension * 0.9;

      card.style.transform = `translate(${translateX}px, ${translateY}px) scale(${targetScale})`;
      card.style.transition = 'transform 0.3s ease-in-out';
    } else {
      card.classList.remove('expanded');
      card.style.transform = '';
      requestAnimationFrame(() => {
        card.style.transition = 'transform 0.3s ease-in-out';
        card.style.transform = '';
      });
      setTimeout(() => {
        card.style.zIndex = '';
      }, 500);
    }
  });
});

document.addEventListener('click', function(event) {
  if (!event.target.closest('.ctf-card:not([data-expandable="false"])')) {
    const expandedCard = document.querySelector('.ctf-card.expanded');
    if (expandedCard) {
      expandedCard.classList.remove('expanded');
      expandedCard.style.transform = '';
      expandedCard.style.transition = 'transform 0.3s ease-in-out';
    }
  }
});
