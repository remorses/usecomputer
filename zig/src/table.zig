/// Aligned table renderer for CLI output.
/// Renders rows of string columns with padding to align them visually.
const std = @import("std");

pub const Alignment = enum { left, right };

pub const Column = struct {
    header: []const u8,
    alignment: Alignment = .left,
};

/// Render rows into aligned, space-separated lines.
/// Each row is a slice of cell strings matching the columns in order.
/// Returns a slice of lines allocated with the given allocator.
pub fn render(
    allocator: std.mem.Allocator,
    columns: []const Column,
    rows: []const []const []const u8,
) ![]const []const u8 {
    if (columns.len == 0 or rows.len == 0) return &.{};

    // Compute max width per column (header vs data)
    const widths = try allocator.alloc(usize, columns.len);
    defer allocator.free(widths);

    for (columns, 0..) |col, i| {
        widths[i] = col.header.len;
    }
    for (rows) |row| {
        for (row, 0..) |cell, i| {
            if (i < widths.len and cell.len > widths[i]) {
                widths[i] = cell.len;
            }
        }
    }

    var lines = std.ArrayListUnmanaged([]const u8).empty;
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit(allocator);
    }

    // Header line
    const header_line = try formatRow(allocator, columns, &.{}, widths, true);
    try lines.append(allocator, header_line);

    // Data lines
    for (rows) |row| {
        const line = try formatRow(allocator, columns, row, widths, false);
        try lines.append(allocator, line);
    }

    return lines.toOwnedSlice(allocator);
}

fn formatRow(
    allocator: std.mem.Allocator,
    columns: []const Column,
    cells: []const []const u8,
    widths: []const usize,
    is_header: bool,
) ![]const u8 {
    var buf = std.ArrayListUnmanaged(u8).empty;
    errdefer buf.deinit(allocator);

    for (columns, 0..) |col, i| {
        if (i > 0) try buf.appendSlice(allocator, "  ");

        const text = if (is_header) col.header else if (i < cells.len) cells[i] else "";
        const w = widths[i];
        const pad = if (w > text.len) w - text.len else 0;

        if (col.alignment == .right and !is_header) {
            try buf.appendNTimes(allocator, ' ', pad);
            try buf.appendSlice(allocator, text);
        } else {
            try buf.appendSlice(allocator, text);
            // Don't pad the last column
            if (i < columns.len - 1) {
                try buf.appendNTimes(allocator, ' ', pad);
            }
        }
    }

    return buf.toOwnedSlice(allocator);
}

// ─── Tests ───

test "renders aligned columns with headers" {
    const allocator = std.testing.allocator;
    const columns = &[_]Column{
        .{ .header = "desktop" },
        .{ .header = "primary" },
        .{ .header = "size", .alignment = .right },
        .{ .header = "name" },
    };
    const rows = &[_][]const []const u8{
        &.{ "#0", "yes", "1720x1440", "Display 1" },
        &.{ "#1", "no", "800x600", "External" },
    };

    const lines = try render(allocator, columns, rows);
    defer {
        for (lines) |line| allocator.free(line);
        allocator.free(lines);
    }

    try std.testing.expectEqual(3, lines.len);
    try std.testing.expectEqualStrings("desktop  primary  size       name", lines[0]);
    try std.testing.expectEqualStrings("#0       yes      1720x1440  Display 1", lines[1]);
    try std.testing.expectEqualStrings("#1       no         800x600  External", lines[2]);
}

test "renders right-aligned numeric columns" {
    const allocator = std.testing.allocator;
    const columns = &[_]Column{
        .{ .header = "id", .alignment = .right },
        .{ .header = "app" },
        .{ .header = "size", .alignment = .right },
        .{ .header = "title" },
    };
    const rows = &[_][]const []const u8{
        &.{ "42", "Zed", "1720x1440", "main.zig" },
        &.{ "1337", "Safari", "800x600", "Google" },
    };

    const lines = try render(allocator, columns, rows);
    defer {
        for (lines) |line| allocator.free(line);
        allocator.free(lines);
    }

    try std.testing.expectEqual(3, lines.len);
    try std.testing.expectEqualStrings("id    app     size       title", lines[0]);
    try std.testing.expectEqualStrings("  42  Zed     1720x1440  main.zig", lines[1]);
    try std.testing.expectEqualStrings("1337  Safari    800x600  Google", lines[2]);
}

test "empty rows returns empty" {
    const allocator = std.testing.allocator;
    const columns = &[_]Column{
        .{ .header = "a" },
    };
    const empty: []const []const []const u8 = &.{};
    const lines = try render(allocator, columns, empty);
    try std.testing.expectEqual(0, lines.len);
}

test "single column no trailing spaces" {
    const allocator = std.testing.allocator;
    const columns = &[_]Column{
        .{ .header = "name" },
    };
    const rows = &[_][]const []const u8{
        &.{"hello"},
        &.{"hi"},
    };

    const lines = try render(allocator, columns, rows);
    defer {
        for (lines) |line| allocator.free(line);
        allocator.free(lines);
    }

    try std.testing.expectEqual(3, lines.len);
    try std.testing.expectEqualStrings("name", lines[0]);
    try std.testing.expectEqualStrings("hello", lines[1]);
    try std.testing.expectEqualStrings("hi", lines[2]);
}
