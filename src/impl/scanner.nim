import std/tables

import types

type Scanner* = object
    source*: string
    start*: int
    current*: int
    line*: int
    tokens*: seq[Token]
    keywords*: Table[string, TokenType]

proc initScanner*(source: string): Scanner =
    result.source = source
    result.start = 0
    result.current = 0
    result.line = 1
    result.tokens = @[]

    let keywordTokens = [
      ("and", tkAnd), ("else", tkElse),
      ("false", tkFalse), ("function", tkFun), ("for", tkFor),
      ("if", tkIf), ("or", tkOr),
      ("return", tkReturn),
       ("true", tkTrue), ("int", tkIntDecl), ("string", tkStringDecl),
      ("while", tkWhile), ("const", tkConst), ("pure", tkPure), ("bool",
              tkBoolDecl), ("forbid", tkForbid)
    ]

    for (keyword, token) in keywordTokens:
        result.keywords[keyword] = token

func isAtEnd*(s: Scanner): bool =
    s.current >= len(s.source)

func advance*(s: var Scanner): char =
    result = s.source[s.current]
    s.current = s.current + 1


func addToken*(s: var Scanner, tkType: TokenType) =
    let line = s.line
    let lexeme = s.source[s.start..s.current-1]
    let token = Token(typ: tkType, value: nil, lexeme: lexeme, line: line)
    s.tokens.add(token)

func addToken*(s: var Scanner, token: Token) =
    s.tokens.add(token)

func peek*(s: Scanner): char =
    if isAtEnd(s):
        return '\n'

    s.source[s.current]

func peekNext*(s: Scanner): char =
    if s.current + 1 >= len(s.source):
        return '\0'

    s.source[s.current + 1]

func match*(s: var Scanner, expected: char): bool =
    if isAtEnd(s):
        return false

    if s.source[s.current] != expected:
        return false

    s.current = s.current + 1
    true
