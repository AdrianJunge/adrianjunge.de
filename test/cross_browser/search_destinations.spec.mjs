import { test, expect } from '@playwright/test';

const cases = [
  ['ecsc', '/ctf#ctf-event-cscg'],
  ['SuiteCRM', '/about#suitecrm-portal-get-entry-list-sql-injection'],
  ['CWE-787', '/about#ffmpeg-vf-quirc-dynamic-resolution-out-of-bounds-write'],
  ['In ChurchCRM 7.0.5, property assignment handling', '/about#churchcrm-propertyassign-blind-sqli'],
  ['Final presentation for the course', '/about#joomla-course-presentation-2026'],
  ['Taking a closer look at in_array', '/ctf/sekaictf/Fancy%20Web#writeup-hint-1'],
  ['High', '/about#churchcrm-propertyassign-blind-sqli', false]
];

for (const width of [390, 1440]) {
  for (const [query, destination, textFragment = true] of cases) {
    test(`${width}px search reaches the selected destination: ${query}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto('/blog');
      // Repeat on the destination page to exercise navigation without a reload.
      for (let visit = 0; visit < 2; visit += 1) {
        await page.locator('#search-taskbar-button:not([disabled])').click();
        await page.locator('[data-site-search-query]').fill(query);
        const result = page.locator(`.site-search-result-link[href${textFragment ? '^' : ''}="${destination}${textFragment ? ':~:text=' : ''}"]`);
        await expect(result).toBeVisible();
        await result.click();
        await expect(page.locator('dialog[open]')).toHaveCount(0);
        const id = destination.split('#')[1];
        await expect.poll(() => page.evaluate(({ id, textFragment }) => {
          const anchor = document.getElementById(id);
          const target = document.querySelector(':target');
          if (!anchor || !target || !anchor.contains(target) || textFragment && target === anchor) return false;
          const bounds = target.getBoundingClientRect();
          return !target.closest('details:not([open]), [inert], .is-hidden') &&
            bounds.bottom > document.querySelector('#top-taskbar').getBoundingClientRect().bottom && bounds.top < innerHeight;
        }, { id, textFragment })).toBe(true);
      }
    });
  }

  for (const [query, path, expectedText, container] of [
    ['JVM Internals', '/blog/java-strings', 'JVM Internals', '.article-meta-tags'],
    ['AI-Assisted Auditing', '/blog/joomla-sqli', 'AI-Assisted Auditing', '.article-meta-tags'],
    ['nrg, the_moon_guy', '/ctf/ehax/Fantastic%20Doom', 'nrg', '.writeup-authors-article']
  ]) {
    test(`${width}px article metadata search highlights displayed text: ${query}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto('/blog');
      for (let visit = 0; visit < 2; visit += 1) {
        await page.locator('#search-taskbar-button:not([disabled])').click();
        await page.locator('[data-site-search-query]').fill(query);
        await page.locator(`.site-search-result-link[href^="${path}#:~:text="]`).click();
        const target = page.locator(`${container} :target`);
        await expect(target).toHaveText(expectedText);
        await expect.poll(() => target.evaluate(element => {
          const bounds = element.getBoundingClientRect();
          return bounds.top >= document.querySelector('#top-taskbar').getBoundingClientRect().bottom && bounds.bottom <= innerHeight;
        })).toBe(true);
      }
    });
  }
}

test('math rendering keeps a sentence search visible after layout settles', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await page.goto('/blog');
  await page.locator('#search-taskbar-button:not([disabled])').click();
  const sentence = 'The reason for this is the following equation holding for any prime P:';
  await page.locator('[data-site-search-query]').fill(sentence);
  await page.locator('.site-search-result-link').first().click();
  await expect(page.locator('[data-math-state]')).toHaveAttribute('data-math-state', 'ready', { timeout: 20000 });
  await expect(page.locator('p:target')).toContainText(sentence);
  await expect.poll(() => page.locator('p:target').evaluate(target => {
    const bounds = target.getBoundingClientRect();
    return bounds.top >= document.querySelector('#top-taskbar').getBoundingClientRect().bottom && bounds.bottom <= innerHeight;
  })).toBe(true);
});

test('same-page searches restore the animated tagline and preserve its highlight', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.goto('/');
  const sentence = 'Politely asking software uncomfortable questions.';
  await expect(page.locator('#typing')).not.toHaveText(sentence);
  await page.locator('#search-taskbar-button:not([disabled])').click();
  await page.locator('[data-site-search-query]').fill('uncomfortable questions');
  await page.locator('.site-search-result-link[href^="/#typing:~:text="]').click();
  await expect(page.locator('#typing:target')).toHaveText(sentence);
  // Wait beyond the normal two-second hold to verify it does not erase the match.
  await page.waitForTimeout(2500);
  await expect(page.locator('#typing:target')).toHaveText(sentence);
});
