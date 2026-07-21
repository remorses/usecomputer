// Global input event listener for macOS using CGEventTap.
// Outputs events as SSE (Server-Sent Events) to stdout.
// Each event includes a "type" field matching the SSE event name,
// usable as a discriminated union tag on the TypeScript side.
//
// Requires Input Monitoring / Accessibility permissions.
// Only macOS is supported; other platforms return an error.
//
// JSON is serialized using std.json.fmt to avoid hand-escaping bugs
// (e.g. backslash key names producing invalid JSON).

const std = @import("std");
const builtin = @import("builtin");

const c = if (builtin.target.os.tag == .macos) @cImport({
    @cInclude("CoreGraphics/CoreGraphics.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
}) else struct {};

// ─── Keycode-to-name reverse mapping (macOS virtual keycodes) ───

const KeycodeEntry = struct {
    code: u16,
    name: []const u8,
};

// Linear scan is fine for ~80 entries at human-input rates.
const keycode_table = [_]KeycodeEntry{
    .{ .code = 0x00, .name = "a" },
    .{ .code = 0x01, .name = "s" },
    .{ .code = 0x02, .name = "d" },
    .{ .code = 0x03, .name = "f" },
    .{ .code = 0x04, .name = "h" },
    .{ .code = 0x05, .name = "g" },
    .{ .code = 0x06, .name = "z" },
    .{ .code = 0x07, .name = "x" },
    .{ .code = 0x08, .name = "c" },
    .{ .code = 0x09, .name = "v" },
    .{ .code = 0x0B, .name = "b" },
    .{ .code = 0x0C, .name = "q" },
    .{ .code = 0x0D, .name = "w" },
    .{ .code = 0x0E, .name = "e" },
    .{ .code = 0x0F, .name = "r" },
    .{ .code = 0x10, .name = "y" },
    .{ .code = 0x11, .name = "t" },
    .{ .code = 0x12, .name = "1" },
    .{ .code = 0x13, .name = "2" },
    .{ .code = 0x14, .name = "3" },
    .{ .code = 0x15, .name = "4" },
    .{ .code = 0x16, .name = "6" },
    .{ .code = 0x17, .name = "5" },
    .{ .code = 0x18, .name = "=" },
    .{ .code = 0x19, .name = "9" },
    .{ .code = 0x1A, .name = "7" },
    .{ .code = 0x1B, .name = "-" },
    .{ .code = 0x1C, .name = "8" },
    .{ .code = 0x1D, .name = "0" },
    .{ .code = 0x1E, .name = "]" },
    .{ .code = 0x1F, .name = "o" },
    .{ .code = 0x20, .name = "u" },
    .{ .code = 0x21, .name = "[" },
    .{ .code = 0x22, .name = "i" },
    .{ .code = 0x23, .name = "p" },
    .{ .code = 0x24, .name = "enter" },
    .{ .code = 0x25, .name = "l" },
    .{ .code = 0x26, .name = "j" },
    .{ .code = 0x27, .name = "'" },
    .{ .code = 0x28, .name = "k" },
    .{ .code = 0x29, .name = ";" },
    .{ .code = 0x2A, .name = "\\" },
    .{ .code = 0x2B, .name = "," },
    .{ .code = 0x2C, .name = "/" },
    .{ .code = 0x2D, .name = "n" },
    .{ .code = 0x2E, .name = "m" },
    .{ .code = 0x2F, .name = "." },
    .{ .code = 0x30, .name = "tab" },
    .{ .code = 0x31, .name = "space" },
    .{ .code = 0x32, .name = "`" },
    .{ .code = 0x33, .name = "backspace" },
    .{ .code = 0x35, .name = "escape" },
    .{ .code = 0x37, .name = "command" },
    .{ .code = 0x38, .name = "shift" },
    .{ .code = 0x3A, .name = "option" },
    .{ .code = 0x3B, .name = "control" },
    .{ .code = 0x3C, .name = "rightShift" },
    .{ .code = 0x3D, .name = "rightOption" },
    .{ .code = 0x3E, .name = "rightControl" },
    .{ .code = 0x3F, .name = "fn" },
    .{ .code = 0x60, .name = "f5" },
    .{ .code = 0x61, .name = "f6" },
    .{ .code = 0x62, .name = "f7" },
    .{ .code = 0x63, .name = "f3" },
    .{ .code = 0x64, .name = "f8" },
    .{ .code = 0x65, .name = "f9" },
    .{ .code = 0x67, .name = "f11" },
    .{ .code = 0x6D, .name = "f10" },
    .{ .code = 0x6F, .name = "f12" },
    .{ .code = 0x73, .name = "home" },
    .{ .code = 0x74, .name = "pageUp" },
    .{ .code = 0x75, .name = "delete" },
    .{ .code = 0x76, .name = "f4" },
    .{ .code = 0x77, .name = "end" },
    .{ .code = 0x78, .name = "f2" },
    .{ .code = 0x79, .name = "pageDown" },
    .{ .code = 0x7A, .name = "f1" },
    .{ .code = 0x7B, .name = "left" },
    .{ .code = 0x7C, .name = "right" },
    .{ .code = 0x7D, .name = "down" },
    .{ .code = 0x7E, .name = "up" },
};

fn keycodeToName(code: u16) []const u8 {
    for (&keycode_table) |*entry| {
        if (entry.code == code) return entry.name;
    }
    return "unknown";
}

// ─── JSON event structs (serialized via std.json.fmt for safe escaping) ───

const MouseEventData = struct {
    type: []const u8,
    button: []const u8,
    x: f64,
    y: f64,
    timestamp: i64,
};

const MoveEventData = struct {
    type: []const u8,
    x: f64,
    y: f64,
    timestamp: i64,
};

const KeyEventData = struct {
    type: []const u8,
    key: []const u8,
    keyCode: u16,
    timestamp: i64,
};

const ScrollEventData = struct {
    type: []const u8,
    x: f64,
    y: f64,
    deltaX: i64,
    deltaY: i64,
    timestamp: i64,
};

// ─── SSE writer ───

const StdoutWriter = std.fs.File.DeprecatedWriter;

fn writeMouseEvent(writer: StdoutWriter, event_name: []const u8, button: []const u8, x: f64, y: f64, timestamp: i64) void {
    const data = MouseEventData{
        .type = event_name,
        .button = button,
        .x = std.math.round(x),
        .y = std.math.round(y),
        .timestamp = timestamp,
    };
    writer.print("event: {s}\ndata: {f}\n\n", .{ event_name, std.json.fmt(data, .{}) }) catch {};
}

fn writeMoveEvent(writer: StdoutWriter, x: f64, y: f64, timestamp: i64) void {
    const data = MoveEventData{
        .type = "mouseMove",
        .x = std.math.round(x),
        .y = std.math.round(y),
        .timestamp = timestamp,
    };
    writer.print("event: mouseMove\ndata: {f}\n\n", .{std.json.fmt(data, .{})}) catch {};
}

fn writeKeyEvent(writer: StdoutWriter, event_name: []const u8, key_name: []const u8, keycode: u16, timestamp: i64) void {
    const data = KeyEventData{
        .type = event_name,
        .key = key_name,
        .keyCode = keycode,
        .timestamp = timestamp,
    };
    writer.print("event: {s}\ndata: {f}\n\n", .{ event_name, std.json.fmt(data, .{}) }) catch {};
}

fn writeScrollEvent(writer: StdoutWriter, x: f64, y: f64, delta_x: i64, delta_y: i64, timestamp: i64) void {
    const data = ScrollEventData{
        .type = "scroll",
        .x = std.math.round(x),
        .y = std.math.round(y),
        .deltaX = delta_x,
        .deltaY = delta_y,
        .timestamp = timestamp,
    };
    writer.print("event: scroll\ndata: {f}\n\n", .{std.json.fmt(data, .{})}) catch {};
}

// ─── Button number to name ───

fn buttonNumberToName(button_number: i64) []const u8 {
    return switch (button_number) {
        0 => "left",
        1 => "right",
        2 => "middle",
        else => "other",
    };
}

// ─── CGEventTap callback ───

fn eventCallback(
    _: c.CGEventTapProxy,
    event_type: c.CGEventType,
    event: c.CGEventRef,
    user_info: ?*anyopaque,
) callconv(.c) c.CGEventRef {
    if (builtin.target.os.tag != .macos) return event;

    const stdout = std.fs.File.stdout().deprecatedWriter();
    const timestamp = std.time.milliTimestamp();
    const location = c.CGEventGetLocation(event);
    const x = location.x;
    const y = location.y;

    _ = user_info;

    // Handle event tap being disabled by the system (timeout or user input).
    // macOS disables the tap if the callback takes too long. Re-enable it.
    if (event_type == c.kCGEventTapDisabledByTimeout or event_type == c.kCGEventTapDisabledByUserInput) {
        if (global_event_tap) |tap| {
            c.CGEventTapEnable(tap, true);
        }
        return event;
    }

    switch (event_type) {
        c.kCGEventLeftMouseDown,
        c.kCGEventRightMouseDown,
        c.kCGEventOtherMouseDown,
        => {
            const btn = c.CGEventGetIntegerValueField(event, c.kCGMouseEventButtonNumber);
            writeMouseEvent(stdout, "mouseClick", buttonNumberToName(btn), x, y, timestamp);
        },
        c.kCGEventLeftMouseUp,
        c.kCGEventRightMouseUp,
        c.kCGEventOtherMouseUp,
        => {
            const btn = c.CGEventGetIntegerValueField(event, c.kCGMouseEventButtonNumber);
            writeMouseEvent(stdout, "mouseRelease", buttonNumberToName(btn), x, y, timestamp);
        },
        c.kCGEventMouseMoved,
        c.kCGEventLeftMouseDragged,
        c.kCGEventRightMouseDragged,
        c.kCGEventOtherMouseDragged,
        => {
            writeMoveEvent(stdout, x, y, timestamp);
        },
        c.kCGEventKeyDown => {
            const keycode_raw = c.CGEventGetIntegerValueField(event, c.kCGKeyboardEventKeycode);
            const keycode: u16 = @intCast(keycode_raw & 0xFFFF);
            const key_name = keycodeToName(keycode);
            writeKeyEvent(stdout, "keyDown", key_name, keycode, timestamp);
        },
        c.kCGEventKeyUp => {
            const keycode_raw = c.CGEventGetIntegerValueField(event, c.kCGKeyboardEventKeycode);
            const keycode: u16 = @intCast(keycode_raw & 0xFFFF);
            const key_name = keycodeToName(keycode);
            writeKeyEvent(stdout, "keyUp", key_name, keycode, timestamp);
        },
        c.kCGEventFlagsChanged => {
            // Modifier key press/release. macOS doesn't distinguish down/up for
            // flagsChanged; we report it as "flagsChanged" with the keycode so
            // consumers can track modifier state if needed.
            const keycode_raw = c.CGEventGetIntegerValueField(event, c.kCGKeyboardEventKeycode);
            const keycode: u16 = @intCast(keycode_raw & 0xFFFF);
            const key_name = keycodeToName(keycode);
            writeKeyEvent(stdout, "flagsChanged", key_name, keycode, timestamp);
        },
        c.kCGEventScrollWheel => {
            const delta_y = c.CGEventGetIntegerValueField(event, c.kCGScrollWheelEventDeltaAxis1);
            const delta_x = c.CGEventGetIntegerValueField(event, c.kCGScrollWheelEventDeltaAxis2);
            writeScrollEvent(stdout, x, y, delta_x, delta_y, timestamp);
        },
        else => {},
    }

    return event;
}

// ─── Public entry point ───

pub fn listen() !void {
    if (builtin.target.os.tag != .macos) {
        return error.UnsupportedPlatform;
    }

    // Build event mask for all event types we care about.
    const mask: c.CGEventMask = ((@as(c.CGEventMask, 1) << @intCast(c.kCGEventLeftMouseDown)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventLeftMouseUp)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventRightMouseDown)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventRightMouseUp)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventOtherMouseDown)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventOtherMouseUp)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventMouseMoved)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventLeftMouseDragged)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventRightMouseDragged)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventOtherMouseDragged)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventKeyDown)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventKeyUp)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventFlagsChanged)) |
        (@as(c.CGEventMask, 1) << @intCast(c.kCGEventScrollWheel)));

    // Pass the event tap as userInfo so the callback can re-enable it
    // if macOS disables it due to timeout.
    const event_tap = c.CGEventTapCreate(
        c.kCGHIDEventTap,
        c.kCGHeadInsertEventTap,
        c.kCGEventTapOptionListenOnly,
        mask,
        eventCallback,
        null, // userInfo set after creation via CFMachPortSetInfo
    );

    if (event_tap == null) {
        const stderr = std.fs.File.stderr().deprecatedWriter();
        stderr.print("error: failed to create event tap. Make sure Input Monitoring permissions are granted.\n", .{}) catch {};
        return error.EventTapCreateFailed;
    }

    // Store tap ref globally so the callback can re-enable it on timeout.
    global_event_tap = event_tap;

    const run_loop_source = c.CFMachPortCreateRunLoopSource(c.kCFAllocatorDefault, event_tap, 0);
    if (run_loop_source == null) {
        c.CFRelease(event_tap);
        return error.RunLoopSourceCreateFailed;
    }

    c.CFRunLoopAddSource(c.CFRunLoopGetCurrent(), run_loop_source, c.kCFRunLoopCommonModes);
    c.CGEventTapEnable(event_tap, true);

    // Print a ready marker so consumers know the tap is active.
    const stderr = std.fs.File.stderr().deprecatedWriter();
    stderr.print("listening for input events (press Ctrl+C to stop)\n", .{}) catch {};

    // Block on the run loop. CFRunLoopRun exits when the process receives
    // SIGINT (Ctrl+C) or when CFRunLoopStop is called.
    c.CFRunLoopRun();

    // Cleanup (reached after CFRunLoopStop or signal)
    c.CGEventTapEnable(event_tap, false);
    c.CFRunLoopRemoveSource(c.CFRunLoopGetCurrent(), run_loop_source, c.kCFRunLoopCommonModes);
    c.CFRelease(run_loop_source);
    c.CFRelease(event_tap);
    global_event_tap = null;
}

// Global tap reference for the callback to re-enable on timeout.
// Only one listen() call runs at a time (the CLI is single-threaded).
var global_event_tap: if (builtin.target.os.tag == .macos) ?c.CFMachPortRef else ?*anyopaque = null;
