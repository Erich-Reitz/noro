import std/options
import std/tables
import ../types

import semtable
import inferexpr
import semerror
import semutils

var currentFunctionName = ""

proc assertIdenticalBinaryIntTypes(lhstype: TypeSpecifer, rhstype: TypeSpecifer,
        expectedType: TypeSpecifer) =
    if lhstype != rhstype:
        typeMismatch(lhstype, rhstype)

    if lhstype != expectedType:
        typeMismatch(lhstype, expectedType)

    if lhstype != binTypeInt:
        typeMismatch(lhstype, TypeSpecifer(kind: tsKindBnType,
                builtinType: binTypeInt))


proc assertIdenticalBinaryBoolTypes(lhstype: TypeSpecifer,
        rhstype: TypeSpecifer, expectedType: TypeSpecifer) =
    if lhstype != rhstype:
        typeMismatch(lhstype, rhstype)

    if lhstype != expectedType:
        typeMismatch(lhstype, expectedType)

    if lhstype != binTypeBool:
        typeMismatch(lhstype, TypeSpecifer(kind: tsKindBnType,
                builtinType: binTypeBool))


proc assertIntType(anyType: TypeSpecifer, expectedType: TypeSpecifer) =
    if anyType != expectedType:
        typeMismatch(anyType, expectedType)

    if anyType != binTypeInt:
        typeMismatch(anyType, TypeSpecifer(kind: tsKindBnType,
                builtinType: binTypeInt))


proc assertExpectedTypeIsBool(expectedType: TypeSpecifer) =
    if expectedType != binTypeBool:
        typeMismatch(expectedType, TypeSpecifer(kind: tsKindBnType,
                builtinType: binTypeBool))


method typecheckExpr(tb: SymbolTable, exp: Expr,
        expectedType: TypeSpecifer) {.base.} =
    echo "reached base of typecheckExpr!"
    quit QuitFailure

method typecheckExpr(tb: SymbolTable, exp: PrimaryExpr,
        expectedType: TypeSpecifer) =
    case exp.kind:
    of pkIden:
        let name = exp.strValue
        if ctxDefined(tb, name):
            let sym = lookup(tb, name).get
            case sym.kind
            of skVar:
                let definedType = singleTypeSpecifier(name, sym.skVar)
                if definedType != expectedType:
                    typeMismatch(expectedType, definedType)

            of skFunc:
                functionAsValue()
        else:
            undeclared(name)
    of pkInt:
        if expectedType != binTypeInt:
            typeMismatch(expectedType, TypeSpecifer(kind: tsKindBnType,
                    builtinType: binTypeInt))
    of pkString:
        if expectedType != binTypeString:
            typeMismatch(expectedType, TypeSpecifer(kind: tsKindBnType,
                    builtinType: binTypeString))
    of pkBool:
        if expectedType != binTypeBool:
            typeMismatch(expectedType, TypeSpecifer(kind: tsKindBnType,
                    builtinType: binTypeBool))
    of pkParen:
        typecheckExpr(tb, exp.exprValue, expectedType)

method typecheckExpr(tb: SymbolTable, exp: Expr) {.base.} =
    echo "reached base!"
    quit QuitFailure

method typecheckExpr(tb: SymbolTable, exp: PrimaryExpr) =
    case exp.kind:
    of pkParen:
        typecheckExpr(tb, exp.exprValue)
    else:
        discard

method typecheckExpr(tb: SymbolTable, exp: AssignmentExpr) = 
    let lhs = cast[PrimaryExpr](exp.lhs)
    let name = lhs.strValue
    
    let lookup = lookup(tb, name)
    if lookup.isNone:
        undeclared(name)
    else:
        let sym = lookup.get
        case sym.kind
        of skVar:
            if isMarkedConst(sym.skVar):
                constReassign(name)
            else:
                typecheckExpr(tb, exp.rhs, singleTypeSpecifier(name, sym.skVar))
        of skFunc:
            functionAsValue()

   

method typecheckExpr(tb: SymbolTable, exp: CallExpr) =
    let name = exp.callee.strValue
    if ctxDefined(tb, name):
        let sym = lookup(tb, name).get
        case sym.kind
        of skVar:
            valueAsFunction()
        of skFunc:
            let funcDef = sym.skFunc
            if len(funcDef.paramsDeclList) != len(exp.args):
                wrongNumberOfArguments(name, len(funcDef.paramsDeclList), len(exp.args))
            else:
                for i in 0..len(funcDef.paramsDeclList)-1:
                    let param = funcDef.paramsDeclList[i]
                    let arg = exp.args[i]
                    typecheckExpr(tb, arg, singleTypeSpecifier(param.name, param.specifiers))
    else:
        undeclared(name)


proc typecheckArthmeticExpr(tb: SymbolTable, lhs: Expr, rhs: Expr) =
    typecheckExpr(tb, lhs)
    typecheckExpr(tb, rhs)

    let lhstype = inferType(tb, lhs)
    let rhstype = inferType(tb, rhs)

    assertIdenticalBinaryIntTypes(lhstype, rhstype, TypeSpecifer(
            kind: tsKindBnType, builtinType: binTypeInt))

proc typecheckBooleanExpr(tb: SymbolTable, lhs: Expr, rhs: Expr) =
    typecheckExpr(tb, lhs)
    typecheckExpr(tb, rhs)

    let lhstype = inferType(tb, lhs)
    let rhstype = inferType(tb, rhs)

    assertIdenticalBinaryBoolTypes(lhstype, rhstype, TypeSpecifer(
            kind: tsKindBnType, builtinType: binTypeBool))

method typecheckExpr(tb: SymbolTable, exp: AdditiveExpr, ) =
    typecheckArthmeticExpr(tb, exp.lhs, exp.rhs)

method typecheckExpr(tb: SymbolTable, exp: RelationalExpr) =
    typecheckArthmeticExpr(tb, exp.lhs, exp.rhs)

method typecheckExpr(tb: SymbolTable, exp: MultiplicativeExpr) =
    typecheckArthmeticExpr(tb, exp.lhs, exp.rhs)



method typecheckExpr(tb: SymbolTable, exp: EqualityExpr) =
    typecheckExpr(tb, exp.lhs)
    typecheckExpr(tb, exp.rhs)

    let lhstype = inferType(tb, exp.lhs)
    let rhstype = inferType(tb, exp.rhs)

    if lhstype != rhstype:
        typeMismatch(lhstype, rhstype)

    if lhstype.kind != tsKindBnType:
        echo "cannot compare non-builtin types"
        quit QuitFailure


method typecheckExpr(tb: SymbolTable, exp: LogicalAndExpr) =
    typecheckBooleanExpr(tb, exp.lhs, exp.rhs)

method typecheckExpr(tb: SymbolTable, exp: LogicalOrExpr) =
    typecheckBooleanExpr(tb, exp.lhs, exp.rhs)


method typecheckExpr(tb: SymbolTable, exp: AssignmentExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)

method typecheckExpr(tb: SymbolTable, exp: CallExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)
    let inferedType = inferType(tb, exp)

    if inferedType != expectedType:
        typeMismatch(expectedType, inferedType)



method typecheckExpr(tb: SymbolTable, exp: MultiplicativeExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)
    let inferedType = inferType(tb, exp)
    assertIntType(inferedType, expectedType)

method typecheckExpr(tb: SymbolTable, exp: AdditiveExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)

    let inferedType = inferType(tb, exp)

    assertIntType(inferedType, expectedType)


method typecheckExpr(tb: SymbolTable, exp: RelationalExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)
    assertExpectedTypeIsBool(expectedType)

method typecheckExpr(tb: SymbolTable, exp: EqualityExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)
    assertExpectedTypeIsBool(expectedType)

method typecheckExpr(tb: SymbolTable, exp: LogicalAndExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)
    assertExpectedTypeIsBool(expectedType)

method typecheckExpr(tb: SymbolTable, exp: LogicalOrExpr,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exp)
    assertExpectedTypeIsBool(expectedType)

proc typecheckInitDeclarator(tb: SymbolTable, iDecl: InitDeclarator,
        expectedType: TypeSpecifer) =
    let initExpr = iDecl.initializer

    typecheckExpr(tb, initExpr, expectedType)


proc typecheckDeclaration(tb: SymbolTable, decl: Declaration) =
    let name = decl.initDeclarator.name
    
    try:
        let typespec = singleTypeSpecifier(name, decl.specifiers)
        typecheckInitDeclarator(tb, decl.initDeclarator, typespec)
    except NoroTypeError as e:
        echo "error duing initalization of <", name, ">: ", e.msg
        quit QuitFailure
        
    let sym = Symbol(kind: skVar, skVar: decl.specifiers)
    tb.table[decl.initDeclarator.name] = sym


proc typecheckStatement(tb: SymbolTable, stm: Stmt, expectedType: TypeSpecifer)

proc typecheckExprStmt(tb: SymbolTable, exprStmt: ExprStmt,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, exprStmt.ex, expectedType)


proc typecheckReturnStmt(tb: SymbolTable, returnStmt: ReturnStmt,
        expectedType: TypeSpecifer) =
    try:
        typecheckExpr(tb, returnStmt.ex, expectedType)
    except NoroTypeError as e:
        echo "error duing return statement of <", currentFunctionName, ">: ", e.msg
        quit QuitFailure

proc typecheckIfStmt(tb: SymbolTable, ifStmt: IfStmt,
        expectedType: TypeSpecifer) =
    typecheckExpr(tb, ifStmt.cond, TypeSpecifer(kind: tsKindBnType,
            builtinType: binTypeBool))
    typecheckStatement(tb, ifStmt.thenStmt, expectedType)
    if ifStmt.elseStmt != nil:
        typecheckStatement(tb, ifStmt.elseStmt, expectedType)


proc typecheckCompoundStmt(tb: SymbolTable, cStmt: CompoundStmt,
        expectedType: TypeSpecifer) =

    for bi in cStmt.blockItems:
        case bi.kind
        of blkDeclaration:
            typecheckDeclaration(tb, bi.declaration)
        of blkStatement:
            typecheckStatement(tb, bi.statement, expectedType)


proc typecheckStatement(tb: SymbolTable, stm: Stmt,
        expectedType: TypeSpecifer) =
    case stm.kind:
    of skExpr:
        typecheckExprStmt(tb, stm.exprStmt, expectedType)
    of skReturn:
        typecheckReturnStmt(tb, stm.returnStmt, expectedType)
    of skIf:
        typecheckIfStmt(tb, stm.ifStmt, expectedType)
    of skCompound:
        typecheckCompoundStmt(tb, stm.compoundStmt, expectedType)




proc typecheckFuncDef(tb: SymbolTable, funcDef: FuncDef) =
    let newTb = SymbolTable(table: initTable[string, Symbol](), parent: tb)

    for param in funcdef.paramsDeclList:
        let sym = Symbol(kind: skVar, skVar: param.specifiers)
        newTb.table[param.name] = sym

    let retType = funcdef.returnType

    currentFunctionName = funcdef.name

    # check body
    typecheckCompoundStmt(newTb, funcdef.body, retType)


proc typecheckExternalDecl(tb: SymbolTable, decl: ExternalDecl) =
    case decl.kind
    of externalDeclKindFuncDef:
        typecheckFuncDef(tb, decl.funcDef)
    of externalDeclKindDeclaration:
        typecheckDeclaration(tb, decl.decl)

proc typecheck*(tb: SymbolTable, p: Program) =
    for decl in p.externalDecls:
        typecheckExternalDecl(tb, decl)
