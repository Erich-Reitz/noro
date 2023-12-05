

proc strrepeat(s: string, n: int): string =
  result = ""
  for i in 0..<n:
    result.add(s)

type
  BinOp* = enum
    binOpPlus, binOpMinus, binOpMul, binOpDiv, binOpAnd, binOpOr

  RelOp* = enum
    relOpEq, relOpNe, relOpLt, relOpGt, relOpLe, relOpGe, relOpPrimary

  AstExprKind = enum
    akConst, akName, akTemp, akBinOp, akMem, akCall,
    akMove, akJump, akCJump, akSeq, akLabel, akFrame, akNop, akReturn

  AstConst* = object
    val*: int

  AstName* = object
    label*: string

  AstTemp* = object
    label*: string

  AstBinOp* = object
    op*: BinOp
    left*, right*: AstNode

  AstMem* = object
    exp: AstNode

  AstCall* = object
    fun*: string
    args*: seq[AstNode]




  AstNode* = ref object
    case kind*: AstExprKind
    of akConst:
      constExpr*: AstConst
    of akName:
      nameExpr*: AstName
    of akTemp:
      tempExpr*: AstTemp
    of akBinOp:
      binOpExpr*: AstBinOp
    of akMem:
      memExpr*: AstMem
    of akCall:
      callExpr*: AstCall
    of akMove:
      moveExpr*: AstMove
    of akJump:
      jumpExpr*: AstJump
    of akCJump:
      cjumpExpr*: AstCJump
    of akSeq:
      seqExpr*: AstSeq
    of akLabel:
      labelExpr*: AstLabel
    of akFrame:
      frameExpr*: AstFrame
    of akReturn:
      returnExpr*: AstReturn
    of akNop:
      discard

  AstMove* = object
    dst*: AstNode
    src*: AstNode


  AstJump* = object
    label*: AstLabel

  AstReturn* = object
    exp*: AstNode


  AstCJump* = object
    op*: RelOp
    left*: AstNode
    right*: AstNode
    trueLabel*: AstLabel
    falseLabel*: AstLabel

  AstSeq* = object
    stmts*: seq[AstNode]

  AstLabel* = object
    label*: string

  AstFrame* = object
    name*: string
    body*: AstSeq
    localvars*: int





proc debugPrintBinOp(op: BinOp, depth: int = 0) =
  let indent = "  " & strrepeat(" ", depth)

  case op
  of binOpPlus:
    echo indent, "binOpPlus"
  of binOpMinus:
    echo indent, "binOpMinus"
  of binOpMul:
    echo indent, "binOpMul"
  of binOpDiv:
    echo indent, "binOpDiv"
  of binOpAnd:
    echo indent, "binOpAnd"
  of binOpOr:
    echo indent, "binOpOr"

proc debugPrintRelOp(op: RelOp, depth: int = 0) =
  let indent = "  " & strrepeat(" ", depth)

  case op
  of relOpEq:
    echo indent, "relOpEq"
  of relOpNe:
    echo indent, "relOpNe"
  of relOpLt:
    echo indent, "relOpLt"
  of relOpGt:
    echo indent, "relOpGt"
  of relOpLe:
    echo indent, "relOpLe"
  of relOpGe:
    echo indent, "relOpGe"
  of relOpPrimary:
    echo indent, "relOpPrimary"

proc debugPrint*(node: AstNode, depth: int = 0): void
proc debugPrint(node: AstSeq, depth: int = 0): void =
  let indent = "  " & strrepeat(" ", depth)

  echo indent, "AstSeq"
  for stm in node.stmts:
    debugPrint(stm, depth + 2)

proc debugPrint(node: AstLabel, depth: int = 0): void =
  let indent = "  " & strrepeat(" ", depth)

  echo indent, "AstLabel: ", node.label


proc debugPrint*(node: AstNode, depth: int = 0): void =
  let indent = "  " & strrepeat(" ", depth)

  case node.kind
  of akConst:
    echo indent, "AstConst: ", node.constExpr.val
  of akName:
    echo indent, "AstName: ", node.nameExpr.label
  of akTemp:
    echo indent, "AstTemp: ", node.tempExpr.label
  of akBinOp:
    echo indent, "AstBinOp: ", node.binOpExpr.op
    debugPrint(node.binOpExpr.left, depth + 2)
    debugPrint(node.binOpExpr.right, depth + 2)
  of akMem:
    echo indent, "AstMem"
    debugPrint(node.memExpr.exp, depth + 2)
  of akCall:
    echo indent, "AstCall: ", node.callExpr.fun
    for arg in node.callExpr.args:
      debugPrint(arg, depth + 2)
  of akMove:
    echo indent, "AstMove"
    debugPrint(node.moveExpr.dst, depth + 2)
    debugPrint(node.moveExpr.src, depth + 2)
  of akJump:
    echo indent, "AstJump"
    debugPrint(node.jumpExpr.label, depth + 2)
  of akCJump:
    echo indent, "AstCJump: ", node.cjumpExpr.op
    debugPrint(node.cjumpExpr.left, depth + 2)
    debugPrint(node.cjumpExpr.right, depth + 2)
    echo indent, "  trueLabel: ", node.cjumpExpr.trueLabel
    echo indent, "  falseLabel: ", node.cjumpExpr.falseLabel
  of akSeq:
    echo indent, "AstSeq"
    for stmt in node.seqExpr.stmts:
      debugPrint(stmt, depth + 2)
  of akLabel:
    echo indent, "AstLabel: ", node.labelExpr.label
  of akFrame:
    echo indent, "AstFrame: ", node.frameExpr.name
    debugPrint(node.frameExpr.body, depth + 2)
  of akReturn:
    echo indent, "AstReturn"
    debugPrint(node.returnExpr.exp, depth + 2)
  of akNop:
    echo indent, "AstNop"
