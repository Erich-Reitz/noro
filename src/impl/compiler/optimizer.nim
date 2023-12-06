import instruct
import std/tables
import std/strutils

let aggresive = true

func isRegister(str: string): bool =
    @["rdi", "rsi", "rdx", "rcx", "r8", "r9", "rax", "rbx", "r10", "r11", "r12", "r13", "r14", "r15"].contains(str)

proc binOpOfConstants(i: Instruction): bool =
    if i.kind == ikAdd or i.kind == ikMinus or i.kind == ikIntEqual:
        if i.src.kind == vkConst and i.src2.kind == vkConst:
            return true
    return false


proc binOpToMoveOp(i: Instruction): Instruction =
    assert binOpOfConstants(i)
    if i.kind == ikAdd:
        let sum = i.src.val + i.src2.val
        return Instruction(kind: ikMov, dst: i.dst, src: Value(kind: vkConst, val: sum))
    elif i.kind == ikMinus:
        let diff = i.src.val - i.src2.val
        return Instruction(kind: ikMov, dst: i.dst, src: Value(kind: vkConst, val: diff))
    elif i.kind == ikIntEqual:
        let equal = i.src.val == i.src2.val
        var byteVal = 0
        if equal == true:
            byteVal = 1
        return Instruction(kind: ikMov, dst: i.dst, src: Value(kind: vkConst, val: byteVal))
    else:
        assert false

proc reduceConstantOperations(instructions: seq[Instruction]): seq[Instruction] =
    result = @[]
    for i in instructions:
        if binOpOfConstants(i):
            let newi = binOpToMoveOp(i)
            result.add(newi)
        else:
            result.add(i)

    return result



proc sourceOfSourceIsConst(instructions: seq[Instruction]): seq[Instruction] =
    echo instructions
    var constTable = initTable[string, int]() # Table to map variable names to constant values
    result = @[]
    for i in 0 ..< instructions.len:
        let instr = instructions[i]
        case instr.kind
        of ikMov:
            if instr.src.kind == vkTemp:
                # Check if the source is a constant in the table
                if instr.src.label in constTable:
                    # get the const value
                    let constVal = constTable[instr.src.label]
                    # update the instruction
                    let newInstruct = Instruction(kind: instr.kind,
                            dst: instr.dst, src: Value(kind: vkConst,
                            val: constVal))
                    result.add(newInstruct)
                else:
                    result.add(instr)
            elif instr.src.kind == vkConst:
                # Update the table with the constant value of the variable
                if instr.dst.label.startsWith("v"):
                    result.add(instr)
                else:
                    constTable[instr.dst.label] = instr.src.val
                    result.add(instr)
            else:
                result.add(instr)
        of ikAdd, ikMinus, ikIntEqual:
            # Check if either source is a constant in the table
            var src1 = instr.src
            var src2 = instr.src2

            if src1.kind == vkTemp and src1.label in constTable:
                src1 = Value(kind: vkConst, val: constTable[src1.label])
            if src2.kind == vkTemp and src2.label in constTable:
                src2 = Value(kind: vkConst, val: constTable[src2.label])

            let newInstruct = Instruction(kind: instr.kind, dst: instr.dst,
                    src: src1, src2: src2)
            result.add(newInstruct)
        else:
            result.add(instr)

    return result

# only run for move instructions, because
# other instructs use "dest" for "src" sometimes.. ConditionalJump example #1
proc removeUnusedTemps(instructions: seq[Instruction]): seq[Instruction] =
    # first, get check to see if they are used.
    var used = initTable[string, bool]()
    for i in instructions:
        let dst = i.dst
        assert dst.kind == vkTemp
        if dst.label == "ret":
            discard

        if dst.label.startsWith("r"):
            continue


        let str = dst.label

        if i.kind != ikConditionalJump:
            used[str] = false
        else:
            used[str] = true
        if i.src != nil:
            let src = i.src

            if src.kind == vkTemp:
                used[src.label] = true

            if i.src2 != nil and i.src2.kind == vkTemp:
                used[i.src2.label] = true

    used["ret"] = true
    for i in instructions:
        if i.kind == ikMov:
            let dst = i.dst
            assert dst.kind == vkTemp
            let str = dst.label
            if used.contains(str) == true and used[str] == false:
                if str.startswith("v"):
                    result.add(i)
                else:
                    discard
            else:
                result.add(i)

        elif i.kind == ikIntEqual:
            let dest = i.dst
            assert dest.kind == vkTemp
            let str = dest.label
            if used.contains(str) == true and used[str] == false:
                if str.startswith("v"):
                    result.add(i)
                else:
                    discard
            else:
                result.add(i)
        else:
            result.add(i)


    return result


proc resultOfCallMoved(instructions: seq[Instruction]): seq[Instruction] =
    var callResultToNextMove = initTable[string, string]()
    for i in instructions:
        if i.kind == ikCall:
            let dst = i.dst
            assert dst.kind == vkTemp
            let str = dst.label
            callResultToNextMove[str] = ""
        elif i.kind == ikMov:
            if i.dst.label.isRegister == true:
                continue
            let src = i.src
            if src.kind != vkTemp:
                continue
            let str = src.label
            if callResultToNextMove.contains(str) == true:
                callResultToNextMove[str] = i.dst.label
        else:
            discard

    var discardMoves = initTable[string, bool]()
    result = @[]
    for i in instructions:
        if i.kind == ikCall:
            let dst = i.dst
            assert dst.kind == vkTemp
            let str = dst.label
            if callResultToNextMove.contains(str) == true:
                let newDest = callResultToNextMove[str]
                if callResultToNextMove[str] != "":
                    discardMoves[newDest] = true

                    let newCallI = Instruction(kind: i.kind, dst: Value(kind: vkTemp, label: newDest), src: i.src)
                    result.add(newCallI)
                else:
                    result.add(i)
            else:
                result.add(i)
        elif i.kind == ikMov:
            let dst = i.dst
            assert dst.kind == vkTemp
            let str = dst.label
            if discardMoves.contains(str) == true:
                discard
            else:
                result.add(i)
        else:
            result.add(i)

    return result


proc optimizeInstructions(instructions: seq[Instruction]): seq[Instruction] =
    var newInstructions = reduceConstantOperations(instructions)
    if aggresive == true:
        discard
        newInstructions = sourceOfSourceIsConst(newInstructions)
    newInstructions = removeUnusedTemps(newInstructions)
    newInstructions = resultOfCallMoved(newInstructions)
    return newInstructions



proc opt(frame: Frame): Frame =
    var newFrame = Frame(name: frame.name)

    var newInstructions = frame.instructions
    var iterations = 0
    const maxIterations = 10

    while iterations < maxIterations:
        newInstructions = optimizeInstructions(newInstructions)
        iterations += 1

    newFrame.instructions = newInstructions
    return newFrame



proc optpass*(frames: seq[Frame]): seq[Frame] =
    var optframes: seq[Frame] = @[]
    for f in frames:
        optframes.add(opt(f))

    return optframes

