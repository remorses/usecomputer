# pyright: reportUnknownParameterType=false, reportMissingParameterType=false, reportMissingTypeArgument=false, reportUnknownMemberType=false, reportUnknownVariableType=false
# mypy: disable-error-code=type-arg
from typing import Any, ClassVar

import objc  # type: ignore  # pyright: ignore
import objc._lazyimport  # type: ignore  # pyright: ignore

CAAnimationCalculationMode: Any
CAAnimationRotationMode: Any
CAAutoresizingMask: Any
CAConstraintAttribute: Any
CACornerMask: Any
CAEdgeAntialiasingMask: Any
CAEmitterLayerEmitterMode: Any
CAEmitterLayerEmitterShape: Any
CAEmitterLayerRenderMode: Any
CAGradientLayerType: Any
CALayerContentsFilter: Any
CALayerContentsFormat: Any
CALayerContentsGravity: Any
CALayerCornerCurve: Any
CAMediaTimingFillMode: Any
CAMediaTimingFunctionName: Any
CAScrollLayerScrollMode: Any
CAShapeLayerFillRule: Any
CAShapeLayerLineCap: Any
CAShapeLayerLineJoin: Any
CATextLayerAlignmentMode: Any
CATextLayerTruncationMode: Any
CATransitionSubtype: Any
CATransitionType: Any
CAValueFunctionName: Any
_ObjCLazyModule__aliases_deprecated: dict
_ObjCLazyModule__enum_deprecated: dict
_ObjCLazyModule__expressions: dict
_ObjCLazyModule__expressions_mapping: objc._lazyimport.GetAttrMap
_ObjCLazyModule__varmap_dct: dict
_ObjCLazyModule__varmap_deprecated: dict

def sel32or64(a, b): ...
def selAorI(a, b): ...

misc: Any
constants: str
enums: str
functions: Any
aliases: Any
r: Any
protocols: Any
expressions: Any

class CAFrameRateRange(objc._structwrapper):  # type: ignore  # pyright: ignore
    _fields: ClassVar[tuple] = ...
    __match_args__: ClassVar[tuple] = ...
    __typestr__: ClassVar[bytes] = ...
    maximum: Any
    minimum: Any
    preferred: Any
    def __init__(self, *args, **kwargs) -> None: ...
    def _asdict(self, *args, **kwargs) -> Any: ...
    def _replace(self, *args, **kwargs) -> Any: ...
    def copy(self, *args, **kwargs) -> Any: ...
    def __delattr__(self, name) -> Any: ...
    def __delitem__(self, other) -> Any: ...
    def __getitem__(self, index) -> Any: ...
    def __pyobjc_copy__(self, *args, **kwargs) -> Any: ...
    def __reduce__(self) -> Any: ...
    def __setattr__(self, name, value) -> Any: ...
    def __setitem__(self, index, object) -> Any: ...

class CATransform3D(objc._structwrapper):  # type: ignore  # pyright: ignore
    _fields: ClassVar[tuple] = ...
    __match_args__: ClassVar[tuple] = ...
    __typestr__: ClassVar[bytes] = ...
    m11: Any
    m12: Any
    m13: Any
    m14: Any
    m21: Any
    m22: Any
    m23: Any
    m24: Any
    m31: Any
    m32: Any
    m33: Any
    m34: Any
    m41: Any
    m42: Any
    m43: Any
    m44: Any
    def __init__(self, *args, **kwargs) -> None: ...
    def _asdict(self, *args, **kwargs) -> Any: ...
    def _replace(self, *args, **kwargs) -> Any: ...
    def copy(self, *args, **kwargs) -> Any: ...
    def __delitem__(self, other) -> Any: ...
    def __getitem__(self, index) -> Any: ...
    def __pyobjc_copy__(self, *args, **kwargs) -> Any: ...
    def __reduce__(self) -> Any: ...
    def __setattr__(self, name, value) -> Any: ...
    def __setitem__(self, index, object) -> Any: ...
