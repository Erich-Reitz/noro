import status
import types



type Parser* = object
    tokens*: seq[Token]
    current*: int = 0

proc parse_expr(p: var Parser): Expr

func peek(p: Parser): Token =
    p.tokens[p.current]

func peektwo(p: Parser): Token =
    p.tokens[p.current + 1]

func isAtEnd(p: Parser): bool =
    peek(p).typ == tkEOF

func previous(p: Parser): Token =
    p.tokens[p.current - 1]

func check(p: Parser, typ: TokenType): bool =
    if isAtEnd(p):
        return false

    peek(p).typ == typ

func advance(p: var Parser): Token =
    if isAtEnd(p) == false:
        p.current += 1

    previous(p)


proc consume(p: var Parser, typ: TokenType, msg: string): Token =
    if check(p, typ) == true:
        return advance(p)

    error(peek(p), msg)
    raise newException(NoroParseError, msg)



func match(p: var Parser, typ: TokenType): bool =
    if check(p, typ):
        discard advance(p)
        return true

    return false

proc match*(p: var Parser, types: varargs[TokenType]): bool =
    for typ in types:
        if match(p, typ):
            return true

    return false


proc is_function_specifier(token: Token): bool =
    token.typ == tkPure

proc indicates_function_specifier(token: Token): bool =
    token.typ == tkFun or is_function_specifier(token)

proc is_type_specifier(token: Token): bool =
    token.typ == tkIntDecl or token.typ == tkString or
    token.typ == tkBoolDecl or token.typ == tkIdentifier

proc to_type_specifier(token: Token): TypeSpecifer =
    case token.typ:
        of tkBoolDecl:
            return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeBool)
        of tkIntDecl:
            return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeInt)
        of tkString:
            return TypeSpecifer(kind: tsKindBnType, builtinType: binTypeString)
        of tkIdentifier:
            return TypeSpecifer(kind: tsKindDecl, typeDecl: TypeDecl(
                    name: token.lexeme))
        else:
            error(token, "Invalid type specifier")
            raise newException(NoroParseError, "Invalid type specifier")



proc to_variable_decl_specifier(token: Token): VariableDeclSpecifier =
    if is_type_specifier(token):
        let typespecifier = to_type_specifier(token)

        return VariableDeclSpecifier(kind: vdsKindTypeSpecifer,
                typeSpec: typespecifier)

    case token.typ:
        of tkConst:
            return VariableDeclSpecifier(kind: vdsKindTypeQualifier,
                    typeQualifier: tqConst)
        else:
            error(token, "Invalid variable decl specifier")
            raise newException(NoroParseError, "Invalid variable decl specifier")



proc is_variable_decl_specifier(token: Token): bool =
    token.typ == tkConst or is_type_specifier(token)

proc parse_var_decl_specs(p: var Parser): seq[VariableDeclSpecifier] =
    var specs: seq[VariableDeclSpecifier] = @[]
    while is_variable_decl_specifier(peektwo(p)):
        let specifier_token = peek(p)
        let spec = to_variable_decl_specifier(specifier_token)
        specs.add(spec)
        discard advance(p)

    return specs




proc parse_identifier(p: var Parser): string =
    let token = consume(p, tkIdentifier, "Expected identifier")
    return token.lexeme


proc parse_primary_expr(p: var Parser): PrimaryExpr =
    let nxt = peek(p)
    case nxt.typ:
        of tkTrue:
            discard advance(p)
            return PrimaryExpr(kind: pkBool, boolValue: true)
        of tkFalse:
            discard advance(p)
            return PrimaryExpr(kind: pkBool, boolValue: false)
        of tkInt:
            discard advance(p)
            return PrimaryExpr(kind: pkInt, intValue: nxt.value.numVal)
        of tkString:
            discard advance(p)
            return PrimaryExpr(kind: pkString, stringValue: nxt.lexeme)
        of tkIdentifier:
            discard advance(p)
            return PrimaryExpr(kind: pkIden, strValue: nxt.lexeme)
        of tkLeftParen:
            discard advance(p)
            let exp = parse_expr(p)
            discard consume(p, tkRightParen, "Expected ')' after expression")
            return PrimaryExpr(kind: pkParen, exprValue: exp)
        else:
            error(nxt, "Invalid primary expression")
            raise newException(NoroParseError, "Invalid primary expression")



proc parse_argument_expression_list(p: var Parser): seq[Expr] =
    var args: seq[Expr] = @[]
    while not match(p, tkRightParen):
        let expr = parse_expr(p)
        args.add(expr)
        if not match(p, tkComma):
            discard consume(p, tkRightParen, "Expected ')' or ',' after argument")
            break

    return args

proc parse_postfix(p: var Parser): Expr =
    var primary_expr = parse_primary_expr(p)
    if match(p, tkLeftParen):
        let arg_list = parse_argument_expression_list(p)
        let callexpr = CallExpr(callee: primary_expr, args: arg_list)
        return callexpr

    return primary_expr

proc toMultOp(t: Token): MultiplicativeOperator =
    case t.typ:
        of tkStar:
            return multOpMul
        of tkSlash:
            return multOpDiv
        else:
            error(t, "Invalid multiplicative operator")
            raise newException(NoroParseError, "Invalid multiplicative operator")

proc parse_multiplicative_expr(p: var Parser): Expr =
    var lhs = parse_postfix(p)
    while match(p, tkStar) or match(p, tkSlash):
        let op = previous(p)
        let rhs = parse_postfix(p)
        lhs = MultiplicativeExpr(lhs: lhs, op: toMultOp(op), rhs: rhs)

    return lhs

proc toAddOp(t: Token): AdditiveOperator =
    case t.typ:
        of tkPlus:
            return addOpAdd
        of tkMinus:
            return addOpMinus
        else:
            error(t, "Invalid additive operator")
            raise newException(NoroParseError, "Invalid additive operator")

proc parse_additive_expr(p: var Parser): Expr =
    var lhs = parse_multiplicative_expr(p)
    while match(p, tkPlus) or match(p, tkMinus):
        let op = previous(p)
        let rhs = parse_multiplicative_expr(p)
        lhs = AdditiveExpr(lhs: lhs, op: toAddOp(op), rhs: rhs)

    return lhs


proc parse_relational_expr(p: var Parser): Expr =
    var lhs = parse_additive_expr(p)
    if match(p, tkLess):
        let rhs = parse_additive_expr(p)
        return RelationalExpr(lhs: lhs, op: relOpLt, rhs: rhs)
    elif match(p, tkGreater):
        let rhs = parse_additive_expr(p)
        return RelationalExpr(lhs: lhs, op: relOpGt, rhs: rhs)
    elif match(p, tkLessEqual):
        let rhs = parse_additive_expr(p)
        return RelationalExpr(lhs: lhs, op: relOpLte, rhs: rhs)
    elif match(p, tkGreaterEqual):
        let rhs = parse_additive_expr(p)
        return RelationalExpr(lhs: lhs, op: relOpGte, rhs: rhs)

    return lhs


proc parse_equality_expr(p: var Parser): Expr =
    var lhs = parse_relational_expr(p)
    if match(p, tkEqualEqual):
        let rhs = parse_relational_expr(p)
        return EqualityExpr(lhs: lhs, op: eqOpEq, rhs: rhs)
    elif match(p, tkBangEqual):
        let rhs = parse_relational_expr(p)
        return EqualityExpr(lhs: lhs, op: eqOpNeq, rhs: rhs)

    return lhs


proc parse_logical_and(p: var Parser): Expr =
    var lhs = parse_equality_expr(p)
    while match(p, tkAnd):
        let rhs = parse_equality_expr(p)
        lhs = LogicalAndExpr(lhs: lhs, rhs: rhs)

    return lhs


proc parse_logical_or(p: var Parser): Expr =
    var lhs = parse_logical_and(p)
    while match(p, tkOr):
        let rhs = parse_logical_and(p)
        lhs = LogicalOrExpr(lhs: lhs, rhs: rhs)

    return lhs


proc parse_assignment(p: var Parser): Expr =
    if peektwo(p).typ != tkEqual:
        return parse_logical_or(p)

    let lhs = parse_postfix(p)
    if match(p, tkEqual):
        let rhs = parse_logical_or(p)
        return AssignmentExpr(lhs: lhs, rhs: rhs)

    error(peek(p), "Expected '=' after identifier")
    raise newException(NoroParseError, "Expected '=' after identifier")


proc parse_expr(p: var Parser): Expr =
    parse_assignment(p)

proc parse_init_declarator(p: var Parser): InitDeclarator =
    let id = parse_identifier(p)
    discard consume(p, tkEqual, "Expected '=' after identifier")
    let init_expr = parse_expr(p)
    return InitDeclarator(name: id, initializer: init_expr)


proc parse_declaration(p: var Parser): Declaration =
    let vds = parse_var_decl_specs(p)

    if vds.len == 0:
        error(peek(p), "Expected variable declaration specifier")
        raise newException(NoroParseError, "Expected variable declaration specifier")

    let initdecl = parse_init_declarator(p)
    discard consume(p, tkSemicolon, "Expected ';' after declaration")
    Declaration(specifiers: vds, initDeclarator: initdecl)


proc to_func_specifier(token: Token): FuncSpecifier =
    case token.typ:
        of tkPure:
            return fsKindPure
        else:
            error(token, "Invalid function specifier")
            raise newException(NoroParseError, "Invalid function specifier")


proc parse_func_specifiers(p: var Parser): seq[FuncSpecifier] =
    var specs: seq[FuncSpecifier] = @[]
    while is_function_specifier(peek(p)):
        let specifier_token = peek(p)
        let spec = to_func_specifier(specifier_token)
        specs.add(spec)
        discard advance(p)

    return specs



proc parse_param_decl(p: var Parser): ParamDecl =
    let specifiers = parse_var_decl_specs(p)
    let name = parse_identifier(p)
    return ParamDecl(specifiers: specifiers, name: name)

proc parse_param_decls(p: var Parser): seq[ParamDecl] =
    var param_decls: seq[ParamDecl] = @[]
    while not match(p, tkRightParen):
        let param_decl = parse_param_decl(p)
        param_decls.add(param_decl)
        if not match(p, tkComma):
            discard consume(p, tkRightParen, "Expected ')' or ',' after parameter declaration")
            break

    return param_decls


proc parse_return_stmt(p: var Parser): ReturnStmt =
    discard consume(p, tkReturn, "Expected 'return' keyword")
    let exp = parse_expr(p)
    discard consume(p, tkSemicolon, "Expected ';' after return statement")
    return ReturnStmt(ex: exp)

proc parse_expression_stmt(p: var Parser): ExprStmt =
    let exp = parse_expr(p)
    discard consume(p, tkSemicolon, "Expected ';' after expression")
    return ExprStmt(ex: exp)

proc parse_stmt(p: var Parser): Stmt
proc parse_compound_stmt(p: var Parser): CompoundStmt

proc parse_if_stmt(p: var Parser): IfStmt =
    discard consume(p, tkIf, "Expected 'if' keyword")
    discard consume(p, tkLeftParen, "Expected '(' after 'if'")
    let cond = parse_expr(p)
    discard consume(p, tkRightParen, "Expected ')' after condition")
    let then_stmt = parse_stmt(p)
    var else_stmt: Stmt
    if match(p, tkElse):
        else_stmt = parse_stmt(p)

    return IfStmt(cond: cond, thenStmt: then_stmt, elseStmt: else_stmt)

proc parse_stmt(p: var Parser): Stmt =
    var nxt = peek(p)
    case nxt.typ:
        of tkReturn:
            return Stmt(kind: skReturn, returnStmt: parse_return_stmt(p))
        of tkIdentifier:
            return Stmt(kind: skExpr, exprStmt: parse_expression_stmt(p))
        of tkIf:
            return Stmt(kind: skIf, ifStmt: parse_if_stmt(p))
        else:
            return Stmt(kind: skCompound, compoundStmt: parse_compound_stmt(p))


proc is_stmt_begin(t: Token): bool =
    t.typ == tkIf or t.typ == tkReturn or t.typ == tkIdentifier

proc parse_block_item(p: var Parser): BlockItem =
    if is_stmt_begin(peek(p)):
        let stm = parse_stmt(p)
        return BlockItem(kind: blkStatement, statement: stm)

    let decl = parse_declaration(p)
    return BlockItem(kind: blkDeclaration, declaration: decl)


proc parse_compound_stmt(p: var Parser): CompoundStmt =
    discard consume(p, tkLeftBrace, "Expected '{' before compound statement")
    var block_items: seq[BlockItem] = @[]
    while not match(p, tkRightBrace):
        let block_item = parse_block_item(p)
        block_items.add(block_item)

    return CompoundStmt(blockItems: block_items)


proc parse_function_def(p: var Parser): FuncDef =
    let specifiers = parse_func_specifiers(p)
    discard consume(p, tkFun, "Expected 'function' keyword before function name")
    let name = parse_identifier(p)
    discard consume(p, tkLeftParen, "Expected '(' after function name")
    let param_list = parse_param_decls(p)
    discard consume(p, tkArrow, "Expected '->' before return type")
    let return_type = to_type_specifier(peek(p))
    discard advance(p)
    let body = parse_compound_stmt(p)
    return FuncDef(specifiers: specifiers, name: name,
            paramsDeclList: param_list, returnType: return_type, body: body)

proc parse_external_declaration(p: var Parser): ExternalDecl =
    let nxtToken = peek(p)
    if indicates_function_specifier(nxtToken):
        let funcdecl = parse_function_def(p)
        return ExternalDecl(kind: externalDeclKindFuncDef, funcDef: funcdecl)

    let decl = parse_declaration(p)
    return ExternalDecl(kind: externalDeclKindDeclaration, decl: decl)


proc parse*(tokens: seq[Token]): Program =
    var parser = Parser(tokens: tokens, current: 0)
    var externalDecls: seq[ExternalDecl]
    while not parser.isAtEnd():
        let externalDecl = parse_external_declaration(parser)
        externalDecls.add(externalDecl)
    Program(externalDecls: externalDecls)

