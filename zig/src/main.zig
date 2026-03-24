/// Standalone CLI for usecomputer — no Node.js required.
/// Calls the same native functions as the N-API module via lib.zig.
const std = @import("std");
const zeke = @import("zeke");
const lib = @import("usecomputer_lib");
const table = @import("table.zig");
const kitty_graphics = @import("kitty-graphics.zig");

const File = std.fs.File;
const Writer = File.DeprecatedWriter;

fn getStdout() Writer {
    return File.stdout().deprecatedWriter();
}

fn getStderr() Writer {
    return File.stderr().deprecatedWriter();
}

// ─── Coord-map ───
// Port of src/coord-map.ts — maps screenshot-space pixels to desktop coordinates.

const CoordMap = struct {
    captureX: f64,
    captureY: f64,
    captureWidth: f64,
    captureHeight: f64,
    imageWidth: f64,
    imageHeight: f64,
};

fn parseCoordMap(s: []const u8) ?CoordMap {
    var iter = std.mem.splitScalar(u8, s, ',');
    const cx_str = iter.next() orelse return null;
    const cy_str = iter.next() orelse return null;
    const cw_str = iter.next() orelse return null;
    const ch_str = iter.next() orelse return null;
    const iw_str = iter.next() orelse return null;
    const ih_str = iter.next() orelse return null;
    const cx = std.fmt.parseFloat(f64, cx_str) catch return null;
    const cy = std.fmt.parseFloat(f64, cy_str) catch return null;
    const cw = std.fmt.parseFloat(f64, cw_str) catch return null;
    const ch = std.fmt.parseFloat(f64, ch_str) catch return null;
    const iw = std.fmt.parseFloat(f64, iw_str) catch return null;
    const ih = std.fmt.parseFloat(f64, ih_str) catch return null;
    if (cw <= 0 or ch <= 0 or iw <= 0 or ih <= 0) return null;
    return .{
        .captureX = cx,
        .captureY = cy,
        .captureWidth = cw,
        .captureHeight = ch,
        .imageWidth = iw,
        .imageHeight = ih,
    };
}

fn mapPointFromCoordMap(point: lib.Point, cm: ?CoordMap) lib.Point {
    const m = cm orelse return point;
    const iw_span = @max(m.imageWidth - 1, 1);
    const ih_span = @max(m.imageHeight - 1, 1);
    const cw_span = @max(m.captureWidth - 1, 0);
    const ch_span = @max(m.captureHeight - 1, 0);
    const max_cx = m.captureX + cw_span;
    const max_cy = m.captureY + ch_span;
    const mapped_x = m.captureX + (point.x / iw_span) * cw_span;
    const mapped_y = m.captureY + (point.y / ih_span) * ch_span;
    return .{
        .x = @round(std.math.clamp(mapped_x, m.captureX, max_cx)),
        .y = @round(std.math.clamp(mapped_y, m.captureY, max_cy)),
    };
}

fn mapPointToCoordMap(point: lib.Point, cm: ?CoordMap) lib.Point {
    const m = cm orelse return point;
    const cw_span = @max(m.captureWidth - 1, 1);
    const ch_span = @max(m.captureHeight - 1, 1);
    const iw_span = @max(m.imageWidth - 1, 0);
    const ih_span = @max(m.imageHeight - 1, 0);
    const rel_x = (point.x - m.captureX) / cw_span;
    const rel_y = (point.y - m.captureY) / ch_span;
    const mapped_x = rel_x * iw_span;
    const mapped_y = rel_y * ih_span;
    return .{
        .x = @round(std.math.clamp(mapped_x, 0, iw_span)),
        .y = @round(std.math.clamp(mapped_y, 0, ih_span)),
    };
}

fn getRegionFromCoordMap(cm: ?CoordMap) ?lib.ScreenshotRegion {
    const m = cm orelse return null;
    return .{
        .x = m.captureX,
        .y = m.captureY,
        .width = m.captureWidth,
        .height = m.captureHeight,
    };
}

// ─── Helpers ───

fn parseF64(s: []const u8) ?f64 {
    return std.fmt.parseFloat(f64, s) catch null;
}

fn parseRegion(s: []const u8) ?lib.ScreenshotRegion {
    // Parse "x,y,w,h" format
    var iter = std.mem.splitScalar(u8, s, ',');
    const x_str = iter.next() orelse return null;
    const y_str = iter.next() orelse return null;
    const w_str = iter.next() orelse return null;
    const h_str = iter.next() orelse return null;
    return .{
        .x = std.fmt.parseFloat(f64, x_str) catch return null,
        .y = std.fmt.parseFloat(f64, y_str) catch return null,
        .width = std.fmt.parseFloat(f64, w_str) catch return null,
        .height = std.fmt.parseFloat(f64, h_str) catch return null,
    };
}

fn printError(result: anytype) void {
    const stderr = getStderr();
    if (result.@"error") |err| {
        stderr.print("error: {s} ({s})\n", .{ err.message, err.code }) catch {};
    } else {
        stderr.print("error: command failed\n", .{}) catch {};
    }
}

fn printScreenshotJson(data: lib.ScreenshotOutput, agent_graphics: bool) void {
    const stdout = getStdout();
    stdout.print(
        "{{\"path\":\"{s}\",\"desktopIndex\":{d:.0},\"captureX\":{d:.0},\"captureY\":{d:.0},\"captureWidth\":{d:.0},\"captureHeight\":{d:.0},\"imageWidth\":{d:.0},\"imageHeight\":{d:.0},\"agentGraphics\":{s}}}\n",
        .{ data.path, data.desktopIndex, data.captureX, data.captureY, data.captureWidth, data.captureHeight, data.imageWidth, data.imageHeight, if (agent_graphics) "true" else "false" },
    ) catch {};
}

// ─── Command definitions ───

const Screenshot = zeke.cmd("screenshot [path]", "Take a screenshot")
    .option("--region [region]", "Capture specific region (x,y,w,h)")
    .option("--display [id]", "Target display")
    .option("--window [id]", "Target window")
    .option("--annotate", "Annotate with grid overlay")
    .option("--json", "Output as JSON");

const Click = zeke.cmd("click [target]", "Click at coordinates or target")
    .option("-x [x]", "X coordinate")
    .option("-y [y]", "Y coordinate")
    .option("--button [button]", "Mouse button: left, right, middle")
    .option("--count [count]", "Click count")
    .option("--modifiers [modifiers]", "Modifiers as ctrl,shift,alt,meta")
    .option("--coord-map [map]", "Map screenshot-space pixels to desktop coordinates");

const DebugPoint = zeke.cmd("debug-point [target]", "Validate click coordinates visually")
    .option("-x [x]", "X coordinate")
    .option("-y [y]", "Y coordinate")
    .option("--coord-map [map]", "Map input coordinates from screenshot space")
    .option("--output [path]", "Save annotated screenshot")
    .option("--json", "Output as JSON");

const TypeText = zeke.cmd("type [text]", "Type text using keyboard")
    .option("--stdin", "Read text from stdin instead of [text] argument")
    .option("--delay [ms]", "Delay between keystrokes in ms")
    .option("--chunk-size [n]", "Split text into fixed-size chunks before typing")
    .option("--chunk-delay [ms]", "Delay in milliseconds between chunks")
    .option("--max-length [n]", "Fail when input text exceeds this maximum length");

const Press = zeke.cmd("press <key>", "Press a key or key combination")
    .option("--count [n]", "Number of times to press")
    .option("--delay [ms]", "Delay between presses in ms");

const Scroll = zeke.cmd("scroll <direction> [amount]", "Scroll in a direction")
    .option("--at [coords]", "Scroll at specific coordinates (x,y)");

const Drag = zeke.cmd("drag <from> <to>", "Drag from one point to another")
    .option("--duration [ms]", "Drag duration in ms")
    .option("--button [button]", "Mouse button")
    .option("--coord-map [map]", "Map input coordinates from screenshot space");

const Hover = zeke.cmd("hover [target]", "Move mouse without clicking")
    .option("-x [x]", "X coordinate")
    .option("-y [y]", "Y coordinate")
    .option("--coord-map [map]", "Map input coordinates from screenshot space");

const MouseMove = zeke.cmd("mouse move", "Move to absolute coordinates")
    .option("-x [x]", "X coordinate")
    .option("-y [y]", "Y coordinate")
    .option("--coord-map [map]", "Map input coordinates from screenshot space");

const MouseDown = zeke.cmd("mouse down", "Press and hold mouse button")
    .option("--button [button]", "Mouse button");

const MouseUp = zeke.cmd("mouse up", "Release mouse button")
    .option("--button [button]", "Mouse button");

const MousePosition = zeke.cmd("mouse position", "Print current mouse position")
    .option("--json", "Output as JSON");

const DisplayList = zeke.cmd("display list", "List connected displays")
    .option("--json", "Output as JSON");

const WindowList = zeke.cmd("window list", "List open windows")
    .option("--json", "Output as JSON");

const DesktopList = zeke.cmd("desktop list", "List desktops as display indexes and sizes")
    .option("--windows", "Include available windows grouped by desktop index")
    .option("--json", "Output as JSON");

const ClipboardGet = zeke.cmd("clipboard get", "Print clipboard text");

const ClipboardSet = zeke.cmd("clipboard set <text>", "Set clipboard text");

// ─── Action functions ───

fn screenshotAction(args: Screenshot.Args, opts: Screenshot.Options) !void {
    const result = lib.screenshot(.{
        .path = args.path,
        .display = if (opts.display) |d| parseF64(d) else null,
        .window = if (opts.window) |w| parseF64(w) else null,
        .region = if (opts.region) |r| parseRegion(r) else null,
        .annotate = opts.annotate,
    });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }

    const agent_graphics = kitty_graphics.canEmitAgentGraphics();

    if (opts.json) {
        if (result.data) |data| {
            printScreenshotJson(data, agent_graphics);
        }
    } else {
        const stdout = getStdout();
        if (result.data) |data| {
            try stdout.print("Screenshot saved to {s} ({d:.0}x{d:.0})\n", .{
                data.path, data.imageWidth, data.imageHeight,
            });
        }
    }

    // Emit the screenshot as Kitty Graphics Protocol escape sequences when
    // AGENT_GRAPHICS=kitty is set. An agent plugin (kitty-graphics-agent)
    // intercepts these and injects the image into the LLM context.
    if (agent_graphics) {
        if (result.data) |data| {
            const stdout = getStdout();
            const png_data = std.fs.cwd().readFileAlloc(std.heap.page_allocator, data.path, 50 * 1024 * 1024) catch |err| {
                const stderr = getStderr();
                try stderr.print("warning: could not read screenshot for kitty graphics: {}\n", .{err});
                return;
            };
            defer std.heap.page_allocator.free(png_data);
            kitty_graphics.emitKittyGraphics(png_data, stdout) catch |err| {
                const stderr = getStderr();
                try stderr.print("warning: kitty graphics emission failed: {}\n", .{err});
                return;
            };
            // In JSON mode, the JSON object already has "agentGraphics":true —
            // don't print extra text to stdout (breaks single-JSON-object contract).
            if (!opts.json) {
                try stdout.print("The screenshot image is in your context. No need to read the file.\n", .{});
            }
        }
    }
}

fn clickAction(args: Click.Args, opts: Click.Options) !void {
    const raw_point = resolvePoint(args.target, opts.x, opts.y) orelse {
        const stderr = getStderr();
        try stderr.print("error: coordinates required (-x and -y, or positional x,y)\n", .{});
        return error.InvalidCoordinate;
    };
    const cm = if (opts.coord_map) |s| (parseCoordMap(s) orelse {
        const stderr = getStderr();
        try stderr.print("error: invalid --coord-map, expected x,y,width,height,imageWidth,imageHeight\n", .{});
        return error.CommandFailed;
    }) else null;
    const point = mapPointFromCoordMap(raw_point, cm);
    const result = lib.click(.{
        .point = point,
        .button = opts.button,
        .count = if (opts.count) |c| parseF64(c) else null,
    });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn debugPointAction(args: DebugPoint.Args, opts: DebugPoint.Options) !void {
    const stderr = getStderr();
    const stdout = getStdout();

    // Resolve input point
    const input_point = resolvePoint(args.target, opts.x, opts.y) orelse {
        try stderr.print("error: coordinates required (-x and -y, or positional x,y)\n", .{});
        return error.InvalidCoordinate;
    };

    // Parse coord-map and compute desktop point
    const cm = if (opts.coord_map) |s| parseCoordMap(s) else null;
    const desktop_point = mapPointFromCoordMap(input_point, cm);

    // Take screenshot (using coord-map region if provided)
    const output_path = opts.output orelse "./tmp/debug-point.png";
    const screenshot_result = lib.screenshot(.{
        .path = output_path,
        .region = getRegionFromCoordMap(cm),
    });
    if (!screenshot_result.ok) {
        printError(screenshot_result);
        return error.CommandFailed;
    }
    const data = screenshot_result.data orelse {
        try stderr.print("error: screenshot returned no data\n", .{});
        return error.CommandFailed;
    };

    // Compute screenshot-space point for the marker
    const screenshot_cm = CoordMap{
        .captureX = data.captureX,
        .captureY = data.captureY,
        .captureWidth = data.captureWidth,
        .captureHeight = data.captureHeight,
        .imageWidth = data.imageWidth,
        .imageHeight = data.imageHeight,
    };
    const screenshot_point = mapPointToCoordMap(desktop_point, screenshot_cm);

    // Draw marker on the screenshot
    const draw_result = lib.drawMarkerOnPng(.{
        .path = data.path,
        .x = screenshot_point.x,
        .y = screenshot_point.y,
        .imageWidth = data.imageWidth,
        .imageHeight = data.imageHeight,
    });
    if (!draw_result.ok) {
        // Non-fatal: print warning but still output coordinates
        try stderr.print("warning: could not draw marker on screenshot\n", .{});
    }

    if (opts.json) {
        stdout.print(
            "{{\"path\":\"{s}\",\"inputPoint\":{{\"x\":{d:.0},\"y\":{d:.0}}},\"desktopPoint\":{{\"x\":{d:.0},\"y\":{d:.0}}},\"screenshotPoint\":{{\"x\":{d:.0},\"y\":{d:.0}}}}}\n",
            .{
                data.path,
                input_point.x,
                input_point.y,
                desktop_point.x,
                desktop_point.y,
                screenshot_point.x,
                screenshot_point.y,
            },
        ) catch {};
    } else {
        try stdout.print("{s}\n", .{data.path});
        try stdout.print("input-point={d:.0},{d:.0}\n", .{ input_point.x, input_point.y });
        try stdout.print("desktop-point={d:.0},{d:.0}\n", .{ desktop_point.x, desktop_point.y });
        try stdout.print("screenshot-point={d:.0},{d:.0}\n", .{ screenshot_point.x, screenshot_point.y });
    }
}

fn readAllStdin(allocator: std.mem.Allocator) ![]const u8 {
    const stdin = std.fs.File.stdin();
    var buf: [8192]u8 = undefined;
    var list: std.ArrayListUnmanaged(u8) = .empty;
    errdefer list.deinit(allocator);
    while (true) {
        const n = stdin.read(&buf) catch return error.StdinReadFailed;
        if (n == 0) break;
        list.appendSlice(allocator, buf[0..n]) catch return error.StdinReadFailed;
        if (list.items.len > 10 * 1024 * 1024) return error.StdinReadFailed;
    }
    return list.toOwnedSlice(allocator) catch return error.StdinReadFailed;
}

fn typeTextAction(args: TypeText.Args, opts: TypeText.Options) !void {
    const stderr = getStderr();
    const from_stdin = opts.stdin;

    if (from_stdin and args.text != null) {
        try stderr.print("error: use either [text] or --stdin, not both\n", .{});
        return error.MissingArgument;
    }

    // Get the text to type
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const text: []const u8 = if (from_stdin)
        readAllStdin(allocator) catch {
            try stderr.print("error: failed to read from stdin\n", .{});
            return error.StdinReadFailed;
        }
    else
        args.text orelse {
            try stderr.print("error: text argument or --stdin required\n", .{});
            return error.MissingArgument;
        };
    defer if (from_stdin) allocator.free(text);

    // Check max-length
    if (opts.max_length) |ml_str| {
        const max_len = parseF64(ml_str) orelse {
            try stderr.print("error: --max-length must be a positive number\n", .{});
            return error.CommandFailed;
        };
        if (max_len <= 0) {
            try stderr.print("error: --max-length must be a positive number\n", .{});
            return error.CommandFailed;
        }
        if (@as(f64, @floatFromInt(text.len)) > max_len) {
            try stderr.print("error: input text length {d} exceeds --max-length {d:.0}\n", .{ text.len, max_len });
            return error.CommandFailed;
        }
    }

    // Determine chunk size
    const chunk_size: ?usize = if (opts.chunk_size) |cs_str| blk: {
        const cs = parseF64(cs_str) orelse {
            try stderr.print("error: --chunk-size must be a positive number\n", .{});
            return error.CommandFailed;
        };
        if (cs <= 0) {
            try stderr.print("error: --chunk-size must be a positive number\n", .{});
            return error.CommandFailed;
        }
        break :blk @as(usize, @intFromFloat(cs));
    } else null;

    const chunk_delay_ns: ?u64 = if (opts.chunk_delay) |cd_str| blk: {
        const cd = parseF64(cd_str) orelse {
            try stderr.print("error: --chunk-delay must be a positive number\n", .{});
            return error.CommandFailed;
        };
        if (cd < 0) {
            try stderr.print("error: --chunk-delay must be a non-negative number\n", .{});
            return error.CommandFailed;
        }
        break :blk @as(u64, @intFromFloat(cd * 1_000_000));
    } else null;

    if (chunk_size) |cs| {
        // Type in chunks (split on UTF-8 boundaries to avoid breaking codepoints)
        var offset: usize = 0;
        while (offset < text.len) {
            var end = @min(offset + cs, text.len);
            // Walk back to a UTF-8 character boundary if we split mid-codepoint
            while (end < text.len and end > offset and (text[end] & 0xC0) == 0x80) {
                end -= 1;
            }
            if (end == offset) end = @min(offset + cs, text.len); // fallback if all continuation bytes
            const chunk = text[offset..end];
            const result = lib.typeText(.{
                .text = chunk,
                .delayMs = if (opts.delay) |d| parseF64(d) else null,
            });
            if (!result.ok) {
                printError(result);
                return error.CommandFailed;
            }
            offset = end;
            if (offset < text.len) {
                if (chunk_delay_ns) |delay| {
                    std.Thread.sleep(delay);
                }
            }
        }
    } else {
        // Type all at once
        const result = lib.typeText(.{
            .text = text,
            .delayMs = if (opts.delay) |d| parseF64(d) else null,
        });
        if (!result.ok) {
            printError(result);
            return error.CommandFailed;
        }
    }
}

fn pressAction(args: Press.Args, opts: Press.Options) !void {
    const result = lib.press(.{
        .key = args.key,
        .count = if (opts.count) |c| parseF64(c) else null,
        .delayMs = if (opts.delay) |d| parseF64(d) else null,
    });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn scrollAction(args: Scroll.Args, opts: Scroll.Options) !void {
    const amount: f64 = if (args.amount) |a| (parseF64(a) orelse 3.0) else 3.0;
    var at: ?lib.Point = null;
    if (opts.at) |at_str| {
        var iter = std.mem.splitScalar(u8, at_str, ',');
        const x_str = iter.next() orelse return error.InvalidCoordinate;
        const y_str = iter.next() orelse return error.InvalidCoordinate;
        at = .{
            .x = std.fmt.parseFloat(f64, x_str) catch return error.InvalidCoordinate,
            .y = std.fmt.parseFloat(f64, y_str) catch return error.InvalidCoordinate,
        };
    }
    const result = lib.scroll(.{
        .direction = args.direction,
        .amount = amount,
        .at = at,
    });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn dragAction(args: Drag.Args, opts: Drag.Options) !void {
    // Parse "x,y" format for from and to
    const from_raw = parsePointArg(args.from) orelse return error.InvalidCoordinate;
    const to_raw = parsePointArg(args.to) orelse return error.InvalidCoordinate;
    const cm = if (opts.coord_map) |s| parseCoordMap(s) else null;
    const result = lib.drag(.{
        .from = mapPointFromCoordMap(from_raw, cm),
        .to = mapPointFromCoordMap(to_raw, cm),
        .durationMs = if (opts.duration) |d| parseF64(d) else null,
        .button = opts.button,
    });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn resolvePoint(target: ?[]const u8, opt_x: ?[]const u8, opt_y: ?[]const u8) ?lib.Point {
    if (opt_x) |x_str| {
        if (opt_y) |y_str| {
            const x = parseF64(x_str) orelse return null;
            const y = parseF64(y_str) orelse return null;
            return .{ .x = x, .y = y };
        }
    }
    if (target) |t| return parsePointArg(t);
    return null;
}

fn parsePointArg(s: []const u8) ?lib.Point {
    var iter = std.mem.splitScalar(u8, s, ',');
    const x_str = iter.next() orelse return null;
    const y_str = iter.next() orelse return null;
    return .{
        .x = std.fmt.parseFloat(f64, x_str) catch return null,
        .y = std.fmt.parseFloat(f64, y_str) catch return null,
    };
}

fn hoverAction(args: Hover.Args, opts: Hover.Options) !void {
    const point = resolvePoint(args.target, opts.x, opts.y) orelse return error.InvalidCoordinate;
    const cm = if (opts.coord_map) |s| parseCoordMap(s) else null;
    const result = lib.hover(mapPointFromCoordMap(point, cm));
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn mouseMoveAction(_: MouseMove.Args, opts: MouseMove.Options) !void {
    const x_str = opts.x orelse return error.InvalidCoordinate;
    const y_str = opts.y orelse return error.InvalidCoordinate;
    const x = parseF64(x_str) orelse return error.InvalidCoordinate;
    const y = parseF64(y_str) orelse return error.InvalidCoordinate;
    const cm = if (opts.coord_map) |s| parseCoordMap(s) else null;
    const point = mapPointFromCoordMap(.{ .x = x, .y = y }, cm);
    const result = lib.mouseMove(point);
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn mouseDownAction(_: MouseDown.Args, opts: MouseDown.Options) !void {
    const result = lib.mouseDown(.{ .button = opts.button });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn mouseUpAction(_: MouseUp.Args, opts: MouseUp.Options) !void {
    const result = lib.mouseUp(.{ .button = opts.button });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

fn mousePositionAction(_: MousePosition.Args, opts: MousePosition.Options) !void {
    const result = lib.mousePosition();
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
    if (result.data) |pos| {
        const stdout = getStdout();
        if (opts.json) {
            try stdout.print("{{\"x\":{d:.0},\"y\":{d:.0}}}\n", .{ pos.x, pos.y });
        } else {
            try stdout.print("{d:.0}, {d:.0}\n", .{ pos.x, pos.y });
        }
    }
}

// ─── Table rendering for list commands ───

fn jsonStr(value: std.json.Value) []const u8 {
    return switch (value) {
        .string => |s| s,
        else => "",
    };
}

fn jsonIntAlloc(allocator: std.mem.Allocator, value: std.json.Value) ![]u8 {
    return switch (value) {
        .integer => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
        .float => |f| try std.fmt.allocPrint(allocator, "{d:.0}", .{f}),
        else => try allocator.dupe(u8, "?"),
    };
}

fn jsonBool(value: std.json.Value) []const u8 {
    return switch (value) {
        .bool => |b| if (b) "yes" else "no",
        else => "no",
    };
}

fn printDisplayTable(allocator: std.mem.Allocator, json_data: []const u8) !void {
    const stdout = getStdout();
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_data, .{}) catch {
        try stdout.print("{s}\n", .{json_data});
        return;
    };
    defer parsed.deinit();

    const items = switch (parsed.value) {
        .array => |a| a.items,
        else => {
            try stdout.print("{s}\n", .{json_data});
            return;
        },
    };

    if (items.len == 0) {
        try stdout.print("no displays\n", .{});
        return;
    }

    const columns = &[_]table.Column{
        .{ .header = "desktop" },
        .{ .header = "primary" },
        .{ .header = "size", .alignment = .right },
        .{ .header = "position", .alignment = .right },
        .{ .header = "id", .alignment = .right },
        .{ .header = "scale", .alignment = .right },
        .{ .header = "name" },
    };

    // Build rows — each row is an array of cell strings
    var rows = std.ArrayListUnmanaged([]const []const u8).empty;
    defer {
        for (rows.items) |row| allocator.free(row);
        rows.deinit(allocator);
    }

    // Buffers for formatted strings that outlive the loop iteration
    var string_bufs = std.ArrayListUnmanaged([]u8).empty;
    defer {
        for (string_bufs.items) |buf| allocator.free(buf);
        string_bufs.deinit(allocator);
    }

    for (items) |item| {
        const obj = switch (item) {
            .object => |o| o,
            else => continue,
        };

        const index_str = try jsonIntAlloc(allocator, obj.get("index") orelse continue);
        try string_bufs.append(allocator, index_str);
        const desktop_str = try std.fmt.allocPrint(allocator, "#{s}", .{index_str});
        try string_bufs.append(allocator, desktop_str);

        const w_str = try jsonIntAlloc(allocator, obj.get("width") orelse continue);
        try string_bufs.append(allocator, w_str);
        const h_str = try jsonIntAlloc(allocator, obj.get("height") orelse continue);
        try string_bufs.append(allocator, h_str);
        const size_str = try std.fmt.allocPrint(allocator, "{s}x{s}", .{ w_str, h_str });
        try string_bufs.append(allocator, size_str);

        const x_str = try jsonIntAlloc(allocator, obj.get("x") orelse continue);
        try string_bufs.append(allocator, x_str);
        const y_str = try jsonIntAlloc(allocator, obj.get("y") orelse continue);
        try string_bufs.append(allocator, y_str);
        const pos_str = try std.fmt.allocPrint(allocator, "{s},{s}", .{ x_str, y_str });
        try string_bufs.append(allocator, pos_str);

        const id_str = try jsonIntAlloc(allocator, obj.get("id") orelse continue);
        try string_bufs.append(allocator, id_str);

        const scale_str = try jsonIntAlloc(allocator, obj.get("scale") orelse continue);
        try string_bufs.append(allocator, scale_str);

        const name_val = obj.get("name") orelse continue;

        const row = try allocator.alloc([]const u8, 7);
        row[0] = desktop_str;
        row[1] = jsonBool(obj.get("isPrimary") orelse .{ .bool = false });
        row[2] = size_str;
        row[3] = pos_str;
        row[4] = id_str;
        row[5] = scale_str;
        row[6] = jsonStr(name_val);
        try rows.append(allocator, row);
    }

    const lines = try table.render(allocator, columns, rows.items);
    defer {
        for (lines) |line| allocator.free(line);
        allocator.free(lines);
    }

    for (lines) |line| {
        try stdout.print("{s}\n", .{line});
    }
}

fn printWindowTable(allocator: std.mem.Allocator, json_data: []const u8) !void {
    const stdout = getStdout();
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_data, .{}) catch {
        try stdout.print("{s}\n", .{json_data});
        return;
    };
    defer parsed.deinit();

    const items = switch (parsed.value) {
        .array => |a| a.items,
        else => {
            try stdout.print("{s}\n", .{json_data});
            return;
        },
    };

    if (items.len == 0) {
        try stdout.print("no windows\n", .{});
        return;
    }

    const columns = &[_]table.Column{
        .{ .header = "id", .alignment = .right },
        .{ .header = "desktop", .alignment = .right },
        .{ .header = "app" },
        .{ .header = "pid", .alignment = .right },
        .{ .header = "size", .alignment = .right },
        .{ .header = "position", .alignment = .right },
        .{ .header = "title" },
    };

    var rows = std.ArrayListUnmanaged([]const []const u8).empty;
    defer {
        for (rows.items) |row| allocator.free(row);
        rows.deinit(allocator);
    }

    var string_bufs = std.ArrayListUnmanaged([]u8).empty;
    defer {
        for (string_bufs.items) |buf| allocator.free(buf);
        string_bufs.deinit(allocator);
    }

    for (items) |item| {
        const obj = switch (item) {
            .object => |o| o,
            else => continue,
        };

        const id_str = try jsonIntAlloc(allocator, obj.get("id") orelse continue);
        try string_bufs.append(allocator, id_str);

        const di_str = try jsonIntAlloc(allocator, obj.get("desktopIndex") orelse continue);
        try string_bufs.append(allocator, di_str);
        const desktop_str = try std.fmt.allocPrint(allocator, "#{s}", .{di_str});
        try string_bufs.append(allocator, desktop_str);

        const pid_str = try jsonIntAlloc(allocator, obj.get("ownerPid") orelse continue);
        try string_bufs.append(allocator, pid_str);

        const w_str = try jsonIntAlloc(allocator, obj.get("width") orelse continue);
        try string_bufs.append(allocator, w_str);
        const h_str = try jsonIntAlloc(allocator, obj.get("height") orelse continue);
        try string_bufs.append(allocator, h_str);
        const size_str = try std.fmt.allocPrint(allocator, "{s}x{s}", .{ w_str, h_str });
        try string_bufs.append(allocator, size_str);

        const x_str = try jsonIntAlloc(allocator, obj.get("x") orelse continue);
        try string_bufs.append(allocator, x_str);
        const y_str = try jsonIntAlloc(allocator, obj.get("y") orelse continue);
        try string_bufs.append(allocator, y_str);
        const pos_str = try std.fmt.allocPrint(allocator, "{s},{s}", .{ x_str, y_str });
        try string_bufs.append(allocator, pos_str);

        const row = try allocator.alloc([]const u8, 7);
        row[0] = id_str;
        row[1] = desktop_str;
        row[2] = jsonStr(obj.get("ownerName") orelse .{ .string = "" });
        row[3] = pid_str;
        row[4] = size_str;
        row[5] = pos_str;
        row[6] = jsonStr(obj.get("title") orelse .{ .string = "" });
        try rows.append(allocator, row);
    }

    const lines = try table.render(allocator, columns, rows.items);
    defer {
        for (lines) |line| allocator.free(line);
        allocator.free(lines);
    }

    for (lines) |line| {
        try stdout.print("{s}\n", .{line});
    }
}

// ─── List command actions ───

fn displayListAction(_: DisplayList.Args, opts: DisplayList.Options) !void {
    const result = lib.displayList();
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
    if (result.data) |data| {
        if (opts.json) {
            const stdout = getStdout();
            try stdout.print("{s}\n", .{data});
        } else {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            printDisplayTable(gpa.allocator(), data) catch {
                const stdout = getStdout();
                try stdout.print("{s}\n", .{data});
            };
        }
    }
}

fn windowListAction(_: WindowList.Args, opts: WindowList.Options) !void {
    const result = lib.windowList();
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
    if (result.data) |data| {
        if (opts.json) {
            const stdout = getStdout();
            try stdout.print("{s}\n", .{data});
        } else {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            printWindowTable(gpa.allocator(), data) catch {
                const stdout = getStdout();
                try stdout.print("{s}\n", .{data});
            };
        }
    }
}

fn desktopListAction(_: DesktopList.Args, opts: DesktopList.Options) !void {
    const display_result = lib.displayList();
    if (!display_result.ok) {
        printError(display_result);
        return error.CommandFailed;
    }
    const stdout = getStdout();

    if (opts.windows) {
        const window_result = lib.windowList();
        if (!window_result.ok) {
            printError(window_result);
            return error.CommandFailed;
        }
        if (opts.json) {
            try stdout.print("{{\"displays\":{s},\"windows\":{s}}}\n", .{
                if (display_result.data) |d| d else "[]",
                if (window_result.data) |w| w else "[]",
            });
        } else {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            const allocator = gpa.allocator();
            if (display_result.data) |d| {
                printDisplayTable(allocator, d) catch try stdout.print("{s}\n", .{d});
            }
            try stdout.print("\n", .{});
            if (window_result.data) |w| {
                printWindowTable(allocator, w) catch try stdout.print("{s}\n", .{w});
            }
        }
    } else {
        if (opts.json) {
            if (display_result.data) |d| try stdout.print("{s}\n", .{d});
        } else {
            var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            defer _ = gpa.deinit();
            if (display_result.data) |d| {
                printDisplayTable(gpa.allocator(), d) catch try stdout.print("{s}\n", .{d});
            }
        }
    }
}

fn clipboardGetAction(_: ClipboardGet.Args, _: ClipboardGet.Options) !void {
    const result = lib.clipboardGet();
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
    if (result.data) |data| {
        const stdout = getStdout();
        try stdout.print("{s}\n", .{data});
    }
}

fn clipboardSetAction(args: ClipboardSet.Args, _: ClipboardSet.Options) !void {
    const result = lib.clipboardSet(.{ .text = args.text });
    if (!result.ok) {
        printError(result);
        return error.CommandFailed;
    }
}

// ─── Main ───

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = zeke.App(.{
        Screenshot.bind(screenshotAction),
        Click.bind(clickAction),
        DebugPoint.bind(debugPointAction),
        TypeText.bind(typeTextAction),
        Press.bind(pressAction),
        Scroll.bind(scrollAction),
        Drag.bind(dragAction),
        Hover.bind(hoverAction),
        MouseMove.bind(mouseMoveAction),
        MouseDown.bind(mouseDownAction),
        MouseUp.bind(mouseUpAction),
        MousePosition.bind(mousePositionAction),
        DisplayList.bind(displayListAction),
        DesktopList.bind(desktopListAction),
        WindowList.bind(windowListAction),
        ClipboardGet.bind(clipboardGetAction),
        ClipboardSet.bind(clipboardSetAction),
    }).init(gpa.allocator(), "usecomputer");

    app.setVersion("0.1.2");
    app.run() catch |err| {
        switch (err) {
            error.CommandFailed, error.InvalidCoordinate, error.MissingArgument => {},
            else => {
                const stderr = getStderr();
                stderr.print("error: {s}\n", .{@errorName(err)}) catch {};
            },
        }
        std.process.exit(1);
    };
}
