// StealthPanda: Stealth injection script.
// Injected at V8 context creation time (before any page scripts).
// Patches JS APIs that bot detectors probe to detect automation.

pub const script: [:0]const u8 =
    // Critical fingerprint fixes — run before main block with individual error handling
    \\try{if(!window.isSecureContext)Object.defineProperty(window,'isSecureContext',{value:true,writable:false,configurable:true})}catch(e){}
    // Debug: intercept XHR flow responses
    \\try{var _xo=XMLHttpRequest.prototype.open,_xs=XMLHttpRequest.prototype.send;
    \\XMLHttpRequest.prototype.open=function(m,u){this._u=u;return _xo.apply(this,arguments)};
    \\XMLHttpRequest.prototype.send=function(){var s=this,oh=this.onreadystatechange;
    \\this.addEventListener('load',function(){if(s._u&&s._u.indexOf('flow')>-1)console.warn('[FLOW]',s.status,s._u.substring(0,60),s.responseText.substring(0,200))});
    \\return _xs.apply(this,arguments)}}catch(e){}
    \\try { // begin main stealth block
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
    \\
    // Trusted Types API stub (used by Angular, React apps for XSS protection)
    \\if (typeof window.trustedTypes === 'undefined') {
    \\  var _policy = {
    \\    createHTML: function(s) { return s; },
    \\    createScript: function(s) { return s; },
    \\    createScriptURL: function(s) { return s; },
    \\  };
    \\  window.trustedTypes = {
    \\    createPolicy: function(name, rules) {
    \\      return {
    \\        createHTML: rules.createHTML || _policy.createHTML,
    \\        createScript: rules.createScript || _policy.createScript,
    \\        createScriptURL: rules.createScriptURL || _policy.createScriptURL,
    \\      };
    \\    },
    \\    defaultPolicy: _policy,
    \\    isHTML: function() { return true; },
    \\    isScript: function() { return true; },
    \\    isScriptURL: function() { return true; },
    \\    emptyHTML: '',
    \\    emptyScript: '',
    \\    getAttributeType: function() { return null; },
    \\    getPropertyType: function() { return null; },
    \\  };
    \\}
    \\
    // Web Animations API stub (Element.animate)
    \\if (!Element.prototype.animate) {
    \\  Element.prototype.animate = function(keyframes, options) {
    \\    var duration = (typeof options === 'number') ? options : (options && options.duration) || 0;
    \\    var anim = {
    \\      playState: 'finished', currentTime: duration, effect: null,
    \\      finished: Promise.resolve(), ready: Promise.resolve(),
    \\      cancel: function() { this.playState = 'idle'; },
    \\      finish: function() { this.playState = 'finished'; },
    \\      play: function() { this.playState = 'finished'; },
    \\      pause: function() { this.playState = 'paused'; },
    \\      reverse: function() {},
    \\      addEventListener: function() {},
    \\      removeEventListener: function() {},
    \\      dispatchEvent: function() { return true; },
    \\      onfinish: null, oncancel: null, onremove: null,
    \\    };
    \\    if (anim.onfinish) setTimeout(anim.onfinish, 0);
    \\    return anim;
    \\  };
    \\}
    \\
    \\
    // Lock navigator.webdriver to false
    \\Object.defineProperty(navigator, 'webdriver', {
    \\  get: () => false, configurable: false, enumerable: true
    \\});
    \\
    \\
    \\
    // Add missing Navigator properties that CF Turnstile fingerprints
    \\(function() {
    \\  var navProps = {
    \\    productSub: '20030107',
    \\    vendor: 'Google Inc.',
    \\    pdfViewerEnabled: true,
    \\    scheduling: {isInputPending: function() { return false; }},
    \\    mediaCapabilities: {decodingInfo: function() { return Promise.resolve({supported: true, smooth: true, powerEfficient: true}); }},
    \\    mediaSession: {metadata: null, playbackState: 'none', setActionHandler: function() {}, setPositionState: function() {}},
    \\    clipboard: {read: function(){return Promise.resolve([])}, readText: function(){return Promise.resolve('')}, write: function(){return Promise.resolve()}, writeText: function(){return Promise.resolve()}},
    \\    credentials: {create: function(){return Promise.resolve(null)}, get: function(){return Promise.resolve(null)}, preventSilentAccess: function(){return Promise.resolve()}, store: function(){return Promise.resolve()}},
    \\    locks: {request: function(){return Promise.resolve()}, query: function(){return Promise.resolve({held:[],pending:[]})}},
    \\    keyboard: {lock: function(){return Promise.resolve()}, unlock: function(){}},
    \\    connection: {effectiveType: '4g', rtt: 50, downlink: 10, saveData: false, onchange: null, addEventListener: function(){}, removeEventListener: function(){}},
    \\    gpu: {requestAdapter: function(){return Promise.resolve(null)}},
    \\    hid: {getDevices: function(){return Promise.resolve([])}, requestDevice: function(){return Promise.resolve([])}},
    \\    usb: {getDevices: function(){return Promise.resolve([])}},
    \\    serial: {getPorts: function(){return Promise.resolve([])}},
    \\    bluetooth: {getAvailability: function(){return Promise.resolve(false)}},
    \\    xr: {isSessionSupported: function(){return Promise.resolve(false)}},
    \\    windowControlsOverlay: {visible: false, getTitlebarAreaRect: function(){return {x:0,y:0,width:0,height:0}}, ongeometrychange: null},
    \\    ink: {requestPresenter: function(){return Promise.resolve(null)}},
    \\    virtualKeyboard: {boundingRect: {x:0,y:0,width:0,height:0}, overlaysContent: false, show: function(){}, hide: function(){}, ongeometrychange: null},
    \\    userActivation: {hasBeenActive: true, isActive: false},
    \\    getGamepads: function() { return []; },
    \\    getBattery: function() { return Promise.resolve({charging: true, chargingTime: 0, dischargingTime: Infinity, level: 1, onchargingchange: null, onchargingtimechange: null, ondischargingtimechange: null, onlevelchange: null}); },
    \\    vibrate: function() { return true; },
    \\    clearAppBadge: function() { return Promise.resolve(); },
    \\    setAppBadge: function() { return Promise.resolve(); },
    \\    getUserMedia: function(c, s, e) { if (e) e(new Error('NotFoundError')); },
    \\    requestMediaKeySystemAccess: function() { return Promise.reject(new Error('NotSupportedError')); },
    \\    sendBeacon: function() { return true; },
    \\    getInstalledRelatedApps: function() { return Promise.resolve([]); },
    \\  };
    \\  Object.keys(navProps).forEach(function(k) {
    \\    if (typeof navigator[k] === 'undefined') {
    \\      try { Object.defineProperty(navigator, k, {value: navProps[k], writable: true, configurable: true, enumerable: true}); } catch(e) {}
    \\    }
    \\  });
    \\  // Also add missing Document properties
    \\  var docProps = {
    \\    pictureInPictureEnabled: false,
    \\    pictureInPictureElement: null,
    \\    fullscreenEnabled: true,
    \\    fullscreen: false,
    \\    fullscreenElement: null,
    \\    wasDiscarded: false,
    \\    featurePolicy: {allowedFeatures: function(){return []}, allowsFeature: function(){return true}, getAllowlistForFeature: function(){return ['*']}},
    \\    fragmentDirective: {},
    \\    designMode: 'off',
    \\    onvisibilitychange: null,
    \\    onfullscreenchange: null,
    \\    onfullscreenerror: null,
    \\    onselectstart: null,
    \\    onpointerlockchange: null,
    \\    onpointerlockerror: null,
    \\    onfreeze: null,
    \\    onresume: null,
    \\    onprerenderingchange: null,
    \\    alinkColor: '', bgColor: '', fgColor: '', linkColor: '', vlinkColor: '',
    \\  };
    \\  Object.keys(docProps).forEach(function(k) {
    \\    if (typeof document[k] === 'undefined') {
    \\      try { Object.defineProperty(document, k, {value: docProps[k], writable: true, configurable: true, enumerable: true}); } catch(e) {}
    \\    }
    \\  });
    \\})();
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
    \\      addEventListener: function() {},
    \\      removeEventListener: function() {},
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
    \\  function patchIframe(child) {
    \\    if (child && child.tagName === 'IFRAME' && child.contentWindow) {
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
    \\      // Patch iframe navigator to match parent navigator properties
    \\      try {
    \\        var pn = window.navigator;
    \\        var cn = w.navigator;
    \\        if (cn) {
    \\          var navProps = ['platform','userAgent','appVersion','vendor','language',
    \\            'languages','hardwareConcurrency','deviceMemory','maxTouchPoints',
    \\            'cookieEnabled','onLine','webdriver','product','appName','appCodeName',
    \\            'doNotTrack','globalPrivacyControl'];
    \\          for (var j = 0; j < navProps.length; j++) {
    \\            (function(prop) {
    \\              if (typeof cn[prop] === 'undefined' || cn[prop] === null || cn[prop] === '') {
    \\                try { Object.defineProperty(cn, prop, {
    \\                  get: function() { return pn[prop]; }, configurable: true
    \\                }); } catch(e) {}
    \\              }
    \\            })(navProps[j]);
    \\          }
    \\          // Copy mimeTypes and plugins references
    \\          if (!cn.mimeTypes) try { Object.defineProperty(cn, 'mimeTypes', { get: function() { return pn.mimeTypes; }, configurable: true }); } catch(e) {}
    \\          if (!cn.plugins) try { Object.defineProperty(cn, 'plugins', { get: function() { return pn.plugins; }, configurable: true }); } catch(e) {}
    \\          if (!cn.mediaDevices) try { Object.defineProperty(cn, 'mediaDevices', { get: function() { return pn.mediaDevices; }, configurable: true }); } catch(e) {}
    \\          if (!cn.permissions) try { Object.defineProperty(cn, 'permissions', { get: function() { return pn.permissions; }, configurable: true }); } catch(e) {}
    \\          if (!cn.connection) try { Object.defineProperty(cn, 'connection', { get: function() { return pn.connection; }, configurable: true }); } catch(e) {}
    \\          if (!cn.gpu) try { Object.defineProperty(cn, 'gpu', { get: function() { return pn.gpu; }, configurable: true }); } catch(e) {}
    \\        }
    \\      } catch(e) {}
    \\      // Copy AudioContext and other constructors to iframe window
    \\      try {
    \\        var ctors = ['AudioContext','webkitAudioContext','OfflineAudioContext',
    \\          'SpeechSynthesis','BroadcastChannel','RTCPeerConnection','Notification'];
    \\        for (var k = 0; k < ctors.length; k++) {
    \\          if (window[ctors[k]] && !w[ctors[k]]) {
    \\            try { w[ctors[k]] = window[ctors[k]]; } catch(e) {}
    \\          }
    \\        }
    \\      } catch(e) {}
    \\    }
    \\  }
    \\  var origAppendChild = Node.prototype.appendChild;
    \\  Node.prototype.appendChild = function(child) {
    \\    var result = origAppendChild.call(this, child);
    \\    patchIframe(child);
    \\    return result;
    \\  };
    \\  var origInsertBefore = Node.prototype.insertBefore;
    \\  Node.prototype.insertBefore = function(child, ref) {
    \\    var result = origInsertBefore.call(this, child, ref);
    \\    patchIframe(child);
    \\    return result;
    \\  };
    \\  var origReplaceChild = Node.prototype.replaceChild;
    \\  Node.prototype.replaceChild = function(newChild, oldChild) {
    \\    var result = origReplaceChild.call(this, newChild, oldChild);
    \\    patchIframe(newChild);
    \\    return result;
    \\  };
    \\  // Also patch document.body/head append for innerHTML-created iframes
    \\  var origAppend = Element.prototype.append;
    \\  if (origAppend) {
    \\    Element.prototype.append = function() {
    \\      origAppend.apply(this, arguments);
    \\      for (var i = 0; i < arguments.length; i++) {
    \\        if (arguments[i] && arguments[i].tagName) patchIframe(arguments[i]);
    \\      }
    \\    };
    \\  }
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
    \\
    // Ensure AudioContext prototype has all expected methods
    \\(function() {
    \\  if (typeof AudioContext === 'function') {
    \\    var proto = AudioContext.prototype;
    \\    var noopNode = { connect: function() { return this; }, disconnect: function() {},
    \\      start: function() {}, stop: function() {},
    \\      addEventListener: function() {}, removeEventListener: function() {} };
    \\    function stubMethod(name, fn) {
    \\      if (!proto[name]) { proto[name] = fn; makeNative(fn, name); }
    \\    }
    \\    stubMethod('createAnalyser', function() {
    \\      var n = Object.create(noopNode);
    \\      n.fftSize = 2048; n.frequencyBinCount = 1024;
    \\      n.minDecibels = -100; n.maxDecibels = -30;
    \\      n.smoothingTimeConstant = 0.8;
    \\      n.getFloatFrequencyData = function(a) { if(a) for(var i=0;i<a.length;i++) a[i]=-100; };
    \\      n.getByteFrequencyData = function(a) { if(a) for(var i=0;i<a.length;i++) a[i]=0; };
    \\      n.getFloatTimeDomainData = function(a) { if(a) for(var i=0;i<a.length;i++) a[i]=0; };
    \\      n.getByteTimeDomainData = function(a) { if(a) for(var i=0;i<a.length;i++) a[i]=128; };
    \\      return n;
    \\    });
    \\    stubMethod('createOscillator', function() { return Object.create(noopNode); });
    \\    stubMethod('createGain', function() {
    \\      var n = Object.create(noopNode);
    \\      n.gain = { value: 1, setValueAtTime: function() {}, linearRampToValueAtTime: function() {},
    \\        exponentialRampToValueAtTime: function() {} };
    \\      return n;
    \\    });
    \\    stubMethod('createBiquadFilter', function() {
    \\      var n = Object.create(noopNode);
    \\      n.type = 'lowpass';
    \\      n.frequency = { value: 350, setValueAtTime: function() {} };
    \\      n.Q = { value: 1, setValueAtTime: function() {} };
    \\      n.getFrequencyResponse = function() {};
    \\      return n;
    \\    });
    \\    stubMethod('createDynamicsCompressor', function() {
    \\      var n = Object.create(noopNode);
    \\      n.threshold = { value: -24, setValueAtTime: function() {} };
    \\      n.knee = { value: 30 }; n.ratio = { value: 12 };
    \\      n.attack = { value: 0.003 }; n.release = { value: 0.25 };
    \\      n.reduction = 0;
    \\      return n;
    \\    });
    \\    stubMethod('createScriptProcessor', function() { return Object.create(noopNode); });
    \\    stubMethod('createBufferSource', function() {
    \\      var n = Object.create(noopNode);
    \\      n.buffer = null; n.loop = false; n.playbackRate = { value: 1 };
    \\      return n;
    \\    });
    \\    if (!('destination' in proto)) {
    \\      Object.defineProperty(proto, 'destination', {
    \\        get: function() { return Object.create(noopNode); }, configurable: true
    \\      });
    \\    }
    \\    window.webkitAudioContext = AudioContext;
    \\  }
    \\})();
    \\
    // Stub navigator.gpu (WebGPU) — fingerprinters check requestAdapter
    \\if (typeof navigator.gpu === 'undefined') {
    \\  Object.defineProperty(navigator, 'gpu', {
    \\    get: function() { return {
    \\      requestAdapter: function() { return Promise.resolve(null); },
    \\      getPreferredCanvasFormat: function() { return 'bgra8unorm'; },
    \\    }; },
    \\    configurable: true
    \\  });
    \\}
    \\
    // Make Blob and Worker wrappers look native
    \\if (typeof Blob === 'function') makeNative(Blob, 'Blob');
    \\if (typeof Worker === 'function') makeNative(Worker, 'Worker');
    // Listen for Turnstile interactiveBegin and try to send completion
    \\window.addEventListener('message', function(e) {
    \\  var d = e.data;
    \\  if (d && d.source === 'cloudflare-challenge' && d.event === 'interactiveBegin') {
    \\    // Respond with interactiveComplete to all iframes
    \\    setTimeout(function() {
    \\      var iframes = document.querySelectorAll('iframe');
    \\      for (var i = 0; i < iframes.length; i++) {
    \\        try { iframes[i].contentWindow.postMessage({source:'cloudflare-challenge',widgetId:d.widgetId,event:'interactiveComplete'}, '*'); } catch(e) {}
    \\      }
    \\      // Also try posting to parent
    \\      try { if (window.parent !== window) window.parent.postMessage({source:'cloudflare-challenge',widgetId:d.widgetId,event:'interactiveComplete'}, '*'); } catch(e) {}
    \\    }, 500);
    \\  }
    \\});
    \\
    // Auto-solve Turnstile interactive mode by clicking inside challenge iframes
    \\(function() {
    \\  // Listen for interactiveBegin from challenge iframes and auto-click
    \\  window.addEventListener('message', function(e) {
    \\    if (e.data && e.data.source === 'cloudflare-challenge' && e.data.event === 'interactiveBegin') {
    \\      // Find the challenge iframe and click inside it
    \\      var iframes = document.querySelectorAll('iframe');
    \\      for (var i = 0; i < iframes.length; i++) {
    \\        try {
    \\          var doc = iframes[i].contentDocument;
    \\          if (doc && doc.body) {
    \\            setTimeout(function(d) {
    \\              d.body.dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true, clientX:28, clientY:28, view:window}));
    \\              d.body.dispatchEvent(new PointerEvent('pointerdown', {bubbles:true, cancelable:true, clientX:28, clientY:28, pointerId:1, pointerType:'mouse'}));
    \\              d.body.dispatchEvent(new PointerEvent('pointerup', {bubbles:true, cancelable:true, clientX:28, clientY:28, pointerId:1, pointerType:'mouse'}));
    \\              var cb = d.querySelector('input[type=checkbox], [role=checkbox], .cb-i, .mark');
    \\              if (cb) cb.click();
    \\            }.bind(null, doc), 200);
    \\          }
    \\        } catch(e) {}
    \\      }
    \\    }
    \\  });
    \\  // Also: if we're inside a challenge iframe (detected after navigation), auto-click on load
    \\  function checkAndClick() {
    \\    try {
    \\      var href = location.href || '';
    \\      if (href.indexOf('challenges.cloudflare.com') >= 0 || href.indexOf('challenge-platform') >= 0) {
    \\        if (document.body) {
    \\          var elems = document.querySelectorAll('*');
    \\          for (var j = 0; j < elems.length; j++) {
    \\            try { elems[j].dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true, clientX:28, clientY:28})); } catch(e) {}
    \\          }
    \\          document.body.dispatchEvent(new PointerEvent('pointerdown', {bubbles:true, cancelable:true, clientX:28, clientY:28, pointerId:1, pointerType:'mouse'}));
    \\          document.body.dispatchEvent(new PointerEvent('pointerup', {bubbles:true, cancelable:true, clientX:28, clientY:28, pointerId:1, pointerType:'mouse'}));
    \\        }
    \\      }
    \\    } catch(e) {}
    \\  }
    \\  setTimeout(checkAndClick, 500);
    \\  setTimeout(checkAndClick, 2000);
    \\  setTimeout(checkAndClick, 5000);
    \\})();
    \\
    \\} catch(e) { console.warn('[SP-CRASH]', e.message, e.stack ? e.stack.split('\n')[1] : ''); } // end main stealth block
;
