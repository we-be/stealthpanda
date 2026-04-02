// StealthPanda: MediaDevices stub.
// Fingerprinters check navigator.mediaDevices.enumerateDevices().
// This returns an empty array to match a privacy-conscious Chrome profile.

const js = @import("../js/js.zig");
const Page = @import("../Page.zig");

const MediaDevices = @This();
_pad: bool = false,

pub const init: MediaDevices = .{};

pub fn enumerateDevices(_: *const MediaDevices, page: *Page) !js.Promise {
    // Return a promise that resolves with an empty array
    return page.js.local.?.resolvePromise(null);
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(MediaDevices);

    pub const Meta = struct {
        pub const name = "MediaDevices";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const enumerateDevices = bridge.function(MediaDevices.enumerateDevices, .{});
};
