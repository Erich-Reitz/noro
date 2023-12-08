type
    InstructionKind* = enum
        ikMov, ikAdd, ikMinus, ikIntEqual, ikLabelCreate, ikLabelJumpTo,
            ikConditionalJump, ikReturn, ikCall, ikStringLabelCreate, ikMult, ikIntGt

    ValueKind* = enum
        vkConst, vkTemp, vkStringLit

    Value* = ref object
        case kind*: ValueKind
        of vkConst:
            val*: int
        of vkTemp:
            label*: string
        of vkStringLit:
            str*: string

    Instruction* = object
        kind*: InstructionKind
        dst*: Value
        src*: Value
        src2*: Value

    Frame* = object
        name*: string
        instructions*: seq[Instruction]


func constInt*(val: int): Value =
    return Value(kind: vkConst, val: val)

func toStrLitValue*(s: string): Value =
    return Value(kind: vkStringLit, str: s)

func fromTempIntToLabelValue*(val: int): Value =
    let str = "t" & $val
    return Value(kind: vkTemp, label: str)


func toLabel*(s: string): Value =
    return Value(kind: vkTemp, label: s)

proc `$`*(v: Value): string =
    case v.kind
    of vkConst:
        return $v.val
    of vkTemp:
        return v.label
    of vkStringLit:
        return v.str
