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
      const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timeout: ${method}`)); }, 30000);
      pending.set(id, (msg) => { clearTimeout(timer); pending.delete(id); resolve(msg); });
      ws.send(JSON.stringify({ id, method, params }));
    });
  }

  const ctx = await send('Target.createBrowserContext');
  const bid = ctx.result.browserContextId;
  const tgt = await send('Target.createTarget', { url: 'about:blank', browserContextId: bid });
  const tid = tgt.result.targetId;
  const att = await send('Target.attachToTarget', { targetId: tid, flatten: true });
  const sid = att.result.sessionId;

  function sessionSend(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = msgId++;
      const timer = setTimeout(() => { pending.delete(id); reject(new Error(`Timeout: ${method}`)); }, 30000);
      pending.set(id, (msg) => { clearTimeout(timer); pending.delete(id); resolve(msg); });
      ws.send(JSON.stringify({ id, method, params, sessionId: sid }));
    });
  }

  return { send: sessionSend, sid };
}

async function evaluate(session, expr) {
  const r = await session.send('Runtime.evaluate', {
    expression: expr,
    returnByValue: true,
    awaitPromise: true,
  });
  return r.result?.result?.value ?? r.result?.exceptionDetails?.text ?? 'N/A';
}

async function testSite(session, name, url, waitMs, evalExpr) {
  console.log(`\n=== ${name} ===`);
  console.log(`URL: ${url}`);

  try {
    const nav = await session.send('Page.navigate', { url });
    if (nav.result?.errorText) {
      console.log(`  Navigation error: ${nav.result.errorText}`);
      return;
    }
    console.log(`  Navigated, waiting ${waitMs/1000}s for page load...`);
    await new Promise(r => setTimeout(r, waitMs));

    const result = await evaluate(session, evalExpr);
    console.log(`  Result: ${result}`);
  } catch (e) {
    console.log(`  Error: ${e.message}`);
  }
}

async function main() {
  const ws = new WebSocket(CDP_URL);
  await new Promise(r => ws.on('open', r));
  console.log('Connected to StealthPanda CDP\n');
  const session = await createSession(ws);

  // 1. Simple: httpbin - just check we can fetch and parse
  await testSite(session, 'httpbin (basic HTTP)', 'https://httpbin.org/headers', 3000,
    `document.body.innerText`);

  // 2. Medium: nowsecure bot detection
  await testSite(session, 'nowsecure.nl (bot detection)', 'https://nowsecure.nl/', 8000,
    `document.title + ' | ' + document.body.innerText.substring(0, 200)`);

  // 3. Medium: CreepJS fingerprint
  await testSite(session, 'CreepJS (fingerprint analysis)', 'https://abrahamjuliot.github.io/creepjs/', 10000,
    `(() => {
      const trust = document.querySelector('.visitor-info .trust-score')?.textContent || 'not found';
      const grade = document.querySelector('.grade')?.textContent || 'not found';
      return 'Trust: ' + trust + ' | Grade: ' + grade;
    })()`);

  // 4. Hard: Cloudflare challenge page
  await testSite(session, 'Cloudflare (generic check)', 'https://www.cloudflare.com/', 5000,
    `document.title + ' | status: ' + (document.body.innerText.length > 100 ? 'loaded' : 'blocked')`);

  // 5. Check what a fingerprinting service sees
  await testSite(session, 'AmIUnique (fingerprint)', 'https://amiunique.org/', 5000,
    `document.title`);

  console.log('\n\n=== All tests complete ===');
  ws.close();
  process.exit(0);
}

main().catch(e => { console.error('Fatal:', e.message); process.exit(1); });
