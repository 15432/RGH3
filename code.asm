#include <defines.asm>

I2C_ST_REG  equ RAM_START ; flags for our i2c worker
RGH_ST_REG  equ RAM_START + 1 ; current RGH procedure step
MSEC_REG    equ RAM_START + 2 ; saved value of milliseconds
DELAY_REG   equ RAM_START + 3 ; delay countdown

; RGH + i2c flags
I2_BIT_NOW  equ 0E0h.0  ; current state of the i2c slowdown
I2_BIT_REQ  equ 0E0h.1  ; request of i2c slowdown
I2_BIT_WAI  equ 0E0h.2  ; request is in progress
I2_BIT_SAV  equ 0E0h.3  ; last executed request

RG_BIT_TIM  equ 0E0h.4  ; flag for timing alternation

; SMC hardware regs
INT_CNTRL   equ 0BFh

org smc_free_space

start:
    lcall   i2c_fsm
    lcall   rgh_fsm
return:
    ret

i2c_fsm:
    mov   R0, #SMC_I2C_STATE
    cjne  @R0, #0, return    ; i2c is busy, no reason to check anything
    mov   R0, #I2C_ST_REG
    mov   A, @R0
    jnb   I2_BIT_WAI, try_send_i2c

; waiting for completion done
    mov   C, I2_BIT_SAV      ; move saved request
    mov   I2_BIT_NOW, C      ; to the real state
    clr   I2_BIT_WAI         ; clear waiting for completion
    mov   @R0, A             ; update rgh i2c state
    ; fall to request processing

try_send_i2c:
    mov   C, I2_BIT_NOW      ; compare request bit and real state
    jc    check_if_1
    jnb   I2_BIT_REQ, return ; we are fast already, nothing to do
    sjmp  start_req
check_if_1:
    jb    I2_BIT_REQ, return ; we are slow already, nothing to do

start_req:
    mov   SMC_VM_ST, #VM_FAST_PTR  ; VM_POS = fast sequence
    jnb   I2_BIT_REQ, skip_slow
    mov   SMC_VM_ST, #VM_SLOW_PTR  ; VM_POS = slow sequence
skip_slow:
    lcall startup_i2c ; initiate the transfer
    jb    0D0h.5, return ; failed to execute the i2c command
i2c_success:
    mov   R0, #SMC_I2C_STATE ; set the i2c FSM into waiting state
    mov   @R0, #4       ; use the state 4 as the least problematic one
    mov   R0, #I2C_ST_REG
    mov   A, @R0
    setb  I2_BIT_WAI    ; set 'waiting for completion'
    mov   C, I2_BIT_REQ 
    mov   I2_BIT_SAV, C ; save the requested speed
    mov   @R0, A
    ret

; RGH FSM states
STATE_IDLE      equ 000h
STATE_WAIT_1C   equ 001h
STATE_POST_1C   equ 002h
STATE_WAIT_NAND equ 003h
STATE_WAIT_SLOW equ 004h
STATE_GLITCH    equ 005h
STATE_WAIT_SUCC equ 006h
STATE_TEST_SUCC equ 007h
STATE_WAIT_HW   equ 008h
STATE_TEST_HW   equ 009h
STATE_FINISH    equ 00Ah

#include <..\msec_func.asm>

rgh_fsm:
    mov    R0, #RGH_ST_REG
    mov    R1, #I2C_ST_REG
    mov    A, @R1
    jb     CPU_RST, check_state_0
    mov    @R0, #STATE_IDLE ; reset the glitch FSM when CPU is off
check_state_0:
    cjne   @R0, #STATE_IDLE, check_state_1
    clr    CPU_PLL          ; disable PLL slowdown
    clr    I2_BIT_REQ       ; disable I2C slowdown
    mov    @R1, A           ; update rgh i2c state
    jb     I2_BIT_NOW, __return  ; wait till I2C done
    jnb    CPU_RST, __return    ; don't setup anything when off
    mov    R1, #DELAY_REG
    mov    @R1, #255   ; 1C waiting delay in ms
    sjmp   go_next_step

check_state_1:
    cjne   @R0, #STATE_WAIT_1C, check_state_2
    sjmp   wait_for_smth
check_state_2:
    cjne   @R0, #STATE_POST_1C, check_state_3
    jb     POSTBIT, go_next_step ; just wait for the POST pin
__return:
    ret

check_state_3:
    cjne   @R0, #STATE_WAIT_NAND, check_state_4
    orl    INT_CNTRL, #01h ; disable interrupts
wait_post_1e:  ;~6.1ms
    jb     POSTBIT, wait_post_1e
wait_post_d01: ;~1.45ms
    jnb    POSTBIT, wait_post_d01  ; in case of bad POST signal
wait_post_d23: ;~20 us             ; we can accidentally cause
    jb     POSTBIT, wait_post_d23  ; watchdog SMC reboot here
wait_post_d45: ;~900 us
    jnb    POSTBIT, wait_post_d45
    ; here all NAND communication is done, so we can do HANA i2c
    setb   CPU_PLL ; use PLL slowdown to get more time for that
    anl    INT_CNTRL, #0FEh ; enable interrupts
    clr    SMC_ARG_E        ; disable argon processing
    setb   I2_BIT_REQ       ; enable I2C slowdown
    mov    @R1, A           ; update rgh i2c state
    mov    R1, #DELAY_REG
    mov    @R1, #25   ; hana clock switch waiting in ms
go_next_step:
    inc    @R0                  ; go next step
    mov    A, @R0               ; debug prints
    ljmp   put_uart

check_state_4:
    cjne   @R0, #STATE_WAIT_SLOW, check_state_5
wait_for_smth:
    lcall  msec_passed
    jnc    __return              ; react only when ms ticks
    mov    R1, #DELAY_REG
    dec    @R1
    mov    A, @R1
    jnz    __return             ; wait the specified amount
    sjmp   go_next_step         ; go next step otherwise

check_state_5:
    cjne   @R0, #STATE_GLITCH, check_state_6
    clr    CPU_PLL           ; remove PLL slowdown, i2c is done, not needed anymore
    orl    INT_CNTRL, #01h   ; disable interrupts
wait_post_d67:
    jb     POSTBIT, wait_post_d67
    mov     R2, #PLL_DELAY_0
    mov     R3, #PLL_DELAY_1
    mov     R4, #PLL_DELAY_2
    mov     R5, #GLI_PULSE_0
    mov     R6, #GLI_PULSE_1
    mov     R7, #GLI_PULSE_2

    mov     C, RG_BIT_TIM
    jc      skip_alternate
    mov     R5, #GLI_PULSE_0 + 1 ; alternate between timing and timing + 1 every new attempt
skip_alternate:
    cpl     RG_BIT_TIM  ; switch timing to alternate
    mov     @R1, A
wait_for_slowdown:
    djnz    R2, wait_for_slowdown
    djnz    R3, wait_for_slowdown
    lcall   reset_watchdog
    djnz    R4, wait_for_slowdown
    setb    CPU_PLL
wait_post_d89:
    jnb     POSTBIT, wait_post_d89
    ; here is the post DA happened, final route to the glitch!
    lcall   reset_watchdog ; we need really much time here
wait_for_reset:
    djnz    R5, wait_for_reset
    djnz    R6, wait_for_reset
    djnz    R7, wait_for_reset
    clr     CPU_RST   ; reset pulse
    setb    CPU_RST
    lcall   reset_watchdog
    clr     CPU_PLL
    anl     INT_CNTRL, #0FEh ; enable interrupts
    clr    I2_BIT_REQ        ; disable I2C slowdown
    mov    @R1, A            ; update rgh i2c state
    mov    R1, #DELAY_REG
    mov    @R1, #10 ; about 10 ms to check the glitch result
    sjmp   go_next_step

check_state_6:
    cjne   @R0, #STATE_WAIT_SUCC, check_state_7
    sjmp   wait_for_smth ; go wait

#ifndef SKIP_CBB_POST_CHECK
SKIP_CBB_POST_CHECK equ 0
#endif

#if SKIP_CBB_POST_CHECK

check_state_7:
    cjne   @R0, #STATE_TEST_SUCC, _return
    setb   SMC_ARG_E        ; enable argon processing
    jnb    POSTBIT, go_next_step
    mov    @R0, #STATE_FINISH  ; set halt step to avoid multiple resets
    ljmp   prepare_reset

#else

check_state_9:
    cjne   @R0, #STATE_TEST_HW, _return
    jb     POSTBIT, go_next_step
    sjmp   go_reset

check_state_7:
    cjne   @R0, #STATE_TEST_SUCC, check_state_8
    mov    R1, #DELAY_REG
    mov    @R1, #100 ; about 100 ms to check the hardware init result
    setb   SMC_ARG_E        ; enable argon processing
    jnb    POSTBIT, go_next_step
go_reset:
    mov    @R0, #STATE_FINISH  ; set halt step to avoid multiple resets
    ljmp   prepare_reset

check_state_8:
    cjne   @R0, #STATE_WAIT_HW, check_state_9
    sjmp   wait_for_smth ; go wait

#endif

put_uart:
    add    A, #030h
    mov    0E7h, A
    mov    A, #09h
loop_uart:
    djnz   0E0h, loop_uart
_return:
    ret

end
