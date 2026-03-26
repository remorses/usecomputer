const root = @import("root");
const std = @import("std");

pub const napi = @cImport({
    @cInclude("node_api.h");
});

// Re-export commonly used napi types for convenience
// Users can access all napi types/functions via napigen.napi.xxx
pub const napi_value = napi.napi_value;
pub const napi_env = napi.napi_env;
pub const napi_status = napi.napi_status;
pub const napi_ref = napi.napi_ref;
pub const napi_callback_info = napi.napi_callback_info;
pub const napi_valuetype = napi.napi_valuetype;

// define error types
pub const NapiError = error{ napi_invalid_arg, napi_object_expected, napi_string_expected, napi_name_expected, napi_function_expected, napi_number_expected, napi_boolean_expected, napi_array_expected, napi_generic_failure, napi_pending_exception, napi_cancelled, napi_escape_called_twice, napi_handle_scope_mismatch, napi_callback_scope_mismatch, napi_queue_full, napi_closing, napi_bigint_expected, napi_date_expected, napi_arraybuffer_expected, napi_detachable_arraybuffer_expected, napi_would_deadlock };
pub const Error = std.mem.Allocator.Error || error{InvalidArgumentCount} || NapiError;

/// translate napi_status > 0 to NapiError with the same name
pub fn check(status: napi.napi_status) Error!void {
    if (status != napi.napi_ok) {
        inline for (comptime std.meta.fieldNames(NapiError)) |f| {
            if (status == @field(napi, f)) return @field(NapiError, f);
        } else @panic("unknown napi err");
    }
}

pub const allocator = std.heap.c_allocator;

/// Convenience helper to define N-API module with a single function
pub fn defineModule(comptime init_fn: fn (*JsContext, napi.napi_value) anyerror!napi.napi_value) void {
    const NapigenNapiModule = struct {
        fn register(env: napi.napi_env, exports: napi.napi_value) callconv(.c) napi.napi_value {
            var cx = JsContext.init(env) catch @panic("could not init JS context");
            return init_fn(cx, exports) catch |e| cx.throw(e);
        }
    };

    @export(&NapigenNapiModule.register, .{ .name = "napi_register_module_v1", .linkage = .strong });
}

pub const JsContext = struct {
    env: napi.napi_env,
    arena: GenerationalArena,
    refs: std.AutoHashMapUnmanaged(usize, napi.napi_ref) = .{},

    /// Init the JS context.
    pub fn init(env: napi.napi_env) Error!*JsContext {
        const self = try allocator.create(JsContext);
        try check(napi.napi_set_instance_data(env, self, finalize, null));
        self.* = .{
            .env = env,
            .arena = GenerationalArena.init(allocator),
        };
        return self;
    }

    /// Deinit the JS context.
    pub fn deinit(self: *JsContext) void {
        self.arena.deinit();
        allocator.destroy(self);
    }

    /// Retreive the JS context from the N-API environment.
    fn getInstance(env: napi.napi_env) *JsContext {
        var res: *JsContext = undefined;
        check(napi.napi_get_instance_data(env, @ptrCast(&res))) catch @panic("could not get JS context");
        return res;
    }

    fn finalize(_: napi.napi_env, data: ?*anyopaque, _: ?*anyopaque) callconv(.c) void {
        // instance data might be already destroyed
        const self: *JsContext = @ptrCast(@alignCast(data));
        self.deinit();
    }

    /// Get the type of a JS value.
    pub fn typeOf(self: *JsContext, val: napi.napi_value) Error!napi.napi_valuetype {
        var res: napi.napi_valuetype = undefined;
        try check(napi.napi_typeof(self.env, val, &res));
        return res;
    }

    /// Throw an error.
    pub fn throw(self: *JsContext, err: anyerror) napi.napi_value {
        const msg = @as([*c]const u8, @ptrCast(@errorName(err)));
        check(napi.napi_throw_error(self.env, null, msg)) catch |e| {
            if (e != error.napi_pending_exception) std.debug.panic("throw failed {s} {any}", .{ msg, e });
        };
        return self.undefined() catch @panic("throw return undefined");
    }

    /// Get the JS `undefined` value.
    pub fn @"undefined"(self: *JsContext) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_get_undefined(self.env, &res));
        return res;
    }

    /// Get the JS `null` value.
    pub fn @"null"(self: *JsContext) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_get_null(self.env, &res));
        return res;
    }

    /// Create a JS boolean value.
    pub fn createBoolean(self: *JsContext, val: bool) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_get_boolean(self.env, val, &res));
        return res;
    }

    /// Read a native boolean from a JS value.
    pub fn readBoolean(self: *JsContext, val: napi.napi_value) Error!bool {
        var res: bool = undefined;
        try check(napi.napi_get_value_bool(self.env, val, &res));
        return res;
    }

    /// Create a JS number value.
    pub fn createNumber(self: *JsContext, val: anytype) Error!napi.napi_value {
        var res: napi.napi_value = undefined;

        switch (@TypeOf(val)) {
            u8, u16, u32, c_uint => try check(napi.napi_create_uint32(self.env, val, &res)),
            u64, usize => try check(napi.napi_create_bigint_uint64(self.env, val, &res)),
            i8, i16, i32, c_int => try check(napi.napi_create_int32(self.env, val, &res)),
            i64, isize, @TypeOf(0) => try check(napi.napi_create_bigint_int64(self.env, val, &res)),
            f16, f32, f64, @TypeOf(0.0) => try check(napi.napi_create_double(self.env, val, &res)),
            else => |T| @compileError(@typeName(T) ++ " is not supported number"),
        }

        return res;
    }

    /// Read a native number from a JS value.
    pub fn readNumber(self: *JsContext, comptime T: type, val: napi.napi_value) Error!T {
        var res: T = undefined;
        var lossless: bool = undefined; // TODO: check overflow?

        switch (T) {
            u8, u16 => res = @as(T, @truncate(try self.read(u32, val))),
            u32, c_uint => try check(napi.napi_get_value_uint32(self.env, val, &res)),
            u64, usize => try check(napi.napi_get_value_bigint_uint64(self.env, val, &res, &lossless)),
            i8, i16 => res = @as(T, @truncate(self.read(i32, val))),
            i32, c_int => try check(napi.napi_get_value_int32(self.env, val, &res)),
            i64, isize => try check(napi.napi_get_value_bigint_int64(self.env, val, &res, &lossless)),
            f16, f32 => res = @as(T, @floatCast(try self.readNumber(f64, val))),
            f64 => try check(napi.napi_get_value_double(self.env, val, &res)),
            else => @compileError(@typeName(T) ++ " is not supported number"),
        }

        return res;
    }

    /// Create a JS string value.
    pub fn createString(self: *JsContext, val: []const u8) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_create_string_utf8(self.env, @as([*c]const u8, @ptrCast(val)), val.len, &res));
        return res;
    }

    /// Get the length of a JS string value.
    pub fn getStringLength(self: *JsContext, val: napi.napi_value) Error!usize {
        var res: usize = undefined;
        try check(napi.napi_get_value_string_utf8(self.env, val, null, 0, &res));
        return res;
    }

    /// Read JS string into a temporary, arena-allocated buffer.
    pub fn readString(self: *JsContext, val: napi.napi_value) Error![]const u8 {
        var len: usize = try self.getStringLength(val);
        var buf = try self.arena.allocator().alloc(u8, len + 1);
        try check(napi.napi_get_value_string_utf8(self.env, val, @as([*c]u8, @ptrCast(buf)), buf.len, &len));
        return buf[0..len];
    }

    /// Create an empty JS array.
    pub fn createArray(self: *JsContext) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_create_array(self.env, &res));
        return res;
    }

    /// Create a JS array with a given length.
    pub fn createArrayWithLength(self: *JsContext, length: u32) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_create_array_with_length(self.env, length, &res));
        return res;
    }

    /// Create a JS array from a native array/slice.
    pub fn createArrayFrom(self: *JsContext, val: anytype) Error!napi.napi_value {
        const res = try self.createArrayWithLength(@as(u32, @truncate(val.len)));
        for (val, 0..) |v, i| {
            try self.setElement(res, @as(u32, @truncate(i)), try self.write(v));
        }
        return res;
    }

    /// Get the length of a JS array.
    pub fn getArrayLength(self: *JsContext, array: napi.napi_value) Error!u32 {
        var res: u32 = undefined;
        try check(napi.napi_get_array_length(self.env, array, &res));
        return res;
    }

    /// Read a native slice from a JS array.
    pub fn readArray(self: *JsContext, comptime T: type, array: napi.napi_value) Error![]T {
        const len: u32 = try self.getArrayLength(array);
        const res = try self.arena.allocator().alloc(T, len);
        for (res, 0..) |*v, i| {
            v.* = try self.read(T, try self.getElement(array, @as(u32, @intCast(i))));
        }
        return res;
    }

    /// Read a native fixed-size array from a JS array.
    pub fn readArrayFixed(self: *JsContext, comptime T: type, comptime len: usize, array: napi.napi_value) Error![len]T {
        var res: [len]T = undefined;
        for (0..len) |i| {
            res[i] = try self.read(T, try self.getElement(array, @as(u32, @intCast(i))));
        }
        return res;
    }

    /// Get a JS value from a JS array by index.
    pub fn getElement(self: *JsContext, array: napi.napi_value, index: u32) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_get_element(self.env, array, index, &res));
        return res;
    }

    /// Set a JS value to a JS array by index.
    pub fn setElement(self: *JsContext, array: napi.napi_value, index: u32, value: napi.napi_value) Error!void {
        try check(napi.napi_set_element(self.env, array, index, value));
    }

    /// Create a JS array from a tuple.
    pub fn createTuple(self: *JsContext, val: anytype) Error!napi.napi_value {
        const fields = std.meta.fields(@TypeOf(val));
        const res = try self.createArrayWithLength(fields.len);
        inline for (fields, 0..) |f, i| {
            const v = try self.write(@field(val, f.name));
            try self.setElement(res, @as(u32, @truncate(i)), v);
        }
        return res;
    }

    /// Read a JS array into a tuple.
    pub fn readTuple(self: *JsContext, comptime T: type, val: napi.napi_value) Error!T {
        const fields = std.meta.fields(T);
        var res: T = undefined;
        inline for (fields, 0..) |f, i| {
            const v = try self.getElement(val, @as(u32, @truncate(i)));
            @field(res, f.name) = try self.read(f.type, v);
        }
        return res;
    }

    /// Create an empty JS object.
    pub fn createObject(self: *JsContext) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_create_object(self.env, &res));
        return res;
    }

    /// Create a JS object from a native value.
    pub fn createObjectFrom(self: *JsContext, val: anytype) Error!napi.napi_value {
        const res: napi.napi_value = try self.createObject();
        inline for (std.meta.fields(@TypeOf(val))) |f| {
            const v = try self.write(@field(val, f.name));
            try self.setNamedProperty(res, f.name ++ "", v);
        }
        return res;
    }

    /// Read a struct/tuple from a JS object.
    pub fn readObject(self: *JsContext, comptime T: type, val: napi.napi_value) Error!T {
        var res: T = undefined;
        inline for (std.meta.fields(T)) |f| {
            const v = try self.getNamedProperty(val, f.name ++ "");
            @field(res, f.name) = try self.read(f.type, v);
        }
        return res;
    }

    /// Get the JS value of an object property by name.
    pub fn getNamedProperty(self: *JsContext, object: napi.napi_value, prop_name: [*:0]const u8) Error!napi.napi_value {
        var res: napi.napi_value = undefined;
        try check(napi.napi_get_named_property(self.env, object, prop_name, &res));
        return res;
    }

    /// Set the JS value of an object property by name.
    pub fn setNamedProperty(self: *JsContext, object: napi.napi_value, prop_name: [*:0]const u8, value: napi.napi_value) Error!void {
        try check(napi.napi_set_named_property(self.env, object, prop_name, value));
    }

    pub fn wrapPtr(self: *JsContext, val: anytype) Error!napi.napi_value {
        const info = @typeInfo(@TypeOf(val));
        if (comptime info == .pointer and @typeInfo(info.pointer.child) == .@"fn") @compileError("use createFunction() to export functions");

        var res: napi.napi_value = undefined;

        if (self.refs.get(@intFromPtr(val))) |ref| {
            if (napi.napi_get_reference_value(self.env, ref, &res) == napi.napi_ok and res != null) {
                return res;
            } else {
                _ = napi.napi_delete_reference(self.env, ref);
            }
        }

        var ref: napi.napi_ref = undefined;
        res = try self.createObject();
        try check(napi.napi_wrap(self.env, res, @constCast(val), &deleteRef, @as(*anyopaque, @ptrCast(@constCast(val))), &ref));
        try self.refs.put(allocator, @intFromPtr(val), ref);

        return res;
    }

    fn deleteRef(env: napi.napi_env, _: ?*anyopaque, ptr: ?*anyopaque) callconv(.c) void {
        var js = JsContext.getInstance(env);

        if (js.refs.get(@intFromPtr(ptr.?))) |ref| {
            // not sure if this is really needed but if we have a new ref and it's valid, we want to skip this
            var val: napi.napi_value = undefined;
            if (napi.napi_get_reference_value(env, ref, &val) == napi.napi_ok) return;

            _ = napi.napi_delete_reference(env, ref);
            _ = js.refs.remove(@intFromPtr(ptr.?));
        }
    }

    /// Unwrap a pointer from a JS object.
    pub fn unwrap(self: *JsContext, comptime T: type, val: napi.napi_value) Error!*T {
        var res: *T = undefined;
        try check(napi.napi_unwrap(self.env, val, @as([*c]?*anyopaque, @ptrCast(&res))));
        return res;
    }

    pub const read = if (@hasDecl(root, "napigenRead")) root.napigenRead else defaultRead;

    pub fn defaultRead(self: *JsContext, comptime T: type, val: napi.napi_value) Error!T {
        if (T == napi.napi_value) return val;
        if (comptime isString(T)) return self.readString(val);

        return switch (@typeInfo(T)) {
            .void => void{},
            .null => null,
            .bool => self.readBoolean(val),
            .int, .comptime_int, .float, .comptime_float => self.readNumber(T, val),
            .@"enum" => std.meta.intToEnum(T, self.read(u32, val)),
            .@"struct" => if (isTuple(T)) self.readTuple(T, val) else self.readObject(T, val),
            .optional => |info| if (try self.typeOf(val) == napi.napi_null) null else try self.read(info.child, val),
            .pointer => |info| switch (info.size) {
                .one, .c => self.unwrap(info.child, val),
                .slice => self.readArray(info.child, val),
                else => @compileError("reading " ++ @tagName(@typeInfo(T)) ++ " " ++ @typeName(T) ++ " is not supported"),
            },
            .array => |info| try self.readArrayFixed(info.child, info.len, val),
            else => @compileError("reading " ++ @tagName(@typeInfo(T)) ++ " " ++ @typeName(T) ++ " is not supported"),
        };
    }

    pub const write = if (@hasDecl(root, "napigenWrite")) root.napigenWrite else defaultWrite;

    pub fn defaultWrite(self: *JsContext, val: anytype) Error!napi.napi_value {
        const T = @TypeOf(val);

        if (T == napi.napi_value) return val;
        if (comptime isString(T)) return self.createString(val);

        return switch (@typeInfo(T)) {
            .void => self.undefined(),
            .null => self.null(),
            .bool => self.createBoolean(val),
            .int, .comptime_int, .float, .comptime_float => self.createNumber(val),
            .@"enum" => self.createNumber(@as(u32, @intFromEnum(val))),
            .@"struct" => if (isTuple(T)) self.createTuple(val) else self.createObjectFrom(val),
            .optional => if (val) |v| self.write(v) else self.null(),
            .pointer => |info| switch (info.size) {
                .one, .c => self.wrapPtr(val),
                .slice => self.createArrayFrom(val),
                else => @compileError("writing " ++ @tagName(@typeInfo(T)) ++ " " ++ @typeName(T) ++ " is not supported"),
            },
            .array => self.createArrayFrom(val),
            else => @compileError("writing " ++ @tagName(@typeInfo(T)) ++ " " ++ @typeName(T) ++ " is not supported"),
        };
    }

    /// Create a JS function.
    pub fn createFunction(self: *JsContext, comptime fun: anytype) Error!napi.napi_value {
        return self.createNamedFunction("anonymous", fun);
    }

    /// Create a named JS function.
    pub fn createNamedFunction(self: *JsContext, comptime name: [*:0]const u8, comptime fun: anytype) Error!napi.napi_value {
        const F = @TypeOf(fun);
        const Args = std.meta.ArgsTuple(F);
        const Res = @typeInfo(F).@"fn".return_type.?;

        const Helper = struct {
            fn call(env: napi.napi_env, cb_info: napi.napi_callback_info) callconv(.c) napi.napi_value {
                var js = JsContext.getInstance(env);
                js.arena.inc();
                defer js.arena.dec();

                const args = readArgs(js, cb_info) catch |e| return js.throw(e);
                const res = @call(.auto, fun, args);

                if (comptime @typeInfo(Res) == .error_union) {
                    return if (res) |r| js.write(r) catch |e| js.throw(e) else |e| js.throw(e);
                } else {
                    return js.write(res) catch |e| js.throw(e);
                }
            }

            fn readArgs(js: *JsContext, cb_info: napi.napi_callback_info) Error!Args {
                var args: Args = undefined;
                var argc: usize = args.len;
                var argv: [args.len]napi.napi_value = undefined;
                try check(napi.napi_get_cb_info(js.env, cb_info, &argc, &argv, null, null));

                var i: usize = 0;
                inline for (std.meta.fields(Args)) |f| {
                    if (comptime f.type == *JsContext) {
                        @field(args, f.name) = js;
                        continue;
                    }

                    @field(args, f.name) = try js.read(f.type, argv[i]);
                    i += 1;
                }

                if (i != argc) {
                    std.debug.print("Expected {d} args\n", .{i});
                    return error.InvalidArgumentCount;
                }

                return args;
            }
        };

        var res: napi.napi_value = undefined;
        try check(napi.napi_create_function(self.env, name, napi.NAPI_AUTO_LENGTH, &Helper.call, null, &res));
        return res;
    }

    /// Call a JS function.
    pub fn callFunction(self: *JsContext, recv: napi.napi_value, fun: napi.napi_value, args: anytype) Error!napi.napi_value {
        const Args = @TypeOf(args);
        var argv: [std.meta.fields(Args).len]napi.napi_value = undefined;
        inline for (std.meta.fields(Args), 0..) |f, i| {
            argv[i] = try self.write(@field(args, f.name));
        }

        var res: napi.napi_value = undefined;
        try check(napi.napi_call_function(self.env, recv, fun, argv.len, &argv, &res));
        return res;
    }

    /// Export a single declaration.
    pub fn exportOne(self: *JsContext, exports: napi.napi_value, comptime name: []const u8, val: anytype) Error!void {
        const c_name = name ++ "";

        if (comptime @typeInfo(@TypeOf(val)) == .@"fn") {
            try self.setNamedProperty(exports, c_name, try self.createNamedFunction(c_name, val));
        } else {
            try self.setNamedProperty(exports, c_name, try self.write(val));
        }
    }

    /// Export all public declarations from a module.
    pub fn exportAll(self: *JsContext, exports: napi.napi_value, comptime mod: anytype) Error!void {
        inline for (comptime std.meta.declarations(mod)) |d| {
            if (@TypeOf(@field(mod, d.name)) == type) continue;

            try self.exportOne(exports, d.name, @field(mod, d.name));
        }
    }
};

// To allow reading strings and other slices, we need to allocate memory
// somewhere. Such data is only needed for a short time, so we can use a
// generational arena to free the memory when it is no longer needed
// - count is increased when a function is called and decreased when it returns
// - when count reaches 0, the arena is reset (but not freed)
const GenerationalArena = struct {
    count: u32 = 0,
    arena: std.heap.ArenaAllocator,

    pub fn init(child_allocator: std.mem.Allocator) GenerationalArena {
        return .{
            .arena = std.heap.ArenaAllocator.init(child_allocator),
        };
    }

    pub fn deinit(self: *GenerationalArena) void {
        self.arena.deinit();
    }

    pub fn allocator(self: *GenerationalArena) std.mem.Allocator {
        return self.arena.allocator();
    }

    pub fn inc(self: *GenerationalArena) void {
        self.count += 1;
    }

    pub fn dec(self: *GenerationalArena) void {
        self.count -= 1;
        if (self.count == 0) {
            _ = self.arena.reset(.retain_capacity);
        }
    }
};

fn isString(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .slice and ptr.child == u8,
        else => return false,
    };
}

fn isTuple(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => |s| s.is_tuple,
        else => return false,
    };
}
