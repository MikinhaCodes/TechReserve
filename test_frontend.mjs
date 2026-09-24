import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto(`file://${process.cwd()}/THEME/dashboard_techreserve_fatec_dark_clean/code.html`);
  await page.screenshot({ path: 'frontend_screenshot.png', fullPage: true });
  console.log('Screenshot captured successfully.');
  await browser.close();
})();
