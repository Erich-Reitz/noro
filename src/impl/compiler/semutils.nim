import std/options

import ../types
import semerror

proc isMarkedConst*(vds: seq[VariableDeclSpecifier]): bool =
    for vs in vds:
        case vs.kind
        of vdsKindTypeQualifier:
            if vs.typeQualifier == tqConst:
                return true
        else:
            discard
    return false

proc isMarkedForbidden*(vds: seq[VariableDeclSpecifier]): bool =
    for vs in vds:
        case vs.kind
        of vdsKindTypeQualifier:
            if vs.typeQualifier == tqForbid:
                return true
        else:
            discard
    return false

proc singleTypeSpecifier*(varname: string, vds: seq[
        VariableDeclSpecifier]): TypeSpecifer =
    var ts: Option[TypeSpecifer] = none(TypeSpecifer)

    for vs in vds:
        case vs.kind
        of vdsKindTypeSpecifer:
            if ts.isSome:
                multipleTypeSpecifiers(varname)
            else:
                ts = some(vs.typeSpec)
        else:
            discard

    if ts.isNone:
        noTypeSpecifiers(varname)

    ts.get

func `==`*(a: TypeSpecifer, b: TypeSpecifer): bool =
    if a.kind != b.kind:
        return false
    case a.kind:
    of tsKindBnType:
        return a.builtinType == b.builtinType
    of tsKindDecl:
        return a.typeDecl == b.typeDecl

func `==`*(a: TypeSpecifer, b: BuiltinType): bool =
    if a.kind != tsKindBnType:
        return false
    return a.builtinType == b

