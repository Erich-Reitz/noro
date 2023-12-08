import std/strutils
import std/tables

import lexutils
import scanner
import status
import types

func valueToken(typ: TokenType, lexeme: string, lit: Value,
        line: int): Token =
    Token(typ: typ, lexeme: lexeme, value: lit, line: line)

proc parseNum(s: var Scanner) =
    let num = lUint(s)
    let lit = Value(kind: lkNum, numVal: num)
    let lexeme = s.source[s.start..s.current-1]
    let line = s.line

    let token = valueToken(tkInt, lexeme, lit, line)

    s.addToken(token)


proc parseString(s: var Scanner) =
    let str = lStr(s)
    let lit = Value(kind: lkString, strVal: str)
    let lexeme = s.source[s.start..s.current-1]
    let line = s.line

    let token = valueToken(tkString, lexeme, lit, line)

    s.addToken(token)


func parseIden(s: var Scanner) =
    let iden = lIden(s)
    let typ = s.keywords.getOrDefault(iden, tkIdentifier)
    let lit = Value(kind: lkIden, strVal: iden)
    let lexeme = s.source[s.start..s.current-1]

    let token = valueToken(typ, lexeme, lit, s.line)

    s.addToken(token)

func indicatesDigit(c: char, s: Scanner): bool =
    isDigit(c) or (c == '-' and isDigit(peek(s)))


proc scanToken(s: var Scanner) =
    let c = advance(s)
    case c:
    of '(':
        addToken(s, tkLeftParen)
    of ')':
        addToken(s, tkRightParen)
    of '{':
        addToken(s, tkLeftBrace)
    of '}':
        addToken(s, tkRightBrace)
    of ',':
        addToken(s, tkComma)
    of '.':
        addToken(s, tkDot)
    of '-':
        addToken(s, if match(s, '>'): tkArrow else: tkMinus)
    of '+':
        addToken(s, tkPlus)
    of ';':
        addToken(s, tkSemicolon)
    of '*':
        addToken(s, tkStar)
    of '!': addToken(s, if match(s, '='): tkBangEqual else: tkBang)
    of '=': addToken(s, if match(s, '='): tkEqualEqual else: tkEqual)
    of '<': addToken(s, if match(s, '='): tkLessEqual else: tkLess)
    of '>': addToken(s, if match(s, '='): tkGreaterEqual else: tkGreater)
    of '/':
        if match(s, '/'):
            while peek(s) != '\n' and isAtEnd(s) == false:
                discard advance(s)
        else:
            addToken(s, tkSlash)
    of ' ', '\r', '\t':
        discard
    of '\n':
        s.line += 1
    of '"':
        parseString(s)
    else:
        if isDigit(c):
            parseNum(s)
        elif isAlphaAscii(c):
            parseIden(s)
        else:
            error(s.line, "Unexpected character.")



proc lex*(program: string): seq[Token] =
    var s = initScanner(program)
    while isAtEnd(s) == false:
        s.start = s.current
        scanToken(s)

    let eofToken = Token(typ: tkEof, lexeme: "", value: nil, line: s.line)
    s.tokens.add(eofToken)

    return s.tokens

