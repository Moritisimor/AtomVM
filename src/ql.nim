import std/cmdline
import std/os
import std/osproc
import std/sets
import std/strformat
import std/strutils
import std/terminal
import ./ql/codegen
import ./ql/parser
import ./ql/tokens

const QlVersion = "0.4.0"

type ColorMode = enum cmAuto, cmAlways, cmNever

proc wantsColor(mode: ColorMode): bool =
  case mode
  of cmAlways: true
  of cmNever: false
  of cmAuto: getEnv("NO_COLOR") == "" and isatty(stderr)

proc paint(enabled: bool, code, text: string): string =
  if enabled: "\e[" & code & "m" & text & "\e[0m" else: text

proc status(enabled: bool, label, msg: string) =
  stderr.writeLine(paint(enabled, "1;32", label) & " " & msg)

proc note(enabled: bool, label, msg: string) =
  stderr.writeLine(paint(enabled, "1;36", label) & " " & msg)

proc printHelp() =
  echo "QuantumLang " & QlVersion
  echo "Usage:"
  echo "  ql build <input.ql> -o <output.bc>"
  echo "  ql check <input.ql>"
  echo "  ql run <input.ql>"
  echo "  ql <input.ql> <output.bc>"
  echo ""
  echo "Options:"
  echo "  -o, --output <file>  Output bytecode path"
  echo "  --run                Run bytecode after compiling"
  echo "  --vm <path>          VM executable for --run/run (default: ./atomvm)"
  echo "  --color <mode>       Color output: auto, always, never"
  echo "  --quiet              Suppress success messages"
  echo "  -h, --help           Show this help text"
  echo "  -V, --version        Print version information"

proc compile*(src: string): seq[byte] =
  generate(parse(tokenize(src)))

proc bytesToString(data: seq[byte]): string =
  result = newString(data.len)
  for i, b in data: result[i] = char(b)

proc resolveImport(baseDir, name: string): string =
  var path = name
  if not path.endsWith(".ql"): path &= ".ql"
  if path.isAbsolute: path else: baseDir / path

proc moduleName(path: string): string =
  splitFile(path).name

proc qualifyModuleSource(src, moduleName: string): string =
  for line in src.splitLines():
    let stripped = line.strip(leading = true, trailing = false)
    if stripped.startsWith("fn "):
      let leading = line[0 ..< line.len - stripped.len]
      result.add(leading & "fn " & moduleName & "::" & stripped[3 .. ^1] & "\n")
    elif stripped.startsWith("type "):
      let leading = line[0 ..< line.len - stripped.len]
      result.add(leading & "type " & moduleName & "::" & stripped[5 .. ^1] & "\n")
    else:
      result.add(line & "\n")

proc loadWithImports(path: string, seen: var HashSet[string]): string =
  let fullPath = normalizedPath(path)
  if fullPath in seen: return ""
  seen.incl(fullPath)
  let src = readFile(fullPath)
  let toks = tokenize(src)
  let baseDir = parentDir(fullPath)
  for i, tok in toks:
    if tok.kind == tkImport and i + 1 < toks.len and toks[i + 1].kind == tkStr:
      let importPath = resolveImport(baseDir, toks[i + 1].text)
      let imported = loadWithImports(importPath, seen)
      result.add(imported)
      result.add(qualifyModuleSource(imported, moduleName(importPath)))
      result.add('\n')
  result.add(src)
  result.add('\n')

proc main(): int =
  let args = commandLineParams()
  if args.len == 0:
    printHelp()
    return 1

  var inputPath = ""
  var outputPath = ""
  var runAfter = false
  var quiet = false
  var vmPath = "./atomvm"
  var colors = cmAuto
  var command = "build"
  var start = 0

  if args[0] in ["build", "check", "run"]:
    command = args[0]
    runAfter = command == "run"
    start = 1

  var i = start
  while i < args.len:
    case args[i]
    of "-h", "--help":
      printHelp()
      return 0
    of "-V", "--version":
      echo "QuantumLang " & QlVersion
      return 0
    of "--run":
      runAfter = true
    of "--quiet":
      quiet = true
    of "--color":
      if i + 1 >= args.len:
        stderr.writeLine("ql: error: expected mode after --color")
        return 1
      inc i
      case args[i]
      of "auto": colors = cmAuto
      of "always": colors = cmAlways
      of "never": colors = cmNever
      else:
        stderr.writeLine("ql: error: invalid color mode '" & args[i] & "'")
        return 1
    of "--vm":
      if i + 1 >= args.len:
        stderr.writeLine("ql: error: expected path after --vm")
        return 1
      inc i
      vmPath = args[i]
    of "-o", "--output":
      if i + 1 >= args.len:
        stderr.writeLine("ql: error: expected path after " & args[i])
        return 1
      inc i
      outputPath = args[i]
    else:
      if args[i].startsWith("-"):
        stderr.writeLine("ql: error: unknown option '" & args[i] & "'")
        stderr.writeLine("Try 'ql --help'.")
        return 1
      elif inputPath == "":
        inputPath = args[i]
      elif outputPath == "":
        outputPath = args[i]
      else:
        stderr.writeLine("ql: error: unexpected argument '" & args[i] & "'")
        return 1
    inc i

  if inputPath == "":
    printHelp()
    return 1

  if outputPath == "":
    outputPath = changeFileExt(inputPath, "bc")

  try:
    let color = wantsColor(colors)
    var seen = initHashSet[string]()
    let source = loadWithImports(inputPath, seen)
    let bytecode = compile(source)
    if command == "check":
      if not quiet:
        status(color, "OK", fmt"{inputPath} typechecked and generated {bytecode.len} bytes")
      return 0
    writeFile(outputPath, bytesToString(bytecode))
    if not quiet:
      status(color, "OK", fmt"wrote {outputPath} ({bytecode.len} bytes)")
      note(color, "BC", "run with: atomvm " & outputPath)
    if runAfter:
      if not quiet:
        note(color, "RUN", outputPath)
      let exitCode = execCmd(quoteShell(vmPath) & " " & quoteShell(outputPath))
      return exitCode
    return 0
  except CatchableError as e:
    stderr.writeLine(fmt"ql: error: {e.msg}")
    return 1

when isMainModule:
  quit(main())
