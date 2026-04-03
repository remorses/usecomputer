<!-- Purpose: track notable user-facing changes for npm releases. -->

# Changelog

All notable changes to `usecomputer` will be documented in this file.

## 0.1.10

1. **Added repeatable `--modifier <key>` support to `click`** — hold one or more keyboard modifiers while clicking, using the same modifier names and aliases accepted by `press` (`cmd`, `command`, `meta`, `option`, `alt`, `ctrl`, `control`, `shift`, `fn`):

   ```bash
   # option-click on macOS
   usecomputer click -x 600 -y 400 --modifier option

   # hold multiple modifiers for one click
   usecomputer click -x 600 -y 400 --modifier cmd --modifier shift
   ```

   `usecomputer click --help` now shows command-specific help with examples for this flow instead of only the global command list.

2. **Fixed negative `-x` and `-y` values in CLI commands** — commands that accept optional coordinate flags now correctly parse negative screen positions, which matters for multi-display layouts where a monitor sits to the left or above the primary display:

   ```bash
   usecomputer hover -x -1200 -y 300
   usecomputer debug-point -x -800 -y 240
   ```

3. **Fixed GitHub release archives for standalone and C API downloads** — CI now always uploads release assets when a matching GitHub release exists, and Windows builds include `usecomputer_c.dll` from the correct output path. Downloaded release archives are now consistent across macOS, Linux, and Windows.

## 0.1.9

1. **C API shared library** — `libusecomputer_c` is now built for all
   platforms and included in GitHub releases. Use it from any language
   with FFI (Julia, Python ctypes, Ruby FFI, etc.):

   ```c
   #include "usecomputer.h"

   double x, y;
   uc_mouse_position(&x, &y);

   char* displays = uc_display_list(); // caller uc_free()s
   char* result = uc_screenshot(NULL, -1, -1);
   if (!result) fprintf(stderr, "%s\n", uc_last_error());
   else { puts(result); uc_free(result); }
   ```

   Download from the GitHub release:
   - `usecomputer-v0.1.9-darwin-arm64.tar.gz`
   - `usecomputer-v0.1.9-darwin-x64.tar.gz`
   - `usecomputer-v0.1.9-linux-arm64.tar.gz`
   - `usecomputer-v0.1.9-linux-x64.tar.gz`
   - `usecomputer-v0.1.9-win32-x64.zip`
   - `usecomputer.h` (platform-independent header)

   Each archive contains the standalone CLI, N-API `.node`, C shared
   library, and header.

2. **All releases now include the standalone executable** — each platform
   archive in GitHub releases contains `usecomputer` (or `usecomputer.exe`
   on Windows), a self-contained binary with no Node.js dependency.

## 0.1.8

1. **AArch64 Linux support** — prebuilt binaries for `linux-arm64` are now
   included in the npm package. Install and run on ARM64 Linux machines
   (Raspberry Pi 5, AWS Graviton, Ampere, Apple Silicon VMs) the same way
   as x64:

   ```bash
   npm install -g usecomputer
   usecomputer screenshot ./shot.png --json
   usecomputer click -x 600 -y 400
   ```

   The Zig source already supported aarch64-linux — this release adds the
   CI cross-compile step so the binary actually ships.

## 0.1.7

1. **Fixed `usecomputer` command on Windows** — the npm `bin` entry now works from
   CMD and PowerShell without needing Git Bash or MSYS2 in PATH. The launcher is
   now a compiled TypeScript file (`dist/bin.js`) instead of a shell script:

   ```bash
   npm install -g usecomputer

   # works in CMD, PowerShell, and all Unix shells
   usecomputer screenshot ./shot.png --json
   ```

2. **Removed `clipboard get` and `clipboard set` commands** — these were only
   implemented on Windows and returned `NOT_SUPPORTED` on macOS and Linux.
   Use keyboard shortcuts instead:

   ```bash
   usecomputer press "cmd+c"   # copy (macOS)
   usecomputer press "ctrl+c"  # copy (Windows/Linux)
   usecomputer press "cmd+v"   # paste (macOS)
   usecomputer press "ctrl+v"  # paste (Windows/Linux)
   ```

## 0.1.6

1. **Windows support** — all automation commands now work on Windows. The native
   module ships as `win32-x64` and is built from the same Zig source as macOS
   and Linux:

   ```bash
   npm install -g usecomputer

   # screenshot the primary display
   usecomputer screenshot ./shot.png --json

   # click, type, press, scroll, drag — all work
   usecomputer click -x 600 -y 400
   usecomputer type "hello from windows"
   usecomputer press "ctrl+c"
   usecomputer scroll down 3
   usecomputer drag 100,200 500,600

   # list displays and windows
   usecomputer display list --json
   usecomputer window list --json

   # clipboard
   usecomputer clipboard set "hello"
   usecomputer clipboard get
   ```

   Implemented via native Win32 APIs: `SendInput` for mouse/keyboard, GDI
   `BitBlt`+`GetDIBits` for screenshots (same approach as Pillow/ImageGrab),
   `EnumDisplayMonitors` for display enumeration, `EnumWindows` for window
   listing, and the standard clipboard API. DPI awareness is initialized
   automatically so coordinates match what you see on screen.

   **Requirements:** run in an interactive desktop session (input injection
   is blocked on the Windows lock screen, same as macOS/Linux).

2. **Curved drag with bezier control point** — `drag` now accepts an optional
   third `[cp]` argument to curve the path. Useful for drawing circles, arcs,
   or any gesture that isn't a straight line:

   ```bash
   # Straight drag (unchanged)
   usecomputer drag 100,200 500,600

   # Curved drag — cp pulls the path toward it without passing through it
   usecomputer drag 100,200 500,600 300,50

   # Draw a circle at center (400,300) radius 50 using 4 bezier arcs
   usecomputer drag 400,250 450,300 450,250
   usecomputer drag 450,300 400,350 450,350
   usecomputer drag 400,350 350,300 350,350
   usecomputer drag 350,300 400,250 350,250
   ```

   Duration is now auto-computed from arc length at ~500 px/s so short and
   long drags feel natural without needing `--duration`.

3. **Version string from package.json** — the CLI binary now reports the correct
   version instead of a stale hardcoded string.

## 0.1.5

- **Fix `bunx` compatibility** — the shell launcher now ensures the native binary
  is executable before running it. npm tarballs can strip the `+x` bit on
  non-bin files, which caused `bunx usecomputer` to fail with
  "native binary not found" even though the binary was present.

## 0.1.4

Same as 0.1.3 but published via CI with correct Linux binaries included.

## 0.1.3

1. **Kitty Graphics Protocol support** — `screenshot` can now emit the PNG image
   inline to stdout using the [Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/).
   Set `AGENT_GRAPHICS=kitty` and the image lands directly in the AI model's context
   window — no separate file-read tool call needed:

   ```bash
   AGENT_GRAPHICS=kitty usecomputer screenshot ./shot.png --json
   # JSON output: { ..., "agentGraphics": true }
   ```

   Works out of the box with [kitty-graphics-agent](https://github.com/remorses/kitty-graphics-agent),
   an OpenCode plugin that intercepts the escape sequences and injects them as
   LLM-visible image attachments. Add it to `opencode.json` to enable:

   ```json
   { "plugin": ["kitty-graphics-agent"] }
   ```

   The plugin sets `AGENT_GRAPHICS=kitty` automatically. `agentGraphics` in the
   JSON output is `true` only when emission actually succeeded.

2. **Aligned table output for list commands** — `display list`, `window list`, and
   `desktop list` now render as aligned, human-readable tables (matching the format
   the old TypeScript CLI produced). JSON mode (`--json`) is unchanged:

   ```
   desktop  primary  size        position  id  scale  name
   0        yes      3440x1440   0,0       5   1      Display 5
   1        no       1512x982    3440,458  1   1      Display 1
   ```

3. **Fixed `agentGraphics` JSON field** — the field now reflects actual Kitty
   emission success rather than just whether `AGENT_GRAPHICS=kitty` was set.
   Empty PNG files and I/O errors report `false` instead of `true`.

## 0.1.2

1. **Removed all unimplemented command stubs** — 18 placeholder commands (`snapshot`, `get text/title/value/bounds/focused`, `window focus/resize/move/minimize/maximize/close`, `app list/launch/quit`, `wait`, `find`, `diff snapshot/screenshot`) that only threw "TODO not implemented" have been removed. The CLI now only exposes commands that actually work.
2. **Clipboard errors clarified** — clipboard commands now return "not supported on this platform" instead of "TODO not implemented".

## 0.1.1

1. **Fixed Linux native builds** — standalone executable now links libc correctly on Linux, fixing "C allocator is only available when linking against libc" errors.
2. **Fixed native host builds** — build script now omits `-Dtarget` when building for the host platform so Zig finds system libraries (X11, libpng, etc).

## 0.1.0

1. **Standalone executable** — `usecomputer` now ships as a self-contained binary.
   Install once and run anywhere without needing Node.js at runtime:

   ```bash
   npm install -g usecomputer
   usecomputer screenshot ./shot.png --json
   ```

2. **Linux X11 screenshot support** — capture screens on Linux desktops via XShm
   (with automatic fallback to XGetImage on XWayland). Returns the same JSON
   output shape as macOS:

   ```bash
   usecomputer screenshot ./shot.png --json
   ```

3. **Screenshot coord-map and scaling** — screenshots are scaled so the longest edge
   is at most 1568 px (model-friendly size). Output includes a `coordMap` field
   for accurate pointer remapping:

   ```bash
   usecomputer screenshot ./shot.png --json
   # use the emitted coord-map for all subsequent pointer commands
   usecomputer click -x 400 -y 220 --coord-map "0,0,1600,900,1568,882"
   ```

4. **New `debug-point` command** — validate a click target before clicking. Captures
   a screenshot and draws a red marker at the mapped coordinate:

   ```bash
   usecomputer debug-point -x 400 -y 220 --coord-map "0,0,1600,900,1568,882"
   ```

5. **Keyboard synthesis** — new `type` and `press` commands for text input and key
   chords:

   ```bash
   usecomputer type "hello from usecomputer"
   usecomputer press "cmd+s"
   usecomputer press "down" --count 10 --delay 30
   cat ./notes.txt | usecomputer type --stdin --chunk-size 4000
   ```

6. **Native scroll support** — scroll in any direction at any position:

   ```bash
   usecomputer scroll --direction down --amount 5
   usecomputer scroll --direction up --amount 3 -x 800 -y 400
   ```

7. **Library exports** — import `usecomputer` as a Node.js library to reuse all
   commands in your own agent harness:

   ```ts
   import * as usecomputer from 'usecomputer'

   const shot = await usecomputer.screenshot({ path: './shot.png', display: null, window: null, region: null, annotate: null })
   const coordMap = usecomputer.parseCoordMapOrThrow(shot.coordMap)
   await usecomputer.click({ point: usecomputer.mapPointFromCoordMap({ point: { x: 400, y: 220 }, coordMap }), button: 'left', count: 1 })
   ```

8. **OpenAI and Anthropic computer-use examples** — README now includes full
   agentic loop examples for both providers showing screenshot → action → result
   cycles.

## 0.0.3

- Implement real screenshot capture + PNG file writing on macOS.
- Screenshot path handling now uses the requested output path reliably.
- Unimplemented commands now return explicit `TODO not implemented: ...` errors.
- Clarify `--display` index behavior as 0-based in help/docs.

## 0.0.2

- Publish macOS native binaries for both `darwin-arm64` and `darwin-x64`.
- Add package metadata/docs for npm distribution.
- Improve CLI coordinate input with `-x` / `-y` flags.

## 0.0.1

- Initial npm package release for macOS.
- Native Zig + Quartz mouse actions:
  - `click`
  - `mouse move`
  - `mouse down`
  - `mouse up`
  - `mouse position`
  - `hover`
  - `drag`
- CLI coordinates improved with `-x` and `-y` flags.
