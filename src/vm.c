#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "vm.h"

void vm_init(vm_state *vm, const uint8_t *program, uint16_t size) {
    vm->sp = 0;
    vm->rsp = 0;
    vm->pc = 0;
    vm->size = size;

    for (uint16_t i = 0; i < size; i++)
        vm->program[i] = program[i];

    for (uint16_t i = 0; i < MEMORY_SIZE; i++)
        vm->memory[i] = 0;

    for (uint16_t i = 0; i < DATA_STACK_SIZE; i++)
        vm->stack[i] = 0;

    for (uint16_t i = 0; i < RETURN_STACK_SIZE; i++)
        vm->return_stack[i] = 0;
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

int vm_run(vm_state *vm) {
    while (1) {
        if (is_halt_or_end(vm))
            return VM_OK;

        uint8_t opcode = vm->program[vm->pc];
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
            if (x == y) vm->pc = target;
            else        vm->pc += 2;
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
            if (y > x) vm->pc = target;
            else       vm->pc += 2;
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
            if (y < x) vm->pc = target;
            else       vm->pc += 2;
            break;
        }

        case JIZ: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if (x == 0) vm->pc = target;
            else        vm->pc += 2;
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
            if (x != y) vm->pc = target;
            else        vm->pc += 2;
            break;
        }

        case JNZ: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if (x != 0) vm->pc = target;
            else        vm->pc += 2;
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
            vm_store(vm, operand, x);
            vm->pc += 2;
            break;
        }

        case LOAD: {
            uint8_t operand;
            code = fetch_operand(vm, &operand);
            if (code) return code;
            code = vm_push(vm, vm_load(vm, operand));
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
            uint8_t val;
            code = vm_pop(vm, &addr_lo);
            if (code) return code;
            val = vm_load(vm, addr_lo);
            code = vm_push(vm, val);
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

        case CALL: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = push_rstack(vm, vm->pc + 2);
            if (code) return code;
            vm->pc = target;
            break;
        }

        case RET:
            code = pop_rstack(vm, &addr);
            if (code) return code;
            vm->pc = addr;
            break;

        case EXECUTE:
            code = vm_pop(vm, &x);
            if (code) return code;
            vm->pc = x;
            break;

        case JGT: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if ((int8_t)x > 0) vm->pc = target;
            else               vm->pc += 2;
            break;
        }

        case JLT: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if ((int8_t)x < 0) vm->pc = target;
            else               vm->pc += 2;
            break;
        }

        case JEQ: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            code = vm_pop(vm, &x);
            if (code) return code;
            if (x == 0) vm->pc = target;
            else        vm->pc += 2;
            break;
        }

        case LOOP: {
            uint8_t target;
            code = fetch_operand(vm, &target);
            if (code) return code;
            if (vm->rsp == 0) return RETURN_STACK_UNDERFLOW;
            vm->return_stack[vm->rsp - 1]--;
            if (vm->return_stack[vm->rsp - 1] != 0)
                vm->pc = target;
            else {
                vm->rsp--;
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
            vm->pc = target;
            break;
        }

        case CALL16: {
            uint16_t target;
            code = fetch_operand16(vm, &target);
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
    }
}
