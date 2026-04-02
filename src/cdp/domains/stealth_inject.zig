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
    \\// 5. Let Turnstile handle everything naturally — no blocking, no force render
;
