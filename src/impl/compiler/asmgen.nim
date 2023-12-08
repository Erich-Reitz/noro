proc asmCmpOffset*(destIndex, jumpEqualToZero, elseJumpLabel: string): string =
        return "    cmp byte [rbp - " & destIndex & "], 0\n" &
               "    je ." & jumpEqualToZero & "\n" &
               "    jmp ." & elseJumpLabel

proc asmCmpOffset*(destIndex, jumpEqualToZero: string): string =
        return "    cmp byte [rbp - " & destIndex & "], 0\n" &
               "    je ." & jumpEqualToZero & "\n"
