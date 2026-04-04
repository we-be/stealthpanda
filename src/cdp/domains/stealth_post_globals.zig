// StealthPanda: Post-globals patches.
// Runs AFTER chrome_globals.zig which creates constructor stubs.
// Adds methods to those stubs that fingerprinters check.

pub const script: [:0]const u8 =
    \\try {
    // OfflineAudioContext.startRendering — CF audio fingerprinting
    \\if (typeof OfflineAudioContext === 'function') {
    \\  if (!OfflineAudioContext.prototype.startRendering) {
    \\    OfflineAudioContext.prototype.startRendering = function() {
    \\      var len = this.length || 44100;
    \\      var sr = this.sampleRate || 44100;
    \\      return Promise.resolve({
    \\        numberOfChannels: this.numberOfChannels || 1,
    \\        length: len, sampleRate: sr, duration: len / sr,
    \\        getChannelData: function() {
    \\          var d = new Float32Array(len);
    \\          for (var i = 0; i < len; i++) d[i] = Math.sin(i * 0.01) * 0.001 + (i % 3) * 0.0001;
    \\          return d;
    \\        },
    \\        copyFromChannel: function() {}, copyToChannel: function() {}
    \\      });
    \\    };
    \\  }
    \\}
    // location.ancestorOrigins
    \\if (typeof location !== 'undefined' && !location.ancestorOrigins) {
    \\  try { Object.defineProperty(location, 'ancestorOrigins', {
    \\    value: { length: 0, contains: function() { return false; }, item: function() { return null; } },
    \\    configurable: true
    \\  }); } catch(e) {}
    \\}
    \\} catch(e) {}
;
