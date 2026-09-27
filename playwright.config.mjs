import { defineConfig } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3210';
const base = new URL(baseURL);
if (!['127.0.0.1', 'localhost', '[::1]'].includes(base.hostname)) {
  throw new Error('Cross-browser smoke tests require a local website instance.');
}

export default defineConfig({
  testDir: './test/cross_browser',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  workers: 2,
  retries: 0,
  timeout: 30_000,
  expect: { timeout: 7_000 },
  outputDir: 'tmp/cross-browser/results',
  reporter: [
    ['list'],
    ['html', { outputFolder: 'tmp/cross-browser/report', open: 'never' }],
    ['json', { outputFile: 'tmp/cross-browser/results.json' }],
  ],
  use: {
    baseURL,
    viewport: { width: 1440, height: 1000 },
    reducedMotion: 'reduce',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],
  // Build CSS before running this suite. An explicit URL uses a caller-owned
  // local server; otherwise Playwright owns only this dedicated test process.
  webServer: process.env.PLAYWRIGHT_BASE_URL ? undefined : {
    command: 'bin/rails server -e test -b 127.0.0.1 -p 3210 -P tmp/pids/cross-browser.pid',
    url: `${baseURL}/up`,
    reuseExistingServer: false,
    timeout: 60_000,
    gracefulShutdown: { signal: 'SIGTERM', timeout: 5_000 },
  },
});
