;*******************************************************************************
;   Once I  have understood how timer0 works, it is easier to grasp the
;   timer2. To calculate its overflow time, use the following formula:
;
;   overflow = machine cycle x PR2 x prescaler x postscaler
;   
;       Prescalers: 1:1, 1:4, 1:16 (increment by one every x machine cycles)
;   
;   It is not possible to increment timer2 by an external event (what is possible
;   in the case tmr0). 
;
;   Its postscaler is an overflow counter: once it is overflowed, wait a bit
;   more and go on imcrementing it accordig to the preset ratio (1:1 to 1:16)
;   
;    PR2 is used to compare the tmr2 counting with its preset value.
;   Clk freq = 4 Mhz, for pic = 1 Mhz, time = 1 us
;				    bit6    bit5     bit4      bit3
;   I have to set T2CON register (TOUTPS3, TOUTPS2, TOUTPS1, TOUTPS0,
;     are used for postscaler settings {0 0 0 0 = 1:1, 0001 = 1:2 ... 1111 = 1:16}, 
;    TMR2ON - bit2, T2CKPS1/T2CKPS0 - bit1, bit0 for prescaler settings
;     {0:0, 0:1, 1:1 or 1:0} )
;
;   In PIE1 register I have to enable its bit1 (TMR2IE) to enable tmr1 interrpution
;    and in PIR1, its bit1 and the TMR2IF which has be cleared when it is set
; 
; ====== PWM ========================================================================
;       Period     = (PR2 + 1) * machine_cycle * prescaler
;                      256     *   1e-6        *  16       = 4.096 ms
; (for HS = 16MHz)	       *   4e-6                    = 16.384 ms
; 
;     Frequency = 1 / 0.00496  ->  244.14 Hz
;     Frequency = 1 / 0.016384 ->  61.035 Hz 
;*******************************************************************************
#include "p16f628a.inc"

; CONFIG
; __config 0xFF19
 __CONFIG _FOSC_INTOSCCLK & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF
 
#define BANK0	BCF STATUS,RP0
#define BANK1	BSF STATUS,RP0

#define BTN1	PORTB,RB0
#define BTN2	PORTB,RB1
 
; TODO PLACE VARIABLE DEFINITIONS GO HERE
CBLOCK	    H'20'
    OLD_STATUS
    OLD_W
ENDC
;*******************************************************************************
; Reset Vector
;*******************************************************************************

RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    START                   ; go to beginning of program

;*******************************************************************************

;*******************************************************************************

; TODO INSERT ISR HERE
	ORG	    H'0004'
        GOTO    ISR
;*******************************************************************************
; MAIN PROGRAM
;*******************************************************************************

MAIN_PROG CODE                      ; let linker place main program

START

    BANK1
    MOVLW	H'56'		     ; copy 0b01010110 into W register
    MOVWF	OPTION_REG	     ;
    MOVLW	H'F7'		     ; load work with  1111 0111
    MOVWF	TRISB                ; RB3 as output, other pins - inputs, CCP1
    MOVLW	H'FF'		     ; load work reg with D'255'
    MOVWF	PR2		     ; equals 255
    
    BANK0
    MOVLW	H'07'		     ; copy 0000 0111 into W reg
    MOVWF	CMCON		     ; disable comparators
    MOVLW	H'E0'		     ; copy 1110 000b into W reg
    MOVWF	INTCON		     ; enable tmr0 interrupt
    MOVLW	H'06'		     ; copy 0110 into W reg
    MOVWF	T2CON		     ; enable tmr2 with prescaler 1:16
    CLRF	CCPR1L		     ; rest CCPR1L (inital duty cycle = 0%, 128 for 50%)
    MOVLW	H'0C'		     ; copy 0000 1100b into W reg for pwm mode
    MOVWF	CCP1CON		     ; enable pwm mode, compare/capture pwm

    GOTO	$
; -----------------------------------------------------------------------------
ISR
	; SAVE CONTEXT
	MOVWF	    OLD_W	    ; save context in W register
	SWAPF	    STATUS,W	    ; set STATUS to W
	BANK0			    ; select bank 0 (default for reset)
	MOVWF	    OLD_STATUS	    ; save STATUS

;------------------------------------------------------------------------------
	BTFSS	    INTCON, T0IF    ; Has timer 2 overflowed?
	GOTO	    EXIT_ISR	    ; NO, jump to ISR end
	BCF	    INTCON, T0IF    ; Yes, clear flag by software
	MOVLW	    D'108'
	MOVWF	    TMR0	    ; Reset timer0
	BTFSS	    BTN1	    ; has button 1 been pressed?
	GOTO	    INC_PWM	    ; Yes, increment PWM
	BTFSS	    BTN2	    ; No, has button 2 been pressed?
	GOTO	    DEC_PWM	    ; Yes, decrement PWM
	GOTO	    EXIT_ISR	    ; No, exit interrupt service routine

INC_PWM
	MOVLW	    D'255'
	XORWF	    CCPR1L, W	    ; W = W xor CCPR1L (reg for PWM, capture/compare mode)
	BTFSC	    STATUS, Z	    ; Is CCPR1L = 255?
	GOTO	    EXIT_ISR	    ; Yes, exit ISR
	INCF	    CCPR1L, F	    ; No, increment PWM
	GOTO	    EXIT_ISR
	
DEC_PWM
	MOVLW	    D'0'
	XORWF	    CCPR1L, W	    ; W = W xor CCPR1L (reg for PWM, capture/compare mode)
	BTFSC	    STATUS, Z	    ; Is CCPR1L = 0?
	GOTO	    EXIT_ISR	    ; Yes, exit ISR
	DECF	    CCPR1L, F	    ; No, decrement PWM
	
;------------------------------------------------------------------------------
EXIT_ISR		
	; Restore context
	SWAPF	    OLD_STATUS,W    ; saved status to W
	MOVFW	    STATUS	    ; to STATUS register
	SWAPF	    OLD_W,F	    ; swap File reg in itself
	SWAPF	    OLD_W,W	    ; re-swap back to W
	
	RETFIE
;------------------------------------------------------------------------------
	END
    

