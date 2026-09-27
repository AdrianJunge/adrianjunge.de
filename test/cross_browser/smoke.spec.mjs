import { test, expect } from '@playwright/test';

// This small engine suite intentionally avoids Chrome CDP and browser-specific
// picker styling. Chrome's detailed system suite owns those regressions.
test('navigation and native About disclosures retain keyboard focus', async ({ page }) => {
  await page.goto('/');
  await page.locator('.taskbar-link[href="/about"]').click();
  await expect(page).toHaveURL(/\/about$/);
  const jump = page.locator('.aboutme-stat[href="#cves"]');
  await jump.focus();
  await jump.press('Enter');
  const summary = page.locator('#cves > summary');
  await expect(page.locator('#cves')).toHaveAttribute('open', '');
  await expect(summary).toBeFocused();
  await page.keyboard.press('Tab');
  await expect(page.locator('#cves .aboutme-card-header a').first()).toBeFocused();

  const details = page.locator('#cves .profile-card-details').first();
  await details.locator(':scope > summary').focus();
  await page.keyboard.press('Enter');
  await expect(details).toHaveAttribute('open', '');
  await page.keyboard.press('Space');
  await expect(details).not.toHaveAttribute('open');
  await expect(details.locator(':scope > summary')).toBeFocused();
});

test('native year selection, text filtering, reset, and history work together', async ({ page }) => {
  await page.goto('/timeline');
  await expect(page.locator('.content-filter-panel')).toHaveAttribute('data-initialized', 'true');
  const yearSelect = page.locator('[data-filter-year]');
  const year = await yearSelect.locator('option').nth(1).getAttribute('value');
  await yearSelect.selectOption(year);
  await expect(page).toHaveURL(new RegExp(`year=${year}`));
  const cards = page.locator('[data-filter-card="timeline"]:visible');
  await expect(cards.first()).toBeVisible();
  for (const card of await cards.all()) {
    await expect(card.locator('time').first()).toHaveAttribute('datetime', new RegExp(`^${year}-`));
  }
  await page.locator('[data-filter-search]').fill('unmatched-qa-smoke-query');
  await expect(cards).toHaveCount(0);
  const filteredURL = page.url();
  const reset = page.locator('[data-filter-reset]');
  await reset.focus();
  await reset.press('Enter');
  await expect(page.locator('[data-filter-search]')).toBeFocused();
  await expect(yearSelect).toHaveValue('');
  await expect(page).toHaveURL(/\/timeline$/);
  await page.keyboard.press('Tab');
  await expect(yearSelect).toBeFocused();
  await page.goBack();
  await expect(page).toHaveURL(filteredURL);
  await expect(yearSelect).toHaveValue(year);
  await expect(cards).toHaveCount(0);
});

test('article contents reach and focus the heading at wide and compact widths', async ({ page }) => {
  for (const width of [1440, 390]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.goto('/blog/java-strings');
    await expect(page.locator('#toc')).toHaveAttribute('data-toc-enhanced', 'true');
    if (width === 390) await page.locator('.article-toc-compact > summary').click();
    const link = page.locator('.toc-anchor').nth(2);
    const href = await link.getAttribute('href');
    await link.focus();
    await link.press('Enter');
    await expect(link).toHaveAttribute('aria-current', 'location');
    await expect(page.locator('.toc-anchor[aria-current]')).toHaveCount(1);
    const heading = page.locator(`[id=${JSON.stringify(decodeURIComponent(href.slice(1)))}]`).locator('..');
    await expect(heading).toBeFocused();
    await expect.poll(async () => heading.evaluate(element => {
      const boundary = innerWidth <= 1400 ? document.querySelector('#toc') : document.querySelector('#top-taskbar');
      return Math.abs(element.getBoundingClientRect().top - boundary.getBoundingClientRect().bottom - 16);
    })).toBeLessThan(3);
    await page.keyboard.press('Tab');
    expect(await heading.evaluate(element => Boolean(element.compareDocumentPosition(document.activeElement) & Node.DOCUMENT_POSITION_FOLLOWING))).toBe(true);
  }
});

test('global search opens, searches, and restores keyboard focus on Escape', async ({ page }) => {
  await page.goto('/blog');
  const opener = page.locator('#search-taskbar-button');
  await opener.focus();
  await opener.press('Enter');
  const input = page.locator('#site-search-palette-query');
  await expect(input).toBeFocused();
  await input.fill('Fibonacci');
  await expect(page.locator('dialog[open] .site-search-results a').first()).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.locator('dialog[open]')).toHaveCount(0);
  await expect(opener).toBeFocused();
});

test('native disclosures and hints stay readable without JavaScript', async ({ browser, baseURL }) => {
  const context = await browser.newContext({ baseURL, javaScriptEnabled: false, viewport: { width: 390, height: 900 } });
  try {
    const page = await context.newPage();
    await page.goto('/about');
    await page.locator('#cves > summary').click();
    await expect(page.locator('#cves')).toHaveAttribute('open', '');
    await page.locator('#cves .profile-card-details > summary').first().click();
    await expect(page.locator('#cves .aboutme-card-body').first()).toBeVisible();
    await page.goto('/ctf/sekaictf/Fancy%20Web');
    await expect(page.locator('.writeup-hint-spoiler-content')).toHaveCount(2);
    await expect(page.locator('.writeup-hint-spoiler-content').first()).toContainText('in_array');
    await expect(page.locator('.writeup-hint-spoiler-content').last()).toContainText('__toString');
    await expect(page.locator('.writeup-hint-spoiler-content[inert], .writeup-hint-spoiler-content[aria-hidden="true"]')).toHaveCount(0);
    await expect(page.locator('[data-hint-spoiler-reveal]').first()).toBeHidden();
    expect(await page.locator('.writeup-hint-spoiler-content').first().evaluate(element => getComputedStyle(element).filter)).toBe('none');
  } finally {
    await context.close();
  }
});
