import std/options

import ../types

import semtable
import semerror
import semutils

method inferType*(tb: SymbolTable, exp: Expr): TypeSpecifer {.base.} =
    echo "reached base of inferType"
    quit QuitFailure

method inferType*(tb: SymbolTable, exp: PrimaryExpr): TypeSpecifer =
    case exp.kind:
    of pkParen:
        return inferType(tb, exp.exprValue)
    of pkBool:
        return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeBool)
    of pkInt:
        return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeInt)
    of pkString:
        return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeString)
    of pkIden:
        let name = exp.strValue
        if ctxDefined(tb, name):
            let sym = lookup(tb, name).get
            case sym.kind
            of skVar:
                return singleTypeSpecifier(name, sym.skVar)
            of skFunc:
                functionAsValue()
        else:
            undeclared(name)

method inferType*(tb: SymbolTable, exp: AdditiveExpr): TypeSpecifer =
    let lhstype = inferType(tb, exp.lhs)
    discard inferType(tb, exp.rhs)

    return lhstype

method inferType*(tb: SymbolTable, exp: MultiplicativeExpr): TypeSpecifer =
    let lhstype = inferType(tb, exp.lhs)
    discard inferType(tb, exp.rhs)

    return lhstype


method inferType*(tb: SymbolTable, exp: EqualityExpr): TypeSpecifer =
    return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeBool)

method inferType*(tb: SymbolTable, exp: RelationalExpr): TypeSpecifer =
    return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeBool)

method inferType*(tb: SymbolTable, exp: LogicalAndExpr): TypeSpecifer =
    return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeBool)

method inferType*(tb: SymbolTable, exp: LogicalOrExpr): TypeSpecifer =
    return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeBool)

method inferType*(tb: SymbolTable, exp: AssignmentExpr): TypeSpecifer =
    return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeUnset)

method inferType*(tb: SymbolTable, exp: CallExpr): TypeSpecifer =
    let name = exp.callee.strValue
    if ctxDefined(tb, name):
        let sym = lookup(tb, name).get
        case sym.kind
        of skFunc:
            return sym.skFunc.returnType
        else:
            valueAsFunction()
    else:
        undeclared(name)
