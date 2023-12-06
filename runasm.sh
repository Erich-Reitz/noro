#!/bin/bash
cd ~/devel/nim-noro
nasm -f elf64 -g asm/out.asm -o asm/out.o
gcc -c src/stlib/writestrnewline.c -o src/stlib/writestrnewline.o
gcc -o asm/out asm/out.o src/stlib/writestrnewline.o -nostartfiles -lc
