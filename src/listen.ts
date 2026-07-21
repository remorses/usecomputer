// Typed async generator that streams global input events from the native binary.
// Spawns `usecomputer listen` as a child process and parses its SSE stdout output.
//
// The child's stderr is captured so permission errors and unsupported-platform
// messages surface as thrown errors instead of silently returning.

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

export async function* listen(): AsyncGenerator<InputEvent, void, undefined> {
  const binaryPath = resolveBinaryPath()

  let child: ChildProcess | null = null
  // Queue of parsed events waiting to be yielded
  const queue: InputEvent[] = []
  // Resolve function for when a new event arrives while generator is waiting
  let notify: (() => void) | null = null
  // Track whether the child has exited
  let exited = false
  let exitError: Error | null = null
  // Whether the generator is being intentionally stopped (break / .return())
  let stopping = false
  // Capture stderr for error reporting
  let stderrOutput = ''

  function wake() {
    if (notify) {
      const n = notify
      notify = null
      n()
    }
  }

  try {
    child = spawn(binaryPath, ['listen'], {
      stdio: ['ignore', 'pipe', 'pipe'],
    })

    const parser = createParser({
      onEvent(sseEvent) {
        try {
          const data = JSON.parse(sseEvent.data) as InputEvent
          queue.push(data)
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
      stderrOutput += chunk.toString()
    })

    child.on('error', (err) => {
      exitError = err
      exited = true
      wake()
    })

    child.on('close', (code) => {
      // If we're not intentionally stopping and the child exited with an error,
      // surface it. This catches permission failures, unsupported platform, etc.
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
      if (exited) {
        if (exitError) {
          throw exitError
        }
        return
      }

      // Wait for the next event or child exit
      await new Promise<void>((resolve) => {
        notify = resolve
      })
    }
  } finally {
    // Cleanup: kill the child process when the generator is returned/thrown
    stopping = true
    if (child && !exited) {
      child.kill('SIGTERM')
      // Wait for close, with a SIGKILL fallback after 1 second
      await new Promise<void>((resolve) => {
        const forceKillTimeout = setTimeout(() => {
          if (child && !exited) {
            child.kill('SIGKILL')
          }
        }, 1000)
        child!.on('close', () => {
          clearTimeout(forceKillTimeout)
          resolve()
        })
        // If already exited between our check and listener setup, resolve now
        if (exited) {
          clearTimeout(forceKillTimeout)
          resolve()
        }
      })
    }
  }
}
