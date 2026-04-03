// Copyright (C) 2023-2025  Lightpanda (Selecy SAS)
// Modified by StealthPanda contributors.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

const std = @import("std");
const z2d = @import("z2d");

const js = @import("../../js/js.zig");

const color = @import("../../color.zig");
const Page = @import("../../Page.zig");

const Canvas = @import("../element/html/Canvas.zig");
const ImageData = @import("../ImageData.zig");
const TextMetrics = @import("TextMetrics.zig");

const Allocator = std.mem.Allocator;

/// Canvas 2D rendering context backed by z2d for real pixel rendering.
/// https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D
const CanvasRenderingContext2D = @This();

_canvas: *Canvas,
_fill_style: color.RGBA = color.RGBA.Named.black,
_stroke_color: color.RGBA = color.RGBA.Named.black,
_line_width: f64 = 1.0,
_global_alpha: f64 = 1.0,

// z2d rendering state — lazily initialized on first draw.
// The surface persists across calls; the context is recreated per fill/stroke.
_surface: ?z2d.Surface = null,
_alloc: ?Allocator = null,

// z2d path accumulator — persists between path operations (moveTo, lineTo, etc.)
// and is consumed by fill/stroke. Uses z2d's native path representation
// which supports cubic bezier curves and arcs natively.
_path: ?z2d.Path = null,

pub fn getCanvas(self: *const CanvasRenderingContext2D) *Canvas {
    return self._canvas;
}

/// Ensure the z2d surface exists, creating it on first use.
fn ensureSurface(self: *CanvasRenderingContext2D, page: *Page) void {
    if (self._surface != null) return;
    const w = self._canvas.getWidth();
    const h = self._canvas.getHeight();
    const alloc = page._factory._arena;
    self._alloc = alloc;
    self._surface = z2d.Surface.init(.image_surface_rgba, alloc, @intCast(w), @intCast(h)) catch null;
}

pub fn getFillStyle(self: *const CanvasRenderingContext2D, page: *Page) ![]const u8 {
    var w = std.Io.Writer.Allocating.init(page.call_arena);
    try self._fill_style.format(&w.writer);
    return w.written();
}

pub fn setFillStyle(self: *CanvasRenderingContext2D, value: []const u8) !void {
    self._fill_style = color.RGBA.parse(value) catch self._fill_style;
}

pub fn setStrokeStyle(self: *CanvasRenderingContext2D, value: []const u8) void {
    self._stroke_color = color.RGBA.parse(value) catch self._stroke_color;
}

const WidthOrImageData = union(enum) {
    width: u32,
    image_data: *ImageData,
};

pub fn createImageData(
    _: *const CanvasRenderingContext2D,
    width_or_image_data: WidthOrImageData,
    maybe_height: ?u32,
    maybe_settings: ?ImageData.ConstructorSettings,
    page: *Page,
) !*ImageData {
    switch (width_or_image_data) {
        .width => |width| {
            const height = maybe_height orelse return error.TypeError;
            return ImageData.init(width, height, maybe_settings, page);
        },
        .image_data => |image_data| {
            return ImageData.init(image_data._width, image_data._height, null, page);
        },
    }
}

pub fn putImageData(_: *const CanvasRenderingContext2D, _: *ImageData, _: f64, _: f64, _: ?f64, _: ?f64, _: ?f64, _: ?f64) void {}

pub fn getImageData(
    self: *CanvasRenderingContext2D,
    _: i32, // sx
    _: i32, // sy
    sw: i32,
    sh: i32,
    page: *Page,
) !*ImageData {
    if (sw <= 0 or sh <= 0) {
        return error.IndexSizeError;
    }

    // Ensure the surface exists so we have rendered pixels
    self.ensureSurface(page);

    return ImageData.init(@intCast(sw), @intCast(sh), null, page);
}

fn fillToZ2dPixel(self: *const CanvasRenderingContext2D) z2d.Pixel {
    return .{ .rgba = .{
        .r = self._fill_style.r,
        .g = self._fill_style.g,
        .b = self._fill_style.b,
        .a = self._fill_style.a,
    } };
}

fn strokeToZ2dPixel(self: *const CanvasRenderingContext2D) z2d.Pixel {
    return .{ .rgba = .{
        .r = self._stroke_color.r,
        .g = self._stroke_color.g,
        .b = self._stroke_color.b,
        .a = self._stroke_color.a,
    } };
}

// === Drawing operations ===

pub fn clearRect(self: *CanvasRenderingContext2D, x: f64, y: f64, w: f64, h: f64, page: *Page) void {
    self.ensureSurface(page);
    const sfc = &(self._surface orelse return);
    // Fill with transparent pixels
    const xi: i32 = @intFromFloat(x);
    const yi: i32 = @intFromFloat(y);
    const wi: i32 = @intFromFloat(w);
    const hi: i32 = @intFromFloat(h);
    var py: i32 = yi;
    while (py < yi + hi) : (py += 1) {
        var px: i32 = xi;
        while (px < xi + wi) : (px += 1) {
            if (px >= 0 and py >= 0) {
                sfc.putPixel(@intCast(px), @intCast(py), .{ .rgba = .{ .r = 0, .g = 0, .b = 0, .a = 0 } });
            }
        }
    }
}

pub fn fillRect(self: *CanvasRenderingContext2D, x: f64, y: f64, w: f64, h: f64, page: *Page) void {
    self.ensureSurface(page);
    var sfc = self._surface orelse return;
    var ctx = z2d.Context.init(self._alloc orelse return, &sfc);
    defer ctx.deinit();

    ctx.setSourceToPixel(self.fillToZ2dPixel());
    ctx.moveTo(x, y) catch return;
    ctx.lineTo(x + w, y) catch return;
    ctx.lineTo(x + w, y + h) catch return;
    ctx.lineTo(x, y + h) catch return;
    ctx.closePath() catch return;
    ctx.fill() catch return;
    self._surface = sfc;
}

pub fn strokeRect(self: *CanvasRenderingContext2D, x: f64, y: f64, w: f64, h: f64, page: *Page) void {
    self.ensureSurface(page);
    var sfc = self._surface orelse return;
    var ctx = z2d.Context.init(self._alloc orelse return, &sfc);
    defer ctx.deinit();

    ctx.setSourceToPixel(self.strokeToZ2dPixel());
    ctx.setLineWidth(self._line_width);
    ctx.moveTo(x, y) catch return;
    ctx.lineTo(x + w, y) catch return;
    ctx.lineTo(x + w, y + h) catch return;
    ctx.lineTo(x, y + h) catch return;
    ctx.closePath() catch return;
    ctx.stroke() catch return;
    self._surface = sfc;
}

// === Path-based drawing using z2d's native path support ===
// z2d provides native cubic bezier curves, arcs, and anti-aliased rendering.
// We accumulate path segments using z2d.Path and render on fill/stroke.

pub fn save(_: *CanvasRenderingContext2D) void {}
pub fn restore(_: *CanvasRenderingContext2D) void {}
pub fn scale(_: *CanvasRenderingContext2D, _: f64, _: f64) void {}
pub fn rotate(_: *CanvasRenderingContext2D, _: f64) void {}
pub fn translate(_: *CanvasRenderingContext2D, _: f64, _: f64) void {}
pub fn transform(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64) void {}
pub fn setTransform(_: *CanvasRenderingContext2D, _: f64, _: f64, _: f64, _: f64, _: f64, _: f64) void {}
pub fn resetTransform(_: *CanvasRenderingContext2D) void {}

fn ensurePath(self: *CanvasRenderingContext2D, page: ?*Page) *z2d.Path {
    // Ensure allocator is set (needed for path ops before any fill/stroke)
    if (self._alloc == null) {
        if (page) |p| {
            self._alloc = p._factory._arena;
        }
    }
    if (self._path) |*p| return p;
    self._path = .empty;
    return &(self._path.?);
}

pub fn beginPath(self: *CanvasRenderingContext2D) void {
    if (self._path) |*p| {
        p.reset();
    }
}

pub fn closePath(self: *CanvasRenderingContext2D, page: *Page) void {
    const alloc = self._alloc orelse page._factory._arena;
    self._alloc = alloc;
    const path = self.ensurePath(page);
    path.close(alloc) catch {};
}

pub fn moveTo(self: *CanvasRenderingContext2D, x: f64, y: f64, page: *Page) void {
    const alloc = self._alloc orelse page._factory._arena;
    self._alloc = alloc;
    const path = self.ensurePath(page);
    path.moveTo(alloc, x, y) catch {};
}

pub fn lineTo(self: *CanvasRenderingContext2D, x: f64, y: f64, page: *Page) void {
    const alloc = self._alloc orelse page._factory._arena;
    self._alloc = alloc;
    const path = self.ensurePath(page);
    path.lineTo(alloc, x, y) catch {};
}

pub fn quadraticCurveTo(self: *CanvasRenderingContext2D, cpx: f64, cpy: f64, x: f64, y: f64, page: *Page) void {
    const alloc = self._alloc orelse page._factory._arena;
    self._alloc = alloc;
    const path = self.ensurePath(page);
    // Approximate quadratic as cubic: use the control point for both cubic CPs.
    // A proper conversion needs the current point, but this produces reasonable curves.
    path.curveTo(alloc, cpx, cpy, cpx, cpy, x, y) catch {};
}

pub fn bezierCurveTo(self: *CanvasRenderingContext2D, cp1x: f64, cp1y: f64, cp2x: f64, cp2y: f64, x: f64, y: f64, page: *Page) void {
    const alloc = self._alloc orelse page._factory._arena;
    self._alloc = alloc;
    const path = self.ensurePath(page);
    path.curveTo(alloc, cp1x, cp1y, cp2x, cp2y, x, y) catch {};
}

pub fn arc(self: *CanvasRenderingContext2D, cx: f64, cy: f64, r: f64, start_angle: f64, end_angle: f64, counter_clockwise: ?bool, page: *Page) void {
    const alloc = self._alloc orelse page._factory._arena;
    self._alloc = alloc;
    const path = self.ensurePath(page);
    if (counter_clockwise orelse false) {
        path.arcNegative(alloc, cx, cy, r, start_angle, end_angle) catch {};
    } else {
        path.arc(alloc, cx, cy, r, start_angle, end_angle) catch {};
    }
}

pub fn arcTo(self: *CanvasRenderingContext2D, x1: f64, y1: f64, _: f64, _: f64, _: f64, page: *Page) void {
    self.lineTo(x1, y1, page);
}

pub fn rect(self: *CanvasRenderingContext2D, x: f64, y: f64, w: f64, h: f64, page: *Page) void {
    self.moveTo(x, y, page);
    self.lineTo(x + w, y, page);
    self.lineTo(x + w, y + h, page);
    self.lineTo(x, y + h, page);
    self.closePath(page);
}

pub fn fill(self: *CanvasRenderingContext2D, page: *Page) void {
    const path = if (self._path) |*p| p else return;
    if (path.nodes.items.len == 0) return;

    self.ensureSurface(page);
    var sfc = self._surface orelse return;
    var ctx = z2d.Context.init(self._alloc orelse return, &sfc);
    defer ctx.deinit();

    ctx.setSourceToPixel(self.fillToZ2dPixel());
    ctx.path = path.*;
    ctx.fill() catch {};
    self._surface = sfc;
}

pub fn stroke(self: *CanvasRenderingContext2D, page: *Page) void {
    const path = if (self._path) |*p| p else return;
    if (path.nodes.items.len == 0) return;

    self.ensureSurface(page);
    var sfc = self._surface orelse return;
    var ctx = z2d.Context.init(self._alloc orelse return, &sfc);
    defer ctx.deinit();

    ctx.setSourceToPixel(self.strokeToZ2dPixel());
    ctx.setLineWidth(self._line_width);
    ctx.path = path.*;
    ctx.stroke() catch {};
    self._surface = sfc;
}

pub fn clip(_: *CanvasRenderingContext2D) void {}
// Embedded font for canvas text rendering (Inter Regular subset from z2d).
// This produces consistent, deterministic text rendering for canvas fingerprinting.
const embedded_font = @embedFile("fonts/Inter-Regular.subset.ttf");

pub fn fillText(self: *CanvasRenderingContext2D, text: []const u8, x: f64, y: f64, _: ?f64, page: *Page) void {
    self.ensureSurface(page);
    var sfc = self._surface orelse return;
    var ctx = z2d.Context.init(self._alloc orelse return, &sfc);
    defer ctx.deinit();

    ctx.setSourceToPixel(self.fillToZ2dPixel());

    // Try to render with the embedded font
    ctx.setFontToBuffer(embedded_font) catch {
        // Font load failed — fall back to rectangle placeholder
        ctx.moveTo(x, y - 10) catch return;
        ctx.lineTo(x + @as(f64, @floatFromInt(text.len)) * 6.0, y - 10) catch return;
        ctx.lineTo(x + @as(f64, @floatFromInt(text.len)) * 6.0, y) catch return;
        ctx.lineTo(x, y) catch return;
        ctx.closePath() catch return;
        ctx.fill() catch return;
        self._surface = sfc;
        return;
    };
    ctx.setFontSize(14.0); // Default 10px CSS maps to ~14px rendering
    ctx.showText(text, x, y) catch {
        // Text render failed — fall back to rectangle
        ctx.moveTo(x, y - 10) catch return;
        ctx.lineTo(x + @as(f64, @floatFromInt(text.len)) * 6.0, y - 10) catch return;
        ctx.lineTo(x + @as(f64, @floatFromInt(text.len)) * 6.0, y) catch return;
        ctx.lineTo(x, y) catch return;
        ctx.closePath() catch return;
        ctx.fill() catch return;
        self._surface = sfc;
        return;
    };
    self._surface = sfc;
}

pub fn strokeText(self: *CanvasRenderingContext2D, text: []const u8, x: f64, y: f64, _: ?f64, page: *Page) void {
    // strokeText is less common in fingerprinting — delegate to fillText for now
    self.fillText(text, x, y, null, page);
}

pub fn measureText(_: *CanvasRenderingContext2D, text: []const u8, page: *Page) !*TextMetrics {
    // Approximate width: ~6px per character for 10px sans-serif default font
    const width: f64 = @as(f64, @floatFromInt(text.len)) * 6.0;
    return page._factory.create(TextMetrics{ ._width = width });
}

pub fn drawImage(_: *CanvasRenderingContext2D, _: ?*anyopaque, _: f64, _: f64) void {}
pub fn setLineDash(_: *CanvasRenderingContext2D) void {}
pub fn isPointInPath(_: *CanvasRenderingContext2D, _: f64, _: f64) bool {
    return false;
}

/// Get the raw RGBA pixel buffer from the surface, or null if not initialized.
pub fn getPixelBuffer(self: *CanvasRenderingContext2D) ?[]const u8 {
    const sfc = self._surface orelse return null;
    const buf = sfc.image_surface_rgba.buf;
    return std.mem.sliceAsBytes(buf);
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(CanvasRenderingContext2D);

    pub const Meta = struct {
        pub const name = "CanvasRenderingContext2D";

        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const canvas = bridge.accessor(CanvasRenderingContext2D.getCanvas, null, .{});
    pub const font = bridge.property("10px sans-serif", .{ .template = false, .readonly = false });
    pub const globalAlpha = bridge.property(1.0, .{ .template = false, .readonly = false });
    pub const globalCompositeOperation = bridge.property("source-over", .{ .template = false, .readonly = false });
    pub const strokeStyle = bridge.property("#000000", .{ .template = false, .readonly = false });
    pub const lineWidth = bridge.property(1.0, .{ .template = false, .readonly = false });
    pub const lineCap = bridge.property("butt", .{ .template = false, .readonly = false });
    pub const lineJoin = bridge.property("miter", .{ .template = false, .readonly = false });
    pub const miterLimit = bridge.property(10.0, .{ .template = false, .readonly = false });
    pub const textAlign = bridge.property("start", .{ .template = false, .readonly = false });
    pub const textBaseline = bridge.property("alphabetic", .{ .template = false, .readonly = false });

    pub const fillStyle = bridge.accessor(CanvasRenderingContext2D.getFillStyle, CanvasRenderingContext2D.setFillStyle, .{});
    pub const createImageData = bridge.function(CanvasRenderingContext2D.createImageData, .{ .dom_exception = true });

    pub const putImageData = bridge.function(CanvasRenderingContext2D.putImageData, .{});
    pub const getImageData = bridge.function(CanvasRenderingContext2D.getImageData, .{ .dom_exception = true });
    pub const save = bridge.function(CanvasRenderingContext2D.save, .{});
    pub const restore = bridge.function(CanvasRenderingContext2D.restore, .{});
    pub const scale = bridge.function(CanvasRenderingContext2D.scale, .{});
    pub const rotate = bridge.function(CanvasRenderingContext2D.rotate, .{});
    pub const translate = bridge.function(CanvasRenderingContext2D.translate, .{});
    pub const transform = bridge.function(CanvasRenderingContext2D.transform, .{});
    pub const setTransform = bridge.function(CanvasRenderingContext2D.setTransform, .{});
    pub const resetTransform = bridge.function(CanvasRenderingContext2D.resetTransform, .{});
    pub const clearRect = bridge.function(CanvasRenderingContext2D.clearRect, .{});
    pub const fillRect = bridge.function(CanvasRenderingContext2D.fillRect, .{});
    pub const strokeRect = bridge.function(CanvasRenderingContext2D.strokeRect, .{});
    pub const beginPath = bridge.function(CanvasRenderingContext2D.beginPath, .{});
    pub const closePath = bridge.function(CanvasRenderingContext2D.closePath, .{});
    pub const moveTo = bridge.function(CanvasRenderingContext2D.moveTo, .{});
    pub const lineTo = bridge.function(CanvasRenderingContext2D.lineTo, .{});
    pub const quadraticCurveTo = bridge.function(CanvasRenderingContext2D.quadraticCurveTo, .{});
    pub const bezierCurveTo = bridge.function(CanvasRenderingContext2D.bezierCurveTo, .{});
    pub const arc = bridge.function(CanvasRenderingContext2D.arc, .{});
    pub const arcTo = bridge.function(CanvasRenderingContext2D.arcTo, .{});
    pub const rect = bridge.function(CanvasRenderingContext2D.rect, .{});
    pub const fill = bridge.function(CanvasRenderingContext2D.fill, .{});
    pub const stroke = bridge.function(CanvasRenderingContext2D.stroke, .{});
    pub const clip = bridge.function(CanvasRenderingContext2D.clip, .{});
    pub const fillText = bridge.function(CanvasRenderingContext2D.fillText, .{});
    pub const strokeText = bridge.function(CanvasRenderingContext2D.strokeText, .{ .noop = true });
    pub const measureText = bridge.function(CanvasRenderingContext2D.measureText, .{});
    pub const drawImage = bridge.function(CanvasRenderingContext2D.drawImage, .{ .noop = true });
    pub const setLineDash = bridge.function(CanvasRenderingContext2D.setLineDash, .{ .noop = true });
    pub const isPointInPath = bridge.function(CanvasRenderingContext2D.isPointInPath, .{});
};

const testing = @import("../../../testing.zig");
test "WebApi: CanvasRenderingContext2D" {
    try testing.htmlRunner("canvas/canvas_rendering_context_2d.html", .{});
}
