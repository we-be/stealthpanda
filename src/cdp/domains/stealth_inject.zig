// StealthPanda: JavaScript stealth injection script.
// Injected before page scripts to patch common bot detection vectors.

pub const script: [:0]const u8 =
    \\// --- StealthPanda anti-detection patches ---
    \\
    \\// 1. Lock navigator.webdriver to false (prevent overwrite detection)
    \\Object.defineProperty(navigator, 'webdriver', {
    \\  get: () => false,
    \\  configurable: false,
    \\  enumerable: true
    \\});
    \\
    \\// 2. Remove cdc_ (ChromeDriver) artifacts from window
    \\(function() {
    \\  var keys = Object.keys(window);
    \\  for (var i = 0; i < keys.length; i++) {
    \\    if (keys[i].match(/^cdc_|^__webdriver/)) {
    \\      try { delete window[keys[i]]; } catch(e) {}
    \\    }
    \\  }
    \\})();
    \\
    \\// 3. Patch Permissions.query to return 'prompt' for notifications
    \\// (headless browsers often return 'denied' which is a detection signal)
    \\if (navigator.permissions && navigator.permissions.query) {
    \\  var origQuery = navigator.permissions.query.bind(navigator.permissions);
    \\  Object.defineProperty(navigator.permissions, 'query', {
    \\    value: function(desc) {
    \\      if (desc && desc.name === 'notifications') {
    \\        return Promise.resolve({ state: 'prompt', onchange: null });
    \\      }
    \\      return origQuery(desc);
    \\    },
    \\    writable: true,
    \\    configurable: true
    \\  });
    \\}
    \\
    \\// 4. Ensure chrome.runtime has expected shape
    \\if (window.chrome) {
    \\  if (!window.chrome.runtime) {
    \\    window.chrome.runtime = {};
    \\  }
    \\  // Chrome runtime should not have onConnect in content scripts
    \\  // but should exist in extensions
    \\}
    \\
    \\// 5. Force Turnstile implicit render after it loads
    \\// The Turnstile API uses setTimeout(Ar, 0) to trigger ready callbacks,
    \\// but the callback sometimes doesn't fire. Poll for turnstile and force render.
    \\(function() {
    \\  var checkInterval = setInterval(function() {
    \\    if (typeof turnstile !== 'undefined' && turnstile.render) {
    \\      clearInterval(checkInterval);
    \\      var els = document.querySelectorAll('.cf-turnstile[data-sitekey]');
    \\      for (var i = 0; i < els.length; i++) {
    \\        if (!els[i].dataset.rendered) {
    \\          els[i].dataset.rendered = '1';
    \\          turnstile.render(els[i]);
    \\        }
    \\      }
    \\    }
    \\  }, 100);
    \\  // Stop polling after 30s
    \\  setTimeout(function() { clearInterval(checkInterval); }, 30000);
    \\})();
    \\
    \\// 6. Respond to requestExtraParams when Turnstile can't find the iframe
    \\// Capture rcV from init messages and pass it back in extraParams response.
    \\(function() {
    \\  var widgetData = {};
    \\  window.addEventListener('message', function(e) {
    \\    if (!e.data || e.data.source !== 'cloudflare-challenge') return;
    \\    if (e.data.event === 'init' && e.data.nextRcV) {
    \\      widgetData[e.data.widgetId] = { rcV: e.data.nextRcV, mode: e.data.mode };
    \\    }
    \\    if (e.data.event !== 'requestExtraParams') return;
    \\    var iframes = document.querySelectorAll('iframe');
    \\    for (var i = 0; i < iframes.length; i++) {
    \\      if (!iframes[i].contentWindow) continue;
    \\      try {
    \\        var wd = widgetData[e.data.widgetId] || {};
    \\        iframes[i].contentWindow.postMessage({
    \\          source: 'cloudflare-challenge',
    \\          widgetId: e.data.widgetId,
    \\          event: 'extraParams',
    \\          url: location.href,
    \\          origin: location.origin,
    \\          sitekey: document.querySelector('.cf-turnstile')?.getAttribute('data-sitekey') || '',
    \\          execution: 'render',
    \\          language: 'auto',
    \\          appearance: 'always',
    \\          retry: 'auto',
    \\          'retry-interval': 8000,
    \\          'refresh-expired': 'auto',
    \\          'refresh-timeout': 'auto',
    \\          'expiry-interval': 300000,
    \\          rcV: wd.rcV || '',
    \\          turnstileType: 'm',
    \\        }, '*');
    \\      } catch(ex) {}
    \\      break;
    \\    }
    \\  });
    \\})();
    \\
    \\// 7. Block unsupported_browser reject in PARENT window (capture phase, runs before Turnstile)
    \\window.addEventListener('message', function(e) {
    \\  if (e.data && e.data.source === 'cloudflare-challenge' &&
    \\      e.data.event === 'reject' && e.data.reason === 'unsupported_browser') {
    \\    e.stopImmediatePropagation();
    \\  }
    \\}, true);
    \\
    \\// 6. Block unsupported_browser reject messages from Turnstile challenge iframes
    \\// The challenge script in the iframe sends {event:"reject",reason:"unsupported_browser"}
    \\// via parent.postMessage when it detects missing features. Block this to prevent
    \\// widget cleanup that destroys the working challenge flow.
    \\if (window.parent && window.parent !== window) {
    \\  var _origParentPM = window.parent.postMessage;
    \\  if (_origParentPM) {
    \\    window.parent.postMessage = function(msg, origin) {
    \\      if (msg && msg.event === 'reject' && msg.reason === 'unsupported_browser') {
    \\        return; // block the reject
    \\      }
    \\      return _origParentPM.apply(this, arguments);
    \\    };
    \\  }
    \\}
;
