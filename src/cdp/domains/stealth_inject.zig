// StealthPanda: Stealth injection script.
// Injected at V8 context creation time (before any page scripts).
// Patches JS APIs that bot detectors probe to detect automation.

pub const script: [:0]const u8 =
    // Lock navigator.webdriver to false
    \\Object.defineProperty(navigator, 'webdriver', {
    \\  get: () => false, configurable: false, enumerable: true
    \\});
    \\
    // Ensure window.chrome exists with realistic structure
    \\if (!window.chrome) window.chrome = {};
    \\if (!window.chrome.runtime) {
    \\  window.chrome.runtime = {
    \\    connect: function() {},
    \\    sendMessage: function() {},
    \\    onMessage: { addListener: function() {}, removeListener: function() {} },
    \\    onConnect: { addListener: function() {}, removeListener: function() {} },
    \\  };
    \\}
    \\if (!window.chrome.csi) window.chrome.csi = function() { return {}; };
    \\if (!window.chrome.loadTimes) window.chrome.loadTimes = function() {
    \\  return {
    \\    commitLoadTime: Date.now() / 1000,
    \\    connectionInfo: 'h2',
    \\    finishDocumentLoadTime: Date.now() / 1000,
    \\    finishLoadTime: Date.now() / 1000,
    \\    firstPaintAfterLoadTime: 0,
    \\    firstPaintTime: Date.now() / 1000,
    \\    navigationType: 'Other',
    \\    npnNegotiatedProtocol: 'h2',
    \\    requestTime: Date.now() / 1000 - 0.3,
    \\    startLoadTime: Date.now() / 1000 - 0.2,
    \\    wasAlternateProtocolAvailable: false,
    \\    wasFetchedViaSpdy: true,
    \\    wasNpnNegotiated: true,
    \\  };
    \\};
    \\
    // Patch Permissions.query to return 'prompt' for notifications
    // (headless Chrome returns 'denied' which is a detection vector)
    \\if (typeof Permissions !== 'undefined' && Permissions.prototype) {
    \\  const origQuery = Permissions.prototype.query;
    \\  Permissions.prototype.query = function(desc) {
    \\    if (desc && desc.name === 'notifications') {
    \\      return Promise.resolve({ state: 'prompt', onchange: null });
    \\    }
    \\    return origQuery ? origQuery.call(this, desc) : Promise.resolve({ state: 'prompt', onchange: null });
    \\  };
    \\}
    \\
    // Ensure toString() on native functions looks native
    \\const nativeToString = Function.prototype.toString;
    \\const fakeNatives = new Map();
    \\function makeNative(fn, name) {
    \\  fakeNatives.set(fn, 'function ' + name + '() { [native code] }');
    \\}
    \\Function.prototype.toString = function() {
    \\  if (fakeNatives.has(this)) return fakeNatives.get(this);
    \\  return nativeToString.call(this);
    \\};
    \\makeNative(Function.prototype.toString, 'toString');
    \\
    // Block unsupported_browser reject (capture phase, before Turnstile handler)
    \\window.addEventListener('message', function(e) {
    \\  if (e.data && e.data.source === 'cloudflare-challenge' &&
    \\      e.data.event === 'reject' && e.data.reason === 'unsupported_browser') {
    \\    e.stopImmediatePropagation();
    \\  }
    \\}, true);
    \\
    // Worker polyfill for managed challenge POW
    // CF creates Workers from Blob URLs for proof-of-work computation.
    // This polyfill runs worker code inline on the main thread.
    \\(function() {
    \\  var _origBlob = window.Blob;
    \\  window.Blob = function(parts, options) {
    \\    return new _origBlob(parts, options);
    \\  };
    \\  window.Blob.prototype = _origBlob.prototype;
    \\  var _origWorker = window.Worker;
    \\  window.Worker = function(url) {
    \\    var _code = null, _msgHandler = null;
    \\    var worker = {
    \\      onmessage: null, onerror: null,
    \\      _listeners: {},
    \\      postMessage: function(data) {
    \\        if (!_code) { setTimeout(function() { worker.postMessage(data); }, 50); return; }
    \\        try {
    \\          var scope = { postMessage: function(msg) {
    \\            setTimeout(function() {
    \\              var ev = new MessageEvent('message', {data: msg});
    \\              if (worker.onmessage) worker.onmessage(ev);
    \\              (worker._listeners['message'] || []).forEach(function(fn) { fn(ev); });
    \\            }, 1);
    \\          }, addEventListener: function(t, fn) { if (t === 'message') _msgHandler = fn; },
    \\          removeEventListener: function() {}, close: function() {},
    \\          importScripts: function() {},
    \\          crypto: window.crypto, performance: window.performance,
    \\          Math: Math, Uint8Array: Uint8Array, Uint32Array: Uint32Array,
    \\          Int32Array: Int32Array, Float64Array: Float64Array,
    \\          ArrayBuffer: ArrayBuffer, DataView: DataView,
    \\          TextEncoder: TextEncoder, TextDecoder: TextDecoder,
    \\          atob: window.atob, btoa: window.btoa,
    \\          console: console, setTimeout: setTimeout, setInterval: setInterval,
    \\          clearTimeout: clearTimeout, clearInterval: clearInterval };
    \\          scope.self = scope; scope.globalThis = scope;
    \\          var fn = new Function('self','postMessage','addEventListener',
    \\            'removeEventListener','close','importScripts',
    \\            'crypto','performance','Math',
    \\            'Uint8Array','Uint32Array','Int32Array','Float64Array',
    \\            'ArrayBuffer','DataView','TextEncoder','TextDecoder',
    \\            'atob','btoa','console','setTimeout','setInterval',
    \\            'clearTimeout','clearInterval','globalThis', _code);
    \\          fn(scope,scope.postMessage,scope.addEventListener,
    \\            scope.removeEventListener,scope.close,scope.importScripts,
    \\            window.crypto,window.performance,Math,
    \\            Uint8Array,Uint32Array,Int32Array,Float64Array,
    \\            ArrayBuffer,DataView,TextEncoder,TextDecoder,
    \\            window.atob,window.btoa,console,setTimeout,setInterval,
    \\            clearTimeout,clearInterval,scope);
    \\          if (_msgHandler) _msgHandler(new MessageEvent('message', {data: data}));
    \\        } catch(e) {
    \\          if (worker.onerror) worker.onerror({message: e.message, error: e});
    \\        }
    \\      },
    \\      terminate: function() {},
    \\      addEventListener: function(type, fn) {
    \\        if (!worker._listeners[type]) worker._listeners[type] = [];
    \\        worker._listeners[type].push(fn);
    \\      },
    \\      removeEventListener: function(type, fn) {
    \\        var list = worker._listeners[type];
    \\        if (list) worker._listeners[type] = list.filter(function(f) { return f !== fn; });
    \\      }
    \\    };
    \\    if (typeof url === 'string' && url.startsWith('blob:')) {
    \\      fetch(url).then(function(r) { return r.text(); }).then(function(code) {
    \\        _code = code;
    \\      }).catch(function() {});
    \\    }
    \\    return worker;
    \\  };
    \\})();
;
