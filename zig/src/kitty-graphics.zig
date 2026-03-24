// Kitty Graphics Protocol emission for usecomputer screenshot output.
//
// When AGENT_GRAPHICS=kitty is set in the environment, CLI tools can emit
// images inline to stdout via APC escape sequences. An agent plugin
// (like kitty-graphics-agent) intercepts these sequences, strips them from
// the text output, and injects the images as LLM-visible attachments.
//
// Protocol format:
//   \x1b_G<control_data>;<base64_payload>\x1b\\
//
// Large images are chunked: continuation chunks use m=1, the last chunk
// uses m=0. Chunk size is 4096 bytes of base64 data (per spec convention).
//
// Reference: https://sw.kovidgoyal.net/kitty/graphics-protocol/
// Agent spec: https://github.com/remorses/kitty-graphics-agent

const std = @import("std");

const base64_alphabet: [64]u8 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".*;
const base64_encoder = std.base64.Base64Encoder.init(base64_alphabet, '=');

/// Max base64 characters per kitty graphics chunk (spec convention).
const chunk_size: usize = 4096;

/// Check whether a value string contains "kitty".
/// Extracted for deterministic testing without env var manipulation.
pub fn containsKitty(val: []const u8) bool {
    return std.mem.indexOf(u8, val, "kitty") != null;
}

/// Check whether the AGENT_GRAPHICS environment variable contains "kitty".
/// CLIs should call this to decide whether to emit kitty graphics on stdout.
/// Uses std.process.getEnvVarOwned for cross-platform compatibility (works on
/// macOS, Linux, and Windows — std.posix.getenv is unavailable on Windows).
pub fn canEmitAgentGraphics() bool {
    const alloc = std.heap.page_allocator;
    const val = std.process.getEnvVarOwned(alloc, "AGENT_GRAPHICS") catch return false;
    defer alloc.free(val);
    return containsKitty(val);
}

/// Emit a PNG image as Kitty Graphics Protocol escape sequences.
///
/// Writes APC sequences to `writer` with f=100 (PNG), a=T (transmit+display),
/// and chunked transfer (m=1 for continuation, m=0 for last/only chunk).
///
/// `png_data` is the raw PNG file bytes (not base64-encoded).
pub fn emitKittyGraphics(png_data: []const u8, writer: anytype) !void {
    // Base64-encode the entire PNG
    const encoded_len = base64_encoder.calcSize(png_data.len);

    // Allocate buffer for full base64 string
    const encoded_buf = try std.heap.page_allocator.alloc(u8, encoded_len);
    defer std.heap.page_allocator.free(encoded_buf);

    const encoded = base64_encoder.encode(encoded_buf, png_data);

    // Emit chunks
    var offset: usize = 0;
    while (offset < encoded.len) {
        const remaining = encoded.len - offset;
        const this_chunk_size = @min(remaining, chunk_size);
        const is_last = (offset + this_chunk_size >= encoded.len);
        const chunk = encoded[offset .. offset + this_chunk_size];

        if (offset == 0) {
            // First (or only) chunk: include full control data
            if (is_last) {
                try writer.print("\x1b_Gf=100,a=T,m=0;{s}\x1b\\", .{chunk});
            } else {
                try writer.print("\x1b_Gf=100,a=T,m=1;{s}\x1b\\", .{chunk});
            }
        } else {
            // Continuation chunk: only m= key (per spec)
            if (is_last) {
                try writer.print("\x1b_Gm=0;{s}\x1b\\", .{chunk});
            } else {
                try writer.print("\x1b_Gm=1;{s}\x1b\\", .{chunk});
            }
        }

        offset += this_chunk_size;
    }
}

// ─── Tests ───

test "containsKitty detects kitty in value" {
    try std.testing.expect(containsKitty("kitty"));
    try std.testing.expect(containsKitty("kitty,iterm2"));
    try std.testing.expect(containsKitty("iterm2,kitty"));
    try std.testing.expect(!containsKitty("iterm2"));
    try std.testing.expect(!containsKitty(""));
    try std.testing.expect(!containsKitty("KITTY")); // case-sensitive per spec
}

test "emitKittyGraphics single chunk for small image" {
    var buf = std.ArrayList(u8).initCapacity(std.testing.allocator, 0) catch unreachable;
    defer buf.deinit(std.testing.allocator);

    // Small PNG-like data (just bytes, doesn't need to be valid PNG for emission test)
    const small_data = "tiny-png-data";
    try emitKittyGraphics(small_data, buf.writer(std.testing.allocator));

    const output = buf.items;
    // Should start with APC start
    try std.testing.expect(std.mem.startsWith(u8, output, "\x1b_G"));
    // Should have f=100,a=T,m=0 (single chunk = last chunk)
    try std.testing.expect(std.mem.indexOf(u8, output, "f=100,a=T,m=0;") != null);
    // Should end with ST
    try std.testing.expect(std.mem.endsWith(u8, output, "\x1b\\"));
}

test "emitKittyGraphics multi chunk for large data" {
    var buf = std.ArrayList(u8).initCapacity(std.testing.allocator, 0) catch unreachable;
    defer buf.deinit(std.testing.allocator);

    // Create data large enough to require multiple chunks after base64 encoding.
    // 4096 base64 chars ~ 3072 raw bytes. Use 8000 raw bytes to get ~10668 base64 chars = 3 chunks.
    var large_data: [8000]u8 = undefined;
    for (&large_data) |*b| {
        b.* = 0xAB;
    }
    try emitKittyGraphics(&large_data, buf.writer(std.testing.allocator));

    const output = buf.items;
    // First chunk should have f=100,a=T,m=1
    try std.testing.expect(std.mem.indexOf(u8, output, "f=100,a=T,m=1;") != null);
    // Last chunk should have m=0
    // Find the last occurrence of m=0
    var found_m0 = false;
    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, output, search_pos, "m=0;")) |pos| {
        found_m0 = true;
        search_pos = pos + 1;
    }
    try std.testing.expect(found_m0);
    // Continuation chunks should have m=1 (without f=100,a=T prefix)
    // Count occurrences of \x1b_Gm=1; (continuation, no control data beyond m=)
    var continuation_count: usize = 0;
    var cpos: usize = 0;
    while (std.mem.indexOfPos(u8, output, cpos, "\x1b_Gm=1;")) |pos| {
        continuation_count += 1;
        cpos = pos + 1;
    }
    // With ~10668 base64 chars / 4096 chunk size = 3 chunks total
    // First chunk: \x1b_Gf=100,a=T,m=1; (1 occurrence)
    // Middle chunk(s): \x1b_Gm=1; (at least 1)
    // Last chunk: \x1b_Gm=0;
    try std.testing.expect(continuation_count >= 1);
}
