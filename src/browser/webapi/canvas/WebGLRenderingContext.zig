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

const js = @import("../../js/js.zig");
const Page = @import("../../Page.zig");

pub fn registerTypes() []const type {
    return &.{
        WebGLRenderingContext,
        // Extension types should be runtime generated. We might want
        // to revisit this.
        Extension.Type.WEBGL_debug_renderer_info,
        Extension.Type.WEBGL_lose_context,
    };
}

const WebGLRenderingContext = @This();

/// On Chrome and Safari, a call to `getSupportedExtensions` returns total of 39.
/// The reference for it lists lesser number of extensions:
/// https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Using_Extensions#extension_list
pub const Extension = union(enum) {
    ANGLE_instanced_arrays: void,
    EXT_blend_minmax: void,
    EXT_clip_control: void,
    EXT_color_buffer_half_float: void,
    EXT_depth_clamp: void,
    EXT_disjoint_timer_query: void,
    EXT_float_blend: void,
    EXT_frag_depth: void,
    EXT_polygon_offset_clamp: void,
    EXT_shader_texture_lod: void,
    EXT_texture_compression_bptc: void,
    EXT_texture_compression_rgtc: void,
    EXT_texture_filter_anisotropic: void,
    EXT_texture_mirror_clamp_to_edge: void,
    EXT_sRGB: void,
    KHR_parallel_shader_compile: void,
    OES_element_index_uint: void,
    OES_fbo_render_mipmap: void,
    OES_standard_derivatives: void,
    OES_texture_float: void,
    OES_texture_float_linear: void,
    OES_texture_half_float: void,
    OES_texture_half_float_linear: void,
    OES_vertex_array_object: void,
    WEBGL_blend_func_extended: void,
    WEBGL_color_buffer_float: void,
    WEBGL_compressed_texture_astc: void,
    WEBGL_compressed_texture_etc: void,
    WEBGL_compressed_texture_etc1: void,
    WEBGL_compressed_texture_pvrtc: void,
    WEBGL_compressed_texture_s3tc: void,
    WEBGL_compressed_texture_s3tc_srgb: void,
    WEBGL_debug_renderer_info: *Type.WEBGL_debug_renderer_info,
    WEBGL_debug_shaders: void,
    WEBGL_depth_texture: void,
    WEBGL_draw_buffers: void,
    WEBGL_lose_context: *Type.WEBGL_lose_context,
    WEBGL_multi_draw: void,
    WEBGL_polygon_mode: void,

    /// Reified enum type from the fields of this union.
    const Kind = blk: {
        const info = @typeInfo(Extension).@"union";
        const fields = info.fields;
        var items: [fields.len]std.builtin.Type.EnumField = undefined;
        for (fields, 0..) |field, i| {
            items[i] = .{ .name = field.name, .value = i };
        }

        break :blk @Type(.{
            .@"enum" = .{
                .tag_type = std.math.IntFittingRange(0, if (fields.len == 0) 0 else fields.len - 1),
                .fields = &items,
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    };

    /// Returns the `Extension.Kind` by its name.
    fn find(name: []const u8) ?Kind {
        // Just to make you really sad, this function has to be case-insensitive.
        // So here we copy what's being done in `std.meta.stringToEnum` but replace
        // the comparison function.
        const kvs = comptime build_kvs: {
            const T = Extension.Kind;
            const EnumKV = struct { []const u8, T };
            var kvs_array: [@typeInfo(T).@"enum".fields.len]EnumKV = undefined;
            for (@typeInfo(T).@"enum".fields, 0..) |enumField, i| {
                kvs_array[i] = .{ enumField.name, @field(T, enumField.name) };
            }
            break :build_kvs kvs_array[0..];
        };
        const Map = std.StaticStringMapWithEql(Extension.Kind, std.static_string_map.eqlAsciiIgnoreCase);
        const map = Map.initComptime(kvs);
        return map.get(name);
    }

    /// Extension types.
    pub const Type = struct {
        pub const WEBGL_debug_renderer_info = struct {
            _: u8 = 0,
            pub const UNMASKED_VENDOR_WEBGL: u64 = 0x9245;
            pub const UNMASKED_RENDERER_WEBGL: u64 = 0x9246;

            pub const JsApi = struct {
                pub const bridge = js.Bridge(WEBGL_debug_renderer_info);

                pub const Meta = struct {
                    pub const name = "WEBGL_debug_renderer_info";

                    pub const prototype_chain = bridge.prototypeChain();
                    pub var class_id: bridge.ClassId = undefined;
                };

                pub const UNMASKED_VENDOR_WEBGL = bridge.property(WEBGL_debug_renderer_info.UNMASKED_VENDOR_WEBGL, .{ .template = false, .readonly = true });
                pub const UNMASKED_RENDERER_WEBGL = bridge.property(WEBGL_debug_renderer_info.UNMASKED_RENDERER_WEBGL, .{ .template = false, .readonly = true });
            };
        };

        pub const WEBGL_lose_context = struct {
            _: u8 = 0,
            pub fn loseContext(_: *const WEBGL_lose_context) void {}
            pub fn restoreContext(_: *const WEBGL_lose_context) void {}

            pub const JsApi = struct {
                pub const bridge = js.Bridge(WEBGL_lose_context);

                pub const Meta = struct {
                    pub const name = "WEBGL_lose_context";

                    pub const prototype_chain = bridge.prototypeChain();
                    pub var class_id: bridge.ClassId = undefined;
                };

                pub const loseContext = bridge.function(WEBGL_lose_context.loseContext, .{ .noop = true });
                pub const restoreContext = bridge.function(WEBGL_lose_context.restoreContext, .{ .noop = true });
            };
        };
    };
};

/// Returns WebGL parameters. Real WebGL returns polymorphic types but we
/// return strings for bridge compatibility. Bot detection primarily checks
/// Returns WebGL parameters with correct JavaScript types.
/// In Chrome, getParameter returns numbers for numeric params, strings for
/// string params, and null for unknown. CF fingerprinting checks typeof.
pub const WebGLParam = union(enum) {
    int: i32,
    string: []const u8,
    boolean: bool,
    null_val,
};

pub fn getParameter(_: *const WebGLRenderingContext, pname: u32) WebGLParam {
    return switch (pname) {
        // String parameters
        0x9245 => .{ .string = "Google Inc. (NVIDIA)" }, // UNMASKED_VENDOR_WEBGL
        0x9246 => .{ .string = "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)" }, // UNMASKED_RENDERER_WEBGL
        0x1F00 => .{ .string = "WebKit" }, // VENDOR
        0x1F01 => .{ .string = "WebKit WebGL" }, // RENDERER
        0x1F02 => .{ .string = "WebGL 1.0 (OpenGL ES 2.0 Chromium)" }, // VERSION
        0x8B8C => .{ .string = "WebGL GLSL ES 1.0 (OpenGL ES GLSL ES 1.0 Chromium)" }, // SHADING_LANGUAGE_VERSION
        // Integer parameters
        0x0D33 => .{ .int = 16384 }, // MAX_TEXTURE_SIZE
        0x84E8 => .{ .int = 16384 }, // MAX_RENDERBUFFER_SIZE
        0x8869 => .{ .int = 16 }, // MAX_VERTEX_ATTRIBS
        0x8DFB => .{ .int = 4096 }, // MAX_VERTEX_UNIFORM_VECTORS
        0x8DFC => .{ .int = 30 }, // MAX_VARYING_VECTORS
        0x8DFD => .{ .int = 1024 }, // MAX_FRAGMENT_UNIFORM_VECTORS
        0x8872 => .{ .int = 16 }, // MAX_TEXTURE_IMAGE_UNITS
        0x8B4C => .{ .int = 16 }, // MAX_VERTEX_TEXTURE_IMAGE_UNITS
        0x8B4D => .{ .int = 32 }, // MAX_COMBINED_TEXTURE_IMAGE_UNITS
        0x851C => .{ .int = 16384 }, // MAX_CUBE_MAP_TEXTURE_SIZE
        0x0D55 => .{ .int = 8 }, // STENCIL_BITS
        0x0D54 => .{ .int = 24 }, // DEPTH_BITS
        0x0D52 => .{ .int = 8 }, // RED_BITS
        0x0D53 => .{ .int = 8 }, // GREEN_BITS
        0x0D56 => .{ .int = 8 }, // BLUE_BITS
        0x0D57 => .{ .int = 8 }, // ALPHA_BITS
        0x0B71 => .{ .int = 4 }, // DEPTH_FUNC (GL_LESS)
        0x0B72 => .{ .boolean = true }, // DEPTH_WRITEMASK
        0x0BE2 => .{ .boolean = false }, // BLEND
        0x0B44 => .{ .boolean = false }, // CULL_FACE
        0x0B90 => .{ .boolean = false }, // DITHER (off by default in WebGL)
        0x846E => .{ .int = 1 }, // ALIASED_LINE_WIDTH_RANGE (simplified)
        0x846D => .{ .int = 1 }, // ALIASED_POINT_SIZE_RANGE (simplified)
        0x0BA2 => .{ .int = 0 }, // ACTIVE_TEXTURE offset
        0x8038 => .{ .int = 0 }, // SAMPLE_COVERAGE_VALUE
        0x80A9 => .{ .int = 4 }, // SAMPLE_BUFFERS
        0x80AA => .{ .int = 4 }, // SAMPLES
        else => .null_val,
    };
}

/// Enables a WebGL extension.
pub fn getExtension(_: *const WebGLRenderingContext, name: []const u8, page: *Page) !?Extension {
    const tag = Extension.find(name) orelse return null;

    return switch (tag) {
        .WEBGL_debug_renderer_info => {
            const info = try page._factory.create(Extension.Type.WEBGL_debug_renderer_info{});
            return .{ .WEBGL_debug_renderer_info = info };
        },
        .WEBGL_lose_context => {
            const ctx = try page._factory.create(Extension.Type.WEBGL_lose_context{});
            return .{ .WEBGL_lose_context = ctx };
        },
        inline else => |comptime_enum| @unionInit(Extension, @tagName(comptime_enum), {}),
    };
}

/// Returns a list of all the supported WebGL extensions.
pub fn getSupportedExtensions(_: *const WebGLRenderingContext) []const []const u8 {
    return std.meta.fieldNames(Extension.Kind);
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(WebGLRenderingContext);

    pub const Meta = struct {
        pub const name = "WebGLRenderingContext";

        pub const prototype_chain = bridge.prototypeChain();
        pub var class_id: bridge.ClassId = undefined;
    };

    pub const getParameter = bridge.function(WebGLRenderingContext.getParameter, .{});
    pub const getExtension = bridge.function(WebGLRenderingContext.getExtension, .{});
    pub const getSupportedExtensions = bridge.function(WebGLRenderingContext.getSupportedExtensions, .{});

    // WebGL constants — these must be properties on the context object
    // so that JS can do `gl.getParameter(gl.MAX_TEXTURE_SIZE)`
    pub const DEPTH_BUFFER_BIT = bridge.property(@as(u32, 0x00000100), .{ .template = true });
    pub const STENCIL_BUFFER_BIT = bridge.property(@as(u32, 0x00000400), .{ .template = true });
    pub const COLOR_BUFFER_BIT = bridge.property(@as(u32, 0x00004000), .{ .template = true });
    pub const POINTS = bridge.property(@as(u32, 0x0000), .{ .template = true });
    pub const LINES = bridge.property(@as(u32, 0x0001), .{ .template = true });
    pub const LINE_LOOP = bridge.property(@as(u32, 0x0002), .{ .template = true });
    pub const LINE_STRIP = bridge.property(@as(u32, 0x0003), .{ .template = true });
    pub const TRIANGLES = bridge.property(@as(u32, 0x0004), .{ .template = true });
    pub const TRIANGLE_STRIP = bridge.property(@as(u32, 0x0005), .{ .template = true });
    pub const TRIANGLE_FAN = bridge.property(@as(u32, 0x0006), .{ .template = true });
    pub const ZERO = bridge.property(@as(u32, 0), .{ .template = true });
    pub const ONE = bridge.property(@as(u32, 1), .{ .template = true });
    pub const SRC_COLOR = bridge.property(@as(u32, 0x0300), .{ .template = true });
    pub const SRC_ALPHA = bridge.property(@as(u32, 0x0302), .{ .template = true });
    pub const DST_ALPHA = bridge.property(@as(u32, 0x0304), .{ .template = true });
    pub const DST_COLOR = bridge.property(@as(u32, 0x0306), .{ .template = true });
    pub const CULL_FACE = bridge.property(@as(u32, 0x0B44), .{ .template = true });
    pub const BLEND = bridge.property(@as(u32, 0x0BE2), .{ .template = true });
    pub const DITHER = bridge.property(@as(u32, 0x0BD0), .{ .template = true });
    pub const DEPTH_TEST = bridge.property(@as(u32, 0x0B71), .{ .template = true });
    pub const SCISSOR_TEST = bridge.property(@as(u32, 0x0C11), .{ .template = true });
    pub const STENCIL_TEST = bridge.property(@as(u32, 0x0B90), .{ .template = true });
    pub const NO_ERROR = bridge.property(@as(u32, 0), .{ .template = true });
    pub const INVALID_ENUM = bridge.property(@as(u32, 0x0500), .{ .template = true });
    pub const INVALID_VALUE = bridge.property(@as(u32, 0x0501), .{ .template = true });
    pub const INVALID_OPERATION = bridge.property(@as(u32, 0x0502), .{ .template = true });
    pub const OUT_OF_MEMORY = bridge.property(@as(u32, 0x0505), .{ .template = true });
    pub const CW = bridge.property(@as(u32, 0x0900), .{ .template = true });
    pub const CCW = bridge.property(@as(u32, 0x0901), .{ .template = true });
    pub const LINE_WIDTH = bridge.property(@as(u32, 0x0B21), .{ .template = true });
    pub const FRONT = bridge.property(@as(u32, 0x0404), .{ .template = true });
    pub const BACK = bridge.property(@as(u32, 0x0405), .{ .template = true });
    pub const FRONT_AND_BACK = bridge.property(@as(u32, 0x0408), .{ .template = true });
    pub const TEXTURE_2D = bridge.property(@as(u32, 0x0DE1), .{ .template = true });
    pub const TEXTURE0 = bridge.property(@as(u32, 0x84C0), .{ .template = true });
    pub const BYTE = bridge.property(@as(u32, 0x1400), .{ .template = true });
    pub const UNSIGNED_BYTE = bridge.property(@as(u32, 0x1401), .{ .template = true });
    pub const SHORT = bridge.property(@as(u32, 0x1402), .{ .template = true });
    pub const UNSIGNED_SHORT = bridge.property(@as(u32, 0x1403), .{ .template = true });
    pub const INT = bridge.property(@as(u32, 0x1404), .{ .template = true });
    pub const UNSIGNED_INT = bridge.property(@as(u32, 0x1405), .{ .template = true });
    pub const FLOAT = bridge.property(@as(u32, 0x1406), .{ .template = true });
    pub const RGBA = bridge.property(@as(u32, 0x1908), .{ .template = true });
    pub const RGB = bridge.property(@as(u32, 0x1907), .{ .template = true });
    pub const ALPHA = bridge.property(@as(u32, 0x1906), .{ .template = true });
    pub const LUMINANCE = bridge.property(@as(u32, 0x1909), .{ .template = true });
    pub const NEAREST = bridge.property(@as(u32, 0x2600), .{ .template = true });
    pub const LINEAR = bridge.property(@as(u32, 0x2601), .{ .template = true });
    pub const TEXTURE_MAG_FILTER = bridge.property(@as(u32, 0x2800), .{ .template = true });
    pub const TEXTURE_MIN_FILTER = bridge.property(@as(u32, 0x2801), .{ .template = true });
    pub const TEXTURE_WRAP_S = bridge.property(@as(u32, 0x2802), .{ .template = true });
    pub const TEXTURE_WRAP_T = bridge.property(@as(u32, 0x2803), .{ .template = true });
    pub const REPEAT = bridge.property(@as(u32, 0x2901), .{ .template = true });
    pub const CLAMP_TO_EDGE = bridge.property(@as(u32, 0x812F), .{ .template = true });
    pub const FRAMEBUFFER = bridge.property(@as(u32, 0x8D40), .{ .template = true });
    pub const RENDERBUFFER = bridge.property(@as(u32, 0x8D41), .{ .template = true });
    pub const COLOR_ATTACHMENT0 = bridge.property(@as(u32, 0x8CE0), .{ .template = true });
    pub const DEPTH_ATTACHMENT = bridge.property(@as(u32, 0x8D00), .{ .template = true });
    pub const STENCIL_ATTACHMENT = bridge.property(@as(u32, 0x8D20), .{ .template = true });
    pub const FRAMEBUFFER_COMPLETE = bridge.property(@as(u32, 0x8CD5), .{ .template = true });
    pub const ARRAY_BUFFER = bridge.property(@as(u32, 0x8892), .{ .template = true });
    pub const ELEMENT_ARRAY_BUFFER = bridge.property(@as(u32, 0x8893), .{ .template = true });
    pub const STATIC_DRAW = bridge.property(@as(u32, 0x88E4), .{ .template = true });
    pub const DYNAMIC_DRAW = bridge.property(@as(u32, 0x88E8), .{ .template = true });
    pub const VERTEX_SHADER = bridge.property(@as(u32, 0x8B31), .{ .template = true });
    pub const FRAGMENT_SHADER = bridge.property(@as(u32, 0x8B30), .{ .template = true });
    pub const COMPILE_STATUS = bridge.property(@as(u32, 0x8B81), .{ .template = true });
    pub const LINK_STATUS = bridge.property(@as(u32, 0x8B82), .{ .template = true });
    // Critical getParameter constants
    pub const VENDOR = bridge.property(@as(u32, 0x1F00), .{ .template = true });
    pub const RENDERER = bridge.property(@as(u32, 0x1F01), .{ .template = true });
    pub const VERSION = bridge.property(@as(u32, 0x1F02), .{ .template = true });
    pub const SHADING_LANGUAGE_VERSION = bridge.property(@as(u32, 0x8B8C), .{ .template = true });
    pub const MAX_TEXTURE_SIZE = bridge.property(@as(u32, 0x0D33), .{ .template = true });
    pub const MAX_RENDERBUFFER_SIZE = bridge.property(@as(u32, 0x84E8), .{ .template = true });
    pub const MAX_VIEWPORT_DIMS = bridge.property(@as(u32, 0x0D3A), .{ .template = true });
    pub const MAX_VERTEX_ATTRIBS = bridge.property(@as(u32, 0x8869), .{ .template = true });
    pub const MAX_VERTEX_UNIFORM_VECTORS = bridge.property(@as(u32, 0x8DFB), .{ .template = true });
    pub const MAX_VARYING_VECTORS = bridge.property(@as(u32, 0x8DFC), .{ .template = true });
    pub const MAX_FRAGMENT_UNIFORM_VECTORS = bridge.property(@as(u32, 0x8DFD), .{ .template = true });
    pub const MAX_TEXTURE_IMAGE_UNITS = bridge.property(@as(u32, 0x8872), .{ .template = true });
    pub const MAX_VERTEX_TEXTURE_IMAGE_UNITS = bridge.property(@as(u32, 0x8B4C), .{ .template = true });
    pub const MAX_COMBINED_TEXTURE_IMAGE_UNITS = bridge.property(@as(u32, 0x8B4D), .{ .template = true });
    pub const MAX_CUBE_MAP_TEXTURE_SIZE = bridge.property(@as(u32, 0x851C), .{ .template = true });
    pub const DEPTH_BITS = bridge.property(@as(u32, 0x0D56), .{ .template = true });
    pub const STENCIL_BITS = bridge.property(@as(u32, 0x0D57), .{ .template = true });
    pub const RED_BITS = bridge.property(@as(u32, 0x0D52), .{ .template = true });
    pub const GREEN_BITS = bridge.property(@as(u32, 0x0D53), .{ .template = true });
    pub const BLUE_BITS = bridge.property(@as(u32, 0x0D54), .{ .template = true });
    pub const ALPHA_BITS = bridge.property(@as(u32, 0x0D55), .{ .template = true });
    pub const ALIASED_LINE_WIDTH_RANGE = bridge.property(@as(u32, 0x846E), .{ .template = true });
    pub const ALIASED_POINT_SIZE_RANGE = bridge.property(@as(u32, 0x846D), .{ .template = true });
    pub const SAMPLES = bridge.property(@as(u32, 0x80A8), .{ .template = true });
    pub const SAMPLE_BUFFERS = bridge.property(@as(u32, 0x80A9), .{ .template = true });
    pub const SAMPLE_COVERAGE_VALUE = bridge.property(@as(u32, 0x80AA), .{ .template = true });
    // Noop methods that CF might call
    pub const enable = bridge.function(noop2, .{});
    pub const disable = bridge.function(noop2, .{});
    pub const clear = bridge.function(noop2, .{});
    pub const clearColor = bridge.function(noop5, .{});
    pub const viewport = bridge.function(noop5, .{});
    pub const getError = bridge.function(noError, .{});
    pub const createShader = bridge.function(noop2, .{});
    pub const createProgram = bridge.function(noop1, .{});
    pub const createBuffer = bridge.function(noop1, .{});
    pub const createTexture = bridge.function(noop1, .{});
    pub const createFramebuffer = bridge.function(noop1, .{});
    pub const createRenderbuffer = bridge.function(noop1, .{});
    pub const isContextLost = bridge.function(notLost, .{});
};

fn noop1(_: *const WebGLRenderingContext) void {}
fn noop2(_: *const WebGLRenderingContext, _: u32) void {}
fn noop5(_: *const WebGLRenderingContext, _: f64, _: f64, _: f64, _: f64) void {}
fn noError(_: *const WebGLRenderingContext) u32 {
    return 0; // NO_ERROR
}
fn notLost(_: *const WebGLRenderingContext) bool {
    return false;
}

const testing = @import("../../../testing.zig");
test "WebApi: WebGLRenderingContext" {
    try testing.htmlRunner("canvas/webgl_rendering_context.html", .{});
}
