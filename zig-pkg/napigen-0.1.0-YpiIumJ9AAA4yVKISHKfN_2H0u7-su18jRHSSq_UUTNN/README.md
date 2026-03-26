# zig-napigen

Comptime N-API bindings for Zig.

> Requires Zig 0.15.2 or later.
>
> See [ggml-js](https://github.com/cztomsik/ggml-js) for a complete, real-world
> example.

## Features

- Primitives, tuples, structs (value types), optionals
- Strings (valid for the function scope)
- Struct pointers (see below)
- Functions (no classes, see below)
- Common napi types like `napi_value` are re-exported for convenience
- All napi functions and types are accessible via `napigen.napi.xxx` for lower-level control

## Limited scope

The library provides a simple and thin API, supporting only basic types. This
design choice is intentional, as it is often difficult to determine the ideal
mapping for more complex types. The library allows users to hook into the
mapping process or use the N-API directly for finer control.

Specifically, there is no support for classes.

## Structs/tuples (value types)

When returning a struct/tuple by value, it is mapped to an anonymous JavaScript
object/array with all properties/elements mapped recursively. Similarly, when
accepting a struct/tuple by value, it is mapped back from JavaScript to the
respective native type.

In both cases, a copy is created, so changes to the JS object are not reflected
in the native part and vice versa.

## Struct pointers (\*T)

When returning a pointer to a struct, an empty JavaScript object will be created
with the pointer wrapped inside. If this JavaScript object is passed to a
function that accepts a pointer, the pointer is unwrapped back.

The same JavaScript object is obtained for the same pointer, unless it has
already been collected. This is useful for attaching state to the JavaScript
counterpart and accessing that data later.

Changes to JavaScript objects are not reflected in the native part, but
getters/setters can be provided in JavaScript and native functions can be called
as necessary.

## Functions

JavaScript functions can be created with ctx.createFunction(zig_fn) and then
exported like any other value. Only comptime-known functions are supported. If
an error is returned from a function call, an exception is thrown in JavaScript.

```zig
fn add(a: i32, b: i32) i32 {
    return a + b;
}

// Somewhere where the JsContext is available
const js_fun: napigen.napi_value = try js.createFunction(add);

// Make the function accessible to JavaScript
try js.setNamedProperty(exports, "add", js_fun);
```

Note that **the number of arguments must match exactly**. So if you need to
support optional arguments, you will have to provide a wrapper function in JS,
which calls the native function with the correct arguments.

## Callbacks, \*JsContext, napi_value

Functions can also accept the current `*JsContext`, which is useful for calling
the N-API directly or performing callbacks. To get a raw JavaScript value,
simply use `napi_value` as an argument type.

```zig
fn callMeBack(js: *napigen.JsContext, recv: napigen.napi_value, fun: napigen.napi_value) !void {
    try js.callFunction(recv, fun, .{ "Hello from Zig" });
}
```

And then

```javascript
native.callMeBack(console, console.log)
```

If you need to store the callback for a longer period of time, you should create
a ref. For now, you have to do that directly, using `napi_create_reference()`.

## defineModule(init_fn), exports

N-API modules need to export a function which will also init & return the
`exports` object. You could export `napi_register_module_v1` and call
`JsContext.init()` yourself but there's also a shorthand using `comptime` block
which will allow you to use `try` anywhere inside:

```zig
comptime { napigen.defineModule(initModule) }

fn initModule(js: *napigen.JsContext, exports: napigen.napi_value) anyerror!napigen.napi_value {
    try js.setNamedProperty(exports, ...);
    ...

    return exports;
}
```

## Hooks

Whenever a value is passed from Zig to JS or vice versa, the library will call a
hook function, if one is defined. This allows you to customize the mapping
process.

Hooks have to be defined in the root module, and they need to be named
`napigenRead` and `napigenWrite` respectively. They must have the following
signature:

```zig
fn napigenRead(js: *napigen.JsContext, comptime T: type, value: napigen.napi_value) !T {
    return switch (T) {
        // we can easily customize the mapping for specific types
        // for example, we can allow passing regular JS strings anywhere where we expect an InternedString
        InternedString => InternedString.from(try js.read([]const u8)),

        // otherwise, just use the default mapping, note that this time
        // we call js.defaultRead() explicitly, to avoid infinite recursion
        else => js.defaultRead(T, value),
    }
}

pub fn napigenWrite(js: *napigen.JsContext, value: anytype) !napigen.napi_value {
    return switch (@TypeOf(value) {
        // convert InternedString to back to a JS string (hypothetically)
        InternedString => try js.write(value.ptr),

        // same thing here
        else => js.defaultWrite(value),
    }
}
```

---

## Complete example

The repository includes a complete example in the `example` directory. Here's a quick walkthrough:

**1. Create a new library**

```bash
mkdir example
cd example
zig init-lib
```

**2. Add napigen as zig module.**

```
zig fetch --save git+https://github.com/cztomsik/napigen#main
```

**3. Update build.zig**

Then, change your `build.zig` to something like this:

```zig
const std = @import("std");
const napigen = @import("napigen");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "example",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add napigen
    napigen.setup(lib);

    // Build the lib
    b.installArtifact(lib);

    // Copy the result to a *.node file so we can require() it
    const copy_node_step = b.addInstallLibFile(lib.getEmittedBin(), "example.node");
    b.getInstallStep().dependOn(&copy_node_step.step);
}
```

**4. Define & export something useful**

Next, define some functions and the N-API module itself in `src/main.zig`

```zig
const std = @import("std");
const napigen = @import("napigen");

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

comptime {
    napigen.defineModule(initModule);
}

fn initModule(js: *napigen.JsContext, exports: napigen.napi_value) anyerror!napigen.napi_value {
    try js.setNamedProperty(exports, "add", try js.createFunction(add));

    return exports;
}
```

**5. Use it from JS side**

Finally, use it from JavaScript as expected:

```javascript
import { createRequire } from 'node:module'
const require = createRequire(import.meta.url)
const native = require('./zig-out/lib/example.node')

console.log('1 + 2 =', native.add(1, 2))
```

To build the library and run the script:

```
> zig build && node example.js
1 + 2 = 3
```

## License

MIT
