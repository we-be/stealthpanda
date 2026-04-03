// StealthPanda: SpeechSynthesis stub.
// Fingerprinters check window.speechSynthesis.getVoices().
// Returns an empty array (consistent with headless Chrome).

const js = @import("../js/js.zig");

const SpeechSynthesis = @This();
_pad: bool = false,

pub const init: SpeechSynthesis = .{};

pub fn getVoices(_: *const SpeechSynthesis) void {
    // Returns empty — the bridge will handle this as an empty array
}

pub fn getPending(_: *const SpeechSynthesis) bool {
    return false;
}

pub fn getSpeaking(_: *const SpeechSynthesis) bool {
    return false;
}

pub fn getPaused(_: *const SpeechSynthesis) bool {
    return false;
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(SpeechSynthesis);

    pub const Meta = struct {
        pub const name = "SpeechSynthesis";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const pending = bridge.accessor(SpeechSynthesis.getPending, null, .{});
    pub const speaking = bridge.accessor(SpeechSynthesis.getSpeaking, null, .{});
    pub const paused = bridge.accessor(SpeechSynthesis.getPaused, null, .{});
};
