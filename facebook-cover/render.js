// Renders banner.html to banner.png at exactly 1640x624 (and a 820x312 preview).
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const here = __dirname;
  const html = 'file://' + path.join(here, 'banner.html');
  const out = process.argv[2] || path.join(here, 'banner.png');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1640, height: 624 }, deviceScaleFactor: 1 });
  await page.goto(html);
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);
  await page.screenshot({ path: out, type: 'png', clip: { x: 0, y: 0, width: 1640, height: 624 } });
  // sizes of the text blocks, to check the mobile-safe zone
  const boxes = await page.evaluate(() => {
    const r = (sel) => { const b = document.querySelector(sel).getBoundingClientRect(); return { left: Math.round(b.left), right: Math.round(b.right), top: Math.round(b.top), bottom: Math.round(b.bottom), width: Math.round(b.width) }; };
    const textWidth = (sel) => { const el = document.querySelector(sel); const range = document.createRange(); range.selectNodeContents(el); const b = range.getBoundingClientRect(); return { left: Math.round(b.left), right: Math.round(b.right), width: Math.round(b.width) }; };
    return { headline: r('.headline'), l1: textWidth('.headline .l1'), l2: textWidth('.headline .l2'), lineA: textWidth('.line-a'), lineB: textWidth('.line-b'), bottom: r('.bottom') };
  });
  console.log(JSON.stringify(boxes));
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
