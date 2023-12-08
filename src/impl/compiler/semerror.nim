import ../types

type NoroTypeError* = object of CatchableError

proc multipleTypeSpecifiers*(s: string) =
    raise newException(NoroTypeError, "multiple type specifiers")

proc noTypeSpecifiers*(s: string) =
    raise newException(NoroTypeError, "no type specifiers: ")


proc forbidden*(s: string) =
    raise newException(NoroTypeError, "use of forbidden: " & s)




proc undeclared*(s: string) =
    echo "undeclared: " & s
    quit QuitFailure


proc constReassign*(s: string) =
    echo "const reassign: " & s
    quit QuitFailure


proc functionAsValue*() =
    echo "function as value"
    quit QuitFailure

proc valueAsFunction*() =
    echo "value as function"
    quit QuitFailure

proc typeMismatch*(wanted: TypeSpecifer, got: TypeSpecifer) =
    raise newException(NoroTypeError, "type mismatch: wanted " & $wanted &
            ", got " & $got)

proc wrongNumberOfArguments*(fun: string, wanted: int, got: int) =
    echo "wrong number of arguments for " & fun & ": wanted " & $wanted &
            ", got " & $got
    quit QuitFailure
