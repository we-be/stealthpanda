const js = @import("../js/js.zig");
const Page = @import("../Page.zig");
const datetime = @import("../../datetime.zig");

pub fn registerTypes() []const type {
    return &.{ Performance, Entry, Mark, Measure, PerformanceTiming, PerformanceNavigation };
}

const std = @import("std");

const Performance = @This();

_time_origin: u64,
_entries: std.ArrayList(*Entry) = .{},
_timing: PerformanceTiming = .{},
_navigation: PerformanceNavigation = .{},

/// Last returned timestamp — ensures monotonic, always-advancing values
var _last_timestamp: u64 = 0;

/// Get high-resolution timestamp in nanoseconds.
/// Chrome headless on Linux rounds to ~100μs (0.1ms). Confirmed via CF Turnstile
/// Worker timer test: Chrome reports kPVx7=0.09999999403953552 (~100μs).
/// Previously we used 5μs which was too precise for headless mode.
fn highResTimestamp() u64 {
    const ts = datetime.timespec();
    const nanos = @as(u64, @intCast(ts.sec)) * 1_000_000_000 + @as(u64, @intCast(ts.nsec));
    // Round to nearest 100 microseconds (100000ns) — matches Chrome headless
    var rounded = @divTrunc(nanos + 50000, 100000) * 100000;
    // Ensure strictly monotonic with natural jitter
    if (rounded <= _last_timestamp) {
        const jitter_seed = nanos ^ (_last_timestamp >> 5);
        const extra = if (jitter_seed & 0x3 == 0) @as(u64, 200000) // ~25% chance of +200μs
            else @as(u64, 100000); // ~75% chance of +100μs
        rounded = _last_timestamp + extra;
    }
    _last_timestamp = rounded;
    return rounded;
}

pub fn init() Performance {
    return .{
        ._time_origin = highResTimestamp(),
        ._entries = .{},
        ._timing = PerformanceTiming.init(),
        ._navigation = .{},
    };
}

pub fn getTiming(self: *Performance) *PerformanceTiming {
    return &self._timing;
}

pub fn now(self: *const Performance) f64 {
    const current = highResTimestamp();
    const elapsed = current - self._time_origin;
    // Return as milliseconds. Chrome uses DOMHighResTimeStamp (double).
    // Chrome's internal conversion from TimeTicks produces values like
    // 100.39999999403954 (not clean 100.4). This float noise is from
    // converting microseconds via double arithmetic.
    // We simulate this by converting through a float32 intermediate,
    // which introduces similar rounding artifacts.
    const ns_f64 = @as(f64, @floatFromInt(elapsed));
    const ms_f64 = ns_f64 / 1_000_000.0;
    // Round-trip through float32 to add Chrome-like precision artifacts
    const ms_f32: f32 = @floatCast(ms_f64);
    return @as(f64, ms_f32);
}

pub fn getTimeOrigin(self: *const Performance) f64 {
    // Return as milliseconds (nanoseconds / 1_000_000)
    return @as(f64, @floatFromInt(self._time_origin)) / 1_000_000.0;
}

pub fn getNavigation(self: *Performance) *PerformanceNavigation {
    return &self._navigation;
}

pub fn mark(
    self: *Performance,
    name: []const u8,
    _options: ?Mark.Options,
    page: *Page,
) !*Mark {
    const m = try Mark.init(name, _options, page);
    try self._entries.append(page.arena, m._proto);
    // Notify about the change.
    try page.notifyPerformanceObservers(m._proto);
    return m;
}

const MeasureOptionsOrStartMark = union(enum) {
    measure_options: Measure.Options,
    start_mark: []const u8,
};

pub fn measure(
    self: *Performance,
    name: []const u8,
    maybe_options_or_start: ?MeasureOptionsOrStartMark,
    maybe_end_mark: ?[]const u8,
    page: *Page,
) !*Measure {
    if (maybe_options_or_start) |options_or_start| switch (options_or_start) {
        .measure_options => |options| {
            // Get start timestamp.
            const start_timestamp = blk: {
                if (options.start) |timestamp_or_mark| {
                    break :blk switch (timestamp_or_mark) {
                        .timestamp => |timestamp| timestamp,
                        .mark => |mark_name| try self.getMarkTime(mark_name),
                    };
                }

                break :blk 0.0;
            };

            // Get end timestamp.
            const end_timestamp = blk: {
                if (options.end) |timestamp_or_mark| {
                    break :blk switch (timestamp_or_mark) {
                        .timestamp => |timestamp| timestamp,
                        .mark => |mark_name| try self.getMarkTime(mark_name),
                    };
                }

                break :blk self.now();
            };

            const m = try Measure.init(
                name,
                options.detail,
                start_timestamp,
                end_timestamp,
                options.duration,
                page,
            );
            try self._entries.append(page.arena, m._proto);
            // Notify about the change.
            try page.notifyPerformanceObservers(m._proto);
            return m;
        },
        .start_mark => |start_mark| {
            // Get start timestamp.
            const start_timestamp = try self.getMarkTime(start_mark);
            // Get end timestamp.
            const end_timestamp = blk: {
                if (maybe_end_mark) |mark_name| {
                    break :blk try self.getMarkTime(mark_name);
                }

                break :blk self.now();
            };

            const m = try Measure.init(
                name,
                null,
                start_timestamp,
                end_timestamp,
                null,
                page,
            );
            try self._entries.append(page.arena, m._proto);
            // Notify about the change.
            try page.notifyPerformanceObservers(m._proto);
            return m;
        },
    };

    const m = try Measure.init(name, null, 0.0, self.now(), null, page);
    try self._entries.append(page.arena, m._proto);
    // Notify about the change.
    try page.notifyPerformanceObservers(m._proto);
    return m;
}

pub fn clearMarks(self: *Performance, mark_name: ?[]const u8) void {
    var i: usize = 0;
    while (i < self._entries.items.len) {
        const entry = self._entries.items[i];
        if (entry._type == .mark and (mark_name == null or std.mem.eql(u8, entry._name, mark_name.?))) {
            _ = self._entries.orderedRemove(i);
        } else {
            i += 1;
        }
    }
}

pub fn clearMeasures(self: *Performance, measure_name: ?[]const u8) void {
    var i: usize = 0;
    while (i < self._entries.items.len) {
        const entry = self._entries.items[i];
        if (entry._type == .measure and (measure_name == null or std.mem.eql(u8, entry._name, measure_name.?))) {
            _ = self._entries.orderedRemove(i);
        } else {
            i += 1;
        }
    }
}

pub fn getEntries(self: *const Performance) []*Entry {
    return self._entries.items;
}

pub fn getEntriesByType(self: *const Performance, entry_type: []const u8, page: *Page) ![]const *Entry {
    var result: std.ArrayList(*Entry) = .empty;

    for (self._entries.items) |entry| {
        if (std.mem.eql(u8, entry.getEntryType(), entry_type)) {
            try result.append(page.call_arena, entry);
        }
    }

    return result.items;
}

pub fn getEntriesByName(self: *const Performance, name: []const u8, entry_type: ?[]const u8, page: *Page) ![]const *Entry {
    var result: std.ArrayList(*Entry) = .empty;

    for (self._entries.items) |entry| {
        if (!std.mem.eql(u8, entry._name, name)) {
            continue;
        }

        const et = entry_type orelse {
            try result.append(page.call_arena, entry);
            continue;
        };

        if (std.mem.eql(u8, entry.getEntryType(), et)) {
            try result.append(page.call_arena, entry);
        }
    }

    return result.items;
}

fn getMarkTime(self: *const Performance, mark_name: []const u8) !f64 {
    for (self._entries.items) |entry| {
        if (entry._type == .mark and std.mem.eql(u8, entry._name, mark_name)) {
            return entry._start_time;
        }
    }

    // PerformanceTiming attribute names are valid start/end marks per the
    // W3C User Timing Level 2 spec. All are relative to navigationStart (= 0).
    // https://www.w3.org/TR/user-timing/#dom-performance-measure
    //
    // `navigationStart` is an equivalent to 0.
    // Others are dependant to request arrival, end of request etc, but we
    // return a dummy 0 value for now.
    const navigation_timing_marks = std.StaticStringMap(void).initComptime(.{
        .{ "navigationStart", {} },
        .{ "unloadEventStart", {} },
        .{ "unloadEventEnd", {} },
        .{ "redirectStart", {} },
        .{ "redirectEnd", {} },
        .{ "fetchStart", {} },
        .{ "domainLookupStart", {} },
        .{ "domainLookupEnd", {} },
        .{ "connectStart", {} },
        .{ "connectEnd", {} },
        .{ "secureConnectionStart", {} },
        .{ "requestStart", {} },
        .{ "responseStart", {} },
        .{ "responseEnd", {} },
        .{ "domLoading", {} },
        .{ "domInteractive", {} },
        .{ "domContentLoadedEventStart", {} },
        .{ "domContentLoadedEventEnd", {} },
        .{ "domComplete", {} },
        .{ "loadEventStart", {} },
        .{ "loadEventEnd", {} },
    });
    if (navigation_timing_marks.has(mark_name)) {
        return 0;
    }

    return error.SyntaxError; // Mark not found
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(Performance);

    pub const Meta = struct {
        pub const name = "Performance";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const now = bridge.function(Performance.now, .{});
    pub const mark = bridge.function(Performance.mark, .{});
    pub const measure = bridge.function(Performance.measure, .{ .dom_exception = true });
    pub const clearMarks = bridge.function(Performance.clearMarks, .{});
    pub const clearMeasures = bridge.function(Performance.clearMeasures, .{});
    pub const getEntries = bridge.function(Performance.getEntries, .{});
    pub const getEntriesByType = bridge.function(Performance.getEntriesByType, .{});
    pub const getEntriesByName = bridge.function(Performance.getEntriesByName, .{});
    pub const timeOrigin = bridge.accessor(Performance.getTimeOrigin, null, .{});
    pub const timing = bridge.accessor(Performance.getTiming, null, .{});
    pub const navigation = bridge.accessor(Performance.getNavigation, null, .{});
    // Chrome-specific: performance.memory (MemoryInfo)
    // Stub for fingerprint consistency — stealth inject overrides with realistic values
    pub const memory = bridge.property(null, .{ .template = false, .readonly = false });
};

pub const Entry = struct {
    _duration: f64 = 0.0,
    _type: Type,
    _name: []const u8,
    _start_time: f64 = 0.0,

    pub const Type = union(Enum) {
        element,
        event,
        first_input,
        @"largest-contentful-paint",
        @"layout-shift",
        @"long-animation-frame",
        longtask,
        measure: *Measure,
        navigation,
        paint,
        resource,
        taskattribution,
        @"visibility-state",
        mark: *Mark,

        pub const Enum = enum(u8) {
            element = 1, // Changing this affect PerformanceObserver's behavior.
            event = 2,
            first_input = 3,
            @"largest-contentful-paint" = 4,
            @"layout-shift" = 5,
            @"long-animation-frame" = 6,
            longtask = 7,
            measure = 8,
            navigation = 9,
            paint = 10,
            resource = 11,
            taskattribution = 12,
            @"visibility-state" = 13,
            mark = 14,
            // If we ever have types more than 16, we have to update entry
            // table of PerformanceObserver too.
        };
    };

    pub fn getDuration(self: *const Entry) f64 {
        return self._duration;
    }

    pub fn getEntryType(self: *const Entry) []const u8 {
        return switch (self._type) {
            else => |t| @tagName(t),
        };
    }

    pub fn getName(self: *const Entry) []const u8 {
        return self._name;
    }

    pub fn getStartTime(self: *const Entry) f64 {
        return self._start_time;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(Entry);

        pub const Meta = struct {
            pub const name = "PerformanceEntry";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const name = bridge.accessor(Entry.getName, null, .{});
        pub const duration = bridge.accessor(Entry.getDuration, null, .{});
        pub const entryType = bridge.accessor(Entry.getEntryType, null, .{});
        pub const startTime = bridge.accessor(Entry.getStartTime, null, .{});
    };
};

pub const Mark = struct {
    _proto: *Entry,
    _detail: ?js.Value.Global,

    const Options = struct {
        detail: ?js.Value = null,
        startTime: ?f64 = null,
    };

    pub fn init(name: []const u8, _opts: ?Options, page: *Page) !*Mark {
        const opts = _opts orelse Options{};
        const start_time = opts.startTime orelse page.window._performance.now();

        if (start_time < 0.0) {
            return error.TypeError;
        }

        const detail = if (opts.detail) |d| try d.persist() else null;
        const m = try page._factory.create(Mark{
            ._proto = undefined,
            ._detail = detail,
        });

        const entry = try page._factory.create(Entry{
            ._start_time = start_time,
            ._name = try page.dupeString(name),
            ._type = .{ .mark = m },
        });
        m._proto = entry;
        return m;
    }

    pub fn getDetail(self: *const Mark) ?js.Value.Global {
        return self._detail;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(Mark);

        pub const Meta = struct {
            pub const name = "PerformanceMark";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const detail = bridge.accessor(Mark.getDetail, null, .{});
    };
};

pub const Measure = struct {
    _proto: *Entry,
    _detail: ?js.Value.Global,

    const Options = struct {
        detail: ?js.Value = null,
        start: ?TimestampOrMark,
        end: ?TimestampOrMark,
        duration: ?f64 = null,

        const TimestampOrMark = union(enum) {
            timestamp: f64,
            mark: []const u8,
        };
    };

    pub fn init(
        name: []const u8,
        maybe_detail: ?js.Value,
        start_timestamp: f64,
        end_timestamp: f64,
        maybe_duration: ?f64,
        page: *Page,
    ) !*Measure {
        const duration = maybe_duration orelse (end_timestamp - start_timestamp);
        if (duration < 0.0) {
            return error.TypeError;
        }

        const detail = if (maybe_detail) |d| try d.persist() else null;
        const m = try page._factory.create(Measure{
            ._proto = undefined,
            ._detail = detail,
        });

        const entry = try page._factory.create(Entry{
            ._start_time = start_timestamp,
            ._duration = duration,
            ._name = try page.dupeString(name),
            ._type = .{ .measure = m },
        });
        m._proto = entry;
        return m;
    }

    pub fn getDetail(self: *const Measure) ?js.Value.Global {
        return self._detail;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(Measure);

        pub const Meta = struct {
            pub const name = "PerformanceMeasure";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };
        pub const detail = bridge.accessor(Measure.getDetail, null, .{});
    };
};

/// PerformanceTiming — Navigation Timing Level 1 (legacy, but widely used).
/// Returns realistic Unix timestamps in milliseconds.
/// CF uses performance.timing.navigationStart for timing analysis.
pub const PerformanceTiming = struct {
    _pad: bool = false,
    _nav_start: f64 = 0,

    pub fn init() PerformanceTiming {
        const ts = datetime.timespec();
        const sec: u64 = @intCast(ts.sec);
        const nsec: u64 = @intCast(@divTrunc(ts.nsec, 1_000_000));
        const ms = @as(f64, @floatFromInt(sec)) * 1000.0 + @as(f64, @floatFromInt(nsec));
        return .{ ._nav_start = ms };
    }

    pub fn getNavigationStart(self: *const PerformanceTiming) f64 {
        return self._nav_start;
    }
    pub fn getFetchStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 1; // 1ms after nav start
    }
    pub fn getDomainLookupStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 5;
    }
    pub fn getDomainLookupEnd(self: *const PerformanceTiming) f64 {
        return self._nav_start + 15;
    }
    pub fn getConnectStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 15;
    }
    pub fn getConnectEnd(self: *const PerformanceTiming) f64 {
        return self._nav_start + 50;
    }
    pub fn getSecureConnectionStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 20;
    }
    pub fn getRequestStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 50;
    }
    pub fn getResponseStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 100;
    }
    pub fn getResponseEnd(self: *const PerformanceTiming) f64 {
        return self._nav_start + 150;
    }
    pub fn getDomLoading(self: *const PerformanceTiming) f64 {
        return self._nav_start + 160;
    }
    pub fn getDomInteractive(self: *const PerformanceTiming) f64 {
        return self._nav_start + 200;
    }
    pub fn getDomContentLoadedEventStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 200;
    }
    pub fn getDomContentLoadedEventEnd(self: *const PerformanceTiming) f64 {
        return self._nav_start + 210;
    }
    pub fn getDomComplete(self: *const PerformanceTiming) f64 {
        return self._nav_start + 300;
    }
    pub fn getLoadEventStart(self: *const PerformanceTiming) f64 {
        return self._nav_start + 300;
    }
    pub fn getLoadEventEnd(self: *const PerformanceTiming) f64 {
        return self._nav_start + 310;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(PerformanceTiming);

        pub const Meta = struct {
            pub const name = "PerformanceTiming";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
            pub const empty_with_no_proto = true;
        };

        pub const navigationStart = bridge.accessor(PerformanceTiming.getNavigationStart, null, .{});
        pub const unloadEventStart = bridge.property(0.0, .{ .template = false, .readonly = true });
        pub const unloadEventEnd = bridge.property(0.0, .{ .template = false, .readonly = true });
        pub const redirectStart = bridge.property(0.0, .{ .template = false, .readonly = true });
        pub const redirectEnd = bridge.property(0.0, .{ .template = false, .readonly = true });
        pub const fetchStart = bridge.accessor(PerformanceTiming.getFetchStart, null, .{});
        pub const domainLookupStart = bridge.accessor(PerformanceTiming.getDomainLookupStart, null, .{});
        pub const domainLookupEnd = bridge.accessor(PerformanceTiming.getDomainLookupEnd, null, .{});
        pub const connectStart = bridge.accessor(PerformanceTiming.getConnectStart, null, .{});
        pub const connectEnd = bridge.accessor(PerformanceTiming.getConnectEnd, null, .{});
        pub const secureConnectionStart = bridge.accessor(PerformanceTiming.getSecureConnectionStart, null, .{});
        pub const requestStart = bridge.accessor(PerformanceTiming.getRequestStart, null, .{});
        pub const responseStart = bridge.accessor(PerformanceTiming.getResponseStart, null, .{});
        pub const responseEnd = bridge.accessor(PerformanceTiming.getResponseEnd, null, .{});
        pub const domLoading = bridge.accessor(PerformanceTiming.getDomLoading, null, .{});
        pub const domInteractive = bridge.accessor(PerformanceTiming.getDomInteractive, null, .{});
        pub const domContentLoadedEventStart = bridge.accessor(PerformanceTiming.getDomContentLoadedEventStart, null, .{});
        pub const domContentLoadedEventEnd = bridge.accessor(PerformanceTiming.getDomContentLoadedEventEnd, null, .{});
        pub const domComplete = bridge.accessor(PerformanceTiming.getDomComplete, null, .{});
        pub const loadEventStart = bridge.accessor(PerformanceTiming.getLoadEventStart, null, .{});
        pub const loadEventEnd = bridge.accessor(PerformanceTiming.getLoadEventEnd, null, .{});
    };
};

// PerformanceNavigation implements the Navigation Timing Level 1 API.
// https://www.w3.org/TR/navigation-timing/#sec-navigation-navigation-timing-interface
// Stub implementation — returns 0 for type (TYPE_NAVIGATE) and 0 for redirectCount.
pub const PerformanceNavigation = struct {
    // Padding to avoid zero-size struct, which causes identity_map pointer collisions.
    _pad: bool = false,

    pub const JsApi = struct {
        pub const bridge = js.Bridge(PerformanceNavigation);

        pub const Meta = struct {
            pub const name = "PerformanceNavigation";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
            pub const empty_with_no_proto = true;
        };

        pub const @"type" = bridge.property(0.0, .{ .template = false, .readonly = true });
        pub const redirectCount = bridge.property(0.0, .{ .template = false, .readonly = true });
    };
};

const testing = @import("../../testing.zig");
test "WebApi: Performance" {
    try testing.htmlRunner("performance.html", .{});
}
