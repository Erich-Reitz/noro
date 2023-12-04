import std/options
import std/tables

import ../types

type
    SymbolKind* = enum
        skVar, skFunc
    Symbol* = object
        kind*: SymbolKind
        skVar*: seq[VariableDeclSpecifier]
        skFunc*: FuncDef

    SymbolTable* = ref object
        table*: Table[string, Symbol]
        parent*: SymbolTable

proc ctxDefined*(tb: SymbolTable, name: string): bool =
    if tb.table.hasKey(name):
        true
    elif tb.parent != nil:
        ctxDefined(tb.parent, name)
    else:
        false

proc lookup*(tb: SymbolTable, name: string): Option[Symbol] =
    if tb.table.hasKey(name):
        some(tb.table[name])
    elif tb.parent != nil:
        lookup(tb.parent, name)
    else:
        none(Symbol)
