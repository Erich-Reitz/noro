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

proc functionReturns(funcDef: FuncDef): bool =
    for blkitem in funcDef.body.blockItems:
        case blkitem.kind
        of blkStatement:
            let stm = blkitem.statement
            case stm.kind
            of skReturn:
                return true
            else:
                discard
        of blkDeclaration:
            discard

    return false

proc functionsReturn(p: Program): bool =
    for decl in p.externalDecls:
        case decl.kind
        of externalDeclKindFuncDef:
            let funcDef = decl.funcDef
            if functionReturns(funcDef) == false:
                return false
        else:
            discard

    return true

proc semAnalysis*(p: Program) =
    let tb = SymbolTable(table: initTable[string, Symbol](), parent: nil)
    gatherDeclarations(tb, p)
    typecheck(tb, p)

    # if functionsReturn(p) == false:
    #     echo "Error: not all functions return"
    #     quit(1)


