; FALCON

; RAM vars
RAM_START   equ 0B9h

; SMC RAM vars
SMC_VM_ST     equ 078h ; start vector for the i2c processing
SMC_MSECS     equ 076h ; SMC memory cell containing milliseconds
SMC_I2C_STATE equ 0A5h ; SMC memory cell containing SMC i2c FSM state
SMC_ARG_E     equ 02Bh.3  ; SMC flag meaning argon (RF board) processing is enabled

; hardware pins
POSTBIT     equ 080h.7 ; GPU_RESET_DONE GPIO_P0_7
CPU_PLL     equ 0C0h.0 ; DBG_LED        GPIO_P3_0
CPU_RST     equ 080h.6 ; CPU_RESET      GPIO_P0_6

; SMC functions
startup_i2c         equ 0261Fh
prepare_reset       equ 012BAh
reset_watchdog      equ 02334h
smc_dbg_space       equ 013C2h
smc_free_space      equ 02D03h

; I2C VM pointers
VM_FAST_PTR         equ 0CFh
VM_SLOW_PTR         equ 0C1h

; glitch parameters
; ~61.5 ms
PLL_DELAY_0         equ 001h    ; does not really matter
PLL_DELAY_1         equ 0C0h    ; 120 mhz - 0B0h ; 117 MHz - 090h ; 48 Mhz - 0E0h ; 96 MHz - 0C0h
PLL_DELAY_2         equ 004h    ; 120 mhz - 05h  ; 117 MHz - 05h  ; 48 MHz - 02h  ; 96 MHz - 04h

; ~26.924 ms
GLI_PULSE_0         equ 004h    ; 120mhz - C8   ; 117mhz - B0   ; 48 MHz - 32h  ; 96 MHz - 04h
GLI_PULSE_1         equ 0A4h    ; 120mhz - 0C   ; 117mhz - FFh  ; 48 MHz - D2h  ; 96 MHz - A4h
GLI_PULSE_2         equ 02h     ; 120mhz - 03   ; 117mhz - 02h  ; 48 MHz - 01h  ; 96 Mhz - 02h
