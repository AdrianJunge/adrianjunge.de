import { test, expect } from '@playwright/test';

const cases = [
  ['Pwn', 'overthewire-beginnings', 1440],
  ['CTF Practice', 'picoctf-beginnings', 390],
  ['Penetration Testing', 'tryhackme-beginnings', 390],
  ['2019', 'overthewire-beginnings', 1440],
  ['First steps with OverTheWire', 'overthewire-beginnings', 1440],
  ['Building foundations in Linux', 'overthewire-beginnings', 390]
];

for (const order of ['newest', 'oldest']) {
  for (const [query, event, width] of cases) {
    test(`${order}: timeline search highlights the selected card for ${query}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.goto(order === 'oldest' ? '/timeline?order=oldest&year=2026&tag=CVE&view=posts' : '/blog');
      await page.locator('#search-taskbar-button:not([disabled])').click();
      await page.locator('[data-site-search-query]').fill(query);
      const id = `timeline-event-${event}`;
      const result = page.locator(`.site-search-result-link[href*="#${id}:~:text="]`);
      await expect(result).toBeVisible();
      await result.click();
      await expect(page.locator('dialog[open]')).toHaveCount(0);
      await expect.poll(() => page.evaluate(id => {
        const anchor = document.getElementById(id);
        const target = document.querySelector(':target');
        if (!anchor || !target || target === anchor || !anchor.contains(target)) return false;
        const bounds = target.getBoundingClientRect();
        return bounds.bottom > document.querySelector('#top-taskbar').getBoundingClientRect().bottom && bounds.top < innerHeight;
      }, id)).toBe(true);
      const destination = new URL(page.url());
      expect(destination.searchParams.get('order')).toBe(order === 'oldest' ? 'oldest' : null);
      expect(destination.searchParams.has('tag')).toBe(false);
      expect(destination.searchParams.has('year')).toBe(false);
      expect(destination.searchParams.has('view')).toBe(false);
    });
  }
}
