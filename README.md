# Atom VM

A stack-based 8-bit virtual machine for the **Quantum** programming language, written in C with an assembler (QASM) and QuantumLang compiler in Nim.

## Features

- **50+ opcodes** — arithmetic, bitwise, stack, memory, control flow, I/O
- **Dual stack** — data stack (2048 bytes) + return stack (256 entries) for subroutine support
- **4 KB program space** (4096 bytes)
- **4 KB data memory** (4096 bytes)
- **16-bit addressing** via JMP16, CALL16, PUSH16 extensions
- **Full error checking** — stack overflow/underflow, division by zero, bounds checks
- **Assembler (QASM)** — with label resolution, hex literals, error reporting
- **[QuantumLang](docs/language.md)** — high-level language that compiles to VM bytecode
- **Core library** — I/O, math, string, memory, and system builtins documented in `docs/stdlib.md`

## Quick Start

```bash
make all          # build VM + assembler + QuantumLang compiler
make test         # run test suite (88 tests)
make lint         # check C code with -Werror

./atomasm hello_world.asm hello.bc   # assemble
./atomvm hello.bc                     # run

./ql build examples/hello.ql -o hello.bc  # compile QuantumLang
./atomvm hello.bc                     # run QuantumLang bytecode
./ql run examples/hello.ql            # compile and run in one command
```

## Command Line Tools

```bash
atomvm --help
atomvm --info program.bc
atomvm --stats program.bc
atomvm program.bc

atomasm program.asm -o program.bc

ql build program.ql -o program.bc
ql check program.ql
ql run program.ql
ql program.ql program.bc              # old positional form still works
```

QuantumLang follows the same broad workflow as Java: source code compiles to portable VM bytecode (`.bc`), then `atomvm` executes that bytecode.

## Example

```asm
; Count from 2 to 255
push 1
label loop
    push 1
    add
    putn
    push 10
    putc
    pop
    jmp loop
```

## Opcode Reference

### Core (backward compatible)

| Hex | Mnemonic | Operand | Stack Effect | Description |
|-----|----------|---------|-------------|-------------|
| 00 | `halt` | — | — | Stop execution |
| 01 | `push` | byte | → val | Push immediate byte |
| 02 | `pop` | — | val → | Pop and discard |
| 03 | `add` | — | a b → sum | b + a |
| 04 | `sub` | — | a b → diff | b − a |
| 05 | `mul` | — | a b → prod | b × a |
| 06 | `div` | — | a b → quot | b ÷ a |
| 07 | `jmp` | addr | — | Unconditional jump |
| 08 | `jig` | addr | a b → | Jump if b > a |
| 09 | `jie` | addr | a b → | Jump if a == b |
| 0A | `jis` | addr | a b → | Jump if b < a |
| 0B | `jiz` | addr | a → | Jump if a == 0 |
| 0C | `jne` | addr | a b → | Jump if a != b |
| 0D | `putn` | — | val → val | Print as number (peek) |
| 0E | `putc` | — | val → val | Print as char (peek) |
| 0F | `jnz` | addr | a → | Jump if a != 0 |
| 10 | `dup` | — | a → a a | Duplicate top |
| 11 | `store` | addr | val → | Pop to memory[addr] |
| 12 | `load` | addr | → val | Push memory[addr] |

### Arithmetic Extensions

| Hex | Mnemonic | Stack Effect | Description |
|-----|----------|-------------|-------------|
| 13 | `mod` | a b → rem | b % a |
| 14 | `inc` | a → a+1 | Increment |
| 15 | `dec` | a → a−1 | Decrement |
| 16 | `neg` | a → −a | Two's complement negate |
| 17 | `and` | a b → a&b | Bitwise AND |
| 18 | `or` | a b → a\|b | Bitwise OR |
| 19 | `xor` | a b → a^b | Bitwise XOR |
| 1A | `not` | a → ~a | Bitwise NOT |
| 1B | `shl` | a b → b<<a | Shift left by a |
| 1C | `shr` | a b → b>>a | Shift right by a |
| 1D | `min` | a b → min | Minimum |
| 1E | `max` | a b → max | Maximum |
| 1F | `cmp` | a b → −1\|0\|1 | Compare; −1 if b<a, 0 if ==, 1 if b>a |

### Stack Manipulation

| Hex | Mnemonic | Stack Effect | Description |
|-----|----------|-------------|-------------|
| 20 | `swap` | a b → b a | Swap top two |
| 21 | `over` | a b → a b a | Copy second to top |
| 22 | `rot` | a b c → b c a | Rotate top three |
| 23 | `nip` | a b → b | Drop second |
| 24 | `tuck` | a b → b a b | Copy top under second |
| 25 | `dup2` | a b → a b a b | Duplicate top pair |
| 26 | `drop2` | a b → | Drop top pair |
| 27 | `swap2` | a b c d → c d a b | Swap top two pairs |
| 28 | `depth` | → depth | Push stack depth |

### Memory Operations

| Hex | Mnemonic | Operand | Stack Effect | Description |
|-----|----------|---------|-------------|-------------|
| 30 | `fetch` | — | addr → val | Push memory[addr] |
| 31 | `storei` | — | val addr → | Pop value to memory[addr] |
| 32 | `fill` | count addr16 | val → | Fill count bytes with val at addr |
| 33 | `fetch16` | — | addr_hi addr_lo → val | Push memory[addr] |
| 34 | `storei16` | — | val addr_hi addr_lo → | Store byte to memory[addr] |
| 35 | `putsn` | — | addr_hi addr_lo len → | Print len bytes from memory |
| 36 | `strcmp` | — | a_hi a_lo b_hi b_lo → cmp | Compare null-terminated strings |
| 37 | `alloc` | — | size → addr_hi addr_lo | Allocate zeroed heap bytes |
| 38 | `aget` | — | addr_hi addr_lo index → val | Read array element |
| 39 | `alen` | — | addr_hi addr_lo → len | Read array length |
| 3A | `loadrel` | — | addr_hi addr_lo offset → val | Read byte at addr + offset |
| 3B | `aset` | — | addr_hi addr_lo index val → | Write array element |

### Control Flow

| Hex | Mnemonic | Operand | Description |
|-----|----------|---------|-------------|
| 40 | `call` | addr | Call subroutine (pushes return address) |
| 41 | `ret` | — | Return from subroutine |
| 42 | `execute` | — | Pop address from stack and jump |
| 43 | `jgt` | addr | Jump if top > 0 (signed) |
| 44 | `jlt` | addr | Jump if top < 0 (signed) |
| 45 | `jeq` | addr | Jump if top == 0 |
| 46 | `loop` | addr | Decrement loop counter on return stack, jump if not zero |

### I/O

| Hex | Mnemonic | Stack Effect | Description |
|-----|----------|-------------|-------------|
| 50 | `emit` | val → val | Print as char (alias for putc) |
| 51 | `cr` | — | Print newline |
| 52 | `space` | — | Print space |
| 53 | `key` | → char | Read one byte from stdin |
| 54 | `puts` | addr_hi addr_lo → | Print null-terminated string from memory |
| 55 | `strlen` | addr_hi addr_lo → len_hi len_lo | Push null-terminated string length |
| 56 | `putc_pop` | val → | Pop and print as char |
| 57 | `putn_pop` | val → | Pop and print as number |

### System

| Hex | Mnemonic | Stack Effect | Description |
|-----|----------|-------------|-------------|
| 60 | `ddepth` | → depth | Data stack depth (alias for depth) |
| 61 | `rdepth` | → depth | Return stack depth |
| 62 | `msize` | → size | Memory size (low byte) |
| 63 | `state` | → flags | Push VM state flags |
| 64 | `bye` | code → | Exit with code from stack |

### 16-bit Extensions

| Hex | Mnemonic | Operand | Stack Effect | Description |
|-----|----------|---------|-------------|-------------|
| 70 | `push16` | word(2) | → hi lo | Push 16-bit value (big-endian) |
| 71 | `jmp16` | addr(2) | — | Jump to 16-bit address |
| 72 | `call16` | addr(2) | — | Call 16-bit subroutine address |

## Architecture

| Component | Size | Notes |
|-----------|------|-------|
| Data stack | 2048 bytes | 8-bit values, 16-bit stack pointer |
| Return stack | 256 × 16-bit | Stores return addresses for CALL/RET |
| Program space | 4096 bytes | 16-bit program counter |
| Data memory | 4096 bytes | Byte-addressable |

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | OK | Success |
| 1 | STACK_OVERFLOW | Data stack full |
| 2 | STACK_UNDERFLOW | Data stack empty |
| 3 | FILE_TOO_LARGE | Program exceeds 4096 bytes |
| 4 | FILE_EMPTY | Program file is empty |
| 5 | NO_INPUT_FILE | No filename given |
| 6 | FILE_NOT_FOUND | Cannot open file |
| 7 | UNKNOWN_OPCODE | Invalid instruction |
| 8 | PC_OUT_OF_BOUNDS | Program counter past end |
| 9 | JUMP_OUT_OF_BOUNDS | Jump target out of range |
| 10 | DIVISION_BY_ZERO | Division by zero |
| 11 | FILE_READ_ERROR | I/O error reading file |
| 12 | RETURN_STACK_OVERFLOW | Return stack full |
| 13 | RETURN_STACK_UNDERFLOW | Return stack empty |

## Building

```bash
make all        # VM + assembler + QuantumLang compiler
make vm         # C VM only
make asm        # Nim assembler only
make qlc        # QuantumLang compiler only
make test       # full test suite (88 tests)
make lint       # C lint with -Werror
make clean      # remove build artifacts
```

Requires a C99 compiler and [Nim](https://nim-lang.org/) 2.0+.

## QuantumLang Status

The compiler is organized as lexer/token, AST, parser, codegen, and CLI modules under `src/ql/`. The currently supported language is intentionally smaller than the design document: functions, import source loading with `module::symbol` aliases, `let`/`mut`/`const`, immutable binding checks, byte arrays, simple records, enum-style ADTs, heap allocation, arithmetic, comparisons, `if`, `while`, counted `for`, `break`, `continue`, compound assignment, simple `case`, byte/char/string literals, literal string concatenation, assertions, memory access, string helpers, and the core library in [`docs/stdlib.md`](docs/stdlib.md) are ready to use.

## License

MIT
