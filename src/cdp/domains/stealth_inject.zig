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
    \\// 5. Deferred iframe.src trigger for shadow DOM iframes
    \\// When an iframe's src is set via setAttribute while it's in a detached
    \\// shadow DOM, defer the .src property assignment until the next microtask
    \\// (by which time the shadow host should be connected to the document).
    \\(function() {
    \\  var origSetAttribute = Element.prototype.setAttribute;
    \\  Element.prototype.setAttribute = function(name, value) {
    \\    var result = origSetAttribute.call(this, name, value);
    \\    if (this.tagName === 'IFRAME' && name === 'src' && value) {
    \\      var iframe = this;
    \\      // Defer to allow the shadow host to be connected first
    \\      Promise.resolve().then(function() {
    \\        try { iframe.src = iframe.getAttribute('src'); } catch(e) {}
    \\      });
    \\    }
    \\    return result;
    \\  };
    \\})();
    \\
    \\// 6. Monitor for errors in the Turnstile message handler
    \\window.addEventListener('message', function(e) {
    \\  if (e.data && e.data.source === 'cloudflare-challenge' && e.data.event === 'requestExtraParams') {
    \\    window.__repDebug = window.__repDebug || [];
    \\    window.__repDebug.push('wid:' + e.data.widgetId);
    \\  }
    \\});
    \\
    \\// 7. Block unsupported_browser reject in PARENT and IFRAME contexts
    \\window.addEventListener('message', function(e) {
    \\  if (e.data && e.data.source === 'cloudflare-challenge' &&
    \\      e.data.event === 'reject' && e.data.reason === 'unsupported_browser') {
    \\    e.stopImmediatePropagation();
    \\  }
    \\}, true);
    \\if (window.parent && window.parent !== window) {
    \\  try {
    \\    var _opm = window.parent.postMessage;
    \\    window.parent.postMessage = function(msg, o) {
    \\      if (msg && msg.event === 'reject' && msg.reason === 'unsupported_browser') return;
    \\      return _opm.apply(this, arguments);
    \\    };
    \\  } catch(e) {}
    \\}
;
