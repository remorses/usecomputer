#!/usr/bin/python
# -*- coding: utf-8 -*-
# Incomplete type stubs for pyobjc
# mypy: disable_error_code = no-any-return
from __future__ import annotations

import sys
assert sys.platform == "darwin"

import ast
import difflib
import platform
import re
import subprocess
import threading
import time
from collections.abc import Iterable
from typing import Any, cast, Sequence, Dict, Optional, Union, List, Tuple
from typing_extensions import TypeAlias, TypedDict, Literal

import AppKit
import Quartz

from ._main import BaseWindow, Re, _WatchDog, _findMonitorName, _WINDATA, _WINDICT
from pywinbox import Size, Point, Rect, pointInBox


Incomplete: TypeAlias = Any
Attribute: TypeAlias = Sequence['Tuple[str, str, bool, str]']

WAIT_ATTEMPTS = 10
WAIT_DELAY = 0.025  # Will be progressively increased on every retry


def checkPermissions(activate: bool = False) -> bool:
    """
    macOS ONLY: Check Apple Script permissions for current script/app and, optionally, shows a
    warning dialog and opens security preferences

    :param activate: If ''True'' and if permissions are not granted, shows a dialog and opens security preferences.
                     Defaults to ''False''
    :return: ''True'' if permissions are already granted or platform is not macOS
    """
    # https://stackoverflow.com/questions/26591560/how-to-grant-applescript-permissions-through-applescript
    if activate:
        cmd = """tell application "System Events"
                    set UI_enabled to UI elements enabled
                end tell
                if UI_enabled is false then
                    display dialog "This script requires Accessibility permissions" & return & return & "You can activate GUI Scripting by selecting the checkbox Enable access for assistive devices in the Security and Privacy > Accessibility preferences" with icon 1 buttons {"Ok"} default button 1
                    tell application "System Preferences"
                        activate
                        set current pane to pane id "com.apple.preference.security"
                    end tell
                end if
                return UI_enabled"""
    else:
        cmd = """tell application "System Events"
                    set UI_enabled to UI elements enabled
                end tell
                return UI_enabled"""
    proc = subprocess.Popen(['osascript'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
    ret, err = proc.communicate(cmd)
    ret = ret.replace("\n", "")
    return ret == "true"


def getActiveWindow() -> Optional[MacOSWindow]:
    """
    Get the currently active (focused) Window

    :return: Window object or None
    """
    # app = AppKit.NSWorkspace.sharedWorkspace().frontmostApplication()   # This fails after using .activateWithOptions_()?!?!?!
    cmd = """on run
                set appName to ""
                set appID to ""
                set winName to ""
                try
                    tell application "System Events"
                        set frontApp to first application process whose frontmost is true
                        set frontAppName to name of frontApp
                        set appID to unix id of frontApp
                        tell process frontAppName
                            set winName to value of attribute "AXTitle" of (1st window whose value of attribute "AXMain" is true)
                        end tell
                    end tell
                end try
                return {appID, winName}
            end run"""
    proc = subprocess.Popen(['osascript'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
    ret, err = proc.communicate(cmd)
    entries = ret.replace("\n", "").split(", ")
    appID = entries[0]
    # Thanks to Anthony Molinaro (djnym) for pointing out this bug and provide the solution!!!
    # sometimes the title of the window contains ',' characters, so just get the first entry as the appName and
    # join the rest back together as a string
    title = ", ".join(entries[1:])
    if appID:  # and title:
        activeApps = _getAllApps()
        for a in activeApps:
            if str(a.processIdentifier()) == appID:
                return MacOSWindow(a, title)
    return None


def getActiveWindowTitle() -> str:
    """
    Get the title of the currently active (focused) Window

    :return: window title as string or empty
    """
    win = getActiveWindow()
    if win:
        return win.title or ""
    else:
        return ""


def getAllWindows() -> List[MacOSWindow]:
    """
    Get the list of Window objects for all visible windows

    :return: list of Window objects
    """
    # TODO: Find a way to return windows as per the stacking order (not sure if it is even possible!)
    windows: List[MacOSWindow] = []
    activeApps = _getAllApps()
    titleList = _getWindowTitles()
    for item in titleList:
        try:
            pID = item[0]
            title = item[1]
        except:
            continue
        for activeApp in activeApps:
            if activeApp.processIdentifier() == pID:
                windows.append(MacOSWindow(activeApp, title))
                break
    return windows


def getAllTitles() -> List[str]:
    """
    Get the list of titles of all visible windows

    :return: list of titles as strings
    """
    cmd = """osascript -s 's' -e 'tell application "System Events"
                                set winNames to {}
                                try
                                    set winNames to {name of every window} of (every process whose background only is false)
                                end try
                            end tell
                            return winNames'"""
    ret = subprocess.check_output(cmd, shell=True).decode(encoding="utf-8").replace("\n", "") \
        .replace('missing value', '"missing value"') \
        .replace("{", "[").replace("}", "]")
    res = ast.literal_eval(ret)
    matches: List[str] = []
    if len(res) > 0:
        for item in res[0]:
            for title in item:
                matches.append(title)
    return matches


def getWindowsWithTitle(title: Union[str, re.Pattern[str]], condition: int = Re.IS, flags: int = 0) -> List[MacOSWindow]:
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
    :param condition: (optional) condition to apply when searching the window. Defaults to ''Re.IS'' (is equal to)
    :param flags: (optional) specific flags to apply to condition. Defaults to 0 (no flags)
    :return: list of Window objects
    """

    if not (title and condition in Re._cond_dic):
        return []  # pyright: ignore[reportUnknownVariableType]  # Type doesn't matter here

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
        title = title.lower()

    matches: List[MacOSWindow] = []
    activeApps = _getAllApps()
    titleList = _getWindowTitles()
    for item in titleList:
        pID = item[0]
        winTitle = item[1].lower() if lower else item[1]
        if winTitle and Re._cond_dic[condition](title, winTitle, flags):
            for a in activeApps:
                if a.processIdentifier() == pID:
                    matches.append(MacOSWindow(a, item[1]))
                    break
    return matches


def getAllAppsNames() -> List[str]:
    """
    Get the list of names of all visible apps

    :return: list of names as strings
    """
    cmd = """osascript -s 's' -e 'tell application "System Events"
                                    set winNames to {}
                                    try
                                        set winNames to name of every process whose background only is false
                                    end try
                                end tell
                                return winNames'"""
    ret = subprocess.check_output(cmd, shell=True).decode(encoding="utf-8").replace("\n", "") \
        .replace('missing value', '"missing value"') \
        .replace("{", "[").replace("}", "]")
    res = ast.literal_eval(ret)
    return res or []


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
            name = name.lower()
        for title in getAllAppsNames():
            if title and Re._cond_dic[condition](name, title.lower() if lower else title, flags):
                matches.append(title)
    return matches


def getAllAppsWindowsTitles():
    """
    Get all visible apps names and their open windows titles

    Format:
        Key: app name

        Values: list of window titles as strings

    :return: python dictionary
    """
    cmd = """osascript -s 's' -e 'tell application "System Events"
                                    set winNames to {}
                                    try
                                        set winNames to {name, (name of every window)} of (every process whose background only is false)
                                    end try
                                end tell
                                return winNames'"""
    ret = subprocess.check_output(cmd, shell=True).decode(encoding="utf-8") \
        .replace('missing value', '"missing value"') \
        .replace("\n", "").replace("{", "[").replace("}", "]")
    res: Tuple[List[str], List[List[str]]] = ast.literal_eval(ret)
    result: dict[str, List[str]] = {}
    if res and len(res) > 0:
        for i, item in enumerate(res[0]):
            result[item] = res[1][i]
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
    windows = getAllWindows()
    cmd = """osascript -s 's' -e 'tell application "System Events"
                                    set winNames to {}
                                    try
                                        set winNames to {unix id, name, ({name, position, size} of every window)} of (every process whose background only is false)
                                    end try
                                end tell
                                return winNames'"""
    ret = subprocess.check_output(cmd, shell=True).decode(encoding="utf-8").replace("\n", "") \
        .replace('missing value', '"missing value"') \
        .replace("{", "[").replace("}", "]")
    res = ast.literal_eval(ret)
    result: dict[str, _WINDICT] = {}
    if len(res) > 0:
        pids = res[0]
        apps = res[1]
        winsData = res[2]
        for i, pID in enumerate(pids):
            appName = apps[i]
            titles = winsData[0][i]
            pos = winsData[1][i]
            sizes = winsData[2][i]
            for j, title in enumerate(titles):
                for win in windows:
                    if title == win.title:
                        winId = win.getHandle()
                        status = 0
                        if win.isMinimized:
                            status = 1
                        elif win.isMaximized:
                            status = 2
                        winDict: _WINDATA = {
                            "id": winId,
                            "display": win.getDisplay(),
                            "position": pos[j],
                            "size": sizes[j],
                            "status": status
                        }
                        if appName not in result.keys():
                            result[appName] = {"pid": pID, "windows": {}}
                        result[appName]["windows"][title] = winDict
                        break
    return result


def getWindowsAt(x: int, y: int, allWindows: Optional[List[MacOSWindow]] = None) -> List[MacOSWindow]:
    """
    Get the list of Window objects whose windows contain the point ``(x, y)`` on screen

    :param x: X screen coordinate of the window(s)
    :param y: Y screen coordinate of the window(s)
    :param allWindows: (optional) list of window objects (required to improve performance in Apple Script version)
    :return: list of Window objects
    """
    windows = allWindows if allWindows else getAllWindows()
    windowBoxGenerator = ((window, window.box) for window in windows)
    return [
        window for (window, box)
        in windowBoxGenerator
        if pointInBox(x, y, box)]


def getTopWindowAt(x: int, y: int, allWindows: Optional[List[MacOSWindow]] = None) -> Optional[MacOSWindow]:
    """
    Get *a* Window object at the point ``(x, y)`` on screen.
    Which window is not guaranteed. See https://github.com/Kalmat/PyWinCtl/issues/20#issuecomment-1193348238

    :param x: X screen coordinate of the window
    :param y: Y screen coordinate of the window
    :param allWindows: list of window objects previously obtained
    :return: Window object or None
    """
    # Once we've figured out why getWindowsAt may not always return all windows
    # (see https://github.com/Kalmat/PyWinCtl/issues/21),
    # we can look into a more efficient implementation that only gets a single window
    windows = getWindowsAt(x, y, allWindows)
    return None if len(windows) == 0 else windows[-1]


def _getAllApps(userOnly: bool = True):
    matches: List[AppKit.NSRunningApplication] = []
    for app in AppKit.NSWorkspace.sharedWorkspace().runningApplications():
        if not userOnly or (userOnly and app.activationPolicy() == Quartz.NSApplicationActivationPolicyRegular):
            matches.append(app)
    return matches


def _getAppWindowsTitles(app: AppKit.NSRunningApplication):
    pid: str = str(app.processIdentifier())
    cmd = """on run arg1
                set pid to arg1 as integer
                set winNames to {}
                try
                    tell application "System Events"
                        set proc to first process whose unix id is pid
                        tell proc to set winNames to name of every window
                    end tell
                end try
                return winNames
            end run"""
    proc = subprocess.Popen(['osascript', '-s', 's', '-', pid],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
    ret, err = proc.communicate(cmd)
    ret = ret.replace("\n", "").replace('missing value', '"missing value"').replace("{", "[").replace("}", "]")
    res = ast.literal_eval(ret)
    return res or []


def _getWindowTitles() -> List[List[str]]:
    # https://gist.github.com/qur2/5729056 - qur2
    cmd = """osascript -s 's' -e 'tell application "System Events"
                                    set winNames to {}
                                    try
                                        set winNames to {unix id, ({name, position, size} of (every window))} of (every process whose background only is false)
                                    end try
                                end tell
                                return winNames'"""
    ret = subprocess.check_output(cmd, shell=True).decode(encoding="utf-8").replace("\n", "") \
        .replace('missing value', '"missing value"') \
        .replace("{", "[").replace("}", "]")
    res = ast.literal_eval(ret)
    result: List[List[str]] = []
    if len(res) > 0:
        for i, pID in enumerate(res[0]):
            try:
                item = res[1][0][i]
                j = 0
                for title in item:  # One-liner script is way faster, but produces complex data structures
                    try:
                        pos = res[1][1][i][j]
                        size = res[1][2][i][j]
                        result.append([pID, title, pos, size])
                    except:
                        pass
                    j += 1
            except:
                pass
    return result


_ItemInfoValue = TypedDict("_ItemInfoValue", {"value": str, "class": str, "settable": bool})


class _SubMenuStructure(TypedDict, total=False):
    hSubMenu: int
    wID: int
    entries: dict[str, _SubMenuStructure]
    parent: int
    rect: Rect
    item_info: dict[str, _ItemInfoValue]
    shortcut: str


class MacOSWindow(BaseWindow):

    def __init__(self, app: AppKit.NSRunningApplication, title: str):
        super().__init__((app.localizedName(), title))

        self._app = app
        self._appPID: int = app.processIdentifier()
        self._appName: str = self.getProcName(self._appPID)
        if not self._appName:
            # localizedName() is not recognized in AppleScript for non-English languages
            self._appName = app.localizedName()
        self._initTitle: str = title
        self._winTitle: str = title
        # self._parent = self.getParent()  # It is slow and not required by now
        v = platform.mac_ver()[0].split(".")
        ver = float(v[0]+"."+v[1])
        # On Yosemite and below we need to use Zoom instead of FullScreen to maximize windows
        self._use_zoom = (ver <= 10.10)
        self._tt: Optional[_SendTop] = None
        self._kill_tt = threading.Event()
        self._tb: Optional[_SendBottom] = None
        self._kill_tb = threading.Event()
        self.menu = self._Menu(self)
        self.watchdog = _WatchDog(self)

    def getProcName(self, appPID):
        cmd = """on run {arg1}
                    set appID to arg1 as integer
                    set procName to ""
                    try
                        tell application "System Events"
                            set procName to name of first application process whose unix id is appID
                        end tell
                    end try
                    return procName
                end run"""
        proc = subprocess.Popen(['osascript', '-', str(appPID)],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        return str(ret.replace("\n", ""))

    def getExtraFrameSize(self, includeBorder: bool = True) -> Tuple[int, int, int, int]:
        """
        Get the invisible space, in pixels, around the window, including or not the visible resize border

        :param includeBorder: set to ''False'' to avoid including window border
        :return: (left, top, right, bottom) frame size as a tuple of int
        """
        return 0, 0, 0, 0

    def getClientFrame(self):
        """
        Get the client area of window including scroll, menu and status bars, as a Rect (x, y, right, bottom)
        Notice that this method won't match non-standard window decoration style sizes

        :return: Rect struct
        """
        # Many thanks to super-iby for this solution which allows using this function from non-main thread

        targetSelector = b'getTitleBarHeightAndBorderWidth'

        if hasattr(AppKit, "WindowDelegate"):  # This prevents re-registration errors
            WindowDelegate = AppKit.WindowDelegate

        else:

            class WindowDelegate(AppKit.NSObject):  # type: ignore[no-redef]
                """super-iby: Helps run window operations on the main thread."""

                results: Dict[bytes, Any] = {}  # Store results here. Not ideal, but may be better than using a global.

                @staticmethod
                def run_on_main_thread(selector: bytes, obj: Optional[Any] = None, wait: Optional[bool] = True) -> Any:
                    """Runs a method of this object on the main thread."""
                    WindowDelegate.alloc().performSelectorOnMainThread_withObject_waitUntilDone_(selector, obj, wait)
                    return WindowDelegate.results.get(selector)

                def getTitleBarHeightAndBorderWidth(self) -> None:
                    """Updates results with title bar height and border width."""
                    frame_width = 100
                    window = AppKit.NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
                        ((0, 0), (frame_width, 100)),
                        AppKit.NSTitledWindowMask,
                        AppKit.NSBackingStoreBuffered,
                        False,
                    )
                    titlebar_height = int(window.titlebarHeight())
                    content_rect = window.contentRectForFrameRect_(window.frame())
                    window.close()
                    x1 = AppKit.NSMinX(content_rect)
                    x2 = AppKit.NSMaxX(content_rect)
                    border_width = int(frame_width - (x2 - x1))
                    result = titlebar_height, border_width
                    # targetSelector can also be defined in a more general way using: inspect.stack()[0].function
                    WindowDelegate.results[targetSelector] = result

        # https://www.macscripter.net/viewtopic.php?id=46336 --> Won't allow access to NSWindow objects, but interesting
        titleHeight, borderWidth = WindowDelegate.run_on_main_thread(targetSelector)
        res = Rect(int(self.left + borderWidth), int(self.top + titleHeight), int(self.right - borderWidth), int(self.bottom - borderWidth))
        return res

    def __repr__(self):
        return '%s(hWnd=%s)' % (self.__class__.__name__, self._app)

    def __eq__(self, other: object):
        return isinstance(other, MacOSWindow) and self._app == other._app

    def close(self, force: bool = False) -> bool:
        """
        Closes this window. This may trigger "Are you sure you want to
        quit?" dialogs or other actions that prevent the window from
        actually closing. This is identical to clicking the X button on the
        window.

        :param force: if ''True'' it will try to close the app if closing the window fails
        :return: ''True'' if window is closed
        """
        if not self._winTitle:
            return False

        self.show()
        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    try
                        tell application appName
                            tell window winName to close
                        end tell
                    end try
                end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        if force and self.isAlive:
            self._app.terminate()
        return not self.isAlive

    def minimize(self, wait: bool = False) -> bool:
        """
        Minimizes this window

        :param wait: set to ''True'' to confirm action requested (in a reasonable time)
        :return: ''True'' if window minimized
        """
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    try
                        tell application "System Events" to tell application process appName
                            set value of attribute "AXMinimized" of window winName to true
                        end tell
                    end try
                end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
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
        if not self._winTitle:
            return False

        # Thanks to: macdeport (for this piece of code, his help, and the moral support!!!)
        if not self.isMaximized:
            if self._use_zoom:
                cmd = """on run {arg1, arg2}
                        set appName to arg1 as string
                        set winName to arg2 as string
                        try
                            tell application "System Events" to tell application appName
                                tell window winName to set zoomed to true
                            end tell
                        end try
                        end run"""
            else:
                cmd = """on run {arg1, arg2}
                            set appName to arg1 as string
                            set winName to arg2 as string
                            try
                                tell application "System Events" to tell application process appName
                                    set value of attribute "AXFullScreen" of window winName to true
                                end tell
                            end try
                        end run"""
            proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
            ret, err = proc.communicate(cmd)
            retries = 0
            while wait and retries < WAIT_ATTEMPTS and not self.isMaximized:
                retries += 1
                time.sleep(WAIT_DELAY * retries)
        return self.isMaximized

    def restore(self, wait: bool = False, user: bool = False) -> bool:
        """
        If maximized or minimized, restores the window to its normal size

        :param wait: set to ''True'' to confirm action requested (in a reasonable time)
        :param user: ignored on macOS platform
        :return: ''True'' if window restored
        """
        if not self._winTitle:
           return False

        if self.isMaximized:
            if self._use_zoom:
                cmd = """on run {arg1, arg2}
                        set appName to arg1 as string
                        set winName to arg2 as string
                            try
                                tell application "System Events" to tell application appName
                                    tell window winName to set zoomed to false
                                end tell
                            end try
                        end run"""
                proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                ret, err = proc.communicate(cmd)
            else:
                cmd = """on run {arg1, arg2}
                            set appName to arg1 as string
                            set winName to arg2 as string
                            try
                                tell application "System Events" to tell application process appName
                                    set value of attribute "AXFullScreen" of window winName to false
                                end tell
                            end try
                        end run"""
                proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                ret, err = proc.communicate(cmd)
        elif self.isMinimized:
            cmd = """on run {arg1, arg2}
                        set appName to arg1 as string
                        set winName to arg2 as string
                        try
                            tell application "System Events" to tell application process appName
                                set value of attribute "AXMinimized" of window winName to false
                            end tell
                        end try
                    end run"""
            proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                    stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
            ret, err = proc.communicate(cmd)
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and (self.isMinimized or self.isMaximized):
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return not self.isMaximized and not self.isMinimized

    def show(self, wait: bool = False) -> bool:
        """
        If hidden or showing, shows the window on screen and in title bar

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window showed
        """
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    set isPossible to false
                    set isDone to false
                    try
                        tell application "System Events" to tell application appName
                            tell window winName to set visible to true
                            set isDone to true
                        end tell
                    end try
                    return (isDone as string)
               end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "")
        if ret != "true":
            self._app.unhide()
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and not self.visible:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return self.visible and self.isActive

    def hide(self, wait: bool = False) -> bool:
        """
        If hidden or showing, hides the window from screen and title bar

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window hidden
        """
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    set isPossible to false
                    set isDone to false
                    try
                        tell application "System Events" to tell application appName
                            tell window winName to set visible to false
                            set isDone to true
                         end tell
                    end try
                    return (isDone as string)
                end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "")
        if ret != "true":
            self._app.hide()
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and self.visible:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return not self.visible

    def activate(self, wait: bool = False, user: bool = True) -> bool:
        """
        Activate this window and make it the foreground (focused) window

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :param user: ignored on macOS platform
        :return: ''True'' if window activated
        """
        if not self._winTitle:
            return False

        if not self.isVisible:
            self.show(wait=wait)
        if self.isMinimized or self.isMaximized:
            self.restore(wait=wait)
        self._app.activateWithOptions_(Quartz.NSApplicationActivateIgnoringOtherApps)
        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    try
                        activate application appName
                        tell application "System Events" to tell application process appName
                            set frontmost to true
                            tell window winName to set value of attribute "AXMain" to true
                        end tell
                    end try
                end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and not self.isActive:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return self.isActive

    def resize(self, widthOffset: int, heightOffset: int, wait: bool = False) -> bool:
        """
        Resizes the window relative to its current size

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window resized to the given size
        """
        box = self.box
        return self.resizeTo(box.width + widthOffset, box.height + heightOffset, wait)

    resizeRel = resize  # resizeRel is an alias for the resize() method.

    def resizeTo(self, newWidth: int, newHeight: int, wait: bool = False) -> bool:
        """
        Resizes the window to a new width and height

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window resized to the given size
        """
        if not self._winTitle:
            return False
        self.size = Size(newWidth, newHeight)
        box = self.box
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and box.width != newWidth and box.height != newHeight:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
            box = self.box
        return box.width == newWidth and box.height == newHeight

    def move(self, xOffset: int, yOffset: int, wait: bool = False) -> bool:
        """
        Moves the window relative to its current position

        :param xOffset: offset relative to current X coordinate to move the window to
        :param yOffset: offset relative to current Y coordinate to move the window to
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window moved to the given position
        """
        box = self.box
        return self.moveTo(box.left + xOffset, box.top + yOffset, wait)

    moveRel = move  # moveRel is an alias for the move() method.

    def moveTo(self, newLeft:int, newTop: int, wait: bool = False) -> bool:
        """
        Moves the window to new coordinates on the screen

        :param newLeft: target X coordinate to move the window to
        :param newTop: target Y coordinate to move the window to
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window moved to the given position
        """
        if not self._winTitle:
            return False
        self.topleft = Point(newLeft, newTop)
        box = self.box
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and box.left != newLeft and box.top != newTop:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
            box = self.box
        return self.left == newLeft and self.top == newTop

    def alwaysOnTop(self, aot: bool = True) -> bool:
        """
        Keeps window on top of all others.

        :param aot: set to ''False'' to deactivate always-on-top behavior
        :return: ''True'' if command succeeded
        """
        # TODO: Is there an attribute or similar to force window always on top?
        ret = True
        if aot:
            if self._tt is None:
                self._kill_tt.clear()
                self._tt = _SendTop(self, self._kill_tt, interval=0.3)
                self._tt.daemon = True
                self._tt.start()
        elif self._tt:
            self._kill_tt.set()
            self._tt.join()
            self._tt = None
        return ret

    def alwaysOnBottom(self, aob: bool = True) -> bool:
        """
        Keeps window below of all others, but on top of desktop icons and keeping all window properties

        :param aob: set to ''False'' to deactivate always-on-bottom behavior
        :return: ''True'' if command succeeded
        """
        # TODO: Is there an attribute or similar to force window always at bottom?
        ret = True
        if aob:
            if self._tb is None:
                self._kill_tb.clear()
                self._tb = _SendBottom(self, self._kill_tb, interval=0.3)
                self._tb.daemon = True
                self._tb.start()
        elif self._tb:
            self._kill_tb.set()
            self._tb.join()
            self._tb = None
        return ret

    def lowerWindow(self):
        """
        Lowers the window to the bottom so that it does not obscure any sibling windows

        :return: ''True'' if window lowered
        """
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    try
                        tell application "System Events"
                            set procList to name of every application process whose background only is false
                            set frontAppName to name of first application process whose frontmost is true
                        end tell
                        repeat with procName in procList
                            if procName is not equal to appName then
                                try
                                    activate application procName
                                    if frontAppName is not equal to appName then
                                        activate application frontAppName
                                    end if
                                end try
                            end if
                        end repeat
                    end try
               end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        return not err

    def raiseWindow(self):
        """
        Raises the window to top so that it is not obscured by any sibling windows.

        :return: ''True'' if window raised
        """
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    try
                        activate application appName
                        tell application "System Events"
                            tell application process appName
                                perform action "AXRaise" of window winName
                            end tell
                        end tell
                    end try
               end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        return not err

    def sendBehind(self, sb: bool = True) -> bool:
        """
        Sends the window to the very bottom, below all other windows, including desktop icons.
        It may also cause that the window does not accept focus nor keyboard/mouse events as well as
        make the window disappear from taskbar and/or pager.

        :param sb: set to ''False'' to bring the window back to front
        :return: ''True'' if window sent behind desktop icons
        """
        # TODO: Is there an attribute or similar to set window level?
        raise NotImplementedError

    def acceptInput(self, setTo: bool) -> None:
        """Toggles the window transparent to input and focus

        :param setTo: True/False to toggle window transparent to input and focus
        :return: None
        """
        raise NotImplementedError

    def getAppName(self) -> str:
        """
        Get the name of the app current window belongs to

        :return: name of the app as string
        """
        return self._appName

    def getParent(self) -> Tuple[str, str]:
        """
        Get the handle of the current window parent. It can be another window or an application

        :return: handle (appName:windowTitle) of the window parent as string. If parent is an application,
        the returned value will contain (appName:Role) where Role will be "AXApplication"
        """
        if not self._winTitle:
            return "", ""

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    set parentRole to ""
                    set parentName to ""
                    try
                        tell application "System Events" to tell application process appName
                            set parentRole to value of attribute "AXRole" of (get value of attribute "AXParent" of window winName)
                            set parentName to value of attribute "AXTitle" of (get value of attribute "AXParent" of window winName)
                        end tell
                    end try
                    return {parentRole, parentName}
               end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "")
        entries = ret.replace("\n", "").split(", ")
        role = entries[0]
        parent = ", ".join(entries[1:])
        result = "", ""
        if parent and role:
            if role == "AXApplication":
                result = role, parent
            else:
                result = self._appName, parent
        return result

    def setParent(self, parent: Tuple[str, str]):
        """
        Current window will become child of given parent
        WARNIG: Not implemented in AppleScript (not possible in macOS for foreign (other apps') windows)

        :param parent: window to set as current window parent
        :return: ''True'' if current window is now child of given parent
        """
        return False

    def getChildren(self):
        """
        Get the children handles of current window

        :return: list of handles as tuples (appName, windowTitle)
        """
        result: List[Tuple[str, str]] = []
        if not self._winTitle:
            return result

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    set winChildren to {}
                    try
                        tell application "System Events" to tell application process appName
                            set winChildren to value of attribute "AXChildren" of window winName
                        end tell
                    end try
                    return winChildren
               end run"""
        proc = subprocess.Popen(['osascript', '-s', 's', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "").replace("{", "['").replace("}", "']").replace('"', '').replace(", ", "', '").replace('missing value', '"missing value"')
        ret = ast.literal_eval(ret)
        for item in ret:
            if item.startswith("window"):
                res = item[item.find("window ")+len("window "):item.rfind(" of window "+self._winTitle)]
                result.append((self._appName, res))
        return result

    def getHandle(self) -> Tuple[str, str]:
        """
        Get the current window handle

        :return: window handle (app:title) as string
        """
        title = self.title
        if not title:
            return "", ""
        return self._appName, title

    def getPID(self) -> Optional[int]:
        """
        Get the current application PID the window belongs to

        :return: application PID or None if it couldn't be retrieved
        """
        cmd = """osascript -s 's' -e 'tell application "System Events"
                                        set appPID to "0"
                                        try
                                            set appPID to unix id of first application process whose name is "%s"
                                        end try
                                    end tell
                                    return appPID'""" % self._appName
        ret = subprocess.check_output(cmd, shell=True).decode(encoding="utf-8").replace("\n", "") \
            .replace('missing value', "0")
        if ret and ret != "0":
            return int(ret)
        return None

    def isParent(self, child: Tuple[str, str]) -> bool:
        """
        Check if current window is parent of given window (handle)

        :param child: handle or name of the window you want to check if the current window is parent of
        :return: ''True'' if current window is parent of the given window
        """
        children = self.getChildren()
        return child in children
    isParentOf = isParent  # isParentOf is an alias of isParent method

    def isChild(self, parent: Tuple[str, str]) -> bool:
        """
        Check if current window is child of given window/app (handle)

        :param parent: handle or name of the window/app you want to check if the current window is child of
        :return: ''True'' if current window is child of the given window
        """
        currParent = self.getParent()
        return currParent == parent
    isChildOf = isChild  # isParentOf is an alias of isParent method

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
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    set isMin to false
                    try
                        tell application "System Events" to tell application process appName
                            set isMin to value of attribute "AXMinimized" of window winName
                        end tell
                    end try
                    return (isMin as string)
                end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "")
        return ret == "true"

    @property
    def isMaximized(self) -> bool:
        """
        Check if current window is currently maximized

        :return: ``True`` if the window is maximized
        """
        if not self._winTitle:
            return False

        if self._use_zoom:
            cmd = """on run {arg1, arg2}
                        set appName to arg1 as string
                        set winName to arg2 as string
                        set isZoomed to false
                        try
                            tell application "System Events" to tell application appName
                                set isZoomed to zoomed of window winName
                            end tell
                        end try
                        return (isZoomed as text)
                    end run"""
        else:
            cmd = """on run {arg1, arg2}
                        set appName to arg1 as string
                        set winName to arg2 as string
                        set isFull to false
                        try
                            tell application "System Events" to tell application process appName
                                set isFull to value of attribute "AXFullScreen" of window winName
                            end tell
                        end try
                        return (isFull as string)
                    end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "")
        return ret == "true"

    @property
    def isActive(self) -> bool:
        """
        Check if current window is currently the active, foreground window

        :return: ``True`` if the window is the active, foreground window
        """
        active = getActiveWindow()
        return active is not None and active._app == self._app and active.title == self._winTitle

    @property
    def title(self) -> str:
        """
        Get the current window title, as string.
        IMPORTANT: window title may change. In that case, it will return an empty string.
        You can use ''updatedTitle'' to try to find the new window title.
        You can also use ''watchdog'' submodule to be notified in case title changes and try to find the new one

        :return: title as a string or None
        """
        titles = _getAppWindowsTitles(self._app)
        if self._winTitle and self._winTitle not in titles:
            self._winTitle = ""
        return self._winTitle

    @property
    def updatedTitle(self) -> str:
        """
        Get and updated title by finding a similar window title within same application.
        It uses a similarity check to find the best match in case title changes (no way to effectively detect it).
        This can be useful since this class uses window title to identify the target window.
        If watchdog is activated, it will stop in case title changes.

        IMPORTANT:

        - New title may not belong to the original target window, it is just similar within same application
        - If original title or a similar one is not found, window may still exist

        :return: possible new title, empty if no similar title found or same title if it didn't change, as a string
        """
        titles = _getAppWindowsTitles(self._app)
        if self._initTitle not in titles:
            newTitles = difflib.get_close_matches(self._initTitle, titles, n=1)  # cutoff=0.6 is the default value
            if newTitles:
                self._winTitle = str(newTitles[0])
                self._initTitle = self._winTitle
            else:
                self._winTitle = ""
        return self._winTitle

    @property
    def visible(self) -> bool:
        """
        Check if current window is visible (minimized windows are also visible)

        :return: ``True`` if the window is currently visible
        """
        return bool(self._winTitle and self._winTitle in _getAppWindowsTitles(self._app))

    isVisible: bool = cast(bool, visible)  # isVisible is an alias for the visible property.

    @property
    def isAlive(self) -> bool:
        """
        Check if window (and application) still exists (minimized and hidden windows are included as existing)
        :return: ''True'' if window exists
        """
        if not self._winTitle:
            return False

        cmd = """on run {arg1, arg2}
                    set appName to arg1 as string
                    set winName to arg2 as string
                    set isDone to false
                    try
                        tell application "System Events" to tell application process appName
                            tell window winName
                            end tell
                            set isDone to true
                        end tell
                    end try
                    return (isDone as string)
               end run"""
        proc = subprocess.Popen(['osascript', '-', self._appName, self._winTitle],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
        ret, err = proc.communicate(cmd)
        ret = ret.replace("\n", "")
        return ret == "true"

    # @property
    # def isAlerting(self) -> bool:
    #     """
    #     Check if window is flashing on taskbar while demanding user attention
    #
    #     :return:  ''True'' if window is demanding attention
    #     """
    #     return False

    class _Menu:

        def __init__(self, parent: MacOSWindow):
            self._parent = parent
            self._menuStructure: dict[str, _SubMenuStructure] = {}
            self.menuList: List[str] = []
            self.itemList: List[str] = []
            self.SEP = "|&|"

        def getMenu(self, addItemInfo: bool = False) -> dict[str, _SubMenuStructure]:
            """
            Loads and returns Menu options, sub-menus and related information, as dictionary.

            It is HIGHLY RECOMMENDED to pre-load the Menu struct by explicitly calling getMenu()
            before invoking any other method.

            WARNING: "item_info" is extremely huge and slow. Instead use getMenuItemInfo() method individually

            WARNING: Notice there are "hidden" menu entries which are not visible, but are returned
            when querying menu. These entries do not have position nor size.

            :param addItemInfo: if ''True'', adds "item_info" struct and "shortcut" to the output
                                "item_info" is extremely huge and slow. Instead use getMenuItemInfo() method individually
            :return: python dictionary with MENU struct

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
            """
            self._menuStructure = {}
            self.menuList = []
            self.itemList = []

            nameList: List[Incomplete] = []
            # Nested recursive types. Dept based on size of nameList.
            # Very complex to type.
            sizeList: List[Sequence[Any]] = []
            posList: List[Sequence[Any]] = []
            attrList: List[Sequence[Any]] = []

            def findit():

                level = 0

                while True:
                    part = ""
                    for lev in range(level):
                        if lev % 2 == 0:
                            part = " of every menu" + part
                        else:
                            part = " of every menu item" + part
                    subCmd1 = "set nameList to name" + part + " of every menu bar item"
                    subCmd2 = "set sizeList to size" + part + " of every menu bar item"
                    subCmd3 = "set posList to position" + part + " of every menu bar item"
                    if addItemInfo:
                        subCmd4 = "set attrList to properties of every attribute" + part + " of every menu bar item"
                    else:
                        subCmd4 = "set attrList to {}"

                    if level % 2 == 0:  # Grabbing items only (menus will have non-empty lists on the next level)

                        cmd = """on run arg1
                                    set procName to arg1 as string
                                    set nameList to {}
                                    set sizeList to {}
                                    set posList to {}
                                    set attrList to {}
                                    try
                                        tell application "System Events"
                                            tell process procName
                                                tell menu bar 1
                                                    %s
                                                    %s
                                                    %s
                                                    %s
                                                end tell
                                            end tell
                                        end tell
                                    end try
                                    return {nameList, sizeList, posList, attrList}
                                end run
                                """ % (subCmd1, subCmd2, subCmd3, subCmd4)
                        # https://stackoverflow.com/questions/69774133/how-to-use-global-variables-inside-of-an-applescript-function-for-a-python-code
                        # Didn't find a way to get the "injected code" working if passed this way
                        proc = subprocess.Popen(['osascript', '-s', 's', '-', str(self._parent._app.localizedName())],
                                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                        ret, err = proc.communicate(cmd)
                        if addItemInfo:
                            ret = ret.replace("\n", "").replace("\t", "").replace('missing value', '"missing value"') \
                                .replace("{", "[").replace("}", "]").replace("value:", "'") \
                                .replace(", class:", "', '").replace(", settable:", "', '").replace(", name:", "', ")
                        else:
                            ret = ret.replace("\n", "").replace("\t", "").replace('missing value', '"missing value"') \
                                .replace("{", "[").replace("}", "]")
                        item = ast.literal_eval(ret)

                        if err is None and not self._isListEmpty(item[0]):
                            nameList.append(item[0])
                            sizeList.append(item[1])
                            posList.append(item[2])
                            attrList.append(item[3])
                        else:
                            break
                    level += 1

                return nameList

            def fillit():

                def subfillit(
                    subNameList: Iterable[str],
                    subSizeList: Sequence[Union[Tuple[int, int], Literal["missing value"]]],
                    subPosList: Sequence[Union[Tuple[int, int], Literal["missing value"]]],
                    subAttrList: Sequence[Attribute],
                    section: str = "",
                    level: int = 0,
                    mainlevel: int = 0,
                    path: Optional[Sequence[int]] = None,
                    parent: int = 0,
                ):
                    path = list(path or [])
                    option = self._menuStructure
                    if section:
                        for sec in section.split(self.SEP):
                            if sec:
                                option = cast("dict[str, _SubMenuStructure]", option[sec])

                    for i, name in enumerate(subNameList):
                        pos = subPosList[i] if len(subPosList) > i else "missing value"
                        size = subSizeList[i] if len(subSizeList) > i else "missing value"
                        attr: Union[str, Attribute] = subAttrList[i] if (addItemInfo and len(subAttrList) > 0) else []
                        if not name:
                            continue
                        elif name == "missing value":
                            name = "separator"
                            option[name] = {}
                        else:
                            ref = section.replace(self.SEP + "entries", "") + self.SEP + name
                            option[name] = {"parent": parent, "wID": self._getNewWid(ref)}
                            if size and pos and size != "missing value" and pos != "missing value":
                                x, y = pos
                                w, h = size
                                option[name]["rect"] = Rect(x, y, x + w, y + h)
                            if addItemInfo and attr:
                                item_info = self._parseAttr(attr)
                                option[name]["item_info"] = item_info
                                option[name]["shortcut"] = self._getaccesskey(item_info)
                            if level + 1 < len(nameList):
                                submenu = nameList[level + 1][mainlevel][0]
                                subPos = posList[level + 1][mainlevel][0]
                                subSize = sizeList[level + 1][mainlevel][0]
                                subAttr: Any = attrList[level + 1][mainlevel][0] if addItemInfo else []
                                subPath = path[3:] + ([0] * (level - 3)) + [i, 0] + ([0] * (level - 2))
                                for j in subPath:
                                    if len(submenu) > j and isinstance(submenu[j], list):
                                        submenu = submenu[j]
                                        subPos = subPos[j]
                                        subSize = subSize[j]
                                        subAttr = subAttr[j] if addItemInfo else []
                                    else:
                                        break
                                if submenu:
                                    option[name]["hSubMenu"] = self._getNewHSubMenu(ref)
                                    option[name]["entries"] = {}
                                    subfillit(submenu, subSize, subPos, subAttr,
                                              section + self.SEP + name + self.SEP + "entries",
                                              level=level + 1, mainlevel=mainlevel, path=[level+1, mainlevel, 0]+subPath,
                                              parent=hSubMenu)
                                else:
                                    option[name]["hSubMenu"] = 0

                for i, item in enumerate(cast("List[str]", nameList[0])):
                    hSubMenu = self._getNewHSubMenu(item)
                    self._menuStructure[item] = {"hSubMenu": hSubMenu, "wID": self._getNewWid(item), "entries": {}}
                    subfillit(nameList[1][i][0], sizeList[1][i][0], posList[1][i][0], attrList[1][i][0] if addItemInfo else [],
                              item + self.SEP + "entries", level=1, mainlevel=i, path=[1, i, 0], parent=hSubMenu)

            if findit(): fillit()

            return self._menuStructure

        def clickMenuItem(self, itemPath: Optional[Sequence[str]] = None, wID: int = 0) -> bool:
            """
            Simulates a click on a menu item

            Notes:
                - It will not work for men/sub-menu entries
                - It will not work if selected option is disabled

            Use one of these input parameters to identify desired menu item:

            :param itemPath: desired menu option and predecessors as list (e.g. ["Menu", "SubMenu", "Item"]). Notice it is language-dependent, so it's better to fulfill it from MENU struct as returned by :meth: getMenu()
            :param wID: item ID within menu struct (as returned by getMenu() method)
            :return: ''True'' if menu item to click is correct and exists (not if it has already been clicked or it had any effect)
            """
            found = False
            if self._checkMenuStruct():
                if not itemPath and wID > 0:
                    itemPath = self._getPathFromWid(wID)

                if itemPath and len(itemPath) > 1:
                    found = True
                    part = ""
                    for i, item in enumerate(itemPath[1:-1]):
                        if i % 2 == 0:
                            part = str(' of menu "%s" of menu item "%s"' % (item, item)) + part
                        else:
                            part = str(' of menu item "%s" of menu "%s"' % (item, item)) + part
                    subCmd = str('click menu item "%s"' % itemPath[-1]) + part + str(' of menu "%s" of menu bar item "%s"' % (itemPath[0], itemPath[0]))

                    cmd = """on run arg1
                                set procName to arg1 as string
                                try
                                    tell application "System Events"
                                        tell process procName
                                            tell menu bar 1
                                                %s
                                            end tell
                                        end tell
                                    end tell
                                end try
                            end run
                            """ % subCmd

                    proc = subprocess.Popen(['osascript', '-s', 's', '-', str(self._parent._app.localizedName())], 
                                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                    ret, err = proc.communicate(cmd)

            return found

        def getMenuInfo(self, hSubMenu: int):
            """
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

            :param hSubMenu: id of the sub-menu entry (as returned by getMenu() method)
            :return: MENUINFO struct
            """
            return self.getMenuItemInfo(hSubMenu, -1)

        def getMenuItemCount(self, hSubMenu: int) -> int:
            """
            Returns the number of items within a menu (main menu if no sub-menu given)

            :param hSubMenu: id of the sub-menu entry (as returned by getMenu() method)
            :return: number of items as int
            """
            count = 0
            if self._checkMenuStruct():
                menuPath = self._getPathFromHSubMenu(hSubMenu)

                if menuPath:
                    part = ""
                    for i, item in enumerate(menuPath[:-1]):
                        if i % 2 == 0:
                            part = str(' of menu "%s"' % item) + part
                        else:
                            part = str(' of menu item "%s"' % item) + part
                    subCmd = 'set itemCount to count of every menu item' + part + str(' of menu bar item "%s"' % menuPath[0])

                    cmd = """on run arg1
                                set procName to arg1 as string
                                set itemCount to 0
                                try
                                    tell application "System Events"
                                        tell process procName
                                            tell menu bar 1
                                                %s
                                            end tell
                                        end tell
                                    end tell
                                end try
                                return itemCount as integer
                            end run
                            """ % subCmd

                    proc = subprocess.Popen(['osascript', '-s', 's', '-', str(self._parent._app.localizedName())], 
                                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                    ret, err = proc.communicate(cmd)
                    ret = ret.replace("\n", "")
                    if ret.isnumeric():
                        count = int(ret)

            return count

        def getMenuItemInfo(self, hSubMenu: int, wID: int):
            """
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

            :param hSubMenu: id of the sub-menu entry (as returned by :meth: getMenu())
            :param wID: id of the window within menu struct (as returned by :meth: getMenu())
            :return: MENUITEMINFO struct
            """
            itemInfo = {}
            if self._checkMenuStruct():
                if wID == -1:
                    itemPath = self._getPathFromHSubMenu(hSubMenu)
                else:
                    itemPath = self._getPathFromWid(wID)

                if itemPath:
                    part = ""
                    for lev, item in enumerate(itemPath[:-1]):
                        if lev % 2 == 0:
                            part = str(' of menu "%s"' % item) + part
                        else:
                            part = str(' of menu item "%s"' % item) + part
                    subCmd = str('set attrList to properties of every attribute of menu item "%s"' % itemPath[-1]) + part + str(' of menu bar item "%s"' % itemPath[0])
                    # subCmd2 = str('set propList to properties of menu item "%s"' % itemPath[-1]) + part + str(' of menu bar item "%s"' % itemPath[0])

                    cmd = """on run arg1
                                set procName to arg1 as string
                                set attrList to {}
                                    tell application "System Events"
                                        tell process procName
                                            tell menu bar 1
                                                %s
                                            end tell
                                        end tell
                                    end tell
                                return attrList
                            end run
                            """ % subCmd
                    # https://stackoverflow.com/questions/69774133/how-to-use-global-variables-inside-of-an-applescript-function-for-a-python-code
                    # Didn't find a way to get the "injected code" working if passed this way
                    proc = subprocess.Popen(['osascript', '-s', 's', '-', str(self._parent._app.localizedName())], 
                                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                    ret, err = proc.communicate(cmd)
                    itemInfo = self._parseAttr(ret)

            return itemInfo

        def getMenuItemRect(self, hSubMenu: int, wID: int) -> Rect:
            """
            Get the Rect struct (left, top, right, bottom) of the given Menu option

            :param hSubMenu: id of the sub-menu entry (as returned by :meth: getMenu())
            :param wID: id of the window within menu struct (as returned by :meth: getMenu())
            :return: Rect struct
            """
            x = y = w = h = 0
            if self._checkMenuStruct():
                menuPath = self._getPathFromHSubMenu(hSubMenu)
                itemPath = self._getPathFromWid(wID)

                if itemPath and menuPath and len(itemPath) > 1 and itemPath[:-1] == menuPath:
                    part = ""
                    for i, item in enumerate(itemPath[1:-1]):
                        if i % 2 == 0:
                            part = str(' of menu "%s" of menu item "%s"' % (item, item)) + part
                        else:
                            part = str(' of menu item "%s" of menu "%s"' % (item, item)) + part
                    subCmd = str('set itemRect to {position, size} of menu item "%s"' % itemPath[-1]) + part + str(' of menu "%s" of menu bar item "%s"' % (itemPath[0], itemPath[0]))

                    cmd = """on run arg1
                                set procName to arg1 as string
                                set itemRect to {{0, 0}, {0, 0}}
                                try
                                    tell application "System Events"
                                        tell process procName
                                            tell menu bar 1
                                                %s
                                            end tell
                                        end tell
                                    end tell
                                end try
                                return itemRect
                            end run
                            """ % subCmd

                    proc = subprocess.Popen(['osascript', '-s', 's', '-', str(self._parent._app.localizedName())], 
                                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, encoding='utf8')
                    ret, err = proc.communicate(cmd)
                    ret = ret.replace("\n", "").replace("{", "[").replace("}", "]").replace('missing value', '"missing value"')
                    rect = ast.literal_eval(ret)
                    x, y = rect[0]
                    w, h = rect[1]

            return Rect(x, y, x + w, y + h)

        def _isListEmpty(self, inList: List[Any]):
            # https://stackoverflow.com/questions/1593564/python-how-to-check-if-a-nested-list-is-essentially-empty/51582274
            if isinstance(inList, list):
                return all(map(self._isListEmpty, inList))
            return False

        def _parseAttr(self, attr: Union[str, Attribute]):

            itemInfo: dict[str, _ItemInfoValue] = {}
            if isinstance(attr, str):
                attr = attr.replace("\n", "").replace('missing value', '"missing value"') \
                    .replace("{", "[").replace("}", "]").replace("value:", "'") \
                    .replace(", class:", "', '").replace(", settable:", "', '").replace(", name:", "', ")
                items: Attribute = ast.literal_eval(attr)
            else:
                items = attr
            for item in items:
                if len(item) >= 4:
                    itemInfo[item[3]] = {"value": item[0], "class": item[1], "settable": item[2]}

            return itemInfo

        def _checkMenuStruct(self):
            if not self._menuStructure:
                self.getMenu()
            return self._menuStructure

        def _getNewWid(self, ref: str):
            self.itemList.append(ref)
            return len(self.itemList)

        def _getPathFromWid(self, wID: int):
            itemPath = []
            if self._checkMenuStruct():
                if 0 < wID <= len(self.itemList):
                    itemPath = self.itemList[wID - 1].split(self.SEP)
            return itemPath

        def _getNewHSubMenu(self, ref: str):
            self.menuList.append(ref)
            return len(self.menuList)

        def _getPathFromHSubMenu(self, hSubMenu: int):
            menuPath = []
            if self._checkMenuStruct():
                if 0 < hSubMenu <= len(self.menuList):
                    menuPath = self.menuList[hSubMenu - 1].split(self.SEP)
            return menuPath

        def _getMenuItemWid(self, itemPath: str):
            wID = 0
            if itemPath:
                option = self._menuStructure
                for item in itemPath[:-1]:
                    entries = option.get(item, {}).get("entries", None)
                    if entries:
                        option = entries
                    else:
                        option = {}
                        break
                wID = option.get(itemPath[-1], {}).get("wID", 0)
            return wID

        def _getaccesskey(self, item_info: Union[Dict[str, Dict[str, str]], Dict[str, _ItemInfoValue]]):
            # https://github.com/babarrett/hammerspoon/blob/master/cheatsheets.lua
            # https://github.com/pyatom/pyatom/blob/master/atomac/ldtpd/core.py

            mods = ["<command", "<shift><command", "<option><command>", "<option><shift><command>",
                    "<control><command>", "<control><option><command>", "", "<tab>", "", "<option>",
                    "<option><shift>", "<control>", "<control><shift>", "<control><option>"]

            try:
                key = item_info["AXMenuItemCmdChar"]["value"]
            except:
                key = ""
            try:
                modifiers = int(item_info["AXMenuItemCmdModifiers"]["value"])
            except:
                modifiers = -1
            try:
                glyph = int(item_info["AXMenuItemCmdGlyph"]["value"])
            except:
                glyph = -1
            try:
                virtual_key = int(item_info["AXMenuItemCmdVirtualKey"]["value"])
            except:
                virtual_key = -1

            modifiers_type = ""
            if modifiers < len(mods):
                modifiers_type = mods[modifiers]

            # Probably, this is not exhaustive
            # Scroll up
            if virtual_key == 115 and glyph == 102:
                modifiers_type = "<option>"
                key = "<left>"
            # Scroll down
            elif virtual_key == 119 and glyph == 105:
                modifiers_type = "<option>"
                key = "<right>"
            # Page up
            elif virtual_key == 116 and glyph == 98:
                modifiers_type = "<option>"
                key = "<up>"
            # Page down
            elif virtual_key == 121 and glyph == 107:
                modifiers_type = "<option>"
                key = "<down>"
            # Line up
            elif virtual_key == 126 and glyph == 104:
                key = "<up>"
            # Line down
            elif virtual_key == 125 and glyph == 106:
                key = "<down>"
            # Noticed in  Google Chrome navigating next tab
            elif virtual_key == 124 and glyph == 101:
                key = "<right>"
            # Noticed in  Google Chrome navigating previous tab
            elif virtual_key == 123 and glyph == 100:
                key = "<left>"
            # list application in a window to Force Quit
            elif virtual_key == 53 and glyph == 27:
                key = "<escape>"

            if not key:
                modifiers_type = ""

            return modifiers_type + key


class _SendTop(threading.Thread):

    def __init__(self, hWnd: MacOSWindow, kill: threading.Event, interval: float = 0.5):
        threading.Thread.__init__(self)
        self._hWnd = hWnd
        self._kill = kill
        self._interval = interval

    def run(self):
        while not self._kill.is_set():
            if not self._hWnd.isActive:
                self._hWnd.activate()
            self._kill.wait(self._interval)


class _SendBottom(threading.Thread):

    def __init__(self, hWnd: MacOSWindow, kill: threading.Event, interval: float = 0.5):
        threading.Thread.__init__(self)
        self._hWnd = hWnd
        self._app = hWnd._app
        self._appPID = hWnd._appPID
        self._kill = kill
        self._interval = interval
        _apps = _getAllApps()
        self._apps: List[AppKit.NSRunningApplication] = []
        for app in _apps:
            if app.processIdentifier() != self._appPID:
                self._apps.append(app)

    def run(self):
        while not self._kill.is_set():
            if self._hWnd.isActive:
                self._hWnd.lowerWindow()
            self._kill.wait(self._interval)

    def kill(self):
        self._kill.set()

    def restart(self):
        self.kill()
        self._kill = threading.Event()
        self.run()


# class MacOSNSWindow(BaseWindow):
#
#     def __init__(self, app: AppKit.NSApplication, hWnd: AppKit.NSWindow):
#         super().__init__(hWnd)
#
#         self._app = app
#         self._hWnd = hWnd
#         self._parent = hWnd.parentWindow()
#         self.watchdog = _WatchDog(self)
#
#     def getExtraFrameSize(self, includeBorder: bool = True) -> Tuple[int, int, int, int]:
#         """
#         Get the extra space, in pixels, around the window, including or not the border
#
#         :param includeBorder: set to ''False'' to avoid including borders
#         :return: (left, top, right, bottom) frame size as a tuple of int
#         """
#         borderWidth = 0
#         if includeBorder:
#             ret = self._hWnd.contentRectForFrameRect_(self._hWnd.frame())
#             frame = self._hWnd.screen().convertRectToBacking_(ret)
#             borderWidth = frame.origin.x - self.left
#         frame = (borderWidth, borderWidth, borderWidth, borderWidth)
#         return frame
#
#     def getClientFrame(self):
#         """
#         Get the client area of window, as a Rect (x, y, right, bottom)
#         Notice that scroll bars will be included within this area
#
#         :return: Rect struct
#         """
#         ret = self._hWnd.contentRectForFrameRect_(self._hWnd.frame())
#         frame = self._hWnd.screen().convertRectToBacking_(ret)
#         x = int(frame.origin.x)
#         y = int(frame.origin.y)
#         w = int(frame.size.width)
#         h = int(frame.size.height)
#         r = x + w
#         b = y + h
#         return Rect(x, y, r, b)
#
#     def __repr__(self):
#         return '%s(hWnd=%s)' % (self.__class__.__name__, self._hWnd)
#
#     def __eq__(self, other: object):
#         return isinstance(other, MacOSNSWindow) and self._hWnd == other._hWnd
#
#     def close(self) -> bool:
#         """
#         Closes this window. This may trigger "Are you sure you want to
#         quit?" dialogs or other actions that prevent the window from
#         actually closing. This is identical to clicking the X button on the
#         window.
#
#         :return: ''True'' if window is closed
#         """
#         return self._hWnd.performClose_(self._app)
#
#     def minimize(self, wait: bool = False) -> bool:
#         """
#         Minimizes this window
#
#         :param wait: set to ''True'' to confirm action requested (in a reasonable time)
#         :return: ''True'' if window minimized
#         """
#         self._hWnd.performMiniaturize_(self._app)
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and not self.isMinimized:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#         return self.isMinimized
#
#     def maximize(self, wait: bool = False) -> bool:
#         """
#         Maximizes this window
#
#         :param wait: set to ''True'' to confirm action requested (in a reasonable time)
#         :return: ''True'' if window maximized
#         """
#         self._hWnd.performZoom_(self._app)
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and not self.isMaximized:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#         return self.isMaximized
#
#     def restore(self, wait: bool = False, user: bool = False) -> bool:
#         """
#         If maximized or minimized, restores the window to it's normal size
#
#         :param wait: set to ''True'' to confirm action requested (in a reasonable time)
#         :param user: ignored on macOS platform
#         :return: ''True'' if window restored
#         """
#         self.activate(wait=True)
#         if self.isMaximized:
#             self._hWnd.performZoom_(self._app)
#         self._hWnd.deminiaturize_(self._app)
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and (self.isMinimized or self.isMaximized):
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#         return not self.isMaximized and not self.isMinimized
#
#     def show(self, wait: bool = False) -> bool:
#         """
#         If hidden or showing, shows the window on screen and in title bar
#
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :return: ''True'' if window showed
#         """
#         self.activate(wait=wait)
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and not self.visible:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#         return self.visible
#
#     def hide(self, wait: bool = False) -> bool:
#         """
#         If hidden or showing, hides the window from screen and title bar
#
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :return: ''True'' if window hidden
#         """
#         self._hWnd.orderOut_(self._app)
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and self.visible:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#         return not self.visible
#
#     def activate(self, wait: bool = False, user: bool = True) -> bool:
#         """
#         Activate this window and make it the foreground (focused) window
#
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :param user: ignored on macOS platform
#         :return: ''True'' if window activated
#         """
#         self._app.activateIgnoringOtherApps_(True)
#         self._hWnd.makeKeyAndOrderFront_(self._app)
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and not self.isActive:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#         return self.isActive
#
#     def resize(self, widthOffset: int, heightOffset: int, wait: bool = False) -> bool:
#         """
#         Resizes the window relative to its current size
#
#         :param widthOffset: offset to add to current window width as target width
#         :param heightOffset: offset to add to current window height as target height
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :return: ''True'' if window resized to the given size
#         """
#         box = self.box
#         return self.resizeTo(box.width + widthOffset, box.height + heightOffset, wait)
#
#     resizeRel = resize  # resizeRel is an alias for the resize() method.
#
#     def resizeTo(self, newWidth: int, newHeight: int, wait: bool = False) -> bool:
#         """
#         Resizes the window to a new width and height
#
#         :param newWidth: target window width
#         :param newHeight: target window height
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :return: ''True'' if window resized to the given size
#         """
#         self.size = Size(newWidth, newHeight)
#         box = self.box
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and box.width != newWidth and box.height != newHeight:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#             box = self.box
#         return box.width == newWidth and box.height == newHeight
#
#     def move(self, xOffset: int, yOffset: int, wait: bool = False) -> bool:
#         """
#         Moves the window relative to its current position
#
#         :param xOffset: offset relative to current X coordinate to move the window to
#         :param yOffset: offset relative to current Y coordinate to move the window to
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :return: ''True'' if window moved to the given position
#         """
#         box = self.box
#         return self.moveTo(box.left + xOffset, box.top + yOffset, wait)
#
#     moveRel = move  # moveRel is an alias for the move() method.
#
#     def moveTo(self, newLeft:int, newTop: int, wait: bool = False) -> bool:
#         """
#         Moves the window to new coordinates on the screen
#
#         :param newLeft: target X coordinate to move the window to
#         :param newTop: target Y coordinate to move the window to
#         :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
#         :return: ''True'' if window moved to the given position
#         """
#         self.topleft = Point(newLeft, newTop)
#         box = self.box
#         retries = 0
#         while wait and retries < WAIT_ATTEMPTS and box.left != newLeft and box.top != newTop:
#             retries += 1
#             time.sleep(WAIT_DELAY * retries)
#             box = self.box
#         return box.left == newLeft and box.top == newTop
#
#     def alwaysOnTop(self, aot: bool = True) -> bool:
#         """
#         Keeps window on top of all others.
#
#         :param aot: set to ''False'' to deactivate always-on-top behavior
#         :return: ''True'' if command succeeded
#         """
#         if aot:
#             ret = self._hWnd.setLevel_(Quartz.kCGScreenSaverWindowLevel)
#         else:
#             ret = self._hWnd.setLevel_(Quartz.kCGNormalWindowLevel)
#         return ret
#
#     def alwaysOnBottom(self, aob: bool = True) -> bool:
#         """
#         Keeps window below of all others, but on top of desktop icons and keeping all window properties
#
#         :param aob: set to ''False'' to deactivate always-on-bottom behavior
#         :return: ''True'' if command succeeded
#         """
#         if aob:
#             ret = self._hWnd.setLevel_(Quartz.kCGDesktopWindowLevel)
#         else:
#             ret = self._hWnd.setLevel_(Quartz.kCGNormalWindowLevel)
#         return ret
#
#     def lowerWindow(self) -> bool:
#         """
#         Lowers the window to the bottom so that it does not obscure any sibling windows
#
#         :return: ''True'' if window lowered
#         """
#         # self._hWnd.orderBack_(self._app)  # Not working or using it wrong???
#         windows = self._app.orderedWindows()
#         ret = False
#         if windows:
#             windows.reverse()
#             for win in windows:
#                 if win != self._hWnd:
#                     ret = win.makeKeyAndOrderFront_(self._app)
#         return ret
#
#     def raiseWindow(self, sb: bool = True) -> bool:
#         """
#         Raises the window to top so that it is not obscured by any sibling windows.
#
#         :return: ''True'' if window raised
#         """
#         return self._hWnd.makeKeyAndOrderFront_(self._app)
#
#     def sendBehind(self, sb: bool = True) -> bool:
#         """
#         Sends the window to the very bottom, below all other windows, including desktop icons.
#         It may also cause that the window does not accept focus nor keyboard/mouse events as well as
#         make the window disappear from taskbar and/or pager.
#
#         :param sb: set to ''False'' to bring the window back to front
#         :return: ''True'' if window sent behind desktop icons
#         """
#         # https://stackoverflow.com/questions/4982584/how-do-i-draw-the-desktop-on-mac-os-x
#         if sb:
#             ret1 = self._hWnd.setLevel_(Quartz.kCGDesktopWindowLevel - 1)
#             ret2 = self._hWnd.setCollectionBehavior_(Quartz.NSWindowCollectionBehaviorCanJoinAllSpaces |
#                                                      Quartz.NSWindowCollectionBehaviorStationary |
#                                                      Quartz.NSWindowCollectionBehaviorIgnoresCycle)
#         else:
#             ret1 = self._hWnd.setLevel_(Quartz.kCGNormalWindowLevel)
#             ret2 = self._hWnd.setCollectionBehavior_(Quartz.NSWindowCollectionBehaviorDefault |
#                                                      Quartz.NSWindowCollectionBehaviorParticipatesInCycle |
#                                                      Quartz.NSWindowCollectionBehaviorManaged)
#         return ret1 and ret2
#
#     def acceptInput(self, setTo: bool) -> None:
#         """Toggles the window transparent to input and focus
#
#         :param setTo: True/False to toggle window transparent to input and focus
#         :return: None
#         """
#         self._hWnd.setIgnoresMouseEvents_(not setTo)
#
#     def getAppName(self) -> str:
#         """
#         Get the name of the app current window belongs to
#
#         :return: name of the app as string
#         """
#         return self._app.localizedName()
#
#     def getParent(self) -> int:
#         """
#         Get the handle of the current window parent. It can be another window or an application
#
#         :return: handle of the window parent
#         """
#         return self._hWnd.parentWindow()
#
#     def setParent(self, parent) -> bool:
#         """
#         Current window will become child of given parent
#         WARNIG: Not implemented in AppleScript (not possible in macOS for foreign (other apps') windows)
#
#         :param parent: window to set as current window parent
#         :return: ''True'' if current window is now child of given parent
#         """
#         parent.addChildWindow(self._hWnd, 1)
#         return bool(self.isChild(parent))
#
#     def getChildren(self) -> List[int]:
#         """
#         Get the children handles of current window
#
#         :return: list of handles
#         """
#         return self._hWnd.childWindows()
#
#     def getHandle(self):
#         """
#         Get the current window handle
#
#         :return: window handle
#         """
#         return self._hWnd
#
#     def isParent(self, child: AppKit.NSWindow) -> bool:
#         """
#         Check if current window is parent of given window (handle)
#
#         :param child: handle of the window you want to check if the current window is parent of
#         :return: ''True'' if current window is parent of the given window
#         """
#         return child.parentWindow() == self._hWnd
#     isParentOf = isParent  # isParentOf is an alias of isParent method
#
#     def isChild(self, parent: int) -> bool:
#         """
#         Check if current window is child of given window/app (handle)
#
#         :param parent: handle of the window/app you want to check if the current window is child of
#         :return: ''True'' if current window is child of the given window
#         """
#         return parent == self.getParent()
#     isChildOf = isChild  # isChildOf is an alias of isParent method
#
#     def getDisplay(self) -> List[str]:
#         """
#         Get display name in which current window space is mostly visible
#
#         :return: display name as string or empty (couldn't retrieve it or window is offscreen)
#         """
#         x, y = self.center
#         return _findMonitorName(x, y)
#     getMonitor = getDisplay  # getMonitor is an alias of getDisplay method
#
#     @property
#     def isMinimized(self) -> bool:
#         """
#         Check if current window is currently minimized
#
#         :return: ``True`` if the window is minimized
#         """
#         return self._hWnd.isMiniaturized()
#
#     @property
#     def isMaximized(self) -> bool:
#         """
#         Check if current window is currently maximized
#
#         :return: ``True`` if the window is maximized
#         """
#         return self._hWnd.isZoomed()
#
#     @property
#     def isActive(self) -> bool:
#         """
#         Check if current window is currently the active, foreground window
#
#         :return: ``True`` if the window is the active, foreground window
#         """
#         windows = getAllWindows(self._app)
#         for win in windows:
#             return self._hWnd == win._hWnd
#         return False
#
#     @property
#     def title(self) -> str:
#         """
#         Get the current window title, as string
#
#         :return: title as a string
#         """
#         return self._hWnd.title()
#
#     @property
#     def updatedTitle(self) -> str:
#         """
#         WARNING: MacOSWindow ONLY. For MacOSNSWindow, this property returns actual title
#
#         :return: title as a string
#         """
#         return self.title
#
#     @property
#     def visible(self) -> bool:
#         """
#         Check if current window is visible (minimized windows are also visible)
#
#         :return: ``True`` if the window is currently visible
#         """
#         return self._hWnd.isVisible()
#
#     isVisible = visible  # isVisible is an alias for the visible property.
#
#     @property
#     def isAlive(self) -> bool:
#         """
#         Check if window (and application) still exists (minimized and hidden windows are included as existing)
#
#         :return: ''True'' if window exists
#         """
#         ret = False
#         if self._hWnd in self._app.orderedWindows():
#             ret = True
#         return ret
#
    # @property
    # def isAlerting(self) -> bool:
    #     """Check if window is flashing on taskbar while demanding user attention
    #
    #     :return:  ''True'' if window is demanding attention
    #     """
    #     return False
