import std/strutils

import scanner
import status

proc lInt*(s: var Scanner): int =
    while isDigit(peek(s)):
        discard advance(s)

    let intStr = s.source.substr(s.start, s.current - 1)
    parseInt(intStr)


proc lStr*(s: var Scanner): string =
    while peek(s) != '"' and (isAtEnd(s) == false):
        if peek(s) == '\n':
            s.line += 1
        discard advance(s)

    if isAtEnd(s):
        error(s.line, "Unterminated string.")

    discard advance(s)

    s.source.substr(s.start + 1, s.current - 2)

func allowedIdentifierChar(c: char): bool =
    isAlphaNumeric(c) or @['_', '?', '-'].contains(c)

proc lIden*(s: var Scanner): string =
    while allowedIdentifierChar(peek(s)):
        discard advance(s)

    s.source.substr(s.start, s.current - 1)
