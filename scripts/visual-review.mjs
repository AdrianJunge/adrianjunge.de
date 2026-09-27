import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { chromium } from '@playwright/test';

export async function captureVisuals(baseURL) {
  const base = new URL(baseURL);
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(base.hostname)) throw new Error('Visual review requires a local server');
  const directory = 'tmp/visual-review';
  await fs.rm(directory, { recursive: true, force: true });
  await fs.mkdir(directory, { recursive: true });
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  try {
    for (const width of [390, 1440]) {
      const page = await browser.newPage({ viewport: { width, height: 1000 }, reducedMotion: 'reduce' });
      for (const [name, route] of [['home', '/'], ['timeline', '/timeline'], ['article', '/blog/java-strings']]) {
        await page.goto(new URL(route, base).href);
        await page.evaluate(() => document.fonts.ready);
        await page.locator('main').waitFor();
        await page.screenshot({ path: path.join(directory, `${name}-${width}.png`), animations: 'disabled' });
      }
      await page.close();
    }
  } finally { await browser.close(); }
  console.log(`Six viewport references saved to ${directory}; compare with test/fixtures/visual. No automatic baseline overwrite or pixel gate.`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  await captureVisuals(process.env.VISUAL_BASE_URL || 'http://127.0.0.1:3210');
}
