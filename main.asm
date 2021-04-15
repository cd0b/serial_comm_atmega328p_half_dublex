;; r16 r17 -> argument to functions
;; r18, r19 -> return from functions
;; r20, ..., r25 -> using in interrupt handlers
;; r16, r17, r18, r19 could be manipulated at return a function

.equ HALF_TIME = 0x7f
.equ FULL_TIME = 0xff

.cseg
.org 0x00


jmp start ; reset vector
jmp int0_handler ; int0
reti
nop					; int1
reti
nop					; pcint0
reti
nop					; pcint1
reti
nop					; pcint2
reti
nop					; wdt
reti
nop					; timer2 compa
reti
nop					; timer2 compb
reti
nop					; timer2 ovf
reti
nop					; timer1 capt
reti
nop					; timer1 compa
reti
nop					; timer1 compb
reti
nop					; timer1 ovf
jmp timer0_compa_handler ; timer0 compa
jmp timer0_compb_handler ; timer0 compb
reti
nop					; timer0 ovf





int0_handler:
	eor r21, r21
	out TCNT0, r21
	ldi r20, HALF_TIME
	out OCR0B, r20
	ldi r20, 0x04
	ldi ZH, high(TIMSK0)
	ldi ZL, low(TIMSK0)
	st Z, r20				; set timer0 compb module with half time
	ldi r20, 0xff
	out OCR0A, r20
	
	out EIMSK, r21			; disable int0
	
	ldi ZH, high(data)
	ldi ZL, low(data)
	st Z, r23				; data to 0
	
	ldi ZH, high(control)
	ldi ZL, low(control)
	ldi r21, 0x01
	st Z, r21				; set half flag in control register
	reti

timer0_compb_handler:
	ldi ZH, high(control)
	ldi ZL, low(control)
	ld r20, Z
	mov r21, r20
	andi r21, 0x01
	sbrc r21, 0x00		; if half flag is cleared, full_handler runs
	rjmp half_handler	; else rjmp .half_handler
						; sbrc -> skip if bit in register is cleared
	
	full_handler:
		ldi YH, high(counter)
		ldi YL, low(counter)
		ld r20, Y
		cpi r20, 0x08
		breq exit_full_handler
		continue_full_handler:
			ldi ZH, high(data)
			ldi ZL, low(data)
			ld r23, Z
			lsr r23
			in r22, PINC
			lsr r22
			sbrc r22, 0x00
			ori r23, 0x80
			st Z, r23
			inc r20
			st Y, r20
			rjmp end_of_full_handler
		exit_full_handler:
			call handler_exit
		end_of_full_handler:
			rjmp timer0_compb_handler_end
	
	half_handler:
		in r21, PINC
		lsr r21
		andi r21, 0x01
		sbrc r21, 0x00
		rjmp false_alarm
		true_alarm:
			ldi YH, high(counter)
			ldi YL, low(counter)
			ld r23, Y
			inc r23
			st Y, r23
			andi r20, 0xfe
			st Z, r20			; half flag to zero
			ldi r20, FULL_TIME
			out OCR0B, r20		; set compare b module with full time
			rjmp timer0_compb_handler_end
		false_alarm:
			call handler_exit

	timer0_compb_handler_end:
		reti
	
timer0_compa_handler:
	ldi YH, high(counter)
	ldi YL, low(counter)
	ld r20, Y
	cpi r20, 0x08
	breq exit_compa_handler
	continue_compa_handler:
		inc r20
		st Y, r20
		ldi YH, high(data)
		ldi YL, low(data)
		ld r20, Y
		mov r21, r20
		andi r21, 0x01
		cpi r21, 0x0
		breq clr_tx
		set_tx:
			ldi r22,0x01
			rjmp set_clr_tx_end
		clr_tx:
			ldi r22, 0x0
		set_clr_tx_end:
			out PORTC, r22
			lsr r20
			st Y, r20
			rjmp end_of_timer0_compa_handler
	
	exit_compa_handler:
		call handler_exit
	
	end_of_timer0_compa_handler:
		reti

	
handler_exit:
	eor r23,r23
	ldi ZH, high(TIMSK0)
	ldi ZL, low(TIMSK0)
	st Z, r23				; turn off timer interrupts
	
	ldi ZH, high(counter)
	ldi ZL, low(counter)
	st Z, r23				; counter to 0
	
	ldi ZH, high(control)
	ldi ZL, low(control)
	st Z, r23				; control to 0
	
	ldi r24, 0x01
	out EIMSK, r24			; turn on int0
	
	out PORTC, r24
	ret
	
	

start:
	call set_timer_settings
	call set_port_settings
	call set_int0_settings
	sei
	
	;ldi r16, 0xac
	;call send

end_of_program:
	rjmp end_of_program
	
	
	
set_timer_settings:	
	ldi r16, 0x02
	out TCCR0A, r16
	ldi r16, 0x01
	out TCCR0B, r16
	ret
	
set_port_settings:
	eor r16, r16
	out DDRD, r16
	ldi r16, 0x01
	out DDRC, r16
	out PORTC, r16
	ret
	
set_int0_settings:
	ldi r16, 0x02
	ldi XH, high(EICRA)
	ldi XL, low(EICRA)
	st X, r16
	ldi r16, 0x01
	out EIMSK, r16
	ret
	
	
write_data:
	ldi XH, high(data)
	ldi XL, low(data)
	st X, r16
	ret

read_data:
	ldi XH, high(data)
	ldi XL, low(data)
	ld r18, X
	ret
	
test:
	ldi r17, 0xff
	out DDRB, r17
	out PORTB, r16
	ret
	
send:
	call write_data
	
	eor r18, r18
	out TCNT0, r18
	ldi r19, FULL_TIME
	out OCR0A, r19
	ldi r19, 0x02
	ldi ZH, high(TIMSK0)
	ldi ZL, low(TIMSK0)
	st Z, r19				; set timer0 compb module with half time
	ldi r19, 0xff
	out OCR0B, r19
	
	out EIMSK, r18			; disable int0
	ret
	
.dseg
	data: .db 0x00
	control: .db 0x00
	counter: .db 0x00