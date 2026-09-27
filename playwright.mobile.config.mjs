import { defineConfig } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL || 'http://127.0.0.1:3212';
if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(baseURL).hostname)) {
  throw new Error('Mobile browser tests require a local website instance.');
}

// Touch and viewport emulation exercise layout and interaction in real engines;
// they do not replace testing Safari/Chrome on physical phones.
export default defineConfig({
  testDir: './test/mobile',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  workers: 2,
  retries: 0,
  timeout: 45_000,
  expect: { timeout: 7_000 },
  outputDir: 'tmp/mobile-browser/results',
  reporter: [
    ['list'],
    ['html', { outputFolder: 'tmp/mobile-browser/report', open: 'never' }],
    ['json', { outputFile: 'tmp/mobile-browser/results.json' }],
  ],
  use: {
    baseURL,
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    isMobile: true,
    hasTouch: true,
    reducedMotion: 'reduce',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'chromium-touch', use: { browserName: 'chromium' } },
    { name: 'webkit-touch', use: { browserName: 'webkit' } },
  ],
  webServer: process.env.PLAYWRIGHT_BASE_URL ? undefined : {
    command: 'bin/rails server -e test -b 127.0.0.1 -p 3212 -P tmp/pids/mobile-browser.pid',
    url: `${baseURL}/up`,
    reuseExistingServer: false,
    timeout: 60_000,
    gracefulShutdown: { signal: 'SIGTERM', timeout: 5_000 },
  },
});
