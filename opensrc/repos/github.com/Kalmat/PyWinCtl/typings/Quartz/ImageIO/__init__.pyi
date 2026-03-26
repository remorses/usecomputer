# pyright: reportUnknownParameterType=false, reportMissingParameterType=false, reportMissingTypeArgument=false
from typing import Any

CFArrayCreate: Any
CFArrayCreateMutable: Any
CFDictionaryCreate: Any
CFDictionaryCreateMutable: Any
CFSetCreate: Any
CFSetCreateMutable: Any
kCFTypeArrayCallBacks: Any
kCFTypeDictionaryKeyCallBacks: Any
kCFTypeDictionaryValueCallBacks: Any
kCFTypeSetCallBacks: Any
def CFCopyLocalizedString(key, comment): ...
def CFCopyLocalizedStringFromTable(key, tbl, comment): ...
def CFCopyLocalizedStringFromTableInBundle(key, tbl, bundle, comment): ...
def CFCopyLocalizedStringWithDefaultValue(key, tbl, bundle, value, comment): ...
def CFSTR(strval): ...
def sel32or64(a, b): ...
def selAorI(a, b): ...


misc: Any
constants: str
enums: str
functions: Any
aliases: Any
cftypes: Any
expressions: Any
