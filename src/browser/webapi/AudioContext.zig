// StealthPanda: AudioContext stub for browser fingerprint consistency.
// Cloudflare Turnstile and other bot detection systems check for the
// existence of AudioContext. This stub provides the constructor and
// basic properties without actual audio rendering.

const js = @import("../js/js.zig");
const Page = @import("../Page.zig");

pub fn registerTypes() []const type {
    return &.{ AudioContext, BaseAudioContext, AudioParam, AnalyserNode, AudioDestinationNode, OscillatorNode, GainNode, BiquadFilterNode };
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
    const freq = try page._factory.create(AudioParam{ .value = 440, .default_value = 440, .min_value = -22050, .max_value = 22050 });
    const det = try page._factory.create(AudioParam{ .value = 0, .default_value = 0, .min_value = -153600, .max_value = 153600 });
    return page._factory.create(OscillatorNode{ ._frequency = freq, ._detune = det });
}

pub fn createGain(_: *AudioContext, page: *Page) !*GainNode {
    const g = try page._factory.create(AudioParam{ .value = 1, .default_value = 1, .min_value = -3.4028235e+38, .max_value = 3.4028235e+38 });
    return page._factory.create(GainNode{ ._gain = g });
}

pub fn createBiquadFilter(_: *AudioContext, page: *Page) !*BiquadFilterNode {
    const freq = try page._factory.create(AudioParam{ .value = 350, .default_value = 350, .min_value = -22050, .max_value = 22050 });
    const q = try page._factory.create(AudioParam{ .value = 1, .default_value = 1, .min_value = -3.4028235e+38, .max_value = 3.4028235e+38 });
    const g = try page._factory.create(AudioParam{ .value = 0, .default_value = 0, .min_value = -3.4028235e+38, .max_value = 3.4028235e+38 });
    const d = try page._factory.create(AudioParam{ .value = 0, .default_value = 0, .min_value = -153600, .max_value = 153600 });
    return page._factory.create(BiquadFilterNode{ ._frequency = freq, ._q = q, ._gain_param = g, ._detune = d });
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

/// Stub AudioParam — used by OscillatorNode.frequency, GainNode.gain, etc.
pub const AudioParam = struct {
    value: f64 = 0,
    default_value: f64 = 0,
    min_value: f64 = -3.4028235e+38,
    max_value: f64 = 3.4028235e+38,

    pub fn getValue(self: *const AudioParam) f64 {
        return self.value;
    }
    pub fn getDefaultValue(self: *const AudioParam) f64 {
        return self.default_value;
    }
    pub fn getMinValue(self: *const AudioParam) f64 {
        return self.min_value;
    }
    pub fn getMaxValue(self: *const AudioParam) f64 {
        return self.max_value;
    }
    pub fn setValueAtTime(_: *AudioParam, _: f64, _: f64) void {}
    pub fn linearRampToValueAtTime(_: *AudioParam, _: f64, _: f64) void {}
    pub fn exponentialRampToValueAtTime(_: *AudioParam, _: f64, _: f64) void {}
    pub fn setTargetAtTime(_: *AudioParam, _: f64, _: f64, _: f64) void {}
    pub fn cancelScheduledValues(_: *AudioParam, _: f64) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(AudioParam);
        pub const Meta = struct {
            pub const name = "AudioParam";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const value = bridge.accessor(AudioParam.getValue, null, .{});
        pub const defaultValue = bridge.accessor(AudioParam.getDefaultValue, null, .{});
        pub const minValue = bridge.accessor(AudioParam.getMinValue, null, .{});
        pub const maxValue = bridge.accessor(AudioParam.getMaxValue, null, .{});
        pub const setValueAtTime = bridge.function(AudioParam.setValueAtTime, .{ .noop = true });
        pub const linearRampToValueAtTime = bridge.function(AudioParam.linearRampToValueAtTime, .{ .noop = true });
        pub const exponentialRampToValueAtTime = bridge.function(AudioParam.exponentialRampToValueAtTime, .{ .noop = true });
        pub const setTargetAtTime = bridge.function(AudioParam.setTargetAtTime, .{ .noop = true });
        pub const cancelScheduledValues = bridge.function(AudioParam.cancelScheduledValues, .{ .noop = true });
    };
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
    _type: []const u8 = "sine",
    _frequency: *AudioParam = undefined,
    _detune: *AudioParam = undefined,

    pub fn getType(self: *const OscillatorNode) []const u8 {
        return self._type;
    }
    pub fn setType(self: *OscillatorNode, t: []const u8) void {
        self._type = t;
    }
    pub fn getFrequency(self: *const OscillatorNode) *AudioParam {
        return self._frequency;
    }
    pub fn getDetune(self: *const OscillatorNode) *AudioParam {
        return self._detune;
    }
    pub fn connect(_: *const OscillatorNode) void {}
    pub fn disconnect(_: *const OscillatorNode) void {}
    pub fn start(_: *const OscillatorNode) void {}
    pub fn stop(_: *const OscillatorNode) void {}
    pub fn addEventListener(_: *const OscillatorNode, _: []const u8) void {}
    pub fn removeEventListener(_: *const OscillatorNode, _: []const u8) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(OscillatorNode);
        pub const Meta = struct {
            pub const name = "OscillatorNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const @"type" = bridge.accessor(OscillatorNode.getType, OscillatorNode.setType, .{});
        pub const frequency = bridge.accessor(OscillatorNode.getFrequency, null, .{});
        pub const detune = bridge.accessor(OscillatorNode.getDetune, null, .{});
        pub const connect = bridge.function(OscillatorNode.connect, .{ .noop = true });
        pub const disconnect = bridge.function(OscillatorNode.disconnect, .{ .noop = true });
        pub const start = bridge.function(OscillatorNode.start, .{ .noop = true });
        pub const stop = bridge.function(OscillatorNode.stop, .{ .noop = true });
        pub const addEventListener = bridge.function(OscillatorNode.addEventListener, .{ .noop = true });
        pub const removeEventListener = bridge.function(OscillatorNode.removeEventListener, .{ .noop = true });
    };
};

pub const GainNode = struct {
    _gain: *AudioParam = undefined,

    pub fn getGain(self: *const GainNode) *AudioParam {
        return self._gain;
    }
    pub fn connect(_: *const GainNode) void {}
    pub fn disconnect(_: *const GainNode) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(GainNode);
        pub const Meta = struct {
            pub const name = "GainNode";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const gain = bridge.accessor(GainNode.getGain, null, .{});
        pub const connect = bridge.function(GainNode.connect, .{ .noop = true });
        pub const disconnect = bridge.function(GainNode.disconnect, .{ .noop = true });
    };
};

pub const BiquadFilterNode = struct {
    _type: []const u8 = "lowpass",
    _frequency: *AudioParam = undefined,
    _q: *AudioParam = undefined,
    _gain_param: *AudioParam = undefined,
    _detune: *AudioParam = undefined,

    pub fn getType(self: *const BiquadFilterNode) []const u8 {
        return self._type;
    }
    pub fn setType(self: *BiquadFilterNode, t: []const u8) void {
        self._type = t;
    }
    pub fn getFrequencyParam(self: *const BiquadFilterNode) *AudioParam {
        return self._frequency;
    }
    pub fn getQ(self: *const BiquadFilterNode) *AudioParam {
        return self._q;
    }
    pub fn getBiquadGain(self: *const BiquadFilterNode) *AudioParam {
        return self._gain_param;
    }
    pub fn getDetune(self: *const BiquadFilterNode) *AudioParam {
        return self._detune;
    }
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
        pub const @"type" = bridge.accessor(BiquadFilterNode.getType, BiquadFilterNode.setType, .{});
        pub const frequency = bridge.accessor(BiquadFilterNode.getFrequencyParam, null, .{});
        pub const Q = bridge.accessor(BiquadFilterNode.getQ, null, .{});
        pub const gain = bridge.accessor(BiquadFilterNode.getBiquadGain, null, .{});
        pub const detune = bridge.accessor(BiquadFilterNode.getDetune, null, .{});
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
