#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "vm.h"

#define MAX_PROGRAM_SIZE PROGRAM_SIZE

static const char *error_string(int code) {
    switch (code) {
        case STACK_OVERFLOW:         return "STACK OVERFLOW";
        case STACK_UNDERFLOW:        return "STACK UNDERFLOW";
        case FILE_TOO_LARGE:         return "FILE TOO LARGE";
        case FILE_EMPTY:             return "FILE EMPTY";
        case NO_INPUT_FILE:          return "NO INPUT FILE";
        case FILE_NOT_FOUND:         return "FILE NOT FOUND";
        case FILE_READ_ERR:          return "FILE READ ERROR";
        case UNKNOWN_OPCODE:         return "UNKNOWN OPCODE";
        case PC_OUT_OF_BOUNDS:       return "PROGRAM COUNTER OUT OF BOUNDS";
        case JUMP_OUT_OF_BOUNDS:     return "JUMP TARGET OUT OF BOUNDS";
        case DIVISION_BY_ZERO:       return "DIVISION BY ZERO";
        case RETURN_STACK_OVERFLOW:  return "RETURN STACK OVERFLOW";
        case RETURN_STACK_UNDERFLOW: return "RETURN STACK UNDERFLOW";
        default:                     return "UNKNOWN ERROR";
    }
}

static int read_program(const char *path, uint8_t *buffer, uint16_t *size) {
    FILE *file = fopen(path, "rb");
    if (!file)
        return FILE_NOT_FOUND;

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return FILE_READ_ERR;
    }

    long file_size = ftell(file);
    if (file_size < 0) {
        fclose(file);
        return FILE_READ_ERR;
    }

    if ((unsigned long)file_size > MAX_PROGRAM_SIZE) {
        printf("Programs may not be larger than %u bytes (this one is %ld bytes)\n",
               MAX_PROGRAM_SIZE, file_size);
        fclose(file);
        return FILE_TOO_LARGE;
    }

    if (file_size == 0) {
        printf("Programs may not be empty\n");
        fclose(file);
        return FILE_EMPTY;
    }

    rewind(file);

    size_t bytes_read = fread(buffer, 1, (size_t)file_size, file);
    if (bytes_read != (size_t)file_size) {
        fclose(file);
        printf("Failed to read program file\n");
        return FILE_READ_ERR;
    }

    fclose(file);
    *size = (uint16_t)bytes_read;
    return VM_OK;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: atomvm <file path>\n");
        return NO_INPUT_FILE;
    }

    uint8_t program[MAX_PROGRAM_SIZE];
    uint16_t size;
    int code = read_program(argv[1], program, &size);
    if (code != VM_OK) {
        if (code == FILE_NOT_FOUND)
            printf("File '%s' not found\n", argv[1]);
        else if (code == FILE_READ_ERR)
            printf("Could not read file '%s'\n", argv[1]);
        return code;
    }

    vm_state vm;
    vm_init(&vm, program, size);

    int exit_code = vm_run(&vm);

    if (exit_code != VM_OK) {
        printf("\n\n===== ERROR =====\n");
        printf("EXECUTION ABNORMALLY TERMINATED AT PC: 0x%x / %u\n",
               (unsigned int)vm.pc, (unsigned int)vm.pc);
        printf("REASON: %s\n", error_string(exit_code));
    }

    return exit_code;
}
