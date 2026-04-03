// StealthPanda: Stealth injection script.
// Injected at V8 context creation time (before any page scripts).
// Patches JS APIs that bot detectors probe to detect automation.

pub const script: [:0]const u8 =
    \\
    \\(function() {
    \\  var _stub = function _s() { return _stub; };
    \\  _stub.bind = function() { return _stub; };
    \\  _stub.call = function() { return _stub; };
    \\  _stub.apply = function() { return _stub; };
    \\  Object.defineProperty(Number.prototype, 'bind', {value: function() { return _stub; }, writable: true, configurable: true, enumerable: false});
    \\  Object.defineProperty(Number.prototype, 'call', {value: function() { return _stub; }, writable: true, configurable: true, enumerable: false});
    \\  Object.defineProperty(Number.prototype, 'apply', {value: function() { return _stub; }, writable: true, configurable: true, enumerable: false});
    \\  var _noopArr = function() { return undefined; };
    \\  ['pop','shift','splice','push','unshift','indexOf'].forEach(function(m) {
    \\    if (typeof Number.prototype[m] === 'undefined') {
    \\      Object.defineProperty(Number.prototype, m, {value: _noopArr, writable: true, configurable: true, enumerable: false});
    \\    }
    \\  });
    \\})();
    \\
    \\
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
    \\  var result = nativeToString.call(this);
    \\  if (typeof result !== 'string') {
    \\    return 'function ' + (this.name || '') + '() { [native code] }';
    \\  }
    \\  return result;
    \\};
    \\makeNative(Function.prototype.toString, 'toString');
    \\try { Object.defineProperty(window, '_makeNative', {value: makeNative, enumerable: false, configurable: true, writable: true}); } catch(e) {}
    \\try { Object.defineProperty(window, 'makeNative', {value: makeNative, enumerable: false, configurable: true, writable: true}); } catch(e) {}
    \\
    // Block unsupported_browser reject (capture phase, before Turnstile handler)
    \\window.addEventListener('message', function(e) {
    \\  if (e.data && e.data.source === 'cloudflare-challenge' &&
    \\      e.data.event === 'reject' && e.data.reason === 'unsupported_browser') {
    \\    e.stopImmediatePropagation();
    \\  }
    \\}, true);
    \\
    // Stub APIs that CF orchestrator checks for browser identity
    \\if (typeof Notification === 'undefined') {
    \\  window.Notification = function(title, opts) {};
    \\  Notification.permission = 'default';
    \\  Notification.requestPermission = function() {
    \\    return Promise.resolve('default');
    \\  };
    \\}
    \\if (typeof BroadcastChannel === 'undefined') {
    \\  window.BroadcastChannel = function(name) {
    \\    this.name = name;
    \\    this.postMessage = function() {};
    \\    this.close = function() {};
    \\    this.onmessage = null;
    \\  };
    \\}
    \\if (typeof indexedDB === 'undefined') {
    \\  Object.defineProperty(window, 'indexedDB', {
    \\    get: function() { return { open: function() { return {}; } }; },
    \\    configurable: true
    \\  });
    \\}
    \\if (typeof caches === 'undefined') {
    \\  Object.defineProperty(window, 'caches', {
    \\    get: function() { return { open: function() { return Promise.resolve({}); } }; },
    \\    configurable: true
    \\  });
    \\}
    \\if (typeof RTCPeerConnection === 'undefined') {
    \\  window.RTCPeerConnection = function(config) {
    \\    this.createDataChannel = function() { return {}; };
    \\    this.createOffer = function() { return Promise.resolve({}); };
    \\    this.setLocalDescription = function() { return Promise.resolve(); };
    \\    this.close = function() {};
    \\  };
    \\}
    \\if (typeof navigator.connection === 'undefined') {
    \\  Object.defineProperty(navigator, 'connection', {
    \\    get: function() { return {
    \\      effectiveType: '4g', rtt: 50, downlink: 10, saveData: false,
    \\      onchange: null, addEventListener: function() {}, removeEventListener: function() {},
    \\    }; },
    \\    configurable: true
    \\  });
    \\}
    \\if (typeof navigator.serviceWorker === 'undefined') {
    \\  Object.defineProperty(navigator, 'serviceWorker', {
    \\    get: function() { return {
    \\      register: function() { return Promise.reject(new Error('not supported')); },
    \\      ready: Promise.resolve(null),
    \\      controller: null,
    \\      getRegistrations: function() { return Promise.resolve([]); },
    \\    }; },
    \\    configurable: true
    \\  });
    \\}
    \\
    // Chrome-specific: performance.memory
    \\if (typeof performance !== 'undefined' && !performance.memory) {
    \\  Object.defineProperty(performance, 'memory', {
    \\    get: function() { return {
    \\      jsHeapSizeLimit: 2172649472,
    \\      totalJSHeapSize: 19863160,
    \\      usedJSHeapSize: 16713168,
    \\    }; },
    \\    configurable: true
    \\  });
    \\}
    \\
    // Make all stealth inject stubs look native
    \\if (typeof Notification === 'function') makeNative(Notification, 'Notification');
    \\if (typeof BroadcastChannel === 'function' && BroadcastChannel.toString().indexOf('native') < 0) makeNative(BroadcastChannel, 'BroadcastChannel');
    \\if (typeof RTCPeerConnection === 'function' && RTCPeerConnection.toString().indexOf('native') < 0) makeNative(RTCPeerConnection, 'RTCPeerConnection');
    \\
    // Stub missing Document methods that Chrome has (all made native)
    \\(function() {
    \\  var dp = Document.prototype;
    \\  var mn = makeNative;
    \\  function stub(name, fn) { if (!dp[name]) { dp[name] = fn; mn(fn, name); } }
    \\  stub('writeln', function() { document.write.apply(document, arguments); });
    \\  stub('clear', function() {});
    \\  stub('execCommand', function() { return false; });
    \\  stub('queryCommandEnabled', function() { return false; });
    \\  stub('queryCommandIndeterm', function() { return false; });
    \\  stub('queryCommandState', function() { return false; });
    \\  stub('queryCommandSupported', function() { return false; });
    \\  stub('queryCommandValue', function() { return ''; });
    \\  stub('caretRangeFromPoint', function() { return null; });
    \\  stub('createExpression', function() { return null; });
    \\  stub('createNSResolver', function() { return null; });
    \\  stub('evaluate', function() { return null; });
    \\  stub('exitFullscreen', function() { return Promise.resolve(); });
    \\  stub('exitPointerLock', function() {});
    \\  stub('getAnimations', function() { return []; });
    \\  stub('captureEvents', function() {});
    \\  stub('releaseEvents', function() {});
    \\  stub('exitPictureInPicture', function() { return Promise.resolve(); });
    \\  stub('hasStorageAccess', function() { return Promise.resolve(true); });
    \\  stub('requestStorageAccess', function() { return Promise.resolve(); });
    \\})();
    \\
    // Patch contentWindow to add missing Chrome properties
    // CF orchestrator creates a hidden iframe and enumerates all properties
    // of contentWindow, navigator, and contentDocument for fingerprinting
    \\(function() {
    \\  var origAppendChild = Node.prototype.appendChild;
    \\  Node.prototype.appendChild = function(child) {
    \\    var result = origAppendChild.call(this, child);
    \\    if (child.tagName === 'IFRAME' && child.contentWindow) {
    \\      var w = child.contentWindow;
    \\      // Add Chrome-like properties that are typically present on Window
    \\      var missing = ['external','styleMedia','defaultStatus','defaultstatus',
    \\        'offscreenBuffering','screenLeft','screenTop',
    \\        'chrome','clientInformation','onbeforeinstallprompt',
    \\        'onappinstalled','getComputedStyle','getSelection',
    \\        'ondevicemotion','ondeviceorientation','ondeviceorientationabsolute',
    \\        'oncontextmenu','onpointerdown','onpointerup','onpointermove',
    \\        'onpointerover','onpointerout','onpointerenter','onpointerleave',
    \\        'onpointercancel','ongotpointercapture','onlostpointercapture',
    \\        'onwheel','ontouchstart','ontouchend','ontouchmove','ontouchcancel',
    \\        'onanimationend','onanimationiteration','onanimationstart',
    \\        'ontransitionend','ontransitionrun','ontransitionstart',
    \\        'onabort','onblur','onerror','onfocus','onload','onresize','onscroll',
    \\        'scheduler','trustedTypes','crossOriginIsolated','originAgentCluster',
    \\        'navigation','caches','cookieStore',
    \\      ];
    \\      for (var i = 0; i < missing.length; i++) {
    \\        if (!(missing[i] in w)) {
    \\          try { w[missing[i]] = null; } catch(e) {}
    \\        }
    \\      }
    \\      // Add clientInformation as alias for navigator
    \\      if (!w.clientInformation) {
    \\        try { Object.defineProperty(w, 'clientInformation', {
    \\          get: function() { return w.navigator; }, configurable: true
    \\        }); } catch(e) {}
    \\      }
    \\    }
    \\    return result;
    \\  };
    \\})();
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
    \\
    // Make Blob and Worker wrappers look native
    \\if (typeof Blob === 'function') makeNative(Blob, 'Blob');
    \\if (typeof Worker === 'function') makeNative(Worker, 'Worker');
;
