#!/usr/bin/env node
// StealthPanda CF Challenge Solver
// Uses Chrome headed to solve CF managed challenges and extract clearance cookies.
// The cf_clearance cookie can then be used by StealthPanda for scraping.

import puppeteer from '/tmp/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const url = process.argv[2] || 'https://www.hapag-lloyd.com/en/online-business/track-and-trace.html';
const timeout = parseInt(process.argv[3] || '60000');

const browser = await puppeteer.launch({
  executablePath: '/var/lib/flatpak/app/com.google.Chrome/x86_64/stable/3f44dc164c2c4c4734bba97e0214ce9fcd355495287d4daf34825809d1df869d/files/extra/chrome',
  headless: false,
  args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage',
         '--disable-blink-features=AutomationControlled',
         '--window-size=1280,720',
         '--user-data-dir=/tmp/chrome_solver_' + Date.now()],
  defaultViewport: null
});

const page = await browser.newPage();
await page.evaluateOnNewDocument(() => {
  Object.defineProperty(navigator, 'webdriver', { get: () => false });
});

process.stderr.write(`Solving challenge for ${url}...\n`);

await page.goto(url, {
  waitUntil: 'networkidle0',
  timeout
}).catch(() => {});

// Wait for clearance
for (let i = 0; i < 12; i++) {
  await new Promise(r => setTimeout(r, 5000));
  const cookies = await page.cookies();
  const clearance = cookies.find(c => c.name === 'cf_clearance');
  if (clearance) {
    // Output cookies as JSON to stdout
    const output = {
      cf_clearance: clearance.value,
      __cf_bm: (cookies.find(c => c.name === '__cf_bm') || {}).value || '',
      _cfuvid: (cookies.find(c => c.name === '_cfuvid') || {}).value || '',
      domain: clearance.domain,
      expires: clearance.expires,
    };
    console.log(JSON.stringify(output));
    process.stderr.write('Challenge solved! cf_clearance obtained.\n');
    await browser.close();
    process.exit(0);
  }
  const title = await page.title();
  if (!title.includes('moment')) {
    // Page loaded without clearance
    const allCookies = cookies.reduce((acc, c) => { acc[c.name] = c.value; return acc; }, {});
    console.log(JSON.stringify(allCookies));
    process.stderr.write(`Page loaded: ${title}\n`);
    await browser.close();
    process.exit(0);
  }
  process.stderr.write(`Waiting... (${(i+1)*5}s)\n`);
}

process.stderr.write('Challenge timeout\n');
await browser.close();
process.exit(1);
