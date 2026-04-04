// Copyright (C) 2023-2026 Lightpanda (Selecy SAS)
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

const String = @import("../../string.zig").String;

const js = @import("../js/js.zig");
const Page = @import("../Page.zig");

/// https://developer.mozilla.org/en-US/docs/Web/API/ImageData/ImageData
const ImageData = @This();
_width: u32,
_height: u32,
_data: js.ArrayBufferRef(.uint8_clamped).Global,

pub const ConstructorSettings = struct {
    /// Specifies the color space of the image data.
    /// Can be set to "srgb" for the sRGB color space or "display-p3" for the display-p3 color space.
    colorSpace: String = .wrap("srgb"),
    /// Specifies the pixel format.
    /// https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/createImageData#pixelformat
    pixelFormat: String = .wrap("rgba-unorm8"),
};

/// This has many constructors:
///
/// ```js
/// new ImageData(width, height)
/// new ImageData(width, height, settings)
///
/// new ImageData(dataArray, width)
/// new ImageData(dataArray, width, height)
/// new ImageData(dataArray, width, height, settings)
/// ```
///
/// We currently support only the first 2.
pub fn init(
    width: u32,
    height: u32,
    maybe_settings: ?ConstructorSettings,
    page: *Page,
) !*ImageData {
    // Though arguments are unsigned long, these are capped to max. i32 on Chrome.
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/canvas/image_data.cc#L61
    const max_i32 = std.math.maxInt(i32);
    if (width == 0 or width > max_i32 or height == 0 or height > max_i32) {
        return error.IndexSizeError;
    }

    const settings: ConstructorSettings = maybe_settings orelse .{};
    if (settings.colorSpace.eql(comptime .wrap("srgb")) == false) {
        return error.TypeError;
    }
    if (settings.pixelFormat.eql(comptime .wrap("rgba-unorm8")) == false) {
        return error.TypeError;
    }

    var size, var overflown = @mulWithOverflow(width, height);
    if (overflown == 1) return error.IndexSizeError;
    size, overflown = @mulWithOverflow(size, 4);
    if (overflown == 1) return error.IndexSizeError;

    return page._factory.create(ImageData{
        ._width = width,
        ._height = height,
        ._data = try page.js.local.?.createTypedArray(.uint8_clamped, size).persist(),
    });
}

pub fn getWidth(self: *const ImageData) u32 {
    return self._width;
}

pub fn getHeight(self: *const ImageData) u32 {
    return self._height;
}

pub fn getData(self: *const ImageData) js.ArrayBufferRef(.uint8_clamped).Global {
    return self._data;
}

/// Create an ImageData and fill its pixel buffer from a z2d surface.
/// This is the key function for canvas getImageData() — it must return
/// actual pixel data, not zeros, for canvas fingerprinting to work.
pub fn initFromSurface(
    width: u32,
    height: u32,
    src_pixels: []const u8,
    src_width: usize,
    src_height: usize,
    sx: usize,
    sy: usize,
    page: *Page,
) !*ImageData {
    const max_i32 = std.math.maxInt(i32);
    if (width == 0 or width > max_i32 or height == 0 or height > max_i32) {
        return error.IndexSizeError;
    }

    // Create the ImageData (zero-initialized typed array)
    const image_data = try init(width, height, null, page);

    // Get the backing store data pointer to write pixels directly
    const local = page.js.local.?;
    const ref = image_data._data.local(local);
    // Access the ArrayBuffer through the ArrayBufferView (typed array → array buffer → backing store)
    const v8 = js.v8;
    const ab = v8.v8__ArrayBufferView__Buffer(@ptrCast(ref.handle)) orelse return image_data;
    const shared_ptr = v8.v8__ArrayBuffer__GetBackingStore(ab);
    const bs_handle = v8.std__shared_ptr__v8__BackingStore__get(&shared_ptr) orelse return image_data;
    const data_ptr: ?*anyopaque = v8.v8__BackingStore__Data(bs_handle);
    if (data_ptr == null) return image_data;

    const dst: [*]u8 = @ptrCast(data_ptr.?);
    const uw: usize = @intCast(width);
    const uh: usize = @intCast(height);

    // Copy pixels from source surface
    for (0..uh) |row| {
        const src_y = sy + row;
        if (src_y >= src_height) break;
        for (0..uw) |col| {
            const src_x = sx + col;
            if (src_x >= src_width) break;
            const src_idx = (src_y * src_width + src_x) * 4;
            const dst_idx = (row * uw + col) * 4;
            if (src_idx + 3 < src_pixels.len) {
                dst[dst_idx] = src_pixels[src_idx]; // R
                dst[dst_idx + 1] = src_pixels[src_idx + 1]; // G
                dst[dst_idx + 2] = src_pixels[src_idx + 2]; // B
                dst[dst_idx + 3] = src_pixels[src_idx + 3]; // A
            }
        }
    }

    return image_data;
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(ImageData);

    pub const Meta = struct {
        pub const name = "ImageData";
        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const constructor = bridge.constructor(ImageData.init, .{ .dom_exception = true });

    pub const colorSpace = bridge.property("srgb", .{ .template = false, .readonly = true });
    pub const pixelFormat = bridge.property("rgba-unorm8", .{ .template = false, .readonly = true });

    pub const data = bridge.accessor(ImageData.getData, null, .{});
    pub const width = bridge.accessor(ImageData.getWidth, null, .{});
    pub const height = bridge.accessor(ImageData.getHeight, null, .{});
};

const testing = @import("../../testing.zig");
test "WebApi: ImageData" {
    try testing.htmlRunner("image_data.html", .{});
}
