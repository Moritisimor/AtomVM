#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define BUF_SIZE 256

// Errors
#define UNKNOWN_MNEMONIC_ERROR 1
#define FILE_NOT_FOUND_ERROR 2
#define NOT_ENOUGH_ARGUMENTS_ERROR 3
#define OUTPUT_ERROR 4

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

int has_prefix(char *pre, char *str) {
    return strncmp(pre, str, strlen(pre)) == 0;
}

int line_to_bytecode(char *line, uint8_t *byte_buf, size_t *top_idx) {
    if (strlen(line) == 0) {
        return 0;
    }

    if (has_prefix("HALT", line)) {
        byte_buf[*top_idx] = HALT;
        *top_idx++;
        return 0;
    }

    return UNKNOWN_MNEMONIC_ERROR;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        printf("Usage: atomasm <input file> <output file>\n");
        return NOT_ENOUGH_ARGUMENTS_ERROR;
    }

    char *file_name = argv[1];
    char *output_path = argv[2];
    char line_buf[BUF_SIZE] = {0};
    uint8_t byte_buf[BUF_SIZE] = {0};
    size_t top_idx = 0;

    FILE *file = fopen(file_name, "r");
    if (file == NULL) {
        printf("File '%s' not found\n", file_name);
        return FILE_NOT_FOUND_ERROR;
    }

    int idx = 1;
    while (fgets(line_buf, BUF_SIZE, file)) {
        int code = line_to_bytecode(line_buf, byte_buf, &top_idx);
        if (code) {
            printf("ERROR WHILE ASSEMBLING BYTECODE AT LINE: %d\n", idx);
            printf("REASON: ");
            switch (code) {
                case UNKNOWN_MNEMONIC_ERROR:
                    printf("UNKNOWN MNEMONIC\n");
                    break;

                default:
                    printf("UNKNOWN ERROR\n");
                    break;
            }

            return code;
        }

        idx++;
    }

    fclose(file);

    FILE *output_file = fopen(output_path, "w");
    if (output_file == NULL) {
        printf("Error while writing to output file\n");
        return OUTPUT_ERROR;
    }

    fwrite(byte_buf, sizeof(uint8_t), BUF_SIZE, output_file);
    fclose(output_file);

    return 0;
}
