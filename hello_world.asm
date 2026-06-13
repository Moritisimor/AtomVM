; Simply prints hello world to the console
push 0x0a ; Newline
push 0x21 ; !

push 0x64 ; d
push 0x6c ; l
push 0x72 ; r
push 0x6f ; o
push 0x57 ; W

push 0x20 ; Space

push 0x6f ; o
push 0x6c ; l
push 0x6c ; l
push 0x65 ; e
push 0x48 ; H

push 13
store 0

label loop
    putc
    pop

    load 0
    push 1
    sub

    store 0
    load 0

    jiz exit
    jmp loop

label exit
