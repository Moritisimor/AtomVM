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
