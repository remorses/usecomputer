// Shared types for usecomputer command parsing and backend bridge calls.

export type MouseButton = 'left' | 'right' | 'middle'

export type ScrollDirection = 'up' | 'down' | 'left' | 'right'

export type Point = {
  x: number
  y: number
}

export type Region = {
  x: number
  y: number
  width: number
  height: number
}

export type CoordMap = {
  captureX: number
  captureY: number
  captureWidth: number
  captureHeight: number
  imageWidth: number
  imageHeight: number
}

export type DisplayInfo = {
  id: number
  index: number
  name: string
  x: number
  y: number
  width: number
  height: number
  scale: number
  isPrimary: boolean
}

export type WindowInfo = {
  id: number
  ownerPid: number
  ownerName: string
  title: string
  x: number
  y: number
  width: number
  height: number
  desktopIndex: number
}

export type ScreenshotInput = {
  path?: string
  display?: number
  window?: number
  region?: Region
  annotate?: boolean
}

export type ScreenshotResult = {
  path: string
  desktopIndex: number
  captureX: number
  captureY: number
  captureWidth: number
  captureHeight: number
  imageWidth: number
  imageHeight: number
  coordMap: string
  hint: string
}

export type ClickInput = {
  point: Point
  button: MouseButton
  count: number
  modifiers: string[]
}

export type TypeInput = {
  text: string
  delayMs?: number
}

export type PressInput = {
  key: string
  count: number
  delayMs?: number
}

export type ScrollInput = {
  direction: ScrollDirection
  amount: number
  at?: Point
}

export type DragInput = {
  from: Point
  to: Point
  cp?: Point
  button: MouseButton
}

// ─── Listen event types (discriminated union via "type" field) ───

/** Button values for listen events. Includes 'other' for side buttons (button 3+). */
export type InputMouseButton = 'left' | 'right' | 'middle' | 'other'

export type MouseClickEvent = {
  type: 'mouseClick'
  button: InputMouseButton
  x: number
  y: number
  timestamp: number
}

export type MouseReleaseEvent = {
  type: 'mouseRelease'
  button: InputMouseButton
  x: number
  y: number
  timestamp: number
}

export type MouseMoveEvent = {
  type: 'mouseMove'
  x: number
  y: number
  timestamp: number
}

export type KeyDownEvent = {
  type: 'keyDown'
  key: string
  keyCode: number
  timestamp: number
}

export type KeyUpEvent = {
  type: 'keyUp'
  key: string
  keyCode: number
  timestamp: number
}

/** Modifier key state change (Shift, Command, Option, Control, Fn, Caps Lock). */
export type FlagsChangedEvent = {
  type: 'flagsChanged'
  key: string
  keyCode: number
  timestamp: number
}

export type ScrollEvent = {
  type: 'scroll'
  x: number
  y: number
  deltaX: number
  deltaY: number
  timestamp: number
}

export type InputEvent =
  | MouseClickEvent
  | MouseReleaseEvent
  | MouseMoveEvent
  | KeyDownEvent
  | KeyUpEvent
  | FlagsChangedEvent
  | ScrollEvent

// ─── Native command types ───

export type NativeErrorObject = {
  code: string
  message: string
  command: string
}

export type NativeCommandResult = {
  ok: boolean
  error?: NativeErrorObject
}

export type NativeDataResult<T> = {
  ok: boolean
  data?: T
  error?: NativeErrorObject
}

export interface UseComputerBridge {
  screenshot(input: ScreenshotInput): Promise<ScreenshotResult>
  click(input: ClickInput): Promise<void>
  typeText(input: TypeInput): Promise<void>
  press(input: PressInput): Promise<void>
  scroll(input: ScrollInput): Promise<void>
  drag(input: DragInput): Promise<void>
  hover(input: Point): Promise<void>
  mouseMove(input: Point): Promise<void>
  mouseDown(input: { button: MouseButton }): Promise<void>
  mouseUp(input: { button: MouseButton }): Promise<void>
  mousePosition(): Promise<Point>
  displayList(): Promise<DisplayInfo[]>
  windowList(): Promise<WindowInfo[]>
}
