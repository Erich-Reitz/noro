import std/options

import ../types
import semerror

proc singleTypeSpecifier*(vds: seq[VariableDeclSpecifier]): TypeSpecifer =
    var ts: Option[TypeSpecifer] = none(TypeSpecifer)

    for vs in vds:
        case vs.kind
        of vdsKindTypeSpecifer:
            if ts.isSome:
                multipleTypeSpecifiers()
            else:
                ts = some(vs.typeSpec)
        else:
            discard

    if ts.isNone:
        noTypeSpecifiers()

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

