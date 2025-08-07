import os
import sys

if __name__ == "__main__":
    os.system("nasm boot.asm -o boot-raw.bin")

    with open ("boot-raw.bin", "rb") as file:
        data = file.read()
        print("data len", len(data))
        if len(data) > 510:
            data_formatted = data[:510]
        else:
            data_formatted = data + b"\x00" * (510 - len(data))
        data_formatted += b"\x55\xAA"
        print(data_formatted)

    with open("boot.bin", "wb") as file:
        file.write(data_formatted)

    if len(sys.argv) > 1 and sys.argv[1] == "--run":
        os.system("qemu-system-i386 -fda boot.bin")
