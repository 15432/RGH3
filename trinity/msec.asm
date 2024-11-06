#include <defines.asm>

MSEC_REG    equ RAM_START + 2 ; saved value of milliseconds
INT_CNTRL   equ 0BFh

org 0

start:

#include <..\msec_func.asm>

end
