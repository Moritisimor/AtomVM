# AtomVM Opcodes

## HALT
Value: 0x0 / 0

### Description

Stops the program, exiting with code 0.

### Example
```asm
HALT
```

## PUSH
Value: 0x1 / 1

### Description

Pushes an immediate value onto the stack.

### Example
```asm
push 0x10
push 0xa
```

## POP
Value: 0x2 / 2

### Description

Pops an element from the stack, discarding the value.

### Example
```asm
push 0x10 
pop 
```

## ADD
Value: 0x3 / 3

### Description

Pops the first two elements from the stack, calculates their sum, and pushes it back onto the stack.

### Example
```asm
push 0x10
push 0x20
add ; 0x20 + 0x10 = 0x30
```

## SUB
Value: 0x4 / 4

### Description

Pops the first two elements from the stack, calculates the difference between the second and first elements, and pushes it back onto the stack.

### Example
```asm
push 0x10
push 0x20
sub ; 0x20 - 0x10 = 0x10
```

## MUL
Value: 0x5 / 5

### Description

Pops the first two elements from the stack, calculates their product, and pushes it back onto the stack.

### Example
```asm
push 0xa
push 0xa
mul ; 0xa * 0xa = 0x64
```

## DIV
Value: 0x6 / 6

### Description

Pops the first two elements from the stack, calculates the quotient of the second and first elements, and pushes it back onto the stack.

### Example
```asm
push 0x10
push 0x20
div ; 0x20 / 0x10 = 0x2
```

## JMP
Value: 0x7 / 7

### Description

Unconditionally jumps to an immediate value. 

The assembler will resolve labels for you though, meaning you won't need to count bytes yourself.

### Example
```asm
push 0x1
label loop
    push 0x1
    add
    jmp loop
```

## JIG
Value: 0x8 / 8

### Description

Jumps to an immediate value/label if the topmost element is bigger than the 2nd topmost element.

This opcode pops the first 2 elements.

### Example
```asm
label loop
    push 0x20
    push 0x30
    jig loop ; This will jump to loop
```

## JIE
Value: 0x9 / 9

### Description

Jumps to an immediate value/label if the 2 topmost elements are equal.

This opcode pops the first 2 elements.

### Example
```asm
label loop
    push 0x10
    push 0x10
    jie loop ; This will jump to loop
```

## JIS
Value: 0xa / 10

### Description

Jumps to an immediate value/label if the topmost element is smaller than the 2nd topmost element.

This opcode pops the first 2 elements.

### Example
```asm
label loop
    push 0x30
    push 0x20
    jis loop ; This will jump to loop
```

## JIZ
Value: 0xb / 11

### Description

Jumps to an immediate value/label if the topmost element is equal to zero (0x0).

This opcode pops the first element.

### Example
```asm
label loop
    push 0x0
    jiz loop ; This will jump to loop
```

## JNE
Value: 0xc / 12

### Description

Jumps to an immediate value/label if the 2 topmost elements are not equal to each other.

This opcode pops the first 2 elements.

### Example
```asm
label loop
    push 0xe
    push 0xf
    jne loop ; This will jump to loop
```

## PUTN
Value: 0xd / 13

### Description

Prints the first element on the stack as a number.

This opcode does not pop the first element, it only peeks.

### Example
```asm
push 0x1
push 0x2
add ; 0x2 + 0x1 = 0x3
putn ; prints 3
```

## PUTC
Value: 0xe / 14

### Description

Prints the first element on the stack as a character.

This opcode does not pop the first element, it only peeks.

### Example
```asm
push 0x41 ; A
putc ; prints A
```

## JNZ
Value: 0xf / 15

### Description

Jumps to an immediate value/label if the topmost element is NOT equal to zero (0x0).

This opcode pops the first element.

### Example
```asm
label loop
    push 0x1
    jnz loop ; This will jump to loop
```

## DUP
Value: 0x10 / 16

### Description

Duplicates the first element on the stack, pushing it back.

### Example
```asm
push 0x1
dup ; The stack now contains 0x1 twice
```

## Store
Value: 0x11 / 17

### Description

Pops the first element on the stack, storing it in memory at the address which is given as an immediate value.

### Example
```asm
push 0x1
store 0xa
```

## Load
Value: 0x12 / 18

### Description

Pushes the value stored at at the address in memory which is given as an immediate value.

### Example
```asm
push 0x1
store 0x0

load 0x0 ; 0x1 is on the stack again
```
