# Test files

This file contains information about the test files.
It is parsed by the `run.sh` script to select the correct parameters for `mops test` for each test file.

Use `test/run.sh` to execute all of the tests, or `test/run.sh <filter>` to run a specific test file.

## Mode

Tests can be run using different test modes.
Currently not all modes support `fromCandid` or `async` calls, therefore some tests are executed using the interpreter, and some using wasi mode.

Specifically the following files use wasi test mode, all others use interpreter test mode:

- jwt
- http

## Slow tests

The following tests currently take very long (> 10 seconds) to run.
You can exclude those by running `test/run.sh --fast`.

- delegation
- ed25519
- jwt
- http

