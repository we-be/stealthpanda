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

const std = @import("std");
const log = @import("../../../log.zig");
const String = @import("../../../string.zig").String;

const CssParser = @import("../../css/Parser.zig");

const js = @import("../../js/js.zig");
const Page = @import("../../Page.zig");
const Element = @import("../Element.zig");

const Allocator = std.mem.Allocator;

const CSSStyleDeclaration = @This();

_element: ?*Element = null,
_properties: std.DoublyLinkedList = .{},
_is_computed: bool = false,

pub fn init(element: ?*Element, is_computed: bool, page: *Page) !*CSSStyleDeclaration {
    const self = try page._factory.create(CSSStyleDeclaration{
        ._element = element,
        ._is_computed = is_computed,
    });

    // Parse the element's existing style attribute into _properties so that
    // subsequent JS reads and writes see all CSS properties, not just newly
    // added ones.  Computed styles have no inline attribute to parse.
    if (!is_computed) {
        if (element) |el| {
            if (el.getAttributeSafe(comptime .wrap("style"))) |attr_value| {
                var it = CssParser.parseDeclarationsList(attr_value);
                while (it.next()) |declaration| {
                    try self.setPropertyImpl(declaration.name, declaration.value, declaration.important, page);
                }
            }
        }
    }

    return self;
}

pub fn length(self: *const CSSStyleDeclaration) u32 {
    if (self._is_computed) {
        return @intCast(computed_property_names.len);
    }
    return @intCast(self._properties.len());
}

pub fn item(self: *const CSSStyleDeclaration, index: u32) []const u8 {
    if (self._is_computed) {
        if (index < computed_property_names.len) {
            return computed_property_names[index];
        }
        return "";
    }
    var i: u32 = 0;
    var node = self._properties.first;
    while (node) |n| {
        if (i == index) {
            const prop = Property.fromNodeLink(n);
            return prop._name.str();
        }
        i += 1;
        node = n.next;
    }
    return "";
}

pub fn getPropertyValue(self: *const CSSStyleDeclaration, property_name: []const u8, page: *Page) []const u8 {
    const normalized = normalizePropertyName(property_name, &page.buf);
    const wrapped = String.wrap(normalized);
    const prop = self.findProperty(wrapped) orelse {
        // Only return default values for computed styles
        if (self._is_computed) {
            return getDefaultPropertyValue(self, wrapped);
        }
        return "";
    };
    return prop._value.str();
}

pub fn getPropertyPriority(self: *const CSSStyleDeclaration, property_name: []const u8, page: *Page) []const u8 {
    const normalized = normalizePropertyName(property_name, &page.buf);
    const prop = self.findProperty(.wrap(normalized)) orelse return "";
    return if (prop._important) "important" else "";
}

pub fn setProperty(self: *CSSStyleDeclaration, property_name: []const u8, value: []const u8, priority_: ?[]const u8, page: *Page) !void {
    // Validate priority
    const priority = priority_ orelse "";
    const important = if (priority.len > 0) blk: {
        if (!std.ascii.eqlIgnoreCase(priority, "important")) {
            return;
        }
        break :blk true;
    } else false;

    try self.setPropertyImpl(property_name, value, important, page);

    try self.syncStyleAttribute(page);
}

fn setPropertyImpl(self: *CSSStyleDeclaration, property_name: []const u8, value: []const u8, important: bool, page: *Page) !void {
    if (value.len == 0) {
        _ = try self.removePropertyImpl(property_name, page);
        return;
    }

    const normalized = normalizePropertyName(property_name, &page.buf);

    // Normalize the value for canonical serialization
    const normalized_value = try normalizePropertyValue(page.call_arena, normalized, value);

    // Find existing property
    if (self.findProperty(.wrap(normalized))) |existing| {
        existing._value = try String.init(page.arena, normalized_value, .{});
        existing._important = important;
        return;
    }

    // Create new property
    const prop = try page._factory.create(Property{
        ._node = .{},
        ._name = try String.init(page.arena, normalized, .{}),
        ._value = try String.init(page.arena, normalized_value, .{}),
        ._important = important,
    });
    self._properties.append(&prop._node);
}

pub fn removeProperty(self: *CSSStyleDeclaration, property_name: []const u8, page: *Page) ![]const u8 {
    const result = try self.removePropertyImpl(property_name, page);
    try self.syncStyleAttribute(page);
    return result;
}

fn removePropertyImpl(self: *CSSStyleDeclaration, property_name: []const u8, page: *Page) ![]const u8 {
    const normalized = normalizePropertyName(property_name, &page.buf);
    const prop = self.findProperty(.wrap(normalized)) orelse return "";

    // the value might not be on the heap (it could be inlined in the small string
    // optimization), so we need to dupe it.
    const old_value = try page.call_arena.dupe(u8, prop._value.str());
    self._properties.remove(&prop._node);
    page._factory.destroy(prop);
    return old_value;
}

// Serialize current properties back to the element's style attribute so that
// DOM serialization (outerHTML, getAttribute) reflects JS-modified styles.
fn syncStyleAttribute(self: *CSSStyleDeclaration, page: *Page) !void {
    const element = self._element orelse return;
    const css_text = try self.getCssText(page);
    try element.setAttributeSafe(comptime .wrap("style"), .wrap(css_text), page);
}

pub fn getFloat(self: *const CSSStyleDeclaration, page: *Page) []const u8 {
    return self.getPropertyValue("float", page);
}

pub fn setFloat(self: *CSSStyleDeclaration, value_: ?[]const u8, page: *Page) !void {
    try self.setPropertyImpl("float", value_ orelse "", false, page);
    try self.syncStyleAttribute(page);
}

pub fn getCssText(self: *const CSSStyleDeclaration, page: *Page) ![]const u8 {
    var buf = std.Io.Writer.Allocating.init(page.call_arena);
    try self.format(&buf.writer);
    return buf.written();
}

pub fn setCssText(self: *CSSStyleDeclaration, text: []const u8, page: *Page) !void {
    // Clear existing properties
    var node = self._properties.first;
    while (node) |n| {
        const next = n.next;
        const prop = Property.fromNodeLink(n);
        self._properties.remove(n);
        page._factory.destroy(prop);
        node = next;
    }

    // Parse and set new properties
    var it = CssParser.parseDeclarationsList(text);
    while (it.next()) |declaration| {
        try self.setPropertyImpl(declaration.name, declaration.value, declaration.important, page);
    }
    try self.syncStyleAttribute(page);
}

pub fn format(self: *const CSSStyleDeclaration, writer: *std.Io.Writer) !void {
    const node = self._properties.first orelse return;
    try Property.fromNodeLink(node).format(writer);

    var next = node.next;
    while (next) |n| {
        try writer.writeByte(' ');
        try Property.fromNodeLink(n).format(writer);
        next = n.next;
    }
}

pub fn findProperty(self: *const CSSStyleDeclaration, name: String) ?*Property {
    var node = self._properties.first;
    while (node) |n| {
        const prop = Property.fromNodeLink(n);
        if (prop._name.eql(name)) {
            return prop;
        }
        node = n.next;
    }
    return null;
}

fn normalizePropertyName(name: []const u8, buf: []u8) []const u8 {
    if (name.len > buf.len) {
        log.info(.dom, "css.long.name", .{ .name = name });
        return name;
    }
    return std.ascii.lowerString(buf, name);
}

// Normalize CSS property values for canonical serialization
fn normalizePropertyValue(arena: Allocator, property_name: []const u8, value: []const u8) ![]const u8 {
    // Per CSSOM spec, unitless zero in length properties should serialize as "0px"
    if (std.mem.eql(u8, value, "0") and isLengthProperty(property_name)) {
        return "0px";
    }

    // "first baseline" serializes canonically as "baseline" (first is the default)
    if (std.ascii.startsWithIgnoreCase(value, "first baseline")) {
        if (value.len == 14) {
            // Exact match "first baseline"
            return "baseline";
        }
        if (value.len > 14 and value[14] == ' ') {
            // "first baseline X" -> "baseline X"
            return try std.mem.concat(arena, u8, &.{ "baseline", value[14..] });
        }
    }

    // For 2-value shorthand properties, collapse "X X" to "X"
    if (isTwoValueShorthand(property_name)) {
        if (collapseDuplicateValue(value)) |single| {
            return single;
        }
    }

    // Canonicalize anchor-size() function: anchor name (dashed ident) comes before size keyword
    if (std.mem.indexOf(u8, value, "anchor-size(")) |idx| {
        return canonicalizeAnchorSize(arena, value, idx);
    }

    // Canonicalize anchor() function: anchor name (dashed ident) comes before position keyword
    // Note: indexOf finds first occurrence, so we check it's not part of "anchor-size("
    if (std.mem.indexOf(u8, value, "anchor(")) |idx| {
        if (idx == 0 or value[idx - 1] != '-') {
            return canonicalizeAnchor(arena, value, idx);
        }
    }

    return value;
}

// Canonicalize anchor-size() so that the dashed ident (anchor name) comes before the size keyword.
// e.g. "anchor-size(width --foo)" -> "anchor-size(--foo width)"
fn canonicalizeAnchorSize(arena: Allocator, value: []const u8, start_index: usize) ![]const u8 {
    var buf = std.Io.Writer.Allocating.init(arena);

    // Copy everything before the first anchor-size(
    try buf.writer.writeAll(value[0..start_index]);

    var i: usize = start_index;

    while (i < value.len) {
        // Look for "anchor-size("
        if (std.mem.startsWith(u8, value[i..], "anchor-size(")) {
            try buf.writer.writeAll("anchor-size(");
            i += "anchor-size(".len;

            // Parse and canonicalize the arguments
            i = try canonicalizeAnchorFnArgs(value, i, &buf.writer, .anchor_size);
        } else {
            try buf.writer.writeByte(value[i]);
            i += 1;
        }
    }

    return buf.written();
}

const AnchorFnKind = enum { anchor, anchor_size };

// Parse anchor/anchor-size arguments and write them in canonical order
fn canonicalizeAnchorFnArgs(value: []const u8, start: usize, writer: *std.Io.Writer, kind: AnchorFnKind) !usize {
    var i = start;
    var depth: usize = 1;

    // Skip leading whitespace
    while (i < value.len and value[i] == ' ') : (i += 1) {}

    var token_count: usize = 0;
    var comma_pos: ?usize = null;

    var first_token_end: usize = 0;
    var first_token_start: ?usize = null;

    var second_token_end: usize = 0;
    var second_token_start: ?usize = null;

    const args_start = i;
    var in_token = false;

    // First pass: find the structure of arguments before comma/closing paren at depth 1
    while (i < value.len and depth > 0) {
        const c = value[i];

        if (c == '(') {
            depth += 1;
            in_token = true;
            i += 1;
        } else if (c == ')') {
            depth -= 1;
            if (depth == 0) {
                if (in_token) {
                    if (token_count == 0) {
                        first_token_end = i;
                    } else if (token_count == 1) {
                        second_token_end = i;
                    }
                }
                break;
            }
            i += 1;
        } else if (c == ',' and depth == 1) {
            if (in_token) {
                if (token_count == 0) {
                    first_token_end = i;
                } else if (token_count == 1) {
                    second_token_end = i;
                }
            }
            comma_pos = i;
            break;
        } else if (c == ' ') {
            if (in_token and depth == 1) {
                if (token_count == 0) {
                    first_token_end = i;
                    token_count = 1;
                } else if (token_count == 1 and second_token_start != null) {
                    second_token_end = i;
                    token_count = 2;
                }
                in_token = false;
            }
            i += 1;
        } else {
            if (!in_token and depth == 1) {
                if (token_count == 0) {
                    first_token_start = i;
                } else if (token_count == 1) {
                    second_token_start = i;
                }
                in_token = true;
            }
            i += 1;
        }
    }

    // Handle end of tokens
    if (in_token and token_count == 1 and second_token_start != null) {
        second_token_end = i;
        token_count = 2;
    } else if (in_token and token_count == 0) {
        first_token_end = i;
        token_count = 1;
    }

    // Check if we have exactly two tokens that need reordering
    if (token_count == 2) {
        const first_start = first_token_start orelse args_start;
        const second_start = second_token_start orelse first_token_end;

        const first_token = value[first_start..first_token_end];
        const second_token = value[second_start..second_token_end];

        // If second token is a dashed ident, it should come first
        // For anchor-size, also check that first token is a size keyword
        const should_swap = std.mem.startsWith(u8, second_token, "--") and
            (kind == .anchor or isAnchorSizeKeyword(first_token));

        if (should_swap) {
            try writer.writeAll(second_token);
            try writer.writeByte(' ');
            try writer.writeAll(first_token);
        } else {
            try writer.writeAll(first_token);
            try writer.writeByte(' ');
            try writer.writeAll(second_token);
        }
    } else if (first_token_start) |fts| {
        // Single token, just copy it
        try writer.writeAll(value[fts..first_token_end]);
    }

    // Handle comma and fallback value (may contain nested functions)
    if (comma_pos) |cp| {
        try writer.writeAll(", ");
        i = cp + 1;
        // Skip whitespace after comma
        while (i < value.len and value[i] == ' ') : (i += 1) {}

        // Copy the fallback, recursively handling nested anchor/anchor-size
        while (i < value.len and depth > 0) {
            if (std.mem.startsWith(u8, value[i..], "anchor-size(")) {
                try writer.writeAll("anchor-size(");
                i += "anchor-size(".len;
                depth += 1;
                i = try canonicalizeAnchorFnArgs(value, i, writer, .anchor_size);
                depth -= 1;
            } else if (std.mem.startsWith(u8, value[i..], "anchor(")) {
                try writer.writeAll("anchor(");
                i += "anchor(".len;
                depth += 1;
                i = try canonicalizeAnchorFnArgs(value, i, writer, .anchor);
                depth -= 1;
            } else if (value[i] == '(') {
                depth += 1;
                try writer.writeByte(value[i]);
                i += 1;
            } else if (value[i] == ')') {
                depth -= 1;
                if (depth == 0) break;
                try writer.writeByte(value[i]);
                i += 1;
            } else {
                try writer.writeByte(value[i]);
                i += 1;
            }
        }
    }

    // Write closing paren
    try writer.writeByte(')');

    return i + 1; // Skip past the closing paren
}

fn isAnchorSizeKeyword(token: []const u8) bool {
    const keywords = std.StaticStringMap(void).initComptime(.{
        .{ "width", {} },
        .{ "height", {} },
        .{ "block", {} },
        .{ "inline", {} },
        .{ "self-block", {} },
        .{ "self-inline", {} },
    });
    return keywords.has(token);
}

// Canonicalize anchor() so that the dashed ident (anchor name) comes before the position keyword.
// e.g. "anchor(left --foo)" -> "anchor(--foo left)"
fn canonicalizeAnchor(arena: Allocator, value: []const u8, start_index: usize) ![]const u8 {
    var buf = std.Io.Writer.Allocating.init(arena);

    // Copy everything before the first anchor(
    try buf.writer.writeAll(value[0..start_index]);

    var i: usize = start_index;

    while (i < value.len) {
        // Look for "anchor(" but not "anchor-size("
        if (std.mem.startsWith(u8, value[i..], "anchor(") and (i == 0 or value[i - 1] != '-')) {
            try buf.writer.writeAll("anchor(");
            i += "anchor(".len;

            // Parse and canonicalize the arguments
            i = try canonicalizeAnchorFnArgs(value, i, &buf.writer, .anchor);
        } else {
            try buf.writer.writeByte(value[i]);
            i += 1;
        }
    }

    return buf.written();
}

// Check if a value is "X X" (duplicate) and return just "X"
fn collapseDuplicateValue(value: []const u8) ?[]const u8 {
    const space_idx = std.mem.indexOfScalar(u8, value, ' ') orelse return null;
    if (space_idx == 0 or space_idx >= value.len - 1) return null;

    const first = value[0..space_idx];
    const rest = std.mem.trimLeft(u8, value[space_idx + 1 ..], " ");

    // Check if there's only one more value (no additional spaces)
    if (std.mem.indexOfScalar(u8, rest, ' ') != null) return null;

    if (std.mem.eql(u8, first, rest)) {
        return first;
    }
    return null;
}

fn isTwoValueShorthand(name: []const u8) bool {
    const shorthands = std.StaticStringMap(void).initComptime(.{
        .{ "place-content", {} },
        .{ "place-items", {} },
        .{ "place-self", {} },
        .{ "margin-block", {} },
        .{ "margin-inline", {} },
        .{ "padding-block", {} },
        .{ "padding-inline", {} },
        .{ "inset-block", {} },
        .{ "inset-inline", {} },
        .{ "border-block-style", {} },
        .{ "border-inline-style", {} },
        .{ "border-block-width", {} },
        .{ "border-inline-width", {} },
        .{ "border-block-color", {} },
        .{ "border-inline-color", {} },
        .{ "overflow", {} },
        .{ "overscroll-behavior", {} },
        .{ "gap", {} },
        .{ "grid-gap", {} },
        // Scroll
        .{ "scroll-padding-block", {} },
        .{ "scroll-padding-inline", {} },
        .{ "scroll-snap-align", {} },
        // Background/Mask
        .{ "background-size", {} },
        .{ "border-image-repeat", {} },
        .{ "mask-repeat", {} },
        .{ "mask-size", {} },
    });
    return shorthands.has(name);
}

fn isLengthProperty(name: []const u8) bool {
    // Properties that accept <length> or <length-percentage> values
    const length_properties = std.StaticStringMap(void).initComptime(.{
        // Sizing
        .{ "width", {} },
        .{ "height", {} },
        .{ "min-width", {} },
        .{ "min-height", {} },
        .{ "max-width", {} },
        .{ "max-height", {} },
        // Margins
        .{ "margin", {} },
        .{ "margin-top", {} },
        .{ "margin-right", {} },
        .{ "margin-bottom", {} },
        .{ "margin-left", {} },
        .{ "margin-block", {} },
        .{ "margin-block-start", {} },
        .{ "margin-block-end", {} },
        .{ "margin-inline", {} },
        .{ "margin-inline-start", {} },
        .{ "margin-inline-end", {} },
        // Padding
        .{ "padding", {} },
        .{ "padding-top", {} },
        .{ "padding-right", {} },
        .{ "padding-bottom", {} },
        .{ "padding-left", {} },
        .{ "padding-block", {} },
        .{ "padding-block-start", {} },
        .{ "padding-block-end", {} },
        .{ "padding-inline", {} },
        .{ "padding-inline-start", {} },
        .{ "padding-inline-end", {} },
        // Positioning
        .{ "top", {} },
        .{ "right", {} },
        .{ "bottom", {} },
        .{ "left", {} },
        .{ "inset", {} },
        .{ "inset-block", {} },
        .{ "inset-block-start", {} },
        .{ "inset-block-end", {} },
        .{ "inset-inline", {} },
        .{ "inset-inline-start", {} },
        .{ "inset-inline-end", {} },
        // Border
        .{ "border-width", {} },
        .{ "border-top-width", {} },
        .{ "border-right-width", {} },
        .{ "border-bottom-width", {} },
        .{ "border-left-width", {} },
        .{ "border-block-width", {} },
        .{ "border-block-start-width", {} },
        .{ "border-block-end-width", {} },
        .{ "border-inline-width", {} },
        .{ "border-inline-start-width", {} },
        .{ "border-inline-end-width", {} },
        .{ "border-radius", {} },
        .{ "border-top-left-radius", {} },
        .{ "border-top-right-radius", {} },
        .{ "border-bottom-left-radius", {} },
        .{ "border-bottom-right-radius", {} },
        // Text
        .{ "font-size", {} },
        .{ "letter-spacing", {} },
        .{ "word-spacing", {} },
        .{ "text-indent", {} },
        // Flexbox/Grid
        .{ "gap", {} },
        .{ "row-gap", {} },
        .{ "column-gap", {} },
        .{ "flex-basis", {} },
        // Legacy grid aliases
        .{ "grid-column-gap", {} },
        .{ "grid-row-gap", {} },
        // Outline
        .{ "outline", {} },
        .{ "outline-width", {} },
        .{ "outline-offset", {} },
        // Multi-column
        .{ "column-rule-width", {} },
        .{ "column-width", {} },
        // Scroll
        .{ "scroll-margin", {} },
        .{ "scroll-margin-top", {} },
        .{ "scroll-margin-right", {} },
        .{ "scroll-margin-bottom", {} },
        .{ "scroll-margin-left", {} },
        .{ "scroll-padding", {} },
        .{ "scroll-padding-top", {} },
        .{ "scroll-padding-right", {} },
        .{ "scroll-padding-bottom", {} },
        .{ "scroll-padding-left", {} },
        // Shapes
        .{ "shape-margin", {} },
        // Motion path
        .{ "offset-distance", {} },
        // Transforms
        .{ "translate", {} },
        // Animations
        .{ "animation-range-end", {} },
        .{ "animation-range-start", {} },
        // Other
        .{ "border-spacing", {} },
        .{ "text-shadow", {} },
        .{ "box-shadow", {} },
        .{ "baseline-shift", {} },
        .{ "vertical-align", {} },
        .{ "text-decoration-inset", {} },
        .{ "block-step-size", {} },
        // Grid lanes
        .{ "flow-tolerance", {} },
        .{ "column-rule-edge-inset", {} },
        .{ "column-rule-interior-inset", {} },
        .{ "row-rule-edge-inset", {} },
        .{ "row-rule-interior-inset", {} },
        .{ "rule-edge-inset", {} },
        .{ "rule-interior-inset", {} },
    });

    return length_properties.has(name);
}

fn getDefaultPropertyValue(self: *const CSSStyleDeclaration, name: String) []const u8 {
    // For computed styles, return realistic defaults for all standard CSS properties.
    // This is critical for fingerprinting — bot detectors check that getComputedStyle
    // returns the correct number of properties with valid default values.
    const n = name.str();

    // Check explicitly set properties first
    switch (name.len) {
        5 => {
            if (name.eql(comptime .wrap("color"))) {
                const element = self._element orelse return "rgb(0, 0, 0)";
                return getDefaultColor(element);
            }
        },
        7 => {
            if (name.eql(comptime .wrap("opacity"))) return "1";
            if (name.eql(comptime .wrap("display"))) {
                const element = self._element orelse return "block";
                return getDefaultDisplay(element);
            }
        },
        10 => {
            if (name.eql(comptime .wrap("visibility"))) return "visible";
        },
        16 => {
            if (name.eqlSlice("background-color")) return "rgba(0, 0, 0, 0)";
        },
        else => {},
    }

    // For computed styles, return CSS spec defaults for common properties
    if (self._is_computed) {
        if (computed_defaults.get(n)) |default| return default;
    }

    return "";
}

const computed_defaults = std.StaticStringMap([]const u8).initComptime(.{
    .{ "position", "static" },
    .{ "top", "auto" },
    .{ "right", "auto" },
    .{ "bottom", "auto" },
    .{ "left", "auto" },
    .{ "float", "none" },
    .{ "clear", "none" },
    .{ "z-index", "auto" },
    .{ "width", "auto" },
    .{ "height", "auto" },
    .{ "min-width", "0px" },
    .{ "min-height", "0px" },
    .{ "max-width", "none" },
    .{ "max-height", "none" },
    .{ "margin", "0px" },
    .{ "margin-top", "0px" },
    .{ "margin-right", "0px" },
    .{ "margin-bottom", "0px" },
    .{ "margin-left", "0px" },
    .{ "padding", "0px" },
    .{ "padding-top", "0px" },
    .{ "padding-right", "0px" },
    .{ "padding-bottom", "0px" },
    .{ "padding-left", "0px" },
    .{ "border-top-width", "0px" },
    .{ "border-right-width", "0px" },
    .{ "border-bottom-width", "0px" },
    .{ "border-left-width", "0px" },
    .{ "border-top-style", "none" },
    .{ "border-right-style", "none" },
    .{ "border-bottom-style", "none" },
    .{ "border-left-style", "none" },
    .{ "border-top-color", "rgb(0, 0, 0)" },
    .{ "border-right-color", "rgb(0, 0, 0)" },
    .{ "border-bottom-color", "rgb(0, 0, 0)" },
    .{ "border-left-color", "rgb(0, 0, 0)" },
    .{ "border-collapse", "separate" },
    .{ "border-spacing", "0px 0px" },
    .{ "font-family", "\"Times New Roman\"" },
    .{ "font-size", "16px" },
    .{ "font-style", "normal" },
    .{ "font-variant", "normal" },
    .{ "font-weight", "400" },
    .{ "font-stretch", "100%" },
    .{ "line-height", "normal" },
    .{ "letter-spacing", "normal" },
    .{ "word-spacing", "0px" },
    .{ "text-align", "start" },
    .{ "text-decoration", "none solid rgb(0, 0, 0)" },
    .{ "text-decoration-line", "none" },
    .{ "text-decoration-style", "solid" },
    .{ "text-decoration-color", "rgb(0, 0, 0)" },
    .{ "text-indent", "0px" },
    .{ "text-transform", "none" },
    .{ "text-shadow", "none" },
    .{ "white-space", "normal" },
    .{ "word-break", "normal" },
    .{ "word-wrap", "normal" },
    .{ "overflow-wrap", "normal" },
    .{ "overflow", "visible" },
    .{ "overflow-x", "visible" },
    .{ "overflow-y", "visible" },
    .{ "cursor", "auto" },
    .{ "pointer-events", "auto" },
    .{ "user-select", "auto" },
    .{ "vertical-align", "baseline" },
    .{ "box-sizing", "content-box" },
    .{ "background-image", "none" },
    .{ "background-repeat", "repeat" },
    .{ "background-position", "0% 0%" },
    .{ "background-size", "auto" },
    .{ "background-origin", "padding-box" },
    .{ "background-clip", "border-box" },
    .{ "background-attachment", "scroll" },
    .{ "outline-style", "none" },
    .{ "outline-width", "0px" },
    .{ "outline-color", "rgb(0, 0, 0)" },
    .{ "outline-offset", "0px" },
    .{ "box-shadow", "none" },
    .{ "list-style-type", "disc" },
    .{ "list-style-position", "outside" },
    .{ "list-style-image", "none" },
    .{ "table-layout", "auto" },
    .{ "caption-side", "top" },
    .{ "empty-cells", "show" },
    .{ "transform", "none" },
    .{ "transform-origin", "0px 0px" },
    .{ "transition-duration", "0s" },
    .{ "transition-delay", "0s" },
    .{ "transition-property", "all" },
    .{ "transition-timing-function", "ease" },
    .{ "animation-name", "none" },
    .{ "animation-duration", "0s" },
    .{ "animation-delay", "0s" },
    .{ "animation-direction", "normal" },
    .{ "animation-fill-mode", "none" },
    .{ "animation-iteration-count", "1" },
    .{ "animation-play-state", "running" },
    .{ "animation-timing-function", "ease" },
    .{ "flex-direction", "row" },
    .{ "flex-wrap", "nowrap" },
    .{ "flex-grow", "0" },
    .{ "flex-shrink", "1" },
    .{ "flex-basis", "auto" },
    .{ "justify-content", "normal" },
    .{ "align-items", "normal" },
    .{ "align-self", "auto" },
    .{ "align-content", "normal" },
    .{ "order", "0" },
    .{ "grid-template-columns", "none" },
    .{ "grid-template-rows", "none" },
    .{ "gap", "normal" },
    .{ "row-gap", "normal" },
    .{ "column-gap", "normal" },
    .{ "object-fit", "fill" },
    .{ "object-position", "50% 50%" },
    .{ "opacity", "1" },
    .{ "visibility", "visible" },
    .{ "content", "normal" },
    .{ "resize", "none" },
    .{ "appearance", "none" },
    .{ "touch-action", "auto" },
    .{ "will-change", "auto" },
    .{ "contain", "none" },
    .{ "isolation", "auto" },
    .{ "mix-blend-mode", "normal" },
    .{ "filter", "none" },
    .{ "backdrop-filter", "none" },
    .{ "direction", "ltr" },
    .{ "unicode-bidi", "normal" },
    .{ "writing-mode", "horizontal-tb" },
    .{ "accent-color", "auto" },
    .{ "color-scheme", "normal" },
});

fn getDefaultDisplay(element: *const Element) []const u8 {
    switch (element._type) {
        .html => |html| {
            return switch (html._type) {
                .anchor, .br, .span, .label, .time, .font, .mod, .quote => "inline",
                .body, .div, .dl, .p, .heading, .form, .button, .canvas, .details, .dialog, .embed, .head, .html, .hr, .iframe, .img, .input, .li, .link, .meta, .ol, .option, .script, .select, .slot, .style, .template, .textarea, .title, .ul, .media, .area, .base, .datalist, .directory, .fieldset, .legend, .map, .meter, .object, .optgroup, .output, .param, .picture, .pre, .progress, .source, .table, .table_caption, .table_cell, .table_col, .table_row, .table_section, .track => "block",
                .generic, .custom, .unknown, .data => blk: {
                    const tag = element.getTagNameLower();
                    if (isInlineTag(tag)) break :blk "inline";
                    break :blk "block";
                },
            };
        },
        .svg => return "inline",
    }
}

fn isInlineTag(tag_name: []const u8) bool {
    const inline_tags = [_][]const u8{
        "abbr",  "b",    "bdi",    "bdo",  "cite", "code", "dfn",
        "em",    "i",    "kbd",    "mark", "q",    "s",    "samp",
        "small", "span", "strong", "sub",  "sup",  "time", "u",
        "var",   "wbr",
    };

    for (inline_tags) |inline_tag| {
        if (std.mem.eql(u8, tag_name, inline_tag)) {
            return true;
        }
    }
    return false;
}

fn getDefaultColor(element: *const Element) []const u8 {
    switch (element._type) {
        .html => |html| {
            return switch (html._type) {
                .anchor => "rgb(0, 0, 238)", // blue
                else => "rgb(0, 0, 0)",
            };
        },
        .svg => return "rgb(0, 0, 0)",
    }
}

pub const Property = struct {
    _name: String,
    _value: String,
    _important: bool = false,
    _node: std.DoublyLinkedList.Node,

    fn fromNodeLink(n: *std.DoublyLinkedList.Node) *Property {
        return @alignCast(@fieldParentPtr("_node", n));
    }

    pub fn format(self: *const Property, writer: *std.Io.Writer) !void {
        try self._name.format(writer);
        try writer.writeAll(": ");
        try self._value.format(writer);

        if (self._important) {
            try writer.writeAll(" !important");
        }
        try writer.writeByte(';');
    }
};

pub const JsApi = struct {
    pub const bridge = js.Bridge(CSSStyleDeclaration);

    pub const Meta = struct {
        pub const name = "CSSStyleDeclaration";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const cssText = bridge.accessor(CSSStyleDeclaration.getCssText, CSSStyleDeclaration.setCssText, .{});
    pub const length = bridge.accessor(CSSStyleDeclaration.length, null, .{});
    pub const item = bridge.function(_item, .{});

    fn _item(self: *const CSSStyleDeclaration, index: i32) []const u8 {
        if (index < 0) {
            return "";
        }
        return self.item(@intCast(index));
    }

    pub const getPropertyValue = bridge.function(CSSStyleDeclaration.getPropertyValue, .{});
    pub const getPropertyPriority = bridge.function(CSSStyleDeclaration.getPropertyPriority, .{});
    pub const setProperty = bridge.function(CSSStyleDeclaration.setProperty, .{});
    pub const removeProperty = bridge.function(CSSStyleDeclaration.removeProperty, .{});
    pub const cssFloat = bridge.accessor(CSSStyleDeclaration.getFloat, CSSStyleDeclaration.setFloat, .{});
};

// Chrome 131 computed style property names (378 properties).
// Bot detectors check getComputedStyle(el).length — returning the correct count
// is essential to avoid detection.
const computed_property_names = [_][]const u8{
    "accent-color",
    "align-content",
    "align-items",
    "align-self",
    "alignment-baseline",
    "animation-composition",
    "animation-delay",
    "animation-direction",
    "animation-duration",
    "animation-fill-mode",
    "animation-iteration-count",
    "animation-name",
    "animation-play-state",
    "animation-range-end",
    "animation-range-start",
    "animation-timeline",
    "animation-timing-function",
    "app-region",
    "appearance",
    "backdrop-filter",
    "backface-visibility",
    "background-attachment",
    "background-blend-mode",
    "background-clip",
    "background-color",
    "background-image",
    "background-origin",
    "background-position",
    "background-repeat",
    "background-size",
    "baseline-shift",
    "baseline-source",
    "block-size",
    "border-block-end-color",
    "border-block-end-style",
    "border-block-end-width",
    "border-block-start-color",
    "border-block-start-style",
    "border-block-start-width",
    "border-bottom-color",
    "border-bottom-left-radius",
    "border-bottom-right-radius",
    "border-bottom-style",
    "border-bottom-width",
    "border-collapse",
    "border-end-end-radius",
    "border-end-start-radius",
    "border-image-outset",
    "border-image-repeat",
    "border-image-slice",
    "border-image-source",
    "border-image-width",
    "border-inline-end-color",
    "border-inline-end-style",
    "border-inline-end-width",
    "border-inline-start-color",
    "border-inline-start-style",
    "border-inline-start-width",
    "border-left-color",
    "border-left-style",
    "border-left-width",
    "border-right-color",
    "border-right-style",
    "border-right-width",
    "border-spacing",
    "border-start-end-radius",
    "border-start-start-radius",
    "border-top-color",
    "border-top-left-radius",
    "border-top-right-radius",
    "border-top-style",
    "border-top-width",
    "bottom",
    "box-shadow",
    "box-sizing",
    "break-after",
    "break-before",
    "break-inside",
    "buffered-rendering",
    "caption-side",
    "caret-color",
    "clear",
    "clip",
    "clip-path",
    "clip-rule",
    "color",
    "color-interpolation",
    "color-interpolation-filters",
    "color-scheme",
    "column-count",
    "column-gap",
    "column-rule-color",
    "column-rule-style",
    "column-rule-width",
    "column-span",
    "column-width",
    "contain",
    "contain-intrinsic-block-size",
    "contain-intrinsic-height",
    "contain-intrinsic-inline-size",
    "contain-intrinsic-width",
    "container-name",
    "container-type",
    "content",
    "content-visibility",
    "cursor",
    "cx",
    "cy",
    "d",
    "direction",
    "display",
    "dominant-baseline",
    "empty-cells",
    "field-sizing",
    "fill",
    "fill-opacity",
    "fill-rule",
    "filter",
    "flex-basis",
    "flex-direction",
    "flex-grow",
    "flex-shrink",
    "flex-wrap",
    "float",
    "flood-color",
    "flood-opacity",
    "font-family",
    "font-feature-settings",
    "font-kerning",
    "font-optical-sizing",
    "font-palette",
    "font-size",
    "font-size-adjust",
    "font-stretch",
    "font-style",
    "font-synthesis-small-caps",
    "font-synthesis-style",
    "font-synthesis-weight",
    "font-variant",
    "font-variant-alternates",
    "font-variant-caps",
    "font-variant-east-asian",
    "font-variant-ligatures",
    "font-variant-numeric",
    "font-variant-position",
    "font-variation-settings",
    "font-weight",
    "grid-auto-columns",
    "grid-auto-flow",
    "grid-auto-rows",
    "grid-column-end",
    "grid-column-start",
    "grid-row-end",
    "grid-row-start",
    "grid-template-areas",
    "grid-template-columns",
    "grid-template-rows",
    "height",
    "hyphenate-character",
    "hyphenate-limit-chars",
    "hyphens",
    "image-orientation",
    "image-rendering",
    "initial-letter",
    "inline-size",
    "inset-block-end",
    "inset-block-start",
    "inset-inline-end",
    "inset-inline-start",
    "interpolate-size",
    "isolation",
    "justify-content",
    "justify-items",
    "justify-self",
    "left",
    "letter-spacing",
    "lighting-color",
    "line-break",
    "line-height",
    "list-style-image",
    "list-style-position",
    "list-style-type",
    "margin-block-end",
    "margin-block-start",
    "margin-bottom",
    "margin-inline-end",
    "margin-inline-start",
    "margin-left",
    "margin-right",
    "margin-top",
    "marker-end",
    "marker-mid",
    "marker-start",
    "mask-clip",
    "mask-composite",
    "mask-image",
    "mask-mode",
    "mask-origin",
    "mask-position",
    "mask-repeat",
    "mask-size",
    "mask-type",
    "math-depth",
    "math-shift",
    "math-style",
    "max-block-size",
    "max-height",
    "max-inline-size",
    "max-width",
    "min-block-size",
    "min-height",
    "min-inline-size",
    "min-width",
    "mix-blend-mode",
    "object-fit",
    "object-position",
    "object-view-box",
    "offset-anchor",
    "offset-distance",
    "offset-path",
    "offset-position",
    "offset-rotate",
    "opacity",
    "order",
    "orphans",
    "outline-color",
    "outline-offset",
    "outline-style",
    "outline-width",
    "overflow-anchor",
    "overflow-clip-margin",
    "overflow-wrap",
    "overflow-x",
    "overflow-y",
    "overlay",
    "overscroll-behavior-block",
    "overscroll-behavior-inline",
    "padding-block-end",
    "padding-block-start",
    "padding-bottom",
    "padding-inline-end",
    "padding-inline-start",
    "padding-left",
    "padding-right",
    "padding-top",
    "paint-order",
    "perspective",
    "perspective-origin",
    "pointer-events",
    "position",
    "position-anchor",
    "position-area",
    "position-try-fallbacks",
    "position-try-order",
    "position-visibility",
    "r",
    "resize",
    "right",
    "rotate",
    "row-gap",
    "ruby-align",
    "ruby-position",
    "rx",
    "ry",
    "scale",
    "scroll-behavior",
    "scroll-margin-block-end",
    "scroll-margin-block-start",
    "scroll-margin-bottom",
    "scroll-margin-inline-end",
    "scroll-margin-inline-start",
    "scroll-margin-left",
    "scroll-margin-right",
    "scroll-margin-top",
    "scroll-padding-block-end",
    "scroll-padding-block-start",
    "scroll-padding-bottom",
    "scroll-padding-inline-end",
    "scroll-padding-inline-start",
    "scroll-padding-left",
    "scroll-padding-right",
    "scroll-padding-top",
    "scroll-snap-align",
    "scroll-snap-stop",
    "scroll-snap-type",
    "scrollbar-color",
    "scrollbar-gutter",
    "scrollbar-width",
    "shape-image-threshold",
    "shape-margin",
    "shape-outside",
    "shape-rendering",
    "speak",
    "stop-color",
    "stop-opacity",
    "stroke",
    "stroke-dasharray",
    "stroke-dashoffset",
    "stroke-linecap",
    "stroke-linejoin",
    "stroke-miterlimit",
    "stroke-opacity",
    "stroke-width",
    "tab-size",
    "table-layout",
    "text-align",
    "text-align-last",
    "text-anchor",
    "text-combine-upright",
    "text-decoration-color",
    "text-decoration-line",
    "text-decoration-skip-ink",
    "text-decoration-style",
    "text-decoration-thickness",
    "text-emphasis-color",
    "text-emphasis-position",
    "text-emphasis-style",
    "text-indent",
    "text-orientation",
    "text-overflow",
    "text-rendering",
    "text-shadow",
    "text-size-adjust",
    "text-spacing-trim",
    "text-transform",
    "text-underline-offset",
    "text-underline-position",
    "text-wrap-mode",
    "text-wrap-style",
    "top",
    "touch-action",
    "transform",
    "transform-origin",
    "transform-style",
    "transition-behavior",
    "transition-delay",
    "transition-duration",
    "transition-property",
    "transition-timing-function",
    "translate",
    "unicode-bidi",
    "user-select",
    "vector-effect",
    "vertical-align",
    "view-timeline-axis",
    "view-timeline-inset",
    "view-timeline-name",
    "view-transition-class",
    "view-transition-name",
    "visibility",
    "white-space-collapse",
    "widows",
    "width",
    "will-change",
    "word-break",
    "word-spacing",
    "writing-mode",
    "x",
    "y",
    "z-index",
    "zoom",
    "-webkit-border-image",
    "-webkit-box-align",
    "-webkit-box-decoration-break",
    "-webkit-box-direction",
    "-webkit-box-flex",
    "-webkit-box-ordinal-group",
    "-webkit-box-orient",
    "-webkit-box-pack",
    "-webkit-box-reflect",
    "-webkit-font-smoothing",
    "-webkit-line-break",
    "-webkit-line-clamp",
    "-webkit-locale",
    "-webkit-mask-box-image-outset",
    "-webkit-mask-box-image-repeat",
    "-webkit-mask-box-image-slice",
    "-webkit-mask-box-image-source",
    "-webkit-mask-box-image-width",
    "-webkit-print-color-adjust",
    "-webkit-rtl-ordering",
    "-webkit-tap-highlight-color",
    "-webkit-text-combine",
    "-webkit-text-decorations-in-effect",
    "-webkit-text-fill-color",
    "-webkit-text-security",
    "-webkit-text-stroke-color",
    "-webkit-text-stroke-width",
    "-webkit-user-drag",
    "-webkit-user-modify",
    "-webkit-writing-mode",
};

const testing = @import("../../../testing.zig");
test "normalizePropertyValue: unitless zero to 0px" {
    const cases = .{
        .{ "width", "0", "0px" },
        .{ "height", "0", "0px" },
        .{ "scroll-margin-top", "0", "0px" },
        .{ "scroll-padding-bottom", "0", "0px" },
        .{ "column-width", "0", "0px" },
        .{ "column-rule-width", "0", "0px" },
        .{ "outline", "0", "0px" },
        .{ "shape-margin", "0", "0px" },
        .{ "offset-distance", "0", "0px" },
        .{ "translate", "0", "0px" },
        .{ "grid-column-gap", "0", "0px" },
        .{ "grid-row-gap", "0", "0px" },
        // Non-length properties should NOT normalize
        .{ "opacity", "0", "0" },
        .{ "z-index", "0", "0" },
    };
    inline for (cases) |case| {
        const result = try normalizePropertyValue(testing.allocator, case[0], case[1]);
        try testing.expectEqual(case[2], result);
    }
}

test "normalizePropertyValue: first baseline to baseline" {
    const result = try normalizePropertyValue(testing.allocator, "align-items", "first baseline");
    try testing.expectEqual("baseline", result);

    const result2 = try normalizePropertyValue(testing.allocator, "align-self", "last baseline");
    try testing.expectEqual("last baseline", result2);
}

test "normalizePropertyValue: collapse duplicate two-value shorthands" {
    const cases = .{
        .{ "overflow", "hidden hidden", "hidden" },
        .{ "gap", "10px 10px", "10px" },
        .{ "scroll-snap-align", "start start", "start" },
        .{ "scroll-padding-block", "5px 5px", "5px" },
        .{ "background-size", "auto auto", "auto" },
        .{ "overscroll-behavior", "auto auto", "auto" },
        // Different values should NOT collapse
        .{ "overflow", "hidden scroll", "hidden scroll" },
        .{ "gap", "10px 20px", "10px 20px" },
    };
    inline for (cases) |case| {
        const result = try normalizePropertyValue(testing.allocator, case[0], case[1]);
        try testing.expectEqual(case[2], result);
    }
}

test "normalizePropertyValue: anchor() canonical order" {
    defer testing.reset();
    const cases = .{
        // Dashed ident should come before keyword
        .{ "left", "anchor(left --foo)", "anchor(--foo left)" },
        .{ "left", "anchor(inside --foo)", "anchor(--foo inside)" },
        .{ "left", "anchor(50% --foo)", "anchor(--foo 50%)" },
        // Already canonical order - keep as-is
        .{ "left", "anchor(--foo left)", "anchor(--foo left)" },
        .{ "left", "anchor(left)", "anchor(left)" },
        // With fallback
        .{ "left", "anchor(left --foo, 1px)", "anchor(--foo left, 1px)" },
        // Nested anchor in fallback
        .{ "left", "anchor(left --foo, anchor(right --bar))", "anchor(--foo left, anchor(--bar right))" },
    };
    inline for (cases) |case| {
        const result = try normalizePropertyValue(testing.arena_allocator, case[0], case[1]);
        try testing.expectEqual(case[2], result);
    }
}
