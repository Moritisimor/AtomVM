import std/cmdline
import std/strutils
import std/tables

proc gatherLabels(tokens: seq[string]): TableRef[string, int] =
  var labels = newTable[string, int]()
  var idx = 0

  for token in tokens:
    if token.toLower() == "label":
      labels[tokens[idx + 1]] = idx

    idx += 1

  return labels

proc tokensToByteCode(tokens: seq[string], labels: TableRef): seq[byte] =
  var idx = 0
  var ignorable: seq[int] = @[]
  var bytes: seq[byte] = @[]

  for token in tokens:
    if token.toLower().startsWith("label"):
      idx += 1
      continue

    if ignorable.contains(idx):
      idx += 1
      continue

    case token.toLower() 
      of "halt":
        bytes.add(0x0)

      of "push":
        bytes.add(0x1)
        let next = tokens[idx + 1]
        let val = parseInt(next)
        if val < 0 or val > 255:
          raise newException(Exception, "Value of immediate does not fit in a byte")
        else:
          bytes.add(cast[byte](val))

      of "putn":
        bytes.add(0xd)
          
      of "putc":
        bytes.add(0xe)

      of "pop":
        bytes.add(0x2)
            
      of "add":
        bytes.add(0x3)
                
      of "sub":
        bytes.add(0x4)

      of "mul":
        bytes.add(0x5)

      of "div":
        bytes.add(0x6)

      of "jmp":
        bytes.add(0x7)
        let next = tokens[idx + 1]
        bytes.add(cast[byte](labels[next]))

      of "jig":
        bytes.add(0x8)
        let next = tokens[idx + 1]
        bytes.add(cast[byte](labels[next]))

      of "jis":
        bytes.add(0xa)
        let next = tokens[idx + 1]
        bytes.add(cast[byte](labels[next]))

      of "jie":
        bytes.add(0x9)
        let next = tokens[idx + 1]
        bytes.add(cast[byte](labels[next]))

      of "jiz":
        bytes.add(0xb)
        let next = tokens[idx + 1]
        bytes.add(cast[byte](labels[next]))

      of "jne":
        bytes.add(0xc)
        let next = tokens[idx + 1]
        bytes.add(cast[byte](labels[next]))

      of "dup":
        bytes.add(0x10)

      of "store":
        bytes.add(0x11)
        let next = tokens[idx + 1]
        let val = parseInt(next)
        if val < 0 or val > 255:
          raise newException(Exception, "Value of immediate does not fit in a byte")
        else:
          bytes.add(cast[byte](val))

      of "load":
        bytes.add(0x12)
        let next = tokens[idx + 1]
        let val = parseInt(next)
        if val < 0 or val > 255:
          raise newException(Exception, "Value of immediate does not fit in a byte")
        else:
          bytes.add(cast[byte](val))

    idx += 1

  return bytes


proc main(args: seq[string]): int =
  let args = commandLineParams()
  if args.len < 2:
    echo "Usage: atomasm <input file> <output file>"
    return 1

  let input_path = args[0]
  let output_path = args[1]
  var content: string

  try:
    content = readFile(input_path)
  except IOError:
    echo "Could not open input file"
    return 1

  let tokens = strutils.splitWhitespace(content, -1)
  let labels = gatherLabels(tokens)

  try:
    let bytes = tokensToByteCode(tokens, labels)
    writeFile(output_path, bytes)
  except Exception as e:
    echo "Error while generating bytecode/writing to file: " .. e.msg
    return 1

  return 0

quit(main(commandLineParams()))
