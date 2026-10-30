import { test, expect } from '@playwright/test';

const eventId = 'kitctf-glacierctf-2024';

async function expectEventVisibleAndFocused(page) {
  const event = page.locator(`#${eventId}`);
  await expect(event).toBeFocused();
  await expect.poll(() => event.evaluate(element => {
    const bounds = element.getBoundingClientRect();
    const taskbarBottom = document.getElementById('top-taskbar').getBoundingClientRect().bottom;
    return !element.closest('details:not([open])') &&
      bounds.top >= taskbarBottom + 8 && bounds.bottom <= innerHeight;
  })).toBe(true);
  await page.keyboard.press('Tab');
  await expect(event.locator('a').first()).toBeFocused();
}

for (const width of [390, 1440]) {
  test(`${width}px timeline link reveals and focuses its nested About event`, async ({ page }) => {
    await page.setViewportSize({ width, height: 844 });
    await page.goto('/timeline?year=2024');
    await page.locator(`.timeline-card-hitbox[href="/about#${eventId}"]`).click({ position: { x: 10, y: 10 } });
    await expect(page).toHaveURL(new RegExp(`/about#${eventId}$`));
    await expectEventVisibleAndFocused(page);

    // A hash change in the same document must reopen both parent disclosures.
    await page.evaluate(() => {
      document.getElementById('achievements').open = false;
      document.querySelector('#kitctf > .profile-card-details').open = false;
      location.hash = 'cves';
    });
    await expect(page.locator('#cves')).toHaveAttribute('open', '');
    await page.evaluate(id => { location.hash = id; }, eventId);
    await expectEventVisibleAndFocused(page);
  });

  test(`${width}px About card anchors keep their header below the taskbar`, async ({ page }) => {
    await page.setViewportSize({ width, height: 844 });
    await page.goto('/about#kitctf');
    await expect(page.locator('#achievements')).toHaveAttribute('open', '');
    await expect(page.locator('#kitctf > .profile-card-details')).toHaveAttribute('open', '');
    await expect.poll(() => page.locator('#kitctf').evaluate(card => {
      const bounds = card.getBoundingClientRect();
      const header = card.querySelector('.aboutme-card-header').getBoundingClientRect();
      const taskbarBottom = document.getElementById('top-taskbar').getBoundingClientRect().bottom;
      return bounds.top >= taskbarBottom + 8 && bounds.top <= taskbarBottom + 48 && header.bottom <= innerHeight;
    })).toBe(true);
  });
}
