import std/strformat
import std/strutils
import ./ast
import ./tokens

type Parser = object
  tokens: seq[Token]
  pos: int
  errors: seq[string]

proc peek(p: Parser): Token =
  if p.pos < p.tokens.len: p.tokens[p.pos] else: Token(kind: tkEof)

proc advance(p: var Parser): Token =
  result = peek(p)
  if p.pos < p.tokens.len: inc p.pos

proc expect(p: var Parser, kind: TokenKind): Token =
  result = peek(p)
  if result.kind != kind:
    p.errors.add(fmt"expected {kind} at line {result.line}, got '{result.text}'")
  discard advance(p)

proc parseExpr(p: var Parser): Expr
proc parseBlock(p: var Parser): Expr
proc parseIf(p: var Parser): Expr
proc parseWhile(p: var Parser): Expr
proc parseFor(p: var Parser): Expr
proc parseCase(p: var Parser): Expr
proc parseReturn(p: var Parser): Expr
proc parseVarDecl(p: var Parser): Expr
proc parseTypeDecl(p: var Parser): Expr

proc parseLoopControl(p: var Parser): Expr =
  let tok = advance(p)
  if tok.kind == tkBreak: Expr(kind: eBreak) else: Expr(kind: eContinue)

proc parseIntLiteral(tok: Token): int =
  if tok.text.len > 2 and tok.text[0..1] == "0x": parseHexInt(tok.text)
  elif tok.text.len > 2 and tok.text[0..1] == "0b": parseBinInt(tok.text)
  elif tok.text.len > 2 and tok.text[0..1] == "0o": parseOctInt(tok.text)
  else: parseInt(tok.text)

proc parseIntExpr(p: var Parser): Expr =
  Expr(kind: eInt, intVal: parseIntLiteral(advance(p)))

proc parseCharExpr(p: var Parser): Expr =
  let tok = advance(p)
  if tok.text.len == 1: Expr(kind: eChar, charVal: tok.text[0])
  elif tok.text == "\\n": Expr(kind: eChar, charVal: '\n')
  elif tok.text == "\\t": Expr(kind: eChar, charVal: '\t')
  elif tok.text == "\\0": Expr(kind: eChar, charVal: '\0')
  elif tok.text == "\\\\": Expr(kind: eChar, charVal: '\\')
  elif tok.text == "\\'": Expr(kind: eChar, charVal: '\'')
  else:
    p.errors.add(fmt"unsupported char escape at line {tok.line}")
    Expr(kind: eChar, charVal: '?')

proc parseQualifiedName(p: var Parser): string =
  let tok = advance(p)
  result = tok.text
  while peek(p).kind == tkDColon:
    discard advance(p)
    let part = expect(p, tkIdent)
    result.add("::")
    result.add(part.text)

proc parseSimpleName(p: var Parser): string =
  expect(p, tkIdent).text

proc parseIdentExpr(p: var Parser): Expr =
  Expr(kind: eIdent, identName: parseQualifiedName(p))

proc parseArrayLit(p: var Parser): Expr =
  discard expect(p, tkLBrack)
  var items: seq[Expr] = @[]
  if peek(p).kind != tkRBrack:
    items.add(parseExpr(p))
    while peek(p).kind == tkComma:
      discard advance(p)
      if peek(p).kind == tkRBrack: break
      items.add(parseExpr(p))
  discard expect(p, tkRBrack)
  Expr(kind: eArrayLit, eItems: items)

proc parseAtom(p: var Parser): Expr =
  case peek(p).kind
  of tkInt: parseIntExpr(p)
  of tkStr:
    let tok = advance(p)
    Expr(kind: eStr, strVal: tok.text)
  of tkChar: parseCharExpr(p)
  of tkTrue, tkFalse:
    let tok = advance(p)
    Expr(kind: eBool, boolVal: tok.kind == tkTrue)
  of tkNil:
    discard advance(p)
    Expr(kind: eNil)
  of tkLParen:
    discard advance(p)
    let expr = parseExpr(p)
    discard expect(p, tkRParen)
    expr
  of tkLBrack: parseArrayLit(p)
  of tkIdent, tkUnder: parseIdentExpr(p)
  of tkLBrace: parseBlock(p)
  of tkIf: parseIf(p)
  of tkWhile: parseWhile(p)
  of tkFor: parseFor(p)
  of tkCase: parseCase(p)
  of tkReturn: parseReturn(p)
  of tkBreak, tkContinue: parseLoopControl(p)
  of tkLet, tkMut, tkConst: parseVarDecl(p)
  else:
    let tok = advance(p)
    p.errors.add(fmt"unexpected token '{tok.text}' at line {tok.line}")
    Expr(kind: eInt, intVal: 0)

proc parseCall(p: var Parser, callee: Expr): Expr =
  discard expect(p, tkLParen)
  var args: seq[Expr] = @[]
  if peek(p).kind != tkRParen:
    args.add(parseExpr(p))
    while peek(p).kind == tkComma:
      discard advance(p)
      args.add(parseExpr(p))
  discard expect(p, tkRParen)
  if callee.kind == eIdent and callee.identName == "print" and args.len == 1:
    if args[0].kind == eStr: return Expr(kind: ePrintStr, ePrintStrVal: args[0])
    return Expr(kind: ePrint, ePrintVal: args[0])
  Expr(kind: eFnCall, eCallee: callee, eArgs: args)

proc parsePostfix(p: var Parser, left: Expr): Expr =
  result = left
  while true:
    case peek(p).kind
    of tkLParen: result = parseCall(p, result)
    of tkDot:
      discard advance(p)
      let name = Expr(kind: eIdent, identName: parseSimpleName(p))
      if peek(p).kind == tkLParen: result = parseCall(p, name)
      else: result = Expr(kind: eBinary, eBinaryOp: ".", eLeft: result, eRight: name)
    of tkLBrack:
      discard advance(p)
      let idx = parseExpr(p)
      discard expect(p, tkRBrack)
      result = Expr(kind: eBinary, eBinaryOp: "[]", eLeft: result, eRight: idx)
    of tkLBrace:
      if result.kind != eIdent: break
      if result.identName.len == 0 or result.identName[0] notin {'A'..'Z'}: break
      let structName = result.identName
      discard advance(p)
      var fields: seq[tuple[name: string, value: Expr]] = @[]
      while peek(p).kind notin {tkRBrace, tkEof}:
        let fieldName = parseSimpleName(p)
        discard expect(p, tkColon)
        fields.add((name: fieldName, value: parseExpr(p)))
        if peek(p).kind == tkComma: discard advance(p)
      discard expect(p, tkRBrace)
      result = Expr(kind: eStructLit, eStructName: structName, eFields: fields)
    else: break

proc parseUnary(p: var Parser): Expr =
  if peek(p).kind in {tkMinus, tkBang, tkNot}:
    let op = advance(p).text
    Expr(kind: eUnary, eUnaryOp: op, eOperand: parseUnary(p))
  else:
    parsePostfix(p, parseAtom(p))

template leftAssoc(levelName, nextName: untyped, kinds: set[TokenKind]) =
  proc levelName(p: var Parser): Expr =
    result = nextName(p)
    while peek(p).kind in kinds:
      let op = advance(p).text
      result = Expr(kind: eBinary, eBinaryOp: op, eLeft: result, eRight: nextName(p))

leftAssoc(parseMul, parseUnary, {tkStar, tkDiv, tkMod})
leftAssoc(parseAdd, parseMul, {tkPlus, tkMinus})
leftAssoc(parseShift, parseAdd, {tkShl, tkShr})
leftAssoc(parseBitAnd, parseShift, {tkBitAnd})
leftAssoc(parseBitXor, parseBitAnd, {tkBitXor})
leftAssoc(parseBitOr, parseBitXor, {tkBitOr})
leftAssoc(parseCompare, parseBitOr, {tkEq, tkNeq, tkLt, tkGt, tkLe, tkGe})
leftAssoc(parseAnd, parseCompare, {tkAnd})
leftAssoc(parseOr, parseAnd, {tkOr})

proc parseAssign(p: var Parser): Expr =
  result = parseOr(p)
  if peek(p).kind in {tkAssign, tkPlusEq, tkMinusEq, tkStarEq, tkDivEq, tkModEq}:
    let op = advance(p).text
    let value = parseAssign(p)
    if result.kind == eIdent:
      if op == "=":
        result = Expr(kind: eAssign, eAssignTarget: result, eAssignVal: value)
      else:
        let baseOp = op[0 ..< op.len - 1]
        let target = result
        result = Expr(
          kind: eAssign,
          eAssignTarget: target,
          eAssignVal: Expr(kind: eBinary, eBinaryOp: baseOp, eLeft: target, eRight: value)
        )
    else: p.errors.add("invalid assignment target")

proc parsePipe(p: var Parser): Expr =
  result = parseAssign(p)
  if peek(p).kind == tkPipe:
    discard advance(p)
    result = Expr(kind: ePipe, ePipeLeft: result, ePipeRight: parsePipe(p))

proc parseExpr(p: var Parser): Expr = parsePipe(p)

proc parseBlock(p: var Parser): Expr =
  discard expect(p, tkLBrace)
  var stmts: seq[Expr] = @[]
  while peek(p).kind notin {tkRBrace, tkEof}:
    if peek(p).kind == tkSemi:
      discard advance(p)
    else:
      stmts.add(parseExpr(p))
      if peek(p).kind == tkSemi: discard advance(p)
  discard expect(p, tkRBrace)
  Expr(kind: eBlock, eStmts: stmts)

proc parseIf(p: var Parser): Expr =
  discard advance(p)
  let cond = parseExpr(p)
  let thenBranch = parseBlock(p)
  var elseBranch: Expr = nil
  if peek(p).kind == tkElse:
    discard advance(p)
    elseBranch = if peek(p).kind == tkIf: parseIf(p) else: parseBlock(p)
  Expr(kind: eIf, eCond: cond, eThen: thenBranch, eElse: elseBranch)

proc parseWhile(p: var Parser): Expr =
  discard advance(p)
  Expr(kind: eWhile, eWhileCond: parseExpr(p), eWhileBody: parseBlock(p))

proc parseFor(p: var Parser): Expr =
  discard advance(p)
  let varName = parseSimpleName(p)
  discard expect(p, tkIn)
  let start = parseExpr(p)
  discard expect(p, tkRange)
  let endExpr = parseExpr(p)
  Expr(kind: eFor, eForVar: varName, eForStart: start, eForEnd: endExpr, eForBody: parseBlock(p))

proc parseCase(p: var Parser): Expr =
  discard advance(p)
  let subject = parseExpr(p)
  discard expect(p, tkLBrace)
  var arms: seq[tuple[pat: Expr, guard: Expr, body: Expr]] = @[]
  while peek(p).kind notin {tkRBrace, tkEof}:
    if peek(p).kind == tkBitOr: discard advance(p)
    let pat = parseAtom(p)
    var guard: Expr = nil
    if peek(p).kind == tkIf:
      discard advance(p)
      guard = parseExpr(p)
    discard expect(p, tkFatArrow)
    let body = if peek(p).kind == tkLBrace: parseBlock(p) else: parseExpr(p)
    arms.add((pat: pat, guard: guard, body: body))
  discard expect(p, tkRBrace)
  Expr(kind: eCase, eCaseExpr: subject, eArms: arms)

proc parseReturn(p: var Parser): Expr =
  discard advance(p)
  if peek(p).kind in {tkRBrace, tkEof}: Expr(kind: eReturn, eRetVal: nil)
  else: Expr(kind: eReturn, eRetVal: parseExpr(p))

proc parseVarDecl(p: var Parser): Expr =
  let declKind = advance(p).kind
  let mutable = declKind == tkMut
  let name = parseSimpleName(p)
  var typ: Expr = nil
  if peek(p).kind == tkDColon:
    discard advance(p)
    typ = parseAtom(p)
  var init: Expr = nil
  if peek(p).kind == tkAssign:
    discard advance(p)
    init = parseExpr(p)
  Expr(kind: eVarDecl, eVarMut: mutable, eVarName: name, eVarType: typ, eVarInit: init)

proc parseFnClause(p: var Parser): Expr =
  discard advance(p)
  let name = parseQualifiedName(p)
  discard expect(p, tkLParen)
  var params: seq[tuple[name: string, typ: Expr]] = @[]
  if peek(p).kind != tkRParen:
    while true:
      let pname = parseSimpleName(p)
      var ptyp: Expr = nil
      if peek(p).kind == tkDColon:
        discard advance(p)
        ptyp = parseAtom(p)
      params.add((name: pname, typ: ptyp))
      if peek(p).kind != tkComma: break
      discard advance(p)
  discard expect(p, tkRParen)
  var retType: Expr = nil
  if peek(p).kind == tkArrow:
    discard advance(p)
    retType = parseAtom(p)
  Expr(kind: eFnDecl, eFnName: name, eParams: params, eRetType: retType, eBody: parseBlock(p))

proc parseFnDecl(p: var Parser): Expr =
  parseFnClause(p)

proc parseTypeDecl(p: var Parser): Expr =
  discard advance(p)
  let name = parseQualifiedName(p)
  var fields: seq[tuple[name: string, typ: Expr]] = @[]
  var variants: seq[string] = @[]
  if peek(p).kind == tkLBrace:
    discard advance(p)
    while peek(p).kind notin {tkRBrace, tkEof}:
      let fieldName = parseSimpleName(p)
      discard expect(p, tkDColon)
      fields.add((name: fieldName, typ: parseAtom(p)))
      if peek(p).kind == tkComma: discard advance(p)
    discard expect(p, tkRBrace)
  elif peek(p).kind == tkAssign:
    discard advance(p)
    while peek(p).kind notin {tkEof, tkFn, tkType, tkImport, tkLet, tkMut, tkConst, tkRBrace}:
      if peek(p).kind == tkBitOr:
        discard advance(p)
      let variant = expect(p, tkIdent)
      variants.add(variant.text)
      if peek(p).kind != tkBitOr: break
  else:
    p.errors.add(fmt"expected type body for '{name}'")
  Expr(kind: eTypeDecl, eTypeName: name, eTypeFields: fields, eTypeVariants: variants)

proc parseImport(p: var Parser): Expr =
  discard advance(p)
  discard expect(p, tkStr)
  Expr(kind: eNoop)

proc parseTopLevel(p: var Parser): Expr =
  case peek(p).kind
  of tkFn: parseFnDecl(p)
  of tkType: parseTypeDecl(p)
  of tkImport: parseImport(p)
  of tkLet, tkMut, tkConst: parseVarDecl(p)
  else: parseExpr(p)

proc parse*(tokens: seq[Token]): seq[Expr] =
  var p = Parser(tokens: tokens)
  while peek(p).kind != tkEof:
    if peek(p).kind == tkSemi: discard advance(p)
    else: result.add(parseTopLevel(p))
  if p.errors.len > 0:
    raise newException(ValueError, p.errors.join("\n"))
