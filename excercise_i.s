.data
A:  .word 0x3FEFFFFFFFFFFFFF
    .word 0x3FE8000000000000
    .word 0xBFFC000000000000
    .word 0x4008000000000000

CONTROL: .word 0x10000
DATA: .word 0x10008

MAXINT64: .word 0x7FFFFFFFFFFFFFFF
MININT64: .word 0x8000000000000000

.text
MAIN:
    ; Setting I/O
    ld R30, CONTROL($zero)              ; loading the address of control
    ld R31, DATA($zero)                 ; loading the address of data
    daddui R29, $zero, 2                ; mode for integer output

    ld R1, A($zero)                     ; Load the address of A. This is not going to be needed in the final code

    ; This is just for testing cvt behaviour
    ;mtc1 R1, F0
    ;cvt.l.d F0, F0
    ;mfc1 R25, F0
    ;j __PRINT_VALUE

    ; Set the mask for computing 2s complement
    lui R27, 0xFFFF
    ori R27, R27, 0xFFFF

    ; Get the sign
    daddui R2, $zero, 63                ; the shift amount to get the sign
    dsrlv R2, R1, R2

    ; Get mantissa
    dsll R4, R1, 12                     ; shifting 12 bits to the left to clear these bits
    dsrl R4, R4, 12                     ; shifting back. now we have our mantissa

    daddui R8, $zero, 1
    daddui R5, $zero, 52                ; the shift amount to get the 1 in front of the mantissa
    dsllv R8, R8, R5                    ; shift 1 to the 53 bit position so we add that to our mantissa.
    or R4, R4, R8                       ; This is the explicit 1 added to the mantissa in IEEE-754 format

    ; Compute exponent
    dsrlv R5, R1, R5                    ; shifting 52 bits to the right to get the exponent to the lowest bits
    andi R5, R5, 0x07FF                 ; and-ing to get only the exponent
    daddi R5, R5, -1023                 ; subtracting bias

    slt R7, R5, $zero                   ; check if exponent is negative
    
    ; zeroing out R25 which is our result register.
    ; if the branch below is taken then the result will be 0.
    ; also we put this instruction so as not to have RAW hazard
    xor R25, R25, R25
    
    bnez R7, __PRINT_VALUE              ; if it is just print the result which is 0

    slti R7, R5, 62                     ; else check is exponent is less or equal to 62

    ; RAW hazard

    bnez R7, __COMPUTE_INTEGER          ; if it is then go to compute the integer
    beqz R2, __LOAD_MAXINT              ; else check if sign is zero and if it is load MAXINT
    ld R25, MININT64($zero)             ; else load MININT
    j __PRINT_VALUE

__LOAD_MAXINT:
    ld R25, MAXINT64($zero)
    j __PRINT_VALUE

__COMPUTE_INTEGER:
    slti R7, R5, 52                     ; check if exponent is less or equal to 52
    
    ; RAW hazard
    
    beqz R7, __SHIFT_MANTISSA_LEFT      ; if not then we shift the mantissa to the left

__SHIFT_MANTISSA_RIGHT:
    daddui R28, $zero, 52               ; we load 52 because this is the mantissa size and we need to subtract from it
    dsub R28, R28, R5                   ; subtract exponent from 52. Thats the amount we need to shift the mantissa to the right
    dsrlv R25, R4, R28
    j __APPLY_SIGN

__SHIFT_MANTISSA_LEFT:
    daddi R28, R5, -52                  ; compute the amount we need to shift the mantissa to the left
    dsllv R25, R4, R28

__APPLY_SIGN:
    beqz R2, __PRINT_VALUE              ; if sign is zero the just print the value
    xor R25, R25, R27                   ; else xor with all ones (that is equavalent to not)
    daddi R25, R25, 1                   ; and add 1 to the result

__PRINT_VALUE:
    sd R25, 0(R31)                      ; setting DATA
    sd R29, 0(R30)                      ; setting CONTROL

__EXIT:
    halt ; Exit program