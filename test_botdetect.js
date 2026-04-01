// Test StealthPanda against real bot detection pages
const WebSocket = require('ws');

const CDP_URL = 'ws://127.0.0.1:9222';
let msgId = 1;

async function createSession(ws) {
  const pending = new Map();

  ws.on('message', (data) => {
    const msg = JSON.parse(data);
    if (msg.id !== undefined && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
    }
  });

  function send(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = msgId++;
      const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timeout: ${method}`)); }, 20000);
      pending.set(id, (msg) => { clearTimeout(timer); pending.delete(id); resolve(msg); });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  await send('Target.createBrowserContext');
  await send('Target.createTarget', { url: 'about:blank', browserContextId: 'BID-1' });
  await send('Target.attachToTarget', { targetId: 'FID-0000000001', flatten: true });

  return { send };
}

async function evaluate(session, expr) {
  const r = await session.send('Runtime.evaluate', {
    expression: `(() => { try { return String(${expr}); } catch(e) { return 'ERR:' + e.message; } })()`,
    returnByValue: true,
  });
  return r.result?.result?.value ?? 'N/A';
}

async function main() {
  const ws = new WebSocket(CDP_URL);
  await new Promise(r => ws.on('open', r));
  const session = await createSession(ws);

  // ===== Test 1: bot.sannysoft.com =====
  console.log('=== Testing bot.sannysoft.com ===\n');
  console.log('Navigating...');
  await session.send('Page.navigate', { url: 'https://bot.sannysoft.com/' });
  await new Promise(r => setTimeout(r, 8000));

  // SannySoft outputs test results in a table. Let's grab key results.
  const sannyTests = [
    ['User Agent', 'document.querySelector("#res-userAgent")?.className || "missing"'],
    ['WebDriver', 'document.querySelector("#res-webdriver")?.className || "missing"'],
    ['Chrome', 'document.querySelector("#res-chrome")?.className || "missing"'],
    ['Permissions', 'document.querySelector("#res-permissions")?.className || "missing"'],
    ['Plugins Length', 'document.querySelector("#res-pluginsLength")?.className || "missing"'],
    ['Languages', 'document.querySelector("#res-languages")?.className || "missing"'],
    ['WebGL Vendor', 'document.querySelector("#res-webglVendor")?.className || "missing"'],
    ['WebGL Renderer', 'document.querySelector("#res-webglRenderer")?.className || "missing"'],
    ['Hairline', 'document.querySelector("#res-hairline")?.className || "missing"'],
    ['Broken Image', 'document.querySelector("#res-brokenImage")?.className || "missing"'],
  ];

  for (const [name, expr] of sannyTests) {
    const val = await evaluate(session, expr);
    const icon = val.includes('passed') ? '✓' : val.includes('failed') ? '✗' : val.includes('warn') ? '⚠' : '?';
    console.log(`${icon} ${name}: ${val}`);
  }

  // Also get the actual values that sannysoft sees
  console.log('\n--- Detected Values ---');
  const detectedValues = [
    ['User-Agent', 'navigator.userAgent.substring(0, 80)'],
    ['WebDriver', 'navigator.webdriver'],
    ['Languages', 'navigator.languages.join(",")'],
    ['Plugins', 'navigator.plugins.length'],
    ['Chrome obj', 'typeof window.chrome'],
    ['Permissions', 'typeof navigator.permissions?.query'],
    ['Connection', 'typeof navigator.connection'],
    ['DeviceMemory', 'navigator.deviceMemory'],
    ['HW Concurrency', 'navigator.hardwareConcurrency'],
    ['WebGL Vendor', '(()=>{try{var c=document.createElement("canvas");var g=c.getContext("webgl");var e=g.getExtension("WEBGL_debug_renderer_info");return g.getParameter(e.UNMASKED_VENDOR_WEBGL)}catch(x){return "ERR:"+x.message}})()'],
    ['WebGL Renderer', '(()=>{try{var c=document.createElement("canvas");var g=c.getContext("webgl");var e=g.getExtension("WEBGL_debug_renderer_info");return g.getParameter(e.UNMASKED_RENDERER_WEBGL)}catch(x){return "ERR:"+x.message}})()'],
    ['Canvas FP', '(()=>{try{var c=document.createElement("canvas");c.width=200;c.height=50;var x=c.getContext("2d");x.fillStyle="red";x.fillRect(10,10,50,50);x.fillStyle="blue";x.font="14px Arial";x.fillText("StealthPanda",60,35);return c.toDataURL().length}catch(e){return "ERR:"+e.message}})()'],
    ['screen.width', 'screen.width'],
    ['screen.height', 'screen.height'],
    ['colorDepth', 'screen.colorDepth'],
    ['AudioContext', 'typeof AudioContext'],
    ['Notification', 'typeof Notification'],
    ['MediaDevices', 'typeof navigator.mediaDevices'],
    ['SpeechSynth', 'typeof window.speechSynthesis'],
    ['window.chrome', 'typeof window.chrome'],
  ];

  for (const [name, expr] of detectedValues) {
    const val = await evaluate(session, expr);
    console.log(`  ${name}: ${val}`);
  }

  console.log('\nDone.');
  ws.close();
  process.exit(0);
}

main().catch(e => { console.error('Fatal:', e.message); process.exit(1); });
