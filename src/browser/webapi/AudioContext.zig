// StealthPanda: AudioContext stub for browser fingerprint consistency.
// Cloudflare Turnstile and other bot detection systems check for the
// existence of AudioContext. This stub provides the constructor and
// basic properties without actual audio rendering.

const js = @import("../js/js.zig");
const Page = @import("../Page.zig");

pub fn registerTypes() []const type {
    return &.{ AudioContext, BaseAudioContext };
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
    pub const close = bridge.function(AudioContext.close, .{});
    pub const @"resume" = bridge.function(AudioContext.resume_, .{});
    pub const @"suspend" = bridge.function(AudioContext.suspend_, .{});
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
