import fs from 'node:fs/promises';
import path from 'node:path';
import { chromium } from '@playwright/test';

// Diagnostic timings only. Correct outcomes and finite measurements are required.
export async function measureInteractions(base, reportDirectory) {
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(base).hostname)) throw new Error('Interaction measurements require a loopback server');
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const report = { conditions: 'Local production, desktop Chromium, unthrottled; five samples per size. Synthetic data uses the real filter module; timings are trends, not pass/fail thresholds.', filters: [] };
  try {
    for (const size of [100, 500, 1000]) {
      const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
      const page = await context.newPage();
      await page.route('**/timeline', async route => {
        const response = await route.fetch();
        const html = await response.text();
        // Inline setup runs while parsing, before deferred ES modules initialize.
        const setup = `<script>(() => {
          const first = document.querySelector('[data-filter-card="timeline"]');
          const template = first.closest('.timeline-item').cloneNode(true);
          const parent = first.closest('.timeline-item').parentElement;
          document.querySelectorAll('.timeline-item').forEach(item => item.remove());
          for (let i = 0; i < ${size}; i++) {
            const item = template.cloneNode(true);
            [item, ...item.querySelectorAll('[id]')].forEach(node => node.removeAttribute('id'));
            const card = item.querySelector('[data-filter-card="timeline"]') || item;
            Object.assign(card.dataset, { filterText: i % 2 ? 'qaneon' : 'qaquasar', filterTags: '', filterYears: '2025' });
            parent.appendChild(item);
          }
        })();</script>`;
        await route.fulfill({ response, body: html.replace('</body>', `${setup}</body>`) });
      });
      await page.goto(new URL('/timeline', base).href);
      await page.locator('[data-filter-scope="timeline"][data-initialized="true"]').waitFor();
      const samples = [];
      for (let i = 0; i < 5; i++) {
        for (const [query, expected] of [['qaquasar', size / 2], ['unfindablefixture', 0], ['', size]]) {
          const result = await page.evaluate(({ query, expected, size }) => new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error('Filter completion timed out')), 10000);
            const started = performance.now();
            document.addEventListener('content:filters-applied', event => {
              if (event.detail.total !== size || event.detail.visible !== expected) {
                clearTimeout(timer);
                reject(new Error(`Wrong filter result: ${JSON.stringify(event.detail)}`));
                return;
              }
              requestAnimationFrame(() => requestAnimationFrame(() => {
                clearTimeout(timer);
                resolve({ query, visible: expected, duration_ms: performance.now() - started });
              }));
            }, { once: true });
            const input = document.querySelector('[data-filter-search="timeline"]');
            input.value = query;
            input.dispatchEvent(new Event('input', { bubbles: true }));
          }), { query, expected, size });
          if (!Number.isFinite(result.duration_ms) || result.duration_ms < 0) throw new Error('Invalid filter timing');
          samples.push(result);
        }
      }
      const times = samples.map(sample => sample.duration_ms).sort((a, b) => a - b);
      report.filters.push({ cards: size, median_ms: times[7], p95_ms: times[14], samples });
      await context.close();
    }

    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(new URL('/blog', base).href);
    const launcher = page.locator('[data-site-search-open][aria-keyshortcuts]');
    await launcher.waitFor();
    const start = performance.now();
    await launcher.click();
    await page.locator('#site-search-palette-query').fill('GuardedString');
    await page.locator('dialog[open] .site-search-results a[href^="/blog/java-strings"]').first().waitFor();
    report.search = { cold_open_to_result_ms: performance.now() - start, resources: await page.evaluate(() => performance.getEntriesByType('resource').filter(entry => /site_search|\/search\/index\.json/.test(entry.name)).map(entry => ({ url: new URL(entry.name).pathname, transfer_bytes: entry.transferSize, duration_ms: entry.duration }))) };
    await context.close();
    // Math rendering is an optional external dependency. A budget run must not
    // appear healthy merely because the expensive renderer failed to load.
    const math = await browser.newPage();
    await math.goto(new URL('/blog/climbing-stairs', base).href);
    await math.locator('.markdown-content[data-math-state="ready"] mjx-container').first().waitFor({ timeout: 30000 });
    report.math = { rendered: true };
    const illustrated = await browser.newPage({ viewport: { width: 390, height: 844 } });
    await illustrated.goto(new URL('/ctf/umdctf/A%20Minecraft%20Movie', base).href);
    const images = illustrated.locator('main.article-page img');
    const imageCount = await images.count();
    if (!imageCount || imageCount > 100) throw new Error('Unexpected image-heavy fixture size');
    for (let index = 0; index < imageCount; index++) {
      await images.nth(index).scrollIntoViewIfNeeded();
      await images.nth(index).evaluate(image => image.decode());
    }
    report.illustrated_article = {
      loaded_images: imageCount,
      resources: await illustrated.evaluate(() => performance.getEntriesByType('resource').filter(entry => entry.initiatorType === 'img').map(entry => ({ url: new URL(entry.name).pathname, transfer_bytes: entry.transferSize, duration_ms: entry.duration }))),
    };
  } finally {
    await browser.close();
    await fs.mkdir(reportDirectory, { recursive: true });
    await fs.writeFile(path.join(reportDirectory, 'interactions.json'), JSON.stringify(report, null, 2));
  }
  console.log(`Filter diagnostics: ${report.filters.map(row => `${row.cards} cards ${row.median_ms.toFixed(1)}ms median`).join('; ')}. Search cold open: ${report.search.cold_open_to_result_ms.toFixed(1)}ms.`);
}
