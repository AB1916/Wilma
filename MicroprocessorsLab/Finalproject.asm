#include p18f87k22.inc

	extern	UART_Setup, UART_Transmit_Message  ; external UART subroutines
	extern  LCD_Setup, LCD_Write_Message,LCD_delay_ms	    ; external LCD subroutines
	
acs0	udata_acs   ; reserve data space in access ram
counter	    res 1   ; reserve one byte for a counter variable
delay_count res 1   ; reserve one byte for counter in the delay routine
mod	    res 1
lowb	    res 1
highb	    res 1
;x_n	    res	1
seed	    res 1 
zero	    res 1
a_con	    res 1
subcounter  res 1
levcounter  res 1
compreg	    res 1
input	    res	1
delayno	    res	1
one	    res 1
two	    res 1
three	    res 1
randno	    res	1
 
tables	udata	0x400    ; reserve data anywhere in RAM (here at 0x400)
myArray res 0x80    ; reserve 128 bytes for message data

rst	code	0    ; reset vector
	goto	LCGsetup

pdata	code    ; a section of programme memory for storing data
	; ******* myTable, data in programme memory, and its length *****
myTable data	    "Hello World!\n"	; message, plus carriage return
	constant    myTable_l=.13	; length of data
	
main	code
	; ******* Programme FLASH read Setup Code ***********************
setup	bcf	EECON1, CFGS	; point to Flash program memory  
	bsf	EECON1, EEPGD 	; access Flash program memory
	call	UART_Setup	; setup UART
	call	LCD_Setup	; setup LCD
	goto	start
	
	; ******* Main programme ****************************************
start 	lfsr	FSR0, myArray	; Load FSR0 with address in RAM	
	movlw	upper(myTable)	; address of data in PM
	movwf	TBLPTRU		; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH		; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL		; load low byte to TBLPTRL
	movlw	myTable_l	; bytes to read
	movwf 	counter		; our counter register
loop 	tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter		; count down to zero
	bra	loop		; keep going until finished
		
	movlw	myTable_l-1	; output message to LCD (leave out "\n")
	lfsr	FSR2, myArray
	call	LCD_Write_Message
	
	movlw	myTable_l	; output message to UART
	lfsr	FSR2, myArray
	call	UART_Transmit_Message

	goto	$		; goto current line in code

	; a delay subroutine if you need one, times around loop in delay_count
delay	
	call	LCD_delay_ms
	decfsz	delay_count	; decrement until zero
	bra delay
	return

inputdelay	
	movf	delayno,0
	call	LCD_delay_ms
	movlw	0xFF
	movwf	TRISF,ACCESS	;sets PORTH to input/output
	;clrf	LATH,ACCESS
	movf	PORTF,0
	
	movwf	input ; moves number from PORTH to input
	tstfsz	input	; if input isn't 0 return, otherwise keep checking
	return
	decfsz	delay_count	; decrement until zero
	bra inputdelay	;keep checking if delay count isnt up
	return

LCGsetup
	clrf	LATF,ACCESS
	movlw	0x00	;seed
	movwf	0x30
	movlw	0x00	;always 0 to make unconditional  skip
	movwf	zero
	movlw	0x04
	movwf	one
	movlw	0x02
	movwf	two
	movlw	0x03
	movwf	three
	
	
	
	movlw	0x03	;sublevel
	movwf	subcounter
	movlw	0x00	;start at level 0
	movwf	levcounter
	movlw	0x12
	movwf	delayno	;inital no. of mini delays
	movwf	delay_count
	movlw	0x03
	movwf	compreg ; no. in compare register
	
Levcheck
	
	decf	subcounter ;decrement sub level counter
	tstfsz	subcounter ;if counter isnt 0 ccontinue
	goto	inputcheck
	incf	levcounter ; increment level counter if have gone through al sub levels
	decf	delayno	; reduce the delay time
	movlw	0x03	; rest sub levle counter
	movwf	subcounter

inputcheck
	
	call	inputdelay
	tstfsz	input	;if no input then go to end
	tstfsz	zero
	goto	the_end
	; add check corrrect input after decoding
	
	
	
	;movlw	0x00
	;movwf	TRISH
	;movff	PORTH , compreg
	;movlw	0x20
	
	;movlw	0x03
	;cpfseq	compreg
	;goto	the_end
	
LCG  ; x_n+1 = (a*x_n + c) mod m
	movlw	0xD5	; set a
	movwf	a_con
	
	movf	a_con, 0	;move a to wreg
	mulwf	0x30	;a * current x_n
	movff	PRODL, lowb ;move both  8 bit numbers from prod registers to file registers
	movff	PRODH, highb
	movlw	0x01 ;c to be added
	addwf	lowb ; adds
	movff	lowb,0x20 ;moves last 8  bits of multiplication into register usd by moulo
	call	modulo2
	movff	0x20, 0x30; moves result  backinto register storing x_n
	
	call	modulo
	
	
	movlw	0x00	; sets port E to not tri state
	movwf	TRISE
	
	movlw	0x01
	addwf	0x20	; adds 1 to random number
	;decoding random number
	movf	0x20,0
	cpfseq	one
	tstfsz	zero
	call	LEDone
	movf	0x20,0
	cpfseq	two
	tstfsz	zero
	call	LEDtwo
	movf	0x20,0
	cpfseq	three
	tstfsz	zero
	call	LEDthree
	
	movff	randno, PORTE ; moves random number to PORTE
	
	movf	delayno,0	;  cycles of delay 
	movwf	delay_count
	call	delay	;delays caled
	
	movlw	0xFF; resets PORTE
	movwf	PORTE
	

	
	
	
	clrf	PORTF
	goto	Levcheck
	
modulo2
	movlw	0xFB	;m-1 used for modulo
	movwf	0x21	;regiser m-1 is stored in

check ; checks if remainder has been found
	movf	0x21,0	;moves m-1 into wreg
	cpfslt	0x20	; compare possible result with wreg, skip if less than
	goto	subloop2    
	tstfsz	highb	; test if first 8 bits  from multipliction have ben decremented to 0
	tstfsz	0x15	;unconitonal skip as 0x25 is alays  0
	return	; result found
	decf	highb ; decement first 8 multplied bits

	
	
	
	
subloop2 ;loop subtracting m from 0x20
	movlw	0xFB	;m 
	subwf	0x20	;0x20-m
	goto	check	
	
	
modulo
	
	movlw	0x02	;m-1 used for modulo
	movwf	0x21	;regiser m-1 is stored in


checkloop ; checks if remainder has been found
	movf	0x21
	cpfsgt	0x20
	return	;terminate everything 
	
subloop ;loop subtracting m from 0x20
	movlw	0x03	;m 
	subwf	0x20	;0x20-m
	goto	checkloop	
	
	
the_end
	
LEDone
	movlw	0x06
	movwf	randno
	return
LEDtwo
	movlw	0x05
	movwf	randno
	return
LEDthree
	movlw	0x03
	movwf	randno
	return
	
	
	
	end
