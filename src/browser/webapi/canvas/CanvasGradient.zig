// StealthPanda: CanvasGradient stub.
// Fingerprinters use createRadialGradient/createLinearGradient.

const js = @import("../../js/js.zig");

const CanvasGradient = @This();
_pad: bool = false,

pub fn addColorStop(_: *CanvasGradient, _: f64, _: []const u8) void {}

pub const JsApi = struct {
    pub const bridge = js.Bridge(CanvasGradient);

    pub const Meta = struct {
        pub const name = "CanvasGradient";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const addColorStop = bridge.function(CanvasGradient.addColorStop, .{ .noop = true });
};
