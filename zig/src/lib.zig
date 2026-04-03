// Native N-API module for usecomputer desktop automation commands.
// Exports direct typed methods (no string command dispatcher) so TS can call
// high-level native functions and receive structured error objects.

const std = @import("std");
const builtin = @import("builtin");
const scroll_impl = @import("scroll.zig");
const window = @import("window.zig");
// napigen is only available when building as N-API library.
// The build system provides a "napigen" module for the library target but not
// for the standalone exe or test targets. We detect availability at comptime
// via the build options module.
const build_options = @import("build_options");
const napigen = if (build_options.enable_napigen) @import("napigen") else undefined;
const c_macos = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
    @cInclude("ImageIO/ImageIO.h");
}) else struct {};

const c_windows = if (builtin.target.os.tag == .windows) @cImport({
    @cInclude("windows.h");
}) else struct {};

const c_x11 = if (builtin.target.os.tag == .linux) @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/extensions/XShm.h");
    @cInclude("X11/extensions/XTest.h");
    @cInclude("sys/ipc.h");
    @cInclude("sys/shm.h");
    @cInclude("png.h");
}) else struct {};

const c = c_macos;
const screenshot_max_long_edge_px: f64 = 1568;

const mac_keycode = struct {
    const a = 0x00;
    const s = 0x01;
    const d = 0x02;
    const f = 0x03;
    const h = 0x04;
    const g = 0x05;
    const z = 0x06;
    const x = 0x07;
    const c = 0x08;
    const v = 0x09;
    const b = 0x0B;
    const q = 0x0C;
    const w = 0x0D;
    const e = 0x0E;
    const r = 0x0F;
    const y = 0x10;
    const t = 0x11;
    const one = 0x12;
    const two = 0x13;
    const three = 0x14;
    const four = 0x15;
    const six = 0x16;
    const five = 0x17;
    const equal = 0x18;
    const nine = 0x19;
    const seven = 0x1A;
    const minus = 0x1B;
    const eight = 0x1C;
    const zero = 0x1D;
    const right_bracket = 0x1E;
    const o = 0x1F;
    const u = 0x20;
    const left_bracket = 0x21;
    const i = 0x22;
    const p = 0x23;
    const l = 0x25;
    const j = 0x26;
    const quote = 0x27;
    const k = 0x28;
    const semicolon = 0x29;
    const backslash = 0x2A;
    const comma = 0x2B;
    const slash = 0x2C;
    const n = 0x2D;
    const m = 0x2E;
    const period = 0x2F;
    const tab = 0x30;
    const space = 0x31;
    const grave = 0x32;
    const delete = 0x33;
    const enter = 0x24;
    const escape = 0x35;
    const command = 0x37;
    const shift = 0x38;
    const option = 0x3A;
    const control = 0x3B;
    const fn_key = 0x3F;
    const f1 = 0x7A;
    const f2 = 0x78;
    const f3 = 0x63;
    const f4 = 0x76;
    const f5 = 0x60;
    const f6 = 0x61;
    const f7 = 0x62;
    const f8 = 0x64;
    const f9 = 0x65;
    const f10 = 0x6D;
    const f11 = 0x67;
    const f12 = 0x6F;
    const home = 0x73;
    const page_up = 0x74;
    const forward_delete = 0x75;
    const end = 0x77;
    const page_down = 0x79;
    const left_arrow = 0x7B;
    const right_arrow = 0x7C;
    const down_arrow = 0x7D;
    const up_arrow = 0x7E;
};

pub const std_options: std.Options = .{
    .log_level = .err,
};

const DisplayInfoOutput = struct {
    id: u32,
    index: u32,
    name: []const u8,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    scale: f64,
    isPrimary: bool,
};

const WindowInfoOutput = struct {
    id: u32,
    ownerPid: i32,
    ownerName: []const u8,
    title: []const u8,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    desktopIndex: u32,
};

const NativeErrorObject = struct {
    code: []const u8,
    message: []const u8,
    command: []const u8,
};

const CommandResult = struct {
    ok: bool,
    @"error": ?NativeErrorObject = null,
};

fn DataResult(comptime T: type) type {
    return struct {
        ok: bool,
        data: ?T = null,
        @"error": ?NativeErrorObject = null,
    };
}

fn okCommand() CommandResult {
    return .{ .ok = true };
}

fn failCommand(command: []const u8, code: []const u8, message: []const u8) CommandResult {
    return .{
        .ok = false,
        .@"error" = .{
            .code = code,
            .message = message,
            .command = command,
        },
    };
}

fn okData(comptime T: type, value: T) DataResult(T) {
    return .{
        .ok = true,
        .data = value,
    };
}

fn failData(comptime T: type, command: []const u8, code: []const u8, message: []const u8) DataResult(T) {
    return .{
        .ok = false,
        .@"error" = .{
            .code = code,
            .message = message,
            .command = command,
        },
    };
}

pub const Point = struct {
    x: f64,
    y: f64,
};

const MouseButtonKind = enum {
    left,
    right,
    middle,
};

const ClickInput = struct {
    point: Point,
    button: ?[]const u8 = null,
    count: ?f64 = null,
    modifiers: []const []const u8 = &[_][]const u8{},
};

const MouseMoveInput = Point;

const MouseButtonInput = struct {
    button: ?[]const u8 = null,
};

const DragInput = struct {
    from: Point,
    to: Point,
    cp: ?Point = null,
    durationMs: ?f64 = null,
    button: ?[]const u8 = null,
};

pub const ScreenshotRegion = struct {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
};

const ScreenshotInput = struct {
    path: ?[]const u8 = null,
    display: ?f64 = null,
    window: ?f64 = null,
    region: ?ScreenshotRegion = null,
    annotate: ?bool = null,
};

pub const ScreenshotOutput = struct {
    path: []const u8,
    desktopIndex: f64,
    captureX: f64,
    captureY: f64,
    captureWidth: f64,
    captureHeight: f64,
    imageWidth: f64,
    imageHeight: f64,
};

const SelectedDisplay = if (builtin.target.os.tag == .macos) struct {
    id: c.CGDirectDisplayID,
    index: usize,
    bounds: c.CGRect,
} else struct {
    id: u32,
    index: usize,
    bounds: struct {
        x: f64,
        y: f64,
        width: f64,
        height: f64,
    },
};

const ScreenshotCapture = if (builtin.target.os.tag == .macos) struct {
    image: c.CGImageRef,
    capture_x: f64,
    capture_y: f64,
    capture_width: f64,
    capture_height: f64,
    desktop_index: usize,
} else struct {
    image: RawRgbaImage,
    capture_x: f64,
    capture_y: f64,
    capture_width: f64,
    capture_height: f64,
    desktop_index: usize,
};

const ScaledScreenshotImage = if (builtin.target.os.tag == .macos) struct {
    image: c.CGImageRef,
    width: f64,
    height: f64,
} else struct {
    image: RawRgbaImage,
    width: f64,
    height: f64,
};

const RawRgbaImage = struct {
    pixels: []u8,
    width: usize,
    height: usize,
};

const WindowsRect = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

const WindowsDisplay = struct {
    id: u32,
    bounds: WindowsRect,
    is_primary: bool,
};

const WindowsSelectedDisplay = struct {
    display: WindowsDisplay,
    index: usize,
};

var windows_dpi_awareness_initialized = false;

fn ensureWindowsDpiAware() void {
    if (builtin.target.os.tag != .windows) {
        return;
    }
    if (windows_dpi_awareness_initialized) {
        return;
    }

    windows_dpi_awareness_initialized = true;
    _ = c_windows.SetProcessDPIAware();
}

const TypeTextInput = struct {
    text: []const u8,
    delayMs: ?f64 = null,
};

const PressInput = struct {
    key: []const u8,
    count: ?f64 = null,
    delayMs: ?f64 = null,
};

const ScrollInput = struct {
    direction: []const u8,
    amount: f64,
    at: ?Point = null,
};

pub fn screenshot(input: ScreenshotInput) DataResult(ScreenshotOutput) {
    _ = input.annotate;
    const output_path = input.path orelse "./screenshot.png";

    if (builtin.target.os.tag == .windows) {
        const capture = createWindowsScreenshotImage(.{
            .display_index = input.display,
            .window_id = input.window,
            .region = input.region,
        }) catch {
            return failData(ScreenshotOutput, "screenshot", "CAPTURE_FAILED", "failed to capture screenshot image");
        };
        defer std.heap.c_allocator.free(capture.image.pixels);

        writeRgbaScreenshotPng(.{
            .image = capture.image,
            .output_path = output_path,
        }) catch {
            return failData(ScreenshotOutput, "screenshot", "WRITE_FAILED", "failed to write screenshot file");
        };

        return okData(ScreenshotOutput, .{
            .path = output_path,
            .desktopIndex = @floatFromInt(capture.desktop_index),
            .captureX = capture.capture_x,
            .captureY = capture.capture_y,
            .captureWidth = capture.capture_width,
            .captureHeight = capture.capture_height,
            .imageWidth = @floatFromInt(capture.image.width),
            .imageHeight = @floatFromInt(capture.image.height),
        });
    }

    if (builtin.target.os.tag == .linux) {
        if (input.window != null) {
            return failData(ScreenshotOutput, "screenshot", "UNSUPPORTED_INPUT", "window screenshots are not supported on Linux yet");
        }

        const capture = createLinuxScreenshotImage(.{
            .display_index = input.display,
            .region = input.region,
        }) catch |err| {
            return failData(ScreenshotOutput, "screenshot", linuxScreenshotErrorCode(err), linuxScreenshotErrorMessage(err));
        };
        defer std.heap.c_allocator.free(capture.image.pixels);

        const scaled_image = scaleLinuxScreenshotImageIfNeeded(capture.image) catch {
            return failData(ScreenshotOutput, "screenshot", "SCALE_FAILED", "failed to scale screenshot image");
        };
        defer std.heap.c_allocator.free(scaled_image.image.pixels);

        writeLinuxScreenshotPng(.{
            .image = scaled_image.image,
            .output_path = output_path,
        }) catch {
            return failData(ScreenshotOutput, "screenshot", "WRITE_FAILED", "failed to write screenshot file");
        };

        return okData(ScreenshotOutput, .{
            .path = output_path,
            .desktopIndex = @floatFromInt(capture.desktop_index),
            .captureX = capture.capture_x,
            .captureY = capture.capture_y,
            .captureWidth = capture.capture_width,
            .captureHeight = capture.capture_height,
            .imageWidth = scaled_image.width,
            .imageHeight = scaled_image.height,
        });
    }

    if (builtin.target.os.tag != .macos) {
        return failData(ScreenshotOutput, "screenshot", "UNSUPPORTED_PLATFORM", "screenshot is unsupported on this platform");
    }

    const capture = createScreenshotImage(.{
        .display_index = input.display,
        .window_id = input.window,
        .region = input.region,
    }) catch {
        return failData(ScreenshotOutput, "screenshot", "CAPTURE_FAILED", "failed to capture screenshot image");
    };
    defer c.CFRelease(capture.image);

    const scaled_image = scaleScreenshotImageIfNeeded(capture.image) catch {
        return failData(ScreenshotOutput, "screenshot", "SCALE_FAILED", "failed to scale screenshot image");
    };
    defer c.CFRelease(scaled_image.image);

    writeScreenshotPng(.{
        .image = scaled_image.image,
        .output_path = output_path,
    }) catch {
        return failData(ScreenshotOutput, "screenshot", "WRITE_FAILED", "failed to write screenshot file");
    };

    return okData(ScreenshotOutput, .{
        .path = output_path,
        .desktopIndex = @as(f64, @floatFromInt(capture.desktop_index)),
        .captureX = capture.capture_x,
        .captureY = capture.capture_y,
        .captureWidth = capture.capture_width,
        .captureHeight = capture.capture_height,
        .imageWidth = scaled_image.width,
        .imageHeight = scaled_image.height,
    });
}

fn linuxScreenshotErrorCode(err: anyerror) []const u8 {
    return switch (err) {
        error.InvalidDisplayIndex, error.InvalidRegion, error.RegionOutOfBounds => "INVALID_INPUT",
        error.DisplayOpenFailed, error.MissingDisplayEnv, error.NoScreens, error.XShmUnavailable => "X11_UNAVAILABLE",
        error.CaptureFailed, error.ImageCreateFailed, error.ShmGetFailed, error.ShmAttachFailed, error.ShmAllocFailed => "CAPTURE_FAILED",
        else => "CAPTURE_FAILED",
    };
}

fn linuxScreenshotErrorMessage(err: anyerror) []const u8 {
    return switch (err) {
        error.InvalidDisplayIndex => "Linux screenshots currently support only display 0",
        error.InvalidRegion => "invalid screenshot region",
        error.RegionOutOfBounds => "screenshot region is outside the X11 root window bounds",
        error.MissingDisplayEnv => "DISPLAY is not set; Linux screenshots require an X11 session",
        error.DisplayOpenFailed => "failed to open X11 display",
        error.NoScreens => "X11 display has no screens",
        error.XShmUnavailable => "X11 shared memory extension is unavailable",
        error.ImageCreateFailed, error.ShmAllocFailed, error.ShmAttachFailed, error.ShmGetFailed, error.CaptureFailed => "failed to capture screenshot image",
        else => "failed to capture screenshot image",
    };
}

const WindowsDisplayEnumContext = struct {
    displays: *std.ArrayList(WindowsDisplay),
    allocator: std.mem.Allocator,
    failed: bool = false,
};

fn enumWindowsDisplayCallback(
    monitor: c_windows.HMONITOR,
    _: c_windows.HDC,
    _: [*c]c_windows.RECT,
    l_param: c_windows.LPARAM,
) callconv(.winapi) c_int {
    const context: *WindowsDisplayEnumContext = @ptrFromInt(@as(usize, @intCast(l_param)));

    var info: c_windows.MONITORINFO = std.mem.zeroes(c_windows.MONITORINFO);
    info.cbSize = @sizeOf(c_windows.MONITORINFO);
    if (c_windows.GetMonitorInfoA(monitor, @ptrCast(&info)) == 0) {
        context.failed = true;
        return c_windows.FALSE;
    }

    const item = WindowsDisplay{
        .id = @as(u32, @truncate(@as(usize, @intFromPtr(monitor)))),
        .bounds = .{
            .x = info.rcMonitor.left,
            .y = info.rcMonitor.top,
            .width = info.rcMonitor.right - info.rcMonitor.left,
            .height = info.rcMonitor.bottom - info.rcMonitor.top,
        },
        .is_primary = (info.dwFlags & c_windows.MONITORINFOF_PRIMARY) != 0,
    };
    context.displays.append(context.allocator, item) catch {
        context.failed = true;
        return c_windows.FALSE;
    };
    return c_windows.TRUE;
}

fn enumerateWindowsDisplays(allocator: std.mem.Allocator) ![]WindowsDisplay {
    if (builtin.target.os.tag != .windows) {
        return error.UnsupportedPlatform;
    }
    ensureWindowsDpiAware();

    var displays = try std.ArrayList(WindowsDisplay).initCapacity(allocator, 0);
    errdefer displays.deinit(allocator);
    var context = WindowsDisplayEnumContext{ .displays = &displays, .allocator = allocator };

    const ok = c_windows.EnumDisplayMonitors(
        null,
        null,
        enumWindowsDisplayCallback,
        @as(c_windows.LPARAM, @intCast(@intFromPtr(&context))),
    );
    if (ok == 0 or context.failed or displays.items.len == 0) {
        displays.deinit(allocator);
        return error.DisplayQueryFailed;
    }

    return displays.toOwnedSlice(allocator);
}

fn resolveWindowsDisplay(display_index: ?f64) !WindowsSelectedDisplay {
    const displays = try enumerateWindowsDisplays(std.heap.c_allocator);
    defer std.heap.c_allocator.free(displays);

    if (display_index) |value| {
        const normalized = @as(i64, @intFromFloat(std.math.round(value)));
        if (normalized < 0) {
            return error.InvalidDisplayIndex;
        }
        const selected_index = @as(usize, @intCast(normalized));
        if (selected_index >= displays.len) {
            return error.InvalidDisplayIndex;
        }
        return .{ .display = displays[selected_index], .index = selected_index };
    }

    var i: usize = 0;
    while (i < displays.len) : (i += 1) {
        if (displays[i].is_primary) {
            return .{ .display = displays[i], .index = i };
        }
    }
    return .{ .display = displays[0], .index = 0 };
}

fn resolveWindowsDesktopIndexForRect(rect: WindowsRect) !usize {
    const displays = try enumerateWindowsDisplays(std.heap.c_allocator);
    defer std.heap.c_allocator.free(displays);

    var best_index: usize = 0;
    var best_overlap: i64 = -1;

    var i: usize = 0;
    while (i < displays.len) : (i += 1) {
        const display = displays[i];
        const left = @max(rect.x, display.bounds.x);
        const top = @max(rect.y, display.bounds.y);
        const right = @min(rect.x + rect.width, display.bounds.x + display.bounds.width);
        const bottom = @min(rect.y + rect.height, display.bounds.y + display.bounds.height);
        const overlap: i64 = if (right <= left or bottom <= top) 0 else (@as(i64, right - left) * @as(i64, bottom - top));
        if (overlap > best_overlap) {
            best_overlap = overlap;
            best_index = i;
        }
    }

    return best_index;
}

fn normalizeWindowHandle(raw_id: f64) !c_windows.HWND {
    const normalized = @as(i64, @intFromFloat(std.math.round(raw_id)));
    if (normalized <= 0) {
        return error.InvalidWindowId;
    }
    const handle_int = @as(usize, @intCast(normalized));
    return @ptrFromInt(handle_int);
}

fn normalizedDimensionI32(value: f64) !i32 {
    if (!std.math.isFinite(value)) {
        return error.InvalidRegion;
    }
    const rounded = @as(i64, @intFromFloat(std.math.round(value)));
    if (rounded <= 0 or rounded > std.math.maxInt(i32)) {
        return error.InvalidRegion;
    }
    return @as(i32, @intCast(rounded));
}

fn createWindowsScreenshotImage(input: struct {
    display_index: ?f64,
    window_id: ?f64,
    region: ?ScreenshotRegion,
}) !ScreenshotCapture {
    if (builtin.target.os.tag != .windows) {
        return error.UnsupportedPlatform;
    }

    if (input.window_id) |window_id| {
        const hwnd = try normalizeWindowHandle(window_id);
        var rect: c_windows.RECT = std.mem.zeroes(c_windows.RECT);
        if (c_windows.GetWindowRect(hwnd, &rect) == 0) {
            return error.WindowNotFound;
        }
        const capture_rect = WindowsRect{
            .x = rect.left,
            .y = rect.top,
            .width = rect.right - rect.left,
            .height = rect.bottom - rect.top,
        };
        if (capture_rect.width <= 0 or capture_rect.height <= 0) {
            return error.CaptureFailed;
        }

        const image = try captureWindowsRect(capture_rect);
        const desktop_index = resolveWindowsDesktopIndexForRect(capture_rect) catch 0;
        return .{
            .image = image,
            .capture_x = @floatFromInt(capture_rect.x),
            .capture_y = @floatFromInt(capture_rect.y),
            .capture_width = @floatFromInt(capture_rect.width),
            .capture_height = @floatFromInt(capture_rect.height),
            .desktop_index = desktop_index,
        };
    }

    const selected_display = try resolveWindowsDisplay(input.display_index);
    const bounds = selected_display.display.bounds;

    var capture_rect = bounds;
    if (input.region) |region| {
        const region_x = try normalizedCoordinate(region.x);
        const region_y = try normalizedCoordinate(region.y);
        const region_width = try normalizedDimensionI32(region.width);
        const region_height = try normalizedDimensionI32(region.height);
        if (region_x < 0 or region_y < 0) {
            return error.InvalidRegion;
        }
        if (region_x + region_width > bounds.width or region_y + region_height > bounds.height) {
            return error.RegionOutOfBounds;
        }
        capture_rect = .{
            .x = bounds.x + region_x,
            .y = bounds.y + region_y,
            .width = region_width,
            .height = region_height,
        };
    }

    const image = try captureWindowsRect(capture_rect);
    return .{
        .image = image,
        .capture_x = @floatFromInt(capture_rect.x),
        .capture_y = @floatFromInt(capture_rect.y),
        .capture_width = @floatFromInt(capture_rect.width),
        .capture_height = @floatFromInt(capture_rect.height),
        .desktop_index = selected_display.index,
    };
}

fn captureWindowsRect(rect: WindowsRect) !RawRgbaImage {
    if (builtin.target.os.tag != .windows) {
        return error.UnsupportedPlatform;
    }
    ensureWindowsDpiAware();

    if (rect.width <= 0 or rect.height <= 0) {
        return error.CaptureFailed;
    }

    const screen_dc = c_windows.GetDC(null);
    if (screen_dc == null) {
        return error.CaptureFailed;
    }
    defer _ = c_windows.ReleaseDC(null, screen_dc);

    const mem_dc = c_windows.CreateCompatibleDC(screen_dc);
    if (mem_dc == null) {
        return error.CaptureFailed;
    }
    defer _ = c_windows.DeleteDC(mem_dc);

    const bitmap = c_windows.CreateCompatibleBitmap(screen_dc, rect.width, rect.height);
    if (bitmap == null) {
        return error.CaptureFailed;
    }
    defer _ = c_windows.DeleteObject(bitmap);

    const prev = c_windows.SelectObject(mem_dc, bitmap);
    if (prev == null) {
        return error.CaptureFailed;
    }
    defer _ = c_windows.SelectObject(mem_dc, prev);

    const raster_op = c_windows.SRCCOPY | c_windows.CAPTUREBLT;
    if (c_windows.BitBlt(mem_dc, 0, 0, rect.width, rect.height, screen_dc, rect.x, rect.y, raster_op) == 0) {
        return error.CaptureFailed;
    }

    const width_usize = @as(usize, @intCast(rect.width));
    const height_usize = @as(usize, @intCast(rect.height));
    const pixel_count = width_usize * height_usize;
    const pixels = try std.heap.c_allocator.alloc(u8, pixel_count * 4);
    errdefer std.heap.c_allocator.free(pixels);

    var bmi: c_windows.BITMAPINFO = std.mem.zeroes(c_windows.BITMAPINFO);
    bmi.bmiHeader.biSize = @sizeOf(c_windows.BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = rect.width;
    bmi.bmiHeader.biHeight = -rect.height;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = c_windows.BI_RGB;

    const scanlines = c_windows.GetDIBits(
        mem_dc,
        bitmap,
        0,
        @as(c_uint, @intCast(rect.height)),
        pixels.ptr,
        &bmi,
        c_windows.DIB_RGB_COLORS,
    );
    if (scanlines == 0) {
        return error.CaptureFailed;
    }

    var i: usize = 0;
    while (i < pixels.len) : (i += 4) {
        const blue = pixels[i];
        const red = pixels[i + 2];
        pixels[i] = red;
        pixels[i + 2] = blue;
        pixels[i + 3] = 255;
    }

    return .{ .pixels = pixels, .width = width_usize, .height = height_usize };
}

fn writeU32BigEndian(writer: anytype, value: u32) !void {
    const bytes = [4]u8{
        @as(u8, @intCast((value >> 24) & 0xFF)),
        @as(u8, @intCast((value >> 16) & 0xFF)),
        @as(u8, @intCast((value >> 8) & 0xFF)),
        @as(u8, @intCast(value & 0xFF)),
    };
    try writer.writeAll(&bytes);
}

fn crc32Update(crc_seed: u32, data: []const u8) u32 {
    var crc = crc_seed;
    for (data) |byte| {
        crc ^= byte;
        var bit: u8 = 0;
        while (bit < 8) : (bit += 1) {
            if ((crc & 1) == 1) {
                crc = (crc >> 1) ^ 0xEDB88320;
            } else {
                crc >>= 1;
            }
        }
    }
    return crc;
}

fn adler32(data: []const u8) u32 {
    const mod_adler: u32 = 65521;
    var s1: u32 = 1;
    var s2: u32 = 0;
    for (data) |byte| {
        s1 = (s1 + byte) % mod_adler;
        s2 = (s2 + s1) % mod_adler;
    }
    return (s2 << 16) | s1;
}

fn encodeZlibStore(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const max_block: usize = 65535;
    const block_count = if (data.len == 0) 1 else (data.len + max_block - 1) / max_block;
    const total_size = 2 + (block_count * 5) + data.len + 4;
    const out = try allocator.alloc(u8, total_size);
    errdefer allocator.free(out);

    var pos: usize = 0;
    out[pos] = 0x78;
    out[pos + 1] = 0x01;
    pos += 2;

    if (data.len == 0) {
        out[pos] = 0x01;
        out[pos + 1] = 0x00;
        out[pos + 2] = 0x00;
        out[pos + 3] = 0xFF;
        out[pos + 4] = 0xFF;
        pos += 5;
    } else {
        var remaining = data;
        while (remaining.len > 0) {
            const block_len = @min(remaining.len, max_block);
            const final_block = block_len == remaining.len;
            out[pos] = if (final_block) 0x01 else 0x00;
            pos += 1;

            const len16 = @as(u16, @intCast(block_len));
            const nlen16: u16 = ~len16;
            out[pos] = @as(u8, @intCast(len16 & 0xFF));
            out[pos + 1] = @as(u8, @intCast((len16 >> 8) & 0xFF));
            out[pos + 2] = @as(u8, @intCast(nlen16 & 0xFF));
            out[pos + 3] = @as(u8, @intCast((nlen16 >> 8) & 0xFF));
            pos += 4;

            @memcpy(out[pos .. pos + block_len], remaining[0..block_len]);
            pos += block_len;
            remaining = remaining[block_len..];
        }
    }

    const checksum = adler32(data);
    out[pos] = @as(u8, @intCast((checksum >> 24) & 0xFF));
    out[pos + 1] = @as(u8, @intCast((checksum >> 16) & 0xFF));
    out[pos + 2] = @as(u8, @intCast((checksum >> 8) & 0xFF));
    out[pos + 3] = @as(u8, @intCast(checksum & 0xFF));
    pos += 4;

    return out[0..pos];
}

fn writePngChunk(writer: anytype, chunk_type: [4]u8, data: []const u8) !void {
    try writeU32BigEndian(writer, @as(u32, @intCast(data.len)));
    try writer.writeAll(&chunk_type);
    try writer.writeAll(data);

    var crc = crc32Update(0xFFFFFFFF, &chunk_type);
    crc = crc32Update(crc, data);
    crc = ~crc;
    try writeU32BigEndian(writer, crc);
}

fn writeRgbaScreenshotPng(input: struct {
    image: RawRgbaImage,
    output_path: []const u8,
}) !void {
    const row_bytes = input.image.width * 4;
    const filtered_len = input.image.height * (row_bytes + 1);
    const filtered = try std.heap.c_allocator.alloc(u8, filtered_len);
    defer std.heap.c_allocator.free(filtered);

    var src_offset: usize = 0;
    var dst_offset: usize = 0;
    var row: usize = 0;
    while (row < input.image.height) : (row += 1) {
        filtered[dst_offset] = 0;
        dst_offset += 1;
        @memcpy(filtered[dst_offset .. dst_offset + row_bytes], input.image.pixels[src_offset .. src_offset + row_bytes]);
        src_offset += row_bytes;
        dst_offset += row_bytes;
    }

    const idat = try encodeZlibStore(std.heap.c_allocator, filtered);
    defer std.heap.c_allocator.free(idat);

    const file = if (std.fs.path.isAbsolute(input.output_path))
        try std.fs.createFileAbsolute(input.output_path, .{})
    else
        try std.fs.cwd().createFile(input.output_path, .{});
    defer file.close();

    const writer = file.deprecatedWriter();
    try writer.writeAll(&[_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 });

    var ihdr: [13]u8 = undefined;
    ihdr[0] = @as(u8, @intCast((input.image.width >> 24) & 0xFF));
    ihdr[1] = @as(u8, @intCast((input.image.width >> 16) & 0xFF));
    ihdr[2] = @as(u8, @intCast((input.image.width >> 8) & 0xFF));
    ihdr[3] = @as(u8, @intCast(input.image.width & 0xFF));
    ihdr[4] = @as(u8, @intCast((input.image.height >> 24) & 0xFF));
    ihdr[5] = @as(u8, @intCast((input.image.height >> 16) & 0xFF));
    ihdr[6] = @as(u8, @intCast((input.image.height >> 8) & 0xFF));
    ihdr[7] = @as(u8, @intCast(input.image.height & 0xFF));
    ihdr[8] = 8;
    ihdr[9] = 6;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    try writePngChunk(writer, .{ 'I', 'H', 'D', 'R' }, &ihdr);
    try writePngChunk(writer, .{ 'I', 'D', 'A', 'T' }, idat);
    try writePngChunk(writer, .{ 'I', 'E', 'N', 'D' }, &[_]u8{});
}

fn createLinuxScreenshotImage(input: struct {
    display_index: ?f64,
    region: ?ScreenshotRegion,
}) !ScreenshotCapture {
    if (builtin.target.os.tag != .linux) {
        return error.UnsupportedPlatform;
    }
    if (input.display_index) |value| {
        const normalized = @as(i64, @intFromFloat(std.math.round(value)));
        if (normalized != 0) {
            return error.InvalidDisplayIndex;
        }
    }
    if (std.posix.getenv("DISPLAY") == null) {
        return error.MissingDisplayEnv;
    }

    const display = c_x11.XOpenDisplay(null) orelse return error.DisplayOpenFailed;
    defer _ = c_x11.XCloseDisplay(display);

    const screen_index = c_x11.XDefaultScreen(display);
    if (screen_index < 0) {
        return error.NoScreens;
    }
    const root = c_x11.XRootWindow(display, screen_index);
    const screen_width_i = c_x11.XDisplayWidth(display, screen_index);
    const screen_height_i = c_x11.XDisplayHeight(display, screen_index);
    if (screen_width_i <= 0 or screen_height_i <= 0) {
        return error.CaptureFailed;
    }

    const screen_width = @as(usize, @intCast(screen_width_i));
    const screen_height = @as(usize, @intCast(screen_height_i));
    const capture_rect = try resolveLinuxCaptureRect(.{
        .screen_width = screen_width,
        .screen_height = screen_height,
        .region = input.region,
    });

    // Try XShm first (fast), fall back to XGetImage (slow but always works).
    // XShm fails on XWayland when processes don't share SHM namespaces.
    const image = captureWithXShm(display, screen_index, root, capture_rect) orelse
        captureWithXGetImage(display, root, capture_rect) orelse
        return error.CaptureFailed;
    // XDestroyImage is a C macro: ((*((ximage)->f.destroy_image))((ximage)))
    // Zig's @cImport can't translate it, so call the function pointer directly.
    defer _ = image.*.f.destroy_image.?(image);

    const rgba = try convertX11ImageToRgba(image, capture_rect.width, capture_rect.height);
    return .{
        .image = rgba,
        .capture_x = @floatFromInt(capture_rect.x),
        .capture_y = @floatFromInt(capture_rect.y),
        .capture_width = @floatFromInt(capture_rect.width),
        .capture_height = @floatFromInt(capture_rect.height),
        .desktop_index = 0,
    };
}

const LinuxCaptureRect = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,
};

// X error handler state for detecting X errors during screenshot capture.
// XSetErrorHandler is process-global, so this is necessarily a global.
var x_capture_error_occurred: bool = false;

fn captureErrorHandler(_: ?*c_x11.Display, _: ?*c_x11.XErrorEvent) callconv(.c) c_int {
    x_capture_error_occurred = true;
    return 0;
}

/// Fast screenshot path using XShm (shared memory). Returns null if XShm is
/// unavailable or fails (common on XWayland with different SHM namespaces).
fn captureWithXShm(
    display: *c_x11.Display,
    screen_index: c_int,
    root: c_x11.Window,
    capture_rect: LinuxCaptureRect,
) ?*c_x11.XImage {
    if (c_x11.XShmQueryExtension(display) == 0) {
        return null;
    }

    const visual = c_x11.XDefaultVisual(display, screen_index);
    const depth = @as(c_uint, @intCast(c_x11.XDefaultDepth(display, screen_index)));
    var shm_info: c_x11.XShmSegmentInfo = undefined;
    shm_info.shmid = -1;
    shm_info.shmaddr = null;
    shm_info.readOnly = 0;

    const image = c_x11.XShmCreateImage(
        display,
        visual,
        depth,
        c_x11.ZPixmap,
        null,
        &shm_info,
        @as(c_uint, @intCast(capture_rect.width)),
        @as(c_uint, @intCast(capture_rect.height)),
    ) orelse return null;

    const bytes_per_image = @as(usize, @intCast(image.*.bytes_per_line)) * capture_rect.height;
    const shmget_result = c_x11.shmget(c_x11.IPC_PRIVATE, bytes_per_image, c_x11.IPC_CREAT | 0o600);
    if (shmget_result < 0) {
        image.*.data = null;
        _ = image.*.f.destroy_image.?(image);
        return null;
    }
    shm_info.shmid = shmget_result;

    const shmaddr = c_x11.shmat(shm_info.shmid, null, 0);
    if (@intFromPtr(shmaddr) == std.math.maxInt(usize)) {
        _ = c_x11.shmctl(shm_info.shmid, c_x11.IPC_RMID, null);
        image.*.data = null;
        _ = image.*.f.destroy_image.?(image);
        return null;
    }
    shm_info.shmaddr = @ptrCast(shmaddr);
    image.*.data = shm_info.shmaddr;

    // Install custom error handler to catch BadAccess from XShmAttach
    // (happens on XWayland when SHM namespaces don't match).
    x_capture_error_occurred = false;
    const old_handler = c_x11.XSetErrorHandler(captureErrorHandler);

    _ = c_x11.XShmAttach(display, &shm_info);
    _ = c_x11.XSync(display, 0);

    if (x_capture_error_occurred) {
        // Restore original handler and clean up
        _ = c_x11.XSetErrorHandler(old_handler);
        _ = c_x11.shmdt(shmaddr);
        _ = c_x11.shmctl(shm_info.shmid, c_x11.IPC_RMID, null);
        image.*.data = null;
        _ = image.*.f.destroy_image.?(image);
        return null;
    }

    if (c_x11.XShmGetImage(
        display,
        root,
        image,
        @as(c_int, @intCast(capture_rect.x)),
        @as(c_int, @intCast(capture_rect.y)),
        c_x11.AllPlanes,
    ) == 0) {
        _ = c_x11.XSetErrorHandler(old_handler);
        _ = c_x11.XShmDetach(display, &shm_info);
        _ = c_x11.shmdt(shmaddr);
        _ = c_x11.shmctl(shm_info.shmid, c_x11.IPC_RMID, null);
        image.*.data = null;
        _ = image.*.f.destroy_image.?(image);
        return null;
    }

    // Copy image data to a separate allocation so we can detach SHM.
    // The caller owns the XImage and will free it via destroy_image.
    const data_copy = std.heap.c_allocator.alloc(u8, bytes_per_image) catch {
        _ = c_x11.XSetErrorHandler(old_handler);
        _ = c_x11.XShmDetach(display, &shm_info);
        _ = c_x11.shmdt(shmaddr);
        _ = c_x11.shmctl(shm_info.shmid, c_x11.IPC_RMID, null);
        image.*.data = null;
        _ = image.*.f.destroy_image.?(image);
        return null;
    };
    @memcpy(data_copy, @as([*]const u8, @ptrCast(shmaddr))[0..bytes_per_image]);
    image.*.data = @ptrCast(data_copy.ptr);

    _ = c_x11.XSetErrorHandler(old_handler);
    _ = c_x11.XShmDetach(display, &shm_info);
    _ = c_x11.shmdt(shmaddr);
    _ = c_x11.shmctl(shm_info.shmid, c_x11.IPC_RMID, null);

    return image;
}

/// Slow but reliable fallback: XGetImage copies pixels over the X connection.
/// Works everywhere including XWayland regardless of SHM namespace.
/// Installs a temporary X error handler to catch BadMatch errors (common
/// on XWayland when the capture region doesn't match the root drawable).
fn captureWithXGetImage(
    display: *c_x11.Display,
    root: c_x11.Window,
    capture_rect: LinuxCaptureRect,
) ?*c_x11.XImage {
    x_capture_error_occurred = false;
    const old_handler = c_x11.XSetErrorHandler(captureErrorHandler);
    defer _ = c_x11.XSetErrorHandler(old_handler);

    const image = c_x11.XGetImage(
        display,
        root,
        @as(c_int, @intCast(capture_rect.x)),
        @as(c_int, @intCast(capture_rect.y)),
        @as(c_uint, @intCast(capture_rect.width)),
        @as(c_uint, @intCast(capture_rect.height)),
        c_x11.AllPlanes,
        c_x11.ZPixmap,
    );
    _ = c_x11.XSync(display, 0);

    if (x_capture_error_occurred) {
        if (image) |img| {
            _ = img.*.f.destroy_image.?(img);
        }
        return null;
    }
    return image;
}

fn resolveLinuxCaptureRect(input: struct {
    screen_width: usize,
    screen_height: usize,
    region: ?ScreenshotRegion,
}) !LinuxCaptureRect {
    if (input.region) |region| {
        const x = @as(i64, @intFromFloat(std.math.round(region.x)));
        const y = @as(i64, @intFromFloat(std.math.round(region.y)));
        const width = @as(i64, @intFromFloat(std.math.round(region.width)));
        const height = @as(i64, @intFromFloat(std.math.round(region.height)));
        if (x < 0 or y < 0 or width <= 0 or height <= 0) {
            return error.InvalidRegion;
        }
        const max_x = x + width;
        const max_y = y + height;
        if (max_x > input.screen_width or max_y > input.screen_height) {
            return error.RegionOutOfBounds;
        }
        return .{
            .x = @as(usize, @intCast(x)),
            .y = @as(usize, @intCast(y)),
            .width = @as(usize, @intCast(width)),
            .height = @as(usize, @intCast(height)),
        };
    }

    return .{
        .x = 0,
        .y = 0,
        .width = input.screen_width,
        .height = input.screen_height,
    };
}

fn convertX11ImageToRgba(image: *c_x11.XImage, width: usize, height: usize) !RawRgbaImage {
    const pixels = try std.heap.c_allocator.alloc(u8, width * height * 4);
    errdefer std.heap.c_allocator.free(pixels);

    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            // XGetPixel is a C macro: ((*((ximage)->f.get_pixel))((ximage), (x), (y)))
            const pixel = image.*.f.get_pixel.?(image, @as(c_int, @intCast(x)), @as(c_int, @intCast(y)));
            const red = normalizeX11Channel(.{ .pixel = pixel, .mask = image.*.red_mask });
            const green = normalizeX11Channel(.{ .pixel = pixel, .mask = image.*.green_mask });
            const blue = normalizeX11Channel(.{ .pixel = pixel, .mask = image.*.blue_mask });
            const offset = (y * width + x) * 4;
            pixels[offset] = red;
            pixels[offset + 1] = green;
            pixels[offset + 2] = blue;
            pixels[offset + 3] = 255;
        }
    }

    return .{ .pixels = pixels, .width = width, .height = height };
}

fn normalizeX11Channel(input: struct {
    pixel: c_ulong,
    mask: c_ulong,
}) u8 {
    if (input.mask == 0) {
        return 0;
    }
    // @ctz returns u7 on 64-bit c_ulong (aarch64-linux), but >> needs u6.
    // The shift can't exceed 63 since mask != 0 and is at most 64 bits.
    const shift: std.math.Log2Int(c_ulong) = @intCast(@ctz(input.mask));
    const bits: std.math.Log2Int(c_ulong) = @intCast(@min(@popCount(input.mask), @bitSizeOf(c_ulong) - 1));
    const raw = (input.pixel & input.mask) >> shift;
    const max_value = (@as(u64, 1) << @intCast(bits)) - 1;
    if (max_value == 0) {
        return 0;
    }
    return @as(u8, @intCast((raw * 255) / max_value));
}

fn scaleLinuxScreenshotImageIfNeeded(image: RawRgbaImage) !ScaledScreenshotImage {
    const image_width = @as(f64, @floatFromInt(image.width));
    const image_height = @as(f64, @floatFromInt(image.height));
    const long_edge = @max(image_width, image_height);
    if (long_edge <= screenshot_max_long_edge_px) {
        const copy = try std.heap.c_allocator.dupe(u8, image.pixels);
        return .{
            .image = .{ .pixels = copy, .width = image.width, .height = image.height },
            .width = image_width,
            .height = image_height,
        };
    }

    const scale = screenshot_max_long_edge_px / long_edge;
    const target_width = @max(1, @as(usize, @intFromFloat(std.math.round(image_width * scale))));
    const target_height = @max(1, @as(usize, @intFromFloat(std.math.round(image_height * scale))));
    const scaled_pixels = try std.heap.c_allocator.alloc(u8, target_width * target_height * 4);
    errdefer std.heap.c_allocator.free(scaled_pixels);

    var y: usize = 0;
    while (y < target_height) : (y += 1) {
        const source_y = @min(image.height - 1, @as(usize, @intFromFloat((@as(f64, @floatFromInt(y)) * image_height) / @as(f64, @floatFromInt(target_height)))));
        var x: usize = 0;
        while (x < target_width) : (x += 1) {
            const source_x = @min(image.width - 1, @as(usize, @intFromFloat((@as(f64, @floatFromInt(x)) * image_width) / @as(f64, @floatFromInt(target_width)))));
            const source_offset = (source_y * image.width + source_x) * 4;
            const target_offset = (y * target_width + x) * 4;
            @memcpy(scaled_pixels[target_offset .. target_offset + 4], image.pixels[source_offset .. source_offset + 4]);
        }
    }

    return .{
        .image = .{ .pixels = scaled_pixels, .width = target_width, .height = target_height },
        .width = @floatFromInt(target_width),
        .height = @floatFromInt(target_height),
    };
}

fn writeLinuxScreenshotPng(input: struct {
    image: RawRgbaImage,
    output_path: []const u8,
}) !void {
    var png: c_x11.png_image = std.mem.zeroes(c_x11.png_image);
    png.version = c_x11.PNG_IMAGE_VERSION;
    png.width = @as(c_x11.png_uint_32, @intCast(input.image.width));
    png.height = @as(c_x11.png_uint_32, @intCast(input.image.height));
    png.format = c_x11.PNG_FORMAT_RGBA;

    const output_path_z = try std.heap.c_allocator.dupeZ(u8, input.output_path);
    defer std.heap.c_allocator.free(output_path_z);

    const write_result = c_x11.png_image_write_to_file(
        &png,
        output_path_z.ptr,
        0,
        input.image.pixels.ptr,
        @as(c_int, @intCast(input.image.width * 4)),
        null,
    );
    if (write_result == 0) {
        c_x11.png_image_free(&png);
        return error.PngWriteFailed;
    }
    c_x11.png_image_free(&png);
}

pub fn click(input: ClickInput) CommandResult {
    const click_count: u32 = if (input.count) |count| blk: {
        const normalized = @as(i64, @intFromFloat(std.math.round(count)));
        if (normalized <= 0) {
            break :blk 1;
        }
        break :blk @as(u32, @intCast(normalized));
    } else 1;

    const button_kind = resolveMouseButton(input.button orelse "left") catch {
        return failCommand("click", "INVALID_INPUT", "invalid click button");
    };
    const parsed_modifiers = parseClickModifiers(input.modifiers) catch {
        return failCommand("click", "INVALID_INPUT", "invalid click modifier");
    };

    switch (builtin.target.os.tag) {
        .macos => {
            const point: c.CGPoint = .{
                .x = input.point.x,
                .y = input.point.y,
            };
            const flags = macosEventFlagsForModifiers(parsed_modifiers);

            postModifierKeysMacos(parsed_modifiers, true, flags) catch {
                return failCommand("click", "EVENT_POST_FAILED", "failed to press click modifier");
            };
            defer postModifierKeysMacos(parsed_modifiers, false, flags) catch {};

            var index: u32 = 0;
            while (index < click_count) : (index += 1) {
                const click_state = @as(i64, @intCast(index + 1));
                postClickPair(point, button_kind, click_state, flags) catch {
                    return failCommand("click", "EVENT_POST_FAILED", "failed to post click event");
                };

                if (index + 1 < click_count) {
                    std.Thread.sleep(80 * std.time.ns_per_ms);
                }
            }

            return okCommand();
        },
        .windows => {
            moveCursorToPointWindows(input.point) catch {
                return failCommand("click", "EVENT_POST_FAILED", "failed to move mouse cursor");
            };

            postModifierKeysWindows(parsed_modifiers, true);
            defer postModifierKeysWindows(parsed_modifiers, false);

            var index: u32 = 0;
            while (index < click_count) : (index += 1) {
                postMouseButtonEventWindows(button_kind, true) catch {
                    return failCommand("click", "EVENT_POST_FAILED", "failed to post click event");
                };
                postMouseButtonEventWindows(button_kind, false) catch {
                    return failCommand("click", "EVENT_POST_FAILED", "failed to post click event");
                };

                if (index + 1 < click_count) {
                    std.Thread.sleep(80 * std.time.ns_per_ms);
                }
            }

            return okCommand();
        },
        .linux => {
            const display = openX11Display() catch {
                return failCommand("click", "EVENT_POST_FAILED", "failed to open X11 display");
            };
            defer _ = c_x11.XCloseDisplay(display);

            moveCursorToPointX11(.{ .x = input.point.x, .y = input.point.y }, display) catch {
                return failCommand("click", "EVENT_POST_FAILED", "failed to move mouse cursor");
            };

            postModifierKeysX11(display, parsed_modifiers, true) catch {
                return failCommand("click", "EVENT_POST_FAILED", "failed to press click modifier");
            };
            defer postModifierKeysX11(display, parsed_modifiers, false) catch {};

            var index: u32 = 0;
            while (index < click_count) : (index += 1) {
                postClickPairX11(.{ .x = input.point.x, .y = input.point.y }, button_kind, display) catch {
                    return failCommand("click", "EVENT_POST_FAILED", "failed to post click event");
                };

                if (index + 1 < click_count) {
                    std.Thread.sleep(80 * std.time.ns_per_ms);
                }
            }

            _ = c_x11.XFlush(display);
            return okCommand();
        },
        else => {
            return failCommand("click", "UNSUPPORTED_PLATFORM", "click is unsupported on this platform");
        },
    }
}

pub fn mouseMove(input: MouseMoveInput) CommandResult {
    switch (builtin.target.os.tag) {
        .macos => {
            const point: c.CGPoint = .{
                .x = input.x,
                .y = input.y,
            };
            moveCursorToPoint(point) catch {
                return failCommand("mouse-move", "EVENT_POST_FAILED", "failed to move mouse cursor");
            };

            return okCommand();
        },
        .windows => {
            moveCursorToPointWindows(.{ .x = input.x, .y = input.y }) catch {
                return failCommand("mouse-move", "EVENT_POST_FAILED", "failed to move mouse cursor");
            };

            return okCommand();
        },
        .linux => {
            const display = openX11Display() catch {
                return failCommand("mouse-move", "EVENT_POST_FAILED", "failed to open X11 display");
            };
            defer _ = c_x11.XCloseDisplay(display);

            moveCursorToPointX11(.{ .x = input.x, .y = input.y }, display) catch {
                return failCommand("mouse-move", "EVENT_POST_FAILED", "failed to move mouse cursor");
            };
            _ = c_x11.XFlush(display);
            return okCommand();
        },
        else => {
            return failCommand("mouse-move", "UNSUPPORTED_PLATFORM", "mouse-move is unsupported on this platform");
        },
    }
}

pub fn mouseDown(input: MouseButtonInput) CommandResult {
    return handleMouseButtonInput(.{ .input = input, .is_down = true });
}

pub fn mouseUp(input: MouseButtonInput) CommandResult {
    return handleMouseButtonInput(.{ .input = input, .is_down = false });
}

fn handleMouseButtonInput(args: struct {
    input: MouseButtonInput,
    is_down: bool,
}) CommandResult {
    const button_kind = resolveMouseButton(args.input.button orelse "left") catch {
        return failCommand("mouse-button", "INVALID_INPUT", "invalid mouse button");
    };

    switch (builtin.target.os.tag) {
        .macos => {
            const point = currentCursorPoint() catch {
                return failCommand("mouse-button", "CURSOR_READ_FAILED", "failed to read cursor position");
            };

            postMouseButtonEvent(point, button_kind, args.is_down, 1, 0) catch {
                return failCommand("mouse-button", "EVENT_POST_FAILED", "failed to post mouse button event");
            };

            return okCommand();
        },
        .windows => {
            postMouseButtonEventWindows(button_kind, args.is_down) catch {
                return failCommand("mouse-button", "EVENT_POST_FAILED", "failed to post mouse button event");
            };

            return okCommand();
        },
        .linux => {
            const display = openX11Display() catch {
                return failCommand("mouse-button", "EVENT_POST_FAILED", "failed to open X11 display");
            };
            defer _ = c_x11.XCloseDisplay(display);

            postMouseButtonEventX11(button_kind, args.is_down, display) catch {
                return failCommand("mouse-button", "EVENT_POST_FAILED", "failed to post mouse button event");
            };
            _ = c_x11.XFlush(display);

            return okCommand();
        },
        else => {
            return failCommand("mouse-button", "UNSUPPORTED_PLATFORM", "mouse button events are unsupported on this platform");
        },
    }
}

pub fn mousePosition() DataResult(Point) {
    switch (builtin.target.os.tag) {
        .macos => {
            const point = currentCursorPoint() catch {
                return failData(Point, "mouse-position", "CURSOR_READ_FAILED", "failed to read cursor position");
            };

            return okData(Point, .{ .x = std.math.round(point.x), .y = std.math.round(point.y) });
        },
        .windows => {
            ensureWindowsDpiAware();
            var point: c_windows.POINT = std.mem.zeroes(c_windows.POINT);
            if (c_windows.GetCursorPos(&point) == 0) {
                return failData(Point, "mouse-position", "CURSOR_READ_FAILED", "failed to read cursor position");
            }

            return okData(Point, .{ .x = @floatFromInt(point.x), .y = @floatFromInt(point.y) });
        },
        .linux => {
            const display = openX11Display() catch {
                return failData(Point, "mouse-position", "EVENT_POST_FAILED", "failed to open X11 display");
            };
            defer _ = c_x11.XCloseDisplay(display);

            const point = currentCursorPointX11(display) catch {
                return failData(Point, "mouse-position", "CURSOR_READ_FAILED", "failed to read cursor position");
            };

            return okData(Point, .{ .x = @floatFromInt(point.x), .y = @floatFromInt(point.y) });
        },
        else => {
            return failData(Point, "mouse-position", "UNSUPPORTED_PLATFORM", "mouse-position is unsupported on this platform");
        },
    }
}

pub fn hover(input: Point) CommandResult {
    return mouseMove(input);
}

// ─── Bezier helpers ───

/// Average human drawing speed: 500 px/s = 0.5 px/ms.
const drag_velocity_px_per_ms: f64 = 0.5;
/// Minimum drag duration to ensure the OS registers all events.
const drag_min_duration_ms: i64 = 200;

/// Quadratic bezier: P(t) = (1-t)²·A + 2(1-t)t·CP + t²·B
fn bezierQuadratic(a: Point, cp: Point, b: Point, t: f64) Point {
    const u = 1.0 - t;
    return .{
        .x = u * u * a.x + 2.0 * u * t * cp.x + t * t * b.x,
        .y = u * u * a.y + 2.0 * u * t * cp.y + t * t * b.y,
    };
}

/// Estimate arc length of a drag path.
/// For quadratic bezier: control polygon length (A→CP + CP→B).
/// For straight line: distance A→B.
fn estimateDragArcLength(from: Point, to: Point, cp: ?Point) f64 {
    if (cp) |control| {
        const d1 = @sqrt((control.x - from.x) * (control.x - from.x) + (control.y - from.y) * (control.y - from.y));
        const d2 = @sqrt((to.x - control.x) * (to.x - control.x) + (to.y - control.y) * (to.y - control.y));
        return d1 + d2;
    }
    return @sqrt((to.x - from.x) * (to.x - from.x) + (to.y - from.y) * (to.y - from.y));
}

/// Compute drag duration from arc length and hardcoded velocity.
/// Returns duration in milliseconds, clamped to minimum.
fn computeDragDurationMs(from: Point, to: Point, cp: ?Point) i64 {
    const arc_length = estimateDragArcLength(from, to, cp);
    const computed = @as(i64, @intFromFloat(@round(arc_length / drag_velocity_px_per_ms)));
    return @max(computed, drag_min_duration_ms);
}

/// Evaluate a drag point at parameter t (0→1).
/// Uses quadratic bezier when cp is present, linear interpolation otherwise.
fn evalDragPoint(from: Point, to: Point, cp: ?Point, t: f64) Point {
    if (cp) |control| {
        return bezierQuadratic(from, control, to, t);
    }
    return .{
        .x = from.x + (to.x - from.x) * t,
        .y = from.y + (to.y - from.y) * t,
    };
}

pub fn drag(input: DragInput) CommandResult {
    const button_kind = resolveMouseButton(input.button orelse "left") catch {
        return failCommand("drag", "INVALID_INPUT", "invalid drag button");
    };
    // Auto-compute duration from arc length and velocity, or use explicit override.
    const duration_ms = if (input.durationMs) |value| blk: {
        const normalized = @as(i64, @intFromFloat(std.math.round(value)));
        if (normalized <= 0) break :blk drag_min_duration_ms;
        break :blk normalized;
    } else computeDragDurationMs(input.from, input.to, input.cp);
    const total_duration_ns = @as(u64, @intCast(duration_ms)) * std.time.ns_per_ms;
    const step_count: u64 = 32;
    const step_duration_ns = if (step_count == 0) 0 else total_duration_ns / step_count;

    switch (builtin.target.os.tag) {
        .macos => {
            const from: c.CGPoint = .{ .x = input.from.x, .y = input.from.y };

            moveCursorToPoint(from) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to move cursor to drag origin");
            };

            postMouseButtonEvent(from, button_kind, true, 1, 0) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to post drag mouse-down");
            };

            var index: u64 = 1;
            while (index <= step_count) : (index += 1) {
                const fraction = @as(f64, @floatFromInt(index)) / @as(f64, @floatFromInt(step_count));
                const p = evalDragPoint(input.from, input.to, input.cp, fraction);
                const next_point: c.CGPoint = .{ .x = p.x, .y = p.y };

                moveCursorToPoint(next_point) catch {
                    return failCommand("drag", "EVENT_POST_FAILED", "failed during drag cursor movement");
                };

                if (step_duration_ns > 0 and index < step_count) {
                    std.Thread.sleep(step_duration_ns);
                }
            }

            const end = evalDragPoint(input.from, input.to, input.cp, 1.0);
            postMouseButtonEvent(.{ .x = end.x, .y = end.y }, button_kind, false, 1, 0) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to post drag mouse-up");
            };

            return okCommand();
        },
        .windows => {
            moveCursorToPointWindows(input.from) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to move cursor to drag origin");
            };

            postMouseButtonEventWindows(button_kind, true) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to post drag mouse-down");
            };

            var index: u64 = 1;
            while (index <= step_count) : (index += 1) {
                const fraction = @as(f64, @floatFromInt(index)) / @as(f64, @floatFromInt(step_count));
                const p = evalDragPoint(input.from, input.to, input.cp, fraction);

                moveCursorToPointWindows(p) catch {
                    return failCommand("drag", "EVENT_POST_FAILED", "failed during drag cursor movement");
                };

                if (step_duration_ns > 0 and index < step_count) {
                    std.Thread.sleep(step_duration_ns);
                }
            }

            postMouseButtonEventWindows(button_kind, false) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to post drag mouse-up");
            };

            return okCommand();
        },
        .linux => {
            const display = openX11Display() catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to open X11 display");
            };
            defer _ = c_x11.XCloseDisplay(display);

            moveCursorToPointX11(.{ .x = input.from.x, .y = input.from.y }, display) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to move cursor to drag origin");
            };

            postMouseButtonEventX11(button_kind, true, display) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to post drag mouse-down");
            };

            var index: u64 = 1;
            while (index <= step_count) : (index += 1) {
                const fraction = @as(f64, @floatFromInt(index)) / @as(f64, @floatFromInt(step_count));
                const p = evalDragPoint(input.from, input.to, input.cp, fraction);

                moveCursorToPointX11(p, display) catch {
                    return failCommand("drag", "EVENT_POST_FAILED", "failed during drag cursor movement");
                };

                if (step_duration_ns > 0 and index < step_count) {
                    std.Thread.sleep(step_duration_ns);
                }
            }

            postMouseButtonEventX11(button_kind, false, display) catch {
                return failCommand("drag", "EVENT_POST_FAILED", "failed to post drag mouse-up");
            };
            _ = c_x11.XFlush(display);

            return okCommand();
        },
        else => {
            return failCommand("drag", "UNSUPPORTED_PLATFORM", "drag is unsupported on this platform");
        },
    }
}

pub fn displayList() DataResult([]const u8) {
    if (builtin.target.os.tag == .windows) {
        const displays = enumerateWindowsDisplays(std.heap.c_allocator) catch {
            return failData([]const u8, "display-list", "DISPLAY_QUERY_FAILED", "failed to query active displays");
        };
        defer std.heap.c_allocator.free(displays);

        var write_buffer: [32 * 1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&write_buffer);
        const writer = stream.writer();

        writer.writeByte('[') catch {
            return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
        };

        var i: usize = 0;
        while (i < displays.len) : (i += 1) {
            if (i > 0) {
                writer.writeByte(',') catch {
                    return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
                };
            }

            var name_buffer: [64]u8 = undefined;
            const display_name = std.fmt.bufPrint(&name_buffer, "Display {d}", .{i}) catch "Display";
            const item = DisplayInfoOutput{
                .id = displays[i].id,
                .index = @intCast(i),
                .name = display_name,
                .x = @floatFromInt(displays[i].bounds.x),
                .y = @floatFromInt(displays[i].bounds.y),
                .width = @floatFromInt(displays[i].bounds.width),
                .height = @floatFromInt(displays[i].bounds.height),
                .scale = 1,
                .isPrimary = displays[i].is_primary,
            };

            writer.print("{f}", .{std.json.fmt(item, .{})}) catch {
                return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
            };
        }

        writer.writeByte(']') catch {
            return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
        };

        const payload = std.heap.c_allocator.dupe(u8, stream.getWritten()) catch {
            return failData([]const u8, "display-list", "ALLOC_FAILED", "failed to allocate display list response");
        };
        return okData([]const u8, payload);
    }

    if (builtin.target.os.tag == .linux) {
        const display = openX11Display() catch {
            return failData([]const u8, "display-list", "DISPLAY_QUERY_FAILED", "failed to open X11 display");
        };
        defer _ = c_x11.XCloseDisplay(display);

        const screen_count: usize = @intCast(c_x11.XScreenCount(display));
        if (screen_count == 0) {
            return failData([]const u8, "display-list", "DISPLAY_QUERY_FAILED", "failed to query active displays");
        }

        const primary_screen = c_x11.XDefaultScreen(display);

        var write_buffer: [32 * 1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&write_buffer);
        const writer = stream.writer();

        writer.writeByte('[') catch {
            return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
        };

        var i: usize = 0;
        while (i < screen_count) : (i += 1) {
            if (i > 0) {
                writer.writeByte(',') catch {
                    return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
                };
            }

            var name_buffer: [64]u8 = undefined;
            const display_name = std.fmt.bufPrint(&name_buffer, "Display {d}", .{i}) catch "Display";
            const screen_index: c_int = @intCast(i);
            const root = c_x11.XRootWindow(display, screen_index);
            const width = c_x11.XDisplayWidth(display, screen_index);
            const height = c_x11.XDisplayHeight(display, screen_index);

            const item = DisplayInfoOutput{
                .id = @as(u32, @truncate(@as(u64, @intCast(root)))),
                .index = @intCast(i),
                .name = display_name,
                .x = 0,
                .y = 0,
                .width = @floatFromInt(width),
                .height = @floatFromInt(height),
                .scale = 1,
                .isPrimary = screen_index == primary_screen,
            };

            writer.print("{f}", .{std.json.fmt(item, .{})}) catch {
                return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
            };
        }

        writer.writeByte(']') catch {
            return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
        };

        const payload = std.heap.c_allocator.dupe(u8, stream.getWritten()) catch {
            return failData([]const u8, "display-list", "ALLOC_FAILED", "failed to allocate display list response");
        };
        return okData([]const u8, payload);
    }

    if (builtin.target.os.tag != .macos) {
        return failData([]const u8, "display-list", "UNSUPPORTED_PLATFORM", "display-list is unsupported on this platform");
    }

    var display_ids: [16]c.CGDirectDisplayID = undefined;
    var display_count: u32 = 0;
    const list_result = c.CGGetActiveDisplayList(display_ids.len, &display_ids, &display_count);
    if (list_result != c.kCGErrorSuccess) {
        return failData([]const u8, "display-list", "DISPLAY_QUERY_FAILED", "failed to query active displays");
    }

    var write_buffer: [32 * 1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&write_buffer);
    const writer = stream.writer();

    writer.writeByte('[') catch {
        return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
    };

    var i: usize = 0;
    while (i < display_count) : (i += 1) {
        if (i > 0) {
            writer.writeByte(',') catch {
                return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
            };
        }

        const display_id = display_ids[i];
        const bounds = c.CGDisplayBounds(display_id);
        var name_buffer: [64]u8 = undefined;
        const fallback_name = std.fmt.bufPrint(&name_buffer, "Display {d}", .{display_id}) catch "Display";
        const item = DisplayInfoOutput{
            .id = display_id,
            .index = @intCast(i),
            .name = fallback_name,
            .x = std.math.round(bounds.origin.x),
            .y = std.math.round(bounds.origin.y),
            .width = std.math.round(bounds.size.width),
            .height = std.math.round(bounds.size.height),
            .scale = 1,
            .isPrimary = c.CGDisplayIsMain(display_id) != 0,
        };

        writer.print("{f}", .{std.json.fmt(item, .{})}) catch {
            return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
        };
    }

    writer.writeByte(']') catch {
        return failData([]const u8, "display-list", "SERIALIZE_FAILED", "failed to serialize display list");
    };

    // TODO: Add Mission Control desktop/space enumeration via private SkyLight APIs.
    const payload = std.heap.c_allocator.dupe(u8, stream.getWritten()) catch {
        return failData([]const u8, "display-list", "ALLOC_FAILED", "failed to allocate display list response");
    };
    return okData([]const u8, payload);
}

pub fn windowList() DataResult([]const u8) {
    if (builtin.target.os.tag == .windows) {
        const payload = serializeWindowListJsonWindows() catch {
            return failData([]const u8, "window-list", "WINDOW_QUERY_FAILED", "failed to query visible windows");
        };
        return okData([]const u8, payload);
    }

    if (builtin.target.os.tag != .macos) {
        return failData([]const u8, "window-list", "UNSUPPORTED_PLATFORM", "window-list is unsupported on this platform");
    }

    const payload = serializeWindowListJson() catch {
        return failData([]const u8, "window-list", "WINDOW_QUERY_FAILED", "failed to query visible windows");
    };
    return okData([]const u8, payload);
}

pub fn typeText(input: TypeTextInput) CommandResult {
    switch (builtin.target.os.tag) {
        .macos => {
            typeTextMacos(input) catch |err| {
                return failCommand("type-text", "EVENT_POST_FAILED", @errorName(err));
            };
            return okCommand();
        },
        .windows => {
            typeTextWindows(input) catch |err| {
                return failCommand("type-text", "EVENT_POST_FAILED", @errorName(err));
            };
            return okCommand();
        },
        .linux => {
            typeTextX11(input) catch |err| {
                return failCommand("type-text", "EVENT_POST_FAILED", @errorName(err));
            };
            return okCommand();
        },
        else => {
            return failCommand("type-text", "UNSUPPORTED_PLATFORM", "type-text is unsupported on this platform");
        },
    }
}

pub fn press(input: PressInput) CommandResult {
    switch (builtin.target.os.tag) {
        .macos => {
            pressMacos(input) catch |err| {
                return failCommand("press", "EVENT_POST_FAILED", @errorName(err));
            };
            return okCommand();
        },
        .windows => {
            pressWindows(input) catch |err| {
                return failCommand("press", "EVENT_POST_FAILED", @errorName(err));
            };
            return okCommand();
        },
        .linux => {
            pressX11(input) catch |err| {
                return failCommand("press", "EVENT_POST_FAILED", @errorName(err));
            };
            return okCommand();
        },
        else => {
            return failCommand("press", "UNSUPPORTED_PLATFORM", "press is unsupported on this platform");
        },
    }
}

pub fn scroll(input: ScrollInput) CommandResult {
    scroll_impl.scroll(.{
        .direction = input.direction,
        .amount = input.amount,
        .at_x = if (input.at) |point| point.x else null,
        .at_y = if (input.at) |point| point.y else null,
    }) catch |err| {
        const error_name = @errorName(err);
        if (std.mem.eql(u8, error_name, "InvalidDirection") or
            std.mem.eql(u8, error_name, "InvalidAmount") or
            std.mem.eql(u8, error_name, "AmountTooLarge") or
            std.mem.eql(u8, error_name, "InvalidPoint"))
        {
            return failCommand("scroll", "INVALID_INPUT", error_name);
        }
        return failCommand("scroll", "EVENT_POST_FAILED", error_name);
    };
    return okCommand();
}

const ParsedModifiers = struct {
    cmd: bool = false,
    alt: bool = false,
    ctrl: bool = false,
    shift: bool = false,
    fn_key: bool = false,
};

const ParsedPress = struct {
    key: []const u8,
    modifiers: ParsedModifiers = .{},
};

fn parseModifierToken(token: []const u8, modifiers: *ParsedModifiers) bool {
    if (std.ascii.eqlIgnoreCase(token, "cmd") or std.ascii.eqlIgnoreCase(token, "command") or std.ascii.eqlIgnoreCase(token, "meta")) {
        modifiers.cmd = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(token, "alt") or std.ascii.eqlIgnoreCase(token, "option")) {
        modifiers.alt = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(token, "ctrl") or std.ascii.eqlIgnoreCase(token, "control")) {
        modifiers.ctrl = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(token, "shift")) {
        modifiers.shift = true;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(token, "fn")) {
        modifiers.fn_key = true;
        return true;
    }
    return false;
}

fn parsePressKey(key_input: []const u8) !ParsedPress {
    var parsed: ParsedPress = .{ .key = "" };
    var saw_key = false;
    var parts = std.mem.splitScalar(u8, key_input, '+');
    while (parts.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t\r\n");
        if (trimmed.len == 0) {
            continue;
        }

        if (parseModifierToken(trimmed, &parsed.modifiers)) {
            continue;
        }

        if (saw_key) {
            return error.MultipleMainKeys;
        }
        parsed.key = trimmed;
        saw_key = true;
    }

    if (!saw_key) {
        return error.MissingMainKey;
    }
    return parsed;
}

fn parseClickModifiers(raw_modifiers: []const []const u8) !ParsedModifiers {
    var parsed: ParsedModifiers = .{};

    for (raw_modifiers) |raw_modifier| {
        var parts = std.mem.tokenizeAny(u8, raw_modifier, "+,");
        var saw_modifier = false;
        while (parts.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " \t\r\n");
            if (trimmed.len == 0) {
                continue;
            }
            if (!parseModifierToken(trimmed, &parsed)) {
                return error.UnknownModifier;
            }
            saw_modifier = true;
        }
        if (!saw_modifier and raw_modifier.len > 0) {
            return error.UnknownModifier;
        }
    }

    return parsed;
}

fn macosEventFlagsForModifiers(modifiers: ParsedModifiers) c_macos.CGEventFlags {
    var flags: c_macos.CGEventFlags = 0;
    if (modifiers.cmd) flags |= c_macos.kCGEventFlagMaskCommand;
    if (modifiers.alt) flags |= c_macos.kCGEventFlagMaskAlternate;
    if (modifiers.ctrl) flags |= c_macos.kCGEventFlagMaskControl;
    if (modifiers.shift) flags |= c_macos.kCGEventFlagMaskShift;
    if (modifiers.fn_key) flags |= c_macos.kCGEventFlagMaskSecondaryFn;
    return flags;
}

test "parsePressKey recognizes modifier aliases" {
    const parsed = try parsePressKey("command+option+shift+k");

    try std.testing.expectEqualStrings("k", parsed.key);
    try std.testing.expect(parsed.modifiers.cmd);
    try std.testing.expect(parsed.modifiers.alt);
    try std.testing.expect(parsed.modifiers.shift);
    try std.testing.expect(!parsed.modifiers.ctrl);
}

test "parseClickModifiers accepts repeated and combined modifiers" {
    const parsed = try parseClickModifiers(&.{ "cmd", "option+shift" });

    try std.testing.expect(parsed.cmd);
    try std.testing.expect(parsed.alt);
    try std.testing.expect(parsed.shift);
    try std.testing.expect(!parsed.ctrl);
}

test "parseClickModifiers rejects non modifier keys" {
    try std.testing.expectError(error.UnknownModifier, parseClickModifiers(&.{"enter"}));
}

fn normalizedCount(value: ?f64) u32 {
    if (value) |count| {
        const rounded = @as(i64, @intFromFloat(std.math.round(count)));
        if (rounded > 0) {
            return @as(u32, @intCast(rounded));
        }
    }
    return 1;
}

fn normalizedDelayNs(value: ?f64) u64 {
    if (value) |delay_ms| {
        const rounded = @as(i64, @intFromFloat(std.math.round(delay_ms)));
        if (rounded > 0) {
            return @as(u64, @intCast(rounded)) * std.time.ns_per_ms;
        }
    }
    return 0;
}

fn codepointToUtf16(codepoint: u21) !struct { units: [2]u16, len: usize } {
    if (codepoint <= 0xD7FF or (codepoint >= 0xE000 and codepoint <= 0xFFFF)) {
        return .{ .units = .{ @as(u16, @intCast(codepoint)), 0 }, .len = 1 };
    }
    if (codepoint >= 0x10000 and codepoint <= 0x10FFFF) {
        const value = codepoint - 0x10000;
        const high = @as(u16, @intCast(0xD800 + (value >> 10)));
        const low = @as(u16, @intCast(0xDC00 + (value & 0x3FF)));
        return .{ .units = .{ high, low }, .len = 2 };
    }
    return error.InvalidCodepoint;
}

fn typeTextMacos(input: TypeTextInput) !void {
    const delay_ns = normalizedDelayNs(input.delayMs);
    var view = try std.unicode.Utf8View.init(input.text);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        const utf16 = try codepointToUtf16(codepoint);
        const down = c_macos.CGEventCreateKeyboardEvent(null, 0, true) orelse return error.CGEventCreateFailed;
        defer c_macos.CFRelease(down);
        c_macos.CGEventSetFlags(down, 0);
        c_macos.CGEventKeyboardSetUnicodeString(down, @as(c_macos.UniCharCount, @intCast(utf16.len)), @ptrCast(&utf16.units[0]));
        c_macos.CGEventPost(c_macos.kCGHIDEventTap, down);

        const up = c_macos.CGEventCreateKeyboardEvent(null, 0, false) orelse return error.CGEventCreateFailed;
        defer c_macos.CFRelease(up);
        c_macos.CGEventSetFlags(up, 0);
        c_macos.CGEventKeyboardSetUnicodeString(up, @as(c_macos.UniCharCount, @intCast(utf16.len)), @ptrCast(&utf16.units[0]));
        c_macos.CGEventPost(c_macos.kCGHIDEventTap, up);

        if (delay_ns > 0) {
            std.Thread.sleep(delay_ns);
        }
    }
}

fn keyCodeForMacosKey(key_name: []const u8) !c_macos.CGKeyCode {
    if (key_name.len == 1) {
        const ch = std.ascii.toLower(key_name[0]);
        return switch (ch) {
            'a' => mac_keycode.a,
            'b' => mac_keycode.b,
            'c' => mac_keycode.c,
            'd' => mac_keycode.d,
            'e' => mac_keycode.e,
            'f' => mac_keycode.f,
            'g' => mac_keycode.g,
            'h' => mac_keycode.h,
            'i' => mac_keycode.i,
            'j' => mac_keycode.j,
            'k' => mac_keycode.k,
            'l' => mac_keycode.l,
            'm' => mac_keycode.m,
            'n' => mac_keycode.n,
            'o' => mac_keycode.o,
            'p' => mac_keycode.p,
            'q' => mac_keycode.q,
            'r' => mac_keycode.r,
            's' => mac_keycode.s,
            't' => mac_keycode.t,
            'u' => mac_keycode.u,
            'v' => mac_keycode.v,
            'w' => mac_keycode.w,
            'x' => mac_keycode.x,
            'y' => mac_keycode.y,
            'z' => mac_keycode.z,
            '0' => mac_keycode.zero,
            '1' => mac_keycode.one,
            '2' => mac_keycode.two,
            '3' => mac_keycode.three,
            '4' => mac_keycode.four,
            '5' => mac_keycode.five,
            '6' => mac_keycode.six,
            '7' => mac_keycode.seven,
            '8' => mac_keycode.eight,
            '9' => mac_keycode.nine,
            '=' => mac_keycode.equal,
            '-' => mac_keycode.minus,
            '[' => mac_keycode.left_bracket,
            ']' => mac_keycode.right_bracket,
            ';' => mac_keycode.semicolon,
            '\'' => mac_keycode.quote,
            '\\' => mac_keycode.backslash,
            ',' => mac_keycode.comma,
            '.' => mac_keycode.period,
            '/' => mac_keycode.slash,
            '`' => mac_keycode.grave,
            else => error.UnknownKey,
        };
    }

    if (std.ascii.eqlIgnoreCase(key_name, "enter") or std.ascii.eqlIgnoreCase(key_name, "return")) return mac_keycode.enter;
    if (std.ascii.eqlIgnoreCase(key_name, "tab")) return mac_keycode.tab;
    if (std.ascii.eqlIgnoreCase(key_name, "space")) return mac_keycode.space;
    if (std.ascii.eqlIgnoreCase(key_name, "escape") or std.ascii.eqlIgnoreCase(key_name, "esc")) return mac_keycode.escape;
    if (std.ascii.eqlIgnoreCase(key_name, "backspace")) return mac_keycode.delete;
    if (std.ascii.eqlIgnoreCase(key_name, "delete")) return mac_keycode.forward_delete;
    if (std.ascii.eqlIgnoreCase(key_name, "left")) return mac_keycode.left_arrow;
    if (std.ascii.eqlIgnoreCase(key_name, "right")) return mac_keycode.right_arrow;
    if (std.ascii.eqlIgnoreCase(key_name, "up")) return mac_keycode.up_arrow;
    if (std.ascii.eqlIgnoreCase(key_name, "down")) return mac_keycode.down_arrow;
    if (std.ascii.eqlIgnoreCase(key_name, "home")) return mac_keycode.home;
    if (std.ascii.eqlIgnoreCase(key_name, "end")) return mac_keycode.end;
    if (std.ascii.eqlIgnoreCase(key_name, "pageup")) return mac_keycode.page_up;
    if (std.ascii.eqlIgnoreCase(key_name, "pagedown")) return mac_keycode.page_down;
    if (std.ascii.eqlIgnoreCase(key_name, "f1")) return mac_keycode.f1;
    if (std.ascii.eqlIgnoreCase(key_name, "f2")) return mac_keycode.f2;
    if (std.ascii.eqlIgnoreCase(key_name, "f3")) return mac_keycode.f3;
    if (std.ascii.eqlIgnoreCase(key_name, "f4")) return mac_keycode.f4;
    if (std.ascii.eqlIgnoreCase(key_name, "f5")) return mac_keycode.f5;
    if (std.ascii.eqlIgnoreCase(key_name, "f6")) return mac_keycode.f6;
    if (std.ascii.eqlIgnoreCase(key_name, "f7")) return mac_keycode.f7;
    if (std.ascii.eqlIgnoreCase(key_name, "f8")) return mac_keycode.f8;
    if (std.ascii.eqlIgnoreCase(key_name, "f9")) return mac_keycode.f9;
    if (std.ascii.eqlIgnoreCase(key_name, "f10")) return mac_keycode.f10;
    if (std.ascii.eqlIgnoreCase(key_name, "f11")) return mac_keycode.f11;
    if (std.ascii.eqlIgnoreCase(key_name, "f12")) return mac_keycode.f12;

    return error.UnknownKey;
}

fn postMacosKey(key_code: c_macos.CGKeyCode, is_down: bool, flags: c_macos.CGEventFlags) !void {
    const event = c_macos.CGEventCreateKeyboardEvent(null, key_code, is_down) orelse return error.CGEventCreateFailed;
    defer c_macos.CFRelease(event);
    c_macos.CGEventSetFlags(event, flags);
    c_macos.CGEventPost(c_macos.kCGHIDEventTap, event);
}

fn postModifierKeysMacos(modifiers: ParsedModifiers, is_down: bool, flags: c_macos.CGEventFlags) !void {
    if (is_down) {
        if (modifiers.cmd) try postMacosKey(mac_keycode.command, true, flags);
        if (modifiers.alt) try postMacosKey(mac_keycode.option, true, flags);
        if (modifiers.ctrl) try postMacosKey(mac_keycode.control, true, flags);
        if (modifiers.shift) try postMacosKey(mac_keycode.shift, true, flags);
        if (modifiers.fn_key) try postMacosKey(mac_keycode.fn_key, true, flags);
        return;
    }

    if (modifiers.fn_key) try postMacosKey(mac_keycode.fn_key, false, flags);
    if (modifiers.shift) try postMacosKey(mac_keycode.shift, false, flags);
    if (modifiers.ctrl) try postMacosKey(mac_keycode.control, false, flags);
    if (modifiers.alt) try postMacosKey(mac_keycode.option, false, flags);
    if (modifiers.cmd) try postMacosKey(mac_keycode.command, false, flags);
}

fn pressMacos(input: PressInput) !void {
    const parsed = try parsePressKey(input.key);
    const key_code = try keyCodeForMacosKey(parsed.key);
    const repeat_count = normalizedCount(input.count);
    const delay_ns = normalizedDelayNs(input.delayMs);
    const flags = macosEventFlagsForModifiers(parsed.modifiers);

    var index: u32 = 0;
    while (index < repeat_count) : (index += 1) {
        try postModifierKeysMacos(parsed.modifiers, true, flags);

        try postMacosKey(key_code, true, flags);
        try postMacosKey(key_code, false, flags);

        try postModifierKeysMacos(parsed.modifiers, false, flags);

        if (delay_ns > 0 and index + 1 < repeat_count) {
            std.Thread.sleep(delay_ns);
        }
    }
}

fn typeTextWindows(input: TypeTextInput) !void {
    const delay_ns = normalizedDelayNs(input.delayMs);
    var view = try std.unicode.Utf8View.init(input.text);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        const utf16 = try codepointToUtf16(codepoint);
        var unit_index: usize = 0;
        while (unit_index < utf16.len) : (unit_index += 1) {
            const unit = utf16.units[unit_index];
            var down = std.mem.zeroes(c_windows.INPUT);
            down.type = c_windows.INPUT_KEYBOARD;
            down.unnamed_0.ki.wVk = 0;
            down.unnamed_0.ki.wScan = unit;
            down.unnamed_0.ki.dwFlags = c_windows.KEYEVENTF_UNICODE;
            _ = c_windows.SendInput(1, &down, @sizeOf(c_windows.INPUT));

            var up = down;
            up.unnamed_0.ki.dwFlags = c_windows.KEYEVENTF_UNICODE | c_windows.KEYEVENTF_KEYUP;
            _ = c_windows.SendInput(1, &up, @sizeOf(c_windows.INPUT));
        }

        if (delay_ns > 0) {
            std.Thread.sleep(delay_ns);
        }
    }
}

fn keyCodeForWindowsKey(key_name: []const u8) !u16 {
    if (key_name.len == 1) {
        const ch = std.ascii.toUpper(key_name[0]);
        if ((ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9')) {
            return ch;
        }
        return switch (key_name[0]) {
            '=' => c_windows.VK_OEM_PLUS,
            '-' => c_windows.VK_OEM_MINUS,
            '[' => c_windows.VK_OEM_4,
            ']' => c_windows.VK_OEM_6,
            ';' => c_windows.VK_OEM_1,
            '\'' => c_windows.VK_OEM_7,
            '\\' => c_windows.VK_OEM_5,
            ',' => c_windows.VK_OEM_COMMA,
            '.' => c_windows.VK_OEM_PERIOD,
            '/' => c_windows.VK_OEM_2,
            '`' => c_windows.VK_OEM_3,
            else => error.UnknownKey,
        };
    }

    if (std.ascii.eqlIgnoreCase(key_name, "enter") or std.ascii.eqlIgnoreCase(key_name, "return")) return c_windows.VK_RETURN;
    if (std.ascii.eqlIgnoreCase(key_name, "tab")) return c_windows.VK_TAB;
    if (std.ascii.eqlIgnoreCase(key_name, "space")) return c_windows.VK_SPACE;
    if (std.ascii.eqlIgnoreCase(key_name, "escape") or std.ascii.eqlIgnoreCase(key_name, "esc")) return c_windows.VK_ESCAPE;
    if (std.ascii.eqlIgnoreCase(key_name, "backspace")) return c_windows.VK_BACK;
    if (std.ascii.eqlIgnoreCase(key_name, "delete")) return c_windows.VK_DELETE;
    if (std.ascii.eqlIgnoreCase(key_name, "left")) return c_windows.VK_LEFT;
    if (std.ascii.eqlIgnoreCase(key_name, "right")) return c_windows.VK_RIGHT;
    if (std.ascii.eqlIgnoreCase(key_name, "up")) return c_windows.VK_UP;
    if (std.ascii.eqlIgnoreCase(key_name, "down")) return c_windows.VK_DOWN;
    if (std.ascii.eqlIgnoreCase(key_name, "home")) return c_windows.VK_HOME;
    if (std.ascii.eqlIgnoreCase(key_name, "end")) return c_windows.VK_END;
    if (std.ascii.eqlIgnoreCase(key_name, "pageup")) return c_windows.VK_PRIOR;
    if (std.ascii.eqlIgnoreCase(key_name, "pagedown")) return c_windows.VK_NEXT;
    if (std.ascii.eqlIgnoreCase(key_name, "f1")) return c_windows.VK_F1;
    if (std.ascii.eqlIgnoreCase(key_name, "f2")) return c_windows.VK_F2;
    if (std.ascii.eqlIgnoreCase(key_name, "f3")) return c_windows.VK_F3;
    if (std.ascii.eqlIgnoreCase(key_name, "f4")) return c_windows.VK_F4;
    if (std.ascii.eqlIgnoreCase(key_name, "f5")) return c_windows.VK_F5;
    if (std.ascii.eqlIgnoreCase(key_name, "f6")) return c_windows.VK_F6;
    if (std.ascii.eqlIgnoreCase(key_name, "f7")) return c_windows.VK_F7;
    if (std.ascii.eqlIgnoreCase(key_name, "f8")) return c_windows.VK_F8;
    if (std.ascii.eqlIgnoreCase(key_name, "f9")) return c_windows.VK_F9;
    if (std.ascii.eqlIgnoreCase(key_name, "f10")) return c_windows.VK_F10;
    if (std.ascii.eqlIgnoreCase(key_name, "f11")) return c_windows.VK_F11;
    if (std.ascii.eqlIgnoreCase(key_name, "f12")) return c_windows.VK_F12;

    return error.UnknownKey;
}

fn postWindowsVirtualKey(virtual_key: u16, is_down: bool) void {
    var event = std.mem.zeroes(c_windows.INPUT);
    event.type = c_windows.INPUT_KEYBOARD;
    event.unnamed_0.ki.wVk = virtual_key;
    event.unnamed_0.ki.wScan = 0;
    event.unnamed_0.ki.dwFlags = if (is_down) 0 else c_windows.KEYEVENTF_KEYUP;
    _ = c_windows.SendInput(1, &event, @sizeOf(c_windows.INPUT));
}

fn postModifierKeysWindows(modifiers: ParsedModifiers, is_down: bool) void {
    if (is_down) {
        if (modifiers.cmd) postWindowsVirtualKey(c_windows.VK_LWIN, true);
        if (modifiers.alt) postWindowsVirtualKey(c_windows.VK_MENU, true);
        if (modifiers.ctrl) postWindowsVirtualKey(c_windows.VK_CONTROL, true);
        if (modifiers.shift) postWindowsVirtualKey(c_windows.VK_SHIFT, true);
        return;
    }

    if (modifiers.shift) postWindowsVirtualKey(c_windows.VK_SHIFT, false);
    if (modifiers.ctrl) postWindowsVirtualKey(c_windows.VK_CONTROL, false);
    if (modifiers.alt) postWindowsVirtualKey(c_windows.VK_MENU, false);
    if (modifiers.cmd) postWindowsVirtualKey(c_windows.VK_LWIN, false);
}

fn pressWindows(input: PressInput) !void {
    const parsed = try parsePressKey(input.key);
    const key_code = try keyCodeForWindowsKey(parsed.key);
    const repeat_count = normalizedCount(input.count);
    const delay_ns = normalizedDelayNs(input.delayMs);

    var index: u32 = 0;
    while (index < repeat_count) : (index += 1) {
        postModifierKeysWindows(parsed.modifiers, true);

        postWindowsVirtualKey(key_code, true);
        postWindowsVirtualKey(key_code, false);

        postModifierKeysWindows(parsed.modifiers, false);

        if (delay_ns > 0 and index + 1 < repeat_count) {
            std.Thread.sleep(delay_ns);
        }
    }
}

fn typeTextX11(input: TypeTextInput) !void {
    const delay_ns = normalizedDelayNs(input.delayMs);
    const display = c_x11.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
    defer _ = c_x11.XCloseDisplay(display);

    for (input.text) |byte| {
        if (byte >= 0x80) {
            return error.NonAsciiUnsupported;
        }
        var key_name = [_:0]u8{ byte, 0 };
        const key_sym = c_x11.XStringToKeysym(&key_name);
        if (key_sym == 0) {
            return error.UnknownKey;
        }
        const key_code = c_x11.XKeysymToKeycode(display, @intCast(key_sym));
        _ = c_x11.XTestFakeKeyEvent(display, key_code, c_x11.True, c_x11.CurrentTime);
        _ = c_x11.XTestFakeKeyEvent(display, key_code, c_x11.False, c_x11.CurrentTime);
        _ = c_x11.XFlush(display);
        if (delay_ns > 0) {
            std.Thread.sleep(delay_ns);
        }
    }
}

fn keySymForX11Key(key_name: []const u8) !c_ulong {
    if (key_name.len == 1) {
        var key_buffer = [_:0]u8{ key_name[0], 0 };
        const key_sym = c_x11.XStringToKeysym(&key_buffer);
        if (key_sym == 0) return error.UnknownKey;
        return @intCast(key_sym);
    }

    if (std.ascii.eqlIgnoreCase(key_name, "enter") or std.ascii.eqlIgnoreCase(key_name, "return")) return c_x11.XK_Return;
    if (std.ascii.eqlIgnoreCase(key_name, "tab")) return c_x11.XK_Tab;
    if (std.ascii.eqlIgnoreCase(key_name, "space")) return c_x11.XK_space;
    if (std.ascii.eqlIgnoreCase(key_name, "escape") or std.ascii.eqlIgnoreCase(key_name, "esc")) return c_x11.XK_Escape;
    if (std.ascii.eqlIgnoreCase(key_name, "backspace")) return c_x11.XK_BackSpace;
    if (std.ascii.eqlIgnoreCase(key_name, "delete")) return c_x11.XK_Delete;
    if (std.ascii.eqlIgnoreCase(key_name, "left")) return c_x11.XK_Left;
    if (std.ascii.eqlIgnoreCase(key_name, "right")) return c_x11.XK_Right;
    if (std.ascii.eqlIgnoreCase(key_name, "up")) return c_x11.XK_Up;
    if (std.ascii.eqlIgnoreCase(key_name, "down")) return c_x11.XK_Down;
    if (std.ascii.eqlIgnoreCase(key_name, "home")) return c_x11.XK_Home;
    if (std.ascii.eqlIgnoreCase(key_name, "end")) return c_x11.XK_End;
    if (std.ascii.eqlIgnoreCase(key_name, "pageup")) return c_x11.XK_Page_Up;
    if (std.ascii.eqlIgnoreCase(key_name, "pagedown")) return c_x11.XK_Page_Down;
    return error.UnknownKey;
}

fn postX11Key(display: *c_x11.Display, key_sym: c_ulong, is_down: bool) !void {
    const key_code = c_x11.XKeysymToKeycode(display, @intCast(key_sym));
    if (key_code == 0) {
        return error.UnknownKey;
    }
    _ = c_x11.XTestFakeKeyEvent(display, key_code, if (is_down) c_x11.True else c_x11.False, c_x11.CurrentTime);
    _ = c_x11.XFlush(display);
}

fn postModifierKeysX11(display: *c_x11.Display, modifiers: ParsedModifiers, is_down: bool) !void {
    if (is_down) {
        if (modifiers.cmd) try postX11Key(display, c_x11.XK_Super_L, true);
        if (modifiers.alt) try postX11Key(display, c_x11.XK_Alt_L, true);
        if (modifiers.ctrl) try postX11Key(display, c_x11.XK_Control_L, true);
        if (modifiers.shift) try postX11Key(display, c_x11.XK_Shift_L, true);
        return;
    }

    if (modifiers.shift) try postX11Key(display, c_x11.XK_Shift_L, false);
    if (modifiers.ctrl) try postX11Key(display, c_x11.XK_Control_L, false);
    if (modifiers.alt) try postX11Key(display, c_x11.XK_Alt_L, false);
    if (modifiers.cmd) try postX11Key(display, c_x11.XK_Super_L, false);
}

fn pressX11(input: PressInput) !void {
    const parsed = try parsePressKey(input.key);
    const key_sym = try keySymForX11Key(parsed.key);
    const repeat_count = normalizedCount(input.count);
    const delay_ns = normalizedDelayNs(input.delayMs);

    const display = c_x11.XOpenDisplay(null) orelse return error.XOpenDisplayFailed;
    defer _ = c_x11.XCloseDisplay(display);

    var index: u32 = 0;
    while (index < repeat_count) : (index += 1) {
        try postModifierKeysX11(display, parsed.modifiers, true);

        try postX11Key(display, key_sym, true);
        try postX11Key(display, key_sym, false);

        try postModifierKeysX11(display, parsed.modifiers, false);

        if (delay_ns > 0 and index + 1 < repeat_count) {
            std.Thread.sleep(delay_ns);
        }
    }
}

fn createScreenshotImage(input: struct {
    display_index: ?f64,
    window_id: ?f64,
    region: ?ScreenshotRegion,
}) !ScreenshotCapture {
    if (input.window_id != null and input.region != null) {
        return error.InvalidScreenshotInput;
    }

    if (input.window_id) |window_id| {
        const normalized_window_id = normalizeWindowId(window_id) catch {
            return error.InvalidWindowId;
        };
        const window_bounds = findWindowBoundsById(normalized_window_id) catch {
            return error.WindowNotFound;
        };
        const selected_display = resolveDisplayForRect(window_bounds) catch {
            return error.DisplayResolutionFailed;
        };

        const window_image = c.CGDisplayCreateImageForRect(selected_display.id, window_bounds);
        if (window_image == null) {
            return error.CaptureFailed;
        }
        return .{
            .image = window_image,
            .capture_x = window_bounds.origin.x,
            .capture_y = window_bounds.origin.y,
            .capture_width = window_bounds.size.width,
            .capture_height = window_bounds.size.height,
            .desktop_index = selected_display.index,
        };
    }

    const selected_display = resolveDisplayId(input.display_index) catch {
        return error.DisplayResolutionFailed;
    };

    if (input.region) |region| {
        const rect: c.CGRect = .{
            .origin = .{
                .x = selected_display.bounds.origin.x + region.x,
                .y = selected_display.bounds.origin.y + region.y,
            },
            .size = .{ .width = region.width, .height = region.height },
        };
        const region_image = c.CGDisplayCreateImageForRect(selected_display.id, rect);
        if (region_image == null) {
            return error.CaptureFailed;
        }
        return .{
            .image = region_image,
            .capture_x = rect.origin.x,
            .capture_y = rect.origin.y,
            .capture_width = rect.size.width,
            .capture_height = rect.size.height,
            .desktop_index = selected_display.index,
        };
    }

    const full_image = c.CGDisplayCreateImage(selected_display.id);
    if (full_image == null) {
        return error.CaptureFailed;
    }
    return .{
        .image = full_image,
        .capture_x = selected_display.bounds.origin.x,
        .capture_y = selected_display.bounds.origin.y,
        .capture_width = selected_display.bounds.size.width,
        .capture_height = selected_display.bounds.size.height,
        .desktop_index = selected_display.index,
    };
}

fn normalizeWindowId(raw_id: f64) !u32 {
    const normalized = @as(i64, @intFromFloat(std.math.round(raw_id)));
    if (normalized <= 0) {
        return error.InvalidWindowId;
    }
    return @intCast(normalized);
}

fn findWindowBoundsById(target_window_id: u32) !c.CGRect {
    const Context = struct {
        target_id: u32,
        bounds: ?c.CGRect = null,
    };

    var context = Context{ .target_id = target_window_id };
    window.forEachVisibleWindow(Context, &context, struct {
        fn callback(ctx: *Context, info: window.WindowInfo) !void {
            if (info.id != ctx.target_id) {
                return;
            }
            ctx.bounds = .{
                .origin = .{ .x = info.bounds.x, .y = info.bounds.y },
                .size = .{ .width = info.bounds.width, .height = info.bounds.height },
            };
            return error.Found;
        }
    }.callback) catch |err| {
        if (err != error.Found) {
            return err;
        }
    };

    if (context.bounds) |bounds| {
        return bounds;
    }
    return error.WindowNotFound;
}

fn resolveDisplayForRect(rect: c.CGRect) !SelectedDisplay {
    var display_ids: [16]c.CGDirectDisplayID = undefined;
    var display_count: u32 = 0;
    const list_result = c.CGGetActiveDisplayList(display_ids.len, &display_ids, &display_count);
    if (list_result != c.kCGErrorSuccess or display_count == 0) {
        return error.DisplayQueryFailed;
    }

    var best_index: usize = 0;
    var best_overlap: f64 = -1;
    var i: usize = 0;
    while (i < display_count) : (i += 1) {
        const bounds = c.CGDisplayBounds(display_ids[i]);
        const overlap = intersectionArea(rect, bounds);
        if (overlap > best_overlap) {
            best_overlap = overlap;
            best_index = i;
        }
    }

    const id = display_ids[best_index];
    return .{
        .id = id,
        .index = best_index,
        .bounds = c.CGDisplayBounds(id),
    };
}

fn intersectionArea(a: c.CGRect, b: c.CGRect) f64 {
    const left = @max(a.origin.x, b.origin.x);
    const top = @max(a.origin.y, b.origin.y);
    const right = @min(a.origin.x + a.size.width, b.origin.x + b.size.width);
    const bottom = @min(a.origin.y + a.size.height, b.origin.y + b.size.height);
    if (right <= left or bottom <= top) {
        return 0;
    }
    return (right - left) * (bottom - top);
}

fn serializeWindowListJson() ![]u8 {
    const Context = struct {
        stream: *std.io.FixedBufferStream([]u8),
        first: bool,
    };

    var write_buffer: [64 * 1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&write_buffer);

    try stream.writer().writeByte('[');
    var context = Context{ .stream = &stream, .first = true };

    try window.forEachVisibleWindow(Context, &context, struct {
        fn callback(ctx: *Context, info: window.WindowInfo) !void {
            const rect: c.CGRect = .{
                .origin = .{ .x = info.bounds.x, .y = info.bounds.y },
                .size = .{ .width = info.bounds.width, .height = info.bounds.height },
            };
            const selected_display = resolveDisplayForRect(rect) catch {
                return;
            };
            const item = WindowInfoOutput{
                .id = info.id,
                .ownerPid = info.owner_pid,
                .ownerName = info.owner_name,
                .title = info.title,
                .x = info.bounds.x,
                .y = info.bounds.y,
                .width = info.bounds.width,
                .height = info.bounds.height,
                .desktopIndex = @intCast(selected_display.index),
            };

            if (!ctx.first) {
                try ctx.stream.writer().writeByte(',');
            }
            ctx.first = false;
            try ctx.stream.writer().print("{f}", .{std.json.fmt(item, .{})});
        }
    }.callback);

    try stream.writer().writeByte(']');
    return std.heap.c_allocator.dupe(u8, stream.getWritten());
}

const WindowsWindowListContext = struct {
    stream: *std.io.FixedBufferStream([]u8),
    first: bool,
    failed: bool = false,
};

fn queryProcessNameWindows(process_id: c_windows.DWORD, buffer: []u8) []const u8 {
    if (process_id == 0) {
        return "unknown";
    }

    const process_handle = c_windows.OpenProcess(c_windows.PROCESS_QUERY_LIMITED_INFORMATION, c_windows.FALSE, process_id);
    if (process_handle == null) {
        return "unknown";
    }
    defer _ = c_windows.CloseHandle(process_handle);

    var size: c_windows.DWORD = @as(c_windows.DWORD, @intCast(buffer.len));
    if (c_windows.QueryFullProcessImageNameA(process_handle, 0, buffer.ptr, &size) == 0 or size == 0) {
        return "unknown";
    }

    const full_path = buffer[0..size];
    if (std.mem.lastIndexOfAny(u8, full_path, "\\/")) |idx| {
        if (idx + 1 < full_path.len) {
            return full_path[idx + 1 ..];
        }
    }
    return full_path;
}

fn enumWindowsWindowCallback(hwnd: c_windows.HWND, l_param: c_windows.LPARAM) callconv(.winapi) c_int {
    const context: *WindowsWindowListContext = @ptrFromInt(@as(usize, @intCast(l_param)));

    if (c_windows.IsWindowVisible(hwnd) == 0) {
        return c_windows.TRUE;
    }

    if (c_windows.GetWindow(hwnd, c_windows.GW_OWNER) != null) {
        return c_windows.TRUE;
    }

    const ex_style = @as(c_ulong, @intCast(c_windows.GetWindowLongPtrA(hwnd, c_windows.GWL_EXSTYLE)));
    if ((ex_style & c_windows.WS_EX_TOOLWINDOW) != 0 or (ex_style & c_windows.WS_EX_NOACTIVATE) != 0) {
        return c_windows.TRUE;
    }

    const title_length = c_windows.GetWindowTextLengthA(hwnd);
    if (title_length <= 0) {
        return c_windows.TRUE;
    }

    var title_buffer: [512]u8 = undefined;
    const copied = c_windows.GetWindowTextA(hwnd, &title_buffer, title_buffer.len);
    if (copied <= 0) {
        return c_windows.TRUE;
    }
    const title = title_buffer[0..@as(usize, @intCast(copied))];

    var rect: c_windows.RECT = std.mem.zeroes(c_windows.RECT);
    if (c_windows.GetWindowRect(hwnd, &rect) == 0) {
        return c_windows.TRUE;
    }
    const width = rect.right - rect.left;
    const height = rect.bottom - rect.top;
    if (width <= 0 or height <= 0) {
        return c_windows.TRUE;
    }

    var process_id: c_windows.DWORD = 0;
    _ = c_windows.GetWindowThreadProcessId(hwnd, &process_id);

    var process_name_buffer: [512]u8 = undefined;
    const owner_name = queryProcessNameWindows(process_id, &process_name_buffer);
    const desktop_index = resolveWindowsDesktopIndexForRect(.{
        .x = rect.left,
        .y = rect.top,
        .width = width,
        .height = height,
    }) catch 0;

    const item = WindowInfoOutput{
        .id = @as(u32, @truncate(@as(usize, @intFromPtr(hwnd)))),
        .ownerPid = @as(i32, @intCast(process_id)),
        .ownerName = owner_name,
        .title = title,
        .x = @floatFromInt(rect.left),
        .y = @floatFromInt(rect.top),
        .width = @floatFromInt(width),
        .height = @floatFromInt(height),
        .desktopIndex = @intCast(desktop_index),
    };

    if (!context.first) {
        context.stream.writer().writeByte(',') catch {
            context.failed = true;
            return c_windows.FALSE;
        };
    }
    context.first = false;

    context.stream.writer().print("{f}", .{std.json.fmt(item, .{})}) catch {
        context.failed = true;
        return c_windows.FALSE;
    };

    return c_windows.TRUE;
}

fn serializeWindowListJsonWindows() ![]u8 {
    if (builtin.target.os.tag != .windows) {
        return error.UnsupportedPlatform;
    }

    var write_buffer: [64 * 1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&write_buffer);
    try stream.writer().writeByte('[');

    var context = WindowsWindowListContext{ .stream = &stream, .first = true };
    const ok = c_windows.EnumWindows(
        enumWindowsWindowCallback,
        @as(c_windows.LPARAM, @intCast(@intFromPtr(&context))),
    );
    if (ok == 0 or context.failed) {
        return error.WindowQueryFailed;
    }

    try stream.writer().writeByte(']');
    return std.heap.c_allocator.dupe(u8, stream.getWritten());
}

fn scaleScreenshotImageIfNeeded(image: c.CGImageRef) !ScaledScreenshotImage {
    const image_width = @as(f64, @floatFromInt(c.CGImageGetWidth(image)));
    const image_height = @as(f64, @floatFromInt(c.CGImageGetHeight(image)));
    const long_edge = @max(image_width, image_height);
    if (long_edge <= screenshot_max_long_edge_px) {
        _ = c.CFRetain(image);
        return .{
            .image = image,
            .width = image_width,
            .height = image_height,
        };
    }

    const scale = screenshot_max_long_edge_px / long_edge;
    const target_width = @max(1, @as(usize, @intFromFloat(std.math.round(image_width * scale))));
    const target_height = @max(1, @as(usize, @intFromFloat(std.math.round(image_height * scale))));

    const color_space = c.CGColorSpaceCreateDeviceRGB();
    if (color_space == null) {
        return error.ScaleFailed;
    }
    defer c.CFRelease(color_space);

    const bitmap_info: c.CGBitmapInfo = c.kCGImageAlphaPremultipliedLast;
    const context = c.CGBitmapContextCreate(
        null,
        target_width,
        target_height,
        8,
        0,
        color_space,
        bitmap_info,
    );
    if (context == null) {
        return error.ScaleFailed;
    }
    defer c.CFRelease(context);

    c.CGContextSetInterpolationQuality(context, c.kCGInterpolationHigh);
    const draw_rect: c.CGRect = .{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{
            .width = @as(c.CGFloat, @floatFromInt(target_width)),
            .height = @as(c.CGFloat, @floatFromInt(target_height)),
        },
    };
    c.CGContextDrawImage(context, draw_rect, image);

    const scaled = c.CGBitmapContextCreateImage(context);
    if (scaled == null) {
        return error.ScaleFailed;
    }
    return .{
        .image = scaled,
        .width = @as(f64, @floatFromInt(target_width)),
        .height = @as(f64, @floatFromInt(target_height)),
    };
}

fn resolveDisplayId(display_index: ?f64) !SelectedDisplay {
    const selected_index: usize = if (display_index) |value| blk: {
        const normalized = @as(i64, @intFromFloat(std.math.round(value)));
        if (normalized < 0) {
            return error.InvalidDisplayIndex;
        }
        break :blk @as(usize, @intCast(normalized));
    } else 0;
    var display_ids: [16]c.CGDirectDisplayID = undefined;
    var display_count: u32 = 0;
    const list_result = c.CGGetActiveDisplayList(display_ids.len, &display_ids, &display_count);
    if (list_result != c.kCGErrorSuccess) {
        return error.DisplayQueryFailed;
    }
    if (selected_index >= display_count) {
        return error.InvalidDisplayIndex;
    }
    const selected_id = display_ids[selected_index];
    const bounds = c.CGDisplayBounds(selected_id);
    return .{
        .id = selected_id,
        .index = selected_index,
        .bounds = bounds,
    };
}

fn writeScreenshotPng(input: struct {
    image: c.CGImageRef,
    output_path: []const u8,
}) !void {
    const path_as_u8: [*]const u8 = @ptrCast(input.output_path.ptr);
    const file_url = c.CFURLCreateFromFileSystemRepresentation(
        null,
        path_as_u8,
        @as(c_long, @intCast(input.output_path.len)),
        0,
    );
    if (file_url == null) {
        return error.FileUrlCreateFailed;
    }
    defer c.CFRelease(file_url);

    const png_type = c.CFStringCreateWithCString(null, "public.png", c.kCFStringEncodingUTF8);
    if (png_type == null) {
        return error.PngTypeCreateFailed;
    }
    defer c.CFRelease(png_type);

    const destination = c.CGImageDestinationCreateWithURL(file_url, png_type, 1, null);
    if (destination == null) {
        return error.ImageDestinationCreateFailed;
    }
    defer c.CFRelease(destination);

    c.CGImageDestinationAddImage(destination, input.image, null);
    const did_finalize = c.CGImageDestinationFinalize(destination);
    if (!did_finalize) {
        return error.ImageDestinationFinalizeFailed;
    }
}

/// Draw a red crosshair+circle debug marker on an existing PNG file (macOS only).
/// Reads the PNG, draws the marker at (x, y) in image coordinates, writes back.
pub fn drawMarkerOnPng(input: struct {
    path: []const u8,
    x: f64,
    y: f64,
    imageWidth: f64,
    imageHeight: f64,
}) CommandResult {
    if (builtin.target.os.tag != .macos) {
        return failCommand("drawMarkerOnPng", "UNSUPPORTED_PLATFORM", "debug-point image overlay is only supported on macOS");
    }

    // Load the existing PNG
    const path_as_u8: [*]const u8 = @ptrCast(input.path.ptr);
    const file_url = c.CFURLCreateFromFileSystemRepresentation(
        null,
        path_as_u8,
        @as(c_long, @intCast(input.path.len)),
        0,
    );
    if (file_url == null) return failCommand("drawMarkerOnPng", "LOAD_FAILED", "failed to create file URL");
    defer c.CFRelease(file_url);

    const source = c.CGImageSourceCreateWithURL(file_url, null);
    if (source == null) return failCommand("drawMarkerOnPng", "LOAD_FAILED", "failed to load PNG");
    defer c.CFRelease(source);

    const image = c.CGImageSourceCreateImageAtIndex(source, 0, null);
    if (image == null) return failCommand("drawMarkerOnPng", "LOAD_FAILED", "failed to decode PNG image");
    defer c.CFRelease(image);

    const w = c.CGImageGetWidth(image);
    const h = c.CGImageGetHeight(image);

    // Create bitmap context
    const color_space = c.CGColorSpaceCreateDeviceRGB();
    if (color_space == null) return failCommand("drawMarkerOnPng", "DRAW_FAILED", "failed to create color space");
    defer c.CFRelease(color_space);

    const ctx = c.CGBitmapContextCreate(
        null,
        w,
        h,
        8,
        0,
        color_space,
        c.kCGImageAlphaPremultipliedLast,
    );
    if (ctx == null) return failCommand("drawMarkerOnPng", "DRAW_FAILED", "failed to create bitmap context");
    defer c.CFRelease(ctx);

    // Draw original image
    const img_rect: c.CGRect = .{
        .origin = .{ .x = 0, .y = 0 },
        .size = .{ .width = @floatFromInt(w), .height = @floatFromInt(h) },
    };
    c.CGContextDrawImage(ctx, img_rect, image);

    // Flip Y: CGContext origin is bottom-left, marker coords are top-left
    const px = input.x;
    const py = @as(f64, @floatFromInt(h)) - input.y;

    const pi = std.math.pi;

    // White crosshair (background for contrast)
    c.CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 0.95);
    c.CGContextSetLineWidth(ctx, 5);
    c.CGContextSetLineCap(ctx, 1); // kCGLineCapRound
    c.CGContextMoveToPoint(ctx, px - 22, py);
    c.CGContextAddLineToPoint(ctx, px + 22, py);
    c.CGContextStrokePath(ctx);
    c.CGContextMoveToPoint(ctx, px, py - 22);
    c.CGContextAddLineToPoint(ctx, px, py + 22);
    c.CGContextStrokePath(ctx);

    // White ring
    c.CGContextSetLineWidth(ctx, 4);
    c.CGContextAddArc(ctx, px, py, 18, 0, 2 * pi, 0);
    c.CGContextStrokePath(ctx);

    // Red crosshair
    c.CGContextSetRGBStrokeColor(ctx, 1, 0.176, 0.176, 1); // #ff2d2d
    c.CGContextSetLineWidth(ctx, 3);
    c.CGContextSetLineCap(ctx, 1);
    c.CGContextMoveToPoint(ctx, px - 22, py);
    c.CGContextAddLineToPoint(ctx, px + 22, py);
    c.CGContextStrokePath(ctx);
    c.CGContextMoveToPoint(ctx, px, py - 22);
    c.CGContextAddLineToPoint(ctx, px, py + 22);
    c.CGContextStrokePath(ctx);

    // Red ring
    c.CGContextSetLineWidth(ctx, 2);
    c.CGContextAddArc(ctx, px, py, 18, 0, 2 * pi, 0);
    c.CGContextStrokePath(ctx);

    // Filled red center dot with white stroke
    c.CGContextSetRGBFillColor(ctx, 1, 0.176, 0.176, 1);
    c.CGContextAddArc(ctx, px, py, 10, 0, 2 * pi, 0);
    c.CGContextFillPath(ctx);
    c.CGContextSetRGBStrokeColor(ctx, 1, 1, 1, 1);
    c.CGContextSetLineWidth(ctx, 3);
    c.CGContextAddArc(ctx, px, py, 10, 0, 2 * pi, 0);
    c.CGContextStrokePath(ctx);

    // Get result image and write back
    const result_image = c.CGBitmapContextCreateImage(ctx);
    if (result_image == null) return failCommand("drawMarkerOnPng", "DRAW_FAILED", "failed to create result image");
    defer c.CFRelease(result_image);

    writeScreenshotPng(.{
        .image = result_image,
        .output_path = input.path,
    }) catch {
        return failCommand("drawMarkerOnPng", "WRITE_FAILED", "failed to write annotated PNG");
    };

    return okCommand();
}

fn resolveMouseButton(button: []const u8) !MouseButtonKind {
    if (std.ascii.eqlIgnoreCase(button, "left")) {
        return .left;
    }
    if (std.ascii.eqlIgnoreCase(button, "right")) {
        return .right;
    }
    if (std.ascii.eqlIgnoreCase(button, "middle")) {
        return .middle;
    }
    return error.InvalidMouseButton;
}

fn postClickPair(point: c.CGPoint, button: MouseButtonKind, click_state: i64, flags: c_macos.CGEventFlags) !void {
    try postMouseButtonEvent(point, button, true, click_state, flags);
    try postMouseButtonEvent(point, button, false, click_state, flags);
}

fn postMouseButtonEvent(point: c.CGPoint, button: MouseButtonKind, is_down: bool, click_state: i64, flags: c_macos.CGEventFlags) !void {
    const button_code: c.CGMouseButton = switch (button) {
        .left => c.kCGMouseButtonLeft,
        .right => c.kCGMouseButtonRight,
        .middle => c.kCGMouseButtonCenter,
    };

    const event_type: c.CGEventType = switch (button) {
        .left => if (is_down) c.kCGEventLeftMouseDown else c.kCGEventLeftMouseUp,
        .right => if (is_down) c.kCGEventRightMouseDown else c.kCGEventRightMouseUp,
        .middle => if (is_down) c.kCGEventOtherMouseDown else c.kCGEventOtherMouseUp,
    };

    const event = c.CGEventCreateMouseEvent(null, event_type, point, button_code);
    if (event == null) {
        return error.CGEventCreateFailed;
    }
    defer c.CFRelease(event);

    c.CGEventSetIntegerValueField(event, c.kCGMouseEventClickState, click_state);
    c.CGEventSetFlags(event, flags);
    c.CGEventPost(c.kCGHIDEventTap, event);
}

fn currentCursorPoint() !c.CGPoint {
    const event = c.CGEventCreate(null);
    if (event == null) {
        return error.CGEventCreateFailed;
    }
    defer c.CFRelease(event);
    return c.CGEventGetLocation(event);
}

fn moveCursorToPoint(point: c.CGPoint) !void {
    const warp_result = c.CGWarpMouseCursorPosition(point);
    if (warp_result != c.kCGErrorSuccess) {
        return error.CGWarpMouseFailed;
    }

    const move_event = c.CGEventCreateMouseEvent(null, c.kCGEventMouseMoved, point, c.kCGMouseButtonLeft);
    if (move_event == null) {
        return error.CGEventCreateFailed;
    }
    defer c.CFRelease(move_event);
    c.CGEventPost(c.kCGHIDEventTap, move_event);
}

fn mouseEventFlagsForButton(button: MouseButtonKind, is_down: bool) c_uint {
    return switch (button) {
        .left => if (is_down) c_windows.MOUSEEVENTF_LEFTDOWN else c_windows.MOUSEEVENTF_LEFTUP,
        .right => if (is_down) c_windows.MOUSEEVENTF_RIGHTDOWN else c_windows.MOUSEEVENTF_RIGHTUP,
        .middle => if (is_down) c_windows.MOUSEEVENTF_MIDDLEDOWN else c_windows.MOUSEEVENTF_MIDDLEUP,
    };
}

fn postMouseButtonEventWindows(button: MouseButtonKind, is_down: bool) !void {
    if (builtin.target.os.tag != .windows) {
        return error.UnsupportedPlatform;
    }

    var event = std.mem.zeroes(c_windows.INPUT);
    event.type = c_windows.INPUT_MOUSE;
    event.unnamed_0.mi.dwFlags = mouseEventFlagsForButton(button, is_down);
    const sent = c_windows.SendInput(1, &event, @sizeOf(c_windows.INPUT));
    if (sent == 0) {
        return error.EventPostFailed;
    }
}

fn moveCursorToPointWindows(point: Point) !void {
    if (builtin.target.os.tag != .windows) {
        return error.UnsupportedPlatform;
    }
    ensureWindowsDpiAware();

    const x = try normalizedCoordinate(point.x);
    const y = try normalizedCoordinate(point.y);
    if (c_windows.SetCursorPos(x, y) == 0) {
        return error.EventPostFailed;
    }
}

fn utf8ToUtf16AllocZ(input: []const u8) ![]u16 {
    const length = c_windows.MultiByteToWideChar(
        c_windows.CP_UTF8,
        0,
        input.ptr,
        @as(c_int, @intCast(input.len)),
        null,
        0,
    );
    if (length <= 0) {
        return error.EncodingFailed;
    }

    const out = try std.heap.c_allocator.alloc(u16, @as(usize, @intCast(length + 1)));
    errdefer std.heap.c_allocator.free(out);

    const written = c_windows.MultiByteToWideChar(
        c_windows.CP_UTF8,
        0,
        input.ptr,
        @as(c_int, @intCast(input.len)),
        @ptrCast(out.ptr),
        length,
    );
    if (written <= 0) {
        return error.EncodingFailed;
    }
    out[@as(usize, @intCast(written))] = 0;
    return out;
}

fn openX11Display() !*c_x11.Display {
    if (builtin.target.os.tag != .linux) {
        return error.UnsupportedPlatform;
    }
    return c_x11.XOpenDisplay(null) orelse error.XOpenDisplayFailed;
}

fn resolveX11ButtonCode(button: MouseButtonKind) c_uint {
    return switch (button) {
        .left => 1,
        .middle => 2,
        .right => 3,
    };
}

fn normalizedCoordinate(value: f64) !c_int {
    if (!std.math.isFinite(value)) {
        return error.InvalidPoint;
    }
    const rounded = @as(i64, @intFromFloat(std.math.round(value)));
    if (rounded < std.math.minInt(c_int) or rounded > std.math.maxInt(c_int)) {
        return error.InvalidPoint;
    }
    return @as(c_int, @intCast(rounded));
}

fn moveCursorToPointX11(point: Point, display: *c_x11.Display) !void {
    const x = try normalizedCoordinate(point.x);
    const y = try normalizedCoordinate(point.y);
    _ = c_x11.XWarpPointer(display, 0, c_x11.XDefaultRootWindow(display), 0, 0, 0, 0, x, y);
}

fn postMouseButtonEventX11(button: MouseButtonKind, is_down: bool, display: *c_x11.Display) !void {
    const button_code = resolveX11ButtonCode(button);
    const press_state: c_int = if (is_down) c_x11.True else c_x11.False;
    const posted = c_x11.XTestFakeButtonEvent(display, button_code, press_state, c_x11.CurrentTime);
    if (posted == 0) {
        return error.EventPostFailed;
    }
}

fn postClickPairX11(point: Point, button: MouseButtonKind, display: *c_x11.Display) !void {
    try moveCursorToPointX11(point, display);
    try postMouseButtonEventX11(button, true, display);
    try postMouseButtonEventX11(button, false, display);
}

fn currentCursorPointX11(display: *c_x11.Display) !struct { x: c_int, y: c_int } {
    const root_window = c_x11.XDefaultRootWindow(display);
    var root_return: c_x11.Window = 0;
    var child_return: c_x11.Window = 0;
    var root_x: c_int = 0;
    var root_y: c_int = 0;
    var win_x: c_int = 0;
    var win_y: c_int = 0;
    var mask_return: c_uint = 0;

    const ok = c_x11.XQueryPointer(
        display,
        root_window,
        &root_return,
        &child_return,
        &root_x,
        &root_y,
        &win_x,
        &win_y,
        &mask_return,
    );
    if (ok == 0) {
        return error.CursorReadFailed;
    }

    return .{ .x = root_x, .y = root_y };
}

fn initModule(js: *napigen.JsContext, exports: napigen.napi_value) !napigen.napi_value {
    try js.setNamedProperty(exports, "screenshot", try js.createFunction(screenshot));
    try js.setNamedProperty(exports, "click", try js.createFunction(click));
    try js.setNamedProperty(exports, "typeText", try js.createFunction(typeText));
    try js.setNamedProperty(exports, "press", try js.createFunction(press));
    try js.setNamedProperty(exports, "scroll", try js.createFunction(scroll));
    try js.setNamedProperty(exports, "drag", try js.createFunction(drag));
    try js.setNamedProperty(exports, "hover", try js.createFunction(hover));
    try js.setNamedProperty(exports, "mouseMove", try js.createFunction(mouseMove));
    try js.setNamedProperty(exports, "mouseDown", try js.createFunction(mouseDown));
    try js.setNamedProperty(exports, "mouseUp", try js.createFunction(mouseUp));
    try js.setNamedProperty(exports, "mousePosition", try js.createFunction(mousePosition));
    try js.setNamedProperty(exports, "displayList", try js.createFunction(displayList));
    try js.setNamedProperty(exports, "windowList", try js.createFunction(windowList));
    return exports;
}

comptime {
    if (build_options.enable_napigen) {
        napigen.defineModule(initModule);
    }
}
