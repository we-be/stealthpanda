// StealthPanda: Minimal stealth injection + reject blocking.

pub const script: [:0]const u8 =
    \\// Lock navigator.webdriver to false
    \\Object.defineProperty(navigator, 'webdriver', {
    \\  get: () => false, configurable: false, enumerable: true
    \\});
    \\// Ensure window.chrome exists
    \\if (!window.chrome) window.chrome = {};
    \\if (!window.chrome.runtime) window.chrome.runtime = {};
    \\// Block unsupported_browser reject (capture phase, before Turnstile handler)
    \\window.addEventListener('message', function(e) {
    \\  if (e.data && e.data.source === 'cloudflare-challenge' &&
    \\      e.data.event === 'reject' && e.data.reason === 'unsupported_browser') {
    \\    e.stopImmediatePropagation();
    \\  }
    \\}, true);
;
