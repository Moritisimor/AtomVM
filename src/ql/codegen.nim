import std/strformat
import std/strutils
import ./ast

type
  VarSlot = object
    name: string
    slot: int
    mutable: bool
    width: int
    typName: string

  StructDef = object
    name: string
    fields: seq[string]

  ConstDef = object
    name: string
    value: int
    typName: string

  FnSym = object
    name: string
    arity: int
    addrVal: int

  Ctx = object
    staticData: seq[byte]
    dataAddr: int
    nextAddr: int
    vars: seq[VarSlot]
    structs: seq[StructDef]
    consts: seq[ConstDef]
    code: seq[byte]
    fns: seq[FnSym]
    callPatches: seq[tuple[operandPos: int, fnName: string]]
    breakPatches: seq[seq[int]]
    continuePatches: seq[seq[int]]
    continueTargets: seq[int]
    errors: seq[string]

proc newCtx(): Ctx =
  Ctx(staticData: @[], dataAddr: 2000, nextAddr: 100, vars: @[], structs: @[], consts: @[], code: @[], fns: @[], callPatches: @[], breakPatches: @[], continuePatches: @[], continueTargets: @[], errors: @[])

proc emit(ctx: var Ctx, b: byte) = ctx.code.add(b)
proc emit2(ctx: var Ctx, b1, b2: byte) = ctx.code.add(b1); ctx.code.add(b2)
proc here(ctx: Ctx): int = ctx.code.len
proc patch(ctx: var Ctx, pos: int, val: int) = ctx.code[pos] = byte(val and 0xFF)

proc pushInt(ctx: var Ctx, val: int) =
  if val >= 0 and val <= 255:
    emit2(ctx, 0x01, byte(val))
  elif val >= 0 and val <= 65535:
    emit(ctx, 0x70)
    emit2(ctx, byte((val shr 8) and 0xFF), byte(val and 0xFF))
  else:
    ctx.errors.add(fmt"integer literal out of VM range: {val}")

proc pushAddr(ctx: var Ctx, address: int) =
  emit(ctx, 0x70)
  emit2(ctx, byte((address shr 8) and 0xFF), byte(address and 0xFF))

proc pushStr(ctx: var Ctx, s: string): int =
  result = ctx.dataAddr + ctx.staticData.len
  for c in s: ctx.staticData.add(byte(c))
  ctx.staticData.add(0)

proc addStaticBytes(ctx: var Ctx, bytes: seq[byte]): int =
  result = ctx.dataAddr + ctx.staticData.len
  ctx.staticData.add(bytes)

proc allocVar(ctx: var Ctx, name: string, mutable: bool, width = 1, typName = "byte"): int =
  result = ctx.nextAddr
  ctx.nextAddr += width
  ctx.vars.add(VarSlot(name: name, slot: result, mutable: mutable, width: width, typName: typName))

proc findVar(ctx: Ctx, name: string): int =
  for i in countdown(ctx.vars.len - 1, 0):
    if ctx.vars[i].name == name: return ctx.vars[i].slot
  -1

proc findVarIndex(ctx: Ctx, name: string): int =
  for i in countdown(ctx.vars.len - 1, 0):
    if ctx.vars[i].name == name: return i
  -1

proc findStruct(ctx: Ctx, name: string): int =
  for i, s in ctx.structs:
    if s.name == name: return i
  -1

proc fieldOffset(ctx: Ctx, typName, fieldName: string): int =
  let idx = findStruct(ctx, typName)
  if idx < 0: return -1
  for i, f in ctx.structs[idx].fields:
    if f == fieldName: return i
  -1

proc findConst(ctx: Ctx, name: string): int =
  for i, c in ctx.consts:
    if c.name == name: return i
  -1

proc typeNameOf(node: Expr): string =
  if node.isNil: return "byte"
  case node.kind
  of eStr: "str"
  of eArrayLit: "array"
  of eStructLit: node.eStructName
  of eIdent:
    if node.identName in ["str", "array"]: node.identName else: "byte"
  else: "byte"

proc widthOfType(typName: string): int =
  if typName in ["str", "array", "addr"]: 2 else: 1

proc builtinReturnType(name: string): string =
  case name
  of "alloc": "addr"
  else: "byte"

proc widthOfExpr(ctx: Ctx, node: Expr): int =
  if node.isNil: return 1
  case node.kind
  of eStr, eArrayLit, eStructLit: 2
  of eBinary:
    if node.eBinaryOp == "+" and node.eLeft.kind == eStr and node.eRight.kind == eStr: 2 else: 1
  of eFnCall:
    if node.eCallee.kind == eIdent: widthOfType(builtinReturnType(node.eCallee.identName)) else: 1
  of eIdent:
    let idx = findVarIndex(ctx, node.identName)
    if idx >= 0: ctx.vars[idx].width
    else:
      let constIdx = findConst(ctx, node.identName)
      if constIdx >= 0: 1 else: 1
  else: 1

proc typeOfExpr(ctx: Ctx, node: Expr): string =
  if node.isNil: return "byte"
  case node.kind
  of eStr: "str"
  of eBinary:
    if node.eBinaryOp == "+" and node.eLeft.kind == eStr and node.eRight.kind == eStr: "str" else: "byte"
  of eArrayLit: "array"
  of eStructLit: node.eStructName
  of eFnCall:
    if node.eCallee.kind == eIdent: builtinReturnType(node.eCallee.identName) else: "byte"
  of eIdent:
    let idx = findVarIndex(ctx, node.identName)
    if idx >= 0: ctx.vars[idx].typName
    else:
      let constIdx = findConst(ctx, node.identName)
      if constIdx >= 0: ctx.consts[constIdx].typName else: "byte"
  else: "byte"

proc findFn(ctx: Ctx, name: string): int =
  for f in ctx.fns:
    if f.name == name: return f.addrVal
  -1

proc hasFn(ctx: Ctx, name: string): bool =
  for f in ctx.fns:
    if f.name == name: return true
  false

proc setFnAddr(ctx: var Ctx, name: string, fnAddr: int) =
  for i, f in ctx.fns:
    if f.name == name:
      ctx.fns[i].addrVal = fnAddr
      return
  ctx.fns.add(FnSym(name: name, arity: 0, addrVal: fnAddr))

proc gen(ctx: var Ctx, node: Expr)

proc storeToSlot(ctx: var Ctx, slot, width: int) =
  if width == 2:
    emit2(ctx, 0x11, byte(slot + 1))
    emit2(ctx, 0x11, byte(slot))
  else:
    emit2(ctx, 0x11, byte(slot))

proc loadFromSlot(ctx: var Ctx, slot, width: int) =
  emit2(ctx, 0x12, byte(slot))
  if width == 2:
    emit2(ctx, 0x12, byte(slot + 1))

proc boolFromCmp(ctx: var Ctx, jumpOpcode: byte) =
  let trueJump = ctx.here()
  emit2(ctx, jumpOpcode, 0)
  pushInt(ctx, 0)
  let done = ctx.here()
  emit2(ctx, 0x07, 0)
  ctx.patch(trueJump + 1, ctx.here())
  pushInt(ctx, 1)
  ctx.patch(done + 1, ctx.here())

proc genIf(ctx: var Ctx, node: Expr) =
  gen(ctx, node.eCond)
  let elseJiz = ctx.here()
  emit2(ctx, 0x0B, 0)
  gen(ctx, node.eThen)
  if node.eElse != nil:
    let endJmp = ctx.here()
    emit2(ctx, 0x07, 0)
    ctx.patch(elseJiz + 1, ctx.here())
    gen(ctx, node.eElse)
    ctx.patch(endJmp + 1, ctx.here())
  else:
    ctx.patch(elseJiz + 1, ctx.here())

proc genWhile(ctx: var Ctx, node: Expr) =
  let loopStart = ctx.here()
  ctx.breakPatches.add(@[])
  ctx.continuePatches.add(@[])
  ctx.continueTargets.add(loopStart)
  gen(ctx, node.eWhileCond)
  let jizPos = ctx.here()
  emit2(ctx, 0x0B, 0)
  gen(ctx, node.eWhileBody)
  emit2(ctx, 0x07, byte(loopStart))
  ctx.patch(jizPos + 1, ctx.here())
  for pos in ctx.breakPatches[^1]: ctx.patch(pos + 1, ctx.here())
  for pos in ctx.continuePatches[^1]: ctx.patch(pos + 1, loopStart)
  discard ctx.breakPatches.pop()
  discard ctx.continuePatches.pop()
  discard ctx.continueTargets.pop()

proc genFor(ctx: var Ctx, node: Expr) =
  gen(ctx, node.eForStart)
  let varSlot = allocVar(ctx, node.eForVar, false)
  emit2(ctx, 0x11, byte(varSlot))
  let loopStart = ctx.here()
  emit2(ctx, 0x12, byte(varSlot))
  gen(ctx, node.eForEnd)
  let stop = ctx.here()
  emit2(ctx, 0x09, 0)
  ctx.breakPatches.add(@[])
  ctx.continuePatches.add(@[])
  ctx.continueTargets.add(-1)
  gen(ctx, node.eForBody)
  let continueTarget = ctx.here()
  for pos in ctx.continuePatches[^1]: ctx.patch(pos + 1, continueTarget)
  emit2(ctx, 0x12, byte(varSlot))
  emit(ctx, 0x14)
  emit2(ctx, 0x11, byte(varSlot))
  emit2(ctx, 0x07, byte(loopStart))
  ctx.patch(stop + 1, ctx.here())
  for pos in ctx.breakPatches[^1]: ctx.patch(pos + 1, ctx.here())
  discard ctx.breakPatches.pop()
  discard ctx.continuePatches.pop()
  discard ctx.continueTargets.pop()

proc genCase(ctx: var Ctx, node: Expr) =
  var endJumps: seq[int] = @[]
  for arm in node.eArms:
    gen(ctx, node.eCaseExpr)
    if arm.pat.kind == eInt or (arm.pat.kind == eIdent and findConst(ctx, arm.pat.identName) >= 0):
      if arm.pat.kind == eInt:
        pushInt(ctx, arm.pat.intVal)
      else:
        pushInt(ctx, ctx.consts[findConst(ctx, arm.pat.identName)].value)
      let eqPos = ctx.here()
      emit2(ctx, 0x09, 0)
      let skip = ctx.here()
      emit2(ctx, 0x07, 0)
      ctx.patch(eqPos + 1, ctx.here())
      gen(ctx, arm.body)
      endJumps.add(ctx.here())
      emit2(ctx, 0x07, 0)
      ctx.patch(skip + 1, ctx.here())
    elif arm.pat.kind == eIdent and arm.pat.identName == "_":
      gen(ctx, arm.body)
      endJumps.add(ctx.here())
      emit2(ctx, 0x07, 0)
    else:
      ctx.errors.add("unsupported case pattern")
  for jmp in endJumps: ctx.patch(jmp + 1, ctx.here())

proc genArrayLit(ctx: var Ctx, node: Expr) =
  var bytes: seq[byte] = @[byte(node.eItems.len and 0xFF)]
  for item in node.eItems:
    if item.kind in {eInt, eChar, eBool}:
      case item.kind
      of eInt: bytes.add(byte(item.intVal and 0xFF))
      of eChar: bytes.add(byte(item.charVal))
      of eBool: bytes.add(if item.boolVal: byte(1) else: byte(0))
      else: discard
    else:
      ctx.errors.add("array literals currently support byte, char, and bool values")
      bytes.add(0)
  pushAddr(ctx, addStaticBytes(ctx, bytes))

proc genStructLit(ctx: var Ctx, node: Expr) =
  let structIdx = findStruct(ctx, node.eStructName)
  if structIdx < 0:
    ctx.errors.add(fmt"unknown struct type '{node.eStructName}'")
    pushInt(ctx, 0)
    return
  var bytes = newSeq[byte](ctx.structs[structIdx].fields.len)
  for field in node.eFields:
    let offset = fieldOffset(ctx, node.eStructName, field.name)
    if offset < 0:
      ctx.errors.add(fmt"unknown field '{field.name}' on {node.eStructName}")
    elif field.value.kind == eInt:
      bytes[offset] = byte(field.value.intVal and 0xFF)
    elif field.value.kind == eChar:
      bytes[offset] = byte(field.value.charVal)
    elif field.value.kind == eBool:
      bytes[offset] = if field.value.boolVal: byte(1) else: byte(0)
    else:
      ctx.errors.add("struct literals currently support byte, char, and bool field values")
  pushAddr(ctx, addStaticBytes(ctx, bytes))

proc genBinary(ctx: var Ctx, op: string, left, right: Expr) =
  case op
  of "+":
    if left.kind == eStr and right.kind == eStr:
      pushAddr(ctx, pushStr(ctx, left.strVal & right.strVal))
    else:
      gen(ctx, left)
      gen(ctx, right)
      emit(ctx, 0x03)
  of "[]":
    gen(ctx, left)
    gen(ctx, right)
    emit(ctx, 0x38)
  of ".":
    if right.kind != eIdent:
      ctx.errors.add("field access expects an identifier")
      return
    let typName = typeOfExpr(ctx, left)
    let offset = fieldOffset(ctx, typName, right.identName)
    if offset < 0:
      ctx.errors.add(fmt"unknown field '{right.identName}' on {typName}")
      return
    gen(ctx, left)
    pushInt(ctx, offset)
    emit(ctx, 0x3A)
  of "==":
    gen(ctx, left); gen(ctx, right); emit(ctx, 0x1F); pushInt(ctx, 0); boolFromCmp(ctx, 0x09)
  of "!=":
    gen(ctx, left); gen(ctx, right); emit(ctx, 0x1F); pushInt(ctx, 0); boolFromCmp(ctx, 0x0C)
  of "<":
    gen(ctx, right); gen(ctx, left); boolFromCmp(ctx, 0x08)
  of ">":
    gen(ctx, left); gen(ctx, right); boolFromCmp(ctx, 0x08)
  of "<=":
    gen(ctx, left); gen(ctx, right); emit(ctx, 0x1F); pushInt(ctx, 1); boolFromCmp(ctx, 0x0C)
  of ">=":
    gen(ctx, left); gen(ctx, right); emit(ctx, 0x1F); pushInt(ctx, 255); boolFromCmp(ctx, 0x0C)
  else:
    gen(ctx, left)
    gen(ctx, right)
    case op
    of "-": emit(ctx, 0x04)
    of "*": emit(ctx, 0x05)
    of "/": emit(ctx, 0x06)
    of "%": emit(ctx, 0x13)
    of "&", "and": emit(ctx, 0x17)
    of "|", "or": emit(ctx, 0x18)
    of "^": emit(ctx, 0x19)
    of "<<": emit(ctx, 0x1B)
    of ">>": emit(ctx, 0x1C)
    else: ctx.errors.add(fmt"unsupported binary op '{op}'")

proc genUnary(ctx: var Ctx, op: string, operand: Expr) =
  gen(ctx, operand)
  case op
  of "-": emit(ctx, 0x16)
  of "!", "not", "~": emit(ctx, 0x1A)
  else: ctx.errors.add(fmt"unsupported unary op '{op}'")

proc genBuiltinCall(ctx: var Ctx, name: string, args: seq[Expr]): bool =
  result = true
  case name
  of "assert":
    if args.len != 1: ctx.errors.add("assert expects 1 argument"); return
    gen(ctx, args[0])
    let ok = ctx.here()
    emit2(ctx, 0x0F, 0)
    pushInt(ctx, 1)
    emit(ctx, 0x64)
    ctx.patch(ok + 1, ctx.here())
  of "assertEq":
    if args.len != 2: ctx.errors.add("assertEq expects 2 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x1F); pushInt(ctx, 0)
    let ok = ctx.here()
    emit2(ctx, 0x09, 0)
    pushInt(ctx, 1)
    emit(ctx, 0x64)
    ctx.patch(ok + 1, ctx.here())
  of "print":
    if args.len != 1: ctx.errors.add("print expects 1 argument"); return
    if args[0].kind == eStr:
      pushAddr(ctx, pushStr(ctx, args[0].strVal)); emit(ctx, 0x54)
    elif typeOfExpr(ctx, args[0]) == "str":
      gen(ctx, args[0]); emit(ctx, 0x54)
    else:
      gen(ctx, args[0]); emit(ctx, 0x57)
  of "println":
    if args.len == 1:
      if args[0].kind == eStr:
        pushAddr(ctx, pushStr(ctx, args[0].strVal)); emit(ctx, 0x54)
      elif typeOfExpr(ctx, args[0]) == "str":
        gen(ctx, args[0]); emit(ctx, 0x54)
      else:
        gen(ctx, args[0]); emit(ctx, 0x57)
    elif args.len != 0:
      ctx.errors.add("println expects 0 or 1 arguments")
    emit(ctx, 0x51)
  of "putc", "char":
    if args.len != 1: ctx.errors.add(name & " expects 1 argument"); return
    gen(ctx, args[0]); emit(ctx, 0x56)
  of "newline":
    if args.len != 0: ctx.errors.add("newline expects no arguments"); return
    emit(ctx, 0x51)
  of "space":
    if args.len != 0: ctx.errors.add("space expects no arguments"); return
    emit(ctx, 0x52)
  of "readByte":
    if args.len != 0: ctx.errors.add("readByte expects no arguments"); return
    emit(ctx, 0x53)
  of "len", "strlen":
    if args.len != 1: ctx.errors.add(name & " expects 1 argument"); return
    gen(ctx, args[0])
    if typeOfExpr(ctx, args[0]) == "array":
      emit(ctx, 0x39)
    else:
      emit(ctx, 0x55)
      emit(ctx, 0x23)
  of "ord":
    if args.len != 1: ctx.errors.add("ord expects 1 argument"); return
    gen(ctx, args[0])
  of "abs":
    if args.len != 1: ctx.errors.add("abs expects 1 argument"); return
    gen(ctx, args[0])
    emit(ctx, 0x10)
    pushInt(ctx, 127)
    boolFromCmp(ctx, 0x08)
    let done = ctx.here()
    emit2(ctx, 0x0B, 0)
    emit(ctx, 0x16)
    ctx.patch(done + 1, ctx.here())
  of "exit":
    if args.len != 1: ctx.errors.add("exit expects 1 argument"); return
    gen(ctx, args[0]); emit(ctx, 0x64)
  of "min":
    if args.len != 2: ctx.errors.add("min expects 2 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x1D)
  of "max":
    if args.len != 2: ctx.errors.add("max expects 2 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x1E)
  of "clamp":
    if args.len != 3: ctx.errors.add("clamp expects 3 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x1E); gen(ctx, args[2]); emit(ctx, 0x1D)
  of "between":
    if args.len != 3: ctx.errors.add("between expects 3 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); gen(ctx, args[2]); emit(ctx, 0x1D); emit(ctx, 0x1E)
  of "memoryRead", "peek":
    if args.len != 1: ctx.errors.add(name & " expects 1 argument"); return
    gen(ctx, args[0]); emit(ctx, 0x33)
  of "memoryWrite", "poke":
    if args.len != 2: ctx.errors.add(name & " expects 2 arguments"); return
    gen(ctx, args[1]); gen(ctx, args[0]); emit(ctx, 0x34)
  of "printBytes":
    if args.len != 2: ctx.errors.add("printBytes expects 2 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x35)
  of "strcmp":
    if args.len != 2: ctx.errors.add("strcmp expects 2 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x36)
  of "stackDepth":
    if args.len != 0: ctx.errors.add("stackDepth expects no arguments"); return
    emit(ctx, 0x28)
  of "returnDepth":
    if args.len != 0: ctx.errors.add("returnDepth expects no arguments"); return
    emit(ctx, 0x61)
  of "alloc":
    if args.len != 1: ctx.errors.add("alloc expects 1 argument"); return
    gen(ctx, args[0]); emit(ctx, 0x37)
  of "arrayLen":
    if args.len != 1: ctx.errors.add("arrayLen expects 1 argument"); return
    gen(ctx, args[0]); emit(ctx, 0x39)
  of "arrayGet":
    if args.len != 2: ctx.errors.add("arrayGet expects 2 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); emit(ctx, 0x38)
  of "arraySet":
    if args.len != 3: ctx.errors.add("arraySet expects 3 arguments"); return
    gen(ctx, args[0]); gen(ctx, args[1]); gen(ctx, args[2]); emit(ctx, 0x3B)
  else:
    result = false

proc genFnCall(ctx: var Ctx, node: Expr) =
  if node.eCallee.kind != eIdent:
    ctx.errors.add("dynamic function calls are not supported yet")
    return
  let name = node.eCallee.identName
  if genBuiltinCall(ctx, name, node.eArgs): return
  for arg in node.eArgs: gen(ctx, arg)
  let fnAddr = findFn(ctx, name)
  if fnAddr >= 0:
    emit2(ctx, 0x40, byte(fnAddr))
  else:
    emit(ctx, 0x40)
    ctx.callPatches.add((ctx.here(), name))
    emit(ctx, 0)

proc genFnDecl(ctx: var Ctx, node: Expr) =
  setFnAddr(ctx, node.eFnName, ctx.here())
  let baseVars = ctx.vars.len
  var paramSlots: seq[int] = @[]
  var paramWidths: seq[int] = @[]
  for param in node.eParams:
    let typName = typeNameOf(param.typ)
    let width = if typName in ["str", "array"] or findStruct(ctx, typName) >= 0: 2 else: 1
    paramSlots.add(allocVar(ctx, param.name, false, width, typName))
    paramWidths.add(width)
  for i in countdown(paramSlots.len - 1, 0): storeToSlot(ctx, paramSlots[i], paramWidths[i])
  gen(ctx, node.eBody)
  emit(ctx, 0x41)
  ctx.vars.setLen(baseVars)

proc gen(ctx: var Ctx, node: Expr) =
  if node.isNil: return
  case node.kind
  of eNoop: discard
  of eTypeDecl:
    var fields: seq[string] = @[]
    for field in node.eTypeFields: fields.add(field.name)
    if fields.len > 0 and findStruct(ctx, node.eTypeName) < 0:
      ctx.structs.add(StructDef(name: node.eTypeName, fields: fields))
    for i, variant in node.eTypeVariants:
      if findConst(ctx, variant) < 0:
        ctx.consts.add(ConstDef(name: variant, value: i, typName: node.eTypeName))
      let qualified = node.eTypeName & "::" & variant
      if findConst(ctx, qualified) < 0:
        ctx.consts.add(ConstDef(name: qualified, value: i, typName: node.eTypeName))
  of eArrayLit: genArrayLit(ctx, node)
  of eStructLit: genStructLit(ctx, node)
  of eInt: pushInt(ctx, node.intVal)
  of eStr: pushAddr(ctx, pushStr(ctx, node.strVal))
  of eChar: pushInt(ctx, int(node.charVal))
  of eBool: pushInt(ctx, if node.boolVal: 1 else: 0)
  of eNil: pushInt(ctx, 0)
  of eIdent:
    let varIndex = findVarIndex(ctx, node.identName)
    if varIndex >= 0: loadFromSlot(ctx, ctx.vars[varIndex].slot, ctx.vars[varIndex].width)
    else:
      let constIdx = findConst(ctx, node.identName)
      if constIdx >= 0: pushInt(ctx, ctx.consts[constIdx].value)
      else: ctx.errors.add(fmt"undefined variable '{node.identName}'")
  of eBinary: genBinary(ctx, node.eBinaryOp, node.eLeft, node.eRight)
  of eUnary: genUnary(ctx, node.eUnaryOp, node.eOperand)
  of eBlock:
    for stmt in node.eStmts: gen(ctx, stmt)
  of eIf: genIf(ctx, node)
  of eWhile: genWhile(ctx, node)
  of eFor: genFor(ctx, node)
  of eCase: genCase(ctx, node)
  of eVarDecl:
    var typName = typeNameOf(node.eVarType)
    if node.eVarType.isNil: typName = typeOfExpr(ctx, node.eVarInit)
    var width = if typName == "byte": widthOfExpr(ctx, node.eVarInit) else: (if typName in ["str", "array", "addr"] or findStruct(ctx, typName) >= 0: 2 else: 1)
    if width <= 0: width = 1
    let slot = allocVar(ctx, node.eVarName, node.eVarMut, width, typName)
    if node.eVarInit != nil:
      gen(ctx, node.eVarInit)
      if widthOfExpr(ctx, node.eVarInit) != width:
        ctx.errors.add(fmt"type width mismatch assigning to '{node.eVarName}'")
      storeToSlot(ctx, slot, width)
  of eAssign:
    if node.eAssignTarget.kind == eIdent:
      let varIndex = findVarIndex(ctx, node.eAssignTarget.identName)
      if varIndex >= 0:
        if not ctx.vars[varIndex].mutable:
          ctx.errors.add(fmt"cannot assign to immutable binding '{node.eAssignTarget.identName}'")
          return
        let slot = ctx.vars[varIndex].slot
        gen(ctx, node.eAssignVal)
        if widthOfExpr(ctx, node.eAssignVal) != ctx.vars[varIndex].width:
          ctx.errors.add(fmt"type mismatch assigning to '{node.eAssignTarget.identName}'")
        storeToSlot(ctx, slot, ctx.vars[varIndex].width)
      else: ctx.errors.add(fmt"undefined variable '{node.eAssignTarget.identName}'")
    else: ctx.errors.add("invalid assignment target")
  of eReturn:
    if node.eRetVal != nil: gen(ctx, node.eRetVal)
    emit(ctx, 0x41)
  of eBreak:
    if ctx.breakPatches.len == 0:
      ctx.errors.add("break used outside a loop")
    else:
      ctx.breakPatches[^1].add(ctx.here())
      emit2(ctx, 0x07, 0)
  of eContinue:
    if ctx.continueTargets.len == 0:
      ctx.errors.add("continue used outside a loop")
    elif ctx.continueTargets[^1] < 0:
      ctx.continuePatches[^1].add(ctx.here())
      emit2(ctx, 0x07, 0)
    else:
      emit2(ctx, 0x07, byte(ctx.continueTargets[^1]))
  of ePrint:
    gen(ctx, node.ePrintVal); emit(ctx, 0x57)
  of ePrintStr:
    pushAddr(ctx, pushStr(ctx, node.ePrintStrVal.strVal)); emit(ctx, 0x54)
  of ePipe:
    if node.ePipeRight.kind == eFnCall:
      gen(ctx, node.ePipeLeft)
      for arg in node.ePipeRight.eArgs: gen(ctx, arg)
      genFnCall(ctx, Expr(kind: eFnCall, eCallee: node.ePipeRight.eCallee, eArgs: @[]))
    else:
      ctx.errors.add("pipe target must be a function call")
  of eFnCall: genFnCall(ctx, node)
  of eFnDecl: genFnDecl(ctx, node)

proc generate*(astNodes: seq[Expr]): seq[byte] =
  var ctx = newCtx()
  for decl in astNodes:
    if decl.kind == eTypeDecl:
      var fields: seq[string] = @[]
      for field in decl.eTypeFields: fields.add(field.name)
      if fields.len > 0 and findStruct(ctx, decl.eTypeName) < 0:
        ctx.structs.add(StructDef(name: decl.eTypeName, fields: fields))
      for i, variant in decl.eTypeVariants:
        if findConst(ctx, variant) < 0:
          ctx.consts.add(ConstDef(name: variant, value: i, typName: decl.eTypeName))
        let qualified = decl.eTypeName & "::" & variant
        if findConst(ctx, qualified) < 0:
          ctx.consts.add(ConstDef(name: qualified, value: i, typName: decl.eTypeName))
  for decl in astNodes:
    if decl.kind == eFnDecl: ctx.fns.add(FnSym(name: decl.eFnName, arity: decl.eParams.len, addrVal: -1))

  for decl in astNodes:
    if decl.kind != eFnDecl:
      gen(ctx, decl)

  if hasFn(ctx, "main"):
    emit(ctx, 0x40)
    ctx.callPatches.add((ctx.here(), "main"))
    emit(ctx, 0)
  emit(ctx, 0x00)

  for decl in astNodes:
    if decl.kind == eFnDecl: genFnDecl(ctx, decl)

  for patchInfo in ctx.callPatches:
    let fnAddr = findFn(ctx, patchInfo.fnName)
    if fnAddr >= 0: ctx.patch(patchInfo.operandPos, fnAddr)
    else: ctx.errors.add(fmt"undefined function '{patchInfo.fnName}'")

  if ctx.code.len > 4094: ctx.errors.add("generated code exceeds VM program space")
  if ctx.errors.len > 0: raise newException(ValueError, ctx.errors.join("\n"))

  let codeSize = ctx.code.len
  result.add(byte(codeSize shr 8))
  result.add(byte(codeSize and 0xFF))
  result.add(ctx.code)
  result.add(ctx.staticData)
