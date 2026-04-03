// StealthPanda: AudioContext stub for browser fingerprint consistency.
// Cloudflare Turnstile and other bot detection systems check for the
// existence of AudioContext. This stub provides the constructor and
// basic properties without actual audio rendering.

const js = @import("../js/js.zig");
const Page = @import("../Page.zig");

pub fn registerTypes() []const type {
    return &.{ AudioContext, BaseAudioContext, AnalyserNode, AudioDestinationNode, OscillatorNode, GainNode, BiquadFilterNode };
}

const AudioContext = @This();

_state: []const u8 = "suspended",

pub fn init(page: *Page) !*AudioContext {
    return page._factory.create(AudioContext{ ._state = "running" });
}

pub fn getState(self: *const AudioContext) []const u8 {
    return self._state;
}

pub fn getSampleRate(_: *const AudioContext) f64 {
    return 44100.0;
}

pub fn getCurrentTime(_: *const AudioContext) f64 {
    return 0.0;
}

pub fn getBaseLatency(_: *const AudioContext) f64 {
    return 0.005;
}

pub fn getDestination(_: *AudioContext, page: *Page) !*AudioDestinationNode {
    return page._factory.create(AudioDestinationNode{});
}

pub fn createAnalyser(_: *AudioContext, page: *Page) !*AnalyserNode {
    return page._factory.create(AnalyserNode{});
}

pub fn createOscillator(_: *AudioContext, page: *Page) !*OscillatorNode {
    return page._factory.create(OscillatorNode{});
}

pub fn createGain(_: *AudioContext, page: *Page) !*GainNode {
    return page._factory.create(GainNode{});
}

pub fn createBiquadFilter(_: *AudioContext, page: *Page) !*BiquadFilterNode {
    return page._factory.create(BiquadFilterNode{});
}

pub fn close(self: *AudioContext) void {
    self._state = "closed";
}

pub fn resume_(self: *AudioContext) void {
    if (!std.mem.eql(u8, self._state, "closed")) {
        self._state = "running";
    }
}

pub fn suspend_(self: *AudioContext) void {
    if (!std.mem.eql(u8, self._state, "closed")) {
        self._state = "suspended";
    }
}

const std = @import("std");

pub const JsApi = struct {
    pub const bridge = js.Bridge(AudioContext);

    pub const Meta = struct {
        pub const name = "AudioContext";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const constructor = bridge.constructor(AudioContext.init, .{});
    pub const state = bridge.accessor(AudioContext.getState, null, .{});
    pub const sampleRate = bridge.accessor(AudioContext.getSampleRate, null, .{});
    pub const currentTime = bridge.accessor(AudioContext.getCurrentTime, null, .{});
    pub const baseLatency = bridge.accessor(AudioContext.getBaseLatency, null, .{});
    pub const destination = bridge.accessor(AudioContext.getDestination, null, .{});
    pub const createAnalyser = bridge.function(AudioContext.createAnalyser, .{});
    pub const createOscillator = bridge.function(AudioContext.createOscillator, .{});
    pub const createGain = bridge.function(AudioContext.createGain, .{});
    pub const createBiquadFilter = bridge.function(AudioContext.createBiquadFilter, .{});
    pub const close = bridge.function(AudioContext.close, .{});
    pub const @"resume" = bridge.function(AudioContext.resume_, .{});
    pub const @"suspend" = bridge.function(AudioContext.suspend_, .{});
};

pub const AnalyserNode = struct {
    _fft_size: u32 = 2048,

    pub fn getFftSize(self: *const AnalyserNode) u32 {
        return self._fft_size;
    }
    pub fn getFrequencyBinCount(self: *const AnalyserNode) u32 {
        return self._fft_size / 2;
    }
    pub fn getMinDecibels(_: *const AnalyserNode) f64 {
        return -100.0;
    }
    pub fn getMaxDecibels(_: *const AnalyserNode) f64 {
        return -30.0;
    }
    pub fn getSmoothingTimeConstant(_: *const AnalyserNode) f64 {
        return 0.8;
    }
    pub fn connect(_: *const AnalyserNode) void {}
    pub fn disconnect(_: *const AnalyserNode) void {}
    pub fn getFloatFrequencyData(_: *const AnalyserNode) void {}
    pub fn getByteFrequencyData(_: *const AnalyserNode) void {}
    pub fn getFloatTimeDomainData(_: *const AnalyserNode) void {}
    pub fn getByteTimeDomainData(_: *const AnalyserNode) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(AnalyserNode);
        pub const Meta = struct {
            pub const name = "AnalyserNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const fftSize = bridge.accessor(AnalyserNode.getFftSize, null, .{});
        pub const frequencyBinCount = bridge.accessor(AnalyserNode.getFrequencyBinCount, null, .{});
        pub const minDecibels = bridge.accessor(AnalyserNode.getMinDecibels, null, .{});
        pub const maxDecibels = bridge.accessor(AnalyserNode.getMaxDecibels, null, .{});
        pub const smoothingTimeConstant = bridge.accessor(AnalyserNode.getSmoothingTimeConstant, null, .{});
        pub const connect = bridge.function(AnalyserNode.connect, .{ .noop = true });
        pub const disconnect = bridge.function(AnalyserNode.disconnect, .{ .noop = true });
        pub const getFloatFrequencyData = bridge.function(AnalyserNode.getFloatFrequencyData, .{ .noop = true });
        pub const getByteFrequencyData = bridge.function(AnalyserNode.getByteFrequencyData, .{ .noop = true });
        pub const getFloatTimeDomainData = bridge.function(AnalyserNode.getFloatTimeDomainData, .{ .noop = true });
        pub const getByteTimeDomainData = bridge.function(AnalyserNode.getByteTimeDomainData, .{ .noop = true });
    };
};

pub const AudioDestinationNode = struct {
    _pad: bool = false,

    pub fn getMaxChannelCount(_: *const AudioDestinationNode) u32 {
        return 2;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(AudioDestinationNode);
        pub const Meta = struct {
            pub const name = "AudioDestinationNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const maxChannelCount = bridge.accessor(AudioDestinationNode.getMaxChannelCount, null, .{});
    };
};

pub const OscillatorNode = struct {
    _pad: bool = false,

    pub fn connect(_: *const OscillatorNode) void {}
    pub fn disconnect(_: *const OscillatorNode) void {}
    pub fn start(_: *const OscillatorNode) void {}
    pub fn stop(_: *const OscillatorNode) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(OscillatorNode);
        pub const Meta = struct {
            pub const name = "OscillatorNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const connect = bridge.function(OscillatorNode.connect, .{ .noop = true });
        pub const disconnect = bridge.function(OscillatorNode.disconnect, .{ .noop = true });
        pub const start = bridge.function(OscillatorNode.start, .{ .noop = true });
        pub const stop = bridge.function(OscillatorNode.stop, .{ .noop = true });
    };
};

pub const GainNode = struct {
    _pad: bool = false,

    pub fn connect(_: *const GainNode) void {}
    pub fn disconnect(_: *const GainNode) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(GainNode);
        pub const Meta = struct {
            pub const name = "GainNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const connect = bridge.function(GainNode.connect, .{ .noop = true });
        pub const disconnect = bridge.function(GainNode.disconnect, .{ .noop = true });
    };
};

pub const BiquadFilterNode = struct {
    _pad: bool = false,

    pub fn connect(_: *const BiquadFilterNode) void {}
    pub fn disconnect(_: *const BiquadFilterNode) void {}
    pub fn getFrequencyResponse(_: *const BiquadFilterNode) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(BiquadFilterNode);
        pub const Meta = struct {
            pub const name = "BiquadFilterNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const connect = bridge.function(BiquadFilterNode.connect, .{ .noop = true });
        pub const disconnect = bridge.function(BiquadFilterNode.disconnect, .{ .noop = true });
        pub const getFrequencyResponse = bridge.function(BiquadFilterNode.getFrequencyResponse, .{ .noop = true });
    };
};

/// BaseAudioContext is the parent interface.
/// Some detection scripts check for its existence.
pub const BaseAudioContext = struct {
    _pad: bool = false,

    pub const JsApi = struct {
        pub const bridge = js.Bridge(BaseAudioContext);
        pub const Meta = struct {
            pub const name = "BaseAudioContext";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
            pub const empty_with_no_proto = true;
        };
    };
};
