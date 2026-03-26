#!/usr/bin/python
# -*- coding: utf-8 -*-
from __future__ import annotations

import sys
assert sys.platform == "win32"

import ctypes
import re
import threading
import time
from collections.abc import Sequence
from ctypes import wintypes
from typing import cast, Any, TYPE_CHECKING, Tuple, Optional, Union, List
from typing_extensions import NotRequired, TypedDict

if TYPE_CHECKING:
    from win32.lib.win32gui_struct import _MENUITEMINFO, _MENUINFO

import win32gui_struct
import win32process
from win32com.client import GetObject
import win32con
import win32api
import win32gui

from ._main import BaseWindow, Re, _WatchDog, _findMonitorName, _WINDATA, _WINDICT
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


def getActiveWindow() -> Optional[Win32Window]:
    """
    Get the currently active (focused) Window

    :return: Window object or None
    """
    hWnd = win32gui.GetForegroundWindow()
    if hWnd:
        return Win32Window(hWnd)
    else:
        return None


def getActiveWindowTitle() -> str:
    """
    Get the title of the currently active (focused) Window

    :return: window title as string or empty
    """
    hWnd = getActiveWindow()
    if hWnd:
        return hWnd.title
    else:
        return ""


def getAllWindows() -> List[Win32Window]:
    """
    Get the list of Window objects for all visible windows

    :return: list of Window objects
    """
    # https://stackoverflow.com/questions/64586371/filtering-background-processes-pywin32
    # return [Win32Window(hwnd[0]) for hwnd in _findMainWindowHandles()]
    return [window for window in __remove_bad_windows(_findWindowHandles())]


def __remove_bad_windows(windows: Optional[List[int]]):
    """
    :param windows: win32 Windows
    :return: A generator of Win32Window that filters out BadWindows
    """
    outList = []
    if windows is not None:
        for window in windows:
            try:
                outList.append(Win32Window(window))
            except:
                pass
    return outList


def getAllTitles() -> List[str]:
    """
    Get the list of titles of all visible windows

    :return: list of titles as strings
    """
    return [window.title for window in getAllWindows()]


def getWindowsWithTitle(title: Union[str, re.Pattern[str]], app: Optional[Tuple[str, ...]] = (), condition: int = Re.IS, flags: int = 0) -> List[Win32Window]:
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
    matches: List[Win32Window] = []
    if title and condition in Re._cond_dic:
        lower = False
        if condition in (Re.MATCH, Re.NOTMATCH):
            title = re.compile(title, flags)
        elif condition in (Re.EDITDISTANCE, Re.DIFFRATIO):
            # flags = Re.IGNORECASE | ratio -> lower = flags & Re.IGNORECASE == Re.IGNORECASE / ratio = flags ^ Re.IGNORECASE
            if not isinstance(flags, int) or not (0 < flags <= 100):
                flags = 90
        elif flags == Re.IGNORECASE:
            lower = True
            if isinstance(title, re.Pattern):
                title = title.pattern
            title = title.lower()
        for win in getAllWindows():
            if win.title and Re._cond_dic[condition](title, win.title.lower() if lower else win.title, flags) \
                    and (not app or (app and win.getAppName() in app)):
                matches.append(win)
    return matches


def getAllAppsNames() -> List[str]:
    """
    Get the list of names of all visible apps

    :return: list of names as strings
    """
    return list(getAllAppsWindowsTitles().keys())


def getAppsWithName(name: Union[str, re.Pattern[str]], condition: int = Re.IS, flags: int = 0) -> List[str]:
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


def getAllAppsWindowsTitles() -> dict[str, List[str]]:
    """
    Get all visible apps names and their open windows titles

    Format:
        Key: app name

        Values: list of window titles as strings

    :return: python dictionary
    """
    process_list = _getAllApps(tryToFilter=True)
    result: dict[str, List[str]] = {}
    for win in getAllWindows():
        pID = win32process.GetWindowThreadProcessId(win.getHandle())
        for item in process_list:
            appPID = item[0]
            appName = str(item[1])
            if appPID == pID[1]:
                if appName in result:
                    result[appName].append(win.title)
                else:
                    result[appName] = [win.title]
                break
    return result


def getAllWindowsDict(tryToFilter: bool = False) -> dict[str, _WINDICT]:
    """
    Get all visible apps and windows info

    Format:
        Key: app name

        Values:
            "pid": app PID
            "windows": subdictionary of all app windows
                Key: window title

                Values:
                    "id": window handle
                    "display": display in which window is mostly visible
                    "position": window position (x, y) within display
                    "size": window size (width, height)
                    "status": 0 - normal, 1 - minimized, 2 - maximized

    :param tryToFilter: Windows ONLY. Set to ''True'' to try to get User (non-system) apps only (may skip real user apps)
    :return: python dictionary
    """
    process_list = _getAllApps(tryToFilter)
    result: dict[str, _WINDICT] = {}
    for win in getAllWindows():
        winId = win.getHandle()
        pID = win32process.GetWindowThreadProcessId(winId)
        for item in process_list:
            appPID = item[0]
            appName = str(item[1])
            if appPID == pID[1]:
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
                break
    return result


def getWindowsAt(x: int, y: int) -> List[Win32Window]:
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


def getTopWindowAt(x: int, y: int) -> Optional[Win32Window]:
    """
    Get the Window object at the top of the stack at the point ``(x, y)`` on screen

    :param x: X screen coordinate of the window
    :param y: Y screen coordinate of the window
    :return: Window object or None
    """
    hwnd = win32gui.WindowFromPoint((x, y))

    # Want to pull the parent window from the window handle
    # By using GetAncestor we are able to get the parent window instead of the owner window.
    while win32gui.IsChild(win32gui.GetParent(hwnd), hwnd):
        hwnd = ctypes.windll.user32.GetAncestor(hwnd, win32con.GA_ROOT)
    return Win32Window(hwnd) if hwnd else None


def _findWindowHandles(parent: Optional[int] = None, window_class: Optional[str] = None, title: Optional[str] = None, onlyVisible: bool = True) -> List[int]:

    handle_list: List[int] = []

    def findit(hwnd: int, ctx: Any) -> bool:

        if window_class and window_class != win32gui.GetClassName(hwnd):
            return True
        if title and title != win32gui.GetWindowText(hwnd):
            return True
        if not onlyVisible or (onlyVisible and win32gui.IsWindowVisible(hwnd)):
            handle_list.append(hwnd)
        return True

    if not parent:
        parent = win32gui.GetDesktopWindow()  # type: ignore[no-untyped-call]  # pyright: ignore[reportUnknownMemberType]
    win32gui.EnumChildWindows(parent, findit, None)
    return handle_list


def _findMainWindowHandles() -> List[Tuple[int, int]]:
    # Filter windows: https://stackoverflow.com/questions/64586371/filtering-background-processes-pywin32

    class TITLEBARINFO(ctypes.Structure):
        if TYPE_CHECKING:
            cbSize: int
            rcTitleBar: wintypes.RECT
            rgstate: List[int]
            def __init__(
                self,
                cbSize: int = ...,
                rcTitleBar: wintypes.RECT = ...,
                rgstate: List[int] = ...
            ): ...

        _fields_ = [
            ("cbSize", wintypes.DWORD),
            ("rcTitleBar", wintypes.RECT),
            ("rgstate", wintypes.DWORD * 6)
        ]

    def winEnumHandler(hwnd: int, ctx: Any):
        if not win32gui.IsWindowVisible(hwnd):
            return

        # Title Info Initialization
        title_info = TITLEBARINFO()
        title_info.cbSize = ctypes.sizeof(title_info)
        ctypes.windll.user32.GetTitleBarInfo(hwnd, ctypes.byref(title_info))

        # DWM Cloaked Check
        isCloaked = ctypes.c_int(0)
        DWMWA_CLOAKED = 14
        ctypes.windll.dwmapi.DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, ctypes.byref(isCloaked), ctypes.sizeof(isCloaked))

        # Variables
        title = win32gui.GetWindowText(hwnd)

        # Append HWND to list
        if win32gui.IsWindowVisible(hwnd) and title != '' and isCloaked.value == 0:
            if not (title_info.rgstate[0] & win32con.STATE_SYSTEM_INVISIBLE):
                handle_list.append((hwnd, win32process.GetWindowThreadProcessId(hwnd)[1]))

    handle_list: List[Tuple[int, int]] = []
    win32gui.EnumWindows(winEnumHandler, None)
    return handle_list


def _getAllApps(tryToFilter: bool = False) -> Union[List[Tuple[int, Optional[str]]], List[Tuple[int, str]]]:
    # https://stackoverflow.com/questions/550653/cross-platform-way-to-get-pids-by-process-name-in-python
    WMI = GetObject('winmgmts:')
    if tryToFilter:
        mainWindows = [w[1] for w in _findMainWindowHandles()]
        return [(p.Properties_("ProcessID").Value, p.Properties_("Name").Value) for p in WMI.InstancesOf('Win32_Process')
                if p.Properties_("ProcessID").Value in mainWindows]
    else:
        return [(p.Properties_("ProcessID").Value, p.Properties_("Name").Value) for p in WMI.InstancesOf('Win32_Process')]


def _getAllAppsDict(tryToFilter: bool = False) -> dict[str, Union[int, str]]:
    # https://stackoverflow.com/questions/550653/cross-platform-way-to-get-pids-by-process-name-in-python
    WMI = GetObject('winmgmts:')
    result: dict[str, Union[int, str]] = {}
    if tryToFilter:
        mainWindows = [w[1] for w in _findMainWindowHandles()]
        for p in WMI.InstancesOf('Win32_Process'):
            if p.Properties_("ProcessID").Value in mainWindows:
               result[p.Properties_("ProcessID").Value] = p.Properties_("Name").Value
    else:
        for p in WMI.InstancesOf('Win32_Process'):
            result[p.Properties_("ProcessID").Value] = p.Properties_("Name").Value
    return result


class tagWINDOWINFO(ctypes.Structure):
    # Help type-checkers with ctypes.Structure
    if TYPE_CHECKING:
        cbSize: int
        rcWindow: wintypes.RECT
        rcClient: wintypes.RECT
        dwStyle: int
        dwExStyle: int
        dwWindowStatus: int
        cxWindowBorders: int
        cyWindowBorders: int
        atomWindowType: int
        wCreatorVersion: int
        def __init__(
            self,
            cbSize: int = ...,
            rcWindow: wintypes.RECT = ...,
            rcClient: wintypes.RECT = ...,
            dwStyle: int = ...,
            dwExStyle: int = ...,
            dwWindowStatus: int = ...,
            cxWindowBorders: int = ...,
            cyWindowBorders: int = ...,
            atomWindowType: int = ...,
            wCreatorVersion: int = ...
        ): ...

    _fields_ = [
        ('cbSize', wintypes.DWORD),
        ('rcWindow', wintypes.RECT),
        ('rcClient', wintypes.RECT),
        ('dwStyle', wintypes.DWORD),
        ('dwExStyle', wintypes.DWORD),
        ('dwWindowStatus', wintypes.DWORD),
        ('cxWindowBorders', wintypes.UINT),
        ('cyWindowBorders', wintypes.UINT),
        ('atomWindowType', wintypes.ATOM),
        ('wCreatorVersion', wintypes.WORD)
    ]


def _getWindowInfo(hWnd: Optional[Union[int, str, bytes, bool]]) -> tagWINDOWINFO:

    # PWINDOWINFO = ctypes.POINTER(tagWINDOWINFO)
    # LPWINDOWINFO = ctypes.POINTER(tagWINDOWINFO)
    # WINDOWINFO = tagWINDOWINFO
    wi = tagWINDOWINFO()
    wi.cbSize = ctypes.sizeof(wi)
    try:
        ctypes.windll.user32.GetWindowInfo(hWnd, ctypes.byref(wi))
    except:
        pass

    # None of these seem to return the right value, at least not in my system, but might be useful for other metrics
    # xBorder = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXBORDER)
    # xEdge = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXEDGE)
    # xSFrame = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXSIZEFRAME)
    # xFFrame = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXFIXEDFRAME)
    # hSscrollXSize = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXHSCROLL)
    # hscrollYSize = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CYHSCROLL)
    # vScrollXSize = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXVSCROLL)
    # vScrollYSize = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CYVSCROLL)
    # menuSize = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CYMENUSIZE)
    # titleSize = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CYCAPTION)
    return wi


class _SubMenuStructure(TypedDict):
    hSubMenu: int
    wID: Optional[int]
    entries: dict[str, _SubMenuStructure]
    parent: int
    rect: Optional[Rect]
    item_info: NotRequired[_MENUITEMINFO]
    shortcut: str


class Win32Window(BaseWindow):

    def __init__(self, hWnd: Union[int, str]):
        super().__init__(hWnd)

        self._hWnd = int(hWnd, base=16) if isinstance(hWnd, str) else int(hWnd)
        self._parent = win32gui.GetParent(self._hWnd)
        self._t: Optional[_SendBottom] = None
        self._kill_t = threading.Event()
        self.menu = self._Menu(self)
        self.watchdog = _WatchDog(self)

        self._hDpy: Optional[int] = None
        self._display: str = ""

    def getExtraFrameSize(self, includeBorder: bool = True) -> Tuple[int, int, int, int]:
        """
        Get the invisible space, in pixels, around the window, including or not the visible resize border (usually 1px)
        This can be useful to accurately adjust window position and size to the desired visible space
        WARNING: Windows seems to only use this offset in the X coordinates, but not in the Y ones

        :param includeBorder: set to ''False'' to avoid including resize border (usually 1px) as part of frame size
        :return: (left, top, right, bottom) frame size as a tuple of int
        """
        wi = _getWindowInfo(self._hWnd)
        xOffset = 0
        yOffset = 0
        if wi:
            xOffset = wi.cxWindowBorders
            yOffset = wi.cyWindowBorders
        if not includeBorder:
            try:
                xBorder = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CXBORDER)
                yBorder = ctypes.windll.user32.GetSystemMetrics(win32con.SM_CYBORDER)
            except:
                xBorder = 1
                yBorder = 1
            xOffset -= xBorder
            yOffset -= yBorder

        return xOffset, yOffset, xOffset, yOffset

    def getClientFrame(self) -> Rect:
        """
        Get the client area of window, as a Rect (x, y, right, bottom)
        Notice that scroll and status bars might be included, or not, depending on the application

        :return: Rect struct
        """
        wi = _getWindowInfo(self._hWnd)
        if wi:
            rcClient: Rect = cast(Rect, wi.rcClient)
        else:
            rcClient = self.rect
        return Rect(rcClient.left, rcClient.top, rcClient.right, rcClient.bottom)

    def __repr__(self) -> str:
        return '%s(hWnd=%s)' % (self.__class__.__name__, self._hWnd)

    def __eq__(self, other: object) -> bool:
        return isinstance(other, Win32Window) and self._hWnd == other._hWnd

    def close(self) -> bool:
        """
        Closes this window. This may trigger "Are you sure you want to
        quit?" dialogs or other actions that prevent the window from
        actually closing. This is identical to clicking the X button on the
        window.

        :return: ''True'' if window is closed
        """
        win32gui.PostMessage(self._hWnd, win32con.WM_CLOSE, 0, 0)
        return not win32gui.IsWindow(self._hWnd)

    def minimize(self, wait: bool = False) -> bool:
        """
        Minimizes this window

        :param wait: set to ''True'' to confirm action requested (in a reasonable time)
        :return: ''True'' if window minimized
        """
        if not self.isMinimized:
            win32gui.ShowWindow(self._hWnd, win32con.SW_MINIMIZE)
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
            win32gui.ShowWindow(self._hWnd, win32con.SW_MAXIMIZE)
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
        win32gui.ShowWindow(self._hWnd, win32con.SW_RESTORE)
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and (self.isMaximized or self.isMinimized):
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return not self.isMaximized and not self.isMinimized

    def show(self, wait: bool = False) -> bool:
        """
        If hidden or showing, shows the window on screen and in title bar

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window showed
        """
        win32gui.ShowWindow(self._hWnd, win32con.SW_SHOW)
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and not self.isVisible:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return self.isVisible

    def hide(self, wait: bool = False) -> bool:
        """
        If hidden or showing, hides the window from screen and title bar

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window hidden
        """
        win32gui.ShowWindow(self._hWnd, win32con.SW_HIDE)
        retries = 0
        while wait and retries < WAIT_ATTEMPTS and self.isVisible:
            retries += 1
            time.sleep(WAIT_DELAY * retries)
        return not self.isVisible

    def activate(self, wait: bool = False, user: bool = True) -> bool:
        """
        Activate this window and make it the foreground (focused) window

        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :param user: ignored on Windows platform
        :return: ''True'' if window activated
        """
        try:
            win32gui.SetForegroundWindow(self._hWnd)
        except:
            pass
        return self.isActive

    def resize(self, widthOffset: int, heightOffset: int, wait: bool = False) -> bool:
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

    def resizeTo(self, newWidth: int, newHeight: int, wait: bool = False) -> bool:
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

    def moveTo(self, newLeft: int, newTop: int, wait: bool = False) -> bool:
        """
        Moves the window to new coordinates on the screen.
        In a multi-display environment, you can move the window to a different monitor using the coordinates
        returned by getAllScreens()

        :param newLeft: target X coordinate to move the window to
        :param newTop: target Y coordinate to move the window to
        :param wait: set to ''True'' to wait until action is confirmed (in a reasonable time lap)
        :return: ''True'' if window moved to the given position
        """
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
        Keeps window on top of all others, except some games (not all, anyway) and media player.

        :param aot: set to ''False'' to deactivate always-on-top behavior
        :return: Always returns ''True''
        """
        # TODO: investigate how to place on top of DirectDraw exclusive mode windows (hook DirectDraw dll)
        # https://stackoverflow.com/questions/7009080/detecting-full-screen-mode-in-windows
        # https://stackoverflow.com/questions/7928308/displaying-another-application-on-top-of-a-directdraw-full-screen-application
        # https://www.codeproject.com/articles/730/apihijack-a-library-for-easy-dll-function-hooking?fid=1267&df=90&mpp=25&sort=Position&view=Normal&spc=Relaxed&select=116946&fr=73&prof=True
        # https://guidedhacking.com/threads/d3d9-hooking.8481/
        # https://stackoverflow.com/questions/25601362/transparent-window-on-top-of-immersive-full-screen-mode
        # https://stackoverflow.com/questions/17131857/python-windows-keep-program-on-top-of-another-full-screen-application
        # This can be interesting to do all of the above with Python
        # https://www.apriorit.com/dev-blog/727-win-guide-to-hooking-windows-apis-with-python
        if self._t:
            self._kill_t.set()
            self._t.join()
            self._t = None
        zorder = win32con.HWND_TOPMOST if aot else win32con.HWND_NOTOPMOST
        win32gui.SetWindowPos(self._hWnd, zorder, 0, 0, 0, 0, win32con.SWP_NOMOVE | win32con.SWP_NOSIZE |
                                                              win32con.SWP_NOACTIVATE)
        return True

    def alwaysOnBottom(self, aob: bool = True) -> bool:
        """
        Keeps window below of all others, but on top of desktop icons and keeping all window properties

        :param aob: set to ''False'' to deactivate always-on-bottom behavior
        :return: ''True'' if command succeeded
        """
        if aob:
            win32gui.SetWindowPos(self._hWnd, win32con.HWND_BOTTOM, 0, 0, 0, 0, win32con.SWP_NOSIZE | win32con.SWP_NOMOVE | win32con.SWP_NOACTIVATE)
            # There is no HWND_BOTTOMMOST (similar to TOPMOST), so it won't keep window below all others as desired
            # May be catching WM_WINDOWPOSCHANGING event? Not sure if possible for a "foreign" window, and seems really complex
            # https://stackoverflow.com/questions/64529896/attach-keyboard-hook-to-specific-window
            # https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setlayeredwindowattributes
            # TODO: Try to find other smarter methods to keep window at the bottom
            ret = True
            if self._t is None:
                self._kill_t.clear()
                self._t = _SendBottom(self._hWnd, self._kill_t)
                self._t.daemon = True
                self._t.start()
        else:
            if self._t:
                self._kill_t.set()
                self._t.join()
                self._t = None
            ret = self.sendBehind(sb=False)
        return ret

    def lowerWindow(self) -> bool:
        """
        Lowers the window to the bottom so that it does not obscure any sibling windows

        :return: Always returns ''True''
        """
        win32gui.SetWindowPos(self._hWnd, win32con.HWND_BOTTOM, 0, 0, 0, 0,
                                       win32con.SWP_NOSIZE | win32con.SWP_NOMOVE | win32con.SWP_NOACTIVATE)
        return True

    def raiseWindow(self) -> bool:
        """
        Raises the window to top so that it is not obscured by any sibling windows.

        :return: Always returns ''True''
        """
        win32gui.SetWindowPos(self._hWnd, win32con.HWND_TOP, 0, 0, 0, 0,
                                       win32con.SWP_NOSIZE | win32con.SWP_NOMOVE)
        return True

    def sendBehind(self, sb: bool = True) -> bool:
        """
        Sends the window to the very bottom, below all other windows, including desktop icons.
        It may also cause that the window does not accept focus nor keyboard/mouse events as well as
        make the window disappear from taskbar and/or pager.

        :param sb: set to ''False'' to bring the window back to front
        :return: ''True'' if window sent behind desktop icons
        """
        # https://www.codeproject.com/Articles/856020/Draw-Behind-Desktop-Icons-in-Windows-plus
        if sb:
            def getWorkerW() -> List[int]:

                thelist: List[int] = []

                def findit(hwnd: int, ctx: Any):
                    p = win32gui.FindWindowEx(hwnd, None, "SHELLDLL_DefView", "")
                    if p != 0:
                        thelist.append(win32gui.FindWindowEx(None, hwnd, "WorkerW", ""))

                win32gui.EnumWindows(findit, None)
                return thelist

            self._parent = win32gui.GetParent(self._hWnd)
            progman = win32gui.FindWindow("Progman", None)
            win32gui.SendMessageTimeout(progman, 0x052C, 0, 0, win32con.SMTO_NORMAL, 1000)
            workerw = getWorkerW()
            ret = 0
            if workerw:
                ret = win32gui.SetParent(self._hWnd, workerw[0])
        else:
            ret = win32gui.SetParent(self._hWnd, self._parent)
            win32gui.DefWindowProc(self._hWnd, 0x0128, 3 | 0x4, 0)
            win32gui.RedrawWindow(self._hWnd, win32gui.GetWindowRect(self._hWnd), 0, 0)  # type: ignore[arg-type]  # pyright: ignore[reportUnknownMemberType, reportGeneralTypeIssues]  # We expect an error here
        return ret != 0

    def acceptInput(self, setTo: bool):
        """Toggles the window transparent to input and focus

        :param setTo: True/False to toggle window transparent to input and focus
        :return: None
        """
        exStyle = win32api.GetWindowLong(self._hWnd, win32con.GWL_EXSTYLE)
        if setTo:
            win32api.SetWindowLong(self._hWnd, win32con.GWL_EXSTYLE, exStyle & ~win32con.WS_EX_TRANSPARENT)
        else:
            win32api.SetWindowLong(self._hWnd, win32con.GWL_EXSTYLE, exStyle | win32con.WS_EX_TRANSPARENT)

    def getAppName(self) -> str:
        """
        Get the name of the app current window belongs to

        :return: name of the app as string
        """
        # https://stackoverflow.com/questions/550653/cross-platform-way-to-get-pids-by-process-name-in-python
        pID: int = win32process.GetWindowThreadProcessId(self._hWnd)[1]
        name: str = self.title
        for app in _getAllApps(tryToFilter=False):
            if int(app[0]) == pID:
                name = str(app[1])
                break
        return name

    def getParent(self) -> int:
        """
        Get the handle of the current window parent. It can be another window or an application

        :return: handle of the window parent
        """
        return win32gui.GetParent(self._hWnd) or 0

    def setParent(self, parent: int) -> bool:
        """
        Current window will become child of given parent
        WARNIG: Not implemented in AppleScript (not possible in macOS for foreign (other apps') windows)

        :param parent: window id to set as current window parent
        :return: ''True'' if current window is now child of given parent
        """
        if win32gui.IsWindow(parent):
            win32gui.SetParent(self._hWnd, parent)
        return bool(self.isChild(parent))

    def getChildren(self) -> List[int]:
        """
        Get the children handles of current window

        :return: list of handles
        """
        return _findWindowHandles(parent=self._hWnd)

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
        ret = win32process.GetWindowThreadProcessId(self._hWnd)
        if ret and len(ret) > 1:
            return ret[1]
        return None

    def isParent(self, child: int) -> bool:
        """
        Check if current window is parent of given window (handle)

        :param child: handle of the window you want to check if the current window is parent of
        :return: ''True'' if current window is parent of the given window
        """
        return bool(child and win32gui.GetParent(child) == self._hWnd)
    isParentOf = isParent  # isParentOf is an alias of isParent method

    def isChild(self, parent: int) -> bool:
        """
        Check if current window is child of given window/app (handle)

        :param parent: handle of the window/app you want to check if the current window is child of
        :return: ''True'' if current window is child of the given window
        """
        return parent == self.getParent()
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
        return bool(win32gui.IsIconic(self._hWnd) != 0)

    @property
    def isMaximized(self) -> bool:
        """
        Check if current window is currently maximized

        :return: ``True`` if the window is maximized
        """
        state = win32gui.GetWindowPlacement(self._hWnd)
        return bool(state[1] == win32con.SW_SHOWMAXIMIZED)

    @property
    def isActive(self) -> bool:
        """
        Check if current window is currently the active, foreground window

        :return: ``True`` if the window is the active, foreground window
        """
        return bool(win32gui.GetForegroundWindow() == self._hWnd)

    @property
    def title(self) -> str:
        """
        Get the current window title, as string

        :return: title as a string
        """
        name = win32gui.GetWindowText(self._hWnd)
        if isinstance(name, bytes):
            name = name.decode()
        return name or ""

    @property
    def visible(self) -> bool:
        """
        Check if current window is visible (minimized windows are also visible)

        :return: ``True`` if the window is currently visible
        """
        return bool(win32gui.IsWindowVisible(self._hWnd) != 0)

    # Must cast because mypy thinks the property is a callable
    # https://github.com/python/mypy/issues/2563
    # https://github.com/python/mypy/issues/11619
    # https://github.com/python/mypy/issues/13975
    isVisible: bool = cast(bool, visible)  # isVisible is an alias for the visible property.

    @property
    def isAlive(self) -> bool:
        """
        Check if window (and application) still exists (minimized and hidden windows are included as existing)

        :return: ''True'' if window exists
        """
        return bool(win32gui.IsWindow(self._hWnd) != 0)

    # @property
    # def isAlerting(self) -> bool:
    #     import pywinauto
    #     def _getFileDescription(hWnd: int) -> str:
    #         # https://stackoverflow.com/questions/31118877/get-application-name-from-exe-file-in-python
    #
    #         _: int = 0
    #         pid: int = 0
    #         _, pid = win32process.GetWindowThreadProcessId(hWnd)
    #         hProc: int = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.PROCESS_VM_READ, 0, pid)
    #         exeName: str = win32process.GetModuleFileNameEx(hProc, 0)
    #
    #         description: str = "unknown"
    #         try:
    #             res: List[Tuple[int, int]] = win32api.GetFileVersionInfo(exeName, '\\VarFileInfo\\Translation')  # type: ignore[func-returns-value]
    #             if res:
    #                 ret: Tuple[int, int] = res[0]
    #                 language, codepage = ret
    #                 stringFileInfo: str = u'\\StringFileInfo\\%04X%04X\\%s' % (language, codepage, "FileDescription")
    #                 desc: str = win32api.GetFileVersionInfo(exeName, stringFileInfo)  # type: ignore[func-returns-value]
    #                 if desc:
    #                     description = desc
    #         except:
    #             pass
    #         return description
    #
    #     def _find_taskbar_icon() -> None | Rect:
    #
    #         exStyle: int = win32api.GetWindowLong(self._hWnd, win32con.GWL_EXSTYLE)
    #         owner: int = win32gui.GetWindow(self._hWnd, win32con.GW_OWNER)
    #         if exStyle & win32con.WS_EX_APPWINDOW != 0 or owner != 0:
    #             return None
    #
    #         name: str = _getFileDescription(self._hWnd)
    #
    #         try:
    #             # app: pywinauto.Application = pywinauto.application.Application().connect(path="explorer")
    #             # sysTray: pywinauto.application.WindowSpecification = app.ShellTrayWnd.TaskBar
    #             app: pywinauto.Application = pywinauto.Application(backend="uia").connect(path="explorer.exe")
    #             sysTray: pywinauto.WindowSpecification = app.window(class_name="Shell_TrayWnd")
    #             w: pywinauto.WindowSpecification = sysTray.child_window(title_re=name, found_index=0)
    #             ret: Rect = w.rectangle()
    #             return Rect(ret.left, ret.top, ret.right, ret.bottom)
    #         except:
    #             return None
    #
    #     def _intToRGBA(color: int) -> Tuple[int, int, int, int]:
    #         r: int = color & 255
    #         g: int = (color >> 8) & 255
    #         b: int = (color >> 16) & 255
    #         a: int = 255
    #         if color > _intfromRGBA((255, 255, 255, 0)):
    #             a = (color >> 24) & 255
    #         return r, g, b, a
    #
    #     def _intfromRGBA(rgba):
    #         r = rgba[0]
    #         g = rgba[1]
    #         b = rgba[2]
    #         a = rgba[3]
    #         RGBint = (a << 24) + (r << 16) + (g << 8) + b
    #         return RGBint
    #
    #     iconRect: Rect = _find_taskbar_icon()
    #     if iconRect:
    #
    #         xPos: int = iconRect.left + int((iconRect.right - iconRect.left) / 2)
    #         color: int = 0
    #         desktop: int = win32gui.GetDesktopWindow()
    #         dc = win32gui.GetWindowDC(desktop)
    #         for i in range(50, 54):
    #             color += win32gui.GetPixel(dc, xPos, iconRect.top + i)
    #         win32gui.ReleaseDC(desktop, dc)
    #         # Not sure if GetSysColor returns colors from taskbar and which value to use to query
    #         # flashColor = win32gui.GetSysColor(win32con.COLOR_BTNHIGHLIGHT)
    #         # This color is the highlight color for windows, titles and other elements, not the one we seek
    #         # pcrColorization = wintypes.DWORD()
    #         # pfOpaqueBlend = wintypes.BOOL()
    #         # ctypes.windll.dwmapi.DwmGetColorizationColor(ctypes.byref(pcrColorization), ctypes.byref(pfOpaqueBlend))
    #         # flashColor = pcrColorization.value
    #         flashColor = 10787327  # This value (255, 153, 164) is totally empirical. Find a way to retrieve it!!!!
    #
    #         if color / 4 == flashColor:
    #             return True
    #         else:
    #             return False
    #     else:
    #         return False

    class _Menu:

        def __init__(self, parent: Win32Window):
            self._parent = parent
            self._hWnd = parent.getHandle()
            self._hMenu = win32gui.GetMenu(self._hWnd)
            self._menuStructure: dict[str, _SubMenuStructure] = {}
            self._sep = "|&|"

        def getMenu(self, addItemInfo: bool = False) -> dict[str, _SubMenuStructure]:
            """
            Loads and returns Menu options, sub-menus and related information, as dictionary.

            It is HIGHLY RECOMMENDED you pre-load the Menu struct by explicitly calling getMenu()
            before invoking any other action.

            :param addItemInfo: if ''True'', adds win32 MENUITEMINFO struct to the output
            :return: python dictionary with MENU struct

            Output Format:
                Key:
                    item (option or sub-menu) title

                Values:
                    "parent":
                        parent sub-menu handle (main menu handle for level-0 items)
                    "hSubMenu":
                        item handle (!= 0 for sub-menu items only)
                    "wID":
                        item ID (required for other actions, e.g. clickMenuItem())
                    "rect":
                        Rect struct of the menu item (relative to window position)
                    "item_info" (optional):
                        win32 MENUITEMINFO struct containing all available menu item info
                    "shortcut":
                        shortcut to menu item, if any
                    "entries":
                        sub-items within the sub-menu (if any)
            """

            def findit(parent: int, level: str = "", parentRect: Optional[Rect] = None):

                option = self._menuStructure
                if level:
                    for section in level.split(self._sep)[1:]:
                        option = cast("dict[str, _SubMenuStructure]", option[section])

                for i in range(win32gui.GetMenuItemCount(parent)):
                    item_info: Optional[_MENUITEMINFO] = self._getMenuItemInfo(hSubMenu=parent, itemPos=i)
                    if not item_info or not item_info.text or item_info.hSubMenu is None:
                        continue
                    text = item_info.text.split("\t")
                    title = (text[0].replace("&", "")) or "separator"
                    shortcut = "" if len(text) < 2 else text[1]
                    rect = self._getMenuItemRect(hSubMenu=parent, itemPos=i, relative=True, parentRect=parentRect)
                    option[title] = {"parent": parent, "hSubMenu": item_info.hSubMenu, "wID": item_info.wID,
                                     "shortcut": shortcut, "rect": rect, "entries": {}}
                    if addItemInfo:
                        option[title]["item_info"] = item_info
                    findit(item_info.hSubMenu, level + self._sep + title + self._sep + "entries", rect)

            if self._hMenu:
                findit(self._hMenu)
            return self._menuStructure

        def clickMenuItem(self, itemPath: Optional[Sequence[str]] = None, wID: Optional[int] = 0) -> bool:
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
            itemID = 0
            if self._hMenu:
                if wID:
                    itemID = wID
                elif itemPath:
                    if not self._menuStructure:
                        self.getMenu()
                    option = self._menuStructure
                    for item in itemPath[:-1]:
                        if item in option:
                            option = option[item]["entries"]
                        else:
                            option = {}
                            break

                    if option and itemPath[-1] in option:
                        itemID = cast(int, option[itemPath[-1]]["wID"])

                if itemID:
                    win32gui.PostMessage(self._hWnd, win32con.WM_COMMAND, itemID, 0)
                    found = True

            return found

        def getMenuInfo(self, hSubMenu: int = 0) -> Optional[_MENUINFO]:
            """
            Returns the MENUINFO struct of the given sub-menu or main menu if none given

            :param hSubMenu: id of the sub-menu entry (as returned by getMenu() method)
            :return: win32 MENUINFO struct
            """
            if not hSubMenu:
                hSubMenu = self._hMenu

            menu_info = None
            if hSubMenu:
                buf = win32gui_struct.EmptyMENUINFO()
                win32gui.GetMenuInfo(self._hMenu, buf)
                menu_info = win32gui_struct.UnpackMENUINFO(buf)
            return menu_info

        def getMenuItemCount(self, hSubMenu: int = 0) -> int:
            """
            Returns the number of items within a menu (main menu if no sub-menu given)

            :param hSubMenu: id of the sub-menu entry (as returned by getMenu() method)
            :return: number of items as int
            """
            if not hSubMenu:
                hSubMenu = self._hMenu
            return win32gui.GetMenuItemCount(hSubMenu)

        def getMenuItemInfo(self, hSubMenu: int, wID: int) -> Optional[_MENUITEMINFO]:
            """
            Returns the MENUITEMINFO struct for the given menu item

            :param hSubMenu: id of the sub-menu entry (as returned by :meth: getMenu())
            :param wID: id of the window within menu struct (as returned by :meth: getMenu())
            :return: win32 MENUITEMINFO struct
            """
            item_info = None
            if self._hMenu:
                buf, _extras = win32gui_struct.EmptyMENUITEMINFO()
                win32gui.GetMenuItemInfo(hSubMenu, wID, False, buf)
                item_info = win32gui_struct.UnpackMENUITEMINFO(buf)
            return item_info

        def _getMenuItemInfo(self, hSubMenu: int, itemPos: int) -> Optional[_MENUITEMINFO]:
            item_info = None
            if self._hMenu:
                buf, _extras = win32gui_struct.EmptyMENUITEMINFO()
                win32gui.GetMenuItemInfo(hSubMenu, itemPos, True, buf)
                item_info = win32gui_struct.UnpackMENUITEMINFO(buf)
            return item_info

        def getMenuItemRect(self, hSubMenu: int, wID: int) -> Rect:
            """
            Get the Rect struct (left, top, right, bottom) of the given Menu option

            :param hSubMenu: id of the sub-menu entry (as returned by :meth: getMenu())
            :param wID: id of the window within menu struct (as returned by :meth: getMenu())
            :return: Rect struct
            """
            def findit(menu: dict[str, _SubMenuStructure], hSubMenu: int, wID: Optional[int]) -> int:

                menuFound: List[dict[str, _SubMenuStructure]] = [{}]

                def findMenu(inMenu: dict[str, _SubMenuStructure], hSubMenu: int):

                    for key in inMenu:
                        if inMenu[key]["hSubMenu"] == hSubMenu:
                            menuFound[0] = inMenu[key]["entries"]
                            break
                        elif "entries" in inMenu[key]:
                            findMenu(inMenu[key]["entries"], hSubMenu)

                findMenu(menu, hSubMenu)
                subMenu = menuFound[0]
                itemPos = -1
                for key in subMenu:
                    itemPos += 1
                    if subMenu[key]["wID"] == wID:
                        return itemPos
                return itemPos

            if not self._menuStructure and self._hMenu:
                self.getMenu()

            itemPos = findit(self._menuStructure, hSubMenu, wID)
            ret = Rect(0, 0, 0, 0)
            if self._hMenu and 0 <= itemPos < self.getMenuItemCount(hSubMenu=hSubMenu):
                result, (x, y, r, b) = win32gui.GetMenuItemRect(self._hWnd, hSubMenu, itemPos)
                if result != 0:
                    ret = Rect(x, y, r, b)
            return ret

        def _getMenuItemRect(self, hSubMenu: int, itemPos: int, parentRect: Optional[Rect] = None, relative: bool = False) -> Optional[Rect]:
            ret = None
            if self._hMenu and hSubMenu and 0 <= itemPos < self.getMenuItemCount(hSubMenu=hSubMenu):
                result, (x, y, r, b) = win32gui.GetMenuItemRect(self._hWnd, hSubMenu, itemPos)
                if result != 0:
                    if relative:
                        x = abs(abs(x) - abs(self._parent.left))
                        y = abs(abs(y) - abs(self._parent.top))
                        r = abs(abs(r) - abs(self._parent.left))
                        b = abs(abs(b) - abs(self._parent.top))
                    if parentRect:
                        x = parentRect.left
                    ret = Rect(int(x), int(y), int(r), int(b))
            return ret


class _SendBottom(threading.Thread):

    def __init__(self, hWnd: int, kill: threading.Event, interval: float = 0.5):
        threading.Thread.__init__(self)
        self._hWnd = hWnd
        self._kill = kill
        self._interval = interval

    def _isLast(self) -> bool:
        # handles = _findMainWindowHandles()
        handles = _findWindowHandles()
        last = None if not handles else handles[-1]
        return self._hWnd == last

    def run(self):
        while not self._kill.is_set() and win32gui.IsWindow(self._hWnd):
            if not self._isLast():
                win32gui.SetWindowPos(self._hWnd, win32con.HWND_BOTTOM, 0, 0, 0, 0,
                                      win32con.SWP_NOSIZE | win32con.SWP_NOMOVE | win32con.SWP_NOACTIVATE)
            self._kill.wait(self._interval)


# Futile attempt to get the taskbar buttons handles without using pywinauto (but useful as "hard" pywin32 example!)
# def _getSysTrayButtons(window_class: str = ""):
#     # https://stackoverflow.com/questions/31068541/how-to-use-win32gui-or-similar-to-click-an-other-window-toolstrip1-item-button
#     # https://github.com/yinkaisheng/Python-UIAutomation-for-Windows
#
#     import commctrl
#
#     def _getSystemTrayHandle():
#
#         # handles = _findWindowHandles()
#         # # CANDIDATES:
#         # """
#         # 65882  ReBarWindow32 (220, 1380, 2316, 1440)  -> Main suspect. Find a way to query for all possible content!!!
#         # 7 FOUND!!! 1
#         # 9 FOUND!!! 1
#         # 10 FOUND!!! 1
#         # 65884 Aplicaciones en ejecución MSTaskSwWClass (220, 1380, 2316, 1440)  -> Son of 65882 (ReBarWindow32)
#         # 65890 Aplicaciones en ejecución MSTaskListWClass (220, 1380, 2316, 1440) -> Son of 65884
#         # """
#         # # OTHER CANDIDATES:
#         # """
#         # 65832  Shell_TrayWnd (0, 1380, 5120, 1440)
#         # 65838 Inicio Start (55, 1380, 110, 1440)
#         # 65844  TrayNotifyWnd (2385, 1380, 5120, 1440)
#         # 66282 DesktopWindowXamlSource Windows.UI.Composition.DesktopWindowContentBridge (2385, 1380, 5120, 1440)
#         # 66272 DesktopWindowXamlSource Windows.UI.Composition.DesktopWindowContentBridge (0, 1380, 5120, 1440)
#         # """
#         # win32gui.SendMessage(hWnd, commctrl.TB_BUTTONCOUNT, None, None)
#         # doesn't work (furthermore, it actually interacts with some windows!!!).
#         # Find another thing to look for, not buttons
#         # for hWnd in handles:
#         #     klass = win32gui.GetClassName(hWnd)
#         #     geom = win32gui.GetWindowRect(hWnd)
#         #     if geom[1] == 1380 and geom[3] == 1440:
#         #         print(hWnd, win32gui.GetWindowText(hWnd), klass, geom)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.TB_BUTTONCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("1 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.TVM_GETCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("2 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.TCM_GETITEMCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("3 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.LVM_GETITEMCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("4 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.HDM_GETITEMCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("5 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.LVM_GETSELECTEDCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("6 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.RB_GETBANDCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("7 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.TCM_GETROWCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("8 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.TTM_GETTOOLCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("9 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.RB_GETROWCOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("10 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.TVM_GETVISIBLECOUNT, None, None)
#         #         if numIcons > 0:
#         #             print("11 FOUND!!!", numIcons)
#         #         numIcons = win32gui.SendMessage(hWnd, commctrl.LVM_GETCOUNTPERPAGE, None, None)
#         #         if numIcons > 0:
#         #             print("12 FOUND!!!", numIcons)
#
#         hWndTray = win32gui.FindWindow("Shell_TrayWnd", None)
#         if hWndTray:
#             hWndTray = win32gui.FindWindowEx(hWndTray, 0, "TrayNotifyWnd", None)
#             if hWndTray:
#                 hWndTray = win32gui.FindWindowEx(hWndTray, 0, "SysPager", None)
#                 if hWndTray:
#                     hWndTray = win32gui.FindWindowEx(hWndTray, 0, "ToolbarWindow32", None)
#                     if hWndTray:
#                         return hWndTray
#         return None
#
#     class TBBUTTON64(ctypes.Structure):
#         _pack_ = 1
#         _fields_ = [
#             ('iBitmap', ctypes.c_int),
#             ('idCommand', ctypes.c_int),
#             ('fsState', ctypes.c_ubyte),
#             ('fsStyle', ctypes.c_ubyte),
#             ('bReserved', ctypes.c_ubyte * 6),
#             ('dwData', ctypes.c_ulong),
#             ('iString', ctypes.c_int),
#         ]
#
#     class TBBUTTON32(ctypes.Structure):
#         _pack_ = 1
#         _fields_ = [
#             ('iBitmap', ctypes.c_int),
#             ('idCommand', ctypes.c_int),
#             ('fsState', ctypes.c_ubyte),
#             ('fsStyle', ctypes.c_ubyte),
#             ('bReserved', ctypes.c_ubyte * 2),
#             ('dwData', ctypes.c_ulong),
#             ('iString', ctypes.c_int),
#         ]
#
#     class RECT(ctypes.Structure):
#         _pack_ = 1
#         _fields_ = [
#             ('left', ctypes.c_ulong),
#             ('top', ctypes.c_ulong),
#             ('right', ctypes.c_ulong),
#             ('bottom', ctypes.c_ulong),
#         ]
#
#     # get the handle to the system tray
#     # hWnd = _getSystemTrayHandle()                             # -> This has no buttons (probably it's not the taskbar)
#     if not window_class:
#         window_class = "ReBarWindow32"
#     # hWnd = _findWindowHandles(window_class=window_class)[0]   # -> This returns more than one handle
#     hWnd = _findWindowHandles(window_class=window_class)[0]     # -> This is promissing, but has no buttons
#
#     # get the count of icons in the tray
#     numIcons = ctypes.windll.user32.SendMessageA(hWnd, commctrl.TB_BUTTONCOUNT, 0, 0)
#
#     # allocate memory within the system tray
#     pid = ctypes.c_ulong()
#     ctypes.windll.user32.GetWindowThreadProcessId(hWnd, ctypes.byref(pid))
#     hProcess = ctypes.windll.kernel32.OpenProcess(win32con.PROCESS_ALL_ACCESS, 0, pid)
#
#     # init our toolbar button and a handle to it
#     if struct.calcsize("P") * 8 == 64:
#         lpPointer = ctypes.windll.kernel32.VirtualAllocEx(hProcess, None, ctypes.sizeof(TBBUTTON64), win32con.MEM_COMMIT, win32con.PAGE_READWRITE)
#         tbButton = TBBUTTON64()
#     else:
#         lpPointer = ctypes.windll.kernel32.VirtualAllocEx(hProcess, None, ctypes.sizeof(TBBUTTON32), win32con.MEM_COMMIT, win32con.PAGE_READWRITE)
#         tbButton = TBBUTTON32()
#     tbRead = ctypes.c_ulong(0)
#     butHandle = ctypes.c_int()
#     butRead = ctypes.c_ulong(0)
#
#     buttons = []
#     for i in range(numIcons):
#         # query the button into the memory we allocated
#         ctypes.windll.user32.SendMessageA(hWnd, commctrl.TB_GETBUTTON, i, lpPointer)
#         # read the memory into our button struct
#         ctypes.windll.kernel32.ReadProcessMemory(hProcess, lpPointer, ctypes.byref(tbButton), ctypes.sizeof(tbButton), ctypes.byref(tbRead))
#         # read the 1st 4 bytes from the dwData into the butHandle var
#         # these first 4 bytes contain the handle to the button
#         ctypes.windll.kernel32.ReadProcessMemory(hProcess, tbButton.dwData, ctypes.byref(butHandle), ctypes.sizeof(butHandle), ctypes.byref(butRead))
#
#         # use TB_RECT message to get the position and size of the systray icon
#         idx_rect = RECT()
#         rectRead = ctypes.c_ulong(0)
#         rlpPointer = ctypes.windll.kernel32.VirtualAllocEx(hProcess, None, ctypes.sizeof(RECT), win32con.MEM_COMMIT, win32con.PAGE_READWRITE)
#         ctypes.windll.user32.SendMessageA(hWnd, commctrl.TB_GETRECT, tbButton.idCommand, rlpPointer)
#         ctypes.windll.kernel32.ReadProcessMemory(hProcess, rlpPointer, ctypes.byref(idx_rect), ctypes.sizeof(idx_rect), ctypes.byref(rectRead))
#         # xpos = int((idx_rect.right - idx_rect.left) / 2) + idx_rect.left
#         # ypos = int((idx_rect.bottom - idx_rect.top) / 2) + idx_rect.top
#         # lParam = ypos << 16 | xpos
#
#         # get the pid that created the button
#         butPid = ctypes.c_ulong()
#         ctypes.windll.user32.GetWindowThreadProcessId(butHandle, ctypes.byref(butPid))
#
#         buttons.append((tbButton.idCommand, idx_rect, butPid))
#
#     return hWnd, buttons
