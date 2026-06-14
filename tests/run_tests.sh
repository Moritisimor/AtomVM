#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VM_BIN="$ROOT_DIR/atomvm"
ASM_BIN="$ROOT_DIR/atomasm"
QL_BIN="$ROOT_DIR/ql"
TEMP_DIR=$(mktemp -d)
PASS=0
FAIL=0

cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); echo "  PASS"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

make_bc() { 
  local tmp="$TEMP_DIR/_raw.bc"
  printf "$2" > "$tmp"
  local len=$(stat -c%s "$tmp")
  local hi=$((len / 256))
  local lo=$((len % 256))
  printf "\\x$(printf '%02x' $hi)\\x$(printf '%02x' $lo)" > "$1"
  cat "$tmp" >> "$1"
}
vm_run() { "$VM_BIN" "$1" > /dev/null 2>&1; echo $?; }
vm_output() { "$VM_BIN" "$1" 2>&1; }

check_binaries() {
    echo "=== Build artifacts ==="
    [ -x "$VM_BIN" ] || { echo "VM binary missing"; exit 1; }
    [ -x "$ASM_BIN" ] || { echo "Assembler binary missing"; exit 1; }
    [ -x "$QL_BIN" ] || { echo "QuantumLang compiler missing"; exit 1; }
    echo "  OK"
    pass
}
check_binaries

echo ""
echo "=== Core (backward compatible) ==="
echo ""

echo "--- hello_world.asm ---"
"$ASM_BIN" "$ROOT_DIR/hello_world.asm" "$TEMP_DIR/hw.bc" 2>/dev/null || { fail "assembly"; echo "done"; }
output=$("$VM_BIN" "$TEMP_DIR/hw.bc" 2>&1); rc=$?
[ "$output" = "Hello World!" ] && [ $rc -eq 0 ] && pass || fail "expected 'Hello World!', got '$output' (exit $rc)"

echo "--- counter (infinite loop) ---"
"$ASM_BIN" "$ROOT_DIR/example.asm" "$TEMP_DIR/counter.bc" 2>/dev/null || { fail "assembly"; echo "done"; }
set +e; timeout 2 "$VM_BIN" "$TEMP_DIR/counter.bc" > /dev/null 2>&1; rc=$?; set -e
[ $rc -eq 124 ] && pass || fail "expected timeout (124), got $rc"

echo "--- STORE/LOAD ---"
make_bc "$TEMP_DIR/sl.bc" '\x01\x2a\x11\x00\x12\x00\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/sl.bc" 2>&1); rc=$?
[ "$output" = "42" ] && [ $rc -eq 0 ] && pass || fail "expected '42', got '$output'"

echo "--- DUP ---"
make_bc "$TEMP_DIR/dup.bc" '\x01\x07\x10\x03\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/dup.bc" 2>&1); rc=$?
[ "$output" = "14" ] && [ $rc -eq 0 ] && pass || fail "expected '14', got '$output'"

echo "--- DIV by zero ---"
make_bc "$TEMP_DIR/d0.bc" '\x01\x0a\x01\x00\x06\x00'
rc=$(vm_run "$TEMP_DIR/d0.bc")
[ $rc -eq 10 ] && pass || fail "expected exit 10, got $rc"

echo "--- stack underflow ---"
make_bc "$TEMP_DIR/uf.bc" '\x02\x00'
rc=$(vm_run "$TEMP_DIR/uf.bc")
[ $rc -eq 2 ] && pass || fail "expected exit 2, got $rc"

echo "--- JIE taken ---"
make_bc "$TEMP_DIR/jie1.bc" '\x01\x05\x01\x05\x09\x08\x01\x63\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jie1.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- JIE not taken ---"
make_bc "$TEMP_DIR/jie2.bc" '\x01\x05\x01\x03\x09\x08\x01\x63\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jie2.bc" 2>&1)
[ "$output" = "99" ] && pass || fail "expected '99', got '$output'"

echo "--- JIZ taken ---"
make_bc "$TEMP_DIR/jiz.bc" '\x01\x00\x0b\x06\x01\x63\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jiz.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- JNE taken ---"
make_bc "$TEMP_DIR/jne.bc" '\x01\x05\x01\x03\x0c\x08\x01\x63\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jne.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo ""
echo "=== Arithmetic extensions ==="
echo ""

echo "--- MOD ---"
make_bc "$TEMP_DIR/mod.bc" '\x01\x14\x01\x06\x13\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/mod.bc" 2>&1)
[ "$output" = "2" ] && pass || fail "expected '2', got '$output'"

echo "--- MOD by zero ---"
make_bc "$TEMP_DIR/mod0.bc" '\x01\x05\x01\x00\x13\x00'
rc=$(vm_run "$TEMP_DIR/mod0.bc")
[ $rc -eq 10 ] && pass || fail "expected exit 10, got $rc"

echo "--- INC ---"
make_bc "$TEMP_DIR/inc.bc" '\x01\x63\x14\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/inc.bc" 2>&1)
[ "$output" = "100" ] && pass || fail "expected '100', got '$output'"

echo "--- DEC ---"
make_bc "$TEMP_DIR/dec.bc" '\x01\x64\x15\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/dec.bc" 2>&1)
[ "$output" = "99" ] && pass || fail "expected '99', got '$output'"

echo "--- NEG ---"
make_bc "$TEMP_DIR/neg.bc" '\x01\x01\x16\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/neg.bc" 2>&1)
[ "$output" = "255" ] && pass || fail "expected '255', got '$output'"

echo "--- AND ---"
make_bc "$TEMP_DIR/and.bc" '\x01\x0f\x01\x03\x17\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/and.bc" 2>&1)
[ "$output" = "3" ] && pass || fail "expected '3', got '$output'"

echo "--- OR ---"
make_bc "$TEMP_DIR/or.bc" '\x01\x0f\x01\x03\x18\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/or.bc" 2>&1)
[ "$output" = "15" ] && pass || fail "expected '15', got '$output'"

echo "--- XOR ---"
make_bc "$TEMP_DIR/xor.bc" '\x01\xff\x01\x0f\x19\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/xor.bc" 2>&1)
[ "$output" = "240" ] && pass || fail "expected '240', got '$output'"

echo "--- NOT ---"
make_bc "$TEMP_DIR/not.bc" '\x01\xaa\x1a\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/not.bc" 2>&1)
[ "$output" = "85" ] && pass || fail "expected '85', got '$output'"

echo "--- SHL ---"
make_bc "$TEMP_DIR/shl.bc" '\x01\x01\x01\x03\x1b\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/shl.bc" 2>&1)
[ "$output" = "8" ] && pass || fail "expected '8', got '$output'"

echo "--- SHR ---"
make_bc "$TEMP_DIR/shr.bc" '\x01\x08\x01\x03\x1c\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/shr.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- MIN ---"
make_bc "$TEMP_DIR/min.bc" '\x01\x0a\x01\x03\x1d\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/min.bc" 2>&1)
[ "$output" = "3" ] && pass || fail "expected '3', got '$output'"

echo "--- MAX ---"
make_bc "$TEMP_DIR/max.bc" '\x01\x0a\x01\x03\x1e\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/max.bc" 2>&1)
[ "$output" = "10" ] && pass || fail "expected '10', got '$output'"

echo "--- CMP greater ---"
make_bc "$TEMP_DIR/cmp1.bc" '\x01\x05\x01\x0a\x1f\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/cmp1.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- CMP less ---"
make_bc "$TEMP_DIR/cmp2.bc" '\x01\x0a\x01\x05\x1f\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/cmp2.bc" 2>&1)
[ "$output" = "255" ] && pass || fail "expected '255', got '$output'"

echo "--- CMP equal ---"
make_bc "$TEMP_DIR/cmp3.bc" '\x01\x05\x01\x05\x1f\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/cmp3.bc" 2>&1)
[ "$output" = "0" ] && pass || fail "expected '0', got '$output'"

echo ""
echo "=== Stack manipulation ==="
echo ""

echo "--- SWAP ---"
make_bc "$TEMP_DIR/swap.bc" '\x01\x0a\x01\x14\x20\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/swap.bc" 2>&1)
[ "$output" = "10" ] && pass || fail "expected '10', got '$output'"

echo "--- OVER ---"
make_bc "$TEMP_DIR/over.bc" '\x01\x0a\x01\x14\x21\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/over.bc" 2>&1)
[ "$output" = "10" ] && pass || fail "expected '10', got '$output'"

echo "--- ROT ---"
make_bc "$TEMP_DIR/rot.bc" '\x01\x01\x01\x02\x01\x03\x22\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/rot.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- NIP ---"
make_bc "$TEMP_DIR/nip.bc" '\x01\x0a\x01\x14\x23\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/nip.bc" 2>&1)
[ "$output" = "20" ] && pass || fail "expected '20', got '$output'"

echo "--- TUCK ---"
make_bc "$TEMP_DIR/tuck.bc" '\x01\x0a\x01\x14\x24\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/tuck.bc" 2>&1)
[ "$output" = "20" ] && pass || fail "expected '20', got '$output'"

echo "--- DUP2 ---"
make_bc "$TEMP_DIR/dup2.bc" '\x01\x0a\x01\x14\x25\x0d\x02\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/dup2.bc" 2>&1)
[ "$output" = "2010" ] && pass || fail "expected '2010', got '$output'"

echo "--- DROP2 ---"
make_bc "$TEMP_DIR/drop2.bc" '\x01\x0a\x01\x14\x01\x1e\x26\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/drop2.bc" 2>&1)
[ "$output" = "10" ] && pass || fail "expected '10', got '$output'"

echo "--- DEPTH empty ---"
make_bc "$TEMP_DIR/dep0.bc" '\x28\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/dep0.bc" 2>&1)
[ "$output" = "0" ] && pass || fail "expected '0', got '$output'"

echo "--- DEPTH with values ---"
make_bc "$TEMP_DIR/dep2.bc" '\x01\x01\x01\x02\x28\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/dep2.bc" 2>&1)
[ "$output" = "2" ] && pass || fail "expected '2', got '$output'"

echo ""
echo "=== Memory operations ==="
echo ""

echo "--- FETCH ---"
make_bc "$TEMP_DIR/fetch.bc" '\x01\x2a\x11\x00\x01\x00\x30\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/fetch.bc" 2>&1)
[ "$output" = "42" ] && pass || fail "expected '42', got '$output'"

echo "--- STOREI ---"
make_bc "$TEMP_DIR/storei.bc" '\x01\x63\x01\x05\x31\x12\x05\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/storei.bc" 2>&1)
[ "$output" = "99" ] && pass || fail "expected '99', got '$output'"

echo "--- FETCH16/STOREI16 ---"
make_bc "$TEMP_DIR/fetch16.bc" '\x01\x41\x70\x01\x2c\x34\x70\x01\x2c\x33\x56\x00'
output=$("$VM_BIN" "$TEMP_DIR/fetch16.bc" 2>&1)
[ "$output" = "A" ] && pass || fail "expected 'A', got '$output'"

echo "--- PUTSN ---"
make_bc "$TEMP_DIR/putsn.bc" '\x01\x41\x70\x01\x2c\x34\x01\x42\x70\x01\x2d\x34\x01\x43\x70\x01\x2e\x34\x70\x01\x2c\x01\x03\x35\x00'
output=$("$VM_BIN" "$TEMP_DIR/putsn.bc" 2>&1)
[ "$output" = "ABC" ] && pass || fail "expected 'ABC', got '$output'"

echo ""
echo "=== Control flow ==="
echo ""

echo "--- CALL/RET ---"
make_bc "$TEMP_DIR/call.bc" '\x01\x01\x40\x05\x00\x01\x02\x0d\x41'
output=$("$VM_BIN" "$TEMP_DIR/call.bc" 2>&1); rc=$?
[ "$output" = "2" ] && [ $rc -eq 0 ] && pass || fail "expected '2', got '$output' (exit $rc)"

echo "--- EXECUTE ---"
make_bc "$TEMP_DIR/exec.bc" '\x01\x05\x42\x00\x00\x01\x63\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/exec.bc" 2>&1); rc=$?
[ "$output" = "99" ] && [ $rc -eq 0 ] && pass || fail "expected '99', got '$output' (exit $rc)"

echo "--- JGT taken ---"
make_bc "$TEMP_DIR/jgt1.bc" '\x01\x01\x43\x06\x01\x63\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jgt1.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- JGT not taken (negative) ---"
make_bc "$TEMP_DIR/jgt2.bc" '\x01\xff\x43\x06\x01\x63\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jgt2.bc" 2>&1)
[ "$output" = "99" ] && pass || fail "expected '99', got '$output'"

echo "--- JLT taken ---"
make_bc "$TEMP_DIR/jlt1.bc" '\x01\xff\x44\x06\x01\x63\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jlt1.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo "--- JEQ taken ---"
make_bc "$TEMP_DIR/jeq1.bc" '\x01\x00\x45\x05\x01\x63\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jeq1.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo ""
echo "=== I/O ==="
echo ""

echo "--- EMIT ---"
make_bc "$TEMP_DIR/emit.bc" '\x01\x41\x50\x00'
output=$("$VM_BIN" "$TEMP_DIR/emit.bc" 2>&1)
[ "$output" = "A" ] && pass || fail "expected 'A', got '$output'"

echo "--- CR ---"
make_bc "$TEMP_DIR/cr.bc" '\x51\x00'
output=$("$VM_BIN" "$TEMP_DIR/cr.bc" 2>&1)
[ "$output" = "" ] && pass || fail "expected empty, got '$output'"

echo "--- SPACE ---"
make_bc "$TEMP_DIR/space.bc" '\x52\x00'
output=$("$VM_BIN" "$TEMP_DIR/space.bc" 2>&1)
[ "$output" = " " ] && pass || fail "expected space, got '$output'"

echo ""
echo "=== System ==="
echo ""

echo "--- BYE ---"
make_bc "$TEMP_DIR/bye.bc" '\x01\x2a\x64'
rc=$(vm_run "$TEMP_DIR/bye.bc")
[ $rc -eq 42 ] && pass || fail "expected exit 42, got $rc"

echo "--- MSIZE ---"
make_bc "$TEMP_DIR/msize.bc" '\x62\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/msize.bc" 2>&1)
[ "$output" = "0" ] && pass || fail "expected '0', got '$output'"

echo "--- RDEPTH ---"
make_bc "$TEMP_DIR/rdep.bc" '\x61\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/rdep.bc" 2>&1)
[ "$output" = "0" ] && pass || fail "expected '0', got '$output'"

echo ""
echo "=== 16-bit extensions ==="
echo ""

echo "--- PUSH16 ---"
make_bc "$TEMP_DIR/p16.bc" '\x70\x01\x02\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/p16.bc" 2>&1)
[ "$output" = "2" ] && pass || fail "expected '2', got '$output'"

echo "--- JMP16 ---"
make_bc "$TEMP_DIR/jmp16.bc" '\x71\x00\x06\x01\x63\x00\x01\x01\x0d\x00'
output=$("$VM_BIN" "$TEMP_DIR/jmp16.bc" 2>&1)
[ "$output" = "1" ] && pass || fail "expected '1', got '$output'"

echo ""
echo "=== Assembler tests ==="
echo ""

asm_fail() {
    local asm="$TEMP_DIR/test_asm.asm"
    local bc="$TEMP_DIR/test_asm.bc"
    cat > "$asm"
    local actual="$TEMP_DIR/asm_out.txt"
    "$ASM_BIN" "$asm" "$bc" > "$actual" 2>&1 || true
    if grep -qi "$1" "$actual" 2>/dev/null; then
        pass
    else
        fail "expected to match '$1', got: $(cat "$actual")"
    fi
}

echo "--- no args ---"
"$ASM_BIN" > "$TEMP_DIR/asm_noargs.txt" 2>&1 || true
grep -q "Usage:" "$TEMP_DIR/asm_noargs.txt" && pass || fail "expected usage"

echo "--- bad input file ---"
"$ASM_BIN" "/nonexistent/file.asm" "$TEMP_DIR/out.bc" > "$TEMP_DIR/asm_bad.txt" 2>&1 || true
grep -qi "error" "$TEMP_DIR/asm_bad.txt" && pass || fail "expected error"

echo "--- unknown mnemonic ---"
asm_fail "unknown" << 'EOF'
push 1
foobar
halt
EOF

echo "--- undefined label ---"
asm_fail "undefined" << 'EOF'
jmp nowhere
halt
EOF

echo "--- duplicate label ---"
asm_fail "duplicate" << 'EOF'
label foo
label foo
halt
EOF

echo "--- value out of range ---"
asm_fail "byte\|255\|fit\|range" << 'EOF'
push 300
halt
EOF

echo "--- cli help/version/info ---"
"$VM_BIN" --help > "$TEMP_DIR/vm_help.txt" 2>&1 && grep -q "Options:" "$TEMP_DIR/vm_help.txt" && pass || fail "expected atomvm help"
"$ASM_BIN" --version > "$TEMP_DIR/asm_version.txt" 2>&1 && grep -q "AtomASM" "$TEMP_DIR/asm_version.txt" && pass || fail "expected atomasm version"
"$QL_BIN" --help > "$TEMP_DIR/ql_help.txt" 2>&1 && grep -q "ql run" "$TEMP_DIR/ql_help.txt" && pass || fail "expected ql help"

echo ""
echo "=== QuantumLang compiler ==="
echo ""

ql_check() {
    local name="$1"
    local source="$2"
    local expected="$3"
    local ql="$TEMP_DIR/$name.ql"
    local bc="$TEMP_DIR/$name.bc"
    printf "%s" "$source" > "$ql"
    "$QL_BIN" "$ql" "$bc" 2>"$TEMP_DIR/$name.err" || { fail "compiler failed: $(cat "$TEMP_DIR/$name.err")"; return; }
    output=$("$VM_BIN" "$bc" 2>&1)
    [ "$output" = "$expected" ] && pass || fail "expected '$expected', got '$output'"
}

ql_fail() {
    local name="$1"
    local source="$2"
    local expected="$3"
    local ql="$TEMP_DIR/$name.ql"
    local bc="$TEMP_DIR/$name.bc"
    printf "%s" "$source" > "$ql"
    if "$QL_BIN" "$ql" "$bc" >"$TEMP_DIR/$name.out" 2>"$TEMP_DIR/$name.err"; then
        fail "expected compiler failure"
        return
    fi
    grep -qi "$expected" "$TEMP_DIR/$name.err" && pass || fail "expected '$expected', got: $(cat "$TEMP_DIR/$name.err")"
}

echo "--- hello string ---"
ql_check "hello" 'fn main() { print("hello") }' "hello"

echo "--- println builtin ---"
ql_check "println" 'fn main() { println("hello") }' "hello"

echo "--- forward function call ---"
ql_check "forward" 'fn main() { print(add(5, 2)) } fn add(a, b) { a + b }' "7"

echo "--- min/max builtins ---"
ql_check "minmax" 'fn main() { print(max(min(9, 3), 7)) }' "7"

echo "--- loops and compound assignment ---"
ql_check "loops" 'fn main() { mut x = 0 for i in 0..6 { if i == 2 { continue } if i == 5 { break } x += i } print(x) }' "8"

echo "--- memory and bytes builtins ---"
ql_check "memory" 'fn main() { memoryWrite(300, 65) putc(memoryRead(300)) printBytes("BCDE", 2) }' "ABC"

echo "--- string builtins ---"
ql_check "strings" 'fn main() { println(len("abc")) print(strcmp("a", "b")) }' "3
255"

echo "--- const and import ---"
printf '%s' 'fn id(x) { x }' > "$TEMP_DIR/core.ql"
ql_check "const_import" 'import "core" const answer = 42 fn main() { assertEq(answer, 42) println(answer) }' "42"

echo "--- immutable assignment error ---"
ql_fail "immutable" 'fn main() { let x = 1 x = 2 }' "immutable"

echo "--- type mismatch error ---"
ql_fail "type_mismatch" 'fn main() { mut x = 1 x = "bad" }' "type mismatch"

echo "--- assert failure exit code ---"
printf '%s' 'fn main() { assert(0) }' > "$TEMP_DIR/assert_fail.ql"
"$QL_BIN" "$TEMP_DIR/assert_fail.ql" "$TEMP_DIR/assert_fail.bc" 2>"$TEMP_DIR/assert_fail.err" || { fail "compiler failed: $(cat "$TEMP_DIR/assert_fail.err")"; }
rc=$(vm_run "$TEMP_DIR/assert_fail.bc")
[ $rc -eq 1 ] && pass || fail "expected exit 1, got $rc"

echo "--- imports arrays structs heap ---"
printf '%s' 'fn triple(x) { x * 3 }' > "$TEMP_DIR/lib.ql"
ql_check "daily" 'import "lib"
type Point { x :: u8, y :: u8 }
fn show(s :: str) { println(s) }
fn main() {
  let nums = [4, 5, 6]
  println(len(nums))
  println(nums[1])
  let p = Point { x: 7, y: 9 }
  println(p.x)
  show("ok")
  println(triple(4))
  let mem = alloc(2)
  memoryWrite(mem, 65)
  putc(memoryRead(mem))
}' "3
5
7
ok
12
A"

echo "--- namespaced import call ---"
printf '%s' 'fn triple(x) { x * 3 }' > "$TEMP_DIR/math.ql"
ql_check "namespace" 'import "math" fn main() { println(math::triple(5)) }' "15"

echo "--- enum variants and case ---"
ql_check "enum_case" 'type Color = Red | Green | Blue fn main() { let c = Color::Green case c { | Red => { print(1) } | Green => { print(2) } | _ => { print(3) } } }' "2"

echo "--- literal string concat ---"
ql_check "str_concat" 'fn main() { println("hello, " + "world") }' "hello, world"

echo "--- array mutation ---"
ql_check "array_set" 'fn main() { let xs = [1, 2, 3] arraySet(xs, 1, 9) println(xs[1]) }' "9"

echo "--- ql run command ---"
printf '%s' 'fn main() { println("run ok") }' > "$TEMP_DIR/run_cmd.ql"
output=$("$QL_BIN" run "$TEMP_DIR/run_cmd.ql" --vm "$VM_BIN" --quiet 2>/dev/null)
[ "$output" = "run ok" ] && pass || fail "expected 'run ok', got '$output'"

echo "--- ql -o command ---"
printf '%s' 'fn main() { print(5) }' > "$TEMP_DIR/out_flag.ql"
"$QL_BIN" build "$TEMP_DIR/out_flag.ql" -o "$TEMP_DIR/out_flag_custom.bc" --quiet 2>"$TEMP_DIR/out_flag.err" || { fail "compiler failed: $(cat "$TEMP_DIR/out_flag.err")"; }
output=$("$VM_BIN" "$TEMP_DIR/out_flag_custom.bc" 2>&1)
[ "$output" = "5" ] && pass || fail "expected '5', got '$output'"

echo "--- ql check command ---"
"$QL_BIN" check "$TEMP_DIR/out_flag.ql" --color never >"$TEMP_DIR/check.out" 2>"$TEMP_DIR/check.err" && grep -q "OK" "$TEMP_DIR/check.err" && pass || fail "expected ql check OK"

echo "--- atomvm info command ---"
"$VM_BIN" --info "$TEMP_DIR/out_flag_custom.bc" > "$TEMP_DIR/info.txt" 2>&1
grep -q "AtomVM bytecode" "$TEMP_DIR/info.txt" && pass || fail "expected bytecode info"

echo "--- atomvm stats command ---"
"$VM_BIN" --stats --color never "$TEMP_DIR/out_flag_custom.bc" >"$TEMP_DIR/stats.out" 2>"$TEMP_DIR/stats.err"
grep -q "finished" "$TEMP_DIR/stats.err" && pass || fail "expected runtime stats"

echo ""
echo "=== Error handling ==="
echo ""

echo "--- no input file ---"
"$VM_BIN" > "$TEMP_DIR/noin.txt" 2>&1 || true
grep -q "Usage:" "$TEMP_DIR/noin.txt" && pass || fail "expected usage"

echo "--- non-existent file ---"
"$VM_BIN" "/nonexistent" > "$TEMP_DIR/nofile.txt" 2>&1 || true
grep -q "not found" "$TEMP_DIR/nofile.txt" && pass || fail "expected 'not found'"

echo "--- empty bytecode ---"
printf '' > "$TEMP_DIR/empty.bc"
"$VM_BIN" "$TEMP_DIR/empty.bc" > "$TEMP_DIR/empty_out.txt" 2>&1 || true
grep -q "empty" "$TEMP_DIR/empty_out.txt" && pass || fail "expected 'empty'"

echo "--- file too large ---"
python3 -c "import sys; sys.stdout.buffer.write(b'\x00' * 5000)" 2>/dev/null > "$TEMP_DIR/large.bc" || \
  dd if=/dev/zero bs=5000 count=1 of="$TEMP_DIR/large.bc" 2>/dev/null
"$VM_BIN" "$TEMP_DIR/large.bc" > "$TEMP_DIR/large_out.txt" 2>&1 || true
grep -qi "larger\|large" "$TEMP_DIR/large_out.txt" && pass || fail "expected 'larger'"

echo ""
echo "============================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================="

[ "$FAIL" -eq 0 ]
