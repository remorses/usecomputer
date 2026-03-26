## General Functions

<a id="..pywinctl._pywinctl_linux.getActiveWindow"></a>

#### getActiveWindow

```python
def getActiveWindow() -> Optional[Window]
```

Get the currently active (focused) Window in default root

WAYLAND
This will not work on Wayland unless you activate unsafe_mode:
   - Press alt + f2
   - write "lg" (without the quotation marks) and press Enter
   - In the command entry box (at the bottom of the window), write "global.context.unsafe_mode = true" (without the quotation marks) and press Enter
   - To exit the "lg" program, click on any of the options in the upper right corner, then press Escape (it seems a lg bug!)
   - You can set unsafe_mode off again by following the same steps, but in this case, using "global.context.unsafe_mode = false"
Anyway, it will not work with all windows (especially built-in/"official" apps do not populate xid nor X-Window object)

**Returns**:

Window object or None

<a id="..pywinctl._pywinctl_linux.getActiveWindowTitle"></a>

#### getActiveWindowTitle

```python
def getActiveWindowTitle() -> str
```

Get the title of the currently active (focused) Window

**Returns**:

window title as string or empty

<a id="..pywinctl._pywinctl_linux.getAllWindows"></a>

#### getAllWindows

```python
def getAllWindows() -> List[Window]
```

Get the list of Window objects for all visible windows in default root

WAYLAND
This will not work on Wayland unless you activate unsafe_mode:
   - Press alt + f2
   - write "lg" (without the quotation marks) and press Enter
   - In the command entry box (at the bottom of the window), write "global.context.unsafe_mode = true" (without the quotation marks) and press Enter
   - To exit the "lg" program, click on any of the options in the upper right corner, then press Escape (it seems a lg bug!)
   - You can set unsafe_mode off again by following the same steps, but in this case, using "global.context.unsafe_mode = false"
Anyway, it will not work with all windows (especially built-in/"official" apps do not populate xid nor X-Window object)

**Returns**:

list of Window objects

<a id="..pywinctl._pywinctl_linux.getAllTitles"></a>

#### getAllTitles

```python
def getAllTitles() -> List[str]
```

Get the list of titles of all visible windows

**Returns**:

list of titles as strings

<a id="..pywinctl._pywinctl_linux.getWindowsWithTitle"></a>

#### getWindowsWithTitle

```python
def getWindowsWithTitle(title: Union[str, re.Pattern[str]],
                        app: Optional[Tuple[str, ...]] = (),
                        condition: int = Re.IS,
                        flags: int = 0)
```

Get the list of window objects whose title match the given string with condition and flags.

Use ''condition'' to delimit the search. Allowed values are stored in pywinctl.Re sub-class (e.g. pywinctl.Re.CONTAINS)
Use ''flags'' to define additional values according to each condition type:

    - IS -- window title is equal to given title (allowed flags: Re.IGNORECASE)
    - CONTAINS -- window title contains given string (allowed flags: Re.IGNORECASE)
    - STARTSWITH -- window title starts by given string (allowed flags: Re.IGNORECASE)
    - ENDSWITH -- window title ends by given string (allowed flags: Re.IGNORECASE)
    - NOTIS -- window title is not equal to given title (allowed flags: Re.IGNORECASE)
    - NOTCONTAINS -- window title does NOT contains given string (allowed flags: Re.IGNORECASE)
    - NOTSTARTSWITH -- window title does NOT starts by given string (allowed flags: Re.IGNORECASE)
    - NOTENDSWITH -- window title does NOT ends by given string (allowed flags: Re.IGNORECASE)
    - MATCH -- window title matched by given regex pattern (allowed flags: regex flags, see https://docs.python.org/3/library/re.html)
    - NOTMATCH -- window title NOT matched by given regex pattern (allowed flags: regex flags, see https://docs.python.org/3/library/re.html)
    - EDITDISTANCE -- window title matched using Levenshtein edit distance to a given similarity percentage (allowed flags: 0-100. Defaults to 90)
    - DIFFRATIO -- window title matched using difflib similarity ratio (allowed flags: 0-100. Defaults to 90)

**Arguments**:

- `title`: title or regex pattern to match, as string
- `app`: (optional) tuple of app names. Defaults to ALL (empty list).  Unsupported on macOS.
- `condition`: (optional) condition to apply when searching the window. Defaults to ''Re.IS'' (is equal to)
- `flags`: (optional) specific flags to apply to condition. Defaults to 0 (no flags)

**Returns**:

list of Window objects

<a id="..pywinctl._pywinctl_linux.getAllAppsNames"></a>

#### getAllAppsNames

```python
def getAllAppsNames() -> List[str]
```

Get the list of names of all visible apps

**Returns**:

list of names as strings

<a id="..pywinctl._pywinctl_linux.getAppsWithName"></a>

#### getAppsWithName

```python
def getAppsWithName(name: Union[str, re.Pattern[str]],
                    condition: int = Re.IS,
                    flags: int = 0) -> List[str]
```

Get the list of app names which match the given string using the given condition and flags.

Use ''condition'' to delimit the search. Allowed values are stored in pywinctl.Re sub-class (e.g. pywinctl.Re.CONTAINS)
Use ''flags'' to define additional values according to each condition type:

    - IS -- app name is equal to given title (allowed flags: Re.IGNORECASE)
    - CONTAINS -- app name contains given string (allowed flags: Re.IGNORECASE)
    - STARTSWITH -- app name starts by given string (allowed flags: Re.IGNORECASE)
    - ENDSWITH -- app name ends by given string (allowed flags: Re.IGNORECASE)
    - NOTIS -- app name is not equal to given title (allowed flags: Re.IGNORECASE)
    - NOTCONTAINS -- app name does NOT contains given string (allowed flags: Re.IGNORECASE)
    - NOTSTARTSWITH -- app name does NOT starts by given string (allowed flags: Re.IGNORECASE)
    - NOTENDSWITH -- app name does NOT ends by given string (allowed flags: Re.IGNORECASE)
    - MATCH -- app name matched by given regex pattern (allowed flags: regex flags, see https://docs.python.org/3/library/re.html)
    - NOTMATCH -- app name NOT matched by given regex pattern (allowed flags: regex flags, see https://docs.python.org/3/library/re.html)
    - EDITDISTANCE -- app name matched using Levenshtein edit distance to a given similarity percentage (allowed flags: 0-100. Defaults to 90)
    - DIFFRATIO -- app name matched using difflib similarity ratio (allowed flags: 0-100. Defaults to 90)

**Arguments**:

- `name`: name or regex pattern to match, as string
- `condition`: (optional) condition to apply when searching the app. Defaults to ''Re.IS'' (is equal to)
- `flags`: (optional) specific flags to apply to condition. Defaults to 0 (no flags)

**Returns**:

list of app names

<a id="..pywinctl._pywinctl_linux.getAllAppsWindowsTitles"></a>

#### getAllAppsWindowsTitles

```python
def getAllAppsWindowsTitles() -> dict
```

Get all visible apps names and their open windows titles

Format:
    
    Key: app name 
    Values: list of window titles as strings

**Returns**:

python dictionary

<a id="..pywinctl._pywinctl_linux.getWindowsAt"></a>

#### getWindowsAt

```python
def getWindowsAt(x: int, y: int) -> Optional[List[Window]]
```

Get the list of Window objects whose windows contain the point ``(x, y)`` on screen

**Arguments**:

- `x`: X screen coordinate of the window(s)
- `y`: Y screen coordinate of the window(s)

**Returns**:

list of Window objects

<a id="..pywinctl._pywinctl_linux.getTopWindowAt"></a>

#### getTopWindowAt

```python
def getTopWindowAt(x: int, y: int) -> Optional[Window]
```

Get the Window object at the top of the stack at the point ``(x, y)`` on screen

**Arguments**:

- `x`: X screen coordinate of the window
- `y`: Y screen coordinate of the window

**Returns**:

Window object or None

<a id="..pywinctl._pywinctl_linux.Window"></a>

<a id="..pywinctl._main._WatchDog"></a>

<a id="..pywinctl.version"></a>

#### version

```python
def version(numberOnly: bool = True) -> str
```

Returns the current version of PyWinCtl module, in the form ''x.x.xx'' as string

#### getAllScreens

<a id="..pywinctl._main.getAllScreens"></a>

```python
def getAllScreens() -> dict
```

Get all monitors info plugged to the system, as a dict.

If watchdog thread is enabled or the 'forceUpdate' param is set to ''True'', it will return updated information.
Otherwise, it will return the monitors info as it was when the PyMonCtl module was initially loaded (static).

Use 'forceUpdate' carefully since it can be CPU-consuming and slow in scenarios in which this function is
repeatedly and quickly invoked, so if it is directly called or indirectly by other functions.

**Returns**:

Monitors info as python dictionary
Output Format:
    Key:
        Display name (in macOS it is necessary to add handle to avoid duplicates)

    Values:
        "system_name":
            name of display as returned by system (in macOS this name can be duplicated!)
        "handle":
            display index as returned by EnumDisplayDevices()
        "is_primary":
            ''True'' if monitor is primary (shows clock and notification area, sign in, lock, CTRL+ALT+DELETE screens...)
        "position":
            Point(x, y) struct containing the display position ((0, 0) for the primary screen)
        "size":
            Size(width, height) struct containing the display size, in pixels
        "workarea":
            Rect(left, top, right, bottom) struct with the screen workarea, in pixels
        "scale":
            Scale ratio, as a tuple of (x, y) scale percentage
        "dpi":
            Dots per inch, as a tuple of (x, y) dpi values
        "orientation":
            Display orientation: 0 - Landscape / 1 - Portrait / 2 - Landscape (reversed) / 3 - Portrait (reversed)
        "frequency":
            Refresh rate of the display, in Hz
        "colordepth":
            Bits per pixel referred to the display color depth

<a id="..pywinctl._main.getScreenSize"></a>

#### getScreenSize

```python
def getScreenSize(name: str = "") -> Tuple[int, int]
```

Get the width and height, in pixels, of the given monitor, or main monitor if no monitor name provided

**Arguments**:

- `name`: name of the monitor as returned by getMonitors() and getDisplay() methods.

**Returns**:

Size struct or None

<a id="..pywinctl._main.getWorkArea"></a>

#### getWorkArea

```python
def getWorkArea(name: str = "") -> Tuple[int, int, int, int]
```

Get coordinates (left, top, right, bottom), in pixels, of the working (usable by windows) area

of the given screen, or main screen if no screen name provided

**Arguments**:

- `name`: name of the monitor as returned by getMonitors() and getDisplay() methods.

**Returns**:

Rect struct or None

<a id="..pywinctl._main.getMousePos"></a>

#### getMousePos

```python
def getMousePos() -> Tuple[int, int]
```

Get the current (x, y) coordinates of the mouse pointer on screen, in pixels

**Returns**:

Point struct

<a id="..pywinctl._main.displayWindowsUnderMouse"></a>

#### displayWindowsUnderMouse

```python
def displayWindowsUnderMouse(xOffset: int = 0, yOffset: int = 0) -> None
```

This function is meant to be run from the command line. It will
automatically display the position of mouse pointer and the titles
of the windows under it

<a id="..pywinctl._pywinctl_linux.checkPermissions"></a>

#### checkPermissions

```python
def checkPermissions(activate: bool = False) -> bool
```

macOS ONLY: Check Apple Script permissions for current script/app and, optionally, shows a

warning dialog and opens security preferences

**Arguments**:

- `activate`: If ''True'' and if permissions are not granted, shows a dialog and opens security preferences.
Defaults to ''False''

**Returns**:

returns ''True'' if permissions are already granted or platform is not macOS

## Window Methods

```python
class Window(BaseWindow)
```

<a id="..pywinctl._pywinctl_linux.Window.getExtraFrameSize"></a>

#### getExtraFrameSize

```python
def getExtraFrameSize(includeBorder: bool = True) -> Tuple[int, int, int, int]
```

Get the extra space, in pixels, around the window, including or not the border.

Notice not all applications/windows will use this property values

**Arguments**:

- `includeBorder`: set to ''False'' to avoid including borders

**Returns**:

additional frame size in pixels, as a tuple of int (left, top, right, bottom)

<a id="..pywinctl._pywinctl_linux.Window.getClientFrame"></a>

#### getClientFrame

```python
def getClientFrame() -> Rect
```

Get the client area of window including scroll, menu and status bars, as a Rect (x, y, right, bottom)

Notice that this method won't match non-standard window decoration sizes

**Returns**:

Rect struct

<a id="..pywinctl._pywinctl_linux.Window.close"></a>

#### close

```python
def close() -> bool
```

Closes this window. This may trigger "Are you sure you want to

quit?" dialogs or other actions that prevent the window from
actually closing. This is identical to clicking the X button on the
window.

**Returns**:

''True'' if window is closed

<a id="..pywinctl._pywinctl_linux.Window.minimize"></a>

#### minimize

```python
def minimize(wait: bool = False) -> bool
```

Minimizes this window

**Arguments**:

- `wait`: set to ''True'' to confirm action requested (in a reasonable time)

**Returns**:

''True'' if window minimized

<a id="..pywinctl._pywinctl_linux.Window.maximize"></a>

#### maximize

```python
def maximize(wait: bool = False) -> bool
```

Maximizes this window

**Arguments**:

- `wait`: set to ''True'' to confirm action requested (in a reasonable time)

**Returns**:

''True'' if window maximized

<a id="..pywinctl._pywinctl_linux.Window.restore"></a>

#### restore

```python
def restore(wait: bool = False, user: bool = True) -> bool
```

If maximized or minimized, restores the window to its normal size

**Arguments**:

- `wait`: set to ''True'' to confirm action requested (in a reasonable time)
- `user`: ignored on Windows platform

**Returns**:

''True'' if window restored

<a id="..pywinctl._pywinctl_linux.Window.show"></a>

#### show

```python
def show(wait: bool = False) -> bool
```

If hidden or showing, shows the window on screen and in title bar

**Arguments**:

- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)

**Returns**:

''True'' if window showed

<a id="..pywinctl._pywinctl_linux.Window.hide"></a>

#### hide

```python
def hide(wait: bool = False) -> bool
```

If hidden or showing, hides the window from screen and title bar

**Arguments**:

- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)

**Returns**:

''True'' if window hidden

<a id="..pywinctl._pywinctl_linux.Window.activate"></a>

#### activate

```python
def activate(wait: bool = False, user: bool = True) -> bool
```

Activate this window and make it the foreground (focused) window

**Arguments**:

- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
- `user`: ''True'' indicates a direct user request, as required by some WMs to comply.

**Returns**:

''True'' if window activated

<a id="..pywinctl._pywinctl_linux.Window.resize"></a>

#### resize

```python
def resize(widthOffset: int, heightOffset: int, wait: bool = False)
```

Resizes the window relative to its current size

**Arguments**:

- `widthOffset`: offset to add to current window width as target width
- `heightOffset`: offset to add to current window height as target height
- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)

**Returns**:

''True'' if window resized to the given size

<a id="..pywinctl._pywinctl_linux.Window.resizeRel"></a>

#### resizeRel

resizeRel is an alias for the resize() method.

<a id="..pywinctl._pywinctl_linux.Window.resizeTo"></a>

#### resizeTo

```python
def resizeTo(newWidth: int, newHeight: int, wait: bool = False)
```

Resizes the window to a new width and height

**Arguments**:

- `newWidth`: target window width
- `newHeight`: target window height
- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)

**Returns**:

''True'' if window resized to the given size

<a id="..pywinctl._pywinctl_linux.Window.move"></a>

#### move

```python
def move(xOffset: int, yOffset: int, wait: bool = False)
```

Moves the window relative to its current position

**Arguments**:

- `xOffset`: offset relative to current X coordinate to move the window to
- `yOffset`: offset relative to current Y coordinate to move the window to
- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)

**Returns**:

''True'' if window moved to the given position

<a id="..pywinctl._pywinctl_linux.Window.moveRel"></a>

#### moveRel

moveRel is an alias for the move() method.

<a id="..pywinctl._pywinctl_linux.Window.moveTo"></a>

#### moveTo

```python
def moveTo(newLeft: int, newTop: int, wait: bool = False)
```

Moves the window to new coordinates on the screen

**Arguments**:

- `newLeft`: target X coordinate to move the window to
- `newTop`: target Y coordinate to move the window to
- `wait`: set to ''True'' to wait until action is confirmed (in a reasonable time lap)

**Returns**:

''True'' if window moved to the given position

<a id="..pywinctl._pywinctl_linux.Window.alwaysOnTop"></a>

#### alwaysOnTop

```python
def alwaysOnTop(aot: bool = True) -> bool
```

Keeps window on top of all others.

**Arguments**:

- `aot`: set to ''False'' to deactivate always-on-top behavior

**Returns**:

''True'' if command succeeded

<a id="..pywinctl._pywinctl_linux.Window.alwaysOnBottom"></a>

#### alwaysOnBottom

```python
def alwaysOnBottom(aob: bool = True) -> bool
```

Keeps window below of all others, but on top of desktop icons and keeping all window properties

**Arguments**:

- `aob`: set to ''False'' to deactivate always-on-bottom behavior

**Returns**:

''True'' if command succeeded

<a id="..pywinctl._pywinctl_linux.Window.lowerWindow"></a>

#### lowerWindow

```python
def lowerWindow() -> bool
```

Lowers the window to the bottom so that it does not obscure any sibling windows

**Returns**:

''True'' if window lowered

<a id="..pywinctl._pywinctl_linux.Window.raiseWindow"></a>

#### raiseWindow

```python
def raiseWindow() -> bool
```

Raises the window to top so that it is not obscured by any sibling windows.

**Returns**:

''True'' if window raised

<a id="..pywinctl._pywinctl_linux.Window.sendBehind"></a>

#### sendBehind

```python
def sendBehind(sb: bool = True) -> bool
```

Sends the window to the very bottom, below all other windows, including desktop icons.

It may also cause that the window does not accept focus nor keyboard/mouse events as well as
make the window disappear from taskbar and/or pager.

**Arguments**:

- `sb`: set to ''False'' to bring the window back to front

**Returns**:

''True'' if window sent behind desktop icons
Notes:
    - On GNOME it will obscure desktop icons... by the moment

<a id="..pywinctl._pywinctl_linux.Window.acceptInput"></a>

#### acceptInput

```python
def acceptInput(setTo: bool)
```

Toggles the window to accept input and focus

**Arguments**:

- `setTo`: True/False to toggle window ignoring input and focus

**Returns**:

None

<a id="..pywinctl._pywinctl_linux.Window.getAppName"></a>

#### getAppName

```python
def getAppName() -> str
```

Get the name of the app current window belongs to

**Returns**:

name of the app as string

<a id="..pywinctl._pywinctl_linux.Window.getParent"></a>

#### getParent

```python
def getParent() -> int
```

Get the handle of the current window parent. It can be another window or an application

**Returns**:

handle of the window parent

<a id="..pywinctl._pywinctl_linux.Window.setParent"></a>

#### setParent

```python
def setParent(parent: int) -> bool
```

Current window will become child of given parent

WARNING: Not implemented in AppleScript (not possible in macOS for foreign - other apps' - windows)

**Arguments**:

- `parent`: window to set as current window parent

**Returns**:

''True'' if current window is now child of given parent

<a id="..pywinctl._pywinctl_linux.Window.getChildren"></a>

#### getChildren

```python
def getChildren() -> List[int]
```

Get the children handles of current window

**Returns**:

list of handles

<a id="..pywinctl._pywinctl_linux.Window.getHandle"></a>

#### getHandle

```python
def getHandle() -> int
```

Get the current window handle

**Returns**:

window handle

<a id="..pywinctl._pywinctl_linux.Window.isParent"></a>

#### isParent

```python
def isParent(child: int) -> bool
```

Returns ''True'' if the window is parent of the given window as input argument

**Arguments**:

- `child`: handle of the window you want to check if the current window is parent of

<a id="..pywinctl._pywinctl_linux.Window.isParentOf"></a>

#### isParentOf

isParentOf is an alias of isParent method

<a id="..pywinctl._pywinctl_linux.Window.isChild"></a>

#### isChild

```python
def isChild(parent: int)
```

Check if current window is child of given window/app (handle)

On Windows, the list will contain up to one display (displays can not overlap), whilst in Linux and macOS, the
list may contain several displays.

**Arguments**:

- `parent`: handle of the window/app you want to check if the current window is child of

**Returns**:

''True'' if current window is child of the given window

<a id="..pywinctl._pywinctl_linux.Window.isChildOf"></a>

#### isChildOf

isChildOf is an alias of isParent method

<a id="..pywinctl._pywinctl_linux.Window.getDisplay"></a>

#### getDisplay

```python
def getDisplay() -> List[str]
```

Get display names in which current window space is mostly visible

**Returns**:

display name as list of strings or empty (couldn't retrieve it or window is off-screen)

<a id="..pywinctl._pywinctl_linux.Window.getMonitor"></a>

#### getMonitor

getMonitor is an alias of getDisplay method

<a id="..pywinctl._pywinctl_linux.Window.isMinimized"></a>

#### isMinimized

```python
@property
def isMinimized() -> bool
```

Check if current window is currently minimized

**Returns**:

``True`` if the window is minimized

<a id="..pywinctl._pywinctl_linux.Window.isMaximized"></a>

#### isMaximized

```python
@property
def isMaximized() -> bool
```

Check if current window is currently maximized

**Returns**:

``True`` if the window is maximized

<a id="..pywinctl._pywinctl_linux.Window.isActive"></a>

#### isActive

```python
@property
def isActive()
```

Check if current window is currently the active, foreground window

**Returns**:

``True`` if the window is the active, foreground window

<a id="..pywinctl._pywinctl_linux.Window.title"></a>

#### title

```python
@property
def title() -> str
```

Get the current window title, as string

**Returns**:

title as a string

<a id="..pywinctl._pywinctl_linux.Window.visible"></a>

#### visible

```python
@property
def visible() -> bool
```

Check if current window is visible (minimized windows are also visible)

**Returns**:

``True`` if the window is currently visible

<a id="..pywinctl._pywinctl_linux.Window.isVisible"></a>

#### isVisible

isVisible is an alias for the visible property.

<a id="..pywinctl._pywinctl_linux.Window.isAlive"></a>

#### isAlive

```python
@property
def isAlive() -> bool
```

Check if window (and application) still exists (minimized and hidden windows are included as existing)

**Returns**:

''True'' if window exists

<a id="..pywinctl._pywinctl_macos.MacOSWindow.updatedTitle"></a>

#### updatedTitle

```python
@property
def updatedTitle() -> str
```

Get and updated title by finding a similar window title within same application.

It uses a similarity check to find the best match in case title changes (no way to effectively detect it).
This can be useful since this class uses window title to identify the target window.
If watchdog is activated, it will stop in case title changes.

IMPORTANT:

- New title may not belong to the original target window, it is just similar within same application
- If original title or a similar one is not found, window may still exist

**Returns**:

possible new title, empty if no similar title found or same title if it didn't change, as a string

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu"></a>

## WatchDog Methods

```python
class _WatchDog()
```

Set a watchdog, in a separate Thread, to be notified when some window states change

Notice that changes will be notified according to the window status at the very moment of instantiating this class

IMPORTANT: This can be extremely slow in macOS Apple Script version

 Available methods:
:meth start: Initialize and start watchdog and selected callbacks
:meth updateCallbacks: Change the states this watchdog is hooked to
:meth updateInterval: Change the interval to check changes
:meth kill: Stop the entire watchdog and all its hooks
:meth isAlive: Check if watchdog is running

<a id="..pywinctl._main._WatchDog.start"></a>

#### start

```python
def start(isAliveCB: Callable[[bool], None] | None = None,
          isActiveCB: Callable[[bool], None] | None = None,
          isVisibleCB: Callable[[bool], None] | None = None,
          isMinimizedCB: Callable[[bool], None] | None = None,
          isMaximizedCB: Callable[[bool], None] | None = None,
          resizedCB: Callable[[Tuple[int, int]], None] | None = None,
          movedCB: Callable[[Tuple[int, int]], None] | None = None,
          changedTitleCB: Callable[[str], None] | None = None,
          changedDisplayCB: Callable[[List[str]], None] | None = None,
          interval: float = 0.3)
```

Initialize and start watchdog and hooks (callbacks to be invoked when desired window states change)

Notice that changes will be notified according to the window status at the very moment of execute start()

The watchdog is asynchronous, so notifications will not be immediate (adjust interval value to your needs)

The callbacks definition MUST MATCH their return value (boolean, string or (int, int))

IMPORTANT: This can be extremely slow in macOS Apple Script version

**Arguments**:

- `isAliveCB`: callback to call if window is not alive. Set to None to not watch this
Returns the new alive status value (False)
- `isActiveCB`: callback to invoke if window changes its active status. Set to None to not watch this
Returns the new active status value (True/False)
- `isVisibleCB`: callback to invoke if window changes its visible status. Set to None to not watch this
Returns the new visible status value (True/False)
- `isMinimizedCB`: callback to invoke if window changes its minimized status. Set to None to not watch this
Returns the new minimized status value (True/False)
- `isMaximizedCB`: callback to invoke if window changes its maximized status. Set to None to not watch this
Returns the new maximized status value (True/False)
- `resizedCB`: callback to invoke if window changes its size. Set to None to not watch this
Returns the new size (width, height)
- `movedCB`: callback to invoke if window changes its position. Set to None to not watch this
Returns the new position (x, y)
- `changedTitleCB`: callback to invoke if window changes its title. Set to None to not watch this
Returns the new title (as string)
- `changedDisplayCB`: callback to invoke if window changes display. Set to None to not watch this
Returns the new display name (as string)
- `interval`: set the interval to watch window changes. Default is 0.3 seconds

<a id="..pywinctl._main._WatchDog.updateCallbacks"></a>

#### updateCallbacks

```python
def updateCallbacks(isAliveCB: Callable[[bool], None] | None = None,
                    isActiveCB: Callable[[bool], None] | None = None,
                    isVisibleCB: Callable[[bool], None] | None = None,
                    isMinimizedCB: Callable[[bool], None] | None = None,
                    isMaximizedCB: Callable[[bool], None] | None = None,
                    resizedCB: Callable[[Tuple[int, int]], None] | None = None,
                    movedCB: Callable[[Tuple[int, int]], None] | None = None,
                    changedTitleCB: Callable[[str], None] | None = None,
                    changedDisplayCB: Callable[[List[str]], None]
                    | None = None)
```

Change the states this watchdog is hooked to

The callbacks definition MUST MATCH their return value (boolean, string or (int, int))

IMPORTANT: When updating callbacks, remember to set ALL desired callbacks or they will be deactivated

IMPORTANT: Remember to set ALL desired callbacks every time, or they will be defaulted to None (and unhooked)

**Arguments**:

- `isAliveCB`: callback to call if window is not alive. Set to None to not watch this
Returns the new alive status value (False)
- `isActiveCB`: callback to invoke if window changes its active status. Set to None to not watch this
Returns the new active status value (True/False)
- `isVisibleCB`: callback to invoke if window changes its visible status. Set to None to not watch this
Returns the new visible status value (True/False)
- `isMinimizedCB`: callback to invoke if window changes its minimized status. Set to None to not watch this
Returns the new minimized status value (True/False)
- `isMaximizedCB`: callback to invoke if window changes its maximized status. Set to None to not watch this
Returns the new maximized status value (True/False)
- `resizedCB`: callback to invoke if window changes its size. Set to None to not watch this
Returns the new size (width, height)
- `movedCB`: callback to invoke if window changes its position. Set to None to not watch this
Returns the new position (x, y)
- `changedTitleCB`: callback to invoke if window changes its title. Set to None to not watch this
Returns the new title (as string)
- `changedDisplayCB`: callback to invoke if window changes display. Set to None to not watch this
Returns the new display name (as string)

<a id="..pywinctl._main._WatchDog.updateInterval"></a>

#### updateInterval

```python
def updateInterval(interval: float = 0.3)
```

Change the interval to check changes

**Arguments**:

- `interval`: set the interval to watch window changes. Default is 0.3 seconds

<a id="..pywinctl._main._WatchDog.setTryToFind"></a>

#### setTryToFind

```python
def setTryToFind(tryToFind: bool)
```

In macOS Apple Script version, if set to ''True'' and in case title changes, watchdog will try to find

a similar title within same application to continue monitoring it. It will stop if set to ''False'' or
similar title not found.

IMPORTANT:

- It will have no effect in other platforms (Windows and Linux) and classes (MacOSNSWindow)
- This behavior is deactivated by default, so you need to explicitly activate it

**Arguments**:

- `tryToFind`: set to ''True'' to try to find a similar title. Set to ''False'' to deactivate this behavior

<a id="..pywinctl._main._WatchDog.stop"></a>

#### stop

```python
def stop()
```

Stop the entire WatchDog and all its hooks

<a id="..pywinctl._main._WatchDog.isAlive"></a>

#### -[watchdog-]()isAlive

```python
def isAlive()
```

Check if watchdog is running

**Returns**:

''True'' if watchdog is alive

## Menu Methods

```python
class _Menu()
```

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu.getMenu"></a>

#### getMenu

```python
def getMenu(addItemInfo: bool = False) -> dict[str, _SubMenuStructure]
```

Loads and returns Menu options, sub-menus and related information, as dictionary.

It is HIGHLY RECOMMENDED to pre-load the Menu struct by explicitly calling getMenu()
before invoking any other method.

WARNING: "item_info" is extremely huge and slow. Instead use getMenuItemInfo() method individually

WARNING: Notice there are "hidden" menu entries which are not visible, but are returned
when querying menu. These entries do not have position nor size.

**Arguments**:

- `addItemInfo`: if ''True'', adds "item_info" struct and "shortcut" to the output
"item_info" is extremely huge and slow. Instead use getMenuItemInfo() method individually

**Returns**:

python dictionary with MENU struct
Output Format:
    Key:
        item (option or sub-menu) title

    Values:
        "parent":
            parent sub-menu handle (main menu handle for level-0 items)


            item handle (!= 0 for sub-menu items only)
        "wID":
            item ID (required for other actions, e.g. clickMenuItem())
        "rect":
            Rect struct of the menu item (relative to window position)
        "item_info" (optional):
            MENUITEMINFO struct containing all avialable menu item info
        "shortcut" (optional):
            shortcut to menu item, if any. Included only if item_info is included as well (addItemInfo=True)
        "entries":
            sub-items within the sub-menu (if any)

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu.clickMenuItem"></a>

#### clickMenuItem

```python
def clickMenuItem(itemPath: Optional[Sequence[str]] = None,
                  wID: int = 0) -> bool
```

Simulates a click on a menu item

Notes:
    - It will not work for men/sub-menu entries
    - It will not work if selected option is disabled

Use one of these input parameters to identify desired menu item:

**Arguments**:

- `itemPath`: desired menu option and predecessors as list (e.g. ["Menu", "SubMenu", "Item"]). Notice it is language-dependent, so it's better to fulfill it from MENU struct as returned by :meth: getMenu()
- `wID`: item ID within menu struct (as returned by getMenu() method)

**Returns**:

''True'' if menu item to click is correct and exists (not if it has already been clicked or it had any effect)

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu.getMenuInfo"></a>

#### getMenuInfo

```python
def getMenuInfo(hSubMenu: int)
```

Returns the MENUINFO struct of the given sub-menu or main menu if none given

Format:
    Key:
        attribute name

    Values:
        "value":"
            value of attribute
        "class":
            class of attribute
        "settable":
            indicates if attribute can be modified (true/false)

**Arguments**:

- `hSubMenu`: id of the sub-menu entry (as returned by getMenu() method)

**Returns**:

MENUINFO struct

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu.getMenuItemCount"></a>

#### getMenuItemCount

```python
def getMenuItemCount(hSubMenu: int) -> int
```

Returns the number of items within a menu (main menu if no sub-menu given)

**Arguments**:

- `hSubMenu`: id of the sub-menu entry (as returned by getMenu() method)

**Returns**:

number of items as int

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu.getMenuItemInfo"></a>

#### getMenuItemInfo

```python
def getMenuItemInfo(hSubMenu: int, wID: int)
```

Returns the MENUITEMINFO struct for the given menu item

Format:
    Key:
        attribute name

    Values:
        "value":"
            value of attribute
        "class":
            class of attribute
        "settable":
            indicates if attribute can be modified (true/false)

**Arguments**:

- `hSubMenu`: id of the sub-menu entry (as returned by :meth: getMenu())
- `wID`: id of the window within menu struct (as returned by :meth: getMenu())

**Returns**:

MENUITEMINFO struct

<a id="..pywinctl._pywinctl_macos.MacOSWindow._Menu.getMenuItemRect"></a>

#### getMenuItemRect

```python
def getMenuItemRect(hSubMenu: int, wID: int) -> Rect
```

Get the Rect struct (left, top, right, bottom) of the given Menu option

**Arguments**:

- `hSubMenu`: id of the sub-menu entry (as returned by :meth: getMenu())
- `wID`: id of the window within menu struct (as returned by :meth: getMenu())

**Returns**:

Rect struct
