from subprocess import call
import os
import itertools

cwd = os.path.dirname(os.path.realpath(__file__))

call(r'nasm boot.asm -o uncompressed.bin', shell=True, cwd=cwd)

with open('uncompressed.bin', 'rb') as bfile:
    bdata = bfile.read()
    byte_list = [byte for byte in bdata]

    patterns = [{}]
    for byte in byte_list:
        if byte not in patterns[0]:
            patterns[0][byte] = 1
        else:
            patterns[0][byte] += 1
    patterns[0] = {k: v for k, v in sorted(patterns[0].items(), key=lambda item: item[1], reverse=True)}
    patterns[0] = {pattern: patterns[0][pattern] for pattern in patterns[0] if patterns[0][pattern] > 1}

    depth = 1
    while True:
        depth += 1
        patterns.append({})
        for i in range(len(byte_list)):
            pattern = tuple(byte_list[i:i+depth])
            if pattern not in patterns[-1]:
                patterns[-1][pattern] = 1
            else:
                patterns[-1][pattern] += 1
        patterns[-1] = {k: v for k, v in sorted(patterns[-1].items(), key=lambda item: item[1], reverse=True)}
        patterns[-1] = {pattern: patterns[-1][pattern] for pattern in patterns[-1] if patterns[-1][pattern] > 1}

        if not patterns[-1]:
            break
    

call(r'cp uncompressed.bin compressed.bin', shell=True, cwd=cwd)
call(r'cp compressed.bin boot.bin', shell=True, cwd=cwd)
call(r'truncate -s 510 boot.bin', shell=True, cwd=cwd)
call(r'echo -en "\x55\xAA" >> boot.bin', shell=True, cwd=cwd)
