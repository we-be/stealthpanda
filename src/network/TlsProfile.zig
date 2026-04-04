// StealthPanda: TLS fingerprint profiles.
// Cloudflare and other bot detection systems fingerprint the TLS ClientHello
// (JA3/JA4) to verify the claimed browser identity. These profiles configure
// libcurl to match real browser TLS handshakes.

const std = @import("std");
const libcurl = @import("../sys/libcurl.zig");

// BoringSSL functions for configuring TLS extensions
// These are linked from the boringssl-zig dependency
const boringssl = struct {
    const SSL_CTX = anyopaque;
    // Enable OCSP stapling (status_request extension)
    extern fn SSL_CTX_enable_ocsp_stapling(ctx: *SSL_CTX) void;
    // Enable signed certificate timestamps (SCT extension)
    extern fn SSL_CTX_enable_signed_cert_timestamps(ctx: *SSL_CTX) void;
    // Enable certificate compression (compress_certificate extension)
    // Algorithm ID 2 = brotli
    extern fn SSL_CTX_add_cert_compression_alg(ctx: *SSL_CTX, alg_id: u16, compress: ?*const anyopaque, decompress: ?*const anyopaque) c_int;
    // GREASE: Generate Random Extensions And Sustain Extensibility (RFC 8701)
    // Chrome enables this — adds random GREASE values to cipher suites, extensions, etc.
    extern fn SSL_CTX_set_grease_enabled(ctx: *SSL_CTX, enabled: c_int) void;
    // Extension permutation: randomize extension order in ClientHello (Chrome does this since ~106)
    extern fn SSL_CTX_set_permute_extensions(ctx: *SSL_CTX, enabled: c_int) void;
    // ALPS (Application-Layer Protocol Settings)
    const SSL = anyopaque;
    extern fn SSL_CTX_set_info_callback(ctx: *SSL_CTX, cb: ?*const fn (*SSL, c_int, c_int) callconv(.c) void) void;
    extern fn SSL_add_application_settings(ssl: *SSL, proto: [*]const u8, proto_len: usize, settings: [*]const u8, settings_len: usize) c_int;
    extern fn SSL_set_alps_use_new_codepoint(ssl: *SSL, use_new: c_int) void;
    // ECH GREASE — sends encrypted_client_hello extension in ClientHello
    // Chrome enables this to signal ECH support even without real ECH keys
    extern fn SSL_set_enable_ech_grease(ssl: *SSL, enable: c_int) void;
};

/// SSL context callback — configures BoringSSL to send Chrome-like extensions
fn sslCtxCallback(_: ?*libcurl.Curl, ssl_ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_uint {
    const ctx: *boringssl.SSL_CTX = @ptrCast(ssl_ctx orelse return 0);
    // Enable GREASE (RFC 8701) — Chrome adds random GREASE values
    boringssl.SSL_CTX_set_grease_enabled(ctx, 1);
    // Enable extension permutation — Chrome randomizes extension order (since ~106)
    boringssl.SSL_CTX_set_permute_extensions(ctx, 1);
    // Enable OCSP stapling (adds status_request extension to ClientHello)
    boringssl.SSL_CTX_enable_ocsp_stapling(ctx);
    // Enable SCT (adds signed_certificate_timestamp extension)
    boringssl.SSL_CTX_enable_signed_cert_timestamps(ctx);
    // Enable certificate compression with brotli (adds compress_certificate extension)
    _ = boringssl.SSL_CTX_add_cert_compression_alg(ctx, 2, null, certDecompress);
    // Set info callback for per-connection ALPS configuration
    // The info callback fires with SSL_CB_HANDSHAKE_START (0x10) before ClientHello
    boringssl.SSL_CTX_set_info_callback(ctx, sslInfoCallback);
    return 0; // CURLE_OK
}

// Brotli decompression for BoringSSL certificate compression
const brotli = struct {
    const BrotliDecoderState = anyopaque;
    const BROTLI_DECODER_RESULT_SUCCESS: c_int = 1;

    extern fn BrotliDecoderCreateInstance(
        alloc_func: ?*const anyopaque,
        free_func: ?*const anyopaque,
        user_data: ?*anyopaque,
    ) ?*BrotliDecoderState;

    extern fn BrotliDecoderDestroyInstance(state: *BrotliDecoderState) void;

    extern fn BrotliDecoderDecompress(
        encoded_size: usize,
        encoded_buffer: [*]const u8,
        decoded_size: *usize,
        decoded_buffer: [*]u8,
    ) c_int;
};

/// BoringSSL cert decompression callback using brotli
/// Signature: int (*)(SSL *ssl, CRYPTO_BUFFER **out, size_t uncompressed_len,
///                    const uint8_t *in, size_t in_len)
fn certDecompress(
    _: ?*anyopaque, // ssl
    out: ?*?*anyopaque, // CRYPTO_BUFFER **out
    uncompressed_len: usize,
    in_data: [*c]const u8,
    in_len: usize,
) callconv(.c) c_int {
    // Allocate output buffer via CRYPTO_BUFFER_new
    const CRYPTO_BUFFER_new = @extern(*const fn ([*]const u8, usize, ?*anyopaque) callconv(.c) ?*anyopaque, .{ .name = "CRYPTO_BUFFER_new" });

    // Decompress using brotli
    var decoded_size: usize = uncompressed_len;
    const buf = std.heap.c_allocator.alloc(u8, uncompressed_len) catch return 0;
    defer std.heap.c_allocator.free(buf);

    const result = brotli.BrotliDecoderDecompress(in_len, in_data, &decoded_size, buf.ptr);
    if (result != brotli.BROTLI_DECODER_RESULT_SUCCESS) return 0;
    if (decoded_size != uncompressed_len) return 0;

    // Create CRYPTO_BUFFER with decompressed data
    const cb = CRYPTO_BUFFER_new(buf.ptr, decoded_size, null);
    if (cb == null) return 0;

    if (out) |o| o.* = cb;
    return 1; // success
}

/// Per-connection SSL info callback to enable ALPS before ClientHello
/// SSL_CB_HANDSHAKE_START = 0x10 fires before the ClientHello is constructed
fn sslInfoCallback(ssl: *boringssl.SSL, where: c_int, _: c_int) callconv(.c) void {
    const SSL_CB_HANDSHAKE_START: c_int = 0x10;
    if (where & SSL_CB_HANDSHAKE_START != 0) {
        // Enable ECH GREASE — adds encrypted_client_hello extension (0xfe0d)
        // Chrome 146 enables this to signal ECH support
        boringssl.SSL_set_enable_ech_grease(ssl, 1);
        // Use new ALPS codepoint to match Chrome 146 (fe0d → 44cd in our BoringSSL)
        boringssl.SSL_set_alps_use_new_codepoint(ssl, 1);
        // Add ALPS settings for h2 protocol
        // Chrome sends its H2 SETTINGS via ALPS during the TLS handshake
        _ = boringssl.SSL_add_application_settings(ssl, "h2", 2, "", 0);
    }
}

pub const TlsProfile = struct {
    name: []const u8,
    /// TLS 1.2 cipher suite ordering (CURLOPT_SSL_CIPHER_LIST)
    cipher_list: [:0]const u8,
    /// TLS 1.3 cipher suite ordering (CURLOPT_TLS13_CIPHERS)
    tls13_ciphers: [:0]const u8,
    /// Elliptic curve ordering (CURLOPT_SSL_EC_CURVES)
    ec_curves: [:0]const u8,
    /// HTTP version preference (CURL_HTTP_VERSION_*)
    http_version: c_long,

    pub fn apply(self: *const TlsProfile, easy: *libcurl.Curl) !void {
        libcurl.curl_easy_setopt(easy, .ssl_cipher_list, self.cipher_list.ptr) catch {};
        libcurl.curl_easy_setopt(easy, .tls13_ciphers, self.tls13_ciphers.ptr) catch {};
        libcurl.curl_easy_setopt(easy, .ssl_ec_curves, self.ec_curves.ptr) catch {};
        libcurl.curl_easy_setopt(easy, .http_version, self.http_version) catch {};
        // Enable Chrome-like TLS extensions via SSL_CTX callback
        // This adds status_request, SCT, compress_certificate, etc.
        libcurl.curl_easy_setopt(easy, .ssl_ctx_function, sslCtxCallback) catch {};
        libcurl.curl_easy_setopt(easy, .ssl_ctx_data, @as(?*anyopaque, null)) catch {};
    }

    /// Chrome 131 TLS fingerprint profile.
    /// Cipher suites and curves match Chrome's ClientHello.
    pub const chrome_131: TlsProfile = .{
        .name = "chrome_131",
        .cipher_list = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:" ++
            "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:" ++
            "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:" ++
            "ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:" ++
            "AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA:AES256-SHA",
        .tls13_ciphers = "TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256",
        .ec_curves = "X25519:P-256:P-384",
        // CURL_HTTP_VERSION_2TLS = 4: HTTP/2 for HTTPS, HTTP/1.1 for HTTP
        .http_version = 4,
    };

    /// Firefox 133 TLS fingerprint profile.
    pub const firefox_133: TlsProfile = .{
        .name = "firefox_133",
        .cipher_list = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:" ++
            "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:" ++
            "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:" ++
            "ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:" ++
            "ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:" ++
            "AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA:AES256-SHA",
        .tls13_ciphers = "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        .ec_curves = "X25519:P-256:P-384:P-521",
        // CURL_HTTP_VERSION_2TLS = 4
        .http_version = 4,
    };

    /// Default profile — uses Chrome 131.
    pub const default = chrome_131;

    pub fn fromName(name: []const u8) ?*const TlsProfile {
        if (std.mem.eql(u8, name, "chrome") or std.mem.eql(u8, name, "chrome_131")) return &chrome_131;
        if (std.mem.eql(u8, name, "firefox") or std.mem.eql(u8, name, "firefox_133")) return &firefox_133;
        return null;
    }
};
