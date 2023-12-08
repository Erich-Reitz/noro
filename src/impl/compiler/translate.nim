import std/tables

import ../types
import ast

type Tabl = ref object
    counter: int
    table: Table[string, string]
    parent: Tabl

    labelCounter: int


proc newVar*(tb: Tabl, name: string) =
    let counter = tb.counter
    tb.counter += 1
    let varname = "v" & $counter
    tb.table[name] = varname

proc newParam*(tb: Tabl, name: string) =
    let counter = tb.counter
    tb.counter += 1
    let varname = "p" & $counter
    tb.table[name] = varname

proc dispenseLabel(tb: Tabl): int =
    let counter = tb.labelCounter
    tb.labelCounter += 1
    return counter


method translateExpression(tb: Tabl, exp: Expr): AstNode {.base.} =
    echo "base methods called for expression"
    quit QuitFailure



#   AstCall* = object
#     fun*: string
#     args*: seq[AstNode]
method translateExpression(tb: Tabl, exp: CallExpr): AstNode =
    let funName = exp.callee.strValue
    let args = exp.args

    var argNodes: seq[AstNode] = @[]
    for arg in args:
        argNodes.add(translateExpression(tb, arg))

    let callNode = AstCall(fun: funName, args: argNodes)
    return AstNode(kind: akCall, callExpr: callNode)

method translateExpression(tb: Tabl, exp: AssignmentExpr): AstNode =
    let lhs = translateExpression(tb, exp.lhs)
    let rhs = translateExpression(tb, exp.rhs)

    let res = AstMove(dst: lhs, src: rhs)

    return AstNode(kind: akMove, moveExpr: res)

method translateExpression(tb: Tabl, exp: AdditiveExpr): AstNode =
    let lhs = translateExpression(tb, exp.lhs)
    let rhs = translateExpression(tb, exp.rhs)

    if exp.op == addOpAdd:
        return AstNode(kind: akBinOp, binOpExpr: AstBinOp(left: lhs, right: rhs,
                op: binOpPlus))
    else:
        return AstNode(kind: akBinOp, binOpExpr: AstBinOp(left: lhs, right: rhs,
                op: binOpMinus))


method translateExpression(tb: Tabl, exp: MultiplicativeExpr): AstNode =
    let lhs = translateExpression(tb, exp.lhs)
    let rhs = translateExpression(tb, exp.rhs)

    if exp.op == multOpMul:
        return AstNode(kind: akBinOp, binOpExpr: AstBinOp(left: lhs, right: rhs,
                op: binOpMul))
    else:
        return AstNode(kind: akBinOp, binOpExpr: AstBinOp(left: lhs, right: rhs,
                op: binOpDiv))


method translateExpression(tb: Tabl, exp: PrimaryExpr): AstNode =
    case exp.kind:
        of pkIden:
            if exp.strValue in tb.table:
                return AstNode(kind: akTemp, tempExpr: AstTemp(label: tb.table[exp.strValue]))
            else:
                echo "Error: Identifier not found"
                quit QuitFailure

        of pkBool:
            let value = if exp.boolValue: 1 else: 0
            return AstNode(kind: akConst, constExpr: AstConst(val: value))

        of pkInt:
            return AstNode(kind: akConst, constExpr: AstConst(
                    val: exp.intValue))

        of pkString:
            return AstNode(kind: akStringLit, stringLitExpr: AstStringLit(
                    val: exp.stringValue))
        of pkParen:
            return translateExpression(tb, exp.exprValue)




proc translate(tb: Tabl, initDecl: InitDeclarator): AstNode =
    let name = initDecl.name
    let exp = initDecl.initializer
    newVar(tb, name)

    let rhs = translateExpression(tb, exp)

    let lhs = AstNode(kind: akTemp, tempExpr: AstTemp(label: tb.table[name]))

    # Move rhs to lhs
    return AstNode(kind: akMove, moveExpr: AstMove(dst: lhs, src: rhs))



proc translate(tb: Tabl, decl: Declaration): AstNode =
    let exp = translate(tb, decl.initDeclarator)
    return exp



proc translate(tb: Tabl, retstmt: ReturnStmt): AstNode =
    let exp = translateExpression(tb, retstmt.ex)

    let retNode = AstReturn(exp: exp)
    return AstNode(kind: akReturn, returnExpr: retNode)



proc translate(tb: Tabl, retstmt: ExprStmt): AstNode =
    let exp = translateExpression(tb, retstmt.ex)
    return exp


proc translate(tb: Tabl, stm: Stmt): AstNode




method relationalOperatorFromExpr(exp: Expr): RelOp {.base.} =
    echo "failed to get relational operator"
    quit QuitFailure

method relationalOperatorFromExpr(exp: PrimaryExpr): RelOp =
    return relOpPrimary


method relationalOperatorFromExpr(exp: EqualityExpr): RelOp =
    case exp.op:
    of eqOpEq:
        return relOpEq
    of eqOpNeq:
        return relOpNe

method relationalOperatorFromExpr(exp: RelationalExpr): RelOp =
    case exp.op:
    of relOpGt:
        return relOpGt
    else:
        assert false


method decomposeCondition(tb: Tabl, exp: Expr): (AstNode, AstNode,
        RelOp) {.base.} =
    echo "failed to decompose condition"
    quit QuitFailure


method decomposeCondition(tb: Tabl, exp: RelationalExpr): (AstNode, AstNode, RelOp) =
    let lhs = translateExpression(tb, exp.lhs)
    let rhs = translateExpression(tb, exp.rhs)
    let op = relationalOperatorFromExpr(exp)
    return (lhs, rhs, op)

method decomposeCondition(tb: Tabl, exp: EqualityExpr): (AstNode, AstNode, RelOp) =
    let lhs = translateExpression(tb, exp.lhs)
    let rhs = translateExpression(tb, exp.rhs)
    let op = relationalOperatorFromExpr(exp)
    return (lhs, rhs, op)


proc translateIfStmt(tb: Tabl, ifstmt: IfStmt): AstNode =
    let (lhs, rhs, op) = decomposeCondition(tb, ifstmt.cond)

    let trueLabel = "l" & $dispenseLabel(tb)

    let falseLabel = "l" & $dispenseLabel(tb)
    let endOfIfLabel = "l" & $dispenseLabel(tb)

    let cjump = AstCJump(op: op, left: lhs, right: rhs, trueLabel: AstLabel(
            label: trueLabel), falseLabel: AstLabel(label: falseLabel))
    let cjumpNode = AstNode(kind: akCJump, cjumpExpr: cjump)

    let trueBranch = translate(tb, ifstmt.thenStmt)


    let falseBranch = if ifstmt.elseStmt != nil:
                         translate(tb, ifstmt.elseStmt)
                      else:
                         AstNode(kind: akNop)

    let trueLabelNode = AstNode(kind: akLabel, labelExpr: AstLabel(
            label: trueLabel))
    let falseLabelNode = AstNode(kind: akLabel, labelExpr: AstLabel(
            label: falseLabel))
    let endOfIfLabelNode = AstNode(kind: akLabel, labelExpr: AstLabel(
            label: endOfIfLabel))

    let jumpToEnd = AstNode(kind: akJump, jumpExpr: AstJump(label: AstLabel(
            label: endOfIfLabel)))

    let seqNodes = @[
        cjumpNode,
        trueLabelNode,
        trueBranch,
        jumpToEnd,
        falseLabelNode,
        falseBranch,
        endOfIfLabelNode
    ]

    return AstNode(kind: akSeq, seqExpr: AstSeq(stmts: seqNodes))





proc translate(tb: Tabl, bi: BlockItem): AstNode =
    case bi.kind:
    of blkDeclaration:
        return translate(tb, bi.declaration)
    of blkStatement:
        return translate(tb, bi.statement)


proc translate(tb: Tabl, stm: Stmt): AstNode =
    case stm.kind:
    of skReturn:
        return translate(tb, stm.returnStmt)
    of skExpr:
        return translate(tb, stm.exprStmt)
    of skIf:
        return translateIfStmt(tb, stm.ifStmt)
    of skCompound:
        var stmts: seq[AstNode] = @[]
        for s in stm.compoundStmt.blockItems.items:
            let node = translate(tb, s)
            stmts.add(node)

        return AstNode(kind: akSeq, seqExpr: AstSeq(stmts: stmts))



proc translate(tb: Tabl, bi: BlockItem, frameNode: var AstFrame): AstNode =
    case bi.kind:
    of blkDeclaration:
        frameNode.localvars = frameNode.localvars + 1
        return translate(tb, bi.declaration)
    of blkStatement:
        return translate(tb, bi.statement)


proc translate(tb: Tabl, body: CompoundStmt, frameNode: var AstFrame): AstSeq =
    var stmts: seq[AstNode] = @[]
    for s in body.blockItems.items:
        let node = translate(tb, s, frameNode)
        stmts.add(node)

    return AstSeq(stmts: stmts)

proc translate(tb: Tabl, funcdef: FuncDef): AstNode =
    let name = funcdef.name
    let params = funcdef.paramsDeclList
    let body = funcdef.body

    var frameNode = AstFrame()
    frameNode.name = name

    for p in params:
        newParam(tb, p.name)
        frameNode.params = frameNode.params + 1

    # Translate the function body
    frameNode.body = translate(tb, body, frameNode)

    # Wrap the frame in an AstNode
    return AstNode(kind: akFrame, frameExpr: frameNode)



proc translate(tb: Tabl, externalDecl: ExternalDecl): AstNode =
    case externalDecl.kind:
    of externalDeclKindFuncDef:
        return translate(tb, externalDecl.funcdef)
    of externalDeclKindDeclaration:
        # special case for global variables
        discard



proc translate*(p: Program): seq[AstNode] =
    let tb = Tabl(counter: 0, table: initTable[string, string](), parent: nil)
    tb.labelCounter = 0
    result = @[]
    for externalDecl in p.externalDecls:
        result.add(translate(tb, externalDecl))
        tb.counter = 0
