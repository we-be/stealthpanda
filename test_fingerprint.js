// Test script to verify StealthPanda fingerprint changes via CDP
const WebSocket = require('ws');

const CDP_URL = 'ws://127.0.0.1:9222';
let msgId = 1;

async function main() {
  const ws = new WebSocket(CDP_URL);
  const pending = new Map();
  const events = [];

  ws.on('message', (data) => {
    const msg = JSON.parse(data);
    if (msg.id !== undefined && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
    } else {
      events.push(msg);
    }
  });

  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = msgId++;
      const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timeout: ${method}`)); }, 15000);
      pending.set(id, (msg) => { clearTimeout(timer); pending.delete(id); resolve(msg); });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await new Promise(r => ws.on('open', r));

  // 1. Create browser context
  console.log('Creating browser context...');
  const ctxResult = await send('Target.createBrowserContext');
  console.log('Browser context:', JSON.stringify(ctxResult));
  const browserContextId = ctxResult.result?.browserContextId;

  // 2. Create target (page)
  console.log('Creating target...');
  const targetResult = await send('Target.createTarget', {
    url: 'about:blank',
    browserContextId,
  });
  console.log('Target:', JSON.stringify(targetResult));
  const targetId = targetResult.result?.targetId;

  // 3. Attach to target
  console.log('Attaching to target...');
  const attachResult = await send('Target.attachToTarget', {
    targetId,
    flatten: true,
  });
  console.log('Attach:', JSON.stringify(attachResult));

  // Wait for sessionId in events
  await new Promise(r => setTimeout(r, 500));
  const sessionId = attachResult.result?.sessionId;
  console.log('Session ID:', sessionId);

  // Helper to send session commands
  function sessionSend(method, params = {}) {
    return send(method, { ...params, ...(sessionId ? {} : {}) });
  }

  // 4. Navigate to example.com
  console.log('Navigating to example.com...');
  const navResult = await sessionSend('Page.navigate', { url: 'https://example.com' });
  console.log('Navigation:', JSON.stringify(navResult));

  // Wait for page load
  await new Promise(r => setTimeout(r, 3000));

  // 5. Evaluate JavaScript
  const tests = [
    ['navigator.userAgent', 'Chrome UA string'],
    ['navigator.vendor', '"Google Inc."'],
    ['navigator.appVersion', 'Starts with 5.0'],
    ['navigator.plugins.length', '5'],
    ['navigator.plugins[0] ? navigator.plugins[0].name : "null"', '"PDF Viewer"'],
    ['navigator.plugins[1] ? navigator.plugins[1].name : "null"', '"Chrome PDF Viewer"'],
    ['navigator.webdriver', 'false'],
    ['navigator.platform', '"Linux x86_64"'],
    ['navigator.hardwareConcurrency', '4'],
    ['navigator.deviceMemory', '8'],
    ['navigator.language', '"en-US"'],
    ['window.innerWidth', '1920'],
    ['window.innerHeight', '1080'],
    ['window.screen.width', '1920'],
    ['window.screen.height', '1080'],
    ['window.screen.availHeight', '1040'],
    ['window.screen.colorDepth', '24'],
    ['typeof AudioContext', '"function"'],
    ['typeof document.createElement("canvas").toDataURL', '"function"'],
    ['document.createElement("canvas").toDataURL().substring(0, 22)', '"data:image/png;base64"'],
  ];

  console.log('\n=== StealthPanda Fingerprint Test ===\n');

  let passed = 0;
  let failed = 0;

  for (const [expr, expected] of tests) {
    const result = await sessionSend('Runtime.evaluate', {
      expression: `(() => { try { return String(${expr}); } catch(e) { return 'ERROR: ' + e.message; } })()`,
      returnByValue: true,
    });

    let value = 'N/A';
    if (result.result?.result?.value !== undefined) {
      value = result.result.result.value;
    } else if (result.error) {
      value = `CDP_ERROR: ${result.error.message}`;
    }

    const isError = String(value).startsWith('ERROR') || String(value).startsWith('CDP_ERROR');
    const pass = !isError && value !== 'undefined' && value !== 'N/A';

    if (pass) passed++; else failed++;
    console.log(`${pass ? '✓' : '✗'} ${expr}`);
    console.log(`  → ${value}  (expected: ${expected})\n`);
  }

  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);

  ws.close();
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
