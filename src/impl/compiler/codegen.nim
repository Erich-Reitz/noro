# import ast 

# type Ctx = ref object 
#     code*: string




# proc `+=`(c: Ctx, s: string) =
#     c.code.add(s)
    

# proc codegen(c: Ctx, n: AstConst) =
#     discard


# proc codegen(c: Ctx, n: AstReturn) =
#     discard

# proc codegen(c: Ctx, n: AstSeq) =
#     for a in n.stmts:
#         case a.kind:
#         of akConst:
#             codegen(c, a.constExpr)
#         of akMove:
#             codegen(c, a.moveExpr)
#         of akReturn:
#             codegen(c, a.returnExpr)

#         else:
#             echo "haven't implemented this yet: ", a.kind
#             quit QuitFailure




# proc codegen(c: Ctx, n: AstFrame) =
#     let name = n.name
#     c += name
#     c += ":\n"

#     c += "    push rbp\n"
#     c += "    mov rbp, rsp\n"

#     c += "    sub rsp, "
#     c += $(n.localvars * 8)
#     c += "\n"

#     for a in n.body.stmts:
#         case a.kind:
#         of akConst:
#             codegen(c, a.constExpr)
#         of akMove:
#             codegen(c, a.moveExpr)
#         of akSeq:
#             codegen(c, a.seqExpr)
#         of akReturn:
#             codegen(c, a.returnExpr)
#         else:
#             echo "haven't implemented this yet: ", a.kind
#             quit QuitFailure

#     if n.localvars > 0:
#         c += "    leave\n"
#     else:
#         c += "    pop rbp\n"

#     c += "    ret\n"



# proc codegen*(nodes: seq[AstNode]) =
#     let ctx = Ctx()

#     ctx += "section .text\n"    
#     ctx += "global _start\n"

#     for n in nodes:
#         case n.kind:
#         of akConst:
#             codegen(ctx, n.constExpr)
#         of akFrame:
#             codegen(ctx, n.frameExpr)
#         else:
#             discard

#     ctx += "_start:\n"
#     ctx += "    call main\n"
#     ctx += "    mov rdi, rax\n"
#     ctx += "    mov rax, 60\n"
#     ctx += "    syscall\n"


#     echo ctx.code
