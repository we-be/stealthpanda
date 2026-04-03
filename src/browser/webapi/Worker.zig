// StealthPanda: Worker stub.
// Cloudflare's managed challenge checks for Worker support before
// running its proof-of-work computation. This stub makes typeof Worker
// return "function" to pass the feature detection check.
//
// NOTE: This is a stub — actual Worker execution (separate V8 isolate,
// message passing) is not implemented. The challenge's POW may still
// fail if it actually tries to instantiate a worker.

const js = @import("../js/js.zig");
const Page = @import("../Page.zig");

const Worker = @This();

_pad: bool = false,

pub fn init(_: []const u8, page: *Page) !*Worker {
    // Return a stub Worker object — the stealth inject JS polyfill
    // overrides `new Worker()` at the JS level
    return page._factory.create(Worker{ ._pad = false });
}

pub fn postMessage(_: *const Worker) void {}
pub fn terminate(_: *const Worker) void {}

pub const JsApi = struct {
    pub const bridge = js.Bridge(Worker);

    pub const Meta = struct {
        pub const name = "Worker";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const constructor = bridge.constructor(Worker.init, .{});
    pub const postMessage = bridge.function(Worker.postMessage, .{ .noop = true });
    pub const terminate = bridge.function(Worker.terminate, .{ .noop = true });
};
