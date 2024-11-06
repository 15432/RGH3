; ZEPHYR

; RAM vars
RAM_START   equ 07Dh

; SMC RAM vars
SMC_VM_ST     equ 078h ; start vector for the i2c processing
SMC_MSECS     equ 076h ; SMC memory cell containing milliseconds
SMC_I2C_STATE equ 0CDh ; SMC memory cell containing SMC i2c FSM state
SMC_ARG_E     equ 02Bh.1  ; SMC flag meaning argon (RF board) processing is enabled

; hardware pins
POSTBIT     equ 080h.7 ; GPU_RESET_DONE GPIO_P0_7
CPU_PLL     equ 0C0h.0 ; DBG_LED        GPIO_P3_0
CPU_RST     equ 080h.6 ; CPU_RESET      GPIO_P0_6

; SMC functions
startup_i2c         equ 02587h
prepare_reset       equ 0126Eh
reset_watchdog      equ 022AAh
smc_dbg_space       equ 01376h
smc_free_space      equ 02C5Fh

; I2C VM pointers
VM_SLOW_PTR         equ 0B5h
VM_FAST_PTR         equ VM_SLOW_PTR + 0Eh

; glitch parameters
; ~62.2 ms
PLL_DELAY_0         equ 001h    ; does not really matter
PLL_DELAY_1         equ 0CCh    ; 120 mhz - 0B0h ; 117 MHz - 090h ; 48 Mhz - 0E0h ; 96 MHz - 0C0h
PLL_DELAY_2         equ 004h    ; 120 mhz - 05h  ; 117 MHz - 05h  ; 48 MHz - 02h  ; 96 MHz - 04h

; ~27.247 ms TODO: refine the timing (02-A8-00, 02-A9-01, 02-A9-02)
GLI_PULSE_0         equ 001h    ; 96 MHz - 01h ? 
GLI_PULSE_1         equ 0A9h    ; 96 MHz - A9h
GLI_PULSE_2         equ 02h     ; 96 Mhz - 02h
