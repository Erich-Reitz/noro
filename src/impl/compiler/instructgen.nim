import ast

import instruction
import instructutils

var temps = 0

proc generateInstruction(node: AstBinOp): seq[Instruction]
proc generateCallInstructionos(node: AstCall): seq[Instruction]

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
    of akCall:
        let newDest = temps.fromTempIntToLabelValue
        let callExpr = side.callExpr
        let callInstructions = generateCallInstructionos(callExpr)
        instructions.add(callinstructions)
        return newDest
    of akStringLit:
        let str = side.stringLitExpr.val
        let strLabel = temps.fromTempIntToLabelValue
        inc temps
        instructions.add(Instruction(kind: ikStringLabelCreate, dst: strLabel,
                src: str.toStrLitValue))

        return strLabel
    else:
        echo "Unsupported expression side: ", side.kind
        quit QuitFailure


proc generateCallInstructionos(node: AstCall): seq[Instruction] =
    let rhsTempInt = temps.fromTempIntToLabelValue
    inc temps
    let funcname = node.fun.toLabel
    var callinstructions = newSeq[Instruction]()
    var argCount = 0
    let registers = @["rdi", "rsi", "rdx", "rcx", "r8", "r9"]
    var tempResultTempLablels = newSeq[Value]()
    for arg in node.args:

        if argCount > 6:
            echo "Too many arguments, only 6 are supported"
            quit QuitFailure

        let argTemp = processSide(arg, callinstructions)
        tempResultTempLablels.add(argTemp)


        argCount += 1

    # Need to this AFTER so they aren't overwritten
    for i in 0..<argCount:
        let reg = registers[i].toLabel
        # generate an artificial move instruction to move the temp to the assembly register
        callinstructions.add(Instruction(kind: ikMov, dst: reg, src: tempResultTempLablels[i]))


    # add an instruction to invoke call
    callinstructions.add(Instruction(kind: ikCall, dst: rhsTempInt,
            src: funcname))

    return callinstructions




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

    proc handleBinOpMult(leftVal, rightVal: Value) =
        instructions.add(Instruction(kind: ikMult, dst: dest, src: leftVal,
                src2: rightVal))


    let leftVal = processSide(node.left, instructions)
    let rightVal = processSide(node.right, instructions)

    case node.op
    of binOpPlus:
        handleBinOpPlus(leftVal, rightVal)
    of binOpMinus:
        handleBinOpMinus(leftVal, rightVal)
    of binOpMul:
        handleBinOpMult(leftVal, rightVal)
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
    of akCall:
        # when we have a call on the right hand side, we need to generate a temp
        let rhsTempInt = temps.fromTempIntToLabelValue
        # generate call instructions, with the temp as the destination
        let callExpr = node.src.callExpr
        # evaluate the arguments, then move them to assembly registers
        let callInstructions = generateCallInstructionos(callExpr)

        # add the call instructions to the main instructions
        instructions.add(callinstructions)
        let moveAfterCallI = Instruction(kind: ikMov, dst: dest, src: rhsTempInt)
        echo "moveAfterCallI: ", moveAfterCallI
        instructions.add(moveAfterCallI)
    of akStringLit:
        let str = node.src.stringLitExpr.val
        let strLabel = temps.fromTempIntToLabelValue
        inc temps
        instructions.add(Instruction(kind: ikStringLabelCreate, dst: strLabel,
                src: str.toStrLitValue))
        instructions.add(Instruction(kind: ikMov, dst: dest, src: strLabel))
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

    # TODO: where change
    if a.op == relOpEq:
        instructions.add(Instruction(kind: ikIntEqual, dst: compareDest,
                src: leftDest, src2: rightDest))
    elif a.op == relOpGt:
        instructions.add(Instruction(kind: ikIntGt, dst: compareDest,
                src: leftDest, src2: rightDest))
    else:
        echo "Unsupported operation: ", a.op
        assert false

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
            let genInstructions = generateInstruction(n.moveExpr)
            instructions.add(genInstructions)
        of akSeq:
            let akSeq = genfuncbody(n.seqExpr.stmts)
            instructions.add(akSeq)
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
        of akCall:
            let callExpr = n.callExpr
            let callInstructions = generateCallInstructionos(callExpr)
            instructions.add(callinstructions)
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
            var paramInstructions = newSeq[Instruction]()
            for p in 0..params-1:
                let paramDest = Value(kind: vkTemp, label: "p" & $p)
                let paramSrc = Value(kind: vkTemp, label: paramRegisters[p])

                paramInstructions.add(Instruction(kind: ikMov, dst: paramDest,
                        src: paramSrc))

            let bodyinstructinos = genfuncbody(node.frameExpr.body.stmts)



            frames.add(Frame(name: name, instructions: paramInstructions &
                    bodyinstructinos))



        else: discard


    return frames
