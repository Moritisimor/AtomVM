#include <stdio.h>
#include <stdint.h>

#define STACK_OVERFLOW_ERROR 1
#define STACK_UNDERFLOW_ERROR 2
#define FILE_TOO_LARGE_ERROR 3
#define FILE_EMPTY_ERROR 4
#define NO_INPUT_FILE_ERROR 5
#define FILE_NOT_FOUND_ERROR 6

typedef struct {
    uint8_t stack[256];
    uint8_t program[256];
    uint8_t stack_size;
    uint8_t pc;
} vm_state;

vm_state initialize_vm(uint8_t *program) {
    uint8_t stack[256];
    vm_state vm = {
        .stack_size = 0,
        .pc = 0,
        .program = program,
        .stack = stack
    };

    return vm;
}

int push(vm_state *vm, uint8_t byte) {
    if (vm->stack_size == 256)
        return STACK_OVERFLOW_ERROR;

    vm->stack[vm->stack_size - 1] = byte;
    vm->stack_size++;

    return 0;
}

int pop(vm_state *vm, uint8_t *byte) {
    if (vm->stack_size == 0)
        return STACK_UNDERFLOW_ERROR;

    *byte = vm->stack[vm->stack_size - 1];
    vm->stack_size--;

    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: atomvm <file path>");
        return NO_INPUT_FILE_ERROR;
    }

    char *file_name = argv[1];
    FILE *file = fopen(file_name, "r");
    if (file == 0) {
        printf("File '%s' not found", file_name);
        return FILE_NOT_FOUND_ERROR;
    }

    fseek(file, 0, SEEK_END);
    long size = ftell(file);

    if (size > 256) {
        printf("Programs may not be larger than 256 bytes (this one is %d bytes large)", size);
        return FILE_TOO_LARGE_ERROR;
    } else if (size == 0) {
        printf("Programs may not be empty");
        return FILE_EMPTY_ERROR;
    }

    rewind(file);
    uint8_t program[256];
    for (size_t i = 0; i < size; i++) {
        int b = fgetc(file);
        if (b == EOF)
            break;

        program[i] = (uint8_t) b;
    }

    vm_state vm = initialize_vm(program);
    return 0;
}
