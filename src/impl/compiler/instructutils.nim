import std/strutils

import instruction

let registers = ["rdi", "rsi", "rdx", "rcx", "r8", "r9", "rax", "rbx", "r10",
        "r11", "r12", "r13", "r14", "r15"]

let paramRegisters* = registers[0..6]

proc isRegister*(str: string): bool =
    registers.contains(str)

func isUserVar*(v: Value): bool =
    return v.kind == vkTemp and v.label.startswith("v")

func isParam*(v: Value): bool =
    return v.kind == vkTemp and v.label.startswith("p")

func isTemp*(v: Value): bool =
    return v.kind == vkTemp and v.label.startswith("t")

func isUserVar*(s: string): bool =
    return s.startswith("v")


proc isSpecial*(v: Value): bool =
    return v.kind == vkTemp and (v.label.startswith("p") or v.label.startswith(
            "v") or v.label.isRegister or v.label == "ret")

proc isBinaryOperationOfConstants*(i: Instruction): bool =
    if i.kind == ikAdd or i.kind == ikMinus or i.kind == ikIntEqual:
        if i.src.kind == vkConst and i.src2.kind == vkConst:
            return true
    return false
