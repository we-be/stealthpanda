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

//! Interprets `CryptoKey` for ECDSA (P-256, P-384).
//! Supports importKey (raw, spki) and verify/sign operations.
//! Signature format: Web Crypto uses IEEE P1363 (r||s), BoringSSL uses DER.

const std = @import("std");
const lp = @import("lightpanda");
const crypto = @import("../../../sys/libcrypto.zig");
const log = @import("../../../log.zig");

const Page = @import("../../Page.zig");
const js = @import("../../js/js.zig");
const algorithm = @import("algorithm.zig");

const CryptoKey = @import("../CryptoKey.zig");

/// Map a curve name string to a BoringSSL NID.
fn curveNameToNid(curve: []const u8) ?c_int {
    if (std.mem.eql(u8, curve, "P-256")) return crypto.NID_X9_62_prime256v1;
    if (std.mem.eql(u8, curve, "P-384")) return crypto.NID_secp384r1;
    if (std.mem.eql(u8, curve, "P-521")) return crypto.NID_secp521r1;
    return null;
}

/// Return the byte size of the field elements for a given curve.
fn curveFieldSize(curve: []const u8) ?usize {
    if (std.mem.eql(u8, curve, "P-256")) return 32;
    if (std.mem.eql(u8, curve, "P-384")) return 48;
    if (std.mem.eql(u8, curve, "P-521")) return 66;
    return null;
}

/// Import a public key in "raw" format (uncompressed EC point: 0x04 || x || y).
pub fn importRawPublicKey(
    key_data: []const u8,
    curve: []const u8,
    extractable: bool,
    page: *Page,
) !js.Promise {
    const local = page.js.local.?;

    const nid = curveNameToNid(curve) orelse {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.NotSupported } });
    };

    // Create EC_KEY for the curve
    const ec_key = crypto.EC_KEY_new_by_curve_name(nid) orelse {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    };
    errdefer crypto.EC_KEY_free(ec_key);

    // Get the group
    const group = crypto.EC_GROUP_new_by_curve_name(nid) orelse {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    };
    defer crypto.EC_GROUP_free(group);

    // Create EC_POINT and decode the raw point bytes
    const point = crypto.EC_POINT_new(group) orelse {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    };
    defer crypto.EC_POINT_free(point);

    crypto.ERR_clear_error();
    const oct_result = crypto.EC_POINT_oct2point(group, point, key_data.ptr, key_data.len, null);
    if (oct_result != 1) {
        var errbuf: [256]u8 = undefined;
        const err_code = crypto.ERR_get_error();
        crypto.ERR_error_string_n(err_code, &errbuf, errbuf.len);
        const err_msg = std.mem.sliceTo(&errbuf, 0);
        log.err(.js, "ECDSA oct2point fail", .{ .err_msg = err_msg });
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    }

    // Set the public key on the EC_KEY
    const set_result = crypto.EC_KEY_set_public_key(ec_key, point);
    if (set_result != 1) {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    }

    // Wrap in EVP_PKEY
    const pkey = crypto.EVP_PKEY_new() orelse {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    };
    errdefer crypto.EVP_PKEY_free(pkey);

    const assign_result = crypto.EVP_PKEY_set1_EC_KEY(pkey, ec_key);
    if (assign_result != 1) {
        return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
    }

    // Store key data persistently
    const key_copy = try page.arena.dupe(u8, key_data);

    const crypto_key = try page._factory.create(CryptoKey{
        ._type = .ecdsa,
        ._extractable = extractable,
        ._usages = CryptoKey.Usages.verify,
        ._key = key_copy,
        ._vary = .{ .pkey = pkey },
    });

    return local.resolvePromise(crypto_key);
}

// Known SPKI prefixes for EC curves (everything before the 65/97/133-byte EC point)
const p256_spki_prefix = [_]u8{
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,
    0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
};
const p384_spki_prefix = [_]u8{
    0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01,
    0x06, 0x05, 0x2b, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00,
};

/// Try to extract raw EC point bytes from a DER-encoded SPKI by matching known prefixes.
fn extractEcPointFromSpki(key_data: []const u8) ?struct { point: []const u8, curve: []const u8 } {
    // P-256: 26-byte prefix + 65-byte point = 91 bytes
    if (key_data.len == 91 and std.mem.startsWith(u8, key_data, &p256_spki_prefix)) {
        return .{ .point = key_data[26..91], .curve = "P-256" };
    }
    // P-384: 23-byte prefix + 97-byte point = 120 bytes
    if (key_data.len == 120 and std.mem.startsWith(u8, key_data, &p384_spki_prefix)) {
        return .{ .point = key_data[23..120], .curve = "P-384" };
    }
    return null;
}

/// Import a public key in "spki" format (DER-encoded SubjectPublicKeyInfo).
pub fn importSpkiPublicKey(
    key_data: []const u8,
    extractable: bool,
    page: *Page,
) !js.Promise {
    const local = page.js.local.?;

    // Method 1: Try BoringSSL's native CBS parser
    var cbs: crypto.CBS = undefined;
    crypto.CBS_init(&cbs, key_data.ptr, key_data.len);
    if (crypto.EVP_parse_public_key(&cbs)) |pkey| {
        const key_copy = try page.arena.dupe(u8, key_data);
        const crypto_key = try page._factory.create(CryptoKey{
            ._type = .ecdsa,
            ._extractable = extractable,
            ._usages = CryptoKey.Usages.verify,
            ._key = key_copy,
            ._vary = .{ .pkey = pkey },
        });
        return local.resolvePromise(crypto_key);
    }

    // Method 2: Try d2i_PUBKEY (OpenSSL compat)
    var inp: [*]const u8 = key_data.ptr;
    if (crypto.d2i_PUBKEY(null, &inp, @intCast(key_data.len))) |pkey| {
        const key_copy = try page.arena.dupe(u8, key_data);
        const crypto_key = try page._factory.create(CryptoKey{
            ._type = .ecdsa,
            ._extractable = extractable,
            ._usages = CryptoKey.Usages.verify,
            ._key = key_copy,
            ._vary = .{ .pkey = pkey },
        });
        return local.resolvePromise(crypto_key);
    }

    // Method 3: Manual SPKI parsing — extract EC point and use raw import
    if (extractEcPointFromSpki(key_data)) |result| {
        return importRawPublicKey(result.point, result.curve, extractable, page);
    }

    log.err(.js, "ECDSA SPKI all failed", .{ .data_len = key_data.len });
    return local.rejectPromise(.{ .dom_exception = .{ .err = error.DataError } });
}

/// Convert IEEE P1363 signature (r||s fixed-size) to DER format for BoringSSL.
/// Returns the DER-encoded bytes in the provided buffer, or null on failure.
fn p1363ToDer(p1363_sig: []const u8, field_size: usize, der_buf: []u8) ?[]const u8 {
    if (p1363_sig.len != field_size * 2) return null;

    const r_bytes = p1363_sig[0..field_size];
    const s_bytes = p1363_sig[field_size .. field_size * 2];

    // Create BIGNUMs for r and s — ECDSA_SIG_free will own these
    const r_bn = crypto.BN_bin2bn(r_bytes.ptr, @intCast(field_size), crypto.BN_new()) orelse return null;
    const s_bn = crypto.BN_bin2bn(s_bytes.ptr, @intCast(field_size), crypto.BN_new()) orelse {
        crypto.BN_free(r_bn);
        return null;
    };

    const sig = crypto.ECDSA_SIG_new() orelse {
        crypto.BN_free(r_bn);
        crypto.BN_free(s_bn);
        return null;
    };
    defer crypto.ECDSA_SIG_free(sig);

    // Set r and s - ECDSA_SIG_free will free these BIGNUMs
    sig.r = r_bn;
    sig.s = s_bn;

    // DER encode
    var out_ptr: [*]u8 = der_buf.ptr;
    const der_len = crypto.i2d_ECDSA_SIG(sig, &out_ptr);
    if (der_len <= 0) return null;

    return der_buf[0..@intCast(der_len)];
}

/// Verify an ECDSA signature.
/// Expects IEEE P1363 signature format (r||s) as used by Web Crypto API.
pub fn verify(
    algo: algorithm.Sign,
    crypto_key: *const CryptoKey,
    signature: []const u8,
    data: []const u8,
    page: *Page,
) !js.Promise {
    var resolver = page.js.local.?.createPromiseResolver();

    if (!crypto_key.canVerify()) {
        resolver.rejectError("ECDSA.verify", .{ .dom_exception = .{ .err = error.InvalidAccessError } });
        return resolver.promise();
    }

    // Get the hash algorithm
    const hash_name = algo.getHashName() orelse "SHA-256";
    const digest = crypto.findDigest(hash_name) catch {
        resolver.rejectError("ECDSA.verify", .{ .dom_exception = .{ .err = error.NotSupported } });
        return resolver.promise();
    };

    // Determine field size from signature length
    // P-256: 64 bytes (32+32), P-384: 96 bytes (48+48), P-521: 132 bytes (66+66)
    const field_size: usize = signature.len / 2;
    if (field_size != 32 and field_size != 48 and field_size != 66) {
        resolver.resolve("ECDSA.verify", false);
        return resolver.promise();
    }

    // Convert P1363 → DER
    var der_buf: [144]u8 = undefined; // max DER size for P-521
    const der_sig = p1363ToDer(signature, field_size, &der_buf) orelse {
        resolver.resolve("ECDSA.verify", false);
        return resolver.promise();
    };

    // Create digest context
    const md_ctx = crypto.EVP_MD_CTX_new() orelse {
        resolver.rejectError("ECDSA.verify", .{ .dom_exception = .{ .err = error.OperationError } });
        return resolver.promise();
    };
    defer crypto.EVP_MD_CTX_free(md_ctx);

    // Initialize verify
    if (crypto.EVP_DigestVerifyInit(md_ctx, null, digest, null, crypto_key.getKeyObject()) != 1) {
        resolver.resolve("ECDSA.verify", false);
        return resolver.promise();
    }

    // Perform verification
    const result = crypto.EVP_DigestVerify(md_ctx, der_sig.ptr, der_sig.len, data.ptr, data.len);

    resolver.resolve("ECDSA.verify", result == 1);
    return resolver.promise();
}

/// Sign data with ECDSA.
/// Returns IEEE P1363 signature format (r||s) as required by Web Crypto API.
pub fn sign(
    algo: algorithm.Sign,
    crypto_key: *const CryptoKey,
    data: []const u8,
    page: *Page,
) !js.Promise {
    var resolver = page.js.local.?.createPromiseResolver();

    if (!crypto_key.canSign()) {
        resolver.rejectError("ECDSA.sign", .{ .dom_exception = .{ .err = error.InvalidAccessError } });
        return resolver.promise();
    }

    // Get the hash algorithm
    const hash_name = algo.getHashName() orelse "SHA-256";
    const digest = crypto.findDigest(hash_name) catch {
        resolver.rejectError("ECDSA.sign", .{ .dom_exception = .{ .err = error.NotSupported } });
        return resolver.promise();
    };

    // Create digest context
    const md_ctx = crypto.EVP_MD_CTX_new() orelse {
        resolver.rejectError("ECDSA.sign", .{ .dom_exception = .{ .err = error.OperationError } });
        return resolver.promise();
    };
    defer crypto.EVP_MD_CTX_free(md_ctx);

    // Initialize sign
    if (crypto.EVP_DigestSignInit(md_ctx, null, digest, null, crypto_key.getKeyObject()) != 1) {
        resolver.rejectError("ECDSA.sign", .{ .dom_exception = .{ .err = error.OperationError } });
        return resolver.promise();
    }

    // First call to get signature length
    var sig_len: usize = 0;
    if (crypto.EVP_DigestSign(md_ctx, null, &sig_len, data.ptr, data.len) != 1) {
        resolver.rejectError("ECDSA.sign", .{ .dom_exception = .{ .err = error.OperationError } });
        return resolver.promise();
    }

    // Allocate and sign
    const der_sig = try page.call_arena.alloc(u8, sig_len);
    if (crypto.EVP_DigestSign(md_ctx, der_sig.ptr, &sig_len, data.ptr, data.len) != 1) {
        resolver.rejectError("ECDSA.sign", .{ .dom_exception = .{ .err = error.OperationError } });
        return resolver.promise();
    }

    // TODO: Convert DER → P1363 format for Web Crypto compliance
    // For now, return DER directly (some consumers accept both)
    resolver.resolve("ECDSA.sign", js.ArrayBuffer{ .values = der_sig[0..sig_len] });
    return resolver.promise();
}
