# Noro

CS 403 final project.

My aim for this project was to write a statically typed language that compiled to assembly. 

## TLDR

I wrote a compiler for a very small language. It supports

- decently complete typechecking and semantic analysis
- variable assignment. integers work completely, strings work as char* to string literals located in the data section
- addition, subtraction, multiplication over ints
- If statements with else blocks
- ==, and > over integers
- calling C functions to print integers and strings.
- functions, and early returns
- no: anything else (user defined types, arrays, operations on strings..). 


## Rest

### Language Features

- `Forbid` construct: forbids a variable from being used after statement

    ```
    pure function discountedPrice(int originalPrice, int discountRate, bool special) -> int {
        int discounted_price = originalPrice * discountRate; 
        forbid originalPrice; 

        if (special) {
            // error duing return statement of <discountedPrice>: use of forbidden: originalPrice
            return originalPrice - 5;

        } 
        
        return discounted_price; 
        
    }
    ```

#### Implemented
The semantic analysis phase includes
- Typechecking over builtin types and their operations (+, -, logical and/or, less than, assignment, etc.)
- Typechecking over functions: checking arity, ensuring variable type matches function return type, typechecking parameters, ensuring return statements match return type of function
- Detecting assignment to a variable previously declared `const`
- Detecting a variable declared with multiple types
- 
    ```
    src/impl/compiler: 
        sempass: start point for semantic analysis
        typechecker: contains logic for typechecking
        inferexpr: used to infer the types of expressions, helps with typechecking
        semtable: structure for holding info during this phase 
        semutils: helper functions
        semerror: error constructors
    ```
To generate assembly, I first recreate the parse tree in a lower form of an AST. Naming for the following sections was taken from the book, "Modern Compiler implementation in C", but the book was otherwise not very helpful.

- 
    ```
    src/impl/compiler: 
        ast: Ast
        translate: transforms parse tree to Ast
    ```

Then, I tranform the Ast into a list of frames, each containing a list of instructions. For the following program, that looks as follows.

- 
    ```
    function main() -> int {
        int one = 1; 
        int two = 2; 
        if (one == 1) {
            two = 3;
        } else {
            two = 4;
        }

        return one + two;
    }
    ```
- 
    ```
    frame: main
    (kind: ikMov, dst: v0, src: 1, src2: nil)
    (kind: ikMov, dst: v1, src: 2, src2: nil)
    (kind: ikMov, dst: t0, src: v0, src2: nil)
    (kind: ikMov, dst: t1, src: 1, src2: nil)
    (kind: ikIntEqual, dst: t2, src: t0, src2: t1)
    (kind: ikConditionalJump, dst: t2, src: l0, src2: l1)
    (kind: ikLabelCreate, dst: l0, src: nil, src2: nil)
    (kind: ikMov, dst: v1, src: 3, src2: nil)
    (kind: ikLabelJumpTo, dst: l2, src: nil, src2: nil)
    (kind: ikLabelCreate, dst: l1, src: nil, src2: nil)
    (kind: ikMov, dst: v1, src: 4, src2: nil)
    (kind: ikLabelCreate, dst: l2, src: nil, src2: nil)
    (kind: ikAdd, dst: t3, src: v0, src2: v1)
    (kind: ikMov, dst: ret, src: t3, src2: nil)
    ```
- 
    ```
    src/impl/compiler: 
        instructgen: start point, logic for generating instructions from Ast
        instruction: structure definitions, includes the various instructions implemented
        instructutils: helper functions
    ```

Note that this is unfortunately not SSA form. The file located at `src/impl/compiler/optimizer` attempts to reduce the instructions, but I didn't spend much time trying to reduce the use of temporaries. The following optimizations are performed.
- `reduceConstantOperations`: computes 2 + 2 at compile time
- `sourceOfSourceIsConst`: If move instruction (mov y x) exists and x was (mov x const), replace it with (mov y const). Only for temporaries
- `removeUnusedTemps`: Remove (for a subset of instruction kinds) instructions that list a temporary as their destination when the temporary is never used 

Finally, `src/impl/compiler/codegen` and `src/impl/compiler/asmgen` construct NASM x86 assembly for the instructions listed. The program is linked with C files so I can print strings and integers. This helps test control flow as well.

## Example Programs

All three are within test suite.

Compute fib(30).
```
// standard library functions
function writestrnewline(string any) -> int {}
function writestr(string any) -> int {}
function writeint(int any) -> int {}

function fibonacci(int n) -> int {
    if (n == 0) {
        return n;
    } 
    if (n == 1) {
        return n;
    } else {
        return fibonacci(n - 1) + fibonacci(n - 2);
    }
}

function printintnewline(int n) -> int {
    writeint(n);
    writestrnewline("");
    return 0;
}   

function printfibonacci(int n) -> int {
    int result = fibonacci(n);
    printintnewline(result);
    return 0; 
}

function main() -> int {
    return printfibonacci(30); 
}
```
Testing control flow
```
// standard library functions
function writestrnewline(string any) -> int {}
function writestr(string any) -> int {}
function writeint(int any) -> int {}

function main() -> int {
    int five = 5; 
    int ten = 10; 

    int sumOfFiveAndTen = five + ten;
    if (sumOfFiveAndTen == 20) {
        writestrnewline("never"); 
    } else {
        writestrnewline("always1"); 
        if (sumOfFiveAndTen == 15) {
            writestrnewline("always2"); 
            int one = 1; 
            int two = 2; 
            // mutating 10 in nested scope
            ten = 9; 
            if (one + two == 3) {
                writestrnewline("always3"); 
            } else {
                writestrnewline("never3"); 
            }
        } else {
            writestrnewline("never2"); 
        }
        writestrnewline("always4");
    }
    writestrnewline("always5");
    return ten;
}
```

Testing nested functions
```
pure function max(int n1, int n2) -> int {
    if (n1 > n2) {
        return n1;
    } else {
        return n2;
    }

}

pure function max6(int n1, int n2, int n3, int n4, int n5, int n6) -> int {
    return max(max(max(n1, n2), max(n3, n4)), max(n5, n6));
}
function main() -> int {
    return max6(101, 2, 3, 100, 5, 6);
}
```

### Generated Assembly

The quality of the assembly is poor, but I don't think it represents a flaw in my approach. Further work would take the instructions generated, place them in SSA form, and then perform a register allocation algorithm on them to remove the use of temporaries. I don't believe anything I did permits this, I just didn't have time to write another pass.

```
max2:
    push rbp
    mov rbp, rsp
                ; from the codegen modules perspective..
    sub rsp, 64 ;   every temporary variable is just a stack allocated regular variable
    mov qword [rbp - 8], rdi   ; Glue code to take the parameters and put them in their param0, param1 locations
    mov qword [rbp - 16], rsi
    mov rax, [rbp - 8] ; moving the parameters to temporaries. That is how instructions are generated for IntGe
    mov [rbp - 24], rax ; as the lhs and rhs of IntGe could be arbitrary.
    mov rax, [rbp - 16]
    mov [rbp - 32], rax
    mov rax, [rbp - 32] ; first actual instruction for IntGe
    cmp [rbp - 24], rax ; instruction sets a flag, no destination
    setg byte [rbp - 40] ; set a temporary to the result.
    cmp byte [rbp - 40], 0  ; branch on the result
    je .l1
    jmp .l0
.l0:

    mov rax, [rbp - 8] ; referencing param0
    jmp .end
    jmp .l2
.l1:

    mov rax, [rbp - 16] ; referencing param1
    jmp .end
.l2:

.end:
    leave
    ret
```

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

