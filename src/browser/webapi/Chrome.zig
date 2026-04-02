// StealthPanda: window.chrome stub.
// Bot detection scripts check for the existence of window.chrome
// and window.chrome.runtime to verify the browser is Chrome.

const js = @import("../js/js.zig");

pub fn registerTypes() []const type {
    return &.{ Chrome, ChromeRuntime };
}

const Chrome = @This();

_pad: bool = false, // Padding so _runtime has a different address than Chrome itself
_runtime: ChromeRuntime = .{},

pub fn getRuntime(self: *Chrome) *ChromeRuntime {
    return &self._runtime;
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(Chrome);

    pub const Meta = struct {
        pub const name = "Chrome";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
        pub const enumerable = false;
    };

    pub const runtime = bridge.accessor(Chrome.getRuntime, null, .{});
};

pub const ChromeRuntime = struct {
    _pad: bool = false,

    pub fn connect(_: *const ChromeRuntime) void {}
    pub fn sendMessage(_: *const ChromeRuntime) void {}

    pub const JsApi = struct {
        pub const bridge = js.Bridge(ChromeRuntime);

        pub const Meta = struct {
            pub const name = "ChromeRuntime";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
            pub const enumerable = false;
        };

        pub const connect = bridge.function(ChromeRuntime.connect, .{});
        pub const sendMessage = bridge.function(ChromeRuntime.sendMessage, .{});
    };
};
