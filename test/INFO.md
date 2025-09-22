# Test files

This file contains information about the test files.
It is parsed by the `run.sh` script to select the correct parameters for `mops test` for each test file.

Use `test/run.sh` to execute all of the tests, or `test/run.sh <filter>` to run a specific test file.

## Mode

Tests can be run using different test modes.
The default is interpreter test mode. which does not support `fromCandid`.
Using the mode `wasi` supports `fromCandid`, but does not support `async` calls.

Specifically the following files use wasi test mode:

- rsa

## Slow tests

The following tests currently take very long (> 10 seconds) to run.
You can exclude those by running `test/run.sh --fast`.

- delegation
- ed25519
- jwt

## Disabled tests

Tests using both fromCandid and async calls are currently disabled:

- jwt
