CC       ?= gcc
CFLAGS   ?= -Wall -Wextra -pedantic -std=c99 -O2
NIM      ?= nim
NIMFLAGS ?= -d:release

SRC_DIR  := src
VM_SRCS  := $(SRC_DIR)/vm.c $(SRC_DIR)/main.c
VM_OBJS  := $(VM_SRCS:.c=.o)
VM_BIN   := atomvm
ASM_BIN  := atomasm
QL_BIN   := ql
QL_SRCS  := $(SRC_DIR)/ql.nim $(wildcard $(SRC_DIR)/ql/*.nim)

UNAME_S := $(shell uname -s)

ifneq (,$(filter $(UNAME_S),Linux Darwin))
    NIM_EXT :=
else
    NIM_EXT := .exe
endif

.PHONY: all vm asm qlc test lint clean

all: vm asm qlc

vm: $(VM_BIN)

$(VM_BIN): $(VM_OBJS)
	$(CC) $(CFLAGS) -o $@ $^

$(SRC_DIR)/%.o: $(SRC_DIR)/%.c $(SRC_DIR)/vm.h $(SRC_DIR)/opcodes.h
	$(CC) $(CFLAGS) -c -o $@ $<

asm: $(ASM_BIN)

$(ASM_BIN): $(SRC_DIR)/atomasm.nim
	$(NIM) c $(NIMFLAGS) --outDir:. --hints:off --verbosity:0 $<

qlc: $(QL_BIN)

$(QL_BIN): $(QL_SRCS)
	$(NIM) c $(NIMFLAGS) --outDir:. --hints:off --verbosity:0 $<

test: all
	./tests/run_tests.sh

lint: vm
	$(CC) $(CFLAGS) -Werror -c -o /dev/null $(SRC_DIR)/vm.c
	$(CC) $(CFLAGS) -Werror -c -o /dev/null $(SRC_DIR)/main.c

clean:
	rm -f $(VM_BIN) $(ASM_BIN) $(ASM_BIN)$(NIM_EXT)
	rm -f $(QL_BIN) $(QL_BIN)$(NIM_EXT)
	rm -f $(SRC_DIR)/*.o
	rm -rf nimcache
