// C-ABI wrapper around lib.zig for use from C/C++/Python/etc.
// Every exported symbol uses the `uc_` prefix.
// Thread-local error state: call uc_last_error() after any function that returns -1 / NULL.

const std = @import("std");
const lib = @import("lib.zig");

const allocator = std.heap.c_allocator;

// ──────────────────────────────────────────────
// Thread-local error buffer
// ──────────────────────────────────────────────

const err_buf_len = 1024;
threadlocal var err_buf: [err_buf_len]u8 = undefined;
threadlocal var err_set: bool = false;
threadlocal var err_end: usize = 0;

fn setError(msg: []const u8) void {
    const n = @min(msg.len, err_buf_len);
    @memcpy(err_buf[0..n], msg[0..n]);
    err_end = n;
    err_set = true;
}

fn clearError() void {
    err_set = false;
    err_end = 0;
}

export fn uc_last_error() [*c]const u8 {
    if (!err_set) return null;
    if (err_end < err_buf_len) {
        err_buf[err_end] = 0; // null-terminate
        return &err_buf;
    }
    // buffer was full — overwrite last byte with NUL
    err_buf[err_buf_len - 1] = 0;
    return &err_buf;
}

// ──────────────────────────────────────────────
// String allocation helpers
// ──────────────────────────────────────────────
// Layout: [ usize length ][ payload bytes ][ NUL ]
// The returned pointer points to the payload (past the header).
// uc_free() reconstructs the full slice from the header.

fn allocCString(data: []const u8) ?[*]u8 {
    const header_size = @sizeOf(usize);
    const total = header_size + data.len + 1; // +1 for NUL terminator
    const buf = allocator.alloc(u8, total) catch return null;
    // Write length header
    const len_ptr: *usize = @ptrCast(@alignCast(buf.ptr));
    len_ptr.* = total;
    // Copy payload
    @memcpy(buf[header_size .. header_size + data.len], data);
    // NUL terminator
    buf[header_size + data.len] = 0;
    return buf.ptr + header_size;
}

export fn uc_free(ptr: ?*anyopaque) void {
    const p: [*]u8 = @ptrCast(ptr orelse return);
    const header_size = @sizeOf(usize);
    const base = p - header_size;
    const len_ptr: *const usize = @ptrCast(@alignCast(base));
    const total = len_ptr.*;
    allocator.free(@as([*]u8, @ptrCast(base))[0..total]);
}

// ──────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────

fn buttonStr(button: c_int) ?[]const u8 {
    return switch (button) {
        0 => "left",
        1 => "right",
        2 => "middle",
        else => null,
    };
}

/// Set error from a failed result and return -1.
fn handleCommandError(result: anytype) c_int {
    if (result.@"error") |err| {
        setError(err.message);
    } else {
        setError("unknown error");
    }
    return -1;
}

/// Set error from a failed result (for functions returning pointers).
fn setResultError(result: anytype) void {
    if (result.@"error") |err| {
        setError(err.message);
    } else {
        setError("unknown error");
    }
}

/// Convert a C string (nullable) to a Zig slice. Returns null for NULL input.
fn cStrToSlice(ptr: ?[*:0]const u8) ?[]const u8 {
    const p = ptr orelse return null;
    return std.mem.sliceTo(p, 0);
}

// ──────────────────────────────────────────────
// Exported C-ABI functions
// ──────────────────────────────────────────────

export fn uc_click(x: f64, y: f64, button: c_int, count: c_int) c_int {
    clearError();
    const result = lib.click(.{
        .point = .{ .x = x, .y = y },
        .button = buttonStr(button),
        .count = if (count > 0) @as(f64, @floatFromInt(count)) else null,
    });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_mouse_move(x: f64, y: f64) c_int {
    clearError();
    const result = lib.mouseMove(.{ .x = x, .y = y });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_hover(x: f64, y: f64) c_int {
    clearError();
    const result = lib.hover(.{ .x = x, .y = y });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_mouse_down(button: c_int) c_int {
    clearError();
    const result = lib.mouseDown(.{ .button = buttonStr(button) });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_mouse_up(button: c_int) c_int {
    clearError();
    const result = lib.mouseUp(.{ .button = buttonStr(button) });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_mouse_position(out_x: ?*f64, out_y: ?*f64) c_int {
    clearError();
    const ox = out_x orelse {
        setError("out_x must not be NULL");
        return -1;
    };
    const oy = out_y orelse {
        setError("out_y must not be NULL");
        return -1;
    };
    const result = lib.mousePosition();
    if (result.ok) {
        if (result.data) |point| {
            ox.* = point.x;
            oy.* = point.y;
            return 0;
        }
    }
    return handleCommandError(result);
}

export fn uc_drag(
    from_x: f64,
    from_y: f64,
    to_x: f64,
    to_y: f64,
    cp_x: f64,
    cp_y: f64,
    has_cp: c_int,
    button: c_int,
) c_int {
    clearError();
    const cp: ?lib.Point = if (has_cp != 0) .{ .x = cp_x, .y = cp_y } else null;
    const result = lib.drag(.{
        .from = .{ .x = from_x, .y = from_y },
        .to = .{ .x = to_x, .y = to_y },
        .cp = cp,
        .button = buttonStr(button),
    });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_type_text(text: ?[*:0]const u8, delay_ms: c_int) c_int {
    clearError();
    const text_ptr = text orelse {
        setError("text must not be NULL");
        return -1;
    };
    const text_slice = std.mem.sliceTo(text_ptr, 0);
    const result = lib.typeText(.{
        .text = text_slice,
        .delayMs = if (delay_ms >= 0) @as(f64, @floatFromInt(delay_ms)) else null,
    });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_press(key: ?[*:0]const u8, count: c_int, delay_ms: c_int) c_int {
    clearError();
    const key_ptr = key orelse {
        setError("key must not be NULL");
        return -1;
    };
    const key_slice = std.mem.sliceTo(key_ptr, 0);
    const result = lib.press(.{
        .key = key_slice,
        .count = if (count > 0) @as(f64, @floatFromInt(count)) else null,
        .delayMs = if (delay_ms >= 0) @as(f64, @floatFromInt(delay_ms)) else null,
    });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_scroll(
    direction: ?[*:0]const u8,
    amount: c_int,
    at_x: f64,
    at_y: f64,
    has_at: c_int,
) c_int {
    clearError();
    const dir_ptr = direction orelse {
        setError("direction must not be NULL");
        return -1;
    };
    const dir_slice = std.mem.sliceTo(dir_ptr, 0);
    const at: ?lib.Point = if (has_at != 0) .{ .x = at_x, .y = at_y } else null;
    const result = lib.scroll(.{
        .direction = dir_slice,
        .amount = if (amount > 0) @as(f64, @floatFromInt(amount)) else 1,
        .at = at,
    });
    if (result.ok) return 0;
    return handleCommandError(result);
}

export fn uc_screenshot(
    path: ?[*:0]const u8,
    display: c_int,
    window_id: c_int,
) [*c]u8 {
    clearError();
    const result = lib.screenshot(.{
        .path = cStrToSlice(path),
        .display = if (display >= 0) @as(f64, @floatFromInt(display)) else null,
        .window = if (window_id >= 0) @as(f64, @floatFromInt(window_id)) else null,
    });
    if (!result.ok) {
        setResultError(result);
        return null;
    }
    const data = result.data orelse {
        setError("screenshot returned no data");
        return null;
    };
    // Serialize ScreenshotOutput to JSON
    var buf: [8192]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    stream.writer().print("{f}", .{std.json.fmt(data, .{})}) catch {
        setError("failed to serialize screenshot output");
        return null;
    };
    const json = stream.getWritten();
    const c_str = allocCString(json) orelse {
        setError("failed to allocate screenshot result string");
        return null;
    };
    return c_str;
}

export fn uc_display_list() [*c]u8 {
    clearError();
    const result = lib.displayList();
    if (!result.ok) {
        setResultError(result);
        return null;
    }
    const data = result.data orelse {
        setError("display_list returned no data");
        return null;
    };
    // data is a JSON string allocated with c_allocator — copy into allocCString format
    defer allocator.free(@constCast(data));
    const c_str = allocCString(data) orelse {
        setError("failed to allocate display list string");
        return null;
    };
    return c_str;
}

export fn uc_window_list() [*c]u8 {
    clearError();
    const result = lib.windowList();
    if (!result.ok) {
        setResultError(result);
        return null;
    }
    const data = result.data orelse {
        setError("window_list returned no data");
        return null;
    };
    // data is a JSON string allocated with c_allocator — copy into allocCString format
    defer allocator.free(@constCast(data));
    const c_str = allocCString(data) orelse {
        setError("failed to allocate window list string");
        return null;
    };
    return c_str;
}
