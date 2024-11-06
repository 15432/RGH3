msec_passed:
    push 0              ; save R0
    mov R0, #MSEC_REG
    mov A, @R0          ; previous saved ms value
    orl INT_CNTRL, #01h
    cjne A, SMC_MSECS, msec_differs
    sjmp msec_same
msec_differs:
    mov @R0, SMC_MSECS
    cjne A, #015h, msec_setc ; do not track the 15h -> 01h
    cjne @R0, #001h, msec_setc ; do not track the 15h -> 01h
    sjmp msec_same
msec_setc:
    setb C
msec_same:
    anl INT_CNTRL, #0FEh
    pop 0               ; restore R0
    ret
