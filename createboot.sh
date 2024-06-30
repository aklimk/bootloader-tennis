nasm boot.asm
truncate -s 510 boot
echo -en "\x55\xAA" >> boot
