// StealthPanda: Chrome global constructor stubs.
// The CF orchestrator fingerprints the Window object by enumerating all properties
// and classifying their types. Chrome has ~900 properties on Window, including
// many Web API constructors. This script adds stubs for all missing constructors
// so the fingerprint matches Chrome.

pub const script: [:0]const u8 =
    \\(function() {
    \\  // Chrome 131 Window constructors that should exist as native functions
    \\  var missing = [
    \\    'AnimationEffect','AnimationEvent','AnimationPlaybackEvent','AnimationTimeline',
    \\    'AnalyserNode','AudioBuffer','AudioBufferSourceNode','AudioDestinationNode',
    \\    'AudioListener','AudioNode','AudioParam','AudioParamMap','AudioProcessingEvent',
    \\    'AudioScheduledSourceNode','AudioWorklet','AudioWorkletNode',
    \\    'BarProp','BatteryManager','BeforeUnloadEvent','BiquadFilterNode',
    \\    'CSSAnimation','CSSConditionRule','CSSCounterStyleRule','CSSFontFaceRule',
    \\    'CSSFontPaletteValuesRule','CSSGroupingRule','CSSImageValue','CSSImportRule',
    \\    'CSSKeyframeRule','CSSKeyframesRule','CSSKeywordValue','CSSLayerBlockRule',
    \\    'CSSLayerStatementRule','CSSMathClamp','CSSMathInvert','CSSMathMax','CSSMathMin',
    \\    'CSSMathNegate','CSSMathProduct','CSSMathSum','CSSMathValue','CSSMatrixComponent',
    \\    'CSSMediaRule','CSSNamespaceRule','CSSNumericArray','CSSNumericValue',
    \\    'CSSPageRule','CSSPerspective','CSSPositionValue','CSSPropertyRule','CSSRotate',
    \\    'CSSScale','CSSSkew','CSSSkewX','CSSSkewY','CSSStyleValue','CSSSupportsRule',
    \\    'CSSTransformComponent','CSSTransformValue','CSSTransition','CSSTranslate',
    \\    'CSSUnitValue','CSSUnparsedValue','CSSVariableReferenceValue',
    \\    'Cache','CacheStorage','CanvasGradient','CanvasPattern',
    \\    'ChannelMergerNode','ChannelSplitterNode','ClipboardEvent','ClipboardItem',
    \\    'CloseEvent','ConstantSourceNode','ContentVisibilityAutoStateChangeEvent',
    \\    'ConvolverNode','CountQueuingStrategy','Credential','CredentialsContainer',
    \\    'CryptoKey','CustomStateSet',
    \\    'DOMMatrix','DOMMatrixReadOnly','DOMPoint','DOMPointReadOnly',
    \\    'DOMRectList','DOMRectReadOnly','DOMStringList',
    \\    'DataTransfer','DataTransferItem','DataTransferItemList',
    \\    'DelayNode','DeviceMotionEvent','DeviceOrientationEvent',
    \\    'DocumentTimeline','DragEvent','DynamicsCompressorNode',
    \\    'ElementInternals','EncodedAudioChunk','EncodedVideoChunk',
    \\    'ErrorEvent','EventCounts','EventSource',
    \\    'External','EyeDropper',
    \\    'FeaturePolicy','FileList','FileReader','FileSystemDirectoryHandle',
    \\    'FileSystemFileHandle','FileSystemHandle','FileSystemWritableFileStream',
    \\    'FocusEvent','FontFace','FontFaceSet','FontFaceSetLoadEvent','FormDataEvent',
    \\    'FragmentDirective',
    \\    'GainNode','Gamepad','GamepadButton','GamepadEvent','GamepadHapticActuator',
    \\    'Geolocation','GeolocationCoordinates','GeolocationPosition',
    \\    'GeolocationPositionError',
    \\    'HTMLAllCollection','HTMLAnchorElement','HTMLAreaElement','HTMLAudioElement',
    \\    'HTMLBRElement','HTMLBaseElement','HTMLBodyElement','HTMLButtonElement',
    \\    'HTMLCanvasElement','HTMLDListElement','HTMLDataElement','HTMLDataListElement',
    \\    'HTMLDetailsElement','HTMLDialogElement','HTMLDirectoryElement',
    \\    'HTMLDivElement','HTMLElement','HTMLEmbedElement','HTMLFencedFrameElement',
    \\    'HTMLFieldSetElement','HTMLFontElement','HTMLFormControlsCollection',
    \\    'HTMLFormElement','HTMLFrameElement','HTMLFrameSetElement','HTMLHRElement',
    \\    'HTMLHeadElement','HTMLHeadingElement','HTMLHtmlElement','HTMLIFrameElement',
    \\    'HTMLImageElement','HTMLInputElement','HTMLLIElement','HTMLLabelElement',
    \\    'HTMLLegendElement','HTMLLinkElement','HTMLMapElement','HTMLMarqueeElement',
    \\    'HTMLMediaElement','HTMLMenuElement','HTMLMetaElement','HTMLMeterElement',
    \\    'HTMLModElement','HTMLOListElement','HTMLObjectElement','HTMLOptGroupElement',
    \\    'HTMLOptionElement','HTMLOptionsCollection','HTMLOutputElement',
    \\    'HTMLParagraphElement','HTMLParamElement','HTMLPictureElement',
    \\    'HTMLPreElement','HTMLProgressElement','HTMLQuoteElement',
    \\    'HTMLScriptElement','HTMLSelectElement','HTMLSlotElement',
    \\    'HTMLSourceElement','HTMLSpanElement','HTMLStyleElement',
    \\    'HTMLTableCaptionElement','HTMLTableCellElement','HTMLTableColElement',
    \\    'HTMLTableElement','HTMLTableRowElement','HTMLTableSectionElement',
    \\    'HTMLTemplateElement','HTMLTextAreaElement','HTMLTimeElement',
    \\    'HTMLTitleElement','HTMLTrackElement','HTMLUListElement',
    \\    'HTMLUnknownElement','HTMLVideoElement',
    \\    'HashChangeEvent','Highlight','HighlightRegistry',
    \\    'IDBCursor','IDBCursorWithValue','IDBDatabase','IDBFactory',
    \\    'IDBIndex','IDBKeyRange','IDBObjectStore','IDBOpenDBRequest',
    \\    'IDBRequest','IDBTransaction','IDBVersionChangeEvent',
    \\    'IdleDeadline','ImageBitmap','ImageBitmapRenderingContext',
    \\    'InputDeviceCapabilities','InputDeviceInfo','InputEvent',
    \\    'IntersectionObserverEntry',
    \\    'KeyframeEffect',
    \\    'LargestContentfulPaint','LazyLoadingObserver',
    \\    'LinearAccelerationSensor','Lock','LockManager',
    \\    'MIDIAccess','MIDIConnectionEvent','MIDIInput','MIDIInputMap',
    \\    'MIDIMessageEvent','MIDIOutput','MIDIOutputMap','MIDIPort',
    \\    'MediaCapabilities','MediaDeviceInfo','MediaDevices','MediaElementAudioSourceNode',
    \\    'MediaEncryptedEvent','MediaError','MediaKeyMessageEvent',
    \\    'MediaKeySession','MediaKeyStatusMap','MediaKeySystemAccess',
    \\    'MediaKeys','MediaList','MediaMetadata','MediaQueryListEvent',
    \\    'MediaRecorder','MediaSession','MediaSource','MediaStream',
    \\    'MediaStreamAudioDestinationNode','MediaStreamAudioSourceNode',
    \\    'MediaStreamEvent','MediaStreamTrack','MediaStreamTrackEvent',
    \\    'MessagePort','MimeType','MimeTypeArray',
    \\    'MutationRecord',
    \\    'NavigateEvent','Navigation','NavigationCurrentEntryChangeEvent',
    \\    'NavigationDestination','NavigationHistoryEntry','NavigationTransition',
    \\    'Navigator','NavigatorUAData','NetworkInformation',
    \\    'Notification',
    \\    'OfflineAudioCompletionEvent','OfflineAudioContext',
    \\    'OscillatorNode','OverconstrainedError',
    \\    'PageTransitionEvent','PannerNode','Path2D','PaymentAddress',
    \\    'PaymentMethodChangeEvent','PaymentRequest','PaymentRequestUpdateEvent',
    \\    'PaymentResponse','PerformanceElementTiming','PerformanceEventTiming',
    \\    'PerformanceLongAnimationFrameTiming','PerformanceLongTaskTiming',
    \\    'PerformanceNavigationTiming','PerformancePaintTiming',
    \\    'PerformanceResourceTiming','PerformanceServerTiming',
    \\    'PeriodicWave','PermissionStatus','PictureInPictureEvent',
    \\    'PictureInPictureWindow','Plugin','PluginArray',
    \\    'PointerEvent','PopStateEvent','Presentation',
    \\    'PresentationAvailability','PresentationConnection',
    \\    'PresentationConnectionAvailableEvent','PresentationConnectionCloseEvent',
    \\    'PresentationConnectionList','PresentationReceiver','PresentationRequest',
    \\    'Profiler','ProgressEvent','PromiseRejectionEvent',
    \\    'PublicKeyCredential',
    \\    'RTCCertificate','RTCDTMFSender','RTCDTMFToneChangeEvent',
    \\    'RTCDataChannel','RTCDataChannelEvent','RTCDtlsTransport',
    \\    'RTCEncodedAudioFrame','RTCEncodedVideoFrame','RTCError',
    \\    'RTCErrorEvent','RTCIceCandidate','RTCIceTransport',
    \\    'RTCPeerConnection','RTCPeerConnectionIceErrorEvent',
    \\    'RTCPeerConnectionIceEvent','RTCRtpReceiver','RTCRtpSender',
    \\    'RTCRtpTransceiver','RTCSctpTransport','RTCSessionDescription',
    \\    'RTCStatsReport','RTCTrackEvent',
    \\    'RadioNodeList','Range','ReadableByteStreamController',
    \\    'ReadableStreamBYOBReader','ReadableStreamBYOBRequest',
    \\    'ReadableStreamDefaultController','ReadableStreamDefaultReader',
    \\    'RemotePlayback','ReportBody','ReportingObserver',
    \\    'ResizeObserverEntry','ResizeObserverSize',
    \\    'SVGAElement','SVGAnimateElement','SVGAnimateMotionElement',
    \\    'SVGAnimateTransformElement','SVGAnimatedAngle','SVGAnimatedBoolean',
    \\    'SVGAnimatedEnumeration','SVGAnimatedInteger','SVGAnimatedLength',
    \\    'SVGAnimatedLengthList','SVGAnimatedNumber','SVGAnimatedNumberList',
    \\    'SVGAnimatedPreserveAspectRatio','SVGAnimatedRect','SVGAnimatedString',
    \\    'SVGAnimatedTransformList','SVGAnimationElement','SVGCircleElement',
    \\    'SVGClipPathElement','SVGComponentTransferFunctionElement','SVGDefsElement',
    \\    'SVGDescElement','SVGElement','SVGEllipseElement','SVGFEBlendElement',
    \\    'SVGFEColorMatrixElement','SVGFEComponentTransferElement','SVGFECompositeElement',
    \\    'SVGFEConvolveMatrixElement','SVGFEDiffuseLightingElement',
    \\    'SVGFEDisplacementMapElement','SVGFEDistantLightElement',
    \\    'SVGFEDropShadowElement','SVGFEFloodElement','SVGFEFuncAElement',
    \\    'SVGFEFuncBElement','SVGFEFuncGElement','SVGFEFuncRElement',
    \\    'SVGFEGaussianBlurElement','SVGFEImageElement','SVGFEMergeElement',
    \\    'SVGFEMergeNodeElement','SVGFEMorphologyElement','SVGFEOffsetElement',
    \\    'SVGFEPointLightElement','SVGFESpecularLightingElement',
    \\    'SVGFESpotLightElement','SVGFETileElement','SVGFETurbulenceElement',
    \\    'SVGFilterElement','SVGForeignObjectElement','SVGGElement',
    \\    'SVGGeometryElement','SVGGradientElement','SVGGraphicsElement',
    \\    'SVGImageElement','SVGLength','SVGLengthList','SVGLineElement',
    \\    'SVGLinearGradientElement','SVGMPathElement','SVGMarkerElement',
    \\    'SVGMaskElement','SVGMatrix','SVGMetadataElement','SVGNumber',
    \\    'SVGNumberList','SVGPathElement','SVGPatternElement','SVGPoint',
    \\    'SVGPointList','SVGPolygonElement','SVGPolylineElement',
    \\    'SVGPreserveAspectRatio','SVGRadialGradientElement','SVGRect',
    \\    'SVGRectElement','SVGSVGElement','SVGScriptElement','SVGSetElement',
    \\    'SVGStopElement','SVGStringList','SVGStyleElement','SVGSwitchElement',
    \\    'SVGSymbolElement','SVGTSpanElement','SVGTextContentElement',
    \\    'SVGTextElement','SVGTextPathElement','SVGTextPositioningElement',
    \\    'SVGTitleElement','SVGTransform','SVGTransformList',
    \\    'SVGUnitTypes','SVGUseElement','SVGViewElement',
    \\    'Scheduler','Scheduling','Screen','ScreenOrientation',
    \\    'ScriptProcessorNode','SecurityPolicyViolationEvent','Selection',
    \\    'ServiceWorker','ServiceWorkerContainer','ServiceWorkerRegistration',
    \\    'SharedWorker','SourceBuffer','SourceBufferList',
    \\    'SpeechSynthesisErrorEvent','SpeechSynthesisEvent',
    \\    'SpeechSynthesisUtterance','SpeechSynthesisVoice',
    \\    'StaticRange','StereoPannerNode','Storage','StorageEvent','StorageManager',
    \\    'StylePropertyMap','StylePropertyMapReadOnly','StyleSheet','StyleSheetList',
    \\    'SubmitEvent','SubtleCrypto','SyncManager',
    \\    'TaskAttributionTiming','TaskController','TaskPriorityChangeEvent','TaskSignal',
    \\    'Text','TextDecoder','TextDecoderStream','TextEncoder','TextEncoderStream',
    \\    'TextEvent','TextMetrics','TextTrack','TextTrackCue','TextTrackCueList',
    \\    'TextTrackList','TimeRanges','Touch','TouchEvent','TouchList',
    \\    'TrackEvent','TransformStream','TransformStreamDefaultController',
    \\    'TransitionEvent','TreeWalker','TrustedHTML','TrustedScript',
    \\    'TrustedScriptURL','TrustedTypePolicy','TrustedTypePolicyFactory',
    \\    'UIEvent','UserActivation',
    \\    'VTTCue','VTTRegion','ValidityState','VideoColorSpace',
    \\    'VideoDecoder','VideoEncoder','VideoFrame','VideoPlaybackQuality',
    \\    'VirtualKeyboard','VisualViewport',
    \\    'WaveShaperNode','WebGL2RenderingContext','WebGLActiveInfo',
    \\    'WebGLBuffer','WebGLContextEvent','WebGLFramebuffer','WebGLProgram',
    \\    'WebGLQuery','WebGLRenderbuffer','WebGLRenderingContext','WebGLSampler',
    \\    'WebGLShader','WebGLShaderPrecisionFormat','WebGLSync','WebGLTexture',
    \\    'WebGLTransformFeedback','WebGLUniformLocation','WebGLVertexArrayObject',
    \\    'WheelEvent','Window','WindowControlsOverlay',
    \\    'WritableStreamDefaultController','WritableStreamDefaultWriter',
    \\    'XMLDocument','XMLHttpRequest','XMLHttpRequestEventTarget',
    \\    'XMLHttpRequestUpload','XMLSerializer','XPathEvaluator',
    \\    'XPathExpression','XPathResult','XSLTProcessor',
    \\    'webkitCancelAnimationFrame','webkitRequestAnimationFrame',
    \\    'webkitURL'
    \\  ];
    \\
    \\  // Hide non-standard types from Object.getOwnPropertyNames
    \\  var _nonChromeTypes = new Set([
    \\    'Chrome','ChromeRuntime','Console','CrossOriginWindow','Css',
    \\    'CSSStyleProperties','SpeechSynthesis','MediaDevices','TextMetrics',
    \\    'BaseAudioContext','StorageEstimate','SVGGenericElement',
    \\    'LazyLoadingObserver','ReadableStreamAsyncIterator',
    \\    'WEBGL_debug_renderer_info','WEBGL_lose_context',
    \\  ]);
    \\  var _origGOPN = Object.getOwnPropertyNames;
    \\  Object.getOwnPropertyNames = function(obj) {
    \\    var names = _origGOPN.call(Object, obj);
    \\    if (obj === window || (obj && obj.constructor === Window)) {
    \\      names = names.filter(function(n) { return !_nonChromeTypes.has(n); });
    \\    }
    \\    return names;
    \\  };
    \\
    \\  var mn = window._makeNative || function(){};
    \\  for (var i = 0; i < missing.length; i++) {
    \\    var name = missing[i];
    \\    if (typeof window[name] === 'undefined') {
    \\      try {
    \\        var f = function() {};
    \\        Object.defineProperty(f, 'name', {value: name});
    \\        window[name] = f;
    \\        mn(f, name);
    \\      } catch(e) {}
    \\    }
    \\  }
    \\
    \\  // Also add Window instance properties that Chrome has
    \\  var winProps = [
    \\    'closed','defaultStatus','defaultstatus','external','frameElement',
    \\    'frames','length','locationbar','menubar','name',
    \\    'offscreenBuffering','opener','outerHeight','outerWidth',
    \\    'pageXOffset','pageYOffset','parent','personalbar',
    \\    'screenLeft','screenTop','screenX','screenY',
    \\    'scrollX','scrollY','scrollbars','self','status',
    \\    'statusbar','toolbar','top','window',
    \\    'originAgentCluster','scheduler','navigation',
    \\    'cookieStore','documentPictureInPicture','launchQueue',
    \\    'sharedStorage','fence',
    \\  ];
    \\
    \\  for (var i = 0; i < winProps.length; i++) {
    \\    if (!(winProps[i] in window)) {
    \\      try { window[winProps[i]] = null; } catch(e) {}
    \\    }
    \\  }
    \\
    \\  // Add event handler properties (onXxx)
    \\  var events = [
    \\    'abort','afterprint','animationend','animationiteration','animationstart',
    \\    'appinstalled','beforeinstallprompt','beforeprint','beforeunload',
    \\    'blur','canplay','canplaythrough','change','click','close',
    \\    'contextmenu','cuechange','dblclick','devicemotion','deviceorientation',
    \\    'deviceorientationabsolute','drag','dragend','dragenter','dragleave',
    \\    'dragover','dragstart','drop','durationchange','emptied','ended',
    \\    'error','focus','formdata','gamepadconnected','gamepaddisconnected',
    \\    'gotpointercapture','hashchange','input','invalid','keydown',
    \\    'keypress','keyup','languagechange','load','loadeddata',
    \\    'loadedmetadata','loadstart','lostpointercapture','message',
    \\    'messageerror','mousedown','mouseenter','mouseleave','mousemove',
    \\    'mouseout','mouseover','mouseup','offline','online','pagehide',
    \\    'pageshow','paste','pause','play','playing','pointercancel',
    \\    'pointerdown','pointerenter','pointerleave','pointermove',
    \\    'pointerout','pointerover','pointerrawupdate','pointerup',
    \\    'popstate','progress','ratechange','rejectionhandled','reset',
    \\    'resize','scroll','scrollend','search','securitypolicyviolation',
    \\    'seeked','seeking','select','selectionchange','selectstart',
    \\    'slotchange','stalled','storage','submit','suspend','timeupdate',
    \\    'toggle','touchcancel','touchend','touchmove','touchstart',
    \\    'transitioncancel','transitionend','transitionrun','transitionstart',
    \\    'unhandledrejection','unload','volumechange','waiting','webkitanimationend',
    \\    'webkitanimationiteration','webkitanimationstart','webkittransitionend',
    \\    'wheel'
    \\  ];
    \\
    \\  for (var i = 0; i < events.length; i++) {
    \\    var prop = 'on' + events[i];
    \\    if (!(prop in window)) {
    \\      try { window[prop] = null; } catch(e) {}
    \\    }
    \\  }
    \\
    \\  // Add missing Navigator properties
    \\  var nav = navigator;
    \\  var navMissing = {
    \\    clipboard: {read:function(){return Promise.resolve([]);},write:function(){return Promise.resolve();},readText:function(){return Promise.resolve('');},writeText:function(){return Promise.resolve();}},
    \\    credentials: {create:function(){return Promise.resolve(null);},get:function(){return Promise.resolve(null);},preventSilentAccess:function(){return Promise.resolve();},store:function(){return Promise.resolve();}},
    \\    geolocation: {getCurrentPosition:function(){},watchPosition:function(){return 0;},clearWatch:function(){}},
    \\    locks: {request:function(){return Promise.resolve();},query:function(){return Promise.resolve({held:[],pending:[]});}},
    \\    mediaCapabilities: {decodingInfo:function(){return Promise.resolve({supported:true,smooth:true,powerEfficient:true});},encodingInfo:function(){return Promise.resolve({supported:true,smooth:true,powerEfficient:true});}},
    \\    mediaSession: {metadata:null,playbackState:'none',setActionHandler:function(){},setPositionState:function(){}},
    \\    mimeTypes: navigator.plugins ? {length:2} : {length:0},
    \\    usb: {getDevices:function(){return Promise.resolve([]);}},
    \\    hid: {getDevices:function(){return Promise.resolve([]);}},
    \\    serial: {getPorts:function(){return Promise.resolve([]);}},
    \\    keyboard: {getLayoutMap:function(){return Promise.resolve(new Map());},lock:function(){return Promise.resolve();},unlock:function(){}},
    \\    wakeLock: {request:function(){return Promise.resolve({released:false,release:function(){return Promise.resolve();}});}},
    \\    gpu: undefined,
    \\    userActivation: {hasBeenActive:false,isActive:false},
    \\    scheduling: {isInputPending:function(){return false;}},
    \\    pdfViewerEnabled: true,
    \\    productSub: '20030107',
    \\    vendorSub: '',
    \\    virtualKeyboard: {boundingRect:{x:0,y:0,width:0,height:0},overlaysContent:false,show:function(){},hide:function(){}},
    \\  };
    \\  for (var key in navMissing) {
    \\    if (!(key in nav)) {
    \\      try { Object.defineProperty(nav, key, {
    \\        get: (function(v){return function(){return v;};})(navMissing[key]),
    \\        configurable: true, enumerable: true
    \\      }); } catch(e) {}
    \\    }
    \\  }
    \\  // getGamepads, vibrate, getUserMedia
    \\  if (!nav.getGamepads) nav.getGamepads = function() { return []; };
    \\  if (!nav.vibrate) nav.vibrate = function() { return true; };
    \\  if (!nav.getUserMedia) nav.getUserMedia = function() {};
    \\  if (!nav.requestMediaKeySystemAccess) nav.requestMediaKeySystemAccess = function() { return Promise.reject(new Error('not supported')); };
    \\  if (!nav.requestMIDIAccess) nav.requestMIDIAccess = function() { return Promise.reject(new Error('not supported')); };
    \\  if (!nav.getInstalledRelatedApps) nav.getInstalledRelatedApps = function() { return Promise.resolve([]); };
    \\  if (!nav.setAppBadge) nav.setAppBadge = function() { return Promise.resolve(); };
    \\  if (!nav.clearAppBadge) nav.clearAppBadge = function() { return Promise.resolve(); };
    \\
    \\  // Add missing Document properties
    \\  var doc = document;
    \\  if (!doc.designMode) Object.defineProperty(doc, 'designMode', {get:function(){return 'off';},set:function(){},configurable:true});
    \\  if (!doc.alinkColor) doc.alinkColor = '';
    \\  if (!doc.bgColor) doc.bgColor = '';
    \\  if (!doc.fgColor) doc.fgColor = '';
    \\  if (!doc.linkColor) doc.linkColor = '';
    \\  if (!doc.vlinkColor) doc.vlinkColor = '';
    \\  if (!doc.fullscreenElement) doc.fullscreenElement = null;
    \\  if (!doc.fullscreenEnabled) doc.fullscreenEnabled = true;
    \\  if (typeof doc.fullscreen === 'undefined') doc.fullscreen = false;
    \\  if (!doc.captureEvents) doc.captureEvents = function(){};
    \\  if (!doc.releaseEvents) doc.releaseEvents = function(){};
    \\  if (!doc.featurePolicy) doc.featurePolicy = {allowsFeature:function(){return true;},features:function(){return[];},allowedFeatures:function(){return[];}};
    \\  if (!doc.fragmentDirective) doc.fragmentDirective = {};
    \\  if (!doc.pictureInPictureElement) doc.pictureInPictureElement = null;
    \\  if (!doc.pictureInPictureEnabled) doc.pictureInPictureEnabled = true;
    \\  if (!doc.exitPictureInPicture) doc.exitPictureInPicture = function(){return Promise.resolve();};
    \\  if (!doc.hasStorageAccess) doc.hasStorageAccess = function(){return Promise.resolve(true);};
    \\  if (!doc.requestStorageAccess) doc.requestStorageAccess = function(){return Promise.resolve();};
    \\  if (!doc.wasDiscarded) doc.wasDiscarded = false;
    \\  if (!doc.prerendering) doc.prerendering = false;
    \\  if (typeof doc.onvisibilitychange === 'undefined') doc.onvisibilitychange = null;
    \\  if (typeof doc.onfullscreenchange === 'undefined') doc.onfullscreenchange = null;
    \\  if (typeof doc.onfullscreenerror === 'undefined') doc.onfullscreenerror = null;
    \\  if (typeof doc.onpointerlockchange === 'undefined') doc.onpointerlockchange = null;
    \\  if (typeof doc.onpointerlockerror === 'undefined') doc.onpointerlockerror = null;
    \\  if (typeof doc.onprerenderingchange === 'undefined') doc.onprerenderingchange = null;
    \\  if (typeof doc.onselectionchange === 'undefined') doc.onselectionchange = null;
    \\  if (typeof doc.onselectstart === 'undefined') doc.onselectstart = null;
    \\  if (typeof doc.onfreeze === 'undefined') doc.onfreeze = null;
    \\  if (typeof doc.onresume === 'undefined') doc.onresume = null;
    \\})();
;
