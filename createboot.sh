nasm boot.asm -o boot-raw.bin -l listing.txt
cp boot-raw.bin boot.bin
truncate -s 510 boot.bin
echo -en "\x55\xAA" >> boot.bin
