// Minimal PNG encoder for Canvas toDataURL().
// Produces valid PNG from raw RGBA pixel data using store-only zlib.

const std = @import("std");

const PNG_SIGNATURE = "\x89PNG\r\n\x1a\n";

/// Encode RGBA pixel data as PNG, return base64-encoded data URL.
pub fn encodeToDataURL(alloc: std.mem.Allocator, rgba: []const u8, width: u32, height: u32) ![]const u8 {
    var png_buf: std.ArrayList(u8) = .empty;
    defer png_buf.deinit(alloc);

    try png_buf.appendSlice(alloc, PNG_SIGNATURE);

    // IHDR chunk
    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], width, .big);
    std.mem.writeInt(u32, ihdr[4..8], height, .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 6; // color type: RGBA
    ihdr[10] = 0; // compression
    ihdr[11] = 0; // filter
    ihdr[12] = 0; // interlace
    try writeChunk(alloc, &png_buf, "IHDR", &ihdr);

    // Build raw scanline data (filter byte 0 + row data for each row)
    const row_bytes = width * 4;
    const row_size = row_bytes + 1; // +1 for filter byte
    const raw_size: usize = row_size * height;
    const raw = try alloc.alloc(u8, raw_size);
    defer alloc.free(raw);

    for (0..height) |y| {
        const row_start = y * row_size;
        raw[row_start] = 0; // filter: None
        const src_start = y * row_bytes;
        const src_end = src_start + row_bytes;
        if (src_end <= rgba.len) {
            @memcpy(raw[row_start + 1 .. row_start + row_size], rgba[src_start..src_end]);
        } else {
            @memset(raw[row_start + 1 .. row_start + row_size], 0);
        }
    }

    // IDAT: wrap raw data in zlib stored blocks (no compression)
    var idat_buf: std.ArrayList(u8) = .empty;
    defer idat_buf.deinit(alloc);
    try zlibStore(alloc, &idat_buf, raw);

    try writeChunk(alloc, &png_buf, "IDAT", idat_buf.items);

    // IEND
    try writeChunk(alloc, &png_buf, "IEND", &.{});

    // Base64 encode to data URL
    const b64_len = std.base64.standard.Encoder.calcSize(png_buf.items.len);
    const prefix = "data:image/png;base64,";
    const result = try alloc.alloc(u8, prefix.len + b64_len);
    @memcpy(result[0..prefix.len], prefix);
    _ = std.base64.standard.Encoder.encode(result[prefix.len..], png_buf.items);

    return result;
}

/// Wrap data in zlib format with stored (no compression) deflate blocks.
fn zlibStore(alloc: std.mem.Allocator, out: *std.ArrayList(u8), data: []const u8) !void {
    // Zlib header: CMF=0x78 (deflate, window=32K), FLG=0x01 (no dict, check bits)
    try out.appendSlice(alloc, &.{ 0x78, 0x01 });

    // Write stored deflate blocks (max 65535 bytes each)
    const max_block: usize = 65535;
    var offset: usize = 0;
    while (offset < data.len) {
        const remaining = data.len - offset;
        const block_len: u16 = @intCast(@min(remaining, max_block));
        const is_final: u8 = if (offset + block_len >= data.len) 1 else 0;

        // Block header: BFINAL (1 bit) + BTYPE=00 (stored, 2 bits) + padding to byte
        try out.append(alloc, is_final); // bfinal=is_final, btype=00 (stored)
        // LEN and NLEN (little-endian)
        var len_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &len_bytes, block_len, .little);
        try out.appendSlice(alloc, &len_bytes);
        var nlen_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &nlen_bytes, ~block_len, .little);
        try out.appendSlice(alloc, &nlen_bytes);
        // Block data
        try out.appendSlice(alloc, data[offset .. offset + block_len]);
        offset += block_len;
    }

    // Handle empty data
    if (data.len == 0) {
        try out.appendSlice(alloc, &.{ 0x01, 0x00, 0x00, 0xFF, 0xFF });
    }

    // Adler-32 checksum (big-endian)
    const adler = adler32(data);
    var adler_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &adler_bytes, adler, .big);
    try out.appendSlice(alloc, &adler_bytes);
}

fn adler32(data: []const u8) u32 {
    var a: u32 = 1;
    var b: u32 = 0;
    for (data) |byte| {
        a = (a + byte) % 65521;
        b = (b + a) % 65521;
    }
    return (b << 16) | a;
}

fn writeChunk(alloc: std.mem.Allocator, buf: *std.ArrayList(u8), chunk_type: *const [4]u8, data: []const u8) !void {
    var len_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &len_bytes, @intCast(data.len), .big);
    try buf.appendSlice(alloc, &len_bytes);
    try buf.appendSlice(alloc, chunk_type);
    try buf.appendSlice(alloc, data);
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(chunk_type);
    crc.update(data);
    var crc_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc_bytes, crc.final(), .big);
    try buf.appendSlice(alloc, &crc_bytes);
}
