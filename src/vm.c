#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "vm.h"

#if VM_DEBUG
#define DBG_PRINT(...) do { \
    printf("[DEBUG pc=%u] ", (unsigned int)vm->pc); \
    printf(__VA_ARGS__); \
} while(0)
#else
#define DBG_PRINT(...)
#endif

void vm_init(vm_state *vm, const uint8_t *program, uint16_t size) {
    vm->sp = 0;
    vm->rsp = 0;
    vm->lsp = 0;
    vm->pc = 0;
    vm->size = size;
    vm->heap = HEAP_START;

    for (uint16_t i = 0; i < MEMORY_SIZE; i++)
        vm->memory[i] = 0;

    for (uint16_t i = 0; i < DATA_STACK_SIZE; i++)
        vm->stack[i] = 0;

    for (uint16_t i = 0; i < RETURN_STACK_SIZE; i++)
        vm->return_stack[i] = 0;

    for (uint16_t i = 0; i < LOOP_STACK_SIZE; i++)
        vm->loop_stack[i] = 0;

    /* bytecode format: [code_size:2 big-endian][code bytes][string data] */
    if (size < 2) {
        vm->size = 0;
        return;
    }

    uint16_t code_size = ((uint16_t)program[0] << 8) | program[1];
    if (code_size > PROGRAM_SIZE) code_size = PROGRAM_SIZE;
    if (code_size > size - 2) code_size = size - 2;

    for (uint16_t i = 0; i < code_size; i++)
        vm->program[i] = program[i + 2];

    vm->size = code_size;

    /* string data starts at fixed address in data memory */
    uint16_t data_start = code_size + 2;
    uint16_t data_len = size - data_start;

    uint16_t str_addr = 2000;
    if (str_addr + data_len > MEMORY_SIZE)
        data_len = MEMORY_SIZE - str_addr;

    for (uint16_t i = 0; i < data_len; i++)
        vm->memory[str_addr + i] = program[data_start + i];
}

int vm_push(vm_state *vm, uint8_t byte) {
    if (vm->sp >= DATA_STACK_SIZE)
        return STACK_OVERFLOW;
    vm->stack[vm->sp++] = byte;
    return VM_OK;
}

int vm_pop(vm_state *vm, uint8_t *byte) {
    if (vm->sp == 0)
        return STACK_UNDERFLOW;
    *byte = vm->stack[--vm->sp];
    return VM_OK;
}

int vm_peek(vm_state *vm, uint8_t *byte) {
    if (vm->sp == 0)
        return STACK_UNDERFLOW;
    *byte = vm->stack[vm->sp - 1];
    return VM_OK;
}

uint8_t vm_load(const vm_state *vm, uint16_t addr) {
    if (addr >= MEMORY_SIZE) return 0;
    return vm->memory[addr];
}

void vm_store(vm_state *vm, uint16_t addr, uint8_t byte) {
    if (addr < MEMORY_SIZE)
        vm->memory[addr] = byte;
}

static int fetch_operand(const vm_state *vm, uint8_t *operand) {
    if (vm->pc + 1 >= vm->size)
        return PC_OUT_OF_BOUNDS;
    *operand = vm->program[vm->pc + 1];
    return VM_OK;
}

static int fetch_operand16(const vm_state *vm, uint16_t *operand) {
    if (vm->pc + 2 >= vm->size)
        return PC_OUT_OF_BOUNDS;
    *operand = ((uint16_t)vm->program[vm->pc + 1] << 8)
             | (uint16_t)vm->program[vm->pc + 2];
    return VM_OK;
}

static int check_jump_bounds(const vm_state *vm, uint16_t target) {
    if (target > vm->size)
        return JUMP_OUT_OF_BOUNDS;
    return VM_OK;
}

static int is_halt_or_end(const vm_state *vm) {
    return vm->pc >= vm->size || vm->program[vm->pc] == 0;
}

static int push_rstack(vm_state *vm, uint16_t addr) {
    if (vm->rsp >= RETURN_STACK_SIZE)
        return RETURN_STACK_OVERFLOW;
    vm->return_stack[vm->rsp++] = addr;
    return VM_OK;
}

static int pop_rstack(vm_state *vm, uint16_t *addr) {
    if (vm->rsp == 0)
        return RETURN_STACK_UNDERFLOW;
    *addr = vm->return_stack[--vm->rsp];
    return VM_OK;
}

static int pop_addr16(vm_state *vm, uint16_t *addr) {
    uint8_t lo, hi;
    int code = vm_pop(vm, &lo);
    if (code) return code;
    code = vm_pop(vm, &hi);
    if (code) return code;
    *addr = ((uint16_t)hi << 8) | lo;
    return VM_OK;
}

int vm_run(vm_state *vm) {
    while (1) {
        if (is_halt_or_end(vm))
            return VM_OK;

        uint8_t opcode = vm->program[vm->pc];
        DBG_PRINT("opcode=0x%02x sp=%u\n", opcode, (unsigned int)vm->sp);
        uint8_t x, y;
        uint16_t addr;
        int code;

        switch (opcode) {

        case PUSH: {
            uint8_t operand;
            code = fetch_operand(vm, &operand);
            if (code) return code;
            code = vm_push(vm, operand);
            if (code) return code;
            vm->pc += 2;
            break;
        }

        case POP:
            code = vm_pop(vm, &x);
            if (code) return code;
            vm->pc++;
            break;

        case ADD:
        case SUB:
        case MUL:
        case DIV:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            if (opcode == DIV && x == 0)
                return DIVISION_BY_ZERO;
            {
                uint8_t result;
                if (opcode == ADD)         result = y + x;
                else if (opcode == SUB)    result = y - x;
                else if (opcode == MUL)    result = y * x;
                else                       result = y / x;
                code = vm_push(vm, result);
                if (code) return code;
            }
            vm->pc++;
            break;

        case JMP: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = check_jump_bounds(vm, target);
            if (code) return code;
            vm->pc = target;
            break;
        }

        case JIE: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            if (x == y) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JIG: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            if (y > x) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JIS: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            if (y < x) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JIZ: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if (x == 0) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JNE: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            if (x != y) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JNZ: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if (x != 0) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case PUTN:
            code = vm_peek(vm, &x);
            if (code) return code;
            printf("%u", (unsigned int)x);
            vm->pc++;
            break;

        case PUTC:
            code = vm_peek(vm, &x);
            if (code) return code;
            printf("%c", x);
            vm->pc++;
            break;

        case DUP:
            code = vm_peek(vm, &x);
            if (code) return code;
            code = vm_push(vm, x);
            if (code) return code;
            vm->pc++;
            break;

        case STORE: {
            uint8_t operand;
            code = fetch_operand(vm, &operand);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            DBG_PRINT("STORE addr=%u val=%u\n", operand, x);
            vm_store(vm, operand, x);
            vm->pc += 2;
            break;
        }

        case LOAD: {
            uint8_t operand;
            code = fetch_operand(vm, &operand);
            if (code) return code;
            x = vm_load(vm, operand);
            DBG_PRINT("LOAD addr=%u val=%u\n", operand, x);
            code = vm_push(vm, x);
            if (code) return code;
            vm->pc += 2;
            break;
        }

        case MOD:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            if (x == 0) return DIVISION_BY_ZERO;
            code = vm_push(vm, y % x);
            if (code) return code;
            vm->pc++;
            break;

        case INC:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_push(vm, x + 1);
            if (code) return code;
            vm->pc++;
            break;

        case DEC:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_push(vm, x - 1);
            if (code) return code;
            vm->pc++;
            break;

        case NEG:
            code = vm_peek(vm, &x);
            if (code) return code;
            vm->stack[vm->sp - 1] = (~x) + 1;
            vm->pc++;
            break;

        case AND:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, y & x);
            if (code) return code;
            vm->pc++;
            break;

        case OR:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, y | x);
            if (code) return code;
            vm->pc++;
            break;

        case XOR:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, y ^ x);
            if (code) return code;
            vm->pc++;
            break;

        case NOT:
            code = vm_peek(vm, &x);
            if (code) return code;
            vm->stack[vm->sp - 1] = ~x;
            vm->pc++;
            break;

        case SHL:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, (uint8_t)((uint16_t)y << (x & 7)));
            if (code) return code;
            vm->pc++;
            break;

        case SHR:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, y >> (x & 7));
            if (code) return code;
            vm->pc++;
            break;

        case MIN:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, (y < x) ? y : x);
            if (code) return code;
            vm->pc++;
            break;

        case MAX:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, (y > x) ? y : x);
            if (code) return code;
            vm->pc++;
            break;

        case CMP: {
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            int8_t cmp_result;
            if (x < y)      cmp_result = -1;
            else if (x > y) cmp_result = 1;
            else            cmp_result = 0;
            code = vm_push(vm, (uint8_t)cmp_result);
            if (code) return code;
            vm->pc++;
            break;
        }

        case SWAP:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = vm_pop(vm, &y);
            if (code) return code;
            code = vm_push(vm, x);
            if (code) return code;
            code = vm_push(vm, y);
            if (code) return code;
            vm->pc++;
            break;

        case OVER:
            if (vm->sp < 2) return STACK_UNDERFLOW;
            x = vm->stack[vm->sp - 2];
            code = vm_push(vm, x);
            if (code) return code;
            vm->pc++;
            break;

        case ROT:
            if (vm->sp < 3) return STACK_UNDERFLOW;
            x = vm->stack[vm->sp - 3];
            vm->stack[vm->sp - 3] = vm->stack[vm->sp - 2];
            vm->stack[vm->sp - 2] = vm->stack[vm->sp - 1];
            vm->stack[vm->sp - 1] = x;
            vm->pc++;
            break;

        case NIP:
            if (vm->sp < 2) return STACK_UNDERFLOW;
            vm->stack[vm->sp - 2] = vm->stack[vm->sp - 1];
            vm->sp--;
            vm->pc++;
            break;

        case TUCK:
            if (vm->sp < 2) return STACK_UNDERFLOW;
            x = vm->stack[vm->sp - 1];
            y = vm->stack[vm->sp - 2];
            vm->stack[vm->sp - 2] = x;
            vm->stack[vm->sp - 1] = y;
            code = vm_push(vm, x);
            if (code) return code;
            vm->pc++;
            break;

        case DUP2:
            if (vm->sp < 2) return STACK_UNDERFLOW;
            x = vm->stack[vm->sp - 2];
            y = vm->stack[vm->sp - 1];
            code = vm_push(vm, x);
            if (code) return code;
            code = vm_push(vm, y);
            if (code) return code;
            vm->pc++;
            break;

        case DROP2:
            if (vm->sp < 2) return STACK_UNDERFLOW;
            vm->sp -= 2;
            vm->pc++;
            break;

        case SWAP2:
            if (vm->sp < 4) return STACK_UNDERFLOW;
            x = vm->stack[vm->sp - 4];
            y = vm->stack[vm->sp - 3];
            vm->stack[vm->sp - 4] = vm->stack[vm->sp - 2];
            vm->stack[vm->sp - 3] = vm->stack[vm->sp - 1];
            vm->stack[vm->sp - 2] = x;
            vm->stack[vm->sp - 1] = y;
            vm->pc++;
            break;

        case DEPTH:
        case DDEPTH:
            code = vm_push(vm, (uint8_t)(vm->sp & 0xFF));
            if (code) return code;
            vm->pc++;
            break;

        case FETCH: {
            uint8_t addr_lo;
            code = vm_pop(vm, &addr_lo);
            if (code) return code;
            x = vm_load(vm, addr_lo);
            code = vm_push(vm, x);
            if (code) return code;
            vm->pc++;
            break;
        }

        case STOREI: {
            uint8_t val, addr_lo;
            code = vm_pop(vm, &addr_lo);
            if (code) return code;
            code = vm_pop(vm, &val);
            if (code) return code;
            vm_store(vm, addr_lo, val);
            vm->pc++;
            break;
        }

        case FILL: {
            uint8_t fill_val, n_bytes;
            uint16_t fill_addr;
            code = vm_pop(vm, &fill_val);
            if (code) return code;
            if (vm->pc + 3 >= vm->size) return PC_OUT_OF_BOUNDS;
            n_bytes = vm->program[vm->pc + 1];
            fill_addr = ((uint16_t)vm->program[vm->pc + 2] << 8)
                      | (uint16_t)vm->program[vm->pc + 3];
            for (uint8_t i = 0; i < n_bytes; i++)
                vm_store(vm, fill_addr + i, fill_val);
            vm->pc += 4;
            break;
        }

        case FETCH16: {
            code = pop_addr16(vm, &addr);
            if (code) return code;
            x = vm_load(vm, addr);
            code = vm_push(vm, x);
            if (code) return code;
            vm->pc++;
            break;
        }

        case STOREI16: {
            code = pop_addr16(vm, &addr);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            vm_store(vm, addr, x);
            vm->pc++;
            break;
        }

        case PUTSN: {
            uint8_t len;
            code = vm_pop(vm, &len);
            if (code) return code;
            code = pop_addr16(vm, &addr);
            if (code) return code;
            for (uint8_t i = 0; i < len && addr + i < MEMORY_SIZE; i++)
                printf("%c", vm_load(vm, addr + i));
            vm->pc++;
            break;
        }

        case STRCMP: {
            uint16_t left, right;
            code = pop_addr16(vm, &right);
            if (code) return code;
            code = pop_addr16(vm, &left);
            if (code) return code;
            while (left < MEMORY_SIZE && right < MEMORY_SIZE) {
                uint8_t a = vm_load(vm, left++);
                uint8_t b = vm_load(vm, right++);
                if (a != b) {
                    code = vm_push(vm, (uint8_t)((a < b) ? -1 : 1));
                    if (code) return code;
                    vm->pc++;
                    goto next_instruction;
                }
                if (a == 0) break;
            }
            code = vm_push(vm, 0);
            if (code) return code;
            vm->pc++;
            break;
        }

        case ALLOC: {
            uint8_t n_bytes;
            code = vm_pop(vm, &n_bytes);
            if (code) return code;
            if ((uint16_t)vm->heap + n_bytes >= MEMORY_SIZE)
                return FILE_TOO_LARGE;
            addr = vm->heap;
            for (uint8_t i = 0; i < n_bytes; i++)
                vm_store(vm, addr + i, 0);
            vm->heap += n_bytes;
            code = vm_push(vm, (uint8_t)(addr >> 8));
            if (code) return code;
            code = vm_push(vm, (uint8_t)(addr & 0xFF));
            if (code) return code;
            vm->pc++;
            break;
        }

        case AGET: {
            uint8_t index;
            code = vm_pop(vm, &index);
            if (code) return code;
            code = pop_addr16(vm, &addr);
            if (code) return code;
            if (index >= vm_load(vm, addr))
                return JUMP_OUT_OF_BOUNDS;
            code = vm_push(vm, vm_load(vm, addr + 1 + index));
            if (code) return code;
            vm->pc++;
            break;
        }

        case ALEN:
            code = pop_addr16(vm, &addr);
            if (code) return code;
            code = vm_push(vm, vm_load(vm, addr));
            if (code) return code;
            vm->pc++;
            break;

        case LOADREL: {
            uint8_t offset;
            code = vm_pop(vm, &offset);
            if (code) return code;
            code = pop_addr16(vm, &addr);
            if (code) return code;
            code = vm_push(vm, vm_load(vm, addr + offset));
            if (code) return code;
            vm->pc++;
            break;
        }

        case ASET: {
            uint8_t index, val;
            code = vm_pop(vm, &val);
            if (code) return code;
            code = vm_pop(vm, &index);
            if (code) return code;
            code = pop_addr16(vm, &addr);
            if (code) return code;
            if (index >= vm_load(vm, addr))
                return JUMP_OUT_OF_BOUNDS;
            vm_store(vm, addr + 1 + index, val);
            vm->pc++;
            break;
        }

        case CALL: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = check_jump_bounds(vm, target);
            if (code) return code;
            code = push_rstack(vm, vm->pc + 2);
            if (code) return code;
            vm->pc = target;
            break;
        }

        case RET:
            code = pop_rstack(vm, &addr);
            if (code) return code;
            code = check_jump_bounds(vm, addr);
            if (code) return code;
            vm->pc = addr;
            break;

        case EXECUTE:
            code = vm_pop(vm, &x);
            if (code) return code;
            code = check_jump_bounds(vm, x);
            if (code) return code;
            vm->pc = x;
            break;

        case JGT: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if ((int8_t)x > 0) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JLT: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if ((int8_t)x < 0) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case JEQ: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if (x == 0) {
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->pc += 2;
            }
            break;
        }

        case LOOP: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            if (vm->lsp == 0) {
                /* initialize loop counter from stack */
                code = vm_pop(vm, &x);
                if (code) return code;
                if (vm->lsp >= LOOP_STACK_SIZE)
                    return STACK_OVERFLOW;
                vm->loop_stack[vm->lsp++] = x;
            }
            if (vm->loop_stack[vm->lsp - 1] > 0) {
                vm->loop_stack[vm->lsp - 1]--;
                code = check_jump_bounds(vm, target);
                if (code) return code;
                vm->pc = target;
            } else {
                vm->lsp--;
                vm->pc += 2;
            }
            break;
        }

        case EMIT:
            code = vm_peek(vm, &x);
            if (code) return code;
            printf("%c", x);
            vm->pc++;
            break;

        case CR:
            printf("\n");
            vm->pc++;
            break;

        case SPACE:
            printf(" ");
            vm->pc++;
            break;

        case KEY: {
            int c = getchar();
            if (c == EOF) c = 0;
            code = vm_push(vm, (uint8_t)c);
            if (code) return code;
            vm->pc++;
            break;
        }

        case PUTS: {
            uint8_t lo, hi;
            code = vm_pop(vm, &lo);
            if (code) return code;
            code = vm_pop(vm, &hi);
            if (code) return code;
            uint16_t addr = ((uint16_t)hi << 8) | lo;
            while (addr < MEMORY_SIZE) {
                uint8_t ch = vm_load(vm, addr);
                if (ch == 0) break;
                printf("%c", ch);
                addr++;
            }
            vm->pc++;
            break;
        }

        case STRLEN: {
            uint8_t lo, hi;
            code = vm_pop(vm, &lo);
            if (code) return code;
            code = vm_pop(vm, &hi);
            if (code) return code;
            uint16_t addr = ((uint16_t)hi << 8) | lo;
            uint16_t len = 0;
            while (addr + len < MEMORY_SIZE) {
                if (vm_load(vm, addr + len) == 0) break;
                len++;
            }
            code = vm_push(vm, (uint8_t)(len >> 8));
            if (code) return code;
            code = vm_push(vm, (uint8_t)(len & 0xFF));
            if (code) return code;
            vm->pc++;
            break;
        }

        case PUTC_POP:
            code = vm_pop(vm, &x);
            if (code) return code;
            printf("%c", x);
            vm->pc++;
            break;

        case PUTN_POP:
            code = vm_pop(vm, &x);
            if (code) return code;
            printf("%u", (unsigned int)x);
            vm->pc++;
            break;

        case RDEPTH:
            code = vm_push(vm, (uint8_t)(vm->rsp & 0xFF));
            if (code) return code;
            vm->pc++;
            break;

        case MSIZE:
            code = vm_push(vm, (uint8_t)(MEMORY_SIZE & 0xFF));
            if (code) return code;
            vm->pc++;
            break;

        case STATE:
            code = vm_push(vm, 0);
            if (code) return code;
            vm->pc++;
            break;

        case BYE:
            code = vm_pop(vm, &x);
            if (code) return code;
            return x;

        case PUSH16: {
            uint16_t val;
            code = fetch_operand16(vm, &val);
            if (code) return code;
            code = vm_push(vm, (uint8_t)(val >> 8));
            if (code) return code;
            code = vm_push(vm, (uint8_t)(val & 0xFF));
            if (code) return code;
            vm->pc += 3;
            break;
        }

        case JMP16: {
            uint16_t target;
            code = fetch_operand16(vm, &target);
            if (code) return code;
            code = check_jump_bounds(vm, target);
            if (code) return code;
            vm->pc = target;
            break;
        }

        case CALL16: {
            uint16_t target;
            code = fetch_operand16(vm, &target);
            if (code) return code;
            code = check_jump_bounds(vm, target);
            if (code) return code;
            code = push_rstack(vm, vm->pc + 3);
            if (code) return code;
            vm->pc = target;
            break;
        }

        case HALT:
            return VM_OK;

        default:
            return UNKNOWN_OPCODE;
        }
next_instruction:
        ;
    }
}
