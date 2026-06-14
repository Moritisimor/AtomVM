#ifndef VM_H
#define VM_H

#include <stdint.h>
#include "opcodes.h"

#define DATA_STACK_SIZE    2048
#define RETURN_STACK_SIZE  256
#define LOOP_STACK_SIZE    64
#define PROGRAM_SIZE       4096
#define MEMORY_SIZE        4096
#define HEAP_START         3000

/* set to 1 for verbose instruction tracing */
#ifndef VM_DEBUG
#define VM_DEBUG 0
#endif

typedef struct {
    uint8_t  stack[DATA_STACK_SIZE];
    uint8_t  memory[MEMORY_SIZE];
    uint8_t  program[PROGRAM_SIZE];
    uint16_t return_stack[RETURN_STACK_SIZE];
    uint16_t loop_stack[LOOP_STACK_SIZE];

    uint16_t sp;
    uint16_t rsp;
    uint16_t lsp;
    uint16_t pc;
    uint16_t size;
    uint16_t heap;
} vm_state;

void vm_init(vm_state *vm, const uint8_t *program, uint16_t size);

int vm_push(vm_state *vm, uint8_t byte);
int vm_pop(vm_state *vm, uint8_t *byte);
int vm_peek(vm_state *vm, uint8_t *byte);

uint8_t vm_load(const vm_state *vm, uint16_t addr);
void vm_store(vm_state *vm, uint16_t addr, uint8_t byte);

int vm_run(vm_state *vm);

#endif
