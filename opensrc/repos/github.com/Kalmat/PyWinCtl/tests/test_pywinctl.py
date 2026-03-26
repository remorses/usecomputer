#!/usr/bin/python
# -*- coding: utf-8 -*-
from __future__ import annotations

import subprocess
import sys
import time

import pywinctl


def test_basic():

    print("PLATFORM:", sys.platform)
    print()
    print("MONITORS:")
    monitors = pywinctl.getAllScreens()
    for monitor in monitors.keys():
        print(monitor, monitors[monitor])
        print()
    print("ALL WINDOWS")
    print(pywinctl.getAllTitles())
    print()
    print("ALL APPS & WINDOWS")
    print(pywinctl.getAllAppsWindowsTitles())
    print()

    if sys.platform == "win32":
        subprocess.Popen('notepad')
        time.sleep(2)

        testWindows = [pywinctl.getActiveWindow()]
        assert len(testWindows) == 1

        npw = testWindows[0]
        wait = True
        timelap = 0.50

        basic_test(npw, wait, timelap)

    elif sys.platform == "linux":
        subprocess.Popen('gedit')
        time.sleep(2)

        testWindows = [pywinctl.getActiveWindow()]
        assert len(testWindows) == 1

        npw = testWindows[0]
        wait = True
        timelap = 0.50

        basic_test(npw, wait, timelap)

    elif sys.platform == "darwin":
        if not pywinctl.checkPermissions(activate=True):
            exit()
        subprocess.Popen(['touch', 'test.py'])
        time.sleep(2)
        subprocess.Popen(['open', '-a', 'TextEdit', 'test.py'])
        time.sleep(5)

        testWindows = pywinctl.getWindowsWithTitle('test.py')
        assert len(testWindows) == 1

        npw = testWindows[0]
        wait = True
        timelap = 0.50

        basic_test(npw, wait, timelap)
        subprocess.Popen(['rm', 'test.py'])

    else:
        raise NotImplementedError('PyWinCtl currently does not support this platform. If you have useful knowledge, please contribute! https://github.com/Kalmat/pywinctl')


def basic_test(npw: pywinctl.Window | None, wait: bool, timelap: float):
    assert npw is not None

    def test_moveresize(attr, value):
        setattr(npw, attr, value)
        time.sleep(timelap)
        new_value = getattr(npw, attr)
        assert new_value == value, f"Error while changing the window using the attribute {attr}. Expected value {value}, instead found {new_value}"

    def moveCB(pos):
        print("WINDOW MOVED!!! New topleft (x, y) position:", pos)

    def resizeCB(size):
        print("WINDOW RESIZED!!! New size (width, height):", size)

    def visibleCB(isVisible):
        print("WINDOW VISIBILITY CHANGED!!! New visibility value:", isVisible)

    def activeCB(isActive):
        print("WINDOW FOCUS CHANGED!!!", isActive)

    print("ACTIVE WINDOW:", npw.title, "/", npw.box)
    print()
    print("CLIENT FRAME:", npw.getClientFrame(), "EXTRA FRAME:", npw.getExtraFrameSize())
    print()
    print("MINIMIZED:", npw.isMinimized, "MAXIMIZED:", npw.isMaximized, "ACTIVE:", npw.isActive, "ALIVE:",
          npw.isAlive, "VISIBLE:", npw.isVisible)
    print()
    print("APP NAME:", npw.getAppName())
    print()
    dpys = npw.getDisplay()
    for dpy in dpys:
        print("WINDOW DISPLAY:", dpy)
        print()

    # Test maximize/minimize/restore
    if npw.isMaximized:  # Make sure it starts un-maximized
        npw.restore(wait=wait)
    assert not npw.isMaximized

    print("MAXIMIZE")
    npw.maximize(wait=wait)
    time.sleep(timelap)
    assert npw.isMaximized
    print("RESTORE")
    npw.restore(wait=wait)
    time.sleep(timelap)
    assert not npw.isMaximized

    print("MINIMIZE")
    npw.minimize(wait=wait)
    time.sleep(timelap)
    assert npw.isMinimized
    print("RESTORE")
    npw.restore(wait=wait)
    time.sleep(timelap)
    assert not npw.isMinimized

    # Test resizing
    print("RESIZE TO", 600, 400)
    npw.resizeTo(600, 400, wait=wait)
    time.sleep(timelap)
    assert npw.size == (600, 400)
    assert npw.width == 600
    assert npw.height == 400

    print("RESIZE", "+10", "+20")
    npw.resizeRel(10, 20, wait=wait)
    assert npw.size == (610, 420)
    assert npw.width == 610
    assert npw.height == 420

    # Test moving
    print("MOVE TO", 150, 154)
    npw.moveTo(150, 154, wait=wait)
    assert npw.topleft == (150, 154)
    assert npw.left == 150
    assert npw.top == 154
    assert npw.right == 760
    assert npw.bottom == 574
    assert npw.bottomright == (760, 574)
    assert npw.bottomleft == (150, 574)
    assert npw.topright == (760, 154)

    print("MOVE", "+1", "+2")
    npw.moveRel(1, 2, wait=wait)
    assert npw.topleft == (151, 156)
    assert npw.left == 151
    assert npw.top == 156
    assert npw.right == 761
    assert npw.bottom == 576
    assert npw.bottomright == (761, 576)
    assert npw.bottomleft == (151, 576)
    assert npw.topright == (761, 156)

    # Move via the properties
    npw.resizeTo(601, 401, wait=wait)
    npw.moveTo(100, 250, wait=wait)
    npw.watchdog.start(movedCB=moveCB, resizedCB=resizeCB, isVisibleCB=visibleCB, isActiveCB=activeCB)

    print("MOVE LEFT", 200)
    test_moveresize('left', 200)
    print("MOVE RIGHT", 860)
    test_moveresize('right', 860)
    print("MOVE TOP", 200)
    test_moveresize('top', 200)
    print("MOVE BOTTOM", 800)
    test_moveresize('bottom', 800)
    print("MOVE TOPLEFT", 300, 400)
    test_moveresize('topleft', (300, 400))
    print("MOVE TOPRIGHT", 800, 400)
    test_moveresize('topright', (800, 400))
    print("MOVE BOTTOMLEFT", 300, 700)
    test_moveresize('bottomleft', (300, 700))
    print("MOVE BOTTOMRIGHT", 850, 900)
    test_moveresize('bottomright', (850, 900))
    print("MOVE MIDLEFT", 300, 400)
    test_moveresize('midleft', (300, 400))
    print("MOVE MIDRIGHT", 770, 400)
    test_moveresize('midright', (770, 400))
    print("MOVE MIDTOP", 800, 400)
    test_moveresize('midtop', (800, 400))
    print("MOVE MIDBOTTOM", 700, 700)
    test_moveresize('midbottom', (700, 700))
    print("MOVE CENTER", 760, 400)
    test_moveresize('center', (760, 400))
    print("MOVE CENTERX", 900)
    test_moveresize('centerx', 900)
    print("MOVE CENTERY", 600)
    test_moveresize('centery', 600)
    print("RESIZE WIDTH", 620)
    test_moveresize('width', 620)
    print("RESIZE HEIGHT", 410)
    test_moveresize('height', 410)
    print("RESIZE", 640, 420)
    test_moveresize('size', (640, 420))

    # Test window stacking
    print("LOWER WINDOW")
    lowered = npw.lowerWindow()
    time.sleep(timelap*3)
    # assert lowered, 'Window has not been lowered'

    print("RAISE WINDOW")
    raised = npw.raiseWindow()
    time.sleep(timelap)
    # assert raised, 'Window has not been raised'

    if sys.platform != "darwin":
        print("SEND BEHIND")
        npw.sendBehind()
        time.sleep(timelap)
        print("RESTORE")
        npw.sendBehind(False)
        time.sleep(timelap)

    print("ALWAYS ON TOP")
    npw.alwaysOnTop()
    time.sleep(timelap)
    print("RESTORE")
    npw.alwaysOnTop(False)
    time.sleep(timelap)

    print("ALWAYS AT BOTTOM")
    npw.alwaysOnBottom()
    time.sleep(timelap*3)
    print("RESTORE")
    npw.alwaysOnBottom(False)
    time.sleep(timelap)

    npw.watchdog.stop()

    # Test parent methods
    print("PARENT INFO")
    parent = npw.getParent()
    if parent:
        print("WINDOW PARENT:", parent, npw.isChild(parent))
        assert npw.isChild(parent)
    children = npw.getChildren()
    for child in children:
        if child and isinstance(child, int):
            print("WINDOW CHILD:", child, npw.isParent(child))

    # Test menu options
    print("MENU INFO (WORKING IN WINDOWS 10 AND MACOS, BUT NOT IN WINDOWS 11 NOR LINUX)")
    if sys.platform in ("win32", "darwin"):
        # Show "About" dialog. Using numbers instead of menu/option names since they are language-dependent
        if sys.platform == "darwin":
            targetSubmenu = 1
            targetOption = 0
        else:
            targetSubmenu = 4
            targetOption = 2
        menu = npw.menu.getMenu()
        submenu = {}
        for i, key in enumerate(menu):
            if i == targetSubmenu:
                submenu = menu[key].get("entries", {})
                break
        option = {}
        for i, key in enumerate(submenu):
            if i == targetOption:
                option = submenu[key]
                break
        if option:
            print("CLICK OPTION")
            npw.menu.clickMenuItem(wID=option.get("wID", ""))
            time.sleep(5)

    # Test closing
    print("CLOSE WINDOW")
    npw.close()


if __name__ == '__main__':
    test_basic()
