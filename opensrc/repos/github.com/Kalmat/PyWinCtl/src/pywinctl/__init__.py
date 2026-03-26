#!/usr/bin/python
# -*- coding: utf-8 -*-

__all__ = [
    "version", "Re",
    # OS Specifics
    "Window", "checkPermissions", "getActiveWindow", "getActiveWindowTitle", "getWindowsWithTitle",
    "getAllWindows", "getAllTitles", "getAppsWithName", "getAllAppsNames", "getAllAppsWindowsTitles",
    "getAllWindowsDict", "getTopWindowAt", "getWindowsAt", "displayWindowsUnderMouse",
    "getAllScreens", "getScreenSize", "getWorkArea", "getMousePos"
]

__version__ = "0.4.01"


def version(numberOnly: bool = True) -> str:
    """Returns the current version of PyWinCtl module, in the form ''x.x.xx'' as string"""
    return ("" if numberOnly else "PyWinCtl-")+__version__


from ._main import (Re, Window, checkPermissions, getActiveWindow,
                    getActiveWindowTitle, getAllAppsNames, getAllAppsWindowsTitles,
                    getAllTitles, getAllWindows, getAppsWithName, getWindowsWithTitle,
                    getAllWindowsDict, getTopWindowAt, getWindowsAt, displayWindowsUnderMouse,
                    getAllScreens, getScreenSize, getWorkArea, getMousePos
                    )
