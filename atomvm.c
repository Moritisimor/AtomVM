#include <stdio.h>
#include <stdint.h>

typedef struct {
    uint8_t stack[256];
    uint8_t stack_size;
    uint8_t pc;
} vm_state;

int push(vm_state *vm, uint8_t byte) {
    if (vm->stack_size == 256)
        return 1;

    vm->stack[vm->stack_size - 1] = byte;
    vm->stack_size++;

    return 0;
}

int pop(vm_state *vm, uint8_t *byte) {
    if (vm->stack_size == 0)
        return 1;

    *byte = vm->stack[vm->stack_size - 1];
    vm->stack_size--;

    return 0;
}

int main(int argc, char **argv) {
    return 0;
}
