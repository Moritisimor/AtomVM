type
  ExprKind* = enum
    eInt, eStr, eChar, eBool, eNil,
    eNoop,
    eArrayLit, eStructLit, eTypeDecl,
    eIdent, eBinary, eUnary,
    eBlock, eIf, eWhile, eFor, eCase, eFnDecl, eFnCall,
    eVarDecl, eAssign, eReturn, eBreak, eContinue,
    ePipe, ePrint, ePrintStr

  Expr* = ref object
    case kind*: ExprKind
    of eInt:
      intVal*: int
    of eStr:
      strVal*: string
    of eChar:
      charVal*: char
    of eBool:
      boolVal*: bool
    of eNil:
      nilVal*: bool
    of eNoop:
      discard
    of eArrayLit:
      eItems*: seq[Expr]
    of eStructLit:
      eStructName*: string
      eFields*: seq[tuple[name: string, value: Expr]]
    of eTypeDecl:
      eTypeName*: string
      eTypeFields*: seq[tuple[name: string, typ: Expr]]
      eTypeVariants*: seq[string]
    of eIdent:
      identName*: string
    of eBinary:
      eBinaryOp*: string
      eLeft*, eRight*: Expr
    of eUnary:
      eUnaryOp*: string
      eOperand*: Expr
    of eBlock:
      eStmts*: seq[Expr]
    of eIf:
      eCond*, eThen*, eElse*: Expr
    of eWhile:
      eWhileCond*, eWhileBody*: Expr
    of eFor:
      eForVar*: string
      eForStart*, eForEnd*, eForBody*: Expr
    of eCase:
      eCaseExpr*: Expr
      eArms*: seq[tuple[pat: Expr, guard: Expr, body: Expr]]
    of eFnDecl:
      eFnName*: string
      eParams*: seq[tuple[name: string, typ: Expr]]
      eRetType*: Expr
      eBody*: Expr
      eFnClauses*: seq[Expr]
    of eFnCall:
      eCallee*: Expr
      eArgs*: seq[Expr]
    of eVarDecl:
      eVarMut*: bool
      eVarName*: string
      eVarType*: Expr
      eVarInit*: Expr
    of eAssign:
      eAssignTarget*: Expr
      eAssignVal*: Expr
    of eReturn:
      eRetVal*: Expr
    of eBreak, eContinue:
      discard
    of ePipe:
      ePipeLeft*, ePipeRight*: Expr
    of ePrint:
      ePrintVal*: Expr
    of ePrintStr:
      ePrintStrVal*: Expr
