# bootloader-tennis
A custom bootloader game selection screen and primitive tennis like game, written entirely on the 512 byte bios bootloader section.

# Building and Running Using Build Script
To both build and run the project in one pass, invoke the build script with the "--run" flag. You will need NASM and QEMU installed and in PATH:<br/>
`py build.py --run`

To only build the project but not run it, run the script with no arguments.
`py build.py`

To later run the program, invoke a bios emulator, with QEMU this would look like.:<br/>
`qemu-system-i386 -fda boot.bin`

# Building and Running Without Build Script.
Building without the python build script requires 3 steps, you will need NASM and utilties for truncating and appending binary data to files.
1. Assemble the boot.asm assembly file.
2. Turncate the file to 510 bytes.
3. Append the BIOS bootloader indicater bytes to the end of the file ("\x55\xAA").

On linux, this would look like:<br/>
`nasm boot.asm -o boot-raw.bin && truncate -s 510 boot.bin | echo -en "\x55\xAA" >> boot.bin`

To later run the built program, invoke a bios emulator, in QEMU this would look like:<br/>
`qemu-system-i386 -fda boot.bin`


