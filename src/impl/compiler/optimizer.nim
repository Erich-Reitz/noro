import std/tables
import instruction
import instructutils

func initMov(dest: Value, src: Value): Instruction =
    return Instruction(kind: ikMov, dst: dest, src: src)

proc binOpToMoveOp(i: Instruction): Instruction =
    assert isBinaryOperationOfConstants(i)
    if i.kind == ikAdd:
        let sum = (i.src.val + i.src2.val).constInt
        return initMov(i.dst, sum)
    elif i.kind == ikMinus:
        let diff = (i.src.val - i.src2.val).constInt
        return initMov(i.dst, diff)
    elif i.kind == ikIntEqual:
        let equal = i.src.val == i.src2.val
        var byteVal = 0.constInt
        if equal == true:
            byteVal = 1.constInt
        return initMov(i.dst, byteVal)
    else:
        assert false

proc reduceConstantOperations(instructions: seq[Instruction]): seq[Instruction] =
    result = @[]
    for i in instructions:
        if isBinaryOperationOfConstants(i):
            let newi = binOpToMoveOp(i)
            result.add(newi)
        else:
            result.add(i)

    return result

proc sourceOfSourceIsConst(instructions: seq[Instruction]): seq[Instruction] =
    var constTable = initTable[string, Value]()
    result = @[]
    for i in 0 ..< instructions.len:
        let instr = instructions[i]
        case instr.kind
        of ikMov:
            if instr.src.kind == vkTemp:
                if instr.src.label in constTable:
                    let constVal = constTable[instr.src.label]
                    let newMov = initMov(instr.dst, constVal)
                    result.add(newMov)
                else:
                    result.add(instr)
            elif instr.src.kind == vkConst and instr.dst.isUserVar == false:
                constTable[instr.dst.label] = instr.src.val.constInt
                result.add(instr)
            else:
                result.add(instr)
        of ikAdd, ikMinus, ikIntEqual:
            var src1 = instr.src
            var src2 = instr.src2
            # if source 1 is a temp, and its label is in the const table,
            # replace it with the value
            if src1.kind == vkTemp and src1.label in constTable:
                src1 = constTable[src1.label]
            if src2.kind == vkTemp and src2.label in constTable:
                src2 = constTable[src2.label]
            let newInstruct = Instruction(kind: instr.kind, dst: instr.dst,
                    src: src1, src2: src2)
            result.add(newInstruct)
        else:
            result.add(instr)

    return result

# only run for move instructions, because
# other instructs use "dest" for "src" sometimes.. ConditionalJump example #1
proc removeUnusedTemps(instructions: seq[Instruction]): seq[Instruction] =
    var used = initTable[string, bool]()
    for i in instructions:
        let dst = i.dst
        assert dst.kind == vkTemp

        if dst.isSpecial:
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
                if str.isUserVar == true:
                    result.add(i)
            else:
                result.add(i)
        elif i.kind == ikIntEqual:
            let dest = i.dst
            assert dest.kind == vkTemp
            let str = dest.label
            if used.contains(str) == true and used[str] == false:
                if str.isUserVar:
                    result.add(i)
            else:
                result.add(i)
        else:
            result.add(i)


    return result


proc optimizeInstructions(instructions: seq[Instruction]): seq[Instruction] =
    var newInstructions = reduceConstantOperations(instructions)
    newInstructions = sourceOfSourceIsConst(newInstructions)
    newInstructions = removeUnusedTemps(newInstructions)

    return newInstructions



proc opt(frame: Frame): Frame =
    var newFrame = Frame(name: frame.name)

    var newInstructions = frame.instructions
    var iterations = 0
    const maxIterations = 15

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

