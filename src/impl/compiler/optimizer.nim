import instruct 
import std/tables
import std/strutils

let aggresive = false
# type
#     InstructionKind* = enum
#         ikMov, ikAdd, ikMinus, ikIntEqual, ikLabelCreate, ikLabelJumpTo, ikConditionalJump

#     ValueKind* = enum
#         vkConst, vkTemp

#     Value* = ref object
#         case kind*: ValueKind
#         of vkConst:
#             val: int
#         of vkTemp:
#             label: string



#     Instruction* = object
#         kind*: InstructionKind
#         dst*: Value
#         src*: Value
#         src2*: Value

#     Frame* = object
#         name*: string
#         instructions*: seq[Instruction]


func binOpOfConstants(i: Instruction): bool =
    if i.kind == ikAdd or i.kind == ikMinus:
        if i.src.kind == vkConst and i.src2.kind == vkConst:
            return true
    return false


func binOpToMoveOp(i: Instruction): Instruction =
    assert binOpOfConstants(i)
    if i.kind == ikAdd:
        let sum = i.src.val + i.src2.val
        return Instruction(kind: ikMov, dst: i.dst, src: Value(kind: vkConst, val: sum))
    elif i.kind == ikMinus:
        let diff = i.src.val - i.src2.val
        return Instruction(kind: ikMov, dst: i.dst, src: Value(kind: vkConst, val: diff))
    else:
        assert false

proc reduceConstantOperations(instructions: seq[Instruction]): seq[Instruction] =
    result = @[]
    for  i in instructions:
        if binOpOfConstants(i):
            let newi = binOpToMoveOp(i)
            result.add(newi)
        else:
            result.add(i)
    
    return result



proc sourceOfSourceIsConst(instructions: seq[Instruction]): seq[Instruction] =
    var constTable = initTable[string, int]()  # Table to map variable names to constant values
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
                    let newInstruct = Instruction(kind: instr.kind, dst: instr.dst, src: Value(kind: vkConst, val: constVal))
                    result.add(newInstruct)
                else:
                    result.add(instr)
            elif instr.src.kind == vkConst:
                # Update the table with the constant value of the variable
                constTable[instr.dst.label] = instr.src.val
                result.add(instr)
            else:
                result.add(instr)
        of ikAdd, ikMinus:
            # Check if either source is a constant in the table
            var src1 = instr.src
            var src2 = instr.src2

            if src1.kind == vkTemp and src1.label in constTable:
                src1 = Value(kind: vkConst, val: constTable[src1.label])
            if src2.kind == vkTemp and src2.label in constTable:
                src2 = Value(kind: vkConst, val: constTable[src2.label])

            let newInstruct = Instruction(kind: instr.kind, dst: instr.dst, src: src1, src2: src2)
            result.add(newInstruct)
        else:
            result.add(instr)

    return result


proc removeUnusedTemps(instructions: seq[Instruction]): seq[Instruction] =
    # first, get check to see if they are used.
    
    var used = initTable[string, bool]()
    for i in instructions:
        let dst = i.dst
        assert dst.kind == vkTemp
        let str = dst.label
        
        
        used[str] = false

        let src = i.src
        
        if src.kind == vkTemp:
            used[src.label] = true
        
        if i.src2 != nil and i.src2.kind == vkTemp:
            used[i.src2.label] = true
    
    used["ret"] = true
    for i in instructions:
        let dst = i.dst
        assert dst.kind == vkTemp
        let str = dst.label
        if not used[str]:
            # if not used
            # if we are in aggresive mode, we can remove all temps
            if aggresive == false:
                if str.startswith("v"):
                    result.add(i)
                else:
                    discard
        else:
            result.add(i)


    return result

proc optimizeInstructions(instructions: seq[Instruction]): seq[Instruction] =
    var newInstructions = reduceConstantOperations(instructions)
    if aggresive == true:
        newInstructions = sourceOfSourceIsConst(newInstructions)
    newInstructions = removeUnusedTemps(newInstructions)
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

