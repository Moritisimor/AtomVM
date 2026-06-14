# Atom VM

A stack-based 8-bit virtual machine for the **Quantum** programming language, written in C with an assembler (QASM) in Nim.

## Features

- **50+ opcodes** — arithmetic, bitwise, stack, memory, control flow, I/O
- **Dual stack** — data stack (2048 bytes) + return stack (256 entries) for subroutine support
- **4 KB program space** (4096 bytes)
- **4 KB data memory** (4096 bytes)
- **16-bit addressing** via JMP16, CALL16, PUSH16 extensions
- **Full error checking** — stack overflow/underflow, division by zero, bounds checks
- **Assembler (QASM)** — with label resolution, hex literals, error reporting

## Quick Start

```bash
make all          # build VM + assembler
make test         # run test suite (62 tests)
make lint         # check C code with -Werror

./atomasm hello_world.asm hello.bc   # assemble
./atomvm hello.bc                     # run
```

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
make all        # VM + assembler
make vm         # C VM only
make asm        # Nim assembler only
make test       # full test suite (62 tests)
make lint       # C lint with -Werror
make clean      # remove build artifacts
```

Requires a C99 compiler and [Nim](https://nim-lang.org/) 2.0+.

## License

MIT
