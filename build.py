import os
import sys

if __name__ == "__main__":
    os.system("nasm boot.asm -o boot-raw.bin")

    with open ("boot-raw.bin", "rb") as file:
        data = file.read()
        data_formatted = data[:510] + b"\x55\xAA"

    with open("boot.bin", "wb") as file:
        file.write(data_formatted)

    if sys.argv > 1 and sys.argv[1] == "--run":
        os.system("qemu-system-i386 -fda boot.bin")