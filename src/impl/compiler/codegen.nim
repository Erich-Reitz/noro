import instruct

import std/tables

type Ctx = ref object
    code*: string
 
type GenTable = ref object
    table*: Table[string, int]
    counter*: int 

proc `[]`(t: GenTable, s: string): int =
    if t.table.contains(s):
        return t.table[s]
    else:
        # if s is a register, return its position in the 6 param pass registers
        if s == "rdi":
            return 0
        elif s == "rsi":
            return 1
        elif s == "rdx":
            return 2
        elif s == "rcx":
            return 3
        elif s == "r8":
            return 4
        elif s == "r9":
            return 5
        else:
            echo "codegen: unknown register: ", s
            quit QuitFailure
            

proc `+=`(c: Ctx, s: string) =
    c.code.add(s)


func isRegister(str: string): bool =
    @["rdi", "rsi", "rdx", "rcx", "r8", "r9", "rax", "rbx", "r10", "r11", "r12", "r13", "r14", "r15"].contains(str)


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


proc codeGenMoveInstruction(t: GenTable,
        i: Instruction): string =
    
    assert i.kind == ikMov
    let dest = i.dst

    if dest.label == "ret":
        case i.src.kind:
        of vkTemp:
            let srcName = i.src.label
            let srcIndex = t[srcName]
            return "    mov rax, [rbp - " & $(srcIndex * 8) & "]\n" &
                   "    jmp .end"
        of vkConst:
            return "    mov rax, " & $(i.src.val) & "\n" &
               "    jmp .end"

    if dest.label.isRegister:
        case i.src.kind
        of vkTemp:
            let srcName = i.src.label
            let srcIndex = t[srcName]
            return "    mov " & dest.label & ", [rbp - " & $(srcIndex * 8) & "]"
        of vkConst:
            return "    mov " & dest.label & ", " & $(i.src.val)
    else:


        if i.src.kind == vkTemp and      i.src.label.isRegister:
            if t.table.contains(dest.label) == false:
                t.table[dest.label] = t.counter

                t.counter += 1
            return "    mov qword [rbp - " & $(t[dest.label] * 8) & "], " & i.src.label
        else:
            if t.table.contains(dest.label) == false:
                t.table[dest.label] = t.counter

                t.counter += 1
            let src = i.src
            case dest.kind
            of vkTemp:
                case src.kind
                of vkTemp:
                    # first move the value of src into rax
                    let srcName = src.label
                    let srcIndex = t[srcName]
                    return "    mov rax, [rbp - " & $(srcIndex * 8) & "]\n" &
                        "    mov [rbp - " & $(t[dest.label] * 8) & "], rax"
                of vkConst:
                    let destName = dest.label
                    let destIndex = t[destName]
                    return "    mov qword [rbp - " & $(destIndex * 8) & "], " & $(src.val)
            else:
                return "    "

proc codeGenIntEqual(t: GenTable, i: Instruction): string =
    assert i.kind == ikIntEqual

    let dest = i.dst
    t.table[dest.label] = t.counter
    t.counter += 1
    let lhsCompare = i.src
    let rhsCompare = i.src2

    assert dest.kind == vkTemp

    case lhsCompare.kind
    of vkTemp:
        case rhsCompare.kind
        of vkTemp:
            # # first move the value of src into rax
            let destName = dest.label
            let lhsName = lhsCompare.label
            let rhsName = rhsCompare.label
            let destIndex = t[destName]
            let lhsIndex = t[lhsName]
            let rhsIndex = t[rhsName]
            # move rhs to rax
            return "    mov rax, [rbp - " & $(rhsIndex * 8) & "]\n" &
                   "    cmp [rbp - " & $(lhsIndex * 8) & "], rax\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
        of vkConst:
            let destName = dest.label
            let lhsName = lhsCompare.label
            let destIndex = t[destName]
            let lhsIndex = t[lhsName]
            return "    cmp qword [rbp - " & $(lhsIndex * 8) & "], " & $(
                    rhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
    of vkConst:
        case rhsCompare.kind
        of vkTemp:
            let destName = dest.label
            let rhsName = rhsCompare.label
            let destIndex = t[destName]
            let rhsIndex = t[rhsName]
            return "    cmp qword [rbp - " & $(rhsIndex * 8) & "], " & $(
                    lhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
        of vkConst:
            let destName = dest.label
            let destIndex = t[destName]
            return "    cmp qword " & $(lhsCompare.val) & ", " & $(
                    rhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & $(destIndex * 8) & "]"
            


proc codegenConditionalJump(t: GenTable,
        i: Instruction): string =
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

proc codegenLabelCreate(t: GenTable, i: Instruction): string =
    assert i.kind == ikLabelCreate

    let dest = i.dst
    assert dest.kind == vkTemp
    let destName = dest.label

    return "." & destName & ":\n"


proc codegenAdd(t: GenTable, i: Instruction): string =
    assert i.kind == ikAdd

    let dest = i.dst
    assert dest.kind == vkTemp

    
    let destName = dest.label
    
    if t.table.contains(destName) == false:
        t.table[destName] = t.counter
        t.counter += 1
    
    let destIndex = t[destName]

    let lhs = i.src
    let rhs = i.src2

    case lhs.kind
    of vkTemp:
        case rhs.kind
        of vkTemp:
            let lhsName = lhs.label
            let rhsName = rhs.label
            let lhsIndex = t[lhsName]
            let rhsIndex = t[rhsName]
            return "    mov rax, [rbp - " & $(lhsIndex * 8) & "]\n" &
                   "    add rax, [rbp - " & $(rhsIndex * 8) & "]\n" &
                   "    mov [rbp - " & $(destIndex * 8) & "], rax"
        of vkConst:
            let lhsName = lhs.label
            let lhsIndex = t[lhsName]
            return "    mov rax, [rbp - " & $(lhsIndex * 8) & "]\n" &
                   "    add rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & $(destIndex * 8) & "], rax"
    of vkConst:
        case rhs.kind
        of vkTemp:
            let rhsName = rhs.label
            let rhsIndex = t[rhsName]
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    add rax, [rbp - " & $(rhsIndex * 8) & "]\n" &
                   "    mov [rbp - " & $(destIndex * 8) & "], rax"
        of vkConst:
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    add rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & $(destIndex * 8) & "], rax"


proc codegen(t: GenTable, i: Instruction): string =
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
    of ikAdd:
        return codegenAdd(t, i)
    of ikCall:
        let dest = i.dst
        assert dest.kind == vkTemp
        let destName = dest.label
        if t.table.contains(destName) == false:
            t.table[destName] = t.counter
            t.counter += 1
        
        let destIndex = t[destName]
        return "    call " & i.src.label & "\n" &
               "    mov [rbp - " & $(destIndex * 8) & "], rax"
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

    


    var tb = GenTable()
    tb.table = Table[string, int]()
    tb.counter = 1

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
