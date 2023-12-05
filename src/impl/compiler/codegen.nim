import instruct

import std/tables

type Ctx = ref object 
    code*: string

var counter = 1

proc `+=`(c: Ctx, s: string) =
    c.code.add(s)
    

func isInstructionWhichStoresTemp(i: Instruction): bool =
    case i.kind
    of ikMov:
        return i.dst.label != "ret"
    of ikConditionalJump:
        return true
    else:
        return false


proc localvars(instructions: seq[Instruction]): int =
    var total = 0
    for i in instructions:
        if isInstructionWhichStoresTemp(i):
            total += 1
    
    return total


proc codeGenMoveInstruction(t: var TableRef[string, int], i: Instruction): string =
    assert i.kind == ikMov



    let dest = i.dst

    if dest.label == "ret":
        return "    mov rax, " & $(i.src.val) & "\n" &
               "    jmp .end"


    t[dest.label] = counter
    counter += 1
    let src = i.src
    case dest.kind
    of vkTemp:
        case src.kind
        of vkTemp:
            let destName = dest.label
            let srcName = src.label
            let destIndex = t[destName]
            let srcIndex = t[srcName]
            return "    mov qword [rbp - " & $(destIndex * 8) & "], [rbp - " & $(srcIndex * 8) & "]"
        of vkConst:
            let destName = dest.label
            let destIndex = t[destName]
            return "    mov qword [rbp - " & $(destIndex * 8) & "], " & $(src.val)
        else:
            return "    "
    else:
        return "    "

proc codeGenIntEqual(t: var TableRef[string, int], i: Instruction): string =
    assert i.kind == ikIntEqual

    let dest = i.dst
    t[dest.label] = counter
    counter += 1
    let lhsCompare = i.src
    let rhsCompare = i.src2

    assert dest.kind == vkTemp
    
    case lhsCompare.kind
    of vkTemp:
        case rhsCompare.kind
        of vkTemp:
            let destName = dest.label
            let lhsName = lhsCompare.label
            let rhsName = rhsCompare.label
            let destIndex = t[destName]
            let lhsIndex = t[lhsName]
            let rhsIndex = t[rhsName]
            return "    cmp [rbp - " & $(lhsIndex * 8) & "], [rbp - " & $(rhsIndex * 8) & "]\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
        of vkConst:
            let destName = dest.label
            let lhsName = lhsCompare.label
            let destIndex = t[destName]
            let lhsIndex = t[lhsName]
            return "    cmp [rbp - " & $(lhsIndex * 8) & "], " & $(rhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
    of vkConst:
        case rhsCompare.kind
        of vkTemp:
            let destName = dest.label
            let rhsName = rhsCompare.label
            let destIndex = t[destName]
            let rhsIndex = t[rhsName]
            return "    cmp " & $(lhsCompare.val) & ", [rbp - " & $(rhsIndex * 8) & "]\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
        of vkConst:
            let destName = dest.label
            let destIndex = t[destName]
            return "    cmp " & $(lhsCompare.val) & ", " & $(rhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
    

proc codegenConditionalJump(t: var TableRef[string, int], i: Instruction): string =
    assert i.kind == ikConditionalJump

    # the destination is the thing to test for 0 or 1
    let dest = i.dst
    
    # if dest is 0, then jump to src2, else if dest is true then jump to src
    let src = i.src
    let src2 = i.src2

    assert dest.kind == vkTemp

    let destName = dest.label
    let destIndex = t[destName]

    # src1 is a temp. label
    assert src.kind == vkTemp
    let src1Name = src.label   

    if src2 != nil:
        assert src2.kind == vkTemp
        let src2Name = src2.label
        return "    cmp byte [rbp - " & $(destIndex * 8) & "], 0\n" &
               "    je ." & src2Name & "\n" &
               "    jmp ." & src1Name
    else:
        return "    cmp byte [rbp - " & $(destIndex * 8) & "], 0\n" &
               "    je ." & src1Name

proc codegenLabelCreate(t: var TableRef[string, int], i: Instruction): string =
    assert i.kind == ikLabelCreate

    let dest = i.dst
    assert dest.kind == vkTemp
    let destName = dest.label

    return "." & destName & ":\n"

proc codegen(t: var TableRef[string, int], i: Instruction): string =
    case i.kind
    of ikMov:
        return codeGenMoveInstruction(t, i)
    of ikIntEqual:
        return codegenIntEqual(t, i)
    of ikConditionalJump:
        return codegenConditionalJump(t, i)
    of ikLabelCreate:
        return codegenLabelCreate(t, i) 
    of ikLabelJumpTo:
        return "    jmp ." & i.dst.label
    else:
        echo "codegen: unhandled instruction kind: ", i.kind
        quit QuitFailure
    
    return ""
        

proc codegen(c: Ctx, n: Frame) =
    let name = n.name
    c += name
    c += ":\n"

    c += "    push rbp\n"
    c += "    mov rbp, rsp\n"
    let localvars = localvars(n.instructions)
    c += "    sub rsp, "
    # subtract by the number of local variables
    c += $(localvars * 8)
    c += "\n"

    var tb = newTable[string, int]()
    for i in n.instructions:
        c += codegen(tb, i)
        c += "\n"



    # end label
    c += ".end:\n"

    if localvars > 0:
        c += "    leave\n"
    else:
        c += "    pop rbp\n"

    c += "    ret\n"



proc codegenFrames*(frames: seq[Frame]): string =
    let ctx = Ctx()

    ctx += "section .text\n"    
    ctx += "global _start\n"

    for f in frames:
        codegen(ctx, f)

    ctx += "_start:\n"
    ctx += "    call main\n"
    ctx += "    mov rdi, rax\n"
    ctx += "    mov rax, 60\n"
    ctx += "    syscall\n"


    return ctx.code
