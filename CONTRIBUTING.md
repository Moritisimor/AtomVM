# Contributing to AtomVM

Thanks for your interest in contributing! The project welcomes any help — bug fixes, new opcodes, documentation, tests, or cleanup.

## Getting Started

1. Fork the repository.
2. Run `make all` to build the VM and assembler.
3. Run `make test` to verify everything works.
4. Make your changes.
5. Run `make test` again.
6. Open a pull request.

## Code Style

- **C**: Follow the existing style. Use `make lint` to check for warnings.
- **Nim**: Keep consistent with the existing formatting.
- All source files should end with a newline.

## Adding an Opcode

1. Add the opcode to `src/opcodes.h` (in the `opcode` enum).
2. Implement the handler in `src/vm.c` (inside the `switch` in `vm_run`).
3. Add the mnemonic to `src/atomasm.nim` (inside `tokensToByteCode`).
4. Add a test case in `tests/run_tests.sh`.
5. Update the opcode reference in `README.md`.

## Testing

Run the test suite with:

```bash
make test
```

All tests must pass before a pull request is merged. If you add a new feature, add a corresponding test.

## Pull Request Checklist

- [ ] `make all` builds without errors or warnings
- [ ] `make test` passes
- [ ] New features include tests
- [ ] Branch is up to date with main
