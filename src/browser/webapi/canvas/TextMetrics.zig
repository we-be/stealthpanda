// StealthPanda: TextMetrics stub for measureText() support.
// Fingerprinters call ctx.measureText("text") and check the returned
// metrics. This provides realistic Chrome-like values.

const js = @import("../../js/js.zig");

const TextMetrics = @This();

_width: f64,

pub const JsApi = struct {
    pub const bridge = js.Bridge(TextMetrics);

    pub const Meta = struct {
        pub const name = "TextMetrics";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const width = bridge.accessor(getWidth, null, .{});
    pub const actualBoundingBoxLeft = bridge.accessor(getActualBoundingBoxLeft, null, .{});
    pub const actualBoundingBoxRight = bridge.accessor(getActualBoundingBoxRight, null, .{});
    pub const fontBoundingBoxAscent = bridge.accessor(getFontBoundingBoxAscent, null, .{});
    pub const fontBoundingBoxDescent = bridge.accessor(getFontBoundingBoxDescent, null, .{});
    pub const actualBoundingBoxAscent = bridge.accessor(getActualBoundingBoxAscent, null, .{});
    pub const actualBoundingBoxDescent = bridge.accessor(getActualBoundingBoxDescent, null, .{});
    pub const hangingBaseline = bridge.accessor(getHangingBaseline, null, .{});
    pub const alphabeticBaseline = bridge.property(@as(f64, 0), .{ .template = false });
    pub const ideographicBaseline = bridge.accessor(getIdeographicBaseline, null, .{});

    fn getWidth(self: *const TextMetrics) f64 {
        return self._width;
    }
    fn getActualBoundingBoxLeft(_: *const TextMetrics) f64 {
        return 0;
    }
    fn getActualBoundingBoxRight(self: *const TextMetrics) f64 {
        return self._width;
    }
    fn getFontBoundingBoxAscent(_: *const TextMetrics) f64 {
        return 8; // Approximate for 10px sans-serif
    }
    fn getFontBoundingBoxDescent(_: *const TextMetrics) f64 {
        return 2;
    }
    fn getActualBoundingBoxAscent(_: *const TextMetrics) f64 {
        return 7;
    }
    fn getActualBoundingBoxDescent(_: *const TextMetrics) f64 {
        return 0;
    }
    fn getHangingBaseline(_: *const TextMetrics) f64 {
        return 6.4;
    }
    fn getIdeographicBaseline(_: *const TextMetrics) f64 {
        return -2;
    }
};
