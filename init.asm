#include <defines.asm>

org smc_dbg_space

start:
    mov R0,   #RAM_START
    mov @R0,  #000h

    mov 0E9h, #0FFh  ; init UART speed

end
