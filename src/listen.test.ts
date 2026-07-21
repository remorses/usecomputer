// End-to-end test for the listen feature.
// Starts the listen async generator, triggers synthetic input events
// using usecomputer's own click/press functions, and asserts the
// generator yields the expected typed events.

import os from 'node:os'
import { describe, expect, test } from 'vitest'
import { listen } from './listen.js'
import { click, press } from './lib.js'
import type { InputEvent } from './types.js'

const isMacOS = os.platform() === 'darwin'

// Helper: collect events from the generator until a condition is met or timeout.
// The generator is consumed in the background so we can fire synthetic events
// after the event tap has had time to initialize.
async function collectEvents(opts: {
  timeoutMs: number
  fireAfterMs: number
  fire: () => Promise<void>
  stopWhen: (events: InputEvent[]) => boolean
}): Promise<InputEvent[]> {
  const generator = listen()
  const events: InputEvent[] = []
  let done = false

  // Start a background task that fires the synthetic event after a delay
  const firePromise = (async () => {
    await new Promise((r) => setTimeout(r, opts.fireAfterMs))
    if (!done) {
      await opts.fire()
    }
  })()

  const deadline = Date.now() + opts.timeoutMs

  try {
    for await (const event of generator) {
      events.push(event)
      if (opts.stopWhen(events) || Date.now() > deadline) {
        break
      }
    }
  } finally {
    done = true
    await generator.return(undefined)
    await firePromise.catch(() => {})
  }

  return events
}

// Tests must run sequentially since each spawns a global CGEventTap and
// concurrent taps can interfere with each other.
describe.sequential('listen', () => {
  const listenTest = isMacOS ? test : test.skip

  listenTest('yields mouseClick events from synthetic clicks', async () => {
    const events = await collectEvents({
      timeoutMs: 8000,
      fireAfterMs: 1500,
      fire: () => click({ point: { x: 400, y: 400 }, button: 'left', count: 1 }),
      stopWhen: (evts) => evts.some((e) => e.type === 'mouseRelease' && e.button === 'left'),
    })

    const clickEvents = events.filter((e) => e.type === 'mouseClick')
    const releaseEvents = events.filter((e) => e.type === 'mouseRelease')
    expect(clickEvents.length).toBeGreaterThanOrEqual(1)
    expect(releaseEvents.length).toBeGreaterThanOrEqual(1)

    const firstClick = clickEvents[0]!
    expect(firstClick.type).toBe('mouseClick')
    if (firstClick.type === 'mouseClick') {
      expect(firstClick.button).toBe('left')
      expect(typeof firstClick.x).toBe('number')
      expect(typeof firstClick.y).toBe('number')
      expect(typeof firstClick.timestamp).toBe('number')
      expect(firstClick.timestamp).toBeGreaterThan(0)
    }
  }, 10000)

  listenTest('yields keyDown and keyUp events from synthetic key press', async () => {
    const events = await collectEvents({
      timeoutMs: 8000,
      fireAfterMs: 1500,
      fire: () => press({ key: 'a', count: 1, delayMs: null }),
      // Wait until we see a keyUp for the 'a' key specifically,
      // since other keys may arrive from previous tests or OS noise.
      stopWhen: (evts) => evts.some((e) => e.type === 'keyUp' && e.key === 'a'),
    })

    const keyDownA = events.filter((e) => e.type === 'keyDown' && e.key === 'a')
    const keyUpA = events.filter((e) => e.type === 'keyUp' && e.key === 'a')
    expect(keyDownA.length).toBeGreaterThanOrEqual(1)
    expect(keyUpA.length).toBeGreaterThanOrEqual(1)

    const firstKeyDown = keyDownA[0]!
    if (firstKeyDown.type === 'keyDown') {
      expect(firstKeyDown.key).toBe('a')
      expect(typeof firstKeyDown.keyCode).toBe('number')
      expect(typeof firstKeyDown.timestamp).toBe('number')
    }
  }, 10000)

  listenTest('events have correct discriminated union type field', async () => {
    const events = await collectEvents({
      timeoutMs: 8000,
      fireAfterMs: 1500,
      fire: () => click({ point: { x: 400, y: 400 }, button: 'left', count: 1 }),
      stopWhen: (evts) => evts.some((e) => e.type === 'mouseRelease'),
    })

    expect(events.length).toBeGreaterThan(0)
    for (const event of events) {
      expect(event.type).toBeDefined()
      expect(
        ['mouseClick', 'mouseRelease', 'mouseMove', 'keyDown', 'keyUp', 'flagsChanged', 'scroll'].includes(event.type),
      ).toBe(true)
    }
  }, 10000)
})
