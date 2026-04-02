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
    \\// 5. Force Turnstile render via polling
    \\(function() {
    \\  var iv = setInterval(function() {
    \\    if (typeof turnstile !== 'undefined' && turnstile.render) {
    \\      clearInterval(iv);
    \\      var els = document.querySelectorAll('.cf-turnstile[data-sitekey]');
    \\      for (var i = 0; i < els.length; i++) {
    \\        if (!els[i].querySelector('iframe')) {
    \\          turnstile.render(els[i]);
    \\        }
    \\      }
    \\    }
    \\  }, 200);
    \\  setTimeout(function() { clearInterval(iv); }, 30000);
    \\})();
    \\
    \\// 6. (removed) Let Turnstile parent code handle requestExtraParams natively
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
