import { test, expect } from '@playwright/test';

async function expectWithinViewport(locator, page) {
  const rectangle = await locator.boundingBox();
  expect(rectangle).not.toBeNull();
  const viewport = page.viewportSize();
  expect(rectangle.x).toBeGreaterThanOrEqual(-1);
  expect(rectangle.y).toBeGreaterThanOrEqual(-1);
  expect(rectangle.x + rectangle.width).toBeLessThanOrEqual(viewport.width + 1);
  expect(rectangle.y + rectangle.height).toBeLessThanOrEqual(viewport.height + 1);
}

async function expectNoHorizontalOverflow(page) {
  expect(await page.evaluate(() => document.documentElement.scrollWidth - innerWidth)).toBeLessThanOrEqual(1);
}

test('navigation and feed controls remain reachable at narrow and landscape sizes', async ({ page }) => {
  for (const viewport of [
    { width: 320, height: 568 }, { width: 360, height: 640 },
    { width: 390, height: 844 }, { width: 430, height: 932 },
    { width: 480, height: 800 }, { width: 600, height: 800 },
    { width: 667, height: 320 },
  ]) {
    await page.setViewportSize(viewport);
    await page.goto('/');
    const controls = page.locator('#top-taskbar .taskbar-link, #top-taskbar .taskbar-button-container');
    for (const control of await controls.all()) {
      await expectWithinViewport(control, page);
      const rectangle = await control.boundingBox();
      expect(rectangle.width).toBeGreaterThanOrEqual(44);
      expect(rectangle.height).toBeGreaterThanOrEqual(44);
    }
    await page.locator('.taskbar-feed-toggle').tap();
    await expect(page.locator('.taskbar-feed-menu')).toHaveAttribute('open', '');
    await expectWithinViewport(page.locator('.taskbar-feed-dropdown'), page);
    await expect(page.locator('.taskbar-feed-option')).toHaveCount(3);
    await page.touchscreen.tap(2, viewport.height - 2);
    await expect(page.locator('.taskbar-feed-menu')).not.toHaveAttribute('open');
    await expectNoHorizontalOverflow(page);
  }
});

test('the last contents link can be tapped without the progress meter covering it', async ({ page }) => {
  for (const viewport of [{ width: 320, height: 568 }, { width: 667, height: 320 }, { width: 390, height: 300 }]) {
    await page.setViewportSize(viewport);
    await page.goto('/blog/java-strings');
    await expect(page.locator('#toc')).toHaveAttribute('data-toc-enhanced', 'true');
    const disclosure = page.locator('.article-toc-compact');
    await disclosure.locator(':scope > summary').tap();
    const destination = page.locator('.toc-anchor').last();
    const href = await destination.getAttribute('href');
    await destination.tap();
    await expect(disclosure).not.toHaveAttribute('open');
    await expect(destination).toHaveAttribute('aria-current', 'location');
    expect(new URL(page.url()).hash).toBe(href);
    const heading = page.locator(`[id=${JSON.stringify(decodeURIComponent(href.slice(1)))}]`).locator('..');
    await expect(heading).toBeFocused();
    await expect.poll(async () => heading.evaluate(element => {
      const rectangle = element.getBoundingClientRect();
      const toc = document.querySelector('#toc').getBoundingClientRect();
      return rectangle.top >= toc.bottom && rectangle.top < innerHeight;
    })).toBe(true);
    await expectNoHorizontalOverflow(page);
  }
});

test('search keeps its frame, scrolls results, and dismisses with a real backdrop tap', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.goto('/timeline');
  await page.evaluate(() => {
    document.documentElement.style.setProperty('overflow-x', 'clip', 'important');
    document.documentElement.style.setProperty('overflow-y', 'auto');
  });
  const opener = page.locator('#search-taskbar-button');
  await page.evaluate(() => scrollTo(0, 600));
  const pagePosition = await page.evaluate(() => scrollY);
  const openerRectangle = await opener.boundingBox();
  await page.touchscreen.tap(openerRectangle.x + openerRectangle.width / 2, openerRectangle.y + openerRectangle.height / 2);
  const dialog = page.locator('dialog[open]');
  const input = page.locator('#site-search-palette-query');
  await expect(input).toBeFocused();
  const before = await dialog.boundingBox();
  for (const query of ['a', 'java', 'no-matching-mobile-review-word', 'a']) {
    await input.fill(query);
    await expect(dialog).toHaveAttribute('aria-busy', 'false');
    const after = await dialog.boundingBox();
    for (const dimension of ['x', 'y', 'width', 'height']) expect(Math.abs(after[dimension] - before[dimension])).toBeLessThanOrEqual(1);
  }
  const results = page.locator('[data-site-search-results]');
  await expect(results.locator('a').last()).toBeVisible();
  await results.locator('a').last().scrollIntoViewIfNeeded();
  expect(await results.evaluate(element => element.scrollTop)).toBeGreaterThan(0);
  await expectWithinViewport(page.locator('[data-site-search-close]'), page);

  // Resizing models the reduced layout viewport available with a keyboard;
  // browser chrome and keyboard behavior still need physical-device review.
  await page.setViewportSize({ width: 390, height: 300 });
  await expectWithinViewport(dialog, page);
  await expectWithinViewport(input, page);
  await expectWithinViewport(page.locator('[data-site-search-close]'), page);
  expect(await results.evaluate(element => element.clientHeight)).toBeGreaterThan(24);
  await page.touchscreen.tap(2, 150);
  await expect(dialog).toHaveCount(0);
  await expect(opener).toBeFocused();
  expect(await page.evaluate(() => scrollY)).toBe(pagePosition);
  expect(await page.evaluate(() => {
    const style = document.documentElement.style;
    return ['overflow-x', 'overflow-y'].map(property => [style.getPropertyValue(property), style.getPropertyPriority(property)]);
  })).toEqual([['clip', 'important'], ['auto', '']]);
  await expectNoHorizontalOverflow(page);
});

test('search backdrop gestures cannot scroll the article underneath', async ({ page, context, browserName }) => {
  test.skip(browserName !== 'chromium', 'Native touch gesture injection uses Chromium CDP; WebKit has no public swipe API.');
  await page.goto('/timeline');
  await page.evaluate(() => scrollTo(0, 600));
  await page.locator('#search-taskbar-button').tap();
  await page.locator('#site-search-palette-query').fill('a');
  await expect(page.locator('[data-site-search-status]')).toHaveText(/^\d+ results$/);
  const position = await page.evaluate(() => scrollY);
  const cdp = await context.newCDPSession(page);
  try {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 2, y: 700 }] });
    for (const y of [680, 620, 550, 450, 350, 250]) {
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 2, y }] });
      await page.waitForTimeout(20);
    }
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await page.waitForTimeout(300);
    expect(await page.evaluate(() => scrollY)).toBe(position);
    await expect(page.locator('dialog[open]')).toBeVisible();
    const results = page.locator('[data-site-search-results]');
    await results.evaluate(element => { element.scrollTop = element.scrollHeight; });
    await results.hover();
    await page.mouse.wheel(0, 700);
    await page.waitForTimeout(200);
    expect(await page.evaluate(() => scrollY)).toBe(position);
    await page.locator('[data-site-search-close]').tap();
    await expect(page.locator('dialog[open]')).toHaveCount(0);
    expect(await page.evaluate(() => scrollY)).toBe(position);
  } finally {
    await cdp.detach();
  }
});

test('a search result on the current page closes search and opens its destination', async ({ page }) => {
  await page.goto('/about');
  await expect(page.locator('#cves')).not.toHaveAttribute('open');
  await page.locator('#search-taskbar-button').tap();
  await page.locator('#site-search-palette-query').fill('CVEs');
  await page.locator('[data-site-search-results] a[href="/about#cves"]').tap();
  await expect(page.locator('dialog[open]')).toHaveCount(0);
  await expect(page.locator('#cves')).toHaveAttribute('open', '');
  await expect(page.locator('#cves > summary')).toBeFocused();
  expect(await page.evaluate(() => document.documentElement.style.overflow)).toBe('');
  await expect.poll(async () => page.locator('#cves > summary').evaluate(element => {
    const rectangle = element.getBoundingClientRect();
    return rectangle.top >= document.querySelector('#top-taskbar').getBoundingClientRect().bottom && rectangle.top < innerHeight;
  })).toBe(true);

  // Selecting the same URL again must reveal its destination even though the
  // hash no longer changes and therefore emits no hashchange event.
  await page.locator('#cves > summary').tap();
  await expect(page.locator('#cves')).not.toHaveAttribute('open');
  await page.locator('#search-taskbar-button').tap();
  await page.locator('[data-site-search-results] a[href="/about#cves"]').tap();
  await expect(page.locator('dialog[open]')).toHaveCount(0);
  await expect(page.locator('#cves')).toHaveAttribute('open', '');
  await expect(page.locator('#cves > summary')).toBeFocused();

  await page.goto('/blog/java-strings');
  await page.locator('#search-taskbar-button').tap();
  await page.locator('#site-search-palette-query').fill('GuardedString');
  const articleResult = page.locator('[data-site-search-results] a[href^="/blog/java-strings#"]');
  await expect(articleResult).toBeVisible();
  const articleHash = new URL(await articleResult.getAttribute('href'), page.url()).hash;
  await articleResult.tap();
  await expect(page.locator('dialog[open]')).toHaveCount(0);
  const heading = page.locator(`[id=${JSON.stringify(decodeURIComponent(articleHash.slice(1)))}]`).locator('..');
  await expect(heading).toBeFocused();
  await expect.poll(async () => heading.evaluate(element => {
    const rectangle = element.getBoundingClientRect();
    return rectangle.top >= document.querySelector('#toc').getBoundingClientRect().bottom && rectangle.top < innerHeight;
  })).toBe(true);
});

test('About disclosures and timeline filters remain usable with touch', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.goto('/about');
  await page.locator('.aboutme-stat[href="#cves"]').tap();
  await expect(page.locator('#cves')).toHaveAttribute('open', '');
  const detail = page.locator('#cves .profile-card-details').first();
  await detail.locator(':scope > summary').tap();
  await expect(detail).toHaveAttribute('open', '');
  await expect(detail.locator('.aboutme-card-body')).toBeVisible();
  await expectNoHorizontalOverflow(page);
  await page.goto('/timeline');
  await expect(page.locator('.content-filter-panel')).toHaveAttribute('data-initialized', 'true');
  const year = page.locator('[data-filter-year]');
  const firstYear = await year.locator('option').nth(1).getAttribute('value');
  await year.selectOption(firstYear);
  const input = page.locator('[data-filter-search]');
  await input.fill('no-matching-mobile-review-word');
  await expect(page.locator('[data-filter-card="timeline"]:visible')).toHaveCount(0);
  await expect(page.locator('.search-clear-btn:visible')).toHaveCount(1);
  await page.locator('.search-clear-btn:visible').tap();
  await expect(input).toHaveValue('');
  await expect(year).toHaveValue(firstYear);
  await expect(page.locator('[data-filter-card="timeline"]:visible').first()).toBeVisible();
  await page.locator('[data-filter-reset]').tap();
  await expect(year).toHaveValue('');
  await expect(input).toBeFocused();
  await expectNoHorizontalOverflow(page);
});

test('long code wraps while copy and hint controls preserve the original interactions', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 568 });
  await page.addInitScript(() => {
    Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText: async text => { window.mobileCopiedText = text; } } });
  });
  await page.goto('/blog/java-strings');
  const blocks = page.locator('.code-block');
  expect(await blocks.count()).toBeGreaterThan(0);
  for (const block of await blocks.all()) {
    expect(await block.locator('pre').evaluate(element => element.scrollWidth - element.clientWidth)).toBeLessThanOrEqual(1);
  }
  const source = await blocks.first().locator('code').textContent();
  await blocks.first().locator('.copy-btn').tap();
  await expect(blocks.first().locator('.copy-check-icon')).toBeVisible();
  expect(await page.evaluate(() => window.mobileCopiedText)).toBe(source);
  await expectNoHorizontalOverflow(page);
  await page.goto('/ctf/sekaictf/Fancy%20Web');
  const hint = page.locator('[data-hint-spoiler]').first();
  await expect(hint.locator('.writeup-hint-spoiler-content')).toHaveAttribute('inert', '');
  await hint.locator('[data-hint-spoiler-reveal]').tap();
  await expect(hint.locator('[data-hint-spoiler-reveal]')).toBeHidden();
  await expect(hint.locator('.writeup-hint-spoiler-content')).not.toHaveAttribute('inert');
  await expectNoHorizontalOverflow(page);
});
