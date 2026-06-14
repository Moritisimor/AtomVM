import std/cmdline
import std/os
import std/strutils
import std/strformat
import std/tables
import std/terminal

const AsmVersion = "0.4.0"

type ColorMode = enum cmAuto, cmAlways, cmNever

proc wantsColor(mode: ColorMode): bool =
  case mode
  of cmAlways: true
  of cmNever: false
  of cmAuto: getEnv("NO_COLOR") == "" and isatty(stderr)

proc paint(enabled: bool, code, text: string): string =
  if enabled: "\e[" & code & "m" & text & "\e[0m" else: text

type
  AssemblerError = object of CatchableError

proc tokenize(lines: seq[string]): seq[string] =
  var tokens: seq[string] = @[]
  for line in lines:
    let strippedLine = line.strip()
    if strippedLine == "" or strippedLine.startsWith(";"):
      continue
    let subTokens = strutils.splitWhitespace(strippedLine, -1)
    for subToken in subTokens:
      if subToken.startsWith(";"):
        break
      tokens.add(subToken)
  return tokens

proc parseIntSafe(s: string): int =
  try:
    if s.len > 2 and s[0] == '0' and (s[1] == 'x' or s[1] == 'X'):
      result = parseHexInt(s)
    else:
      result = parseInt(s)
  except ValueError:
    raise newException(AssemblerError, fmt"Invalid integer literal: '{s}'")

proc parseByte(s: string): byte =
  let v = parseIntSafe(s)
  if v < 0 or v > 255:
    raise newException(AssemblerError, fmt"Value '{s}' does not fit in a byte (0-255)")
  result = cast[byte](v)

proc parseWord(s: string): uint16 =
  let v = parseIntSafe(s)
  if v < 0 or v > 65535:
    raise newException(AssemblerError, fmt"Value '{s}' does not fit in a word (0-65535)")
  result = cast[uint16](v)

type InstrInfo = object
  opcode: byte
  argBytes: int
  tokensConsumed: int

proc instrInfo(mnemonic: string): InstrInfo =
  case mnemonic.toLower()
    of "halt":      return InstrInfo(opcode: 0x00, argBytes: 0, tokensConsumed: 1)
    of "pop":       return InstrInfo(opcode: 0x02, argBytes: 0, tokensConsumed: 1)
    of "add":       return InstrInfo(opcode: 0x03, argBytes: 0, tokensConsumed: 1)
    of "sub":       return InstrInfo(opcode: 0x04, argBytes: 0, tokensConsumed: 1)
    of "mul":       return InstrInfo(opcode: 0x05, argBytes: 0, tokensConsumed: 1)
    of "div":       return InstrInfo(opcode: 0x06, argBytes: 0, tokensConsumed: 1)
    of "putn":      return InstrInfo(opcode: 0x0D, argBytes: 0, tokensConsumed: 1)
    of "putc":      return InstrInfo(opcode: 0x0E, argBytes: 0, tokensConsumed: 1)
    of "dup":       return InstrInfo(opcode: 0x10, argBytes: 0, tokensConsumed: 1)
    of "inc":       return InstrInfo(opcode: 0x14, argBytes: 0, tokensConsumed: 1)
    of "dec":       return InstrInfo(opcode: 0x15, argBytes: 0, tokensConsumed: 1)
    of "neg":       return InstrInfo(opcode: 0x16, argBytes: 0, tokensConsumed: 1)
    of "and":       return InstrInfo(opcode: 0x17, argBytes: 0, tokensConsumed: 1)
    of "or":        return InstrInfo(opcode: 0x18, argBytes: 0, tokensConsumed: 1)
    of "xor":       return InstrInfo(opcode: 0x19, argBytes: 0, tokensConsumed: 1)
    of "not":       return InstrInfo(opcode: 0x1A, argBytes: 0, tokensConsumed: 1)
    of "shl":       return InstrInfo(opcode: 0x1B, argBytes: 0, tokensConsumed: 1)
    of "shr":       return InstrInfo(opcode: 0x1C, argBytes: 0, tokensConsumed: 1)
    of "min":       return InstrInfo(opcode: 0x1D, argBytes: 0, tokensConsumed: 1)
    of "max":       return InstrInfo(opcode: 0x1E, argBytes: 0, tokensConsumed: 1)
    of "cmp":       return InstrInfo(opcode: 0x1F, argBytes: 0, tokensConsumed: 1)
    of "swap":      return InstrInfo(opcode: 0x20, argBytes: 0, tokensConsumed: 1)
    of "over":      return InstrInfo(opcode: 0x21, argBytes: 0, tokensConsumed: 1)
    of "rot":       return InstrInfo(opcode: 0x22, argBytes: 0, tokensConsumed: 1)
    of "nip":       return InstrInfo(opcode: 0x23, argBytes: 0, tokensConsumed: 1)
    of "tuck":      return InstrInfo(opcode: 0x24, argBytes: 0, tokensConsumed: 1)
    of "dup2":      return InstrInfo(opcode: 0x25, argBytes: 0, tokensConsumed: 1)
    of "drop2":     return InstrInfo(opcode: 0x26, argBytes: 0, tokensConsumed: 1)
    of "swap2":     return InstrInfo(opcode: 0x27, argBytes: 0, tokensConsumed: 1)
    of "depth":     return InstrInfo(opcode: 0x28, argBytes: 0, tokensConsumed: 1)
    of "fetch":     return InstrInfo(opcode: 0x30, argBytes: 0, tokensConsumed: 1)
    of "storei":    return InstrInfo(opcode: 0x31, argBytes: 0, tokensConsumed: 1)
    of "fetch16":   return InstrInfo(opcode: 0x33, argBytes: 0, tokensConsumed: 1)
    of "storei16":  return InstrInfo(opcode: 0x34, argBytes: 0, tokensConsumed: 1)
    of "putsn":     return InstrInfo(opcode: 0x35, argBytes: 0, tokensConsumed: 1)
    of "strcmp":    return InstrInfo(opcode: 0x36, argBytes: 0, tokensConsumed: 1)
    of "alloc":     return InstrInfo(opcode: 0x37, argBytes: 0, tokensConsumed: 1)
    of "aget":      return InstrInfo(opcode: 0x38, argBytes: 0, tokensConsumed: 1)
    of "alen":      return InstrInfo(opcode: 0x39, argBytes: 0, tokensConsumed: 1)
    of "loadrel":   return InstrInfo(opcode: 0x3A, argBytes: 0, tokensConsumed: 1)
    of "aset":      return InstrInfo(opcode: 0x3B, argBytes: 0, tokensConsumed: 1)
    of "ret":       return InstrInfo(opcode: 0x41, argBytes: 0, tokensConsumed: 1)
    of "execute":   return InstrInfo(opcode: 0x42, argBytes: 0, tokensConsumed: 1)
    of "emit":      return InstrInfo(opcode: 0x50, argBytes: 0, tokensConsumed: 1)
    of "cr":        return InstrInfo(opcode: 0x51, argBytes: 0, tokensConsumed: 1)
    of "space":     return InstrInfo(opcode: 0x52, argBytes: 0, tokensConsumed: 1)
    of "key":       return InstrInfo(opcode: 0x53, argBytes: 0, tokensConsumed: 1)
    of "puts":      return InstrInfo(opcode: 0x54, argBytes: 0, tokensConsumed: 1)
    of "strlen":    return InstrInfo(opcode: 0x55, argBytes: 0, tokensConsumed: 1)
    of "putc_pop":  return InstrInfo(opcode: 0x56, argBytes: 0, tokensConsumed: 1)
    of "putn_pop":  return InstrInfo(opcode: 0x57, argBytes: 0, tokensConsumed: 1)
    of "ddepth":    return InstrInfo(opcode: 0x60, argBytes: 0, tokensConsumed: 1)
    of "rdepth":    return InstrInfo(opcode: 0x61, argBytes: 0, tokensConsumed: 1)
    of "msize":     return InstrInfo(opcode: 0x62, argBytes: 0, tokensConsumed: 1)
    of "state":     return InstrInfo(opcode: 0x63, argBytes: 0, tokensConsumed: 1)
    of "bye":       return InstrInfo(opcode: 0x64, argBytes: 0, tokensConsumed: 1)
    of "push":      return InstrInfo(opcode: 0x01, argBytes: 1, tokensConsumed: 2)
    of "jmp":       return InstrInfo(opcode: 0x07, argBytes: 1, tokensConsumed: 2)
    of "jig":       return InstrInfo(opcode: 0x08, argBytes: 1, tokensConsumed: 2)
    of "jie":       return InstrInfo(opcode: 0x09, argBytes: 1, tokensConsumed: 2)
    of "jis":       return InstrInfo(opcode: 0x0A, argBytes: 1, tokensConsumed: 2)
    of "jiz":       return InstrInfo(opcode: 0x0B, argBytes: 1, tokensConsumed: 2)
    of "jne":       return InstrInfo(opcode: 0x0C, argBytes: 1, tokensConsumed: 2)
    of "jnz":       return InstrInfo(opcode: 0x0F, argBytes: 1, tokensConsumed: 2)
    of "store":     return InstrInfo(opcode: 0x11, argBytes: 1, tokensConsumed: 2)
    of "load":      return InstrInfo(opcode: 0x12, argBytes: 1, tokensConsumed: 2)
    of "call":      return InstrInfo(opcode: 0x40, argBytes: 1, tokensConsumed: 2)
    of "jgt":       return InstrInfo(opcode: 0x43, argBytes: 1, tokensConsumed: 2)
    of "jlt":       return InstrInfo(opcode: 0x44, argBytes: 1, tokensConsumed: 2)
    of "jeq":       return InstrInfo(opcode: 0x45, argBytes: 1, tokensConsumed: 2)
    of "loop":      return InstrInfo(opcode: 0x46, argBytes: 1, tokensConsumed: 2)
    of "push16":    return InstrInfo(opcode: 0x70, argBytes: 2, tokensConsumed: 2)
    of "jmp16":     return InstrInfo(opcode: 0x71, argBytes: 2, tokensConsumed: 2)
    of "call16":    return InstrInfo(opcode: 0x72, argBytes: 2, tokensConsumed: 2)
    of "fill":      return InstrInfo(opcode: 0x32, argBytes: 0, tokensConsumed: 3)
    else:
      raise newException(AssemblerError, fmt"Unknown mnemonic: '{mnemonic}'")

proc printHelp() =
  echo "AtomASM " & AsmVersion
  echo "Usage:"
  echo "  atomasm [options] <input.asm> -o <output.bc>"
  echo "  atomasm <input.asm> <output.bc>"
  echo ""
  echo "Options:"
  echo "  -o, --output <file>  Output bytecode path"
  echo "  --color <mode>       Color output: auto, always, never"
  echo "  -h, --help           Show this help text"
  echo "  -V, --version        Print version information"
  echo "  --quiet              Do not print success output"


proc computeByteOffsets(tokens: seq[string]): seq[int] =
  result = newSeq[int](tokens.len)
  var offset = 0
  var i = 0
  while i < tokens.len:
    case tokens[i].toLower()
      of "label":
        result[i] = offset
        if i + 1 < tokens.len:
          result[i + 1] = offset
        i += 2
      of "fill":
        result[i] = offset
        if i + 1 < tokens.len: result[i + 1] = offset
        if i + 2 < tokens.len: result[i + 2] = offset
        offset += 4
        i += 3
      else:
        let info = instrInfo(tokens[i])
        result[i] = offset
        for j in 1 ..< info.tokensConsumed:
          if i + j < tokens.len:
            result[i + j] = offset
        offset += 1 + info.argBytes
        i += info.tokensConsumed


proc gatherLabels(tokens: seq[string], byteOffsets: seq[int]): TableRef[string, int] =
  var labels = newTable[string, int]()
  var idx = 0
  for token in tokens:
    if token.toLower() == "label":
      if idx + 1 >= tokens.len:
        raise newException(AssemblerError, "LABEL keyword without a name at token position " & $idx)
      let labelName = tokens[idx + 1]
      if labels.hasKey(labelName):
        raise newException(AssemblerError, fmt"Duplicate label '{labelName}'")
      if idx + 1 < byteOffsets.len:
        labels[labelName] = byteOffsets[idx + 1]
      else:
        labels[labelName] = byteOffsets[idx]
    idx += 1
  return labels


proc expectOperand(tokens: seq[string], idx: int, mnemonic: string, n: int = 1): string =
  if idx + n >= tokens.len:
    raise newException(AssemblerError, fmt"Expected operand after '{mnemonic}'")
  return tokens[idx + n]

proc expectLabel(labels: TableRef, name: string, mnemonic: string): int =
  if not labels.hasKey(name):
    raise newException(AssemblerError, fmt"Undefined label '{name}' referenced by '{mnemonic}'")
  return labels[name]


proc tokensToByteCode(tokens: seq[string], labels: TableRef): seq[byte] =
  var idx = 0
  var ignorable: seq[int] = @[]
  var bytes: seq[byte] = @[]

  while idx < tokens.len:
    if ignorable.contains(idx):
      idx += 1
      continue

    let token = tokens[idx]

    if token.toLower() == "label":
      if idx + 1 >= tokens.len:
        raise newException(AssemblerError, "LABEL keyword without a name")
      let labelName = tokens[idx + 1]
      if not labelName[0].isAlphaAscii():
        raise newException(AssemblerError, fmt"Invalid label name '{labelName}'")
      ignorable.add(idx + 1)
      idx += 1
      continue

    let info = instrInfo(token)

    case token.toLower()
      of "fill":
        bytes.add(info.opcode)
        ignorable.add(idx + 1)
        ignorable.add(idx + 2)
        let countTok = expectOperand(tokens, idx, "fill", 1)
        let addrTok  = expectOperand(tokens, idx, "fill", 2)
        let count = parseByte(countTok)
        let addrVal  = parseWord(addrTok)
        bytes.add(count)
        bytes.add(cast[byte]((addrVal shr 8) and 0xFF))
        bytes.add(cast[byte](addrVal and 0xFF))
        idx += 3
        continue

      else:
        discard

    bytes.add(info.opcode)

    case token.toLower()
      of "push", "store", "load":
        let next = expectOperand(tokens, idx, token)
        ignorable.add(idx + 1)
        bytes.add(parseByte(next))

      of "jmp", "jig", "jie", "jis", "jiz", "jne", "jnz",
         "call", "jgt", "jlt", "jeq", "loop":
        let next = expectOperand(tokens, idx, token)
        ignorable.add(idx + 1)
        bytes.add(cast[byte](expectLabel(labels, next, token)))

      of "push16", "jmp16", "call16":
        let next = expectOperand(tokens, idx, token)
        ignorable.add(idx + 1)
        let val = parseWord(next)
        bytes.add(cast[byte]((val shr 8) and 0xFF))
        bytes.add(cast[byte](val and 0xFF))

      else:
        discard

    idx += info.tokensConsumed

  return bytes

proc main(): int =
  let args = commandLineParams()
  var input_path = ""
  var output_path = ""
  var quiet = false
  var colors = cmAuto
  var i = 0
  while i < args.len:
    case args[i]
    of "-h", "--help":
      printHelp()
      return 0
    of "-V", "--version":
      echo "AtomASM " & AsmVersion
      return 0
    of "--quiet":
      quiet = true
    of "--color":
      if i + 1 >= args.len:
        stderr.writeLine("atomasm: error: expected mode after --color")
        return 1
      inc i
      case args[i]
      of "auto": colors = cmAuto
      of "always": colors = cmAlways
      of "never": colors = cmNever
      else:
        stderr.writeLine("atomasm: error: invalid color mode '" & args[i] & "'")
        return 1
    of "-o", "--output":
      if i + 1 >= args.len:
        stderr.writeLine("atomasm: error: expected path after " & args[i])
        return 1
      inc i
      output_path = args[i]
    else:
      if args[i].startsWith("-"):
        stderr.writeLine("atomasm: error: unknown option '" & args[i] & "'")
        stderr.writeLine("Try 'atomasm --help'.")
        return 1
      elif input_path == "":
        input_path = args[i]
      elif output_path == "":
        output_path = args[i]
      else:
        stderr.writeLine("atomasm: error: unexpected argument '" & args[i] & "'")
        return 1
    inc i

  if input_path == "" or output_path == "":
    printHelp()
    return 1

  var content: string

  try:
    content = readFile(input_path)
  except IOError:
    stderr.writeLine(fmt"atomasm: error: could not open input file '{input_path}'")
    return 1

  let tokens = atomasm.tokenize(strutils.splitLines(content))

  var byteOffsets: seq[int]
  try:
    byteOffsets = computeByteOffsets(tokens)
  except AssemblerError as e:
    stderr.writeLine(fmt"atomasm: error: {e.msg}")
    return 1

  var labels: TableRef[string, int]
  try:
    labels = gatherLabels(tokens, byteOffsets)
  except AssemblerError as e:
    stderr.writeLine(fmt"atomasm: error: {e.msg}")
    return 1

  try:
    let bytes = tokensToByteCode(tokens, labels)
    let size = bytes.len
    var outBytes = @[byte((size shr 8) and 0xFF), byte(size and 0xFF)]
    outBytes.add(bytes)
    writeFile(output_path, outBytes)
    if not quiet:
      let color = wantsColor(colors)
      stderr.writeLine(paint(color, "1;32", "OK") & fmt" wrote {output_path} ({size} code bytes)")
  except AssemblerError as e:
    stderr.writeLine(fmt"atomasm: error: {e.msg}")
    return 1
  except IOError as e:
    stderr.writeLine(fmt"atomasm: error: could not write to output file '{output_path}': {e.msg}")
    return 1

  return 0

quit(main())
