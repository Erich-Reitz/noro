import std/os

import impl/lexer
import impl/parser
import impl/status
import impl/compiler/sempass
import impl/compiler/translate
import impl/compiler/codegen
import impl/compiler/instructgen
import impl/compiler/optimizer

proc run(program: string): void =
    let tokens = lex(program)
    let lexpr = parse(tokens)
    semAnalysis(lexpr)
    let code = translate(lexpr)
    let instructions = instructgen(code)
    let optimized = optpass(instructions)
    let asmCode = codegenFrames(optimized)
    writeFile("asm/out.asm", asmCode)


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

proc main() =
    let paramCount = os.paramCount()
    if paramCount > 1:
        echo "Usage: ./noro [script]"
        quit(QuitFailure)
    elif paramCount == 1:
        let filename = os.paramStr(1)
        let result = runfile(filename)
        quit(result)


when isMainModule:
    main()
