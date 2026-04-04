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
    // Log challenge metadata sizes
    \\if (window === window.top && window._cf_chl_opt) {
    \\  var o = window._cf_chl_opt;
    \\  console.warn('CF_OPT: md=' + (o.md||'').length + ' mdrd=' + (o.mdrd||'').length + ' cH=' + (o.cH||'').length + ' cType=' + o.cType + ' ver=' + o.cTplV);
    \\}
    // Parent-side: track errors and Turnstile events
    \\if (window === window.top) {
    \\  window.addEventListener('error', function(e) {
    \\    console.warn('PAR_ERR: ' + (e.message || '') + ' at ' + (e.filename || '').slice(-40) + ':' + e.lineno);
    \\  });
    \\  window.addEventListener('unhandledrejection', function(e) {
    \\    var r = e.reason || {};
    \\    console.warn('PAR_REJ: ' + (r.message || String(r)).substring(0, 80));
    \\  });
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
    \\        if (e.data.event === 'fail') {
    \\          console.warn('RESULT_FAIL: ' + (e.data.code || 'none'));
    \\        }
    \\        if (e.data.event === 'turnstileResults') console.warn('RESULT_OK: token=' + String(e.data.token || '').substring(0,30));
    \\        console.warn('PAR_IN: ' + e.data.event + extra);
    \\      }
    \\    }
    \\  });
    \\  // Track JSD/orchestrate fetch requests
    \\  var _origParFetch = window.fetch;
    \\  if (_origParFetch) {
    \\    window.fetch = function(input, init) {
    \\      var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
    \\      if (url.indexOf('cdn-cgi') >= 0 || url.indexOf('challenge') >= 0) {
    \\        var method = (init && init.method) || 'GET';
    \\        var bodyLen = (init && init.body) ? init.body.length || 0 : 0;
    \\        console.warn('PAR_FETCH: ' + method + ' ' + url.split('/').slice(-3).join('/') + ' body=' + bodyLen);
    \\      }
    \\      return _origParFetch.apply(this, arguments);
    \\    };
    \\  }
    \\  // Intercept ALL postMessage calls including to iframe contentWindows.
    \\  // The api.js calls Le.contentWindow.postMessage() which goes through
    \\  // the postMessage function on the iframe's Window object.
    \\  // We need to intercept at the prototype level AND wrap contentWindow.
    \\  try {
    \\    // Wrap HTMLIFrameElement.contentWindow to intercept postMessage on iframes
    \\    var _origCWDesc = Object.getOwnPropertyDescriptor(HTMLIFrameElement.prototype, 'contentWindow');
    \\    if (_origCWDesc && _origCWDesc.get) {
    \\      var _origCWGet = _origCWDesc.get;
    \\      Object.defineProperty(HTMLIFrameElement.prototype, 'contentWindow', {
    \\        get: function() {
    \\          var cw = _origCWGet.call(this);
    \\          if (cw && !cw._spWrapped) {
    \\            try {
    \\              var origPM = cw.postMessage;
    \\              cw.postMessage = function(msg, origin) {
    \\                if (msg && typeof msg === 'object' && msg.event === 'extraParams' && msg.source === 'cloudflare-challenge') {
    \\                  _fixExtraParams(msg);
    \\                }
    \\                return origPM.call(cw, msg, origin);
    \\              };
    \\              cw._spWrapped = true;
    \\            } catch(ex) {} // cross-origin may throw
    \\          }
    \\          return cw;
    \\        },
    \\        configurable: true
    \\      });
    \\    }
    \\  } catch(e) {}
    \\  function _fixExtraParams(msg) {
    \\      if (msg && typeof msg === 'object' && msg.event === 'extraParams' && msg.source === 'cloudflare-challenge') {
    \\        // Fix wPr widget position to match Chrome's CSS layout
    \\        // Chrome layout: Turnstile widget (300x65px) is typically in
    \\        // the content flow. getBoundingClientRect().top|right values
    \\        // depend on real CSS layout which we don't have.
    \\        if (msg.wPr && msg.wPr.pi) {
    \\          var iw = msg.wPr['w.iW'] || window.innerWidth || 800;
    \\          // Compute realistic position: widget centered-ish, below some content
    \\          // Chrome peet.ws: top=126.78125, right=792 (widget near right edge)
    \\          // The right value = left + width, Chrome uses full-width containers
    \\          var tl = msg.wPr.pi.tL || 15; // total element count
    \\          var wTop = 50 + tl * 4 + Math.random() * 30; // scale with content
    \\          var wRight = iw - 4 - Math.random() * 10; // near right edge (full-width parent)
    \\          msg.wPr.pi.wp = wTop.toFixed(5) + '|' + wRight.toFixed(0);
    \\        }
    \\        if (!msg.apiJsResourceTiming && msg.au) {
    \\          // Cross-origin resource timing: Chrome returns zeros for timing/size
    \\          // fields because challenges.cloudflare.com doesn't send
    \\          // Timing-Allow-Origin. Must match Chrome's exact format.
    \\          var st = performance.now() - Math.random() * 50 - 80;
    \\          if (st < 50) st = 50 + Math.random() * 100;
    \\          var dur = Math.random() * 40 + 60;
    \\          msg.apiJsResourceTiming = {
    \\            name: msg.au, entryType: 'resource', startTime: st,
    \\            duration: dur, initiatorType: 'script',
    \\            deliveryType: '', nextHopProtocol: '',
    \\            renderBlockingStatus: 'non-blocking', contentEncoding: '',
    \\            workerStart: 0, workerRouterEvaluationStart: 0,
    \\            workerCacheLookupStart: 0, workerMatchedSourceType: '',
    \\            workerFinalSourceType: '',
    \\            redirectStart: 0, redirectEnd: 0,
    \\            fetchStart: st,
    \\            domainLookupStart: 0, domainLookupEnd: 0,
    \\            connectStart: 0, connectEnd: 0, secureConnectionStart: 0,
    \\            requestStart: 0, responseStart: 0,
    \\            firstInterimResponseStart: 0, finalResponseHeadersStart: 0,
    \\            responseEnd: st + dur,
    \\            transferSize: 0, encodedBodySize: 0, decodedBodySize: 0,
    \\            responseStatus: 0, serverTiming: []
    \\          };
    \\          console.warn('AJRT_INJECTED');
    \\        }
    \\      }
    \\  }
    \\}
    // Iframe instrumentation
    \\if (window !== window.top) {
    \\  // Capture extraParams fingerprint data from parent
    \\  window.addEventListener('message', function(e) {
    \\    if (e.data && typeof e.data === 'object' && e.data.event === 'extraParams') {
    \\      try {
    \\        // Log ALL keys in the extraParams message (not just wPr)
    \\        var keys = Object.keys(e.data).sort().join(',');
    \\        console.warn('EXTRA_KEYS: ' + keys);
    \\        // Log specific timing and fingerprint fields
    \\        if (e.data.apiJsResourceTiming) console.warn('EXTRA_RT: ' + JSON.stringify(e.data.apiJsResourceTiming).substring(0,120));
    \\        if (e.data.chlPageData) console.warn('EXTRA_CPD: ' + JSON.stringify(e.data.chlPageData).substring(0,120));
    \\        if (e.data.ch) console.warn('EXTRA_CH: len=' + String(e.data.ch).length);
    \\        if (e.data.scs) console.warn('EXTRA_SCS: ' + JSON.stringify(e.data.scs).substring(0,120));
    \\        if (e.data.au) console.warn('EXTRA_AU: ' + JSON.stringify(e.data.au).substring(0,120));
    \\        if (e.data.wPr) {
    \\          // Fix widget position in wPr before Turnstile JS processes it
    \\          try {
    \\            if (e.data.wPr.pi) {
    \\              var oldWp = e.data.wPr.pi.wp;
    \\              var iw = e.data.wPr['w.iW'] || 800;
    \\              var tl = e.data.wPr.pi.tL || 15;
    \\              var wTop = 50 + tl * 4 + Math.random() * 30;
    \\              var wRight = iw - 4 - Math.random() * 10;
    \\              e.data.wPr.pi.wp = wTop.toFixed(5) + '|' + wRight.toFixed(0);
    \\              console.warn('WP_FIX: ' + oldWp + ' -> ' + e.data.wPr.pi.wp);
    \\            }
    \\          } catch(ex) { console.warn('WP_FIX_ERR: ' + ex.message); }
    \\          try { console.warn('EXTRA_WPR: ' + JSON.stringify(e.data.wPr)); } catch(ex) {}
    \\        }
    \\        if (e.data.apiJsResourceTiming) {
    \\          // Fix: ensure cross-origin format (zeros for timing/size)
    \\          var rt = e.data.apiJsResourceTiming;
    \\          if (rt.nextHopProtocol && rt.nextHopProtocol !== '') {
    \\            rt.nextHopProtocol = '';
    \\            rt.domainLookupStart = 0; rt.domainLookupEnd = 0;
    \\            rt.connectStart = 0; rt.connectEnd = 0; rt.secureConnectionStart = 0;
    \\            rt.requestStart = 0; rt.responseStart = 0;
    \\            rt.transferSize = 0; rt.encodedBodySize = 0; rt.decodedBodySize = 0;
    \\            rt.responseStatus = 0;
    \\            if (!rt.deliveryType) rt.deliveryType = '';
    \\            if (!rt.renderBlockingStatus) rt.renderBlockingStatus = 'non-blocking';
    \\            if (!rt.contentEncoding) rt.contentEncoding = '';
    \\          }
    \\          try { console.warn('EXTRA_AJRT: ' + JSON.stringify(rt).substring(0,200)); } catch(ex) {}
    \\        } else {
    \\          // Inject AJRT if completely missing
    \\          if (e.data.au) {
    \\            var st = performance.now() - Math.random() * 50 - 80;
    \\            if (st < 50) st = 50 + Math.random() * 100;
    \\            var dur = Math.random() * 40 + 60;
    \\            e.data.apiJsResourceTiming = {
    \\              name: e.data.au, entryType: 'resource', startTime: st,
    \\              duration: dur, initiatorType: 'script',
    \\              deliveryType: '', nextHopProtocol: '',
    \\              renderBlockingStatus: 'non-blocking', contentEncoding: '',
    \\              workerStart: 0, redirectStart: 0, redirectEnd: 0, fetchStart: st,
    \\              domainLookupStart: 0, domainLookupEnd: 0,
    \\              connectStart: 0, connectEnd: 0, secureConnectionStart: 0,
    \\              requestStart: 0, responseStart: 0, responseEnd: st + dur,
    \\              transferSize: 0, encodedBodySize: 0, decodedBodySize: 0,
    \\              responseStatus: 0, serverTiming: []
    \\            };
    \\          }
    \\          console.warn('EXTRA_AJRT: INJECTED at iframe level');
    \\        }
    \\        console.warn('EXTRA_TIMES: init=' + e.data.timeInitMs + ' params=' + e.data.timeParamsMs + ' render=' + e.data.timeRenderMs + ' extra=' + e.data.timeExtraParamsMs);
    \\      } catch(ex) { console.warn('EXTRA_ERR: ' + ex.message); }
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
    \\  // Document property stubs for iframe — applied early (before VM runs)
    \\  // These must be defined BEFORE the Chrome property stubs IIFE at the end
    \\  // because the IIFE checks if(!(k in document)) which would skip if already set.
    \\  var _iframeDocStubs = {
    \\    pictureInPictureEnabled: true, pictureInPictureElement: null,
    \\    fullscreenEnabled: true, fullscreen: false, fullscreenElement: null,
    \\    wasDiscarded: false, designMode: 'off',
    \\    onfullscreenchange: null, onfullscreenerror: null,
    \\    onpointerlockchange: null, onpointerlockerror: null,
    \\    onvisibilitychange: null, onselectstart: null, onselectionchange: null,
    \\    onfreeze: null, onresume: null, onprerenderingchange: null,
    \\    fragmentDirective: {},
    \\    featurePolicy: {allowsFeature:function(){return true},features:function(){return[]},allowedFeatures:function(){return[]}},
    \\    // Legacy HTMLDocument color properties (Chrome returns empty string)
    \\    alinkColor: '', bgColor: '', fgColor: '', linkColor: '', vlinkColor: ''
    \\  };
    \\  Object.keys(_iframeDocStubs).forEach(function(k) {
    \\    if (!(k in document)) {
    \\      try { Object.defineProperty(document, k, {value: _iframeDocStubs[k], writable: true, configurable: true, enumerable: true}); } catch(e) {}
    \\    }
    \\  });
    \\  window.addEventListener('error', function(e) {
    \\    if (_errCount <= 30) console.warn('IF_ERR: ' + (e.message||'') + ' at ' + (e.filename||'').slice(-30) + ':' + e.lineno);
    \\  });
    \\  window.addEventListener('unhandledrejection', function(e) {
    \\    var r = e.reason || {};
    \\    if (_errCount <= 30) console.warn('IF_REJ: ' + (r.message || String(r)).substring(0,60));
    \\  });
    \\  // Track property access failures via Proxy (for window and document)
    \\  // This catches the VM probing for APIs that don't exist
    \\  // Track canvas toDataURL calls to see CF's canvas fingerprint
    \\  try {
    \\    var _origToDataURL = HTMLCanvasElement.prototype.toDataURL;
    \\    var _canvasCalls = 0;
    \\    HTMLCanvasElement.prototype.toDataURL = function() {
    \\      var result = _origToDataURL.apply(this, arguments);
    \\      _canvasCalls++;
    \\      if (_canvasCalls <= 3) {
    \\        console.warn('CANVAS_FP: call=' + _canvasCalls + ' w=' + this.width + ' h=' + this.height + ' len=' + result.length + ' hash=' + result.substring(22,50));
    \\      }
    \\      return result;
    \\    };
    \\  } catch(e) {}
    \\  // Track WebGL getParameter calls to see what CF checks
    \\  try {
    \\    var _origGlGetParam = WebGLRenderingContext.prototype.getParameter;
    \\    if (_origGlGetParam) {
    \\      var _glCalls = 0;
    \\      WebGLRenderingContext.prototype.getParameter = function(pname) {
    \\        var result = _origGlGetParam.call(this, pname);
    \\        _glCalls++;
    \\        if (_glCalls <= 10) console.warn('GL: 0x' + pname.toString(16) + '=' + String(result).substring(0,30));
    \\        return result;
    \\      };
    \\    }
    \\  } catch(e) {}
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
    \\  XMLHttpRequest.prototype.open = function(m, u) {
    \\    this._stUrl = u; this._stMethod = m;
    \\    return _origXHROpen.apply(this, arguments);
    \\  };
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
    \\      var fullUrl = this._stUrl || '';
    \\      var urlType = fullUrl.indexOf('chl_api') >= 0 ? 'API' : 'FLOW';
    \\      console.warn('IF_XHR: ' + urlType + ' f=' + flowNum + ' t=' + elapsed + 'ms len=' + (body ? body.length : 0));
    \\      if (flowNum <= 8) console.warn('XHR_URL: ' + fullUrl.slice(-50));
    \\      // For chl_api_m requests, log the body to understand what VM checks fail
    \\      if (urlType === 'API' && body) {
    \\        console.warn('API_BODY: f=' + flowNum + ' ' + String(body).substring(0,200));
    \\      }
    \\      // Log full body of initial flow POST (3-4KB, base64-like)
    \\      if (urlType === 'FLOW' && flowNum === 1 && body && body.length > 1000) {
    \\        // Split body into chunks for logging
    \\        for (var bi = 0; bi < body.length && bi < 5000; bi += 200) {
    \\          console.warn('FLOW_B' + Math.floor(bi/200) + ': ' + body.substring(bi, bi+200));
    \\        }
    \\      }
    \\      if (false && urlType === 'FLOW' && flowNum === 1 && body && body.length > 3000) {
    \\        var chars = {};
    \\        for (var ci = 0; ci < body.length; ci++) chars[body[ci]] = 1;
    \\        var uniq = Object.keys(chars).sort().join('');
    \\        console.warn('OUR_BODY: len=' + body.length + ' unique=' + uniq.length + ' chars=' + uniq);
    \\        console.warn('OUR_BODY_START: ' + body.substring(0,60));
    \\        console.warn('OUR_BODY_END: ' + body.substring(body.length-60));
    \\      }
    \\      var xhr = this;
    \\      xhr.addEventListener('load', function() {
    \\        var rsp = xhr.responseText || '';
    \\        var elapsed2 = Date.now() - _flowStartTime;
    \\        var rspBody = rsp.length <= 50 ? rsp : rsp.substring(0,50);
    \\        // Simple hash of response for verification
    \\        var rspHash = 0;
    \\        for (var hi = 0; hi < rsp.length; hi++) {
    \\          rspHash = ((rspHash << 5) - rspHash + rsp.charCodeAt(hi)) | 0;
    \\        }
    \\        // Check for high bytes in response (Latin-1 encoding)
    \\        var rspHi = 0, rspMax = 0;
    \\        for (var ri = 0; ri < Math.min(rsp.length, 10000); ri++) {
    \\          var rc = rsp.charCodeAt(ri);
    \\          if (rc > 127) rspHi++;
    \\          if (rc > rspMax) rspMax = rc;
    \\        }
    \\        console.warn('IF_RSP: f=' + flowNum + ' t=' + elapsed2 + 'ms s=' + xhr.status + ' len=' + rsp.length + ' hi=' + rspHi + ' max=' + rspMax + ' hash=' + rspHash);
    \\        if (xhr.status >= 400) {
    \\          var allHdrs = (xhr.getAllResponseHeaders() || '').replace(/\r?\n/g, ' | ');
    \\          console.warn('FAIL_HDRS: ' + allHdrs);
    \\        }
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
    \\    // Add toJSON() — CF calls JSON.stringify(performance.timing)
    \\    if (!t.toJSON || typeof t.toJSON !== 'function') {
    \\      Object.defineProperty(t, 'toJSON', {value: function() {
    \\        var o = {};
    \\        var keys = ['navigationStart','unloadEventStart','unloadEventEnd','redirectStart','redirectEnd','fetchStart','domainLookupStart','domainLookupEnd','connectStart','secureConnectionStart','connectEnd','requestStart','responseStart','responseEnd','domLoading','domInteractive','domContentLoadedEventStart','domContentLoadedEventEnd','domComplete','loadEventStart','loadEventEnd'];
    \\        for (var i = 0; i < keys.length; i++) o[keys[i]] = this[keys[i]];
    \\        return o;
    \\      }, writable: true, configurable: true});
    \\    }
    \\  } catch(e) {}
    \\})();
    \\
    // PerformanceResourceTiming polyfill — CF Turnstile reads apiJsResourceTiming
    // from performance.getEntriesByType('resource'). Without real entries, CF
    // knows we're not a real browser. Intercept script/link loading to generate
    // synthetic resource timing entries.
    \\(function() {
    \\  var _resEntries = [];
    \\  var _navStart = performance.timeOrigin || Date.now();
    \\  var _origGetEntries = performance.getEntries.bind(performance);
    \\  var _origGetByType = performance.getEntriesByType.bind(performance);
    \\  var _origGetByName = performance.getEntriesByName.bind(performance);
    \\  // PerformanceResourceTiming constructor — needed for instanceof checks
    \\  // CF's api.js does: if (U(entry, PerformanceResourceTiming))
    \\  if (typeof PerformanceResourceTiming === 'undefined') {
    \\    window.PerformanceResourceTiming = function() { throw new TypeError('Illegal constructor'); };
    \\    // Use Symbol.hasInstance to make instanceof work on plain objects
    \\    // (Can't use Object.create(PerformanceEntry.prototype) because name/entryType are read-only accessors)
    \\    Object.defineProperty(PerformanceResourceTiming, Symbol.hasInstance, {
    \\      value: function(obj) { return obj && obj.entryType === 'resource'; }
    \\    });
    \\    Object.defineProperty(PerformanceResourceTiming.prototype, Symbol.toStringTag, {value: 'PerformanceResourceTiming', configurable: true});
    \\  }
    \\  var _PRT = null; // Don't set prototype — just use Symbol.hasInstance
    \\  function makeResEntry(url, startOff, dur, size, initiator) {
    \\    var st = performance.now() - startOff;
    \\    if (st < 0) st = Math.random() * 50 + 10;
    \\    // Cross-origin scripts: Chrome returns zeros for detailed timing/size
    \\    // because Timing-Allow-Origin header is not set by CF
    \\    var isCrossOrigin = false;
    \\    try {
    \\      var pageOrigin = location.origin || location.protocol + '//' + location.host;
    \\      isCrossOrigin = url.indexOf(pageOrigin) < 0 && url.indexOf('://') >= 0;
    \\    } catch(e) { isCrossOrigin = true; }
    \\    var rspEnd = st + dur;
    \\    var entry;
    \\    if (isCrossOrigin) {
    \\      entry = {
    \\        name: url, entryType: 'resource', startTime: st,
    \\        duration: dur, initiatorType: initiator || 'script',
    \\        deliveryType: '', nextHopProtocol: '',
    \\        renderBlockingStatus: 'non-blocking', contentEncoding: '',
    \\        workerStart: 0, workerRouterEvaluationStart: 0,
    \\        workerCacheLookupStart: 0, workerMatchedSourceType: '',
    \\        workerFinalSourceType: '',
    \\        redirectStart: 0, redirectEnd: 0, fetchStart: st,
    \\        domainLookupStart: 0, domainLookupEnd: 0,
    \\        connectStart: 0, connectEnd: 0, secureConnectionStart: 0,
    \\        requestStart: 0, responseStart: 0,
    \\        firstInterimResponseStart: 0, finalResponseHeadersStart: 0,
    \\        responseEnd: rspEnd,
    \\        transferSize: 0, encodedBodySize: 0, decodedBodySize: 0,
    \\        responseStatus: 0, serverTiming: [],
    \\        toJSON: function() { var o = {}; for (var k in this) if (typeof this[k] !== 'function') o[k] = this[k]; return o; }
    \\      };
    \\    } else {
    \\      var dns = st + Math.random() * 2;
    \\      var conn = dns + Math.random() * 5;
    \\      var ssl = conn + Math.random() * 10;
    \\      var reqSt = ssl + Math.random() * 2;
    \\      entry = {
    \\        name: url, entryType: 'resource', startTime: st,
    \\        duration: dur, initiatorType: initiator || 'script',
    \\        deliveryType: '', nextHopProtocol: 'h2',
    \\        renderBlockingStatus: 'non-blocking', contentEncoding: '',
    \\        workerStart: 0, workerRouterEvaluationStart: 0,
    \\        workerCacheLookupStart: 0, workerMatchedSourceType: '',
    \\        workerFinalSourceType: '',
    \\        redirectStart: 0, redirectEnd: 0, fetchStart: st,
    \\        domainLookupStart: dns, domainLookupEnd: dns + 1,
    \\        connectStart: conn, connectEnd: ssl, secureConnectionStart: conn + 1,
    \\        requestStart: reqSt, responseStart: reqSt + dur*0.3,
    \\        firstInterimResponseStart: 0, finalResponseHeadersStart: 0,
    \\        responseEnd: rspEnd,
    \\        transferSize: size || Math.floor(dur * 100 + 5000),
    \\        encodedBodySize: size ? Math.floor(size * 0.7) : Math.floor(dur * 70 + 3500),
    \\        decodedBodySize: size || Math.floor(dur * 100 + 5000),
    \\        responseStatus: 200, serverTiming: [],
    \\        toJSON: function() { var o = {}; for (var k in this) if (typeof this[k] !== 'function') o[k] = this[k]; return o; }
    \\      };
    \\    }
    \\    return entry;
    \\  }
    \\  // Observe script insertions to generate resource entries
    \\  var _origAppend = Element.prototype.appendChild;
    \\  Element.prototype.appendChild = function(child) {
    \\    var result = _origAppend.call(this, child);
    \\    try {
    \\      if (child.tagName === 'SCRIPT' && child.src) {
    \\        var url = child.src;
    \\        var t = performance.now();
    \\        child.addEventListener('load', function() {
    \\          var dur = performance.now() - t;
    \\          if (dur < 5) dur = Math.random() * 80 + 20;
    \\          _resEntries.push(makeResEntry(url, dur, dur, 0, 'script'));
    \\        });
    \\        child.addEventListener('error', function() {
    \\          _resEntries.push(makeResEntry(url, 50, 50, 0, 'script'));
    \\        });
    \\      } else if (child.tagName === 'LINK' && child.href) {
    \\        _resEntries.push(makeResEntry(child.href, 30, Math.random()*40+20, 0, 'link'));
    \\      }
    \\    } catch(e) {}
    \\    return result;
    \\  };
    \\  // Lazily scan existing DOM for parser-loaded resources on first query
    \\  var _scanned = false;
    \\  function _scanExistingResources() {
    \\    if (_scanned) return;
    \\    _scanned = true;
    \\    try {
    \\      var scripts = document.querySelectorAll('script[src]');
    \\      for (var i = 0; i < scripts.length; i++) {
    \\        var src = scripts[i].src;
    \\        if (src && !_resEntries.some(function(e) { return e.name === src; })) {
    \\          var dur = Math.random() * 120 + 30;
    \\          var st = Math.random() * 200 + 20;
    \\          _resEntries.push(makeResEntry(src, st, dur, 0, 'script'));
    \\        }
    \\      }
    \\      var links = document.querySelectorAll('link[href][rel=stylesheet]');
    \\      for (var j = 0; j < links.length; j++) {
    \\        var href = links[j].href;
    \\        if (href && !_resEntries.some(function(e) { return e.name === href; })) {
    \\          _resEntries.push(makeResEntry(href, Math.random()*150+40, Math.random()*60+20, 0, 'link'));
    \\        }
    \\      }
    \\    } catch(e) {}
    \\  }
    \\  // Also track fetch and XHR as resource entries
    \\  var _origFetch = window.fetch;
    \\  if (_origFetch) {
    \\    window.fetch = function(input, init) {
    \\      var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
    \\      var t = performance.now();
    \\      return _origFetch.apply(this, arguments).then(function(resp) {
    \\        var dur = performance.now() - t;
    \\        if (dur < 1) dur = Math.random() * 30 + 5;
    \\        _resEntries.push(makeResEntry(url, dur, dur, 0, 'fetch'));
    \\        return resp;
    \\      });
    \\    };
    \\  }
    \\  // Patch getEntriesByType to include resource entries
    \\  performance.getEntriesByType = function(type) {
    \\    var real = _origGetByType(type);
    \\    if (type === 'resource') {
    \\      _scanExistingResources();
    \\      var all = (real || []).concat(_resEntries);
    \\      // Ensure Turnstile api.js has a resource timing entry
    \\      // CF checks apiJsResourceTiming — undefined = bot signal
    \\      // The api.js filters entries by its own URL (y.scriptUrl)
    \\      var hasCF = false;
    \\      for (var ri = 0; ri < all.length; ri++) {
    \\        if (all[ri].name && (all[ri].name.indexOf('challenges.cloudflare.com') >= 0 || all[ri].name.indexOf('turnstile') >= 0)) {
    \\          hasCF = true; break;
    \\        }
    \\      }
    \\      if (!hasCF) {
    \\        // Look for the script in DOM
    \\        try {
    \\          var allScripts = document.getElementsByTagName('script');
    \\          for (var si = 0; si < allScripts.length; si++) {
    \\            var scriptSrc = allScripts[si].src || '';
    \\            if (scriptSrc.indexOf('challenges.cloudflare.com') >= 0 || scriptSrc.indexOf('turnstile') >= 0) {
    \\              all.push(makeResEntry(scriptSrc, 80 + Math.random()*120, 50 + Math.random()*80, 52567, 'script'));
    \\              hasCF = true;
    \\            }
    \\          }
    \\        } catch(e) {}
    \\      }
    \\      return all;
    \\    }
    \\    if (type === 'navigation') {
    \\      if (real && real.length > 0) return real;
    \\      // Return a synthetic PerformanceNavigationTiming entry
    \\      var now = performance.now();
    \\      return [{
    \\        name: location.href, entryType: 'navigation', startTime: 0,
    \\        duration: now, initiatorType: 'navigation',
    \\        nextHopProtocol: 'h2', workerStart: 0,
    \\        redirectStart: 0, redirectEnd: 0, redirectCount: 0,
    \\        fetchStart: 1, domainLookupStart: 5, domainLookupEnd: 10,
    \\        connectStart: 10, connectEnd: 40, secureConnectionStart: 15,
    \\        requestStart: 40, responseStart: 80, responseEnd: 120,
    \\        transferSize: 50000, encodedBodySize: 35000, decodedBodySize: 50000,
    \\        unloadEventStart: 0, unloadEventEnd: 0,
    \\        domInteractive: 200, domContentLoadedEventStart: 200,
    \\        domContentLoadedEventEnd: 210, domComplete: now - 50,
    \\        loadEventStart: now - 50, loadEventEnd: now - 40,
    \\        type: 'navigate', serverTiming: [],
    \\        toJSON: function() {
    \\          var o = {}; for (var k in this) if (typeof this[k] !== 'function') o[k] = this[k]; return o;
    \\        }
    \\      }];
    \\    }
    \\    return real;
    \\  };
    \\  performance.getEntries = function() {
    \\    _scanExistingResources();
    \\    return (_origGetEntries() || []).concat(_resEntries);
    \\  };
    \\  performance.getEntriesByName = function(name, type) {
    \\    _scanExistingResources();
    \\    var real = _origGetByName(name, type);
    \\    if (!type || type === 'resource') {
    \\      var matched = _resEntries.filter(function(e) { return e.name === name; });
    \\      return (real || []).concat(matched);
    \\    }
    \\    return real;
    \\  };
    \\})();
    \\
    // PerformanceObserver.supportedEntryTypes — Chrome returns a full list
    \\if (typeof PerformanceObserver !== 'undefined') {
    \\  Object.defineProperty(PerformanceObserver, 'supportedEntryTypes', {
    \\    get: function() { return ['element','event','first-input','largest-contentful-paint','layout-shift','long-animation-frame','longtask','mark','measure','navigation','paint','resource','visibility-state']; },
    \\    configurable: true
    \\  });
    \\  // Patch PerformanceObserver to support 'resource' type
    \\  // CF's api.js uses PerformanceObserver to find its own resource timing.
    \\  // Without this, apiJsResourceTiming=undefined (bot signal).
    \\  var _OrigPO = PerformanceObserver;
    \\  window.PerformanceObserver = function(callback) {
    \\    this._spCallback = callback;
    \\    try { _OrigPO.call(this, callback); } catch(e) {
    \\      this._spFallback = true;
    \\    }
    \\  };
    \\  window.PerformanceObserver.prototype = _OrigPO.prototype;
    \\  Object.defineProperty(window.PerformanceObserver, 'supportedEntryTypes', {
    \\    get: function() { return ['element','event','first-input','largest-contentful-paint','layout-shift','long-animation-frame','longtask','mark','measure','navigation','paint','resource','visibility-state']; },
    \\    configurable: true
    \\  });
    \\  var _origPOObserve = _OrigPO.prototype.observe;
    \\  _OrigPO.prototype.observe = function(options) {
    \\    var self = this;
    \\    try { _origPOObserve.call(this, options); } catch(e) {}
    \\    if (options && (options.type === 'resource' || (options.entryTypes && options.entryTypes.indexOf('resource') >= 0))) {
    \\      setTimeout(function() {
    \\        try {
    \\          var scripts = document.getElementsByTagName('script');
    \\          var entries = [];
    \\          for (var i = 0; i < scripts.length; i++) {
    \\            var src = scripts[i].src || '';
    \\            if (src.length > 0) {
    \\              var st = performance.now() - Math.random() * 100 - 30;
    \\              if (st < 30) st = 30 + Math.random() * 80;
    \\              var dur = Math.random() * 60 + 40;
    \\              // Cross-origin format: zeros for timing/size (no Timing-Allow-Origin)
    \\              entries.push({
    \\                name: src, entryType: 'resource', startTime: st,
    \\                duration: dur, initiatorType: 'script',
    \\                deliveryType: '', nextHopProtocol: '',
    \\                renderBlockingStatus: 'non-blocking', contentEncoding: '',
    \\                workerStart: 0, workerRouterEvaluationStart: 0,
    \\                workerCacheLookupStart: 0, workerMatchedSourceType: '',
    \\                workerFinalSourceType: '',
    \\                redirectStart: 0, redirectEnd: 0, fetchStart: st,
    \\                domainLookupStart: 0, domainLookupEnd: 0,
    \\                connectStart: 0, connectEnd: 0, secureConnectionStart: 0,
    \\                requestStart: 0, responseStart: 0,
    \\                firstInterimResponseStart: 0, finalResponseHeadersStart: 0,
    \\                responseEnd: st + dur,
    \\                transferSize: 0, encodedBodySize: 0, decodedBodySize: 0,
    \\                responseStatus: 0, serverTiming: [],
    \\                toJSON: function() { var o={}; for(var k in this) if(typeof this[k]!=='function') o[k]=this[k]; return o; }
    \\              });
    \\            }
    \\          }
    \\          if (entries.length > 0 && self._spCallback) {
    \\            var entryList = { getEntries: function() { return entries; }, getEntriesByType: function(t) { return entries.filter(function(e){return e.entryType===t}); }, getEntriesByName: function(n) { return entries.filter(function(e){return e.name===n}); } };
    \\            self._spCallback(entryList, self);
    \\          }
    \\        } catch(e) {}
    \\      }, 1);
    \\    }
    \\  };
    \\}
    \\
    // Lock navigator.webdriver to false (Chrome returns false when not under automation)
    \\Object.defineProperty(navigator, 'webdriver', {
    \\  get: () => false, configurable: true, enumerable: true
    \\});
    // Override getBattery to return a proper BatteryManager stub
    // Chrome always resolves getBattery() — rejection is a detection vector
    \\navigator.getBattery = function getBattery() {
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
    // Make our polyfilled functions appear as native code
    // CF's Turnstile API checks Worker.toString(), Blob.toString(), etc.
    // If they show JS source instead of [native code], CF classifies us as non-standard
    \\var _origToString = Function.prototype.toString;
    \\var _nativeMap = new WeakMap();
    \\function makeNative(fn, name) {
    \\  _nativeMap.set(fn, 'function ' + (name || fn.name || '') + '() { [native code] }');
    \\}
    \\Function.prototype.toString = function() {
    \\  if (_nativeMap.has(this)) return _nativeMap.get(this);
    \\  return _origToString.call(this);
    \\};
    \\makeNative(Function.prototype.toString, 'toString');
    // Don't expose makeNative on window — it's a detection vector
    \\var _mn = makeNative;
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
    \\  var _workerCount = 0;
    \\  window.Worker = function(url) {
    \\    _workerCount++;
    \\    var _wid = _workerCount;
    \\    var cached = _blobCache[url];
    \\    console.warn('WK_NEW: #' + _wid + ' cached=' + (cached ? cached.length : 'NO'));
    \\    if (cached && cached.length < 200) console.warn('WK_CODE: ' + cached);
    \\    var _code = null, _msgHandler = null;
    \\    var worker = {
    \\      onmessage: null, onerror: null,
    \\      _listeners: {},
    \\      postMessage: function(data) {
    \\        console.warn('WK#' + _wid + '_PM: code=' + (_code ? _code.length : 'null') + ' data=' + (typeof data === 'string' ? data.substring(0,60) : JSON.stringify(data).substring(0,60)));
    \\        if (!_code) {
    \\          _pmRetries++;
    \\          if (_pmRetries <= 5) {
    \\            setTimeout(function() { worker.postMessage(data); }, 10);
    \\          }
    \\          return;
    \\        }
    \\        console.warn('WK_PM_IN: ' + (typeof data === 'string' ? data.substring(0,60) : JSON.stringify(data).substring(0,60)));
    \\        try {
    \\          var scope = { postMessage: function(msg) {
    \\            var msgStr = JSON.stringify(msg).substring(0,80);
    \\            console.warn('WK_PM_OUT: ' + msgStr);
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
    \\          // Worker scope needs its own navigator with deviceMemory=8
    \\          // Can't use Object.create(window.navigator) because native
    \\          // getters throw "Illegal invocation" when called on proxy object.
    \\          // Must copy values directly.
    \\          var _nav = window.navigator;
    \\          scope.navigator = {
    \\            platform: _nav.platform, userAgent: _nav.userAgent,
    \\            appVersion: _nav.appVersion, vendor: _nav.vendor,
    \\            product: _nav.product, appName: _nav.appName,
    \\            appCodeName: _nav.appCodeName,
    \\            language: _nav.language, languages: _nav.languages,
    \\            onLine: _nav.onLine, cookieEnabled: _nav.cookieEnabled,
    \\            hardwareConcurrency: _nav.hardwareConcurrency,
    \\            maxTouchPoints: _nav.maxTouchPoints,
    \\            webdriver: _nav.webdriver,
    \\            deviceMemory: 8,
    \\            doNotTrack: _nav.doNotTrack,
    \\            globalPrivacyControl: _nav.globalPrivacyControl,
    \\            pdfViewerEnabled: _nav.pdfViewerEnabled,
    \\            connection: _nav.connection || {effectiveType:'4g',downlink:10,rtt:50},
    \\            userAgentData: _nav.userAgentData
    \\          };
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
    \\              console.warn('WK1: ' + data.substring(0,120));
    \\              if (data.length > 120) console.warn('WK2: ' + data.substring(120,240));
    \\            }
    \\            var mev = {data: data, isTrusted: true, origin: '', source: null, type: 'message',
    \\                     ports: [], lastEventId: '', preventDefault: function(){}, stopPropagation: function(){},
    \\                     stopImmediatePropagation: function(){}};
    \\            handler(mev);
    \\          }
    \\        } catch(e) {
    \\          console.warn('IF_WORKER: code ERROR ' + (e.message || e).substring(0, 80) + (e.stack ? ' STACK:' + e.stack.split('\n').slice(0,3).join('|') : ''));
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
    \\    // Make worker pass instanceof Worker check
    \\    try { Object.setPrototypeOf(worker, _origWorker.prototype); } catch(e) {}
    \\    worker.terminate = function() {};
    \\    worker.dispatchEvent = function() {};
    \\    return worker;
    \\  };
    \\  // Preserve Worker.prototype and constructor relationship
    \\  window.Worker.prototype = _origWorker.prototype;
    \\  Object.defineProperty(window.Worker, 'name', {value: 'Worker'});
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
    \\if (navigator.getBattery) makeNative(navigator.getBattery, 'getBattery');
    \\if (typeof URL.createObjectURL === 'function' && URL.createObjectURL.toString().indexOf('native') < 0) makeNative(URL.createObjectURL, 'createObjectURL');
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
    \\  // ALL Chrome 146 Window constructors — CF VM hashes all window properties
    \\  // to create a browser fingerprint. Missing 685+ constructors = wrong hash = bot.
    \\  'AbsoluteOrientationSensor,Accelerometer,AnimationEffect,AnimationEvent,AnimationPlaybackEvent,AnimationTimeline,AnimationTrigger,AudioBuffer,AudioBufferSourceNode,AudioData,AudioDecoder,AudioEncoder,AudioListener,AudioNode,AudioParamMap,AudioPlaybackStats,AudioProcessingEvent,AudioScheduledSourceNode,AudioSinkInfo,AudioWorklet,AudioWorkletNode,AuthenticatorAssertionResponse,AuthenticatorAttestationResponse,AuthenticatorResponse,BackgroundFetchManager,BackgroundFetchRecord,BackgroundFetchRegistration,BarProp,BatteryManager,BeforeInstallPromptEvent,BeforeUnloadEvent,BlobEvent,Bluetooth,BluetoothCharacteristicProperties,BluetoothDevice,BluetoothRemoteGATTCharacteristic,BluetoothRemoteGATTDescriptor,BluetoothRemoteGATTServer,BluetoothRemoteGATTService,BluetoothUUID,BroadcastChannel,BrowserCaptureMediaStreamTrack,ByteLengthQueuingStrategy,Cache,CacheStorage,CanvasCaptureMediaStreamTrack,CanvasPattern,CaptureController,CaretPosition,ChannelMergerNode,ChannelSplitterNode,ChapterInformation,CharacterBoundsUpdateEvent,Clipboard,ClipboardChangeEvent,ClipboardEvent,ClipboardItem,CloseEvent,CloseWatcher,CommandEvent,CompressionStream,ConstantSourceNode,ContentVisibilityAutoStateChangeEvent,ConvolverNode,CookieChangeEvent,CookieStore,CookieStoreManager,CountQueuingStrategy,CrashReportContext,CreateMonitor,Credential,CredentialsContainer,CropTarget,CSPViolationReportBody,CSSAnimation,CSSConditionRule,CSSContainerRule,CSSCounterStyleRule,CSSFontFaceRule,CSSFontFeatureValuesRule,CSSFontPaletteValuesRule,CSSFunctionDeclarations,CSSFunctionDescriptors,CSSFunctionRule,CSSGroupingRule,CSSImageValue,CSSImportRule,CSSKeyframeRule,CSSKeyframesRule,CSSKeywordValue,CSSLayerBlockRule,CSSLayerStatementRule,CSSMarginRule,CSSMathClamp,CSSMathInvert,CSSMathMax,CSSMathMin,CSSMathNegate,CSSMathProduct,CSSMathSum,CSSMathValue,CSSMatrixComponent,CSSMediaRule,CSSNamespaceRule,CSSNestedDeclarations,CSSNumericArray,CSSNumericValue,CSSPageRule,CSSPerspective,CSSPositionTryDescriptors,CSSPositionTryRule,CSSPositionValue,CSSPropertyRule,CSSRotate,CSSScale,CSSScopeRule,CSSSkew,CSSSkewX,CSSSkewY,CSSStartingStyleRule,CSSStyleValue,CSSSupportsRule,CSSTransformComponent,CSSTransformValue,CSSTransition,CSSTranslate,CSSUnitValue,CSSUnparsedValue,CSSVariableReferenceValue,CSSViewTransitionRule,CustomStateSet,DataTransfer,DataTransferItem,DataTransferItemList,DecompressionStream,DelayNode,DelegatedInkTrailPresenter,DeviceMotionEvent,DeviceMotionEventAcceleration,DeviceMotionEventRotationRate,DeviceOrientationEvent,DevicePosture,DigitalCredential,DocumentPictureInPicture,DocumentPictureInPictureEvent,DocumentTimeline,DOMError,DOMMatrix,DOMMatrixReadOnly,DOMPoint,DOMPointReadOnly,DOMQuad,DOMRectList,DOMRectReadOnly,DOMStringList,DragEvent,DynamicsCompressorNode,EditContext,ElementInternals,EncodedAudioChunk,EncodedVideoChunk,EventCounts,EventSource,External,FeaturePolicy,FederatedCredential,Fence,FencedFrameConfig,FetchLaterResult,FileSystemDirectoryHandle,FileSystemFileHandle,FileSystemHandle,FileSystemObserver,FileSystemWritableFileStream,FontData,FontFaceSetLoadEvent,FragmentDirective,Gamepad,GamepadButton,GamepadEvent,GamepadHapticActuator,Geolocation,GeolocationCoordinates,GeolocationPosition,GeolocationPositionError,GainNode,OscillatorNode,AnalyserNode,BiquadFilterNode,GPU,GPUAdapter,GPUAdapterInfo,GPUBindGroup,GPUBindGroupLayout,GPUBuffer,GPUBufferUsage,GPUCanvasContext,GPUColorWrite,GPUCommandBuffer,GPUCommandEncoder,GPUCompilationInfo,GPUCompilationMessage,GPUComputePassEncoder,GPUComputePipeline,GPUDevice,GPUDeviceLostInfo,GPUError,GPUExternalTexture,GPUInternalError,GPUMapMode,GPUOutOfMemoryError,GPUPipelineError,GPUPipelineLayout,GPUQuerySet,GPUQueue,GPURenderBundle,GPURenderBundleEncoder,GPURenderPassEncoder,GPURenderPipeline,GPUSampler,GPUShaderModule,GPUShaderStage,GPUSupportedFeatures,GPUSupportedLimits,GPUTexture,GPUTextureUsage,GPUTextureView,GPUUncapturedErrorEvent,GPUValidationError,GravitySensor,Gyroscope,HashChangeEvent,HID,HIDConnectionEvent,HIDDevice,HIDInputReportEvent,Highlight,HighlightRegistry,HTMLFencedFrameElement,HTMLFrameElement,HTMLFrameSetElement,HTMLGeolocationElement,HTMLMarqueeElement,HTMLMenuElement,HTMLSelectedContentElement,IDBCursor,IDBCursorWithValue,IDBDatabase,IDBFactory,IDBIndex,IDBKeyRange,IDBObjectStore,IDBOpenDBRequest,IDBRecord,IDBRequest,IDBTransaction,IDBVersionChangeEvent,IdentityCredential,IdentityCredentialError,IdentityProvider,IdleDetector,IIRFilterNode,ImageBitmap,ImageBitmapRenderingContext,ImageCapture,ImageDecoder,ImageTrack,ImageTrackList,Ink,InputDeviceCapabilities,InputDeviceInfo,IntegrityViolationReportBody,InterestEvent,Keyboard,KeyboardLayoutMap,KeyframeEffect,LanguageDetector,LargestContentfulPaint,LaunchParams,LaunchQueue,LayoutShift,LayoutShiftAttribution,LinearAccelerationSensor,Lock,LockManager,MathMLElement,MediaCapabilities,MediaDeviceInfo,MediaElementAudioSourceNode,MediaEncryptedEvent,MediaKeyMessageEvent,MediaKeys,MediaKeySession,MediaKeyStatusMap,MediaKeySystemAccess,MediaList,MediaMetadata,MediaQueryListEvent,MediaRecorder,MediaSession,MediaSource,MediaSourceHandle,MediaStream,MediaStreamAudioDestinationNode,MediaStreamAudioSourceNode,MediaStreamEvent,MediaStreamTrack,MediaStreamTrackAudioStats,MediaStreamTrackEvent,MediaStreamTrackGenerator,MediaStreamTrackProcessor,MediaStreamTrackVideoStats,MIDIAccess,MIDIConnectionEvent,MIDIInput,MIDIInputMap,MIDIMessageEvent,MIDIOutput,MIDIOutputMap,MIDIPort,NavigateEvent,NavigationDestination,NavigationPrecommitController,NavigationPreloadManager,NavigationTransition,NavigatorLogin,NavigatorManagedData,NavigatorUAData,NetworkInformation,Notification,NotRestoredReasonDetails,NotRestoredReasons,Observable,OfflineAudioCompletionEvent,OfflineAudioContext,Option,OrientationSensor,Origin,OTPCredential,OverconstrainedError,PageRevealEvent,PageSwapEvent,PannerNode,PasswordCredential,PaymentAddress,PaymentManager,PaymentMethodChangeEvent,PaymentRequest,PaymentRequestUpdateEvent,PaymentResponse,PerformanceElementTiming,PerformanceEventTiming,PerformanceLongAnimationFrameTiming,PerformanceLongTaskTiming,PerformanceNavigationTiming,PerformancePaintTiming,PerformanceScriptTiming,PerformanceServerTiming,PerformanceTimingConfidence,PeriodicSyncManager,PeriodicWave,PictureInPictureEvent,PictureInPictureWindow,Presentation,PresentationAvailability,PresentationConnection,PresentationConnectionAvailableEvent,PresentationConnectionCloseEvent,PresentationConnectionList,PresentationReceiver,PresentationRequest,PressureObserver,PressureRecord,Profiler,ProtectedAudience,PublicKeyCredential,PushManager,PushSubscription,PushSubscriptionOptions,ReadableByteStreamController,ReadableStreamBYOBReader,ReadableStreamBYOBRequest,RelativeOrientationSensor,RemotePlayback,ReportBody,ReportingObserver,ResizeObserverEntry,ResizeObserverSize,RestrictionTarget,RTCCertificate,RTCDataChannel,RTCDataChannelEvent,RTCDtlsTransport,RTCDTMFSender,RTCDTMFToneChangeEvent,RTCEncodedAudioFrame,RTCEncodedVideoFrame,RTCError,RTCErrorEvent,RTCIceCandidate,RTCIceTransport,RTCPeerConnection,RTCPeerConnectionIceErrorEvent,RTCPeerConnectionIceEvent,RTCRtpReceiver,RTCRtpScriptTransform,RTCRtpSender,RTCRtpTransceiver,RTCSctpTransport,RTCSessionDescription,RTCStatsReport,RTCTrackEvent,Sanitizer,Scheduler,Scheduling,ScreenDetailed,ScreenDetails,ScriptProcessorNode,ScrollTimeline,SecurityPolicyViolationEvent,Sensor,SensorErrorEvent,Serial,SerialPort,ServiceWorker,ServiceWorkerContainer,ServiceWorkerRegistration,SharedWorker,SnapEvent,SourceBuffer,SourceBufferList,SpeechSynthesisErrorEvent,SpeechSynthesisEvent,SpeechSynthesisUtterance,SpeechSynthesisVoice,StaticRange,StereoPannerNode,StorageEvent,StylePropertyMap,StylePropertyMapReadOnly,StyleSheet,SVGAElement,SVGAngle,SVGAnimatedAngle,SVGAnimatedBoolean,SVGAnimatedEnumeration,SVGAnimatedInteger,SVGAnimatedLength,SVGAnimatedLengthList,SVGAnimatedNumber,SVGAnimatedNumberList,SVGAnimatedPreserveAspectRatio,SVGAnimatedRect,SVGAnimatedString,SVGAnimatedTransformList,SVGAnimateElement,SVGAnimateMotionElement,SVGAnimateTransformElement,SVGAnimationElement,SVGCircleElement,SVGClipPathElement,SVGComponentTransferFunctionElement,SVGDefsElement,SVGDescElement,SVGEllipseElement,SVGFEBlendElement,SVGFEColorMatrixElement,SVGFEComponentTransferElement,SVGFECompositeElement,SVGFEConvolveMatrixElement,SVGFEDiffuseLightingElement,SVGFEDisplacementMapElement,SVGFEDistantLightElement,SVGFEDropShadowElement,SVGFEFloodElement,SVGFEFuncAElement,SVGFEFuncBElement,SVGFEFuncGElement,SVGFEFuncRElement,SVGFEGaussianBlurElement,SVGFEImageElement,SVGFEMergeElement,SVGFEMergeNodeElement,SVGFEMorphologyElement,SVGFEOffsetElement,SVGFEPointLightElement,SVGFESpecularLightingElement,SVGFESpotLightElement,SVGFETileElement,SVGFETurbulenceElement,SVGFilterElement,SVGForeignObjectElement,SVGGElement,SVGGeometryElement,SVGGradientElement,SVGGraphicsElement,SVGImageElement,SVGLength,SVGLengthList,SVGLinearGradientElement,SVGLineElement,SVGMarkerElement,SVGMaskElement,SVGMatrix,SVGMetadataElement,SVGMPathElement,SVGNumber,SVGNumberList,SVGPathElement,SVGPatternElement,SVGPoint,SVGPointList,SVGPolygonElement,SVGPolylineElement,SVGPreserveAspectRatio,SVGRadialGradientElement,SVGRect,SVGRectElement,SVGScriptElement,SVGSetElement,SVGStopElement,SVGStringList,SVGStyleElement,SVGSVGElement,SVGSwitchElement,SVGSymbolElement,SVGTextContentElement,SVGTextElement,SVGTextPathElement,SVGTextPositioningElement,SVGTitleElement,SVGTransform,SVGTransformList,SVGTSpanElement,SVGUnitTypes,SVGUseElement,SVGViewElement,SyncManager,TaskAttributionTiming,TaskController,TaskPriorityChangeEvent,TaskSignal,TextTrack,TextTrackCueList,TextTrackList,TimeRanges,ToggleEvent,Touch,TouchEvent,TouchList,TrackEvent,TransitionEvent,TrustedHTML,TrustedScript,TrustedScriptURL,TrustedTypePolicy,TrustedTypePolicyFactory,URLPattern,USB,USBAlternateInterface,USBConfiguration,USBConnectionEvent,USBDevice,USBEndpoint,USBInterface,USBInTransferResult,USBIsochronousInTransferPacket,USBIsochronousInTransferResult,USBIsochronousOutTransferPacket,USBIsochronousOutTransferResult,USBOutTransferResult,UserActivation,ValidityState,VideoColorSpace,VideoDecoder,VideoEncoder,VideoFrame,VideoPlaybackQuality,ViewTimeline,ViewTransition,ViewTransitionTypeSet,VirtualKeyboard,VirtualKeyboardGeometryChangeEvent,VisibilityStateEntry,WakeLock,WakeLockSentinel,WaveShaperNode,WebGLActiveInfo,WebGLBuffer,WebGLContextEvent,WebGLFramebuffer,WebGLObject,WebGLProgram,WebGLQuery,WebGLRenderbuffer,WebGLSampler,WebGLShader,WebGLShaderPrecisionFormat,WebGLSync,WebGLTexture,WebGLTransformFeedback,WebGLUniformLocation,WebGLVertexArrayObject,WebKitCSSMatrix,WebKitMutationObserver,WebSocket,WebSocketError,WebSocketStream,WebTransport,WebTransportBidirectionalStream,WebTransportDatagramDuplexStream,WebTransportError,WindowControlsOverlay,WindowControlsOverlayGeometryChangeEvent,Worklet,XMLHttpRequestUpload,XPathEvaluator,XPathExpression,XPathResult,XRAnchor,XRAnchorSet,XRBoundedReferenceSpace,XRCamera,XRCPUDepthInformation,XRDepthInformation,XRDOMOverlayState,XRFrame,XRHand,XRHitTestResult,XRHitTestSource,XRInputSource,XRInputSourceArray,XRInputSourceEvent,XRInputSourcesChangeEvent,XRJointPose,XRJointSpace,XRLayer,XRLightEstimate,XRLightProbe,XRPose,XRRay,XRReferenceSpace,XRReferenceSpaceEvent,XRRenderState,XRRigidTransform,XRSession,XRSessionEvent,XRSpace,XRSystem,XRTransientInputHitTestResult,XRTransientInputHitTestSource,XRView,XRViewerPose,XRViewport,XRVisibilityMaskChangeEvent,XRWebGLBinding,XRWebGLDepthInformation,XRWebGLLayer,AudioContext,MessageChannel,MessagePort,IntersectionObserver,IntersectionObserverEntry,ResizeObserver,MutationRecord,PerformanceObserverEntryList,FileReader,FileList,FocusEvent,FormDataEvent,KeyboardEvent,MouseEvent,ProgressEvent,SubmitEvent,WheelEvent,UIEvent,PromiseRejectionEvent,PageTransitionEvent,PopStateEvent,InputEvent,CompositionEvent,PointerEvent'.split(',').forEach(function(n){
    \\    if(!(n in window))try{window[n]=_mkCtor(n)}catch(e){}
    \\  });
    \\  // Navigator stubs
    \\  var navStubs = {bluetooth:{},clipboard:{readText:function(){return Promise.resolve('')},writeText:function(){return Promise.resolve()}},connection:{effectiveType:'4g',downlink:10,rtt:50,saveData:false,type:'wifi'},credentials:{get:function(){return Promise.resolve(null)},create:function(){return Promise.resolve(null)},store:function(){return Promise.resolve()}},geolocation:{getCurrentPosition:function(){},watchPosition:function(){return 0},clearWatch:function(){}},locks:{request:function(){return Promise.resolve()},query:function(){return Promise.resolve({held:[],pending:[]})}},mediaCapabilities:{decodingInfo:function(){return Promise.resolve({supported:true,smooth:true,powerEfficient:true})}},mediaSession:{setActionHandler:function(){},metadata:null,playbackState:'none'},permissions:{query:function(){return Promise.resolve({state:'prompt'})}},storage:{estimate:function(){return Promise.resolve({usage:Math.floor(Math.random()*500000)+100000,quota:63113641984})}},usb:{getDevices:function(){return Promise.resolve([])},requestDevice:function(){return Promise.reject(new DOMException('','NotFoundError'))}},serial:{getPorts:function(){return Promise.resolve([])}},hid:{getDevices:function(){return Promise.resolve([])}},gpu:undefined,ink:undefined,keyboard:{lock:function(){return Promise.resolve()},unlock:function(){}},wakeLock:{request:function(){return Promise.reject(new DOMException('','NotAllowedError'))}},pdfViewerEnabled:true,doNotTrack:null,maxTouchPoints:0,webdriver:false,scheduling:{isInputPending:function(){return false}},userActivation:{hasBeenActive:false,isActive:false}};
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
