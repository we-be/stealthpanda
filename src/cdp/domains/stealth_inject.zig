// StealthPanda: Stealth injection script.
// Injected at V8 context creation time (before any page scripts).
// Patches JS APIs that bot detectors probe to detect automation.

pub const script: [:0]const u8 =
    \\try { // begin main stealth block
    \\
    \\// Number.prototype patches DISABLED — may cause wrong VM computation
    \\// These were added to prevent crashes in CF's XOR-indexed handler table
    \\// but they change the VM's code path, potentially producing wrong results
    \\
    \\
    \\
    // Add critical missing Window APIs that CF checks
    \\(function() {
    \\  // indexedDB stub
    \\  if (typeof indexedDB === 'undefined') {
    \\    Object.defineProperty(window, 'indexedDB', {
    \\      value: {
    \\        open: function(name, ver) {
    \\          return {
    \\            result: null, error: null, readyState: 'done',
    \\            onsuccess: null, onerror: null, onupgradeneeded: null,
    \\            addEventListener: function() {}, removeEventListener: function() {}
    \\          };
    \\        },
    \\        deleteDatabase: function() { return { onsuccess: null, onerror: null }; },
    \\        databases: function() { return Promise.resolve([]); },
    \\        cmp: function() { return 0; }
    \\      },
    \\      writable: true, configurable: true, enumerable: true
    \\    });
    \\  }
    \\  // CacheStorage / caches stub
    \\  if (typeof caches === 'undefined') {
    \\    Object.defineProperty(window, 'caches', {
    \\      value: {
    \\        open: function() { return Promise.resolve({ match: function() { return Promise.resolve(undefined); }, put: function() { return Promise.resolve(); }, delete: function() { return Promise.resolve(true); }, keys: function() { return Promise.resolve([]); } }); },
    \\        has: function() { return Promise.resolve(false); },
    \\        delete: function() { return Promise.resolve(true); },
    \\        keys: function() { return Promise.resolve([]); },
    \\        match: function() { return Promise.resolve(undefined); }
    \\      },
    \\      writable: true, configurable: true, enumerable: true
    \\    });
    \\  }
    \\  // BroadcastChannel stub
    \\  if (typeof BroadcastChannel === 'undefined') {
    \\    window.BroadcastChannel = function(name) {
    \\      this.name = name;
    \\      this.onmessage = null;
    \\      this.onmessageerror = null;
    \\    };
    \\    window.BroadcastChannel.prototype.postMessage = function() {};
    \\    window.BroadcastChannel.prototype.close = function() {};
    \\    window.BroadcastChannel.prototype.addEventListener = function() {};
    \\    window.BroadcastChannel.prototype.removeEventListener = function() {};
    \\  }
    \\  // ServiceWorker container stub
    \\  if (typeof navigator.serviceWorker === 'undefined') {
    \\    try {
    \\      Object.defineProperty(navigator, 'serviceWorker', {
    \\        value: {
    \\          register: function() { return Promise.reject(new Error('SecurityError')); },
    \\          getRegistration: function() { return Promise.resolve(undefined); },
    \\          getRegistrations: function() { return Promise.resolve([]); },
    \\          ready: Promise.resolve(null),
    \\          controller: null,
    \\          oncontrollerchange: null,
    \\          onmessage: null,
    \\          addEventListener: function() {}, removeEventListener: function() {}
    \\        },
    \\        writable: true, configurable: true, enumerable: true
    \\      });
    \\    } catch(e) {}
    \\  }
    \\})();
    // Parent-side: track Turnstile challenge events + extraParams data
    \\if (window === window.top) {
    \\  window.addEventListener('message', function(e) {
    \\    if (e.data && typeof e.data === 'object' && e.data.event && e.data.source === 'cloudflare-challenge') {
    \\      if (e.data.event !== 'meow' && e.data.event !== 'food') {
    \\        var extra = '';
    \\        if (e.data.event === 'fail' || e.data.event === 'turnstileResults') {
    \\          extra = ' code=' + (e.data.code || 'none');
    \\          extra += ' cfChlOut=' + String(e.data.cfChlOut || '').substring(0,40);
    \\        }
    \\        if (e.data.event === 'requestExtraParams' && e.data.wPr) {
    \\          try {
    \\            var wp = JSON.stringify(e.data.wPr);
    \\            console.warn('PAR_WPR: ' + wp.substring(0,120));
    \\            console.warn('PAR_WPR2: ' + wp.substring(120,240));
    \\          } catch(ex) {}
    \\        }
    \\        if (e.data.event === 'fail') console.warn('RESULT_FAIL: ' + (e.data.code || 'none'));
    \\        if (e.data.event === 'turnstileResults') console.warn('RESULT_OK: token=' + String(e.data.token || '').substring(0,30));
    \\        console.warn('PAR_IN: ' + e.data.event + extra);
    \\      }
    \\    }
    \\  });
    \\}
    // Iframe instrumentation
    \\if (window !== window.top) {
    \\  // Capture extraParams fingerprint data from parent
    \\  window.addEventListener('message', function(e) {
    \\    if (e.data && typeof e.data === 'object' && e.data.event === 'extraParams' && e.data.wPr) {
    \\      try {
    \\        var wp = JSON.stringify(e.data.wPr);
    \\        // Output in 120-char chunks
    \\        for (var ci = 0; ci < wp.length; ci += 120) {
    \\          console.warn('WPR' + Math.floor(ci/120) + ': ' + wp.substring(ci, ci+120));
    \\        }
    \\        console.warn('WPR_LEN: ' + wp.length);
    \\        // Also log the top-level keys
    \\        console.warn('WPR_KEYS: ' + Object.keys(e.data.wPr).join(','));
    \\      } catch(ex) { console.warn('WPR_ERR: ' + ex.message); }
    \\    }
    \\  });
    \\  // Accelerate 500ms VM processing timers to 100ms
    \\  (function() {
    \\    var origST = window.setTimeout;
    \\    window.setTimeout = function(fn, ms) {
    \\      if (ms >= 490 && ms <= 510) {
    \\        return origST.call(null, fn, 100);
    \\      }
    \\      return origST.apply(null, arguments);
    \\    };
    \\  })();
    \\  // Track JS errors that V8 catches internally
    \\  window.addEventListener('error', function(e) {
    \\    console.warn('IF_ERR: ' + (e.message || '') + ' at ' + (e.filename || '').slice(-40) + ':' + e.lineno);
    \\  });
    \\  window.addEventListener('unhandledrejection', function(e) {
    \\    var r = e.reason || {};
    \\    var msg = r.message || String(r);
    \\    var stack = r.stack ? r.stack.split('\n').slice(0,3).join(' | ') : '';
    \\    console.warn('IF_REJ: ' + msg.substring(0, 60) + ' STACK: ' + stack.substring(0,80));
    \\  });
    \\  // Suppress overrunBegin (our POW slightly slower than real Workers)
    \\  try {
    \\    var _pmOrig = window.parent.postMessage.bind(window.parent);
    \\    window.parent.postMessage = function(msg, origin) {
    \\      if (msg && typeof msg === 'object' && msg.event === 'overrunBegin') return;
    \\      return _pmOrig(msg, origin);
    \\    };
    \\  } catch(e) {}
    \\  // XHR tracking
    \\  var _origXHRSend = XMLHttpRequest.prototype.send;
    \\  var _origXHROpen = XMLHttpRequest.prototype.open;
    \\  XMLHttpRequest.prototype.open = function(m, u) { this._stUrl = u; this._stMethod = m; return _origXHROpen.apply(this, arguments); };
    \\  var _origSetHdr = XMLHttpRequest.prototype.setRequestHeader;
    \\  XMLHttpRequest.prototype.setRequestHeader = function(name, val) {
    \\    if (name === 'cf-chl-ra' || name === 'cf-chl') {
    \\      this['_h_' + name] = val;
    \\    }
    \\    return _origSetHdr.apply(this, arguments);
    \\  };
    \\  var _xhrFlowCount = 0;
    \\  var _flowStartTime = Date.now();
    \\  XMLHttpRequest.prototype.send = function(body) {
    \\    // Track ALL challenge-related XHR requests
    \\    if (this._stUrl && (this._stUrl.indexOf('/ov1') >= 0 || this._stUrl.indexOf('challenge') >= 0 || this._stUrl.indexOf('cdn-cgi') >= 0)) {
    \\      _xhrFlowCount++;
    \\      var flowNum = _xhrFlowCount;
    \\      var elapsed = Date.now() - _flowStartTime;
    \\      var urlEnd = (this._stUrl || '').split('/').slice(-2).join('/');
    \\      var bodyStr = (typeof body === 'string') ? body : '';
    \\      var ra = this['_h_cf-chl-ra'];
    \\      console.warn('IF_BODY: f=' + flowNum + ' t=' + elapsed + 'ms len=' + bodyStr.length + ' method=' + this._stMethod + ' ra=' + ra);
    \\      var xhr = this;
    \\      xhr.addEventListener('load', function() {
    \\        var rsp = xhr.responseText || '';
    \\        var elapsed2 = Date.now() - _flowStartTime;
    \\        var rspBody = rsp.length <= 50 ? rsp : rsp.substring(0,50);
    \\        var allHdrs = (xhr.getAllResponseHeaders() || '').replace(/\r?\n/g, ' | ');
    \\        if (flowNum <= 1) {
    \\          var chlGen = xhr.getResponseHeader('cf-chl-gen');
    \\          console.warn('CHL_GEN: len=' + (chlGen ? chlGen.length : 'null'));
    \\        }
    \\        if (xhr.status >= 400) { console.warn('FAIL_HDRS: ' + allHdrs); }
    \\        allHdrs = allHdrs.substring(0, 200);
    \\        console.warn('IF_RSP: f=' + flowNum + ' t=' + elapsed2 + 'ms s=' + xhr.status + ' len=' + rsp.length + ' body=' + rspBody + ' hdrs=' + allHdrs);
    \\      });
    \\    }
    \\    return _origXHRSend.apply(this, arguments);
    \\  };
    \\}
    \\
    // Fix performance.timing — all timestamps should be realistic Unix timestamps
    \\(function() {
    \\  try {
    \\    var t = performance.timing;
    \\    var now = Date.now();
    \\    var offsets = {
    \\      navigationStart: 0, unloadEventStart: 0, unloadEventEnd: 0,
    \\      redirectStart: 0, redirectEnd: 0, fetchStart: 1,
    \\      domainLookupStart: 5, domainLookupEnd: 15,
    \\      connectStart: 15, connectEnd: 50, secureConnectionStart: 20,
    \\      requestStart: 50, responseStart: 100, responseEnd: 150,
    \\      domLoading: 160, domInteractive: 200,
    \\      domContentLoadedEventStart: 200, domContentLoadedEventEnd: 210,
    \\      domComplete: 300, loadEventStart: 300, loadEventEnd: 310
    \\    };
    \\    Object.keys(offsets).forEach(function(key) {
    \\      var val = offsets[key] === 0 && key !== 'navigationStart' ? 0 : now - 500 + offsets[key];
    \\      try { Object.defineProperty(t, key, {value: val, writable: true, configurable: true}); } catch(e) {}
    \\    });
    \\  } catch(e) {}
    \\})();
    \\
    // Lock navigator.webdriver to false
    \\Object.defineProperty(navigator, 'webdriver', {
    \\  get: () => false, configurable: false, enumerable: true
    \\});
    // Override getBattery to return a proper BatteryManager stub
    // Chrome always resolves getBattery() — rejection is a detection vector
    \\navigator.getBattery = function() {
    \\  return Promise.resolve({
    \\    charging: true, chargingTime: 0, dischargingTime: Infinity, level: 1,
    \\    addEventListener: function() {}, removeEventListener: function() {},
    \\    onchargingchange: null, onchargingtimechange: null,
    \\    ondischargingtimechange: null, onlevelchange: null
    \\  });
    \\};
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
    \\    connect: function() { return {onMessage:{addListener:function(){}},onDisconnect:{addListener:function(){}},postMessage:function(){}}; },
    \\    sendMessage: function() {},
    \\    onMessage: { addListener: function() {}, removeListener: function() {} },
    \\    onConnect: { addListener: function() {}, removeListener: function() {} },
    \\  };
    \\}
    \\if (!window.chrome.app) {
    \\  window.chrome.app = {isInstalled:false,getDetails:function(){return null},getIsInstalled:function(){return false},installState:function(){return'disabled'},runningState:function(){return'cannot_run'}};
    \\}
    \\if (!window.chrome.csi) window.chrome.csi = function() { return {startE:Date.now(),onloadT:Date.now(),pageT:0,tran:15}; };
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
    // makeNative — just a no-op now, Function.prototype.toString not patched
    // Patching toString was suspicious — CF may detect non-standard toString behavior
    \\function makeNative() {}
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
    // Key optimization: intercept createObjectURL to pre-cache blob content,
    // avoiding async fetch() when Worker is created.
    \\(function() {
    \\  var _blobCache = {};
    \\  var _origCreateObjectURL = URL.createObjectURL;
    \\  URL.createObjectURL = function(blob) {
    \\    var url = _origCreateObjectURL.call(URL, blob);
    \\    // Synchronously cache blob text content for instant Worker loading
    \\    if (blob && blob._textContent) {
    \\      _blobCache[url] = blob._textContent;
    \\    }
    \\    return url;
    \\  };
    \\  var _origBlob = window.Blob;
    \\  window.Blob = function(parts, options) {
    \\    var blob = new _origBlob(parts, options);
    \\    try {
    \\      if (parts && parts.length > 0 && typeof parts[0] === 'string') {
    \\        blob._textContent = parts.join('');
    \\      }
    \\    } catch(e) {}
    \\    return blob;
    \\  };
    \\  window.Blob.prototype = _origBlob.prototype;
    \\  Object.defineProperty(window.Blob, 'name', {value: 'Blob'});
    \\  var _origWorker = window.Worker;
    \\  window.Worker = function(url) {
    \\    var _code = null, _msgHandler = null;
    \\    var worker = {
    \\      onmessage: null, onerror: null,
    \\      _listeners: {},
    \\      postMessage: function(data) {
    \\        if (!_code) {
    \\          _pmRetries++;
    \\          if (_pmRetries <= 5) {
    \\            setTimeout(function() { worker.postMessage(data); }, 10);
    \\          }
    \\          return;
    \\        }
    \\        try {
    \\          var scope = { postMessage: function(msg) {
    \\            // Deliver worker→main messages ASYNCHRONOUSLY to match real Worker behavior
    \\            // Real Workers deliver messages via event loop, not synchronously
    \\            setTimeout(function() {
    \\              var ev = {data: msg, isTrusted: true, origin: '', source: null, type: 'message',
    \\                     ports: [], lastEventId: '', preventDefault: function(){}, stopPropagation: function(){},
    \\                     stopImmediatePropagation: function(){}};
    \\              if (worker.onmessage) worker.onmessage(ev);
    \\              (worker._listeners['message'] || []).forEach(function(fn) { fn(ev); });
    \\            }, 0);
    \\          }, addEventListener: function(t, fn) { if (t === 'message') _msgHandler = fn; },
    \\          removeEventListener: function() {}, close: function() {},
    \\          importScripts: function() {},
    \\          crypto: window.crypto, performance: window.performance,
    \\          // Keep Worker setTimeout natural — don't accelerate
    \\          setTimeout: setTimeout,
    \\          Math: Math, Uint8Array: Uint8Array, Uint32Array: Uint32Array,
    \\          Int32Array: Int32Array, Float64Array: Float64Array,
    \\          ArrayBuffer: ArrayBuffer, DataView: DataView,
    \\          TextEncoder: TextEncoder, TextDecoder: TextDecoder,
    \\          atob: window.atob, btoa: window.btoa,
    \\          console: console, setInterval: setInterval,
    \\          clearTimeout: clearTimeout, clearInterval: clearInterval };
    \\          scope.self = scope; scope.globalThis = scope;
    \\          scope.onmessage = null; scope.onerror = null;
    \\          scope.navigator = window.navigator;
    \\          scope.location = {href: '', origin: '', protocol: 'https:'};
    \\          scope.String = String; scope.Number = Number; scope.Object = Object;
    \\          scope.Array = Array; scope.JSON = JSON; scope.Date = Date;
    \\          scope.Error = Error; scope.TypeError = TypeError;
    \\          scope.Promise = Promise; scope.Map = Map; scope.Set = Set;
    \\          scope.Blob = Blob; scope.Response = Response;
    \\          scope.fetch = fetch; scope.Request = Request;
    \\          scope.URL = URL; scope.URLSearchParams = URLSearchParams;
    \\          scope.Headers = typeof Headers !== 'undefined' ? Headers : undefined;
    \\          // Wrap code in with(self) so onmessage= assigns to scope
    \\          var wrappedCode = 'with(self){' + _code + '}';
    \\          var fn = new Function('self','postMessage','addEventListener',
    \\            'removeEventListener','close','importScripts',
    \\            'crypto','performance','Math',
    \\            'Uint8Array','Uint32Array','Int32Array','Float64Array',
    \\            'ArrayBuffer','DataView','TextEncoder','TextDecoder',
    \\            'atob','btoa','console','setTimeout','setInterval',
    \\            'clearTimeout','clearInterval','globalThis', wrappedCode);
    \\          fn(scope,scope.postMessage,scope.addEventListener,
    \\            scope.removeEventListener,scope.close,scope.importScripts,
    \\            window.crypto,window.performance,Math,
    \\            Uint8Array,Uint32Array,Int32Array,Float64Array,
    \\            ArrayBuffer,DataView,TextEncoder,TextDecoder,
    \\            window.atob,window.btoa,console,setTimeout,setInterval,
    \\            clearTimeout,clearInterval,scope);
    \\          // Deliver main→worker message synchronously
    \\          var handler = _msgHandler || scope.onmessage;
    \\          if (handler) {
    \\            // Log the eval'd code for POW analysis
    \\            if (typeof data === 'string' && data.length > 50) {
    \\              console.warn('IF_WK_EVAL: len=' + data.length + ' code=' + data.substring(0,120));
    \\            }
    \\            var mev = {data: data, isTrusted: true, origin: '', source: null, type: 'message',
    \\                     ports: [], lastEventId: '', preventDefault: function(){}, stopPropagation: function(){},
    \\                     stopImmediatePropagation: function(){}};
    \\            handler(mev);
    \\          }
    \\        } catch(e) {
    \\          console.warn('IF_WORKER: code ERROR ' + (e.message || e).substring(0, 60));
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
    \\      // Try cached blob content first (instant)
    \\      if (_blobCache[url]) {
    \\        _code = _blobCache[url];
    \\        if (_code.length > 13 && _code.length <= 200) {
    \\          console.warn('IF_WK_CODE: ' + _code);
    \\        }
    \\      } else {
    \\        // Fallback to fetch
    \\        fetch(url).then(function(r) { return r.text(); }).then(function(code) {
    \\          _code = code;
    \\          if (_code.length > 13 && _code.length <= 200) {
    \\            console.warn('IF_WK_CODE: ' + _code);
    \\          }
    \\        }).catch(function() {});
    \\      }
    \\    }
    \\    return worker;
    \\  };
    \\})();
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
    \\    stubMethod('createOscillator', function() {
    \\      var n = Object.create(noopNode);
    \\      n.type = 'sine';
    \\      n.frequency = { value: 440, setValueAtTime: function(){}, linearRampToValueAtTime: function(){},
    \\        exponentialRampToValueAtTime: function(){}, setTargetAtTime: function(){},
    \\        cancelScheduledValues: function(){}, defaultValue: 440, minValue: -22050, maxValue: 22050 };
    \\      n.detune = { value: 0, setValueAtTime: function(){}, defaultValue: 0, minValue: -153600, maxValue: 153600 };
    \\      return n;
    \\    });
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
    \\    stubMethod('createBuffer', function(channels, length, sampleRate) {
    \\      return {
    \\        length: length, sampleRate: sampleRate, numberOfChannels: channels, duration: length / sampleRate,
    \\        getChannelData: function() { return new Float32Array(length); },
    \\        copyFromChannel: function() {}, copyToChannel: function() {}
    \\      };
    \\    });
    \\    if (!('destination' in proto)) {
    \\      Object.defineProperty(proto, 'destination', {
    \\        get: function() { return Object.create(noopNode); }, configurable: true
    \\      });
    \\    }
    \\    window.webkitAudioContext = AudioContext;
    \\  }
    \\  // OfflineAudioContext — used for audio fingerprinting
    \\  if (typeof OfflineAudioContext !== 'function' || !OfflineAudioContext.prototype.startRendering) {
    \\    window.OfflineAudioContext = function(channels, length, sampleRate) {
    \\      this.sampleRate = sampleRate || 44100;
    \\      this.length = length || 44100;
    \\      this.numberOfChannels = channels || 1;
    \\      this.state = 'suspended';
    \\      this.currentTime = 0;
    \\    };
    \\    var oacProto = OfflineAudioContext.prototype;
    \\    // Inherit AudioContext methods
    \\    if (typeof AudioContext === 'function') {
    \\      var acProto = AudioContext.prototype;
    \\      ['createOscillator','createGain','createAnalyser','createBiquadFilter',
    \\       'createDynamicsCompressor','createScriptProcessor','createBufferSource',
    \\       'createBuffer'].forEach(function(m) {
    \\        if (acProto[m]) oacProto[m] = acProto[m];
    \\      });
    \\      Object.defineProperty(oacProto, 'destination', Object.getOwnPropertyDescriptor(acProto, 'destination') || {
    \\        get: function() { return { channelCount: 1, maxChannelCount: 1 }; }
    \\      });
    \\    }
    \\    oacProto.startRendering = function() {
    \\      var self = this;
    \\      self.state = 'running';
    \\      return new Promise(function(resolve) {
    \\        setTimeout(function() {
    \\          self.state = 'closed';
    \\          // Create a fake AudioBuffer with deterministic data
    \\          var buf = { length: self.length, sampleRate: self.sampleRate, numberOfChannels: self.numberOfChannels,
    \\            duration: self.length / self.sampleRate,
    \\            getChannelData: function(ch) {
    \\              var data = new Float32Array(self.length);
    \\              // Fill with deterministic non-zero values (like a real audio render)
    \\              for (var i = 0; i < data.length; i++) {
    \\                data[i] = Math.sin(i * 0.01) * 0.0001;
    \\              }
    \\              return data;
    \\            },
    \\            copyFromChannel: function(dest, ch) {
    \\              var src = this.getChannelData(ch);
    \\              for (var i = 0; i < Math.min(dest.length, src.length); i++) dest[i] = src[i];
    \\            }
    \\          };
    \\          if (self.oncomplete) self.oncomplete({renderedBuffer: buf});
    \\          resolve(buf);
    \\        }, 1);
    \\      });
    \\    };
    \\    oacProto.resume = function() { this.state = 'running'; return Promise.resolve(); };
    \\    oacProto.suspend = function() { this.state = 'suspended'; return Promise.resolve(); };
    \\    oacProto.close = function() { this.state = 'closed'; return Promise.resolve(); };
    \\    oacProto.addEventListener = function() {};
    \\    oacProto.removeEventListener = function() {};
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
    \\
    \\// Chrome property stubs for fingerprint detection bypass
    \\(function(){
    \\  // Event handlers that Chrome's window has but we don't
    \\  'onabort,onafterprint,onanimationend,onanimationiteration,onanimationstart,onauxclick,onbeforeinput,onbeforeprint,onbeforeunload,onblur,oncancel,oncanplay,oncanplaythrough,onchange,onclick,onclose,oncontentvisibilityautostatechange,oncontextlost,oncontextmenu,oncontextrestored,oncuechange,ondblclick,ondrag,ondragend,ondragenter,ondragleave,ondragover,ondragstart,ondrop,ondurationchange,onemptied,onended,onfocus,onformdata,ongotpointercapture,onhashchange,oninput,oninvalid,onkeydown,onkeypress,onkeyup,onlanguagechange,onloadeddata,onloadedmetadata,onloadstart,onlostpointercapture,onmessageerror,onmousedown,onmouseenter,onmouseleave,onmousemove,onmouseout,onmouseover,onmouseup,onoffline,ononline,onpagehide,onpaste,onpause,onplay,onplaying,onpointercancel,onpointerdown,onpointerenter,onpointerleave,onpointermove,onpointerout,onpointerover,onpointerup,onprogress,onratechange,onreset,onresize,onscroll,onscrollend,onsearch,onsecuritypolicyviolation,onseeked,onseeking,onselect,onselectionchange,onselectstart,onslotchange,onstalled,onstorage,onsubmit,onsuspend,ontimeupdate,ontoggle,ontouchcancel,ontouchend,ontouchmove,ontouchstart,ontransitioncancel,ontransitionend,ontransitionrun,ontransitionstart,onunload,onvolumechange,onwaiting,onwebkitanimationend,onwebkitanimationiteration,onwebkitanimationstart,onwebkittransitionend,onwheel'.split(',').forEach(function(n){
    \\    if(!(n in window))try{Object.defineProperty(window,n,{value:null,writable:true,configurable:true,enumerable:true})}catch(e){}
    \\  });
    \\  // Chrome global constructors — create Illegal constructor stubs
    \\  var _mkCtor = function(name){
    \\    var F = function(){throw new TypeError('Illegal constructor')};
    \\    Object.defineProperty(F,'name',{value:name,configurable:true});
    \\    F.prototype = Object.create(null);
    \\    F.prototype.constructor = F;
    \\    try{Object.defineProperty(F.prototype,Symbol.toStringTag,{value:name,configurable:true})}catch(e){}
    \\    return F;
    \\  };
    \\  // Only the constructors CF actually probes for (from unknown_prop log)
    \\  'CSSKeywordValue,CSSPositionTryDescriptors,CSSStyleValue,CSSTransformValue,CSSUnitValue,CSSUnparsedValue,VirtualKeyboardGeometryChangeEvent,MIDIOutputMap,MIDIInputMap,RTCRtpScriptTransform,AudioWorkletNode,AudioContext,OfflineAudioContext,AudioBuffer,AudioBufferSourceNode,GainNode,OscillatorNode,AnalyserNode,BiquadFilterNode,ChannelMergerNode,ChannelSplitterNode,ConvolverNode,DelayNode,DynamicsCompressorNode,WaveShaperNode,PannerNode,StereoPannerNode,AnimationEvent,TransitionEvent,ClipboardEvent,PointerEvent,InputEvent,CompositionEvent,DragEvent,FocusEvent,FormDataEvent,GamepadEvent,KeyboardEvent,MouseEvent,ProgressEvent,SubmitEvent,TouchEvent,WheelEvent,UIEvent,SecurityPolicyViolationEvent,PromiseRejectionEvent,PageTransitionEvent,HashChangeEvent,BeforeUnloadEvent,MediaQueryListEvent,PopStateEvent,StorageEvent,BroadcastChannel,MessageChannel,MessagePort,Notification,RTCPeerConnection,RTCSessionDescription,RTCIceCandidate,RTCDataChannel,MediaStream,MediaStreamTrack,MediaRecorder,ImageBitmap,IntersectionObserver,IntersectionObserverEntry,ResizeObserver,ResizeObserverEntry,MutationRecord,PerformanceObserverEntryList,Clipboard,ClipboardItem,FileReader,FileList,Geolocation,Lock,LockManager,Credential,CredentialsContainer,Gamepad,GamepadButton,GamepadHapticActuator'.split(',').forEach(function(n){
    \\    if(!(n in window))try{window[n]=_mkCtor(n)}catch(e){}
    \\  });
    \\  // Navigator stubs
    \\  var navStubs = {bluetooth:{},clipboard:{readText:function(){return Promise.resolve('')},writeText:function(){return Promise.resolve()}},connection:{effectiveType:'4g',downlink:10,rtt:50,saveData:false,type:'wifi'},credentials:{get:function(){return Promise.resolve(null)},create:function(){return Promise.resolve(null)},store:function(){return Promise.resolve()}},geolocation:{getCurrentPosition:function(){},watchPosition:function(){return 0},clearWatch:function(){}},locks:{request:function(){return Promise.resolve()},query:function(){return Promise.resolve({held:[],pending:[]})}},mediaCapabilities:{decodingInfo:function(){return Promise.resolve({supported:true,smooth:true,powerEfficient:true})}},mediaSession:{setActionHandler:function(){},metadata:null,playbackState:'none'},permissions:{query:function(){return Promise.resolve({state:'prompt'})}},storage:{estimate:function(){return Promise.resolve({usage:0,quota:1073741824})}},usb:{getDevices:function(){return Promise.resolve([])},requestDevice:function(){return Promise.reject(new DOMException('','NotFoundError'))}},serial:{getPorts:function(){return Promise.resolve([])}},hid:{getDevices:function(){return Promise.resolve([])}},gpu:undefined,ink:undefined,keyboard:{lock:function(){return Promise.resolve()},unlock:function(){}},wakeLock:{request:function(){return Promise.reject(new DOMException('','NotAllowedError'))}},pdfViewerEnabled:true,doNotTrack:null,maxTouchPoints:0,webdriver:false,scheduling:{isInputPending:function(){return false}},userActivation:{hasBeenActive:false,isActive:false}};
    \\  Object.keys(navStubs).forEach(function(k){
    \\    if(!(k in navigator))try{Object.defineProperty(navigator,k,{value:navStubs[k],configurable:true,enumerable:true})}catch(e){}
    \\  });
    \\  // Document property stubs
    \\  var docStubs = {fullscreen:false,fullscreenElement:null,fullscreenEnabled:true,pictureInPictureElement:null,pictureInPictureEnabled:true,onvisibilitychange:null,onselectstart:null,onselectionchange:null,onfullscreenchange:null,onfullscreenerror:null,onpointerlockchange:null,onpointerlockerror:null,wasDiscarded:false,featurePolicy:{allowsFeature:function(){return true},features:function(){return[]},allowedFeatures:function(){return[]}}};
    \\  Object.keys(docStubs).forEach(function(k){
    \\    if(!(k in document))try{Object.defineProperty(document,k,{value:docStubs[k],writable:true,configurable:true,enumerable:true})}catch(e){}
    \\  });
    \\  // Chrome object
    \\  if(!window.chrome)window.chrome={app:{isInstalled:false,getDetails:function(){return null},getIsInstalled:function(){return false},installState:function(){return'disabled'}},csi:function(){return{startE:Date.now(),onloadT:Date.now(),pageT:Date.now()-performance.timing.navigationStart,tran:15}},loadTimes:function(){return{commitLoadTime:Date.now()/1000,connectionInfo:'h2',finishDocumentLoadTime:0,finishLoadTime:0,firstPaintAfterLoadTime:0,firstPaintTime:0,navigationType:'Other',npnNegotiatedProtocol:'h2',requestTime:Date.now()/1000-0.3,startLoadTime:Date.now()/1000-0.5,wasAlternateProtocolAvailable:false,wasFetchedViaSpdy:true,wasNpnNegotiated:true}},runtime:{connect:function(){return{onMessage:{addListener:function(){}},onDisconnect:{addListener:function(){}},postMessage:function(){}}},sendMessage:function(){}}};
    \\})();
;
