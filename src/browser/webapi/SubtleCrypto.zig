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
const ECDSA = @import("crypto/ECDSA.zig");
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
    log.info(.js, "subtle.sign called", .{ .key_type = key._type, .data_len = data.len });
    return switch (key._type) {
        .hmac => return HMAC.sign(algo, key, data, page),
        .ecdsa => return ECDSA.sign(algo, key, data, page),
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
    log.info(.js, "subtle.verify called", .{ .key_type = key._type, .sig_len = signature.len });
    if (algo.isECDSA()) {
        return switch (key._type) {
            .ecdsa => ECDSA.verify(algo, key, signature, data, page),
            else => page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.InvalidAccessError } }),
        };
    }

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
/// Supports "raw" and "spki" formats for ECDSA, and "raw" for symmetric keys.
pub fn importKey(
    _: *const SubtleCrypto,
    format: []const u8,
    key_data: js.TypedArray(u8),
    algo: ?algorithm.Import,
    extractable: bool,
    _: ?js.Value, // key_usages
    page: *Page,
) !js.Promise {
    const algo_name: []const u8 = if (algo) |a| a.getName() else "null";
    log.info(.js, "subtle.importKey called", .{ .format = format, .algo = algo_name });
    // Check if the algorithm is ECDSA
    if (algo) |a| {
        if (a.isECDSA()) {
            if (std.mem.eql(u8, format, "raw")) {
                const curve = a.getNamedCurve() orelse "P-256";
                return ECDSA.importRawPublicKey(key_data.values, curve, extractable, page);
            }

            if (std.mem.eql(u8, format, "spki")) {
                return ECDSA.importSpkiPublicKey(key_data.values, extractable, page);
            }

            log.warn(.not_implemented, "SubtleCrypto.importKey ECDSA", .{ .format = format });
            return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
        }
    }

    if (!std.mem.eql(u8, format, "raw") and !std.mem.eql(u8, format, "spki")) {
        log.warn(.not_implemented, "SubtleCrypto.importKey", .{ .format = format });
        return page.js.local.?.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    }

    // Copy key bytes to arena so they persist
    const key_copy = try page.arena.dupe(u8, key_data.values);

    // Determine key type from algorithm
    var key_type: CryptoKey.Type = .raw;
    var vary: @TypeOf(@as(CryptoKey, undefined)._vary) = undefined;

    if (algo) |a| {
        const name = a.getName();
        if (std.mem.eql(u8, name, "HMAC")) {
            key_type = .hmac;
            // Get the hash algorithm for HMAC
            const hash_name = switch (a) {
                .hmac_import => |h| switch (h.hash) {
                    .string => |s| s,
                    .object => |o| o.name,
                },
                else => "SHA-256",
            };
            vary = .{ .digest = crypto.findDigest(hash_name) catch crypto.EVP_sha256() };
        }
    }

    const key = try page._factory.create(CryptoKey{
        ._type = key_type,
        ._extractable = extractable,
        ._usages = 0xff, // allow all usages
        ._key = key_copy,
        ._vary = vary,
    });

    return page.js.local.?.resolvePromise(key);
}

/// AES-GCM parameters parsed from JS algorithm object.
const AesGcmParams = struct {
    iv: []const u8,
    tag_length: u8, // in bytes (16 = 128 bits default)
    ad: ?[]const u8, // additional data
};

/// Extract AES-GCM parameters from a JS algorithm value.
fn parseAesGcmAlgo(algo_val: js.Value) ?AesGcmParams {
    if (!algo_val.isObject()) return null;
    const obj = algo_val.toObject();

    // Check name
    const name_val = obj.get("name") catch return null;
    const name_str = name_val.toStringSlice() catch return null;
    if (!std.mem.eql(u8, name_str, "AES-GCM")) return null;

    // Get IV (required)
    const iv_val = obj.get("iv") catch return null;
    if (iv_val.isNullOrUndefined()) return null;
    const iv = extractBytes(iv_val) orelse return null;

    // Get tagLength (optional, default 128 bits)
    var tag_length: u8 = 16; // 128 bits
    const tl_val = obj.get("tagLength") catch null;
    if (tl_val) |tlv| {
        if (!tlv.isNullOrUndefined()) {
            const bits = tlv.toF64() catch 128.0;
            tag_length = @intCast(@as(u64, @intFromFloat(bits)) / 8);
        }
    }

    // Get additionalData (optional)
    var ad: ?[]const u8 = null;
    const ad_val = obj.get("additionalData") catch null;
    if (ad_val) |adv| {
        if (!adv.isNullOrUndefined()) {
            ad = extractBytes(adv);
        }
    }

    return AesGcmParams{ .iv = iv, .tag_length = tag_length, .ad = ad };
}

/// Extract raw bytes from a JS ArrayBuffer, TypedArray, or DataView.
fn extractBytes(val: js.Value) ?[]const u8 {
    if (val.isTypedArray() or val.isUint8Array() or val.isArrayBufferView()) {
        const typed = val.toZig(js.TypedArray(u8)) catch return null;
        return typed.values;
    }
    if (val.isArrayBuffer()) {
        const ab = val.toZig(js.ArrayBuffer) catch return null;
        return ab.values;
    }
    return null;
}

/// Encrypt data using AES-GCM.
pub fn encrypt(
    _: *const SubtleCrypto,
    algo_val: ?js.Value,
    key: *CryptoKey,
    data: js.TypedArray(u8),
    page: *Page,
) !js.Promise {
    const local = page.js.local.?;

    const av = algo_val orelse return local.rejectPromise(.{ .dom_exception = .{ .err = error.SyntaxError } });
    const params = parseAesGcmAlgo(av) orelse {
        log.warn(.not_implemented, "SubtleCrypto.encrypt", .{});
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    };

    const key_bytes = key._key;
    const plaintext = data.values;

    // Output = ciphertext + tag
    const output = try page.call_arena.alloc(u8, plaintext.len + params.tag_length);

    if (key_bytes.len == 16) {
        // AES-128-GCM
        const aes = std.crypto.aead.aes_gcm.Aes128Gcm;
        if (params.iv.len != 12) return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
        var tag: [16]u8 = undefined;
        aes.encrypt(output[0..plaintext.len], &tag, plaintext, params.ad orelse "", params.iv[0..12].*, key_bytes[0..16].*);
        @memcpy(output[plaintext.len..][0..params.tag_length], tag[0..params.tag_length]);
    } else if (key_bytes.len == 32) {
        // AES-256-GCM
        const aes = std.crypto.aead.aes_gcm.Aes256Gcm;
        if (params.iv.len != 12) return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
        var tag: [16]u8 = undefined;
        aes.encrypt(output[0..plaintext.len], &tag, plaintext, params.ad orelse "", params.iv[0..12].*, key_bytes[0..32].*);
        @memcpy(output[plaintext.len..][0..params.tag_length], tag[0..params.tag_length]);
    } else {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
    }

    return local.resolvePromise(js.ArrayBuffer{ .values = output });
}

/// Decrypt data using AES-GCM.
pub fn decrypt(
    _: *const SubtleCrypto,
    algo_val: ?js.Value,
    key: *CryptoKey,
    data: js.TypedArray(u8),
    page: *Page,
) !js.Promise {
    const local = page.js.local.?;

    const av = algo_val orelse return local.rejectPromise(.{ .dom_exception = .{ .err = error.SyntaxError } });
    const params = parseAesGcmAlgo(av) orelse {
        log.warn(.not_implemented, "SubtleCrypto.decrypt", .{});
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    };

    const key_bytes = key._key;
    const ciphertext_with_tag = data.values;

    if (ciphertext_with_tag.len < params.tag_length) {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
    }

    const ciphertext_len = ciphertext_with_tag.len - params.tag_length;
    const ciphertext = ciphertext_with_tag[0..ciphertext_len];
    const tag_slice = ciphertext_with_tag[ciphertext_len..];

    const output = try page.call_arena.alloc(u8, ciphertext_len);

    if (key_bytes.len == 16) {
        const aes = std.crypto.aead.aes_gcm.Aes128Gcm;
        if (params.iv.len != 12) return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
        var tag: [16]u8 = undefined;
        @memcpy(tag[0..params.tag_length], tag_slice[0..params.tag_length]);
        aes.decrypt(output, ciphertext, tag, params.ad orelse "", params.iv[0..12].*, key_bytes[0..16].*) catch {
            return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
        };
    } else if (key_bytes.len == 32) {
        const aes = std.crypto.aead.aes_gcm.Aes256Gcm;
        if (params.iv.len != 12) return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
        var tag: [16]u8 = undefined;
        @memcpy(tag[0..params.tag_length], tag_slice[0..params.tag_length]);
        aes.decrypt(output, ciphertext, tag, params.ad orelse "", params.iv[0..12].*, key_bytes[0..32].*) catch {
            return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
        };
    } else {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.OperationError } });
    }

    return local.resolvePromise(js.ArrayBuffer{ .values = output });
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
