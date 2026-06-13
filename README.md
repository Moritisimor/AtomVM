# AtomVM
A really tiny 8-bit based Virtual Machine written in C

## What is this project about?
AtomVM is a simple, small but very fast Virtual Machine. 

It is 8-bit based, meaning that it is very limited, but also that it is architecturally very simple and small.

AtomVM is also stack-based, meaning it uses push and pop for operating on the stack.

It is not entirely finished yet, but in a usable state.

## What does the project consist of?
As of right now, the project consists of the Virtual Machine itself, which is written in C, and a small assembler, which is written in Nim.

## What does the assembly look like?
Here's a small example of a program, which is written in AtomASM, and can thus be assembled for the AtomVM:
```asm
; This program simply counts from 0 to 255 in an infinite loop, overflowing when it goes beyond 255.
push 1
label loop
    push 1
    add
    putn
    push 10 ; Newline
    putc
    pop

    jmp loop
```

Comments are written with `;`, so anything that comes after `;` is ignored by the tokenizer.

Labels are simply declared using the `label` keyword, followed by the identifier.

## What does the bytecode look like?
[Hexflex's](https://github.com/Moritisimor/hexflex) output for this program looks like this:
```
0x00000000: 0x01 0x01 0x01 0x01 0x03 0x0d 0x01 0x0a |........|
0x00000008: 0x0e 0x02 0x07 0x02 |....|
```

What a beautiful translation of assembly to bytecode!

### Explanation
The first 2 bytes, `0x01` and `0x01` push the value 1 to the stack.

The second 2 bytes do the same thing.

The 5th byte, `0x03`, adds the top 2 values of the stack.

The 6th byte, `0x0d`, prints the top value of the stack to the console as a number. It only peeks, meaning the element is not popped, and remains on the stack.

The 7th and 8th byte, once again, push something to the stack. This time it's the value `0x0a`. This is the ASCII code for newline.

The 9th byte, `0x0e`, prints the top value of the stack as a character, not as a number. Here, we effectively print a newline.

The 10th byte, `0x02`, pops the top value of the stack, effectively discarding it. We no longer need the newline here.

The 11th and 12 byte compose an unconditional jump. Here, we jump to the 3rd byte, which lies at address `0x02`.

## Compilation
Since this project consists of more than one programming language, you will need a C compiler of your choice for the VM itself, and the [nim](https://nim-lang.org/)
 compiler for the assembler.

Here's a small shell script for cloning the repository and compiling the VM and Assembler:
```bash
git clone https://github.com/Moritisimor/AtomVM
cd AtomVM/src
gcc atomvm.c -o atomvm
nim c atomasm.nim
```
