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
const lp = @import("lightpanda");
const log = @import("../../log.zig");
const crypto = @import("../../sys/libcrypto.zig");

const Page = @import("../Page.zig");
const js = @import("../js/js.zig");

const CryptoKey = @import("CryptoKey.zig");

const algorithm = @import("crypto/algorithm.zig");
const HMAC = @import("crypto/HMAC.zig");
const X25519 = @import("crypto/X25519.zig");

/// The SubtleCrypto interface of the Web Crypto API provides a number of low-level
/// cryptographic functions.
/// https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto
/// https://w3c.github.io/webcrypto/#subtlecrypto-interface
const SubtleCrypto = @This();
/// Don't optimize away the type.
_pad: bool = false,

/// Generate a new key (for symmetric algorithms) or key pair (for public-key algorithms).
pub fn generateKey(
    _: *const SubtleCrypto,
    algo: algorithm.Init,
    extractable: bool,
    key_usages: []const []const u8,
    page: *Page,
) !js.Promise {
    switch (algo) {
        .hmac_key_gen => |params| return HMAC.init(params, extractable, key_usages, page),
        .name => |name| {
            if (std.mem.eql(u8, "X25519", name)) {
                return X25519.init(extractable, key_usages, page);
            }

            log.warn(.not_implemented, "generateKey", .{ .name = name });
        },
        .object => |object| {
            // Ditto.
            const name = object.name;
            if (std.mem.eql(u8, "X25519", name)) {
                return X25519.init(extractable, key_usages, page);
            }

            log.warn(.not_implemented, "generateKey", .{ .name = name });
        },
        else => log.warn(.not_implemented, "generateKey", .{}),
    }

    return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.SyntaxError } });
}

/// Exports a key: that is, it takes as input a CryptoKey object and gives you
/// the key in an external, portable format.
pub fn exportKey(
    _: *const SubtleCrypto,
    format: []const u8,
    key: *CryptoKey,
    page: *Page,
) !js.Promise {
    if (!key.canExportKey()) {
        return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.InvalidAccessError } });
    }

    if (std.mem.eql(u8, format, "raw")) {
        return page.js.local.?.resolvePromise(js.ArrayBuffer{ .values = key._key });
    }

    const is_unsupported = std.mem.eql(u8, format, "pkcs8") or
        std.mem.eql(u8, format, "spki") or std.mem.eql(u8, format, "jwk");

    if (is_unsupported) {
        log.warn(.not_implemented, "SubtleCrypto.exportKey", .{ .format = format });
        return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    }

    return page.js.local.?.rejectPromise(.{ .type_error = "invalid format" });
}

/// Derive a secret key from a master key.
pub fn deriveBits(
    _: *const SubtleCrypto,
    algo: algorithm.Derive,
    base_key: *const CryptoKey, // Private key.
    length: usize,
    page: *Page,
) !js.Promise {
    return switch (algo) {
        .ecdh_or_x25519 => |params| {
            const name = params.name;
            if (std.mem.eql(u8, name, "X25519")) {
                const result = X25519.deriveBits(base_key, params.public, length, page) catch |err| switch (err) {
                    error.InvalidAccessError => return page.js.local.?.rejectPromise(.{
                        .dom_exception = .{ .err = error.InvalidAccessError },
                    }),
                    else => return err,
                };

                return page.js.local.?.resolvePromise(result);
            }

            if (std.mem.eql(u8, name, "ECDH")) {
                log.warn(.not_implemented, "SubtleCrypto.deriveBits", .{ .name = name });
            }

            return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
        },
    };
}

/// Generate a digital signature.
pub fn sign(
    _: *const SubtleCrypto,
    /// https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/sign#algorithm
    algo: algorithm.Sign,
    key: *CryptoKey,
    data: []const u8, // ArrayBuffer.
    page: *Page,
) !js.Promise {
    return switch (key._type) {
        // Call sign for HMAC.
        .hmac => return HMAC.sign(algo, key, data, page),
        else => {
            log.warn(.not_implemented, "SubtleCrypto.sign", .{ .key_type = key._type });
            return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.InvalidAccessError } });
        },
    };
}

/// Verify a digital signature.
pub fn verify(
    _: *const SubtleCrypto,
    algo: algorithm.Sign,
    key: *const CryptoKey,
    signature: []const u8, // ArrayBuffer.
    data: []const u8, // ArrayBuffer.
    page: *Page,
) !js.Promise {
    if (!algo.isHMAC()) {
        return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.InvalidAccessError } });
    }

    return switch (key._type) {
        .hmac => HMAC.verify(key, signature, data, page),
        else => page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.InvalidAccessError } }),
    };
}

/// Generates a digest of the given data, using the specified hash function.
pub fn digest(_: *const SubtleCrypto, algo: []const u8, data: js.TypedArray(u8), page: *Page) !js.Promise {
    const local = page.js.local.?;

    if (algo.len > 10) {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    }

    const normalized = std.ascii.upperString(&page.buf, algo);
    const digest_type = crypto.findDigest(normalized) catch {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    };

    const bytes = data.values;
    const out = page.buf[0..crypto.EVP_MAX_MD_SIZE];
    var out_size: c_uint = 0;
    const result = crypto.EVP_Digest(bytes.ptr, bytes.len, out, &out_size, digest_type, null);
    lp.assert(result == 1, "SubtleCrypto.digest", .{ .algo = algo });

    return local.resolvePromise(js.ArrayBuffer{ .values = out[0..out_size] });
}

/// Import a key from external, portable format.
/// Supports "raw" format for AES keys.
pub fn importKey(
    _: *const SubtleCrypto,
    format: []const u8,
    key_data: js.TypedArray(u8),
    _: ?js.Value, // algo
    extractable: bool,
    _: ?js.Value, // key_usages
    page: *Page,
) !js.Promise {
    if (!std.mem.eql(u8, format, "raw")) {
        log.warn(.not_implemented, "SubtleCrypto.importKey", .{ .format = format });
        return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    }

    // Copy key bytes to arena so they persist
    const key_copy = try page.arena.dupe(u8, key_data.values);

    // Create a CryptoKey with the raw bytes
    const key = try page._factory.create(CryptoKey{
        ._type = .raw,
        ._extractable = extractable,
        ._usages = 0xff, // allow all usages
        ._key = key_copy,
        ._vary = undefined,
    });

    return page.js.local.?.resolvePromise(key);
}

/// Encrypt data using AES-GCM or AES-CBC.
pub fn encrypt(
    _: *const SubtleCrypto,
    algo_val: ?js.Value,
    key_val: ?js.Value,
    data_val: ?js.Value,
    page: *Page,
) !js.Promise {
    _ = algo_val;

    // Get key
    const kv = key_val orelse return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.SyntaxError } });
    _ = kv;

    // Get data
    const dv = data_val orelse return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.SyntaxError } });
    _ = dv;

    // For now, return a stub encrypted result
    // TODO: implement real AES-GCM using std.crypto.aead.aes_gcm
    log.warn(.not_implemented, "SubtleCrypto.encrypt stub", .{});
    return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
}

/// Decrypt data.
pub fn decrypt(_: *const SubtleCrypto, _: ?js.Value, _: ?js.Value, _: ?js.Value, page: *Page) !js.Promise {
    log.warn(.not_implemented, "SubtleCrypto.decrypt", .{});
    return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
}

/// Derive a key from a master key.
pub fn deriveKey(_: *const SubtleCrypto, _: ?js.Value, _: ?js.Value, _: ?js.Value, _: bool, _: ?js.Value, page: *Page) !js.Promise {
    log.warn(.not_implemented, "SubtleCrypto.deriveKey", .{});
    return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
}

/// Wrap a key.
pub fn wrapKey(_: *const SubtleCrypto, _: ?js.Value, _: ?js.Value, _: ?js.Value, _: ?js.Value, page: *Page) !js.Promise {
    log.warn(.not_implemented, "SubtleCrypto.wrapKey", .{});
    return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
}

/// Unwrap a key.
pub fn unwrapKey(_: *const SubtleCrypto, _: ?js.Value, _: ?js.Value, _: ?js.Value, _: ?js.Value, _: ?js.Value, _: bool, _: ?js.Value, page: *Page) !js.Promise {
    log.warn(.not_implemented, "SubtleCrypto.unwrapKey", .{});
    return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
}

pub const JsApi = struct {
    pub const bridge = js.Bridge(SubtleCrypto);

    pub const Meta = struct {
        pub const name = "SubtleCrypto";

        pub var class_id: bridge.ClassId = undefined;
        pub const prototype_chain = bridge.prototypeChain();
    };

    pub const generateKey = bridge.function(SubtleCrypto.generateKey, .{ .dom_exception = true });
    pub const exportKey = bridge.function(SubtleCrypto.exportKey, .{ .dom_exception = true });
    pub const importKey = bridge.function(SubtleCrypto.importKey, .{ .dom_exception = true });
    pub const encrypt = bridge.function(SubtleCrypto.encrypt, .{ .dom_exception = true });
    pub const decrypt = bridge.function(SubtleCrypto.decrypt, .{ .dom_exception = true });
    pub const deriveKey = bridge.function(SubtleCrypto.deriveKey, .{ .dom_exception = true });
    pub const wrapKey = bridge.function(SubtleCrypto.wrapKey, .{ .dom_exception = true });
    pub const unwrapKey = bridge.function(SubtleCrypto.unwrapKey, .{ .dom_exception = true });
    pub const sign = bridge.function(SubtleCrypto.sign, .{ .dom_exception = true });
    pub const verify = bridge.function(SubtleCrypto.verify, .{ .dom_exception = true });
    pub const deriveBits = bridge.function(SubtleCrypto.deriveBits, .{ .dom_exception = true });
    pub const digest = bridge.function(SubtleCrypto.digest, .{ .dom_exception = true });
};
