.data
CONTROL: .word 0x10000
DATA:    .word 0x10008

MAXINT64: .word 0x7FFFFFFFFFFFFFFF
MININT64: .word 0x8000000000000000
MANTISSA_MASK: .word 0x000FFFFFFFFFFFFF
MANTISSA_BIT_53: .word 0x0010000000000000
TWOS_COMPLEMENT_MASK: .word 0xFFFFFFFFFFFFFFFF

A:  .word   0x4008000000000000 ; 3
    .word   0x7FEFFFFFFFFFFFFF ; out of int64 not in [-0.5 , 0.5]
    .word   0x7FF0000000000000 ; infinity
    .word   0xBFD3333333333333 ; -0.3
    .word   0xBFF4000000000000 ; -1.25
    .word   0x0000000000000000 ; question for the 1 Million. Which number is that?
		    
B:  .space 1200
C:  .space 1200

.text
MAIN:
    ; Setting I/O
    ld R30, CONTROL($zero)              ; loading the address of control
    ld R31, DATA($zero)                 ; loading the address of data
    daddui R29, $zero, 2                ; mode for integer output

    daddui R3, $zero, A

    ; Counters initialization
    xor R10, R10, R10                   ; This is our counter for (P)
    xor R11, R11, R11                   ; This is our counter for (N)
    xor R12, R12, R12                   ; This is our counter for (D)
    xor R13, R13, R13                   ; This is our counter for (T)
    xor R14, R14, R14                   ; This is our counter for (Z)
    xor R15, R15, R15                   ; This is our counter for (I)

    ld R8, MANTISSA_BIT_53($zero)       ; The explicit 53th bit for the mantissa

    daddi R19, $zero, 0x07FF            ; The mask for getting the exponent. Used elsewhere too

    ld R27, TWOS_COMPLEMENT_MASK($zero) ; Set the mask for computing 2s complement

    ld R22, MANTISSA_MASK($zero)        ; Set the mask for getting the mantissa

    xor R23, R23, R23                   ; This is our iterator 

    daddui R24, $zero, 52               ; Shift amount for getting the exponent. Also mantissa size

    daddui R9, $zero, 63                ; The shift amount to get the sign

    daddui R16, $zero, 6                ; The number of iterations

__LOOP:
    dsll R6, R23, 3                     ; Compute offset in memory for double word (64 bits)
    ld R1, A(R6)                        ; Load word

    daddui R23, R23, 1                  ; increase iterator

    dsll R25, R1, 1			            ; remove sign to check for zero input

    dsrlv R2, R1, R9                    ; Get the sign

    beqz  R25, __NUMBER_ZERO		    ; check if input number is zero

    ; This is just for testing cvt behaviour
    ;mtc1 R1, F0
    ;cvt.l.d F0, F0
    ;mfc1 R25, F0
    ;j __PRINT_VALUE

    ; Get exponent
    dsrlv R5, R1, R24                   ; shifting 52 bits to the right to get the exponent to the lowest bits
    and R5, R5, R19                     ; and-ing to get only the exponent

    and R4, R1, R22                     ; Get mantissa

__HANDLE_INFINITY:
    bne R5, R19, __COMPUTE_NUMBER		; check if exponent is all ones (infinity or NaN)
	bnez R4, __COMPUTE_NUMBER			; if exponent all zeros and mantissa != 0 then continue
    daddi R15, R15, 1					; else increase counter for infinity numbers
    j __CHECK_SIGN_FOR_INFINITY         ; and check sign to load the appropriate number
  
__COMPUTE_NUMBER:
    daddi R5, R5, -1023                 ; subtract bias
    
    slt R7, R5, $zero                   ; check if exponent is negative
    
    ; zeroing out R25 which is our result register.
    ; if the branch below is taken then the result will be 0.
    ; also we put this instruction so as not to have RAW hazard
    xor R25, R25, R25
    
    bnez R7, __MANIP_LESS_1             ; if exponent negative check if |number| < 0.5 and print  

    slti R7, R5, 63                     ; else check if exponent is less or equal to 62

	or R4, R4, R8                       ; This is the explicit 1 added to the mantissa in IEEE-754 format
    
    bnez R7, __COMPUTE_INTEGER          ; if it is then go to compute the integer

__CHECK_SIGN_FOR_INFINITY:
    beqz R2, __LOAD_MAXINT              ; else check if sign is zero and if it is load MAXINT
    
__LOAD_MININT:
    ld R25, MININT64($zero)             ; else load MININT
    daddui R13, R13, 1                  ; increase (T) counter
    j __PRINT_VALUE

__LOAD_MAXINT:
    ld R25, MAXINT64($zero)
    daddui R13, R13, 1                  ; increase (T) counter 
    j __PRINT_VALUE

__NUMBER_ZERO:
   daddi R14, R14, 1			        ; increase (Z) counter
   j __PRINT_VALUE

__COMPUTE_INTEGER:
    slti R26, R5, 53                     ; check if exponent is less or equal to 52
    daddui R13, R13, 1                   ; increase (T) counter
    beqz R26, __SHIFT_MANTISSA_LEFT      ; if not then we shift the mantissa to the left

__SHIFT_MANTISSA_RIGHT:
    dsub R28, R24, R5                   ; subtract exponent from 52. Thats the amount we need to shift the mantissa to the right
    dsrlv R25, R4, R28
    j __APPLY_SIGN

__SHIFT_MANTISSA_LEFT:
    daddi R28, R5, -52                  ; compute the amount we need to shift the mantissa to the left
    dsllv R25, R4, R28

__APPLY_SIGN:
    beqz R2, __INCREASE_P
    daddu R11, R11, R2                  ; increase (N) counter if sign is 1
    xor R25, R25, R27                   ; else xor with all ones (that is equavalent to not)
    daddi R25, R25, 1                   ; and add 1 to the result
	j __PRINT_VALUE

__INCREASE_P:
    daddui R10, R10, 1                  ; increase (P) counter is sign is 0 
    j __PRINT_VALUE

__MANIP_LESS_1:
    slti R21, R5, -1 		            ; check if exp < -1 -- if exp >= -1 then number*2>=1 --> |number| > 0,5
    daddu R12, R12, R21		            ; if so then increase (D) counter
    xori R21, R21, 1                    ; find the complement of R21
    daddu R13, R13, R21                 ; increase (T) counter

__PRINT_VALUE:
    sd R25, 0(R31)                      ; setting CONTROL
    sd R29, 0(R30)                      ; setting CONTROL

    bne R23, R16, __LOOP

    sd R10, 0(R31)
    sd R29, 0(R30)
    sd R11, 0(R31)
    sd R29, 0(R30)
    sd R12, 0(R31)
    sd R29, 0(R30)
    sd R13, 0(R31)
    sd R29, 0(R30)
    sd R14, 0(R31)
    sd R29, 0(R30)
    sd R15, 0(R31)
    sd R29, 0(R30)
    
__EXIT:
    halt ; Exit program