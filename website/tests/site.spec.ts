import { expect, test } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.waitForLoadState('networkidle');
});

test('homepage download, previews and keyboard-operated integration examples', async ({ page, context }) => {
  const errors: string[] = [];
  page.on('pageerror', error => errors.push(error.message));
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveTitle('LocalStack — 让本地开发，一目了然');
  await expect(page.locator('main')).toHaveCount(1);
  await expect(page.getByRole('link', { name: '下载 macOS 版' }).first()).toHaveAttribute('href', /github\.com\/backrunner\/localstack\/releases\/download\/.+\.dmg$/);
  await page.getByRole('button', { name: '浅色', exact: true }).click();
  await expect(page.locator('.app-window img')).toHaveAttribute('src', '/brand/panel-light.png');
  await page.getByRole('button', { name: '深色', exact: true }).click();
  await expect(page.locator('.app-window img')).toHaveAttribute('src', '/brand/panel-dark.png');
  await page.getByRole('tab', { name: 'CLI', exact: true }).click();
  await expect(page.getByRole('tabpanel')).toContainText('localstack --json list');
  await page.getByRole('tab', { name: 'CLI', exact: true }).press('ArrowRight');
  await expect(page.getByRole('tab', { name: 'MCP', exact: true })).toBeFocused();
  await expect(page.getByRole('tabpanel')).toContainText('localstack mcp serve');
  await page.getByRole('button', { name: '复制当前集成示例' }).click();
  await expect(page.locator('.code-status')).toHaveText('已复制');
  expect(await page.evaluate(() => navigator.clipboard.readText())).toContain('localstack mcp serve');
  expect(errors).toEqual([]);
});

test('documentation search, anchors, standalone page and missing route', async ({ page }) => {
  await page.goto('/docs');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('h1')).toHaveText('下载与安装');
  await page.locator('.sd-search-trigger').click();
  await page.getByRole('combobox').fill('MCP');
  const result = page.getByRole('option').filter({ hasText: 'CLI 与 MCP' }).first();
  await expect(result).toBeVisible();
  await result.click();
  await expect(page).toHaveURL(/\/docs\/cli/);
  await expect(page.locator('h1')).toHaveText('CLI 与 MCP');
  await page.goto('/docs/vite#接入-vite');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('#接入-vite')).toBeInViewport();
  await page.goto('/changelog');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('h1')).toHaveText('版本更新');
  const response = await page.goto('/this-page-does-not-exist');
  await page.waitForLoadState('networkidle');
  expect(response?.status()).toBe(404);
  await expect(page.getByRole('heading', { name: '这里还没有页面' })).toBeVisible();
  await expect(page.getByRole('link', { name: '返回首页', exact: true })).toBeVisible();
});

test('mobile navigation, FAQ and layout stay usable down to 320px', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('h1')).toHaveText('让本地开发，一目了然。');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  // The responsive shell keeps navigation links in the DOM for keyboard and screen-reader access.
  await expect(page.getByRole('button', { name: '打开菜单', exact: true })).toBeVisible();
  await page.getByRole('button', { name: '打开菜单', exact: true }).click();
  await page.locator('.sd-topnav a[href="/docs"]').click();
  await expect(page.locator('h1')).toHaveText('下载与安装');
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await page.getByText('需要为每个项目安装插件吗？', { exact: false }).click();
  await expect(page.locator('details').first()).toHaveAttribute('open', '');
  await page.setViewportSize({ width: 320, height: 760 });
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  expect(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior)).toBe('auto');
});

test('SEO and agent endpoints serve the public content', async ({ request }) => {
  for (const path of ['/robots.txt', '/sitemap.xml', '/llms.txt', '/llms-full.txt', '/docs/vite/index.md', '/brand/social.png']) {
    const response = await request.get(path);
    expect(response.status(), path).toBe(200);
    expect((await response.body()).length, path).toBeGreaterThan(20);
  }
  const sitemap = await request.get('/sitemap.xml');
  expect(await sitemap.text()).toContain('https://localstack.pwp.sh/docs/vite');
  const markdown = await request.get('/docs/vite', { headers: { Accept: 'text/markdown' } });
  expect(markdown.headers()['content-type']).toContain('text/markdown');
  expect(await markdown.text()).toContain('unplugin-localstack');
});


test('English docs, locale links and current distribution details', async ({ page }) => {
  await page.goto('/docs/en/usage');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('h1')).toHaveText('Menu bar and daily use');
  await expect(page.locator('main')).toContainText('Stop one or several services');
  await expect(page.locator('main')).toContainText('does not include the standalone CLI or Widget extension');
  await expect(page.locator('link[rel="canonical"]')).toHaveAttribute('href', 'https://localstack.pwp.sh/docs/en/usage');
  await expect(page.locator('link[hreflang="zh-CN"]')).toHaveAttribute('href', 'https://localstack.pwp.sh/docs/usage');
  await page.locator('.sd-search-trigger').click();
  await page.getByRole('combobox').fill('MCP');
  const result = page.getByRole('option').filter({ hasText: 'CLI and MCP' }).first();
  await expect(result).toBeVisible();
  await result.click();
  await expect(page).toHaveURL(/\/docs\/en\/cli/);
  await expect(page.locator('h1')).toHaveText('CLI and MCP');
  await page.goto('/docs/en/distribution');
  await expect(page.locator('main')).toContainText('not been submitted to or approved');
  await page.goto('/docs/distribution');
  await expect(page.locator('h1')).toHaveText('分发与商店状态');
  await page.goto('/en');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('h1')).toContainText('Your localhost');
  await expect(page.getByRole('link', { name: 'Download for macOS' }).first()).toHaveAttribute('href', /v0\.2\.3\/LocalStack-0\.2\.3\.dmg$/);
  await page.screenshot({ path: 'test-results/home-en-desktop.png', fullPage: true });
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.screenshot({ path: 'test-results/home-zh-mobile.png', fullPage: true });
});
