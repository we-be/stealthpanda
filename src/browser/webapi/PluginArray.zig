// Copyright (C) 2023-2026  Lightpanda (Selecy SAS)
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

const std = @import("std");
const js = @import("../js/js.zig");
const Page = @import("../Page.zig");
const GenericIterator = @import("collections/iterator.zig").Entry;

pub fn registerTypes() []const type {
    return &.{ PluginArray, Plugin, MimeTypeArray, MimeType, ValueIterator, MimeTypeArray.MimeValueIterator };
}

const PluginArray = @This();

_plugins: [5]Plugin = chrome_plugins,

pub fn refresh(_: *const PluginArray) void {}

pub fn getLength(_: *const PluginArray) u32 {
    return chrome_plugins.len;
}

pub fn getAtIndex(self: *PluginArray, index: usize) ?*Plugin {
    if (index >= chrome_plugins.len) return null;
    return &self._plugins[index];
}

pub fn getByName(self: *PluginArray, name: []const u8) ?*Plugin {
    for (&self._plugins) |*p| {
        if (std.mem.eql(u8, p.name, name)) return p;
    }
    return null;
}

pub fn values(self: *PluginArray, page: *Page) !*ValueIterator {
    return ValueIterator.init(.{ .list = self }, page);
}

pub const ValueIterator = GenericIterator(PluginIterator, null);

const PluginIterator = struct {
    index: u32 = 0,
    list: *PluginArray,

    pub fn next(self: *PluginIterator, _: *Page) ?*Plugin {
        if (self.index >= chrome_plugins.len) return null;
        const plugin = &self.list._plugins[self.index];
        self.index += 1;
        return plugin;
    }
};

pub const Plugin = struct {
    name: [:0]const u8 = "",
    filename: [:0]const u8 = "",
    description: [:0]const u8 = "",
    mime_types: []const MimeType = &.{},

    pub fn getName(self: *const Plugin) [:0]const u8 {
        return self.name;
    }

    pub fn getFilename(self: *const Plugin) [:0]const u8 {
        return self.filename;
    }

    pub fn getDescription(self: *const Plugin) [:0]const u8 {
        return self.description;
    }

    pub fn getLength(self: *const Plugin) u32 {
        return @intCast(self.mime_types.len);
    }

    pub fn getAtIndex(_: *const Plugin, _: usize) ?*MimeType {
        return null;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(Plugin);
        pub const Meta = struct {
            pub const name = "Plugin";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
        };

        pub const name = bridge.accessor(Plugin.getName, null, .{});
        pub const filename = bridge.accessor(Plugin.getFilename, null, .{});
        pub const description = bridge.accessor(Plugin.getDescription, null, .{});
        pub const length = bridge.accessor(Plugin.getLength, null, .{});
        pub const @"[int]" = bridge.indexed(Plugin.getAtIndex, null, .{ .null_as_undefined = true });
    };
};

pub const MimeType = struct {
    type_str: [:0]const u8 = "",
    suffixes: [:0]const u8 = "",
    description: [:0]const u8 = "",

    pub fn getType(self: *const MimeType) [:0]const u8 {
        return self.type_str;
    }

    pub fn getSuffixes(self: *const MimeType) [:0]const u8 {
        return self.suffixes;
    }

    pub fn getDescription(self: *const MimeType) [:0]const u8 {
        return self.description;
    }

    pub const JsApi = struct {
        pub const bridge = js.Bridge(MimeType);
        pub const Meta = struct {
            pub const name = "MimeType";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
            pub const empty_with_no_proto = true;
        };

        pub const @"type" = bridge.accessor(MimeType.getType, null, .{});
        pub const suffixes = bridge.accessor(MimeType.getSuffixes, null, .{});
        pub const description = bridge.accessor(MimeType.getDescription, null, .{});
    };
};

pub const MimeTypeArray = struct {
    _mime_types: [2]MimeType = pdf_mime_types,

    pub fn getLength(_: *const MimeTypeArray) u32 {
        return pdf_mime_types.len;
    }

    pub fn getAtIndex(self: *MimeTypeArray, index: usize) ?*MimeType {
        if (index >= pdf_mime_types.len) return null;
        return &self._mime_types[index];
    }

    pub fn values(self: *MimeTypeArray, page: *Page) !*MimeValueIterator {
        return MimeValueIterator.init(.{ .list = self }, page);
    }

    pub const MimeValueIterator = GenericIterator(MimeIterator, null);

    const MimeIterator = struct {
        index: u32 = 0,
        list: *MimeTypeArray,

        pub fn next(self: *MimeIterator, _: *Page) ?*MimeType {
            if (self.index >= pdf_mime_types.len) return null;
            const mt = &self.list._mime_types[self.index];
            self.index += 1;
            return mt;
        }
    };

    pub const JsApi = struct {
        pub const bridge = js.Bridge(MimeTypeArray);
        pub const Meta = struct {
            pub const name = "MimeTypeArray";
            pub const prototype_chain = bridge.prototypeChain();
            pub var class_id: bridge.ClassId = undefined;
            pub const empty_with_no_proto = true;
        };

        pub const length = bridge.accessor(MimeTypeArray.getLength, null, .{});
        pub const @"[int]" = bridge.indexed(MimeTypeArray.getAtIndex, null, .{ .null_as_undefined = true });
        pub const symbol_iterator = bridge.iterator(MimeTypeArray.values, .{});
    };
};

// Chrome's standard PDF mime types
const pdf_mime_types = [_]MimeType{
    .{ .type_str = "application/pdf", .suffixes = "pdf", .description = "Portable Document Format" },
    .{ .type_str = "text/pdf", .suffixes = "pdf", .description = "Portable Document Format" },
};

// Chrome's 5 standard PDF plugins
const chrome_plugins = [5]Plugin{
    .{ .name = "PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = &pdf_mime_types },
    .{ .name = "Chrome PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = &pdf_mime_types },
    .{ .name = "Chromium PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = &pdf_mime_types },
    .{ .name = "Microsoft Edge PDF Viewer", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = &pdf_mime_types },
    .{ .name = "WebKit built-in PDF", .filename = "internal-pdf-viewer", .description = "Portable Document Format", .mime_types = &pdf_mime_types },
};

pub const JsApi = struct {
    pub const bridge = js.Bridge(PluginArray);

    pub const Meta = struct {
        pub const name = "PluginArray";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
        pub const empty_with_no_proto = true;
    };

    pub const length = bridge.accessor(PluginArray.getLength, null, .{});
    pub const refresh = bridge.function(PluginArray.refresh, .{});
    pub const @"[int]" = bridge.indexed(PluginArray.getAtIndex, null, .{ .null_as_undefined = true });
    pub const @"[str]" = bridge.namedIndexed(PluginArray.getByName, null, null, .{ .null_as_undefined = true });
    pub const symbol_iterator = bridge.iterator(PluginArray.values, .{});
    pub const item = bridge.function(_item, .{});
    fn _item(self: *PluginArray, index: i32) ?*Plugin {
        if (index < 0) {
            return null;
        }
        return self.getAtIndex(@intCast(index));
    }
    pub const namedItem = bridge.function(PluginArray.getByName, .{});
};
