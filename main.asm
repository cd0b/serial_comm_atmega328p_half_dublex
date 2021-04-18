.equ HALF_TIME = 0x2f
.equ FULL_TIME = 0x7f

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
	push r16
	
	ldi r16, HALF_TIME 
	call set_timer_b			; set timer
	
	ldi XL, low(control)
	ldi XH, high(control)
	ldi r20, 0x03
	st X, r20					; serial flag and half flag are set
	
	eor r20, r20
	out EIMSK, r20				; disable int0
	
	ldi XH, high(data)
	ldi XL, low(data)
	st X, r20					; data to 0x00
	
	pop r16
	reti
	
	
	
	
timer0_compa_handler:
	ldi XH, high(counter)
	ldi XL, low(counter)
	ld r20, X
	cpi r20, 0x08
	breq exit_handler_a			; if counter==8 exit
	
	inc r20
	st X, r20					; ++counter
	
	ldi XH, high(data)
	ldi XL, low(data)
	ld r20, X					; get data
	
	mov r21, r20
	andi r21, 0x01
	out PORTC, r21				; tx 1 or 0 others 0
	
	lsr r20
	st X, r20
	reti						; shift data to right and return
	
	exit_handler_a:
	call handler_exit
	reti
	
	
	
	
timer0_compb_handler:
	ldi XH, high(control)
	ldi XL, low(control)
	ld r20, X
	sbrc r20, 0x00		
	rjmp half_handler			; if half flag is set, jump to half_handler
					
	full_handler:
		ldi XH, high(counter)
		ldi XL, low(counter)
		ld r20, X
		cpi r20, 0x08			
		breq exit_handler_b		; if counter==8 exit
		
		inc r20
		st X, r20				; ++counter
		
		ldi XH, high(data)
		ldi XL, low(data)
		ld r20, X
		lsr r20					; data >>= 1
		
		in r21, PINC
		sbrc r21, 0x01
		ori r20, 0x80
		st X, r20				; if rx==1 data|=0b10000000
		reti
		
		exit_handler_b:
		call handler_exit
		reti
	
	half_handler:
		push r16
		ldi r16, FULL_TIME
		call set_timer_b			; set compare b module with full time
		pop r16
		
		in r21, PINC
		lsr r21
		sbrc r21, 0x00
		rjmp false_alarm			; if half flag is set jump false_alarm
		
		true_alarm:
		ldi XH, high(counter)
		ldi XL, low(counter)
		ld r20, X
		inc r20
		st X, r20					; ++counter
		
		ldi XH, high(control)
		ldi XL, low(control)
		ldi r20, 0x02
		st X, r20					; half flag to zero
		reti
		
		false_alarm:
		call handler_exit
		reti

	

	
	
handler_exit:
	call stop_timers
	
	eor r20,r20
	ldi XH, high(counter)
	ldi XL, low(counter)
	st X, r20					; counter to 0
	
	ldi XH, high(control)
	ldi XL, low(control)
	st X, r20					; control to 0
	
	ldi r20, 0x01
	out EIMSK, r20				; turn on int0
	
	out PORTC, r20				; tx will be set
	
	ldi XH, high(data)
	ldi XL, low(data)
	ld r20, X
	ldi XH, high(recv_data)
	ldi XL, low(recv_data)
	st X, r20
	ret
	
	
	
	
	
start:
	call init_serial
	
	
	
	program:
	; sender side
	; ldi r16, 0xaa
	; call send
	
	; receiver side
	call recv
	cpi r16, 0xaa
	breq call_test
	ldi r16, 0xff
	call test
	rjmp program
	call_test:
	ldi r16, 0x00
	call test
	rjmp program


init_serial:
	call init_timers
	call init_ports
	call init_int0
	sei
	ret
	
	
init_timers:
	ldi r16, 0x02
	out TCCR0A, r16
	ldi r17, 0x01
	out TCCR0B, r17
	ret
	
init_ports:
	eor r16,r16
	out DDRD, r16
	ldi r16, 0x01
	out DDRC, r16
	out PORTC, r16
	ret
	
init_int0:
	ldi r16, 0x02
	ldi XH, high(EICRA)
	ldi XL, low(EICRA)
	st X, r16
	ldi r16, 0x01
	out EIMSK, r16
	ret
	
set_timer_a:
	eor r17,r17
	out TCNT0, r17			; timer count is 0

	out OCR0A, r16			; set timer's length
	
	ldi r17, 0x06
	out TIFR0, r17			; clear interrupt flags
	
	ldi r17, 0x02
	ldi XH, high(TIMSK0)
	ldi XL, low(TIMSK0)
	st X, r17				; activate timer compare interrupts
	
	ret
	
	
set_timer_b:
	eor r20,r20
	out TCNT0, r20			; timer count is 0

	out OCR0A, r16
	out OCR0B, r16			; set timer's length
	
	ldi r20, 0x06
	out TIFR0, r20			; clear interrupt flags
	
	ldi r20, 0x04
	ldi XH, high(TIMSK0)
	ldi XL, low(TIMSK0)
	st X, r20				; activate timer compare interrupts
	
	ret
	
	
	
stop_timers:
	ldi r20, 0x00
	ldi XH, high(TIMSK0)
	ldi XL, low(TIMSK0)
	st Z, r20				; turn off timer compare interrupts
	ret

	

	
test:
	ldi r17, 0xff
	out DDRB, r17
	out PORTB, r16
	ret
	
	
send:
	ldi ZH, high(control)
	ldi ZL, low(control)
	
	wait_for_send:
	ld r17, Z
	sbrc r17, 0x2
	rjmp wait_for_send		; wait to end serial
	
	eor r17, r17
	out EIMSK, r17			; disable int0
	
	ldi r17, 0x06
	st Z, r17				; serial and send flag is set
	
	ldi ZH, high(data)
	ldi ZL, low(data)
	st Z, r16				; write data
	
	ldi r16, FULL_TIME
	call set_timer_a		; set_timer
	
	ret	
	
	
recv:
	ldi ZH, high(control)
	ldi ZL, low(control)
	
	wait_for_recv:
	ld r16, Z
	sbrc r16, 0x2
	rjmp wait_for_recv		; wait to end serial
	
	ldi ZH, high(recv_data)
	ldi ZL, low(recv_data)
	ld r16, Z
	ldi r17, 0xff
	st Z, r17
	
	ret
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; control: - - - - - send serial half ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.dseg
	data: .db 0x00
	counter: .db 0x00
	control: .db 0x00
	recv_data: .db 0x00
