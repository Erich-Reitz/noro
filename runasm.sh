#!/bin/bash
nasm -f elf64 -g asm/out.asm -o asm/out.o
gcc -c src/stlib/stdlib.c -o src/stlib/stdlib.o
gcc -o asm/out asm/out.o src/stlib/stdlib.o -nostartfiles -lc
