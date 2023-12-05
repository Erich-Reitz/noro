import ast

type
    InstructionKind* = enum
        ikMov, ikAdd, ikMinus, ikIntEqual, ikLabelCreate, ikLabelJumpTo,
            ikConditionalJump, ikReturn

    ValueKind* = enum
        vkConst, vkTemp

    Value* = ref object
        case kind*: ValueKind
        of vkConst:
            val*: int
        of vkTemp:
            label*: string



    Instruction* = object
        kind*: InstructionKind
        dst*: Value
        src*: Value
        src2*: Value

    Frame* = object
        name*: string
        instructions*: seq[Instruction]

func constInt*(val: int): Value =
    return Value(kind: vkConst, val: val)

func fromTempIntToLabelValue*(val: int): Value =
    let str = "t" & $val
    return Value(kind: vkTemp, label: str)

func toLabel*(s: string): Value =
    return Value(kind: vkTemp, label: s)

proc `$`*(v: Value): string =
    case v.kind
    of vkConst:
        return $v.val
    of vkTemp:
        return v.label

var temps = 0
proc generateInstruction(node: AstBinOp): seq[Instruction]

proc processSide(side: AstNode, instructions: var seq[Instruction]): Value =
    case side.kind
    of akConst:
        return side.constExpr.val.constInt
    of akTemp:
        return side.tempExpr.label.toLabel
    of akBinOp:
        let newDest = temps.fromTempIntToLabelValue
        let sideInstructions = generateInstruction(side.binOpExpr)
        instructions.add(sideInstructions)
        return newDest
    of akLabel:
        return side.labelExpr.label.toLabel
    else:
        echo "Unsupported expression side: ", side.kind
        quit QuitFailure

proc generateInstruction(node: AstBinOp): seq[Instruction] =
    var instructions = newSeq[Instruction]()
    let dest = temps.fromTempIntToLabelValue
    inc temps

    proc handleBinOpPlus(leftVal, rightVal: Value) =
        instructions.add(Instruction(kind: ikAdd, dst: dest, src: leftVal,
                src2: rightVal))

    proc handleBinOpMinus(leftVal, rightVal: Value) =
        instructions.add(Instruction(kind: ikMinus, dst: dest, src: leftVal,
                src2: rightVal))



    let leftVal = processSide(node.left, instructions)
    let rightVal = processSide(node.right, instructions)

    case node.op
    of binOpPlus:
        handleBinOpPlus(leftVal, rightVal)
    of binOpMinus:
        handleBinOpMinus(leftVal, rightVal)
    else:
        echo "Unsupported operation: ", node.op
        quit QuitFailure

    return instructions




proc generateInstruction(node: AstMove): seq[Instruction] =
    var instructions = newSeq[Instruction]()
    let dest = node.dst.tempExpr.label.toLabel

    case node.src.kind
    of akConst:
        let src = node.src.constExpr.val.constInt
        instructions.add(Instruction(kind: ikMov, dst: dest, src: src))
    of akTemp:
        let src = node.src.tempExpr.label.toLabel
        instructions.add(Instruction(kind: ikMov, dst: dest, src: src))
    of akBinOp:
        # when we have a binop on the right hand side, we need to generate a temp
        let rhsTempInt = temps.fromTempIntToLabelValue
        # generate bin op instructions, with the temp as the destination
        let binopinstructions = generateInstruction(node.src.binOpExpr)
        # add the binop instructions to the main instructions
        instructions.add(binopinstructions)
        # add the move instruction to move the temp to the destination
        instructions.add(Instruction(kind: ikMov, dst: dest, src: rhsTempInt))
    else:
        echo "Unsupported expression: ", node.src.kind
        quit QuitFailure

    return instructions



proc genCJumpInstructions(a: AstCJump): seq[Instruction] =
    var instructions = newSeq[Instruction]()

    let leftDest = temps.fromTempIntToLabelValue
    inc temps
    let leftValue = processSide(a.left, instructions)

    instructions.add(Instruction(kind: ikMov, dst: leftDest, src: leftValue))

    let rightDest = temps.fromTempIntToLabelValue
    inc temps
    let rightValue = processSide(a.right, instructions)

    instructions.add(Instruction(kind: ikMov, dst: rightDest, src: rightValue))

    let compareDest = temps.fromTempIntToLabelValue
    inc temps
    instructions.add(Instruction(kind: ikIntEqual, dst: compareDest,
            src: leftDest, src2: rightDest))

    # now the conditional jumps
    let trueLabel = a.trueLabel.label.toLabel
    let falseLabel = a.falseLabel.label.toLabel

    instructions.add(Instruction(kind: ikConditionalJump, dst: compareDest,
            src: trueLabel, src2: falseLabel))

    return instructions



proc generateInstruction(node: AstReturn): seq[Instruction] =
    var instructions = newSeq[Instruction]()

    let retExp = node.exp

    let retDest = Value(kind: vkTemp, label: "ret")

    let retValue = processSide(retExp, instructions)

    instructions.add(Instruction(kind: ikMov, dst: retDest, src: retValue))

    return instructions




proc genfuncbody(funcbody: seq[AstNode]): seq[Instruction] =
    var instructions = newSeq[Instruction]()
    for n in funcbody:
        case n.kind:
        of akMove:
            instructions.add(generateInstruction(n.moveExpr))
        of akSeq:
            instructions.add(genfuncbody(n.seqExpr.stmts))
        of akCJump:
            let jumpInstruction = genCJumpInstructions(n.cjumpExpr)
            instructions.add(jumpInstruction)
        of akLabel:
            let label = n.labelExpr.label.toLabel
            instructions.add(Instruction(kind: ikLabelCreate, dst: label))
        of akJump:
            let label2 = n.jumpExpr.label.label.toLabel
            instructions.add(Instruction(kind: ikLabelJumpTo, dst: label2))
        of akNop:
            discard
        of akReturn:
            instructions.add(generateInstruction(n.returnExpr))
        else:
            echo "Unsupported expression: ", n.kind
            quit QuitFailure

    return instructions




proc instructgen*(nodes: seq[AstNode]): seq[Frame] =
    var frames = newSeq[Frame]()

    for node in nodes:
        case node.kind
        of akFrame:
            let name = node.frameExpr.name
            let params = node.frameExpr.params

            # so also when you have a frame, you have params.
            # i placed these in special p0, p1 IR..
            # so we need "glue instructions" to move these from their assembly registers to 
            # the stack
            # so we need to generate instructions for these params
            # and add them to the frame instructions
            let registers = @["rdi", "rsi", "rdx", "rcx", "r8", "r9"]

            var paramInstructions = newSeq[Instruction]()
            
            for p in 0..params-1:

                let paramDest = Value(kind: vkTemp, label: "p" & $p)
                let paramSrc = Value(kind: vkTemp, label: registers[p])
                
                paramInstructions.add(Instruction(kind: ikMov, dst: paramDest, src: paramSrc))
            
            let bodyinstructinos = genfuncbody(node.frameExpr.body.stmts)

            

            frames.add(Frame(name: name, instructions: paramInstructions & bodyinstructinos))

            

        else: discard


    return frames
