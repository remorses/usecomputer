# https://github.com/ronaldoussoren/pyobjc/issues/198
# https://github.com/ronaldoussoren/pyobjc/issues/417
# https://github.com/ronaldoussoren/pyobjc/issues/419

from typing import Any

NSWindowStyleMaskTitled: int
NSWindowStyleMaskClosable: int
NSWindowStyleMaskMiniaturizable: int
NSWindowStyleMaskResizable: int

class NSObject:
    @staticmethod
    def alloc()-> Any: ...
    def __getattr__(self, name: str) -> Any: ...


class NSWorkspace(NSObject):
    @staticmethod
    def sharedWorkspace() -> Any: ...
    def __getattr__(self, name: str) -> Any: ...


class NSScreen(NSObject):
    @staticmethod
    def screens() -> list[Any]: ...
    def __getattr__(self, name: str) -> Any: ...


class NSMakeRect(NSObject):
    def __init__(self, left: float, top: float, width: float, height: float) -> None: ...
    def __getattr__(self, name: str) -> Any: ...


class NSApplication(NSObject):
    @staticmethod
    def sharedApplication() -> Any: ...
    def __getattr__(self, name: str) -> Any: ...


class NSApp(NSApplication):
    def __getattr__(self, name: str) -> Any: ...


class NSRunningApplication(NSObject):
    def __getattr__(self, name: str) -> Any: ...


class NSWindow(NSObject):
    @staticmethod
    def alloc() -> Any: ...
    def __getattr__(self, name: str) -> Any: ...


class NSBackingStoreBuffered(NSObject):
    def __getattr__(self, name: str) -> Any: ...


class WindowDelegate(NSObject):
    def __getattr__(self, name:str) -> Any: ...