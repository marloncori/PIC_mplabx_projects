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
;*******************************************************************************
 #include "p16f887.inc"

; __config 0xE0D2
 __CONFIG _CONFIG1, _FOSC_HS & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
; CONFIG2
; __config 0xFEFF
 __CONFIG _CONFIG2, _BOR4V_BOR21V & _WRT_OFF
 

#define BANK0	BCF STATUS,RP0
#define BANK1	BSF STATUS,RP0

#define	LED2	PORTA, RA3
; TODO PLACE VARIABLE DEFINITIONS GO HERE
CBLOCK	    H'20'
    OLD_STATUS
    OLD_W
    COUNTER
    COUNTER2
    COUNTER3
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
        GOTO	   TMR2_ISR
;*******************************************************************************
; MAIN PROGRAM
;*******************************************************************************

MAIN_PROG CODE                      ; let linker place main program

START

    BANK1
    MOVLW	H'FE'		     ; load work with  1111 1110
    MOVWF	TRISB                ; RB0 AS output, other pins - input
    MOVLW	H'33'		     ; load work reg with D'101'
    MOVWF	PR2		     ; equals 51
    BSF		PIE1, TMR2IE	     ; enable timer2 interruption
    
    BANK0
    MOVLW	H'FE'		     ; load Work register with hexa value
    MOVWF	PORTB	    	     ; RB0 AT low level
    MOVLW	H'25'	 	     ; B'0 0100 101' - timer2 enabled with
    MOVWF	T2CON		     ; postscaler 1:5 (0100) and prescaler 1:4
    BSF		INTCON, GIE	     ; enable global interrupts
    BSF		INTCON, PEIE	     ; enable peripheral interrupts
 
LOOP
    CLRF	TMR2		     ; reset timer2 
    BSF		T2CON,TMR2ON	     ; enable timer2 again
    BSF		LED2		     ; turn led on
    CALL	delay500ms	     ; wait, RB0 state is kept for half second
    
    BCF		T2CON,TMR2ON         ; disable timer2
    BCF		LED2		     ; turn led off
    CALL	delay500ms	     ; wait
    GOTO	LOOP		     ; repeat routine forever
; -----------------------------------------------------------------------------
TMR2_ISR
	; SAVE CONTEXT
	MOVWF	    OLD_W	    ; save context in W register
	SWAPF	    STATUS,W	    ; set STATUS to W
	BANK0			    ; select bank 0 (default for reset)
	MOVWF	    OLD_STATUS	    ; save STATUS

;------------------------------------------------------------------------------
	BTFSS	    PIR1, TMR2IF    ; Has timer 2 overflowed?
	GOTO	    EXIT_ISR	    ; NO, jump to ISR end
	BCF	    PIR1, TMR2IF    ; Yes, clear flag by software
	COMF	    PORTB	    ; invert portb state
; -- expected overflow time
;    machine cycle x PR2 x prescaler x postscaler
;    4e-6          * 101 *     4     *   5        = 0,00808 -> 8.09 ms
;                    51
;------------------------------------------------------------------------------
EXIT_ISR		
	; Restore context
	SWAPF	    OLD_STATUS,W    ; saved status to W
	MOVFW	    STATUS	    ; to STATUS register
	SWAPF	    OLD_W,F	    ; swap File reg in itself
	SWAPF	    OLD_W,W	    ; re-swap back to W
	
	RETFIE
;------------------------------------------------------------------------------
delay500ms
	MOVLW	    D'200'
	MOVWF	    COUNTER
AUX1
	MOVLW	    D'250'
	MOVWF	    COUNTER2	
AUX2
	MOVLW	    D'2'
	MOVWF	    COUNTER3
FOR	DECFSZ	    COUNTER3
	GOTO	    FOR
	GOTO	    EXIT
EXIT
	DECFSZ	    COUNTER2
	GOTO	    AUX2
	DECFSZ	    COUNTER
	GOTO	    AUX1
	
	RETURN
;------------------------------------------------------------------------------
	END
    

