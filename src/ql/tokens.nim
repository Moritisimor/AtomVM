import std/strformat

type
  TokenKind* = enum
    tkIdent, tkInt, tkStr, tkChar, tkBool,
    tkFn, tkLet, tkMut, tkIf, tkElse, tkCase, tkFor, tkWhile, tkIn,
    tkReturn, tkBreak, tkContinue, tkImport, tkPub, tkConst, tkType, tkShape, tkImpl, tkSpawn,
    tkMake, tkWire, tkTrue, tkFalse, tkNil, tkAnd, tkOr, tkNot,
    tkSome, tkNone, tkOk, tkErr,
    tkLParen, tkRParen, tkLBrace, tkRBrace, tkLBrack, tkRBrack,
    tkComma, tkColon, tkDColon, tkDot, tkSemi, tkUnder,
    tkArrow, tkFatArrow, tkPipe, tkRange, tkSend,
    tkPlus, tkMinus, tkStar, tkDiv, tkMod,
    tkEq, tkNeq, tkLt, tkGt, tkLe, tkGe,
    tkAssign, tkPlusEq, tkMinusEq, tkStarEq, tkDivEq, tkModEq,
    tkShl, tkShr, tkBitOr, tkBitXor, tkBitAnd, tkBang,
    tkTry, tkDotQ,
    tkEof, tkError

  Token* = object
    kind*: TokenKind
    text*: string
    line*, col*: int

  Lexer = object
    src: string
    pos, line, col: int

proc newLexer(src: string): Lexer =
  Lexer(src: src, line: 1, col: 1)

proc peek(lex: Lexer): char =
  if lex.pos < lex.src.len: lex.src[lex.pos] else: char(0)

proc advance(lex: var Lexer) =
  if lex.pos >= lex.src.len: return
  if lex.src[lex.pos] == '\n':
    inc lex.line
    lex.col = 1
  else:
    inc lex.col
  inc lex.pos

proc skipWhitespace(lex: var Lexer) =
  while lex.pos < lex.src.len and lex.src[lex.pos] in {' ', '\t', '\n', '\r'}:
    advance(lex)

proc skipComment(lex: var Lexer) =
  if peek(lex) == '/' and lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '/':
    while lex.pos < lex.src.len and lex.src[lex.pos] != '\n': advance(lex)
  elif peek(lex) == '/' and lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '*':
    advance(lex); advance(lex)
    while lex.pos + 1 < lex.src.len and not (lex.src[lex.pos] == '*' and lex.src[lex.pos + 1] == '/'):
      advance(lex)
    if lex.pos + 1 < lex.src.len:
      advance(lex); advance(lex)

proc readIdent(lex: var Lexer): string =
  let start = lex.pos
  while lex.pos < lex.src.len and lex.src[lex.pos] in {'a'..'z', 'A'..'Z', '0'..'9', '_'}:
    advance(lex)
  lex.src[start ..< lex.pos]

proc readInt(lex: var Lexer): string =
  let start = lex.pos
  if lex.pos + 1 < lex.src.len and lex.src[lex.pos] == '0' and lex.src[lex.pos + 1] in {'x', 'o', 'b'}:
    advance(lex); advance(lex)
    while lex.pos < lex.src.len and lex.src[lex.pos] in {'0'..'9', 'a'..'f', 'A'..'F'}: advance(lex)
  else:
    while lex.pos < lex.src.len and lex.src[lex.pos] in {'0'..'9'}: advance(lex)
  lex.src[start ..< lex.pos]

proc readString(lex: var Lexer): string =
  advance(lex)
  var text = ""
  while lex.pos < lex.src.len and lex.src[lex.pos] != '"':
    if lex.src[lex.pos] == '\\' and lex.pos + 1 < lex.src.len:
      advance(lex)
      case lex.src[lex.pos]
      of 'n': text.add('\n')
      of 't': text.add('\t')
      of '0': text.add('\0')
      of '"': text.add('"')
      of '\\': text.add('\\')
      else: text.add(lex.src[lex.pos])
      advance(lex)
    else:
      text.add(lex.src[lex.pos])
      advance(lex)
  if lex.pos < lex.src.len: advance(lex)
  text

proc readChar(lex: var Lexer): string =
  advance(lex)
  let start = lex.pos
  if lex.pos < lex.src.len and lex.src[lex.pos] == '\\': advance(lex)
  if lex.pos < lex.src.len: advance(lex)
  result = lex.src[start ..< lex.pos]
  if lex.pos < lex.src.len and lex.src[lex.pos] == '\'': advance(lex)

proc keywordToToken(s: string): TokenKind =
  case s
  of "fn": tkFn
  of "let": tkLet
  of "mut": tkMut
  of "if": tkIf
  of "else": tkElse
  of "case": tkCase
  of "for": tkFor
  of "while": tkWhile
  of "in": tkIn
  of "return": tkReturn
  of "break": tkBreak
  of "continue": tkContinue
  of "import": tkImport
  of "pub": tkPub
  of "const": tkConst
  of "type": tkType
  of "shape": tkShape
  of "impl": tkImpl
  of "spawn": tkSpawn
  of "make": tkMake
  of "wire": tkWire
  of "true": tkTrue
  of "false": tkFalse
  of "nil": tkNil
  of "and": tkAnd
  of "or": tkOr
  of "not": tkNot
  of "Some": tkSome
  of "None": tkNone
  of "Ok": tkOk
  of "Err": tkErr
  else: tkIdent

proc one(kind: TokenKind, text: string, line, col: int): Token =
  Token(kind: kind, text: text, line: line, col: col)

proc nextToken(lex: var Lexer): Token =
  skipWhitespace(lex)
  while peek(lex) == '/' and lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] in {'/', '*'}:
    skipComment(lex)
    skipWhitespace(lex)
  if lex.pos >= lex.src.len: return one(tkEof, "", lex.line, lex.col)
  let line = lex.line
  let col = lex.col
  let ch = peek(lex)
  case ch
  of 'a'..'z', 'A'..'Z', '_':
    let text = readIdent(lex)
    one(keywordToToken(text), text, line, col)
  of '0'..'9': one(tkInt, readInt(lex), line, col)
  of '"': one(tkStr, readString(lex), line, col)
  of '\'': one(tkChar, readChar(lex), line, col)
  of '(': advance(lex); one(tkLParen, "(", line, col)
  of ')': advance(lex); one(tkRParen, ")", line, col)
  of '{': advance(lex); one(tkLBrace, "{", line, col)
  of '}': advance(lex); one(tkRBrace, "}", line, col)
  of '[': advance(lex); one(tkLBrack, "[", line, col)
  of ']': advance(lex); one(tkRBrack, "]", line, col)
  of ',': advance(lex); one(tkComma, ",", line, col)
  of ';': advance(lex); one(tkSemi, ";", line, col)
  of '.':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '.': advance(lex); advance(lex); one(tkRange, "..", line, col)
    else: advance(lex); one(tkDot, ".", line, col)
  of ':':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == ':': advance(lex); advance(lex); one(tkDColon, "::", line, col)
    else: advance(lex); one(tkColon, ":", line, col)
  of '|':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '>': advance(lex); advance(lex); one(tkPipe, "|>", line, col)
    elif lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '|': advance(lex); advance(lex); one(tkBitOr, "||", line, col)
    else: advance(lex); one(tkBitOr, "|", line, col)
  of '=':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkEq, "==", line, col)
    elif lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '>': advance(lex); advance(lex); one(tkFatArrow, "=>", line, col)
    else: advance(lex); one(tkAssign, "=", line, col)
  of '!':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkNeq, "!=", line, col)
    else: advance(lex); one(tkBang, "!", line, col)
  of '<':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkLe, "<=", line, col)
    elif lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '<': advance(lex); advance(lex); one(tkShl, "<<", line, col)
    elif lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '-': advance(lex); advance(lex); one(tkSend, "<-", line, col)
    else: advance(lex); one(tkLt, "<", line, col)
  of '>':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkGe, ">=", line, col)
    elif lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '>': advance(lex); advance(lex); one(tkShr, ">>", line, col)
    else: advance(lex); one(tkGt, ">", line, col)
  of '-':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '>': advance(lex); advance(lex); one(tkArrow, "->", line, col)
    elif lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkMinusEq, "-=", line, col)
    else: advance(lex); one(tkMinus, "-", line, col)
  of '+':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkPlusEq, "+=", line, col)
    else: advance(lex); one(tkPlus, "+", line, col)
  of '*':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkStarEq, "*=", line, col)
    else: advance(lex); one(tkStar, "*", line, col)
  of '/':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkDivEq, "/=", line, col)
    else: advance(lex); one(tkDiv, "/", line, col)
  of '%':
    if lex.pos + 1 < lex.src.len and lex.src[lex.pos + 1] == '=': advance(lex); advance(lex); one(tkModEq, "%=", line, col)
    else: advance(lex); one(tkMod, "%", line, col)
  of '&': advance(lex); one(tkBitAnd, "&", line, col)
  of '^': advance(lex); one(tkBitXor, "^", line, col)
  of '~': advance(lex); one(tkBang, "~", line, col)
  else:
    advance(lex)
    one(tkError, $ch, line, col)

proc tokenize*(src: string): seq[Token] =
  var lex = newLexer(src)
  while true:
    let tok = nextToken(lex)
    result.add(tok)
    if tok.kind == tkError:
      raise newException(ValueError, fmt"unexpected character '{tok.text}' at {tok.line}:{tok.col}")
    if tok.kind == tkEof: break
