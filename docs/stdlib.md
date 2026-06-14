# QuantumLang Core Library

QuantumLang currently ships a compiler-recognized core library. These names are available without imports and compile directly to VM opcodes.

## I/O

| Function | Arguments | Description |
|----------|-----------|-------------|
| `print(x)` | `int`, `char`, or `str` | Print a value without a newline. |
| `println()` | none | Print a newline. |
| `println(x)` | `int`, `char`, or `str` | Print a value followed by a newline. |
| `putc(x)` | byte | Print `x` as a character. |
| `char(x)` | byte | Alias for `putc`. |
| `newline()` | none | Print a newline. |
| `space()` | none | Print one space. |
| `readByte()` | none | Read one byte from standard input and leave it on the stack. |
| `printBytes(addr, len)` | address/string, byte | Print exactly `len` bytes from memory. |

## Math

| Function | Arguments | Description |
|----------|-----------|-------------|
| `min(a, b)` | byte, byte | Return the smaller value. |
| `max(a, b)` | byte, byte | Return the larger value. |
| `abs(x)` | byte | Return the absolute value using VM byte semantics. |
| `clamp(x, low, high)` | byte, byte, byte | Keep `x` between `low` and `high`. |
| `between(x, low, high)` | byte, byte, byte | Alias-like clamp helper, useful in expressions. |

## Strings

| Function | Arguments | Description |
|----------|-----------|-------------|
| `len(s)` | string/address | Return the length of a null-terminated string. |
| `strlen(s)` | string/address | Alias for `len`. |
| `strcmp(a, b)` | string/address, string/address | Return `0` when equal, `255` when `a < b`, `1` when `a > b`. |

String literal concatenation with `+` is compiled into one static string: `"hello, " + "world"`.

## Arrays

Arrays are byte arrays today. Literals like `[1, 2, 3]` are stored in VM memory as a length byte followed by element bytes.

| Function | Arguments | Description |
|----------|-----------|-------------|
| `arrayLen(a)` | array | Return the byte length of an array. |
| `arrayGet(a, i)` | array, byte | Return `a[i]`. Same operation as `a[i]`. |
| `arraySet(a, i, value)` | array, byte, byte | Write `value` into `a[i]`. |

Example:

```ql
let xs = [1, 2, 3]
arraySet(xs, 1, 9)
println(xs[1])  // 9
```

## Memory

| Function | Arguments | Description |
|----------|-----------|-------------|
| `memoryRead(addr)` | address | Read one byte from VM memory. |
| `peek(addr)` | address | Alias for `memoryRead`. |
| `memoryWrite(addr, value)` | address, byte | Store one byte in VM memory. |
| `poke(addr, value)` | address, byte | Alias for `memoryWrite`. |
| `alloc(size)` | byte | Allocate zeroed bytes from the VM heap and return an address. |

## System

| Function | Arguments | Description |
|----------|-----------|-------------|
| `assert(cond)` | byte/bool | Exit with code `1` if `cond` is zero. |
| `assertEq(a, b)` | byte, byte | Exit with code `1` if `a != b`. |
| `exit(code)` | byte | Stop the VM with `code`. |
| `stackDepth()` | none | Return data stack depth. |
| `returnDepth()` | none | Return return stack depth. |

## Current Limits

The VM is byte-oriented. Integer values are currently unsigned bytes except where `PUSH16` is used for addresses, strings, arrays, heap pointers, and records. Strings are immutable literals stored in VM data memory. Arrays and records are byte-backed memory objects. User functions, imports, local variables, conditionals, loops, `break`, `continue`, compound assignment, arithmetic, comparisons, memory access, arrays, records, heap allocation, and string output are usable today; algebraic data types, generics, package namespaces, and channels are still design-level features.
