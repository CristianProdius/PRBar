import { chromium } from "playwright-core";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

const out = join(import.meta.dirname, "viral-frames");
mkdirSync(out, { recursive: true });

const fps = 30;
const seconds = 7;
const frames = fps * seconds;
const chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const pageUrl = "file:///Users/cristian/Development/PRBar/demo/viral-motion.html";

const browser = await chromium.launch({
  executablePath: chrome,
  headless: true,
  args: ["--hide-scrollbars", "--disable-gpu"],
});
const page = await browser.newPage({
  viewport: { width: 1280, height: 720 },
  deviceScaleFactor: 1,
});
await page.goto(pageUrl, { waitUntil: "load" });
await page.waitForFunction(() => typeof window.seek === "function");

for (let i = 0; i < frames; i++) {
  const t = i / fps;
  await page.evaluate((time) => window.seek(time), t);
  await page.screenshot({
    path: join(out, `f${String(i).padStart(4, "0")}.jpg`),
    type: "jpeg",
    quality: 88,
  });
  if (i % 30 === 0) console.log(`frame ${i}/${frames} t=${t.toFixed(2)}`);
}

await browser.close();
console.log("done", frames);
