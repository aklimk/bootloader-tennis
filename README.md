# bootloader-tennis
A custom bootloader game selection screen and primitive tennis like game, written entirely on the 512 byte bios bootloader section.

# Building
-Building the project requires NASM (The Netwide Assembler), or another equivelent assembler that can understand intel-like assembler syntax and NASM pre-processed equations.<br/>
-Building the project also requires a program which can turncate and append data to binary files.

To build the project:
1. Assemble the boot.asm assembly file.
2. Turncate the file to 510 bytes.
3. Append the BIOS bootloader indicater bytes to the end of the file ("\x55\xAA").

## Example
On linux, run:
`nasm boot.asm -o boot.bin && truncate -s 510 boot.bin && echo -en "\x55\xAA" >> boot.bin`

# Running
The program should be able to run on any emulator (or device) that supports a BIOS boot mode.

## Example
With QEMU, run:
`qemu-system-i386 -fda boot.bin`
