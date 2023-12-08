type
  BinOp* = enum
    binOpPlus, binOpMinus, binOpMul, binOpDiv, binOpAnd, binOpOr

  RelOp* = enum
    relOpEq, relOpNe, relOpLt, relOpGt, relOpLe, relOpGe, relOpPrimary

  AstExprKind = enum
    akConst, akName, akTemp, akBinOp, akMem, akCall,
    akMove, akJump, akCJump, akSeq, akLabel, akFrame, akNop, akReturn, akStringLit

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

  AstStringLit* = object
    val*: string


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
    of akStringLit:
      stringLitExpr*: AstStringLit
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
    params*: int
