const { chromium } = require('playwright');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const ledger = require('../Docs/word-resources/generated-images.json');
const fs = require('node:fs');

(async () => {
  const browser = await chromium.launch({ headless: true, channel: process.env.PLAYWRIGHT_CHANNEL || 'chrome' });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    await page.goto(pathToFileURL(path.resolve(__dirname, '../Docs/word-resources/image-review.html')).href);
    await page.locator('img').evaluateAll(images => images.forEach(image => { image.loading = 'eager'; }));
    await page.waitForFunction(() => [...document.images].every(image => image.complete));
    const broken = await page.locator('img').evaluateAll(images => images.filter(image => image.naturalWidth !== 128 || image.naturalHeight !== 128).length);
    if (broken || await page.locator('figure').count() !== ledger.assets.length) throw new Error(`Broken or absent images: ${broken}`);
    await page.screenshot({ path: '/private/tmp/NCEWordImagesDesktop.png' });
    await page.locator('#kind').selectOption('meaning_card');
    if (await page.locator('figure:visible').count() !== ledger.assets.filter(asset => asset.kind === 'meaning_card').length) throw new Error('Meaning-card filter count is wrong');
    await page.locator('#kind').selectOption('');
    await page.locator('#query').fill('handbag');
    if (await page.locator('figure:visible').count() !== 1) throw new Error('Word search is wrong');
    await page.locator('#query').fill('');
    for (const width of [390, 320]) {
      await page.setViewportSize({ width, height: 844 });
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth > innerWidth);
      if (overflow) throw new Error(`Horizontal overflow at ${width}px`);
      await page.screenshot({ path: `/private/tmp/NCEWordImagesMobile-${width}.png` });
    }
    await page.locator('#kind').selectOption('ai_illustration');
    const aiCount = ledger.assets.filter(asset => asset.kind === 'ai_illustration').length;
    if (await page.locator('figure:visible').count() !== aiCount) throw new Error('AI-illustration filter count is wrong');
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: width === 1440 ? 1000 : 844 });
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw new Error(`AI-gallery overflow at ${width}px`);
      await page.screenshot({ path: `/private/tmp/NCEWordImagesAI-${width}.png` });
    }
    console.log(`Review gallery: all ${ledger.assets.length} images loaded at 128x128; ${aiCount} AI illustrations; filters/search and 1440/390/320 layouts passed.`);
    if (process.env.CONTACT_DIRECTORY) {
      const directory = process.env.CONTACT_DIRECTORY;
      fs.mkdirSync(directory, { recursive: true });
      await page.setViewportSize({ width: 1440, height: 1200 });
      await page.locator('#kind').selectOption('');
      await page.addStyleTag({ content: 'header{display:none}main{grid-template-columns:repeat(10,1fr);gap:12px;margin:0}body{margin:12px}small{font-size:11px}figcaption{font-size:12px}' });
      for (let start = 0; start < ledger.assets.length; start += 60) {
        await page.locator('figure').evaluateAll((figures, start) => figures.forEach((figure, index) => { figure.hidden = index < start || index >= start + 60; }), start);
        await page.screenshot({ path: path.join(directory, `page-${String(start / 60 + 1).padStart(2, '0')}.png`), fullPage: true });
      }
      console.log(`Rendered ${Math.ceil(ledger.assets.length / 60)} contact pages covering every final image and caption.`);
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
