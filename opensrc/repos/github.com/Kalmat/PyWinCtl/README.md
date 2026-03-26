# PyWinCtl <a name="pywinctl"></a>
[![Type Checking](https://github.com/Kalmat/PyWinCtl/actions/workflows/type-checking.yml/badge.svg?branch=dev)](https://github.com/Kalmat/PyWinCtl/actions/workflows/type-checking.yml)
[![PyPI version](https://badge.fury.io/py/PyWinCtl.svg)](https://badge.fury.io/py/PyWinCtl)
[![Documentation Status](https://readthedocs.org/projects/pywinctl/badge/?version=latest)](https://pywinctl.readthedocs.io/en/latest/?badge=latest)
[![Downloads](https://static.pepy.tech/badge/pywinctl/month)](https://pepy.tech/project/pywinctl)


Cross-Platform module to get info on and control windows on screen.

With PyWinCtl you can retrieve info or control windows from other open applications, as well as use it as a cross-platform toolkit to manipulate your own application windows.

This module is a Python 3 evolution from [asweigart's PyGetWindow module](https://github.com/asweigart/PyGetWindow), which adds Linux/X11 and macOS support to the MS Windows-only original module, multi-monitor support, and many additional features; in the hope others can use it, test it or contribute.

My most sincere thanks and acknowledgement. amongst many others (see AUTHORS.txt), to [MestreLion](https://github.com/MestreLion), [super-ibby](https://github.com/super-ibby), [Avasam](https://github.com/Avasam), [macdeport](https://github.com/macdeport) and [holychowders](https://github.com/holychowders) for their help and moral boost.

1. [Window Features](#window-features)
   1. [Important macOS notice](#macos-notice)
   2. [Important Linux notice](#linux-notice)
2. [Window Change Notifications](#watchdog])
   1. [Important comments](#watchdog-comments)
   2. [Important macOS Apple Script version notice](#watchdog-macos-comments)
3. [Menu Features](#menu-features)
4. [Install](#install)
5. [Support](#support)
6. [Using this code](#using)
7. [Test](#test)


## Window Features <a name="window-features"></a>

There are three kinds of functions to be used within PyWinCtl:
- General, independent functions: These functions can be directly invoked at module level, without the need of referencing a Window object (e.g. `pywinctl.getActiveWindow()` or `pywinctl.getAllTitles()`)
- Window class: You need a Window object to control or get info on the target window on screen. It is possible to get a Window object by using any of the general methods (e.g. getActiveWidow() or getWindowsWithTitle()). You can also use the window id, as returned by PyQt's self.winId() or tkinter's root.frame(), which is very handy to get the Window object for your own application.
  - Methods: functions within Window class to get info or perform actions and changes on target window (e.g. `window.resizeTo(800, 600)` or `window.close()`)
  - Properties: Window attributes, getters and setters, that also require to use a Window object (e.g. `window.title` or `window.center = (500, 300)`)

These features are available at the moment, in all three platforms (Windows, Linux and macOS)

|                  General, independent functions:                   |                Window class methods:                 |                                  Window class properties:                                  |
|:------------------------------------------------------------------:|:----------------------------------------------------:|:------------------------------------------------------------------------------------------:|
|          [getActiveWindow](docstrings.md#getactivewindow)          |             [close](docstrings.md#close)             |                             (GET) [title](docstrings.md#title)                             |
|     [getActiveWindowTitle](docstrings.md#getactivewindowtitle)     |          [minimize](docstrings.md#minimize)          |            (GET) [updatedTitle](docstrings.md#updatedtitle) (MacOSWindow only)             |
|            [getAllWindows](docstrings.md#getallwindows)            |          [maximize](docstrings.md#maximize)          |                       (GET) [isMaximized](docstrings.md#ismaximized)                       |
|             [getAllTitles](docstrings.md#getalltitles)             |           [restore](docstrings.md#restore)           |                       (GET) [isMinimized](docstrings.md#isminimized)                       |
|      [getWindowsWithTitle](docstrings.md#getwindowswithtitle)      |              [hide](docstrings.md#hide)              |                          (GET) [isActive](docstrings.md#isactive)                          |
|          [getAllAppsNames](docstrings.md#getallappsnames)          |              [show](docstrings.md#show)              |                         (GET) [isVisible](docstrings.md#isvisible)                         |
|          [getAppsWithName](docstrings.md#getappswithname)          |          [activate](docstrings.md#activate)          |                          (GET) [isAlive](docstrings.md#isvisible)                          |
|  [getAllAppsWindowsTitles](docstrings.md#getallappswindowstitles)  |      [resize / resizeRel](docstrings.md#resize)      | **Position / Size** (inherited from [PyWinBox module](https://github.com/Kalmat/PyWinBox)) |
|           [getWindowsAt](docstrings.md#getwindowsat)               |          [resizeTo](docstrings.md#resizeto)          |                                 (GET/SET) position (x, y)                                  |
| [getTopWindowAt](docstrings.md#gettopwindowat)                     |         [move / moveRel](docstrings.md#move)         |                                     (GET/SET) left (x)                                     |
| [displayWindowsUnderMouse](docstrings.md#displaywindowsundermouse) |            [moveTo](docstrings.md#moveto)            |                                     (GET/SET) top (y)                                      |
| [version](docstrings.md#version)                                   |       [raiseWindow](docstrings.md#raisewindow)       |                                    (GET/SET) right (x)                                     |
| [checkPermissions](docstrings.md#checkpermissions) (macOS only)    |       [lowerWindow](docstrings.md#lowerwindow)       |                                    (GET/SET) bottom (y)                                    |
|                                                                    |       [alwaysOnTop](docstrings.md#alwaysontop)       |                                  (GET/SET) topleft (x, y)                                  |
|                                                                    |    [alwaysOnBottom](docstrings.md#alwaysonbottom)    |                                 (GET/SET) topright (x, y)                                  |
|                                                                    |        [sendBehind](docstrings.md#sendbehind)        |                                (GET/SET) bottomleft (x, y)                                 |
|                                                                    |       [acceptInput](docstrings.md#acceptinput)       |                                (GET/SET) bottomright (x, y)                                |
|                                                                    |        [getAppName](docstrings.md#getappname)        |                                  (GET/SET) midtop (x, y)                                   |
|                                                                    |         [getHandle](docstrings.md#gethandle)         |                                  (GET/SET) midleft (x, y)                                  |
|                                                                    |         [getParent](docstrings.md#getparent)         |                                 (GET/SET) midbotton (x, y)                                 |
|                                                                    |         [setParent](docstrings.md#setparent)         |                                 (GET/SET) midright (x, y)                                  |
|                                                                    |       [getChildren](docstrings.md#getchildren)       |                                  (GET/SET) center (x, y)                                   |
|                                                                    |          [isParent](docstrings.md#isparent)          |                                   (GET/SET) centerx (x)                                    |
|                                                                    |           [isChild](docstrings.md#ischild)           |                                   (GET/SET) centery (y)                                    |
|                                                                    |        [getDisplay](docstrings.md#getdisplay)        |                               (GET/SET) size (width, height)                               |
|                                                                    | [getExtraFrameSize](docstrings.md#getextraframesize) |                                      (GET/SET) width                                       |
|                                                                    |    [getClientFrame](docstrings.md#getclientframe)    |                                      (GET/SET) height                                      |
|                                                                    |                        getPID                        |                             (GET/SET) box (x, y, width, height                             |
|                                                                    |                                                      |                            (GET/SET) rect (x, y, right, bottom)                            |

***Important macOS notice <a name="macos-notice"></a>***

macOS doesn't "like" controlling windows from other apps. MacOSWindow() class is based on Apple Script, so it is non-standard, slower and, in some cases, tricky (uses window name as reference, which may change or be duplicate), but it's working fine in most cases. You will likely need to grant permissions on Settings -> Security&Privacy -> Accessibility. ***Notice some applications will have limited Apple Script support or no support at all, so some or even all methods may fail!***

***Important Linux notice <a name="linux-notice"></a>***

The enormous variety of Linux distributions, Desktop Environments, Window Managers, and their combinations, make it impossible to test in all scenarios.

This module has been tested OK in some X11 setups: Ubuntu/Gnome, Ubuntu/KDE, Ubuntu/Unity, Mint/Cinnamon and Raspbian/LXDE. Except for Mint/Cinnamon and Ubuntu 22.04+, `sendBehind()` method doesn't properly work!

In Wayland (the new GNOME protocol for Ubuntu 22.04+), it is not possible to retrieve the active window nor the list 
of open windows, so `getActiveWindow()` and `getAllWindows()` will not likely work even though unsafe-mode is  
enabled (built-in and "official" applications do not populate their Xid nor their X-Window object, so it may work for
other applications like Chrome or your own application windows)

In case you find problems in other configs, please [open an issue](https://github.com/Kalmat/PyWinCtl/issues). Furthermore, if you have knowledge in these other configs, do not hesitate to contribute!

## Window Change Notifications <a name="watchdog"></a>

Window watchdog sub-class, running in a separate Thread, will allow to define hooks and its callbacks to be notified when some window states change. Accessible through 'watchdog' submodule.

The watchdog will automatically stop when window doesn't exist anymore or main program quits.

    isAliveCB:      callback to invoke when window is not alive anymore. Set to None to not to watch this
                    Passes the new alive status value (False)
    
    isActiveCB:     callback to invoke if window changes its active status. Set to None to not to watch this
                    Passes the new active status value (True/False)
    
    isVisibleCB:    callback to invoke if window changes its visible status. Set to None to not to watch this
                    Passes the new visible status value (True/False)

    isMinimizedCB:  callback to invoke if window changes its minimized status. Set to None to not to watch this
                    Passes the new minimized status value (True/False)

    isMaximizedCB:  callback to invoke if window changes its maximized status. Set to None to not to watch this
                    Passes the new maximized status value (True/False)
    
    resizedCB:      callback to invoke if window changes its size. Set to None to not to watch this
                    Passes the new size (width, height)
    
    movedCB:        callback to invoke if window changes its position. Set to None to not to watch this
                    Passes the new position (x, y)
    
    changedTitleCB: callback to invoke if window changes its title. Set to None to not to watch this
                    Passes the new title (as string)
                    IMPORTANT: In MacOS AppScript version, if title changes, watchdog will stop unless using setTryToFind(True)

    changedDisplayCB: callback to invoke if window changes display. Set to None to not to watch this
                      Passes the new display name (as string)

|              watchdog sub-module methods:               |
|:-------------------------------------------------------:|
|              [start](docstrings.md#start)               |
|    [updateCallbacks](docstrings.md#updatecallbacks)     |
|     [updateInterval](docstrings.md#updateinterval)      |
| [setTryToFind](docstrings.md#settrytofind) (macOS only) |
|       [isAlive](docstrings.md#-watchdog-isalive)        |
|               [stop](docstrings.md#stop)                |

Example:

    import pywinctl as pwc
    import time

    def activeCB(active):
        print("NEW ACTIVE STATUS", active)

    def movedCB(pos):
        print("NEW POS", pos)

    npw = pwc.getActiveWindow()
    npw.watchdog.start(isActiveCB=activeCB)
    npw.watchdog.setTryToFind(True)
    print("Toggle focus and move active window")
    print("Press Ctl-C to Quit")
    i = 0
    while True:
        try:
            if i == 50:
                npw.watchdog.updateCallbacks(isActiveCB=activeCB, movedCB=movedCB)
            if i == 100:
                npw.watchdog.updateInterval(0.1)
                npw.watchdog.setTryToFind(False)
            time.sleep(0.1)
        except KeyboardInterrupt:
            break
        i += 1
    npw.watchdog.stop()


***Important comments <a name="watchdog-comments"></a>***

- The callbacks definition MUST MATCH their invocation params (boolean, string or (int, int))
- The watchdog is asynchronous, so notifications won't be immediate (adjust interval value to your needs). Use window object properties instead (e.g. isAlive)
- Position and size notifications will trigger several times between initial and final values
- When updating callbacks, remember to set ALL desired callbacks. Non-present (None) callbacks will be deactivated

***Important macOS Apple Script version notice <a name="watchdog-macos-comments"></a>***

- Might be very slow and resource-consuming
- It uses the title to identify the window, so if it changes, the watchdog will consider it is not available anymore and will stop
- To avoid this, use ''tryToFind(True)'' method to try to find the new title (not fully guaranteed since it uses a similarity check, so the new title might not be found or correspond to a different window)


## Menu Features <a name="menu-features"></a>

***Available in: MS-Windows and macOS Apple Script version (Win32Window() and MacOSWindow() classes)***

menu sub-class for Menu info and control methods, accessible through 'menu' submodule.

|              menu sub-module methods:              |
|:--------------------------------------------------:|
|          [getMenu](docstrings.md#getmenu)          |
|      [getMenuInfo](docstrings.md#getmenuinfo)      |
| [getMenuItemCount](docstrings.md#getmenuitemcount) |
|  [getMenuItemInfo](docstrings.md#getmenuiteminfo)  |
|  [getMenuItemRect](docstrings.md#getmenuitemrect)  |
|    [clickMenuItem](docstrings.md#clickmenuitem)    |

MS-Windows example (notice it is language-dependent):

    import pywinctl as pwc
    import subprocess
    # import json

    subprocess.Popen('notepad')
    windows = pwc.getWindowsWithTitle('notepad', condition=pwc.Re.CONTAINS, flags=pwc.Re.IGNORECASE)
    if windows:
        win = windows[0]
        menu = win.menu.getMenu()
        # print(json.dumps(menu, indent=4, ensure_ascii=False))  # Prints menu dict in legible format
        ret = win.menu.clickMenuItem(["File", "Exit"])           # Exit program
        if not ret:
            print("Option not found. Check option path and language")
    else:
        print("Window not found. Check application name and language")

Menu dictionary (returned by getMenu() method) will likely contain all you may need to handle application menu:

    Key:            item title
    Values:
      "parent":     parent sub-menu handle
      "hSubMenu":   item handle (!= 0 for sub-menus only)
      "wID":        item ID (required for other actions, e.g. clickMenuItem())
      "rect":       Rect struct of the menu item. (Windows: It is relative to window position, so it won't likely change if window is moved or resized)
      "item_info":  [Optional] Python dictionary (macOS) / MENUITEMINFO struct (Windows)
      "shortcut":   shortcut to menu item, if any (macOS: only if item_info is included)
      "entries":    sub-items within the sub-menu (or not present otherwise)
                    these sub-items will have this very same format, in a nested struct.

Note not all windows/applications will have a menu accessible by these methods.

## Install <a name="install"></a>

To install this module on your system, you can use pip: 

    pip3 install pywinctl

or

    python3 -m pip install pywinctl

Alternatively, you can download the wheel file (.whl) available in the [Download page](https://pypi.org/project/PyWinCtl/#files) and run this (don't forget to replace 'x.xx' with proper version number):

    pip install PyWinCtl-x.xx-py3-none-any.whl

You may want to add `--force-reinstall` option to be sure you are installing the right dependencies version.

Then, you can use it on your own projects just importing it:

    import pywinctl as pwc

## Support <a name="support"></a>

In case you have a problem, comments or suggestions, do not hesitate to [open issues](https://github.com/Kalmat/PyWinCtl/issues) on the [project homepage](https://github.com/Kalmat/PyWinCtl)

## Using this code <a name="using"></a>

If you want to use this code or contribute, you can either:

* Create a fork of the [repository](https://github.com/Kalmat/PyWinCtl), or 
* [Download the repository](https://github.com/Kalmat/PyWinCtl/archive/refs/heads/master.zip), uncompress, and open it on your IDE of choice (e.g. PyCharm)

Be sure you install all dependencies described on "requirements.txt" by using pip

## Test <a name="test"></a>

To test this module on your own system, cd to "tests" folder and run:

    python3 test_pywinctl.py

