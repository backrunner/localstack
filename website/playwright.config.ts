import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  workers: 1,
  timeout: 60000,
  expect: { timeout: 15000 },
  use: {
    baseURL: process.env.WEBSITE_TEST_URL ?? 'http://127.0.0.1:4186',
    browserName: 'chromium',
    viewport: { width: 1440, height: 1000 },
    trace: 'retain-on-failure'
  },
  webServer: process.env.WEBSITE_TEST_URL ? undefined : {
    command: 'npm run dev -- --host 127.0.0.1 --port 4186 --strictPort',
    url: 'http://127.0.0.1:4186',
    timeout: 120000,
    reuseExistingServer: !process.env.CI
  }
});
