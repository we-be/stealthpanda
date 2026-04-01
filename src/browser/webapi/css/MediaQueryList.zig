// Copyright (C) 2023-2025  Lightpanda (Selecy SAS)
//
// Francis Bouvier <francis@lightpanda.io>
// Pierre Tachoire <pierre@lightpanda.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// zlint-disable unused-decls
const std = @import("std");
const js = @import("../../js/js.zig");
const EventTarget = @import("../EventTarget.zig");

const MediaQueryList = @This();

_proto: *EventTarget,
_media: []const u8,
_matches: bool = true,

pub fn deinit(self: *MediaQueryList) void {
    _ = self;
}

pub fn asEventTarget(self: *MediaQueryList) *EventTarget {
    return self._proto;
}

pub fn getMedia(self: *const MediaQueryList) []const u8 {
    return self._media;
}

pub fn getMatches(self: *const MediaQueryList) bool {
    return self._matches;
}

/// Basic media query evaluation. Handles common queries that bot detection checks.
pub fn evaluateQuery(query: []const u8, screen_width: u32) bool {
    const trimmed = std.mem.trim(u8, query, &std.ascii.whitespace);

    // "(prefers-color-scheme: dark)" -> false (we're light)
    if (std.mem.indexOf(u8, trimmed, "prefers-color-scheme") != null) {
        return std.mem.indexOf(u8, trimmed, "light") != null;
    }

    // "(prefers-reduced-motion: ...)" -> no-preference
    if (std.mem.indexOf(u8, trimmed, "prefers-reduced-motion") != null) {
        return std.mem.indexOf(u8, trimmed, "no-preference") != null;
    }

    // "(min-width: Npx)" -> compare against screen width
    if (std.mem.indexOf(u8, trimmed, "min-width")) |_| {
        if (parsePxValue(trimmed)) |px| {
            return screen_width >= px;
        }
    }

    // "(max-width: Npx)"
    if (std.mem.indexOf(u8, trimmed, "max-width")) |_| {
        if (parsePxValue(trimmed)) |px| {
            return screen_width <= px;
        }
    }

    // "screen", "all", "(color)" -> true
    if (std.mem.eql(u8, trimmed, "screen") or
        std.mem.eql(u8, trimmed, "all") or
        std.mem.eql(u8, trimmed, "(color)"))
    {
        return true;
    }

    // "print" -> false
    if (std.mem.eql(u8, trimmed, "print")) return false;

    // Default: true (most queries should match for a desktop browser)
    return true;
}

fn parsePxValue(query: []const u8) ?u32 {
    // Find a number followed by "px" in the query
    var i: usize = 0;
    while (i < query.len) : (i += 1) {
        if (std.ascii.isDigit(query[i])) {
            var end = i;
            while (end < query.len and std.ascii.isDigit(query[end])) : (end += 1) {}
            if (end + 2 <= query.len and std.mem.eql(u8, query[end .. end + 2], "px")) {
                return std.fmt.parseInt(u32, query[i..end], 10) catch null;
            }
        }
    }
    return null;
}

pub fn addListener(_: *const MediaQueryList, _: js.Function) void {}
pub fn removeListener(_: *const MediaQueryList, _: js.Function) void {}

pub const JsApi = struct {
    pub const bridge = js.Bridge(MediaQueryList);

    pub const Meta = struct {
        pub const name = "MediaQueryList";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const media = bridge.accessor(MediaQueryList.getMedia, null, .{});
    pub const matches = bridge.accessor(MediaQueryList.getMatches, null, .{});
    pub const addListener = bridge.function(MediaQueryList.addListener, .{ .noop = true });
    pub const removeListener = bridge.function(MediaQueryList.removeListener, .{ .noop = true });
};

const testing = @import("../../../testing.zig");
test "WebApi: MediaQueryList" {
    try testing.htmlRunner("css/media_query_list.html", .{});
}
