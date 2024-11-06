..\c51asm.exe -fB ..\init.asm -o init.bin
..\c51asm.exe -fB ..\code.asm -o code.bin
python smc_patcher.py
python ..\rgh3_build.py
type nul >>image.ecc
..\nandpro.exe image.ecc: +W16 image.bin :1198010
pause
