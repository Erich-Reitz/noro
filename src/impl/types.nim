type
    Token* = object
        typ*: TokenType
        value*: Value
        lexeme*: string
        line*: int

    NoroParseError* = object of CatchableError

    TokenType* = enum
        tkLeftParen, tkRightParen, tkLeftBrace, tkRightBrace,
        tkComma, tkDot, tkMinus, tkPlus, tkSemicolon, tkSlash, tkStar,

        # One or two character tokens.
        tkBang, tkBangEqual,
        tkEqual, tkEqualEqual,
        tkGreater, tkGreaterEqual,
        tkLess, tkLessEqual,

        # Literals.
        tkIdentifier, tkString, tkInt,

        # Keywords.
        tkAnd, tkElse, tkFalse, tkFun, tkFor, tkIf, tkIntDecl, tkStringDecl,
            tkOr,
        tkReturn, tkTrue, tkWhile, tkConst, tkPure, tkBoolDecl, tkArrow, tkForbid

        tkEOF

    ValueKind* = enum lkBool, lkNum, lkString, lkIden

    Value* = ref object of RootObj
        case kind*: ValueKind
        of lkBool: boolVal*: bool
        of lkString, lkIden: strVal*: string
        of lkNum: numVal*: int


type
    PrimaryExprKind* = enum
        pkIden, pkInt, pkString, pkBool, pkParen

    MultiplicativeOperator* = enum
        multOpMul, multOpDiv

    AdditiveOperator* = enum
        addOpAdd, addOpMinus

    RelationalOperator* = enum
        relOpLt, relOpGt, relOpLte, relOpGte

    EqualityOperator* = enum
        eqOpEq, eqOpNeq

    FuncSpecifier* = enum
        fsKindNone, fsKindPure

    TypeQualifier* = enum
        tqNone, tqConst, tqForbid

    BuiltinType* = enum
        binTypeUnset, binTypeInt, binTypeString, binTypeBool

    # Objects
    Expr* = ref object of RootObj

    PrimaryExpr* = ref object of Expr
        case kind*: PrimaryExprKind
        of pkIden:
            strValue*: string
        of pkInt:
            intValue*: int64
        of pkString:
            stringValue*: string
        of pkBool:
            boolValue*: bool
        of pkParen:
            exprValue*: Expr
        token*: Token

    CallExpr* = ref object of Expr
        callee*: PrimaryExpr
        args*: seq[Expr]

    AssignmentExpr* = ref object of Expr
        lhs*, rhs*: Expr

    MultiplicativeExpr* = ref object of Expr
        lhs*, rhs*: Expr
        op*: MultiplicativeOperator

    AdditiveExpr* = ref object of Expr
        lhs*, rhs*: Expr
        op*: AdditiveOperator

    RelationalExpr* = ref object of Expr
        lhs*, rhs*: Expr
        op*: RelationalOperator

    EqualityExpr* = ref object of Expr
        lhs*, rhs*: Expr
        op*: EqualityOperator

    LogicalAndExpr* = ref object of Expr
        lhs*, rhs*: Expr

    LogicalOrExpr* = ref object of Expr
        lhs*, rhs*: Expr

    TypeSpeciferKind* = enum
        tsKindBnType, tsKindDecl

    TypeSpecifer* = object
        case kind*: TypeSpeciferKind
        of tsKindBnType:
            builtinType*: BuiltinType
        of tsKindDecl:
            typeDecl*: TypeDecl

    VariableDeclSpecifierKind* = enum
        vdsKindTypeSpecifer, vdsKindTypeQualifier

    VariableDeclSpecifier* = object
        case kind*: VariableDeclSpecifierKind
        of vdsKindTypeSpecifer:
            typeSpec*: TypeSpecifer
        of vdsKindTypeQualifier:
            typeQualifier*: TypeQualifier

    TypeDecl* = object
        name*: string

    ParamDecl* = object
        specifiers*: seq[VariableDeclSpecifier]
        name*: string

    InitDeclarator* = object
        name*: string
        initializer*: Expr

    Declaration* = ref object
        specifiers*: seq[VariableDeclSpecifier]
        initDeclarator*: InitDeclarator

    ReturnStmt* = object
        ex*: Expr

    ExprStmt* = object
        ex*: Expr

    ForbidStmt* = object
        iden*: string

    IfStmt* = object
        cond*: Expr
        thenStmt*: Stmt
        elseStmt*: Stmt
        relOp*: RelationalOperator

    BlockItemKind* = enum
        blkDeclaration, blkStatement
    # BlockItem Details
    BlockItem* = object
        case kind*: BlockItemKind
        of blkDeclaration:
            declaration*: Declaration
        of blkStatement:
            statement*: Stmt



    StmtKind* = enum
        skReturn, skExpr, skIf, skCompound, skForbid

    Stmt* = ref object
        case kind*: StmtKind
        of skReturn:
            returnStmt*: ReturnStmt
        of skExpr:
            exprStmt*: ExprStmt
        of skIf:
            ifStmt*: IfStmt
        of skCompound:
            compoundStmt*: CompoundStmt
        of skForbid:
            forbidStmt*: ForbidStmt


    CompoundStmt* = object
        blockItems*: seq[BlockItem]

    FuncDef* = object
        specifiers*: seq[FuncSpecifier]
        name*: string
        paramsDeclList*: seq[ParamDecl]
        returnType*: TypeSpecifer
        body*: CompoundStmt

    ExternalDeclKind* = enum
        externalDeclKindFuncDef, externalDeclKindDeclaration
    ExternalDecl* = object
        case kind*: ExternalDeclKind
        of externalDeclKindFuncDef:
            funcDef*: FuncDef
        of externalDeclKindDeclaration:
            decl*: Declaration


    Program* = ref object
        externalDecls*: seq[ExternalDecl]


