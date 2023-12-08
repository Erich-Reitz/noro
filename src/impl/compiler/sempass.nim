import std/tables

import ../types

import semtable
import typechecker


proc gatherExternalDecl(tb: SymbolTable, decl: ExternalDecl) =
    case decl.kind
    of
        externalDeclKindDeclaration:
        let varDecl = decl.decl
        let sym = Symbol(kind: skVar, skVar: varDecl.specifiers)
        tb.table[varDecl.initDeclarator.name] = sym
    of externalDeclKindFuncDef:
        let funcDef = decl.funcDef
        let sym = Symbol(kind: skFunc, skFunc: funcDef)
        tb.table[funcDef.name] = sym

proc gatherDeclarations*(tb: SymbolTable, p: Program) =
    for decl in p.externalDecls:
        gatherExternalDecl(tb, decl)


proc semAnalysis*(p: Program) =
    let tb = SymbolTable(table: initTable[string, Symbol](), parent: nil)
    gatherDeclarations(tb, p)
    typecheck(tb, p)


