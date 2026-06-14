#ifndef OPCODES_H
#define OPCODES_H

/* Opcodes
 * Encoding: opcode byte, followed by 0, 1, or 2 operand bytes.
 * All existing opcodes (0x00-0x12) are backward compatible.
 */

typedef enum {
    /* Core (backward compatible) */
    HALT    = 0x00,  /* ()  Stop execution */
    PUSH    = 0x01,  /* ( -- val)  Push 1-byte immediate */
    POP     = 0x02,  /* (val -- )  Pop and discard */
    ADD     = 0x03,  /* (a b -- sum)  b + a */
    SUB     = 0x04,  /* (a b -- diff)  b - a */
    MUL     = 0x05,  /* (a b -- prod)  b * a */
    DIV     = 0x06,  /* (a b -- quot)  b / a */
    JMP     = 0x07,  /* ( -- )  Jump to 1-byte address */
    JIG     = 0x08,  /* (a b -- )  Jump if b > a */
    JIE     = 0x09,  /* (a b -- )  Jump if a == b */
    JIS     = 0x0A,  /* (a b -- )  Jump if b < a */
    JIZ     = 0x0B,  /* (a -- )  Jump if a == 0 */
    JNE     = 0x0C,  /* (a b -- )  Jump if a != b */
    PUTN    = 0x0D,  /* (val -- val)  Print top as number (peek) */
    PUTC    = 0x0E,  /* (val -- val)  Print top as char (peek) */
    JNZ     = 0x0F,  /* (a -- )  Jump if a != 0 */
    DUP     = 0x10,  /* (a -- a a)  Duplicate top */
    STORE   = 0x11,  /* (val -- )  Pop to memory[addr] */
    LOAD    = 0x12,  /* ( -- val)  Push memory[addr] */

    /* Arithmetic extensions */
    MOD     = 0x13,  /* (a b -- rem)  b % a */
    INC     = 0x14,  /* (a -- a+1)  Increment top */
    DEC     = 0x15,  /* (a -- a-1)  Decrement top */
    NEG     = 0x16,  /* (a -- -a)  Two's complement negate */
    AND     = 0x17,  /* (a b -- a&b)  Bitwise AND */
    OR      = 0x18,  /* (a b -- a|b)  Bitwise OR */
    XOR     = 0x19,  /* (a b -- a^b)  Bitwise XOR */
    NOT     = 0x1A,  /* (a -- ~a)  Bitwise NOT */
    SHL     = 0x1B,  /* (a b -- b<<a)  Shift b left by a */
    SHR     = 0x1C,  /* (a b -- b>>a)  Shift b right by a */
    MIN     = 0x1D,  /* (a b -- min(a,b))  Minimum */
    MAX     = 0x1E,  /* (a b -- max(a,b))  Maximum */
    CMP     = 0x1F,  /* (a b -- -1|0|1)  Compare: -1 if b<a, 0 if b==a, 1 if b>a */

    /* Stack manipulation */
    SWAP    = 0x20,  /* (a b -- b a)  Swap top two */
    OVER    = 0x21,  /* (a b -- a b a)  Copy second to top */
    ROT     = 0x22,  /* (a b c -- b c a)  Rotate top three */
    NIP     = 0x23,  /* (a b -- b)  Drop second */
    TUCK    = 0x24,  /* (a b -- b a b)  Copy top under second */
    DUP2    = 0x25,  /* (a b -- a b a b)  Duplicate top pair */
    DROP2   = 0x26,  /* (a b -- )  Drop top pair */
    SWAP2   = 0x27,  /* (a b c d -- c d a b)  Swap top two pairs */
    DEPTH   = 0x28,  /* ( -- depth)  Push data stack depth */

    /* Memory operations */
    FETCH   = 0x30,  /* (addr -- val)  Push memory[addr] */
    STOREI  = 0x31,  /* (val addr -- )  Pop value to memory[addr] */
    FILL    = 0x32,  /* (val -- )  Fill n bytes with val from addr (2 imm: addr n) */
    FETCH16 = 0x33,  /* (addr_hi addr_lo -- val)  Push memory[addr] */
    STOREI16 = 0x34, /* (val addr_hi addr_lo -- )  Store byte to memory[addr] */
    PUTSN   = 0x35,  /* (addr_hi addr_lo len -- )  Print len bytes from memory[addr] */
    STRCMP  = 0x36,  /* (a_hi a_lo b_hi b_lo -- cmp)  Compare null-terminated strings */
    ALLOC   = 0x37,  /* (size -- addr_hi addr_lo)  Allocate bytes from VM heap */
    AGET    = 0x38,  /* (addr_hi addr_lo index -- val)  Read array byte at index */
    ALEN    = 0x39,  /* (addr_hi addr_lo -- len)  Read array length byte */
    LOADREL = 0x3A,  /* (addr_hi addr_lo offset -- val)  Read byte at addr + offset */
    ASET    = 0x3B,  /* (addr_hi addr_lo index val -- )  Write array byte at index */

    /* Control flow */
    CALL    = 0x40,  /* ( -- )  Call subroutine at 1-byte address */
    RET     = 0x41,  /* ( -- )  Return from subroutine */
    EXECUTE = 0x42,  /* (addr -- )  Jump to address on stack */
    JGT     = 0x43,  /* (a -- )  Jump if a > 0 (signed) */
    JLT     = 0x44,  /* (a -- )  Jump if a < 0 (signed) */
    JEQ     = 0x45,  /* (a -- )  Jump if a == 0 */
    LOOP    = 0x46,  /* ( -- )  Decrement loop counter, jump if not zero (1-byte imm addr) */

    /* I/O */
    EMIT    = 0x50,  /* (val -- val)  Alias for PUTC */
    CR      = 0x51,  /* ( -- )  Print newline */
    SPACE   = 0x52,  /* ( -- )  Print space */
    KEY     = 0x53,  /* ( -- char)  Read one byte from stdin */
    PUTS    = 0x54,  /* (addr hi lo -- )  Print null-terminated string from memory[addr] */
    STRLEN  = 0x55,  /* (addr hi lo -- len)  Push length of null-terminated string */
    PUTC_POP = 0x56, /* (val -- )  Pop and print as char */
    PUTN_POP = 0x57, /* (val -- )  Pop and print as number */

    /* System */
    DDEPTH  = 0x60,  /* ( -- depth)  Push data stack depth (alias for DEPTH) */
    RDEPTH  = 0x61,  /* ( -- depth)  Push return stack depth */
    MSIZE   = 0x62,  /* ( -- size)  Push memory size */
    STATE   = 0x63,  /* ( -- flags)  Push VM state flags */
    BYE     = 0x64,  /* (code -- )  Exit with code from stack */

    /* 16-bit extensions */
    PUSH16  = 0x70,  /* ( -- val)  Push 16-bit immediate (2 bytes, big-endian) */
    JMP16   = 0x71,  /* ( -- )  Jump to 16-bit address (2 bytes, big-endian) */
    CALL16  = 0x72,  /* ( -- )  Call 16-bit address (2 bytes, big-endian) */
} opcode;

/* Error codes */
typedef enum {
    VM_OK                  = 0,
    STACK_OVERFLOW         = 1,
    STACK_UNDERFLOW        = 2,
    FILE_TOO_LARGE         = 3,
    FILE_EMPTY             = 4,
    NO_INPUT_FILE          = 5,
    FILE_NOT_FOUND         = 6,
    UNKNOWN_OPCODE         = 7,
    PC_OUT_OF_BOUNDS       = 8,
    JUMP_OUT_OF_BOUNDS     = 9,
    DIVISION_BY_ZERO       = 10,
    FILE_READ_ERR          = 11,
    RETURN_STACK_OVERFLOW  = 12,
    RETURN_STACK_UNDERFLOW = 13,
} vm_error;

#endif
