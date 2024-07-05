from subprocess import call
import os

cwd = os.path.dirname(os.path.realpath(__file__))

call(r'nasm boot.asm -o uncompressed.bin', shell=True, cwd=cwd)
call(r'cp uncompressed.bin compressed.bin', shell=True, cwd=cwd)
call(r'cp compressed.bin boot.bin', shell=True, cwd=cwd)
call(r'truncate -s 510 boot.bin', shell=True, cwd=cwd)
call(r'echo -en "\x55\xAA" >> boot.bin', shell=True, cwd=cwd)
