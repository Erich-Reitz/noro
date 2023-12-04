# Noro

CS 403 final project

## Development Environment

This project is written in the [Nim](https://nim-lang.org/) programming language and requires version 
2.0.0 or greater. To install Nim, visit: [Install Nim](https://nim-lang.org/install.html). Building the 
project requires `Nimble` which is bundled with Nim installation. To the build the binary, execute 
`nimble build` in the project directory.

### Commands
- format: `find src/ -name "*.nim" -exec nimpretty {} \;`
- build: `nimble build`
- test: `nimble test`

### Testing
The program used for testing can be viewed at `tests/test.nim`. The program will automatically execute each test case, invoking the lox program with a specific test file located at `tests/<testname>/<testname>.lox`. The expected output is 
in the same folder, at `tests/<testname>/<testname>.out`.

