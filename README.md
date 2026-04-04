<!-- Purpose: npm package usage and install guide for usecomputer CLI. -->

# usecomputer

`usecomputer` is a desktop automation CLI for AI agents. It works on macOS,
Linux (X11), and Windows.

Screenshot, mouse control (move, click, drag, scroll), and keyboard synthesis
(`type` and `press`) are all available as CLI commands backed by a native Zig
binary — no Node.js runtime required.

## Install

```bash
npm install -g usecomputer
```

## Agent skill

If you use an AI coding agent (OpenCode, Claude Code, etc.), install the
usecomputer skill so the agent knows how to use the CLI correctly:

```bash
npx skills add remorses/usecomputer
```

The skill teaches the agent the screenshot → act → screenshot feedback loop,
coord-map usage, and window-scoped screenshot workflow.

## Requirements

- **macOS** — Accessibility permission enabled for your terminal app
- **Linux** — X11 session with `DISPLAY` set (Wayland via XWayland works too)
- **Windows** — run in an interactive desktop session (automation input is blocked on locked desktop)

## Quick start

```bash
usecomputer mouse position --json
usecomputer mouse move -x 500 -y 500
usecomputer click -x 500 -y 500 --button left --count 1
usecomputer type "hello"
usecomputer press "cmd+s"
```

## Library usage

```ts
import * as usecomputer from 'usecomputer'

const screenshot = await usecomputer.screenshot({
  path: './tmp/shot.png',
  display: null,
  window: null,
  region: null,
  annotate: null,
})

const coordMap = usecomputer.parseCoordMapOrThrow(screenshot.coordMap)
const point = usecomputer.mapPointFromCoordMap({
  point: { x: 400, y: 220 },
  coordMap,
})

await usecomputer.click({
  point,
  button: 'left',
  count: 1,
})
```

These exported functions intentionally mirror the native command shapes used by
the Zig N-API module. Optional native fields are passed as `null` when absent.

## OpenAI computer tool example

```ts
import fs from 'node:fs'
import * as usecomputer from 'usecomputer'

async function sendComputerScreenshot() {
  const screenshot = await usecomputer.screenshot({
    path: './tmp/computer-tool.png',
    display: null,
    window: null,
    region: null,
    annotate: null,
  })

  return {
    screenshot,
    imageBase64: await fs.promises.readFile(screenshot.path, 'base64'),
  }
}

async function runComputerAction(action, coordMap) {
  if (action.type === 'click') {
    await usecomputer.click({
      point: usecomputer.mapPointFromCoordMap({
        point: { x: action.x, y: action.y },
        coordMap: usecomputer.parseCoordMapOrThrow(coordMap),
      }),
      button: action.button ?? 'left',
      count: 1,
    })
    return
  }

  if (action.type === 'double_click') {
    await usecomputer.click({
      point: usecomputer.mapPointFromCoordMap({
        point: { x: action.x, y: action.y },
        coordMap: usecomputer.parseCoordMapOrThrow(coordMap),
      }),
      button: action.button ?? 'left',
      count: 2,
    })
    return
  }

  if (action.type === 'scroll') {
    await usecomputer.scroll({
      direction: action.scrollY && action.scrollY < 0 ? 'up' : 'down',
      amount: Math.abs(action.scrollY ?? 0),
      at: typeof action.x === 'number' && typeof action.y === 'number'
        ? usecomputer.mapPointFromCoordMap({
            point: { x: action.x, y: action.y },
            coordMap: usecomputer.parseCoordMapOrThrow(coordMap),
          })
        : null,
    })
    return
  }

  if (action.type === 'keypress') {
    await usecomputer.press({
      key: action.keys.join('+'),
      count: 1,
      delayMs: null,
    })
    return
  }

  if (action.type === 'type') {
    await usecomputer.typeText({
      text: action.text,
      delayMs: null,
    })
}
}
```

## Anthropic computer use example

Anthropic's computer tool uses action names like `left_click`, `double_click`,
`mouse_move`, `key`, `type`, `scroll`, and `screenshot`. `usecomputer`
provides the execution layer for those actions.

```ts
import fs from 'node:fs'
import Anthropic from '@anthropic-ai/sdk'
import type {
  BetaToolResultBlockParam,
  BetaToolUseBlock,
} from '@anthropic-ai/sdk/resources/beta/messages/messages'
import * as usecomputer from 'usecomputer'

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY })

const message = await anthropic.beta.messages.create({
  model: 'claude-opus-4-6',
  max_tokens: 1024,
  tools: [
    {
      type: 'computer_20251124',
      name: 'computer',
      display_width_px: 1024,
      display_height_px: 768,
      display_number: 1,
    },
  ],
  messages: [{ role: 'user', content: 'Open Safari and search for usecomputer.' }],
  betas: ['computer-use-2025-11-24'],
})

for (const block of message.content) {
  if (block.type !== 'tool_use' || block.name !== 'computer') {
    continue
  }

  const toolUse = block as BetaToolUseBlock
  await usecomputer.screenshot({
    path: './tmp/claude-current-screen.png',
    display: null,
    window: null,
    region: null,
    annotate: null,
  })
  const coordinate = Array.isArray(toolUse.input.coordinate)
    ? toolUse.input.coordinate
    : null
  const point = coordinate
    ? { x: coordinate[0] ?? 0, y: coordinate[1] ?? 0 }
    : null

  switch (toolUse.input.action) {
    case 'screenshot': {
      break
    }
    case 'left_click': {
      if (point) {
        await usecomputer.click({ point, button: 'left', count: 1 })
      }
      break
    }
    case 'double_click': {
      if (point) {
        await usecomputer.click({ point, button: 'left', count: 2 })
      }
      break
    }
    case 'mouse_move': {
      if (point) {
        await usecomputer.mouseMove(point)
      }
      break
    }
    case 'type': {
      if (typeof toolUse.input.text === 'string') {
        await usecomputer.typeText({ text: toolUse.input.text, delayMs: null })
      }
      break
    }
    case 'key': {
      if (typeof toolUse.input.text === 'string') {
        await usecomputer.press({ key: toolUse.input.text, count: 1, delayMs: null })
      }
      break
    }
    case 'scroll': {
      await usecomputer.scroll({
        direction: toolUse.input.scroll_direction === 'up' || toolUse.input.scroll_direction === 'down' || toolUse.input.scroll_direction === 'left' || toolUse.input.scroll_direction === 'right'
          ? toolUse.input.scroll_direction
          : 'down',
        amount: typeof toolUse.input.scroll_amount === 'number' ? toolUse.input.scroll_amount : 3,
        at: point,
      })
      break
    }
    default: {
      throw new Error(`Unsupported Claude computer action: ${String(toolUse.input.action)}`)
    }
  }

  const afterActionScreenshot = await usecomputer.screenshot({
    path: './tmp/claude-computer-tool.png',
    display: null,
    window: null,
    region: null,
    annotate: null,
  })
  const imageBase64 = await fs.promises.readFile(afterActionScreenshot.path, 'base64')
  const toolResult: BetaToolResultBlockParam = {
    type: 'tool_result',
    tool_use_id: toolUse.id,
    content: [
      {
        type: 'image',
        source: {
          type: 'base64',
          media_type: 'image/png',
          data: imageBase64,
        },
      },
    ],
  }
  // Append toolResult to the next user message in your agent loop.
}
```

## Screenshot scaling and coord-map

`usecomputer screenshot` always scales the output image so the longest edge is
at most `1568` px. This keeps screenshots in a model-friendly size for
computer-use agents.

Screenshot output includes:

- `desktopIndex` (display index used for capture)
- `coordMap` in the form `captureX,captureY,captureWidth,captureHeight,imageWidth,imageHeight`
- `hint` with usage text for coordinate mapping

Always pass the exact `--coord-map` value emitted by `usecomputer screenshot`
to pointer commands when you are clicking coordinates from that screenshot.
This maps screenshot-space coordinates back to real screen coordinates:

```bash
usecomputer screenshot ./shot.png --json
usecomputer click -x 400 -y 220 --coord-map "0,0,1600,900,1568,882"
usecomputer mouse move -x 100 -y 80 --coord-map "0,0,1600,900,1568,882"
```

To validate a target before clicking, use `debug-point`. It takes the same
coordinates and `--coord-map`, captures a fresh full-desktop screenshot, and
draws a red marker where the click would land. When `--coord-map` is present,
it captures that same region so the overlay matches the screenshot you are
targeting:

```bash
usecomputer debug-point -x 400 -y 220 --coord-map "0,0,1600,900,1568,882"
```

### Window-scoped screenshots

Capture only a specific application window for a smaller, more focused image.
This improves model accuracy because the screenshot contains only the target
app — no dock, menu bar, or background windows.

```bash
# 1. find the window ID
usecomputer window list --json

# 2. screenshot that window
usecomputer screenshot ./tmp/app.png --window 12345 --json
# output: {"path":"./tmp/app.png","coordMap":"200,100,1200,800,1568,1045",...}

# 3. click using the coord-map (maps window screenshot pixels to desktop coords)
usecomputer click -x 400 -y 220 --coord-map "200,100,1200,800,1568,1045"
```

The coord-map from a window screenshot includes the window's position on
screen, so pointer commands land on the correct desktop coordinates even
though the screenshot only shows one window.

## Kitty Graphics Protocol (agent-friendly screenshots)

When the `AGENT_GRAPHICS` environment variable contains `kitty`, the
`screenshot` command emits the PNG image inline to stdout using the
[Kitty Graphics Protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/).
This lets AI agents receive screenshots in a single tool call — no separate
file read needed.

The protocol is supported by [kitty-graphics-agent](https://github.com/remorses/kitty-graphics-agent),
an OpenCode plugin that intercepts Kitty Graphics escape sequences from CLI
output and injects them as LLM-visible image attachments. To use it, add the
plugin to your `opencode.json`:

```json
{
  "plugin": ["kitty-graphics-agent"]
}
```

The plugin sets `AGENT_GRAPHICS=kitty` in the shell environment automatically.
When the agent runs `usecomputer screenshot`, the image appears directly in the
model's context window.

The JSON output includes `"agentGraphics": true` when the image was emitted
inline, so programmatic consumers know the screenshot is already in context.

## Drag commands

Drag moves the mouse while holding a button down. Coordinates are `x,y` pairs.
The format is `drag <from> <to> [cp]` where `cp` is an optional quadratic
bezier control point that curves the path.

```bash
# Straight line drag (2 points)
usecomputer drag 100,200 500,600

# Curved drag (3 points — cp pulls the curve toward it)
usecomputer drag 100,200 500,600 300,50

# With coord-map from a screenshot
usecomputer drag 100,200 500,600 --coord-map "0,0,1600,900,1568,882"
```

Duration is computed automatically from arc length at ~500 px/s (average human
drawing speed). Shorter drags are faster, longer drags take proportionally more
time.

### Bezier control point

The optional third argument `[cp]` is a quadratic bezier control point. It
"pulls" the curve toward itself — the cursor does NOT pass through it:

```
Straight (2 points):           Curved (3 points):

                                        * cp
from ──────────────── to        from . ´  ` .
                                    ´        ` .
                                   ´            to
```

### Drawing circles and ellipses

A circle at center `(cx, cy)` with radius `r` uses 4 quadratic bezier arcs.
Each arc goes between two cardinal points (top, right, bottom, left), with the
control point at the bounding box corner between them:

```bash
# Circle at center (400, 300) radius 50
usecomputer drag 400,250 450,300 450,250   # top → right,    cp = top-right corner
usecomputer drag 450,300 400,350 450,350   # right → bottom, cp = bottom-right corner
usecomputer drag 400,350 350,300 350,350   # bottom → left,  cp = bottom-left corner
usecomputer drag 350,300 400,250 350,250   # left → top,     cp = top-left corner
```

The pattern for any circle:

```
drag cx,cy-r   cx+r,cy   cx+r,cy-r    # top → right
drag cx+r,cy   cx,cy+r   cx+r,cy+r    # right → bottom
drag cx,cy+r   cx-r,cy   cx-r,cy+r    # bottom → left
drag cx-r,cy   cx,cy-r   cx-r,cy-r    # left → top
```

For an ellipse, use different `rx` and `ry` instead of `r`:

```bash
# Ellipse at center (400, 300) rx=30 ry=80
usecomputer drag 400,220 430,300 430,220   # top → right
usecomputer drag 430,300 400,380 430,380   # right → bottom
usecomputer drag 400,380 370,300 370,380   # bottom → left
usecomputer drag 370,300 400,220 370,220   # left → top
```

## Keyboard commands

### Type text

```bash
# Short text
usecomputer type "hello from usecomputer"

# Type from stdin (good for multiline or very long text)
cat ./notes.txt | usecomputer type --stdin --chunk-size 4000 --chunk-delay 15

# Simulate slower typing for apps that drop fast input
usecomputer type "hello" --delay 20
```

`--delay` is the per-character delay in milliseconds.

For very long text, prefer `--stdin` + `--chunk-size` so shell argument limits
and app input buffers are less likely to cause dropped characters.

### Press keys and shortcuts

```bash
# Single key
usecomputer press "enter"

# Chords
usecomputer press "cmd+s"
usecomputer press "cmd+shift+p"
usecomputer press "ctrl+s"

# Repeats
usecomputer press "down" --count 10 --delay 30
```

Modifier aliases: `cmd`/`command`/`meta`, `ctrl`/`control`, `alt`/`option`,
`shift`, `fn`.

Platform note:

- macOS: `cmd` maps to Command.
- Windows/Linux: `cmd` maps to Win/Super.
- For app shortcuts that should work on Windows/Linux too, prefer `ctrl+...`.

## Coordinate options

Commands that target coordinates accept `-x` and `-y` flags:

- `usecomputer click -x <n> -y <n>`
- `usecomputer hover -x <n> -y <n>`
- `usecomputer mouse move -x <n> -y <n>`

`mouse move` is optional before `click` when click coordinates are already
provided.

Legacy coordinate forms are also accepted where available.

## Display index options

For commands that accept `--display`, the index is 0-based:

- `0` = first display
- `1` = second display
- `2` = third display

Example:

```bash
usecomputer screenshot ./shot.png --display 0 --json
```
