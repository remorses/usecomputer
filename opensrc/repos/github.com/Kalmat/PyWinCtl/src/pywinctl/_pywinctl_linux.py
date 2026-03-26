#!/usr/bin/python
# -*- coding: utf-8 -*-
from __future__ import annotations

import sys
assert sys.platform == "linux"

import json
import os
import platform
import re
import subprocess
import time
from typing import cast, Optional, Union, List, Tuple

import Xlib.display
import Xlib.error
import Xlib.protocol
import Xlib.X
import Xlib.Xatom
import Xlib.Xutil
import Xlib.ext
from Xlib.xobject.drawable import Window as XWindow

from ._main import BaseWindow, Re, _WatchDog, _findMonitorName, _WINDATA, _WINDICT
from ewmhlib import EwmhWindow, EwmhRoot, defaultEwmhRoot, Props
from ewmhlib._ewmhlib import _xlibGetAllWindows

from pywinbox import Size, Point, Rect, pointInBox

# WARNING: Changes are not immediately applied, specially for hide/show (unmap/map)
#          You may set wait to True in case you need to effectively know if/when change has been applied.
WAIT_ATTEMPTS = 10
WAIT_DELAY = 0.025  # Will be progressively increased on every retry


def checkPermissions(activate: bool = False) -> bool:
    """
    macOS ONLY: Check Apple Script permissions for current script/app and, optionally, shows a
    warning dialog and opens security preferences

    :param activate: If ''True'' and if permissions are not granted, shows a dialog and opens security preferences.
                     Defaults to ''False''
    :return: returns ''True'' if permissions are already granted or platform is not macOS
    """
    return True


def getActiveWindow() -> Optional[LinuxWindow]:
    """
    Get the currently active (focused) Window in default root

    WAYLAND
    This will not work on Wayland unless you activate unsafe_mode:
       - Press alt + f2
       - write "lg" (without the quotation marks) and press Enter
       - In the command entry box (at the bottom of the window), write "global.context.unsafe_mode = true" (without the quotation marks) and press Enter
       - To exit the "lg" program, click on any of the options in the upper right corner, then press Escape (it seems a lg bug!)
       - You can set unsafe_mode off again by following the same steps, but in this case, using "global.context.unsafe_mode = false"
    Anyway, it will not work with all windows (especially built-in/"official" apps do not populate xid nor X-Window object)

    :return: Window object or None
    """
    # Wayland doesn't seem to have a way to get the active window or the list of open windows
    # This alternative partially works, but will require to enable unsafe_mode (on newer versions,
    # this is not possible from command-line nor using any gnome-shell extension, so it has to be done manually)
    # https://unix.stackexchange.com/questions/399753/how-to-get-a-list-of-active-windows-when-using-wayland
    # https://stackoverflow.com/questions/45465016/how-do-i-get-the-active-window-on-gnome-wayland
    # https://askubuntu.com/questions/1412130/dbus-calls-to-gnome-shell-dont-work-under-ubuntu-22-04
    # https://stackoverflow.com/questions/48797323/retrieving-active-window-from-mutter-on-gnome-wayland-session
    # https://discourse.gnome.org/t/get-window-id-of-a-window-object-window-get-xwindow-doesnt-exist/10956/3
    # https://www.reddit.com/r/gnome/comments/d8x27b/is_there_a_program_that_can_show_keypresses_on/
    win_id: Union[str, int] = 0
    if os.environ.get('XDG_SESSION_TYPE', '').lower() == "wayland":
        # IN SWAY: swaymsg -t get_tree | jq '.. | select(.type?) | select(.focused==true).pid'
        # pynput / mouse --> Not working (no global events allowed, only application events)
        _, activeWindow = _WgetAllWindows()
        if activeWindow:
            win_id = str(activeWindow["id"])
    if not win_id:
        win_id = defaultEwmhRoot.getActiveWindow()
    if win_id:
        return LinuxWindow(win_id)
    return None


def getActiveWindowTitle():
    """
    Get the title of the currently active (focused) Window

    :return: window title as string or empty
    """
    win = getActiveWindow()
    if win:
        return win.title
    else:
        return ""


def getAllWindows():
    """
    Get the list of Window objects for all visible windows in default root

    WAYLAND
    This will not work on Wayland unless you activate unsafe_mode:
       - Press alt + f2
       - write "lg" (without the quotation marks) and press Enter
       - In the command entry box (at the bottom of the window), write "global.context.unsafe_mode = true" (without the quotation marks) and press Enter
       - To exit the "lg" program, click on any of the options in the upper right corner, then press Escape (it seems a lg bug!)
       - You can set unsafe_mode off again by following the same steps, but in this case, using "global.context.unsafe_mode = false"
    Anyway, it will not work with all windows (especially built-in/"official" apps do not populate xid nor X-Window object)

    :return: list of Window objects
    """
    if os.environ.get('XDG_SESSION_TYPE', '').lower() == "wayland":
        windowsList, _ = _WgetAllWindows()
        windows = [str(win["id"]) for win in windowsList]
    else:
        windows = defaultEwmhRoot.getClientListStacking()
    return __remove_bad_windows(windows)


def getAllTitles() -> List[str]:
    """
    Get the list of titles of all visible windows

    :return: list of titles as strings
    """
    return [window.title for window in getAllWindows()]


def getWindowsWithTitle(title: Union[str, re.Pattern[str]], app: Optional[Tuple[str, ...]] = (), condition: int = Re.IS, flags: int = 0):
    """
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

    :param title: title or regex pattern to match, as string
    :param app: (optional) tuple of app names. Defaults to ALL (empty list)
    :param condition: (optional) condition to apply when searching the window. Defaults to ''Re.IS'' (is equal to)
    :param flags: (optional) specific flags to apply to condition. Defaults to 0 (no flags)
    :return: list of Window objects
    """
    matches: List[LinuxWindow] = []
    if title and condition in Re._cond_dic:
        lower = False
        if condition in (Re.MATCH, Re.NOTMATCH):
            title = re.compile(title, flags)
        elif condition in (Re.EDITDISTANCE, Re.DIFFRATIO):
            if not isinstance(flags, int) or not (0 < flags <= 100):
                flags = 90
        elif flags == Re.IGNORECASE:
            lower = True
            if isinstance(title, re.Pattern):
                title = title.pattern
            else:
                title = title.lower()
        for win in getAllWindows():
            if win.title and Re._cond_dic[condition](title, win.title.lower() if lower else win.title, flags)  \
                    and (not app or (app and win.getAppName() in app)):
                matches.append(win)
    return matches


def getAllAppsNames() -> List[str]:
    """
    Get the list of names of all visible apps

    :return: list of names as strings
    """
    return list(getAllAppsWindowsTitles())


def getAppsWithName(name: Union[str, re.Pattern[str]], condition: int = Re.IS, flags: int = 0):
    """
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

    :param name: name or regex pattern to match, as string
    :param condition: (optional) condition to apply when searching the app. Defaults to ''Re.IS'' (is equal to)
    :param flags: (optional) specific flags to apply to condition. Defaults to 0 (no flags)
    :return: list of app names
    """
    matches: List[str] = []
    if name and condition in Re._cond_dic:
        lower = False
        if condition in (Re.MATCH, Re.NOTMATCH):
            name = re.compile(name, flags)
        elif condition in (Re.EDITDISTANCE, Re.DIFFRATIO):
            if not isinstance(flags, int) or not (0 < flags <= 100):
                flags = 90
        elif flags == Re.IGNORECASE:
            lower = True
            if isinstance(name, re.Pattern):
                name = name.pattern
            else:
                name = name.lower()
        for title in getAllAppsNames():
            if title and Re._cond_dic[condition](name, title.lower() if lower else title, flags):
                matches.append(title)
    return matches


def _getAllApps():
    cmd = "ps -A | awk '{ print $2, $11 }'"
    proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if not stderr:
        procs = stdout.decode(encoding="utf8").split("\n")[1:]
        result = []
        for item in procs:
            if item:
                part = item.split(" ")
                result.append([int(part[0]), part[1]])
        return result
    return []


def getAllAppsWindowsTitles():
    """
    Get all visible apps names and their open windows titles

    Format:
        Key: app name

        Values: list of window titles as strings

    :return: python dictionary
    """
    result: dict[str, List[str]] = {}
    for win in getAllWindows():
        appName = win.getAppName()
        if appName in result.keys():
            result[appName].append(win.title)
        else:
            result[appName] = [win.title]
    return result


def getAllWindowsDict(tryToFilter: bool = False) -> dict[str, _WINDICT]:
    """
    Get all visible apps and windows info

    Format:
        Key: app name

        Values:
            "pid": app PID
            "windows": subdictionary of all app windows
                "title": subdictionary of window info
                    "id": window handle
                    "display": display in which window is mostly visible
                    "position": window position (x, y) within display
                    "size": window size (width, height)
                    "status": 0 - normal, 1 - minimized, 2 - maximized

    :param tryToFilter: Windows ONLY. Set to ''True'' to try to get User (non-system) apps only (may skip real user apps)
    :return: python dictionary
    """
    result: dict[str, _WINDICT] = {}
    for win in getAllWindows():
        winId = win.getHandle()
        appName = win.getAppName()
        appPID = win._win.getPid()
        status = 0
        if win.isMinimized:
            status = 1
        elif win.isMaximized:
            status = 2
        pos = win.position
        size = win.size
        winDict: _WINDATA = {
            "id": winId,
            "display": win.getDisplay(),
            "position": (pos.x, pos.y),
            "size": (size.width, size.height),
            "status": status
        }
        if appName not in result.keys():
            result[appName] = {"pid": appPID, "windows": {}}
        result[appName]["windows"][win.title] = winDict
    return result


def getWindowsAt(x: int, y: int):
    """
    Get the list of Window objects whose windows contain the point ``(x, y)`` on screen

    :param x: X screen coordinate of the window(s)
    :param y: Y screen coordinate of the window(s)
    :return: list of Window objects
    """
    windowBoxGenerator = ((window, window.box) for window in getAllWindows())
    return [
        window for (window, box)
        in windowBoxGenerator
        if pointInBox(x, y, box)]


def getTopWindowAt(x: int, y: int):
    """
    Get the Window object at the top of the stack at the point ``(x, y)`` on screen

    :param x: X screen coordinate of the window
    :param y: Y screen coordinate of the window
    :return: Window object or None
    """
    windows: List[LinuxWindow] = getAllWindows()
    for window in reversed(windows):
        if pointInBox(x, y, window.box):
            return window
    else:
        return None


def _WgetAllWindows() -> Tuple[List[dict[str, Union[str, bool]]], dict[str, Union[str, bool]]]:
    # POSSIBLE REFERENCE: https://www.roojs.org/seed/gir-1.2-gtk-3.0/seed/Meta.Window.html
    # Built-in / official apps (e.g. Terminal or gedit) do not fulfill proper get_description() to get the Xid
    windowsList: List[dict[str, Union[str, bool]]] = [{}]
    activeWindow: dict[str, Union[str, bool]] = {}
    cmd = ('gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell '
           '--method org.gnome.Shell.Eval "global.get_window_actors()'
           '.map(a=>a.meta_window)'
           '.map(w=>({class: w.get_wm_class(), title: w.get_title(), active: w.has_focus(), id: w.get_description(), id2: w.get_id(), id3: w.get_pid()}))"')
    ret = subprocess.check_output(cmd, shell=True, timeout=1).decode("utf-8").replace("\n", "")
    if ret and ret.startswith("(true, "):
        windows: List[str] = (str(ret[8:-2]).replace("[", "").replace("]", "").replace("},{", "}|&|{").split("|&|"))
        for window in windows:
            output: dict[str, Union[str, bool]] = json.loads(window)
            if str(output.get("id", "")).startswith("0x"):
                windowsList.append(output)
                if output.get("active", False):
                    activeWindow = output
    return windowsList, activeWindow


def __remove_bad_windows(windows: Optional[Union[List[str], List[int]]]) -> List[LinuxWindow]:
    outList = []
    if windows is not None:
        for window in windows:
            try:
                # Thanks to Seraphli (https://github.com/Seraphli) for pointing out this issue!
                if window: outList.append(LinuxWindow(window))
            except:
                pass
    return outList


class LinuxWindow(BaseWindow):

    def __init__(self, hWnd: Union[XWindow, int, str]):
        super().__init__(hWnd)

        if isinstance(hWnd, XWindow):
            self._hWnd = hWnd.id
        elif isinstance(hWnd, str):
            self._hWnd = int(hWnd, base=16)
        else:
            self._hWnd = int(hWnd)
        self._win = EwmhWindow(self._hWnd)
        self._display: Xlib.display.Display = self._win.display
        self._rootWin: EwmhRoot = self._win.ewmhRoot
        self._xWin: XWindow = self._win.xWindow
        self.watchdog = _WatchDog(self)

        self._currDesktop = os.environ.get('XDG_CURRENT_DESKTOP', "").lower()
        self._currSessionType = os.environ.get('XDG_SESSION_TYPE', "").lower()
        self._motifHints: List[int] = []

    def getExtraFrameSize(self, includeBorder: bool = True) -> Tuple[int, int, int, int]:
        """
        Get the extra space, in pixels, around the window, including or not the border.
        Notice not all applications/windows will use this property values

        :param includeBorder: set to ''False'' to avoid including borders
        :return: additional frame size in pixels, as a tuple of int (left, top, right, bottom)
        """
        ret: Tuple[int, int, int, int] = (0, 0, 0, 0)
        borderWidth = 0
        if includeBorder:
            geom = self._xWin.get_geometry()
            borderWidth = geom.border_width
        if "gnome" in self._currDesktop:
            _gtk_extents: List[int] = self._win._getGtkFrameExtents()
            if _gtk_extents and len(_gtk_extents) >= 4:
                ret = (_gtk_extents[0] + borderWidth, _gtk_extents[2] + borderWidth,
                       _gtk_extents[1] + borderWidth, _gtk_extents[3] + borderWidth)
        else:
            # TODO: Check if this makes sense in other environments, then find a way to get these values
            pass
        return ret

    def getClientFrame(self) -> Rect:
        """
        Get the client area of window including scroll, menu and status bars, as a Rect (x, y, right, bottom)
        Notice that this method won't match non-standard window decoration sizes

        :return: Rect struct
        """
        x, y, w, h = self.box
        # Thanks to roym899 (https://github.com/roym899) for his HELP!!!!
        _net_extents = self._win._getNetFrameExtents()
        if _net_extents and len(_net_extents) >= 4:
            x += int(_net_extents[0])
            y += int(_net_extents[2])
            w -= (int(_net_extents[0]) + int(_net_extents[1]))
            h -= (int(_net_extents[2]) + int(_net_extents[3]))
        else:
            # TODO: Find a way to get window title and borders sizes in GNOME
            #       (not setting _NET_EXTENTS, but _GTK_EXTENTS, containing space AROUND window)
            # Don't add / subtract anything to avoid missing window parts, since it's adjusted in PyWinBox
            pass
        ret = Rect(x, y, x + w, y + h)
        return ret

    def __repr__(self):
        return '%s(hWnd=%s)' % (self.__class__.__name__, self._hWnd)

    def __eq__(self, other: object) -> bool:
        return isinstance(other, LinuxWindow) and self._hWnd == other._hWnd

    def close(self) -> bool:
        """
        Closes this window. This may trigger "Are you sure you want to
        quit?" dialogs or other actions that prevent the window from
        actually closing. This is identical to clicking the X button on the
        window.

        :return: ''True'' if window is closed
        """
        self._win.setClosed()
        ids = [w._hWnd for w in getAllWindows()]
        return self._hWnd not in ids

    def minimize(self, wait: bool = False) -> bool:
        """
        Minimizes this window

        :param wait: set to ''True'' to confirm action requested (in a reasonable time)
        :return: ''True'' if window minimized
        """
        if not self.isMinimized:
            self._win.setMinimized()
            retries = 0
            while wait and retries < WAIT_ATTEMPTS and not self.isMinimized:
                retries += 1
                time.sleep(WAIT_DELAY * retries)
        return self.isMinimized

    def maximize(self, wait: bool = False) -> bool:
        """
        Maximizes this window

        :param wait: set to ''True'' to confirm action requested (in a reasonable time)
        :return: ''True'' if window maximized
        """
        if not self.isMaximized:
            self._win.setMaximized(True, True)
            retries = 0
            while wait and retries < WAIT_ATTEMPTS and not self.isMaximized:
                retries += 1
                time.sleep(WAIT_DELAY * retries)
        return self.isMaximized

    def restore(self, wait: bool = False, user: bool = True) -> bool:
        """
        If maximized or minimized, restores the window to its normal size

        :param wait: set to ''True'' to confirm action requested (in a reasonable time)
        :param user: ignored on Windows platform
        :return: ''True'' if window restored
        """
        if self.isMaximized:
            self._win.changeWmState(Props.StateAction.REMOVE, Props.State.MAXIMIZED_HORZ, Props.State.MAXIMIZED_VERT)
        self.activate()
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and (self.isMaximized or self.isMinimized):
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return bool(not self.isMaximized and not self.isMinimized)

    def show(self, wait: bool = False) -> bool:
        """
        If hidden or showing, shows the window on screen and in title bar

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window showed
        """
        self._xWin.map()
        self._xWin.map_sub_windows()
        self._display.flush()
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and not self._isMapped:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return self._isMapped

    def hide(self, wait: bool = False) -> bool:
        """
        If hidden or showing, hides the window from screen and title bar

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window hidden
        """
        self._xWin.unmap_sub_windows()
        self._xWin.unmap()
        self._display.flush()
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and self._isMapped:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return not self._isMapped

    def activate(self, wait: bool = False, user: bool = True) -> bool:
        """
        Activate this window and make it the foreground (focused) window

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :param user: ''True'' indicates a direct user request, as required by some WMs to comply.
        :return: ''True'' if window activated
        """
        if "arm" in platform.platform():
            self._win.changeWmState(Props.StateAction.REMOVE, Props.State.ABOVE)
            self._win.changeWmState(Props.StateAction.ADD, Props.State.ABOVE, Props.State.FOCUSED)
        else:
            # This was not working as expected in Unity
            # Thanks to MestreLion (https://github.com/MestreLion) for his solution!!!!
            self._win.setActive(user)
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and not self.isActive:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return bool(self.isActive)

    def resize(self, widthOffset: int, heightOffset: int, wait: bool = False):
        """
        Resizes the window relative to its current size

        :param widthOffset: offset to add to current window width as target width
        :param heightOffset: offset to add to current window height as target height
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window resized to the given size
        """
        box = self.box
        return self.resizeTo(box.width + widthOffset, box.height + heightOffset, wait)

    resizeRel = resize  # resizeRel is an alias for the resize() method.

    def resizeTo(self, newWidth: int, newHeight: int, wait: bool = False):
        """
        Resizes the window to a new width and height

        :param newWidth: target window width
        :param newHeight: target window height
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window resized to the given size
        """
        self.size = Size(newWidth, newHeight)
        box = self.box
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and (box.width != newWidth or box.height != newHeight):
            retries += 1
            time.sleep(WAIT_DELAY * retries)
            box = self.box
        return box.width == newWidth and box.height == newHeight

    def move(self, xOffset: int, yOffset: int, wait: bool = False):
        """
        Moves the window relative to its current position

        :param xOffset: offset relative to current X coordinate to move the window to
        :param yOffset: offset relative to current Y coordinate to move the window to
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window moved to the given position
        """
        box = self.box
        newLeft = max(0, box.left + xOffset)  # Xlib won't accept negative positions
        newTop = max(0, box.top + yOffset)
        return self.moveTo(newLeft, newTop, wait)

    moveRel = move  # moveRel is an alias for the move() method.

    def moveTo(self, newLeft: int, newTop: int, wait: bool = False):
        """
        Moves the window to new coordinates on the screen

        :param newLeft: target X coordinate to move the window to
        :param newTop: target Y coordinate to move the window to
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window moved to the given position
        """
        newLeft = max(0, newLeft)  # Xlib won't accept negative positions
        newTop = max(0, newTop)
        self.topleft = Point(newLeft, newTop)
        box = self.box
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and (box.left != newLeft or box.top != newTop):
            retries += 1
            time.sleep(WAIT_DELAY * retries)
            box = self.box
        return box.left == newLeft and box.top == newTop

    def alwaysOnTop(self, aot: bool = True) -> bool:
        """
        Keeps window on top of all others.

        :param aot: set to ''False'' to deactivate always-on-top behavior
        :return: ''True'' if command succeeded
        """
        action = Props.StateAction.ADD if aot else Props.StateAction.REMOVE
        self._win.changeWmState(action, Props.State.ABOVE)
        states = self._win.getWmState(True)
        return bool(states and Props.State.ABOVE in states)

    def alwaysOnBottom(self, aob: bool = True) -> bool:
        """
        Keeps window below of all others, but on top of desktop icons and keeping all window properties

        :param aob: set to ''False'' to deactivate always-on-bottom behavior
        :return: ''True'' if command succeeded
        """
        action = Props.StateAction.ADD if aob else Props.StateAction.REMOVE
        self._win.changeWmState(action, Props.State.BELOW)
        states = self._win.getWmState(True)
        return bool(states and Props.State.BELOW in states)

    def lowerWindow(self) -> bool:
        """
        Lowers the window to the bottom so that it does not obscure any sibling windows

        :return: ''True'' if window lowered
        """
        self._xWin.configure(stack_mode=Xlib.X.Below)
        windows = self._rootWin.getClientListStacking()
        return bool(windows and self._hWnd == windows[-1])

    def raiseWindow(self) -> bool:
        """
        Raises the window to top so that it is not obscured by any sibling windows.

        :return: ''True'' if window raised
        """
        self._xWin.configure(stack_mode=Xlib.X.Above)
        windows = self._rootWin.getClientListStacking()
        return bool(windows and self._hWnd == windows[0])

    def sendBehind(self, sb: bool = True) -> bool:
        """
        Sends the window to the very bottom, below all other windows, including desktop icons.
        It may also cause that the window does not accept focus nor keyboard/mouse events as well as
        make the window disappear from taskbar and/or pager.

        :param sb: set to ''False'' to bring the window back to front
        :return: ''True'' if window sent behind desktop icons

        Notes:
            - On GNOME it will obscure desktop icons... by the moment
        """
        if sb:
            # This sends window below all others, but not behind the desktop icons
            self._win.setWmWindowType(Props.WindowType.DESKTOP)

            # This will try to raise the desktop icons layer on top of the window
            # Ubuntu: "@!0,0;BDHF" is the new desktop icons NG extension on Ubuntu 22.04
            # Mint: "Desktop" title is language-dependent. Using its class instead
            # KDE: desktop and icons seem to be the same window. Likely it's not possible to place a window in between
            # TODO: Test / find in other OS
            desktop = _xlibGetAllWindows(title="@!0,0;BDHF", klass=('nemo-desktop', 'Nemo-desktop'))
            self.lowerWindow()
            for d in desktop:
                w: XWindow = self._display.create_resource_object('window', d.id)
                w.raise_window()
                self._display.flush()
            types = self._win.getWmWindowType(True)
            return bool(types and Props.WindowType.DESKTOP in types)

        else:
            self._win.setWmWindowType(Props.WindowType.NORMAL)
            types = self._win.getWmWindowType(True)
            return bool(types and Props.WindowType.NORMAL in types and self.isActive)

    def acceptInput(self, setTo: bool):
        """
        Toggles the window to accept input and focus

        :param setTo: True/False to toggle window ignoring input and focus
        :return: None
        """
        # TODO: Is it possible to make the window completely transparent to input (click-thru) in GNOME?
        if setTo:

            if "gnome" in self._currDesktop:

                self._win.changeWmState(Props.StateAction.REMOVE, Props.State.BELOW)

                onebyte = int(0xFF)
                fourbytes = onebyte | (onebyte << 8) | (onebyte << 16) | (onebyte << 24)
                self._win.changeProperty("_NET_WM_WINDOW_OPACITY", [fourbytes], Xlib.Xatom.CARDINAL)

                if self._motifHints:
                    self._win.changeProperty("_MOTIF_WM_HINTS", self._motifHints)

            self._win.setWmWindowType(Props.WindowType.NORMAL)

        else:

            if "gnome" in self._currDesktop:

                self._win.changeWmState(Props.StateAction.ADD, Props.State.BELOW)

                onebyte = int(0xFA)  # Calculate as 0xff * target_opacity
                fourbytes = onebyte | (onebyte << 8) | (onebyte << 16) | (onebyte << 24)
                self._win.changeProperty("_NET_WM_WINDOW_OPACITY", [fourbytes], Xlib.Xatom.CARDINAL)

                ret = self._win.getProperty("_MOTIF_WM_HINTS")
                # Cinnamon uses this as default: [2, 1, 1, 0, 0]
                self._motifHints = [a for a in ret.value] if ret and hasattr(ret, "value") else [2, 0, 0, 0, 0]
                self._win.changeProperty("_MOTIF_WM_HINTS", [0, 0, 0, 0, 0])

            self._win.setWmWindowType(Props.WindowType.DESKTOP)

    def getAppName(self) -> str:
        """
        Get the name of the app current window belongs to

        :return: name of the app as string
        """
        pid = self._win.getPid()
        if pid != 0:
            proc = subprocess.Popen(f"ps -q {pid} -o comm=", shell=True, stdout=subprocess.PIPE)
            stdout, stderr = proc.communicate()
            name = stdout.decode(encoding="utf8").replace("\n", "")
        else:
            name = ""
        return name

    def getParent(self) -> int:
        """
        Get the handle of the current window parent. It can be another window or an application

        :return: handle of the window parent
        """
        return int(self._xWin.query_tree().parent.id)

    def setParent(self, parent: int) -> bool:
        """
        Current window will become child of given parent
        WARNING: Not implemented in AppleScript (not possible in macOS for foreign - other apps' - windows)

        :param parent: window to set as current window parent
        :return: ''True'' if current window is now child of given parent
        """
        self._xWin.reparent(parent, 0, 0)
        return bool(self.isChild(parent))

    def getChildren(self) -> List[int]:
        """
        Get the children handles of current window

        :return: list of handles
        """
        return cast(List[int], self._xWin.query_tree().children)

    def getHandle(self) -> int:
        """
        Get the current window handle

        :return: window handle
        """
        return self._hWnd

    def getPID(self) -> Optional[int]:
        """
        Get the current application PID the window belongs to

        :return: application PID or None if it couldn't be retrieved
        """
        return self._win.getPid()

    def isParent(self, child: int) -> bool:
        """Returns ''True'' if the window is parent of the given window as input argument

        :param child: handle of the window you want to check if the current window is parent of
        """
        win = self._display.create_resource_object('window', child)
        return bool(win.query_tree().parent.id == self._hWnd)
    isParentOf = isParent  # isParentOf is an alias of isParent method

    def isChild(self, parent: int):
        """
        Check if current window is child of given window/app (handle)

        On Windows, the list will contain up to one display (displays can not overlap), whilst in Linux and macOS, the
        list may contain several displays.

        :param parent: handle of the window/app you want to check if the current window is child of
        :return: ''True'' if current window is child of the given window
        """
        return bool(parent == self.getParent())
    isChildOf = isChild  # isChildOf is an alias of isParent method

    def getDisplay(self) -> List[str]:
        """
        Get display names in which current window space is mostly visible

        On Windows, the list will contain up to one display (displays can not overlap), whilst in Linux and macOS, the
        list may contain several displays.

        If you need to get info or control the monitor, use these names as input to PyMonCtl's findMonitorWithName().

        :return: display name as list of strings or empty (couldn't retrieve it or window is off-screen)
        """
        x, y = self.center
        return _findMonitorName(x, y)
    getMonitor = getDisplay  # getMonitor is an alias of getDisplay method

    @property
    def isMinimized(self) -> bool:
        """
        Check if current window is currently minimized

        :return: ``True`` if the window is minimized
        """
        state = self._win.getWmState(True)
        return bool(state and Props.State.HIDDEN in state)

    @property
    def isMaximized(self) -> bool:
        """
        Check if current window is currently maximized

        :return: ``True`` if the window is maximized
        """
        state = self._win.getWmState(True)
        return bool(state and Props.State.MAXIMIZED_HORZ in state and Props.State.MAXIMIZED_VERT in state)

    @property
    def isActive(self):
        """
        Check if current window is currently the active, foreground window

        :return: ``True`` if the window is the active, foreground window
        """
        win = getActiveWindow()
        return bool(win and win.getHandle() == self._hWnd)

    @property
    def title(self) -> str:
        """
        Get the current window title, as string

        :return: title as a string
        """
        name: Union[str, bytes] = self._win.getName()
        if isinstance(name, bytes):
            name = name.decode()
        return name

    @property
    def visible(self) -> bool:
        """
        Check if current window is visible (minimized windows are also visible)

        :return: ``True`` if the window is currently visible
        """
        state: int = self._xWin.get_attributes().map_state
        return bool(state == Xlib.X.IsViewable)

    isVisible: bool = cast(bool, visible)  # isVisible is an alias for the visible property.

    @property
    def isAlive(self) -> bool:
        """
        Check if window (and application) still exists (minimized and hidden windows are included as existing)

        :return: ''True'' if window exists
        """
        try:
            state: int = self._xWin.get_attributes().map_state
        except Xlib.error.BadWindow:
            return False
        else:
            return True

    # @property
    # def isAlerting(self) -> bool:
    #     """Check if window is flashing/bouncing/demanding attetion on taskbar while demanding user attention
    #
    #     :return:  ''True'' if window is demanding attention
    #     """
    #     return bool(STATE_ATTENTION in self._windowWrapper.getWmState())

    @property
    def _isMapped(self) -> bool:
        # Returns ``True`` if the window is currently mapped
        state: int = self._xWin.get_attributes().map_state
        return bool(state != Xlib.X.IsUnmapped)
