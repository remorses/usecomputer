// Typed async generator that streams global input events from the native binary.
// Spawns `usecomputer listen` as a child process and parses its SSE stdout output.
//
// The child's stderr is captured so permission errors and unsupported-platform
// messages surface as thrown errors instead of silently returning.
//
// Memory notes:
// - Consecutive mouseMove events are coalesced to prevent unbounded queue growth
//   when the consumer is slow (mouse moves arrive at ~125 Hz).
// - Pass an AbortSignal to cleanly stop the generator when no events are flowing.
//   Without a signal, breaking out of the for-await loop works when events are
//   actively arriving, but may hang if .return() is called while the generator
//   is waiting with no incoming events.

import { spawn, type ChildProcess } from 'node:child_process'
import { existsSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createParser } from 'eventsource-parser'
import type { InputEvent } from './types.js'

const __dirname = dirname(fileURLToPath(import.meta.url))

function resolveBinaryPath(): string {
  // Dev build path (zig-out from local zig build)
  const devPath = join(__dirname, '..', 'zig-out', 'bin', 'usecomputer')
  if (existsSync(devPath)) {
    return devPath
  }

  // Packaged distribution path (same layout as bin.ts)
  const target = `${process.platform}-${process.arch}`
  const binaryName = process.platform === 'win32' ? 'usecomputer.exe' : 'usecomputer'
  const distPath = join(__dirname, target, binaryName)
  if (existsSync(distPath)) {
    return distPath
  }

  throw new Error(
    `usecomputer native binary not found. Tried:\n  ${devPath}\n  ${distPath}\nRun 'zig build' or install from npm to get prebuilt binaries.`,
  )
}

export type ListenOptions = {
  /** Signal to abort the listener. When aborted, the child process is killed
   *  and the generator returns cleanly. This is the recommended way to stop
   *  listening from outside the for-await loop. */
  signal?: AbortSignal
}

export async function* observe(options?: ListenOptions): AsyncGenerator<InputEvent, void, undefined> {
  const binaryPath = resolveBinaryPath()
  const signal = options?.signal

  let child: ChildProcess | null = null
  // Queue of parsed events waiting to be yielded.
  // Consecutive mouseMove events are coalesced: the latest replaces the
  // previous one so the queue stays bounded during fast mouse movement.
  const queue: InputEvent[] = []
  // Resolve function for when a new event arrives while generator is waiting
  let notify: (() => void) | null = null
  // Track whether the child has exited
  let exited = false
  let exitError: Error | null = null
  // Whether the generator is being intentionally stopped
  let stopping = false
  // Capture stderr for error reporting (capped at 4 KB)
  let stderrOutput = ''

  function wake() {
    if (notify) {
      const n = notify
      notify = null
      n()
    }
  }

  function stopChild() {
    if (!child || exited || stopping) return
    stopping = true
    child.kill('SIGTERM')
    const c = child
    const forceKillTimeout = setTimeout(() => {
      if (!exited) c.kill('SIGKILL')
    }, 1000)
    c.on('close', () => clearTimeout(forceKillTimeout))
  }

  // If the caller provided an AbortSignal, wire it up to kill the child.
  // This breaks the generator out of its pending await so .return() can proceed.
  const onAbort = signal
    ? () => {
        stopChild()
        wake()
      }
    : undefined

  try {
    if (signal?.aborted) return

    child = spawn(binaryPath, ['observe'], {
      stdio: ['ignore', 'pipe', 'pipe'],
    })

    if (onAbort) signal!.addEventListener('abort', onAbort, { once: true })

    const parser = createParser({
      onEvent(sseEvent) {
        try {
          const data = JSON.parse(sseEvent.data) as InputEvent
          // Coalesce consecutive mouseMove events to prevent unbounded growth.
          // At ~125 Hz, a slow consumer would otherwise accumulate thousands
          // of move events. We keep only the latest position.
          if (data.type === 'mouseMove' && queue.length > 0 && queue[queue.length - 1]!.type === 'mouseMove') {
            queue[queue.length - 1] = data
          } else {
            queue.push(data)
          }
          wake()
        } catch {
          // Skip malformed events
        }
      },
    })

    child.stdout!.on('data', (chunk: Buffer) => {
      parser.feed(chunk.toString())
    })

    child.stderr!.on('data', (chunk: Buffer) => {
      if (stderrOutput.length < 4096) {
        stderrOutput += chunk.toString()
      }
    })

    child.on('error', (err) => {
      exitError = err
      exited = true
      wake()
    })

    child.on('close', (code) => {
      if (!stopping && code !== 0 && code !== null) {
        const msg = stderrOutput.trim() || `usecomputer listen exited with code ${code}`
        exitError = new Error(msg)
      }
      exited = true
      wake()
    })

    // Yield events as they arrive
    while (true) {
      // Drain any queued events first
      while (queue.length > 0) {
        yield queue.shift()!
      }

      // If the child has exited and the queue is drained, we're done
      if (exited || stopping) {
        if (exitError) throw exitError
        return
      }

      // Wait for the next event, child exit, or abort signal.
      await new Promise<void>((resolve) => {
        notify = resolve
      })
    }
  } finally {
    if (onAbort) signal?.removeEventListener('abort', onAbort)
    stopChild()
    // Wait for the child to actually exit
    if (child && !exited) {
      await new Promise<void>((resolve) => {
        child!.on('close', () => resolve())
        if (exited) resolve()
      })
    }
  }
}
