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
    \\      // Defer with multiple delays to ensure shadow host is connected
    \\      var triggered = false;
    \\      var triggerSrc = function() {
    \\        if (triggered) return;
    \\        var alive = !!iframe;
    \\        var connected = alive && iframe.isConnected;
    \\        var hasSrc = alive && iframe.getAttribute('src');
    \\        if (connected) {
    \\          triggered = true;
    \\          try { iframe.src = hasSrc; } catch(e) {}
    \\        }
    \\      };
    \\      setTimeout(triggerSrc, 50);
    \\      setTimeout(triggerSrc, 500);
    \\    }
    \\    return result;
    \\  };
    \\})();
    \\
    \\// 6. Intercept Turnstile handler to inject logging into requestExtraParams
    \\(function() {
    \\  var _ael = EventTarget.prototype.addEventListener;
    \\  EventTarget.prototype.addEventListener = function(type, fn, opts) {
    \\    if (type === 'message' && fn && fn.toString().indexOf('widgetMap') !== -1) {
    \\      var origFn = fn;
    \\      var wrapped = function(e) {
    \\        try {
    \\          origFn.call(this, e);
    \\        } catch(ex) {}
    \\      };
    \\      return _ael.call(this, type, wrapped, opts);
    \\    }
    \\    return _ael.call(this, type, fn, opts);
    \\  };
    \\})();
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
