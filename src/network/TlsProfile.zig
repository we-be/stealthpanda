// StealthPanda: TLS fingerprint profiles.
// Cloudflare and other bot detection systems fingerprint the TLS ClientHello
// (JA3/JA4) to verify the claimed browser identity. These profiles configure
// libcurl to match real browser TLS handshakes.

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
};

/// SSL context callback — configures BoringSSL to send Chrome-like extensions
fn sslCtxCallback(_: ?*libcurl.Curl, ssl_ctx: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_uint {
    const ctx: *boringssl.SSL_CTX = @ptrCast(ssl_ctx orelse return 0);
    // Enable OCSP stapling (adds status_request extension to ClientHello)
    boringssl.SSL_CTX_enable_ocsp_stapling(ctx);
    // Enable SCT (adds signed_certificate_timestamp extension)
    boringssl.SSL_CTX_enable_signed_cert_timestamps(ctx);
    // Certificate compression (brotli) - disabled for now as it requires
    // a real brotli decompressor. The status_request and SCT extensions
    // are more impactful for the JA3 fingerprint.
    // TODO: Add brotli decompression for cert compression support.
    return 0; // CURLE_OK
}

/// Dummy brotli decompress function for certificate compression
/// We don't actually need to decompress — we just need the extension in ClientHello
fn dummyDecompress(_: ?*anyopaque, _: ?*anyopaque, _: usize, _: [*c]const u8, _: usize) callconv(.c) c_int {
    return 0; // success (won't actually be called in practice)
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
        const std = @import("std");
        if (std.mem.eql(u8, name, "chrome") or std.mem.eql(u8, name, "chrome_131")) return &chrome_131;
        if (std.mem.eql(u8, name, "firefox") or std.mem.eql(u8, name, "firefox_133")) return &firefox_133;
        return null;
    }
};
