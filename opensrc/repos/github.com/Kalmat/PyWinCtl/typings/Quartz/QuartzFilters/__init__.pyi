# pyright: reportUnknownParameterType=false, reportMissingParameterType=false, reportMissingTypeArgument=false
from typing import Any

import Foundation as Foundation  # type: ignore  # pyright: ignore


def sel32or64(a, b): ...
def selAorI(a, b): ...


misc: Any
constants: str
enums: str
r: Any
protocols: Any
expressions: Any


class NSDisabledAutomaticTermination:
    def __init__(self, reason) -> None: ...
    def __enter__(self) -> None: ...
    def __exit__(self, exc_type, exc_val, exc_tb): ...


class NSDisabledSuddenTermination:
    def __enter__(self) -> None: ...
    def __exit__(self, exc_type, exc_val, exc_tb): ...
