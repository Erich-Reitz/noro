import std/os

import impl/lexer
import impl/parser
import impl/status
import impl/compiler/sempass
import impl/compiler/translate
import impl/compiler/ast
import impl/compiler/codegen
import impl/compiler/instruct
import impl/compiler/optimizer


proc run(program: string): void =
    let tokens = lex(program)
    let lexpr = parse(tokens)
    semAnalysis(lexpr)
    let code = translate(lexpr)

    for n in code:
        debugPrint(n)

    let instructions = instructgen(code)
    let optimized = optpass(instructions)
    for f in optimized:
        echo f.name
        for i in f.instructions:
            if i.src2 != nil:
                echo i.kind, " ", "dst: ", i.dst, " src: ", i.src, " src2: ", i.src2
            else:
                if i.src != nil:
                    echo i.kind, " ", "dst: ", i.dst, " src: ", i.src
                else:
                    echo i.kind, " ", "dst: ", i.dst






proc runfile(filename: string): int =
    try:
        let contents = readFile(filename)
        run(contents)
        if hadError:
            return 65
        if hadRuntimeError:
            return 70

        return 0


    except IOError as e:
        echo e.msg
        return QuitFailure

proc runPrompt(): int =
    while true:
        stdout.write "> "
        let line = readLine(stdin)
        if len(line) == 0:
            break

        run(line)
        status.hadError = false
    return QuitSuccess

proc main() =
    let paramCount = os.paramCount()
    if paramCount > 1:
        echo "Usage: ./noro [script]"
        quit(QuitFailure)
    elif paramCount == 1:
        let filename = os.paramStr(1)
        let result = runfile(filename)
        quit(result)
    else:
        let result = runPrompt()
        quit(result)



when isMainModule:
    main()
