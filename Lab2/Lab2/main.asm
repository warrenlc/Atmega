;
; Lab2.asm
;
; Created: 2023-11-15 11:16:00
; Author : warren
;

; UPPGIFT 1

; CONSTANTS
.equ N			= 1;63  ; ? Gives approx 96ms per N 
.equ T			= 1;254 ; ? Sounded reasonable in the lab. Assignment done with Word, however
.def ARG_N		= r20
.def COUNTER    = r22

INIT:
	ldi r16,HIGH(RAMEND)
	out SPH,r16
	ldi r16,LOW(RAMEND)
	out SPL,r16
/*	ldi r20, $80
	out DDRB, r20*/

;MESSAGE: .db "HEJ PETTER", $00

;BTAB: ;  A   B   C   D   E   F   G   H   I   J   K   L   M   N   O   P   Q   R   S   T   U   V   W   X   Y   Z
;	.db $60,$88,$A8,$90,$40,$28,$D0,$08,$20,$78,$B0,$48,$E0,$A0,$F0,$68,$D8,$50,$10,$C0,$30,$18,$70,$98,$B8,$C8


; ***************************** ATTEMPT 2, untested with Hardware **********************************************


MORSE:
	ldi ZH,HIGH(MESSAGE*2)
	ldi ZL,LOW(MESSAGE*2)	
		
	SEND: 
		lpm r16,Z+
		
		cpi r16,$00
		breq DONE
		cpi r16,$20
		brne UNTIL_STOP_BIT 
	SPACE: 
		ldi ARG_N, 4*N
		rjmp SPACE_
	;WAIT:  
	;	rcall NOBEEP
	;	rjmp SEND	 

UNTIL_STOP_BIT: 
	ldi ARG_N,N				; default argument
	sbrc r16,7
	ldi ARG_N,3*N			; skip this and use default if bit is low
	
BEEP:
	sbi PORTB,7				; set bit, 
	rcall REST				; Wait, clear, decrement
	brne BEEP
	
CONTINUE:	
	ldi ARG_N, N
	rcall NOBEEP
	
	lsl r16					; shift and check against stop bit
	cpi r16, $80
	breq END
	rjmp UNTIL_STOP_BIT
	
	END: ldi ARG_N, 2*N     ; Wait a period of 2N after transmission
		 ;rjmp WAIT
	SPACE_:	 
		 rcall NOBEEP
		 rjmp SEND 
NOBEEP:
	cbi PORTB,7             ; clear bit (to match BEEP timing)
	rcall REST              ; Wait, clear, decrement
	brne NOBEEP
	ret

REST:		
	ldi COUNTER,T           ; Haven't yet found away to avoid duplication
	
	PAUSE_1:				; and maintain proper branching here
		dec COUNTER
		brne PAUSE_1
	cbi PORTB,7
	ldi COUNTER,T
	
	PAUSE_2:
		dec COUNTER
		brne PAUSE_2
	
	dec ARG_N
	ret

DONE: rjmp DONE

MESSAGE: .db $08,$40,$78,$20,$68,$40,$C0,$C0,$40,$50,$00


