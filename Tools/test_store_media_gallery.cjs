const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const root = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(__dirname, '../StoreAssets/1.3');
  const browser = await chromium.launch({ headless: true, channel: process.env.PLAYWRIGHT_CHANNEL || 'chrome',
    args: ['--allow-file-access-from-files'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    await page.goto(pathToFileURL(path.join(root, 'index.html')).href);
    await page.locator('img').evaluateAll(images => images.forEach(image => { image.loading = 'eager'; }));
    await page.waitForFunction(() => [...document.images].every(image => image.complete));
    const images = await page.locator('img').evaluateAll(images => images.map(image => ({ width: image.naturalWidth, height: image.naturalHeight })));
    if (images.length !== 60 || images.some(image => !((image.width === 1290 && image.height === 2796) || (image.width === 2048 && image.height === 2732)))) {
      throw new Error('Absent or broken store screenshots');
    }
    if (await page.locator('video').count() !== 12) throw new Error('Missing preview videos');
    const videos = await page.locator('video').evaluateAll(async videos => {
      const results = [];
      for (const video of videos) {
        if (video.readyState < 1) await new Promise((resolve, reject) => {
          const timer = setTimeout(() => reject(new Error('Video metadata timed out')), 20000);
          video.addEventListener('loadedmetadata', () => { clearTimeout(timer); resolve(); }, { once: true });
          video.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Video loading failed')); }, { once: true });
          video.load();
        });
        results.push({ width: video.videoWidth, height: video.videoHeight, duration: video.duration });
      }
      return results;
    });
    if (videos.some(video => video.duration < 15 || video.duration > 30 || !((video.width === 886 && video.height === 1920) || (video.width === 1200 && video.height === 1600)))) {
      throw new Error('Browser reports unexpected video specifications');
    }
    const playback = await page.locator('video').evaluateAll(async videos => {
      const results = [];
      for (const video of videos) {
        video.muted = true;
        await video.play();
        await new Promise(resolve => setTimeout(resolve, 600));
        video.pause();
        if (video.currentTime <= 0) throw new Error(`Preview stalled: ${video.src}`);
        const canvas = document.createElement('canvas');
        canvas.width = 80;
        canvas.height = Math.round(80 * video.videoHeight / video.videoWidth);
        const context = canvas.getContext('2d');
        const scenes = [];
        for (let scene = 0; scene < 5; scene++) {
          const seconds = scene * 4.8 + 1.2;
          await new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error(`Video seeking timed out: ${video.src}`)), 20000);
            video.addEventListener('seeked', () => { clearTimeout(timer); resolve(); }, { once: true });
            video.currentTime = seconds;
          });
          context.drawImage(video, 0, 0, canvas.width, canvas.height);
          const values = context.getImageData(0, 0, canvas.width, canvas.height).data;
          let low = 255, high = 0;
          for (let index = 0; index < values.length; index += 4) {
            for (let channel = 0; channel < 3; channel++) {
              low = Math.min(low, values[index + channel]);
              high = Math.max(high, values[index + channel]);
            }
          }
          if (high - low < 100) throw new Error(`Blank preview scene ${scene + 1}: ${video.src}`);
          scenes.push({ seconds, pixelRange: high - low });
        }
        results.push({ path: new URL(video.src).pathname, playing: true, sampled_scenes: scenes });
        video.currentTime = 0;
      }
      return results;
    });
    for (const width of [1440, 390, 320]) {
      await page.setViewportSize({ width, height: width === 1440 ? 1000 : 844 });
      if (await page.evaluate(() => document.documentElement.scrollWidth > innerWidth)) throw new Error(`Horizontal overflow at ${width}px`);
      await page.screenshot({ path: path.join(root, `review/gallery-${width}.png`) });
    }
    fs.writeFileSync(path.join(root, 'review/gallery-validation.json'), JSON.stringify({ status: 'passed', screenshots_loaded: images.length,
      videos_loaded: videos.length, browser_video_metadata: videos, nonblank_playback: playback,
      viewport_widths: [1440, 390, 320], horizontal_overflow: false }, null, 2) + '\n');
    console.log('Store gallery: 60 images, all 12 previews playing with 5 nonblank scenes each, desktop/mobile layouts passed.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
