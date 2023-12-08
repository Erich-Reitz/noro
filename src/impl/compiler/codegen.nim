import instruct
import std/strutils

import std/tables

type Ctx = ref object
    code*: string
    datasection*: string
 
type GenTable = ref object
    table*: Table[string, int]
    counter*: int 
    createdStringLabels = Table[string, string]()


proc `[]`(t: GenTable, s: string): string =
    # i deleted reg code?
    if t.createdStringLabels.contains(s):
        return "FOUND STRING LABEL:" & t.createdStringLabels[s]  
    if t.table.contains(s):
        return $(t.table[s] * 8)
    
 
    
    echo "codegen: ", s, " not found in table"
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

            if srcIndex.startsWith("FOUND STRING LABEL:"):
                return "    mov rax, " & srcIndex.split(":")[1] & "\n" &
                       "    jmp .end"
            else:

                return "    mov rax, [rbp - " & srcIndex & "]\n" &
                   "    jmp .end"
        of vkConst:
            return "    mov rax, " & $(i.src.val) & "\n" &
               "    jmp .end"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure

    if dest.label.isRegister:
        case i.src.kind
        of vkTemp:
            let srcName = i.src.label
            let srcIndex = t[srcName]
            
            if srcIndex.startsWith("FOUND STRING LABEL:"):
                return "    mov " & dest.label & ", " & srcIndex.split(":")[1]
            else:
                return "    mov " & dest.label & ", [rbp - " & srcIndex & "]"   
        of vkConst:
            return "    mov " & dest.label & ", " & $(i.src.val)
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure
    else:
        if i.src.kind == vkTemp and      i.src.label.isRegister:
            if t.table.contains(dest.label) == false:
                t.table[dest.label] = t.counter

                t.counter += 1

            return "    mov qword [rbp - " & $t[dest.label] & "], " & i.src.label
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
                    var retStr = "    mov rax, [rbp - " & srcIndex & "]\n"
                    if srcIndex.startsWith("FOUND STRING LABEL:"):
                        retStr = "    mov " & "rax" & ", " & srcIndex.split(":")[1] & "\n"

                    retStr = retStr &    "    mov [rbp - " & $t[dest.label] & "], rax"
                    return retStr
                of vkConst:
                    let destName = dest.label
                    let destIndex = t[destName]
                    return "    mov qword [rbp - " & destIndex & "], " & $(src.val)
                of vkStringLit:
                    echo "codegen: string literals not supported yet"
                    quit QuitFailure
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
            return "    mov rax, [rbp - " & rhsIndex & "]\n" &
                   "    cmp [rbp - " & lhsIndex & "], rax\n" &
                   "    sete byte [rbp - " & destIndex & "]"
        of vkConst:
            let destName = dest.label
            let lhsName = lhsCompare.label
            let destIndex = t[destName]
            let lhsIndex = t[lhsName]
            return "    cmp qword [rbp - " & lhsIndex & "], " & $(
                    rhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & destIndex & "]"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure
    of vkConst:
        case rhsCompare.kind
        of vkTemp:
            let destName = dest.label
            let rhsName = rhsCompare.label
            let destIndex = t[destName]
            let rhsIndex = t[rhsName]
            return "    cmp qword [rbp - " & rhsIndex & "], " & $(
                    lhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & destIndex & "]"
        of vkConst:
            let destName = dest.label
            let destIndex = t[destName]
            return "    cmp qword " & $(lhsCompare.val) & ", " & $(
                    rhsCompare.val) & "\n" &
                   "    sete byte [rbp - " & destIndex & "]"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure

    of vkStringLit:
        echo "codegen: string literals not supported yet"
        quit QuitFailure


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
        return "    cmp byte [rbp - " & destIndex & "], 0\n" &
               "    je ." & src2Name & "\n" &
               "    jmp ." & src1Name
    else:
        return "    cmp byte [rbp - " & destIndex & "], 0\n" &
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
            return "    mov rax, [rbp - " & lhsIndex & "]\n" &
                   "    add rax, [rbp - " & rhsIndex & "]\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkConst:
            let lhsName = lhs.label
            let lhsIndex = t[lhsName]
            return "    mov rax, [rbp - " & lhsIndex & "]\n" &
                   "    add rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure
    of vkStringLit:
        echo "codegen: string literals not supported yet"
        quit QuitFailure
    of vkConst:
        case rhs.kind
        of vkTemp:
            let rhsName = rhs.label
            let rhsIndex = t[rhsName]
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    add rax, [rbp - " & rhsIndex & "]\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkConst:
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    add rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure

proc codegenMinus(t: GenTable, i: Instruction): string =
    assert i.kind == ikMinus

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
            return "    mov rax, [rbp - " & lhsIndex & "]\n" &
                   "    sub rax, [rbp - " & rhsIndex & "]\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkConst:
            let lhsName = lhs.label
            let lhsIndex = t[lhsName]
            return "    mov rax, [rbp - " & lhsIndex & "]\n" &
                   "    sub rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure
    of vkStringLit:
        echo "codegen: string literals not supported yet"
        quit QuitFailure
    of vkConst:
        case rhs.kind
        of vkTemp:
            let rhsName = rhs.label
            let rhsIndex = t[rhsName]
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    sub rax, [rbp - " & rhsIndex & "]\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkConst:
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    sub rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure




proc codegenMult(t: GenTable, i: Instruction): string =
    assert i.kind == ikMult

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
            return "    mov rax, [rbp - " & lhsIndex & "]\n" &
                   "    imul rax, [rbp - " & rhsIndex & "]\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkConst:
            let lhsName = lhs.label
            let lhsIndex = t[lhsName]
            return "    mov rax, [rbp - " & lhsIndex & "]\n" &
                   "    imul rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure
    of vkStringLit:
        echo "codegen: string literals not supported yet"
        quit QuitFailure
    of vkConst:
        case rhs.kind
        of vkTemp:
            let rhsName = rhs.label
            let rhsIndex = t[rhsName]
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    imul rax, [rbp - " & rhsIndex & "]\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkConst:
            return "    mov rax, " & $(lhs.val) & "\n" &
                   "    imul rax, " & $(rhs.val) & "\n" &
                   "    mov [rbp - " & destIndex & "], rax"
        of vkStringLit:
            echo "codegen: string literals not supported yet"
            quit QuitFailure



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
    of ikMinus:
        return codegenMinus(t, i)
    of ikMult:
        return codegenMult(t, i)
    of ikCall:
        let dest = i.dst
        assert dest.kind == vkTemp
        let destName = dest.label
        if t.table.contains(destName) == false:
            t.table[destName] = t.counter
            t.counter += 1
        
        let destIndex = t[destName]
        return "    call " & i.src.label & "\n" &
               "    mov [rbp - " & destIndex & "], rax"
    of ikStringLabelCreate:
        discard
    else:
        echo "codegen: unhandled instruction kind: ", i.kind
        quit QuitFailure

    return ""


# message:  db        "Hello, World", 10      ; no

proc codegen(c: Ctx, n: Frame) =
    let name = n.name
    var tb = GenTable()
    tb.table = Table[string, int]()
    tb.counter = 1
    var stringLabelGenCode = ""
    # Generate string labels in the .data section
    for i in n.instructions:
        if i.kind == ikStringLabelCreate:
            assert i.src.kind == vkStringLit
            let str = i.src.str
            let label = i.dst.label
            let asmLabel = name & "_" & label
            stringLabelGenCode.add(asmLabel)
            stringLabelGenCode.add(": db ")
            stringLabelGenCode.add(str)
            stringLabelGenCode.add(", 0\n") # Null-terminated string

            tb.createdStringLabels[label] = asmLabel

    c.dataSection.add(stringLabelGenCode)

    c += name
    c += ":\n"

    c += "    push rbp\n"
    c += "    mov rbp, rsp\n"
    let localvars = localvars(n.instructions)
    c += "    sub rsp, "
    # subtract by the number of local variables
    let localVarsBytes = localvars * 8
    var localVarsBytesAligned = 0
    if localVarsBytes != 0:
        localVarsBytesAligned = localVarsBytes + (16 - (localVarsBytes mod 16))

    c += $localVarsBytesAligned
    c += "\n"

    




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
        if f.name == "writestrnewline":
            ctx += "extern writestrnewline\n"
            continue
        if f.name == "writeint":
            ctx += "extern writeint\n"
            continue

        if f.name == "writestr":
            ctx += "extern writestr\n"
            continue

        codegen(ctx, f)


    ctx += "_start:\n"
    ctx += "    call main\n"
    ctx += "    mov rdi, rax\n"
    ctx += "    mov rax, 60\n"
    ctx += "    syscall\n"
    
    ctx += "section .data\n"
    ctx += ctx.datasection
    ctx += "\n"
    ctx += "section .note.GNU-stack noalloc noexec nowrite progbits\n"

    return ctx.code
