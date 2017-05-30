# cross compiling on x86_64 host, assuming /opt/adapteva as default path

PGM="main"

e-gcc -Ofast -mfp-mode=int -mshort-calls -m1reg-r63 -T /opt/adapteva/esdk/bsps/current/internal.ldf src/e_${PGM}.c src/e_${PGM}.S -o bin/e_${PGM}.elf -le-lib
