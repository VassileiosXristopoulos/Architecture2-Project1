.data
A:  .word 0x4008000000000000

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

    ; Get the sign
    daddui R2, $zero, 63                ; the shift amount to get the sign
    dsrlv R2, R1, R2

    ; Compute mantissa mask
    ; Load the upper 16 bits with FFFF
    ; That includes the bits 15 to 31 but because MIPS does sign extension
    ; that means bit from 16 to 63 are also going to be all Fs
    lui R3, 0xFFFF
    ori R3, R3, 0xF000                  ; or-ing to add an extra to F
    dsrl R3, R3, 12                     ; and shifting to get a MASK of 52 Fs. That is our mantissa mask

    ; Get mantissa
    and R4, R1, R3
    daddui R8, $zero, 1
    daddui R5, $zero, 52                ; the shift amount to get the 1 in front of the mantissa
    dsllv R8, R8, R5                    ; shift 1 to the 53 bit position so we add that to our mantissa.
    or R4, R4, R8                       ; This is the explicit 1 added to the mantissa in IEEE-754 format

    ; Compute exponent
    ;daddi R5, R5, -1                    ; the shift amount to get the exponent to the lowest bits
    dsrlv R5, R1, R5                    ; shifting 52 bits to the right to get the exponent to the lowest bits
    andi R5, R5, 0x07FF                 ; and-ing to get only the exponent
    daddi R5, R5, -1023                 ; subtracting bias

    slt R7, R5, $zero                   ; check if exponent is negative
    
    ; NOTE(GeorgeLS): Here we have to add an instruction because branch evaluates
    ; the registers at ID stage so we have a RAW hazard
    
    bnez R7, __EXIT                     ; if it is the do something
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
    daddui R28, $zero, 52               ; we load 52 because this is the mantissa size and we need to subtract from it
    dsub R28, R28, R5                   ; subtract exponent from 52. Thats the amount we need to shift the mantissa to the right
    dsrlv R25, R4, R28
    j __PRINT_VALUE

__SHIFT_MANTISSA_LEFT:
    daddi R28, R5, -52                  ; compute the amount we need to shift the mantissa to the left
    dsllv R25, R4, R28

__PRINT_VALUE:
    sd R25, 0(R31)                      ; setting DATA
    sd R29, 0(R30)                      ; setting CONTROL

__EXIT:
    halt ; Exit program