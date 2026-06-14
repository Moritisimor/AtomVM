#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "vm.h"

#define MAX_PROGRAM_SIZE PROGRAM_SIZE
#define ATOMVM_VERSION "0.4.0"

typedef enum {
    COLOR_AUTO,
    COLOR_ALWAYS,
    COLOR_NEVER
} color_mode;

static int use_color(color_mode mode) {
    if (mode == COLOR_ALWAYS)
        return 1;
    if (mode == COLOR_NEVER || getenv("NO_COLOR") != NULL)
        return 0;
    return isatty(STDERR_FILENO);
}

static const char *style(int enabled, const char *code) {
    return enabled ? code : "";
}

static void print_help(void) {
    printf("AtomVM %s\n", ATOMVM_VERSION);
    printf("Usage:\n");
    printf("  atomvm [options] <program.bc>\n\n");
    printf("Options:\n");
    printf("  -h, --help       Show this help text\n");
    printf("  -V, --version    Print version information\n");
    printf("  --info           Print bytecode metadata without running\n");
    printf("  --stats          Print runtime statistics after execution\n");
    printf("  --color <mode>   Color output: auto, always, never\n");
    printf("  --quiet          Suppress VM error banner\n");
}

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

static void print_info(const char *path, const uint8_t *program, uint16_t size) {
    uint16_t code_size = 0;
    uint16_t data_size = 0;
    if (size >= 2) {
        code_size = ((uint16_t)program[0] << 8) | program[1];
        if (code_size > size - 2)
            code_size = size - 2;
        data_size = size - 2 - code_size;
    }

    printf("AtomVM bytecode\n");
    printf("  file: %s\n", path);
    printf("  size: %u bytes\n", (unsigned int)size);
    printf("  code: %u bytes\n", (unsigned int)code_size);
    printf("  data: %u bytes\n", (unsigned int)data_size);
}

int main(int argc, char **argv) {
    const char *input_path = NULL;
    int show_info = 0;
    int show_stats = 0;
    int quiet = 0;
    color_mode colors = COLOR_AUTO;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_help();
            return VM_OK;
        } else if (strcmp(argv[i], "-V") == 0 || strcmp(argv[i], "--version") == 0) {
            printf("AtomVM %s\n", ATOMVM_VERSION);
            return VM_OK;
        } else if (strcmp(argv[i], "--info") == 0) {
            show_info = 1;
        } else if (strcmp(argv[i], "--stats") == 0) {
            show_stats = 1;
        } else if (strcmp(argv[i], "--color") == 0) {
            if (i + 1 >= argc) {
                fprintf(stderr, "atomvm: error: expected mode after --color\n");
                return NO_INPUT_FILE;
            }
            i++;
            if (strcmp(argv[i], "auto") == 0)
                colors = COLOR_AUTO;
            else if (strcmp(argv[i], "always") == 0)
                colors = COLOR_ALWAYS;
            else if (strcmp(argv[i], "never") == 0)
                colors = COLOR_NEVER;
            else {
                fprintf(stderr, "atomvm: error: invalid color mode '%s'\n", argv[i]);
                return NO_INPUT_FILE;
            }
        } else if (strcmp(argv[i], "--quiet") == 0) {
            quiet = 1;
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "atomvm: error: unknown option '%s'\n", argv[i]);
            fprintf(stderr, "Try 'atomvm --help'.\n");
            return NO_INPUT_FILE;
        } else if (input_path == NULL) {
            input_path = argv[i];
        } else {
            fprintf(stderr, "atomvm: error: unexpected argument '%s'\n", argv[i]);
            fprintf(stderr, "Try 'atomvm --help'.\n");
            return NO_INPUT_FILE;
        }
    }

    if (input_path == NULL) {
        print_help();
        return NO_INPUT_FILE;
    }

    uint8_t program[MAX_PROGRAM_SIZE];
    uint16_t size;
    int code = read_program(input_path, program, &size);
    if (code != VM_OK) {
        if (code == FILE_NOT_FOUND)
            fprintf(stderr, "atomvm: error: file '%s' not found\n", input_path);
        else if (code == FILE_READ_ERR)
            fprintf(stderr, "atomvm: error: could not read file '%s'\n", input_path);
        return code;
    }

    if (show_info) {
        print_info(input_path, program, size);
        return VM_OK;
    }

    vm_state vm;
    vm_init(&vm, program, size);

    clock_t started = clock();
    int exit_code = vm_run(&vm);
    clock_t finished = clock();

    if (exit_code != VM_OK && !quiet) {
        int color = use_color(colors);
        fprintf(stderr, "\n%satomvm:%s %serror:%s execution failed\n",
                style(color, "\033[1m"), style(color, "\033[0m"),
                style(color, "\033[31m"), style(color, "\033[0m"));
        fprintf(stderr, "  pc:     0x%x / %u\n",
               (unsigned int)vm.pc, (unsigned int)vm.pc);
        fprintf(stderr, "  reason: %s\n", error_string(exit_code));
    }

    if (show_stats && !quiet) {
        double elapsed_ms = 0.0;
        if (finished >= started)
            elapsed_ms = ((double)(finished - started) * 1000.0) / (double)CLOCKS_PER_SEC;
        fprintf(stderr, "atomvm: finished in %.2f ms (exit %d, pc %u, stack %u)\n",
                elapsed_ms, exit_code, (unsigned int)vm.pc, (unsigned int)vm.sp);
    }

    return exit_code;
}
