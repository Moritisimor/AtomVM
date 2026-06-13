#include <stdio.h>
#include <stdint.h>

// Errors
#define STACK_OVERFLOW_ERROR 1
#define STACK_UNDERFLOW_ERROR 2
#define FILE_TOO_LARGE_ERROR 3
#define FILE_EMPTY_ERROR 4
#define NO_INPUT_FILE_ERROR 5
#define FILE_NOT_FOUND_ERROR 6
#define UNKNOWN_OPCODE_ERROR 7

// Opcodes
#define HALT 0
#define PUSH 1
#define POP 2
#define ADD 3
#define SUB 4
#define MUL 5
#define DIV 6
#define JMP 7
#define JIG 8
#define JIE 9
#define JIS 10
#define JIZ 11
#define JNE 12
#define PUTN 13
#define PUTC 14
#define JNZ 15
#define DUP 16
#define STORE 17
#define LOAD 18

typedef struct {
    uint8_t stack[256];
    uint8_t program[256];
    uint8_t memory[256];
    uint8_t stack_pointer;
    uint8_t pc;
} vm_state;

int push(vm_state *vm, uint8_t byte) {
    if (vm->stack_pointer == 255)
        return STACK_OVERFLOW_ERROR;

    vm->stack[vm->stack_pointer] = byte;
    vm->stack_pointer++;

    return 0;
}

uint8_t load(vm_state *vm, uint8_t idx) {
    return vm->memory[idx];
}

void store(vm_state *vm, uint8_t idx, uint8_t byte) {
    vm->memory[idx] = byte;
}

int pop(vm_state *vm, uint8_t *byte) {
    if (vm->stack_pointer == 0)
        return STACK_UNDERFLOW_ERROR;

    *byte = vm->stack[--vm->stack_pointer];
    return 0;
}

int peek(vm_state *vm, uint8_t *byte) {
    if (vm->stack_pointer == 0)
        return STACK_UNDERFLOW_ERROR;

    *byte = vm->stack[vm->stack_pointer - 1];
    return 0;
}

int fetch_decode_exec_loop(vm_state *vm) {
    while (1) {
        uint8_t x, y, z, jmp_target, address;
        uint8_t opcode = vm->program[vm->pc];
        int code;

        switch (opcode) {
            case PUSH:
                code = push(vm, vm->program[vm->pc + 1]);
                if (code)
                    return code;

                vm->pc += 2;
                break;

            case POP:
                code = pop(vm, &x);
                if (code)
                    return code;

                vm->pc++;
                break;

            case ADD:
            case SUB:
            case MUL:
            case DIV:
                code = pop(vm, &x);
                if (code)
                    return code;

                code = pop(vm, &y);
                if (code)
                    return code;

                uint8_t result;
                if (opcode == ADD) 
                    result = y + x;
                else if (opcode == SUB)
                    result = y - x;
                else if (opcode == MUL)
                    result = y * x;
                else
                    result = y / x;

                code = push(vm, result);
                if (code)
                    return code;

                vm->pc++;
                break;

            case PUTN:
                code = peek(vm, &x);
                if (code)
                    return code;

                printf("%d", x);
                vm->pc++;
                break;

            case PUTC:
                code = peek(vm, &x);
                if (code)
                    return code;

                printf("%c", x);
                vm->pc++;
                break;

            case JMP:
                jmp_target = vm->program[vm->pc + 1];
                vm->pc = jmp_target;
                break;

            case JIE:
                jmp_target = vm->program[vm->pc + 1];
        
                code = pop(vm, &x);
                if (code)
                    return code;

                code = pop(vm, &y);
                if (code)
                    return code;

                if (x == y)
                    vm->pc = jmp_target;
                else
                    vm->pc += 2;

                break;

            case JIG:
                jmp_target = vm->program[vm->pc + 1];

                code = pop(vm, &x);
                if (code)
                    return code;

                code = pop(vm, &y);
                if (code)
                    return code;

                if (y > x)
                    vm->pc = jmp_target;
                else
                    vm->pc += 2;

                break;

            case JIS:
                jmp_target = vm->program[vm->pc + 1];

                code = pop(vm, &x);
                if (code)
                    return code;

                code = pop(vm, &y);
                if (code)
                    return code;

                if (y < x)
                    vm->pc = jmp_target;
                else
                    vm->pc += 2;

                break;

            case JIZ:
                jmp_target = vm->program[vm->pc + 1];

                code = pop(vm, &x);
                if (code)
                    return code;

                if (x == 0)
                    vm->pc = jmp_target;
                else
                    vm->pc += 2;

                break;

            case JNZ:
                jmp_target = vm->program[vm->pc + 1];

                code = pop(vm, &x);
                if (code)
                    return code;

                if (x != 0)
                    vm->pc = jmp_target;
                else
                    vm->pc += 2;

                break;

            case DUP:
                code = peek(vm, &x);
                if (code)
                    return code;

                code = push(vm, x);
                if (code)
                    return code;

                break;

            case STORE:
                address = vm->program[vm->pc + 1];

                code = pop(vm, &x);
                if (code)
                    return code;

                store(vm, address, x);
                vm->pc += 2;
                break;

            case LOAD:
                address = vm->program[vm->pc + 1];

                code = push(vm, load(vm, address));
                if (code)
                    return code;

                vm->pc += 2;
                break;

            case HALT: return 0;
            default: return UNKNOWN_OPCODE_ERROR;
        }
    }
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: atomvm <file path>\n");
        return NO_INPUT_FILE_ERROR;
    }

    char *file_name = argv[1];
    FILE *file = fopen(file_name, "r");
    if (file == 0) {
        printf("File '%s' not found\n", file_name);
        return FILE_NOT_FOUND_ERROR;
    }

    fseek(file, 0, SEEK_END);
    long size = ftell(file);

    if (size > 256) {
        printf("Programs may not be larger than 256 bytes (this one is %d bytes large)\n", size);
        return FILE_TOO_LARGE_ERROR;
    } else if (size == 0) {
        printf("Programs may not be empty\n");
        return FILE_EMPTY_ERROR;
    }

    rewind(file);
    uint8_t program[256];
    vm_state vm = {0};

    for (size_t i = 0; i < size; i++) {
        int b = fgetc(file);
        if (b == EOF)
            break;

        vm.program[i] = (uint8_t) b;
    }

    int exit_code = fetch_decode_exec_loop(&vm);
    int last_pc = vm.pc;

    if (exit_code != 0) {
        printf("\n\n===== ERROR =====\n");
        printf("EXECUTION ABNORMALLY TERMINATED AT PC: 0x%x / %d\n", last_pc, last_pc);
        printf("REASON: ");
        switch (exit_code) {
            case STACK_OVERFLOW_ERROR:
                printf("STACK OVERFLOW\n");
                break;

            case STACK_UNDERFLOW_ERROR:
                printf("STACK UNDERFLOW\n");
                break;

            case UNKNOWN_OPCODE_ERROR:
                printf("UNKNOWN OPCODE\n");
                break;
        }
    }

    return exit_code;
}
