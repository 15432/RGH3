; TRINITY

; RAM vars
RAM_START   equ 0C0h

; SMC RAM vars
SMC_VM_ST     equ 07Ah ; start vector for the i2c processing
SMC_MSECS     equ 078h ; SMC memory cell containing milliseconds
SMC_I2C_STATE equ 0A7h ; SMC memory cell containing SMC i2c FSM state
SMC_ARG_E     equ 02Bh.7  ; SMC flag meaning argon (RF board) processing is enabled

; hardware pins
POSTBIT     equ 080h.7 ; GPU_RESET_DONE GPIO_P0_7
CPU_PLL     equ 0C0h.0 ; DBG_LED        GPIO_P3_0
CPU_RST     equ 080h.6 ; CPU_RESET      GPIO_P0_6

; SMC functions
startup_i2c         equ 027E1h
prepare_reset       equ 013D8h
reset_watchdog      equ 02480h
smc_dbg_space       equ 014BFh
smc_free_space      equ 02EE9h

; I2C VM pointers
VM_FAST_PTR         equ 0E7h
VM_SLOW_PTR         equ 0DFh

; glitch parameters
; ~61.9 ms
PLL_DELAY_0         equ 080h
PLL_DELAY_1         equ 0E2h
PLL_DELAY_2         equ 02h

; ~134.623 ms
GLI_PULSE_0         equ 09Ah
GLI_PULSE_1         equ 018h
GLI_PULSE_2         equ 05h