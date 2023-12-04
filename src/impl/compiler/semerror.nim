import ../types

proc multipleTypeSpecifiers*() =
    echo "multiple type specifiers"
    quit QuitFailure

proc noTypeSpecifiers*() =
    echo "no type specifiers"
    quit QuitFailure

proc undeclared*(s: string) =
    echo "undeclared: " & s
    quit QuitFailure

proc functionAsValue*() =
    echo "function as value"
    quit QuitFailure

proc valueAsFunction*() =
    echo "value as function"
    quit QuitFailure

proc typeMismatch*(wanted: TypeSpecifer, got: TypeSpecifer) =
    echo "type mismatch: wanted " & $wanted & ", got " & $got
    quit QuitFailure

proc wrongNumberOfArguments*(fun: string, wanted: int, got: int) =
    echo "wrong number of arguments for " & fun & ": wanted " & $wanted &
            ", got " & $got
    quit QuitFailure
