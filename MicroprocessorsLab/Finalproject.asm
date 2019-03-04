	#include p18f87k22.inc
	
	
	
	extern	UART_Setup, UART_Transmit_Message  ; external UART subroutines
	extern  LCD_Setup, LCD_Write_Message,LCD_delay_ms,LCD_Write_Hex	,LCD_Send_Byte_I,LCD_Send_Byte_D,LCD_delay_q	    ; external LCD subroutines
	
			  
acs0	udata_acs   ; reserve data space in access ram
counter	    res 1   ; reserve one byte for a counter variable
delay_count res 1   ; reserve one byte for counter in the delay routine
mod	    res 1
lowb	    res 1
highb	    res 1
x_n	    res	1
seed	    res 1 
zero	    res 1
a_con	    res 1
subcounter  res 1
levcounter  res 1

input	    res	1
delayno	    res	1
one	    res 1
two	    res 1
three	    res 1
four	    res	1
six	    res	1
eight	    res	1
randno	    res	1
score	    res	1
keyboard_input	    res	1
conv_count  res 1
pos	    res 1
rawranno    res	1
tencount    res 1
unitcount   res	1

 
tables	udata	0x400    ; reserve data anywhere in RAM (here at 0x400)
myArray res 0x80    ; reserve 128 bytes for message data

rst	code	0    ; reset vector
	goto	LCGsetup


	; a delay subroutine if you need one, times around loop in delay_count
delay	
	call	LCD_delay_q
	decfsz	delay_count	; decrement until zero
	bra delay
	return

inputdelay	


	movf	delayno,0   ; length of delay
	call	LCD_delay_q	;delay  for input time

	
	movff	zero,keyboard_input	;rest keybord input
	call	keyboardcheck	; check currret keyboard input
	movff	zero,input; reset input
	movf	keyboard_input,0; move keyboard input to wreg
	addwf	input ; add keyboard input to inout
	
	movlw	0x00
	movwf	pos ;reset pos
	call	pollADC	;poll adc conversion and count times aboce a threshold
	tstfsz	pos ; skip if pos = 0
	incf	input	; increment input


	tstfsz	input,0	; if input isn't 0 return, otherwise keep checking
	return
	decfsz	delay_count	; decrement until zero
	bra inputdelay	;keep checking if delay count isnt up
	return


	
	
	
	
LCGsetup
	
	call	LCD_Setup
	movlw	0x00
	movwf	TRISJ,ACCESS ; set portj  to input
	
	
	bsf	PADCFG1,REPU, BANKED	; se t bit to read keyboard
	clrf	LATJ ;  clear latch
	movlw	0x0F	; set half the bit s to input and half to output

	
	
	bsf	    TRISA,RA0	    ; use pin A0(==AN0) for input
	bsf	    ANCON0,ANSEL0   ; set A0 to analog
	movlw   0x01	    ; select AN0 for measurement
	movwf   ADCON0	    ; and turn ADC on
	movlw   0x30	    ; Select 2.048V positive reference
	movwf   ADCON1	    ; 0V for -ve reference and -ve input
	movlw   0xF6	    ; Right justified output
	movwf   ADCON2	    ; Fosc/64 clock and acquisition times
	
	movlw	0x00	;seed if for some reason the folloeing two lines dont work
	call	ADC_Read ;  take volume
	movf	ADRESL,0    ;use most precise 8  bits as seed
	movwf	x_n
	movlw	0x00	;always 0 to make unconditional  skip
	movwf	zero
	movwf	score	;   set score to 0
	movlw	0x01
	movwf	one	; number of  modulus that turnss on led 1
	movlw	0x02
	movwf	two	  ; reserve vaiable for number 2
	movlw	0x03
	movwf	three; reserve vaiable for number 3
	movlw	0x04
	movwf	four; reserve vaiable for number 4
	movlw	0x08
	movwf	eight; reserve vaiable for number 8
	movlw	0x06
	movwf	six; reserve vaiable for number 6
	
	movlw	0x02	;sublevel
	movwf	subcounter
	movlw	0x00	;start at level 0
	movwf	levcounter
	movlw	0x12
	movwf	delayno	;inital no. of mini delays
	movwf	delay_count
	
	
	

	goto	LCG
	
	
Levcheck
	
	decf	subcounter ;decrement sub level counter
	tstfsz	subcounter ;if counter isnt 0 ccontinue
	goto	inputcheck
	incf	levcounter ; increment level counter if have gone through al sub levels
	decf	delayno	; reduce the delay time
	movlw	0x02	; rest sub levle counter
	movwf	subcounter

inputcheck
	
	call	inputdelay

	; add check corrrect input after decoding

	movf	input, 0

	call	inputfour ; call input 4
	movf	input,	0
	cpfseq	randno	;if input matches randno then its correct, othereise end
	goto	the_end
	incf	score
	
	movlw	b'00000001'	; display clear
	call	LCD_Send_Byte_I
	movlw	.2		; wait 2ms
	call	LCD_delay_ms
	movff	score, unitcount ; move score to score to unit count
	movlw	0x00	
	movwf	tencount    ; tens digits start at 0
	call	LCDmodulo   ; call LCDmodulo
	movlw	0x30	; add number to convert units and tens to numbers for LCD
	addwf	unitcount
	addwf	tencount
	movf	tencount,0  ; send data byte for tens 
	call	LCD_Send_Byte_D
	movf	unitcount,0 ; send data byte 
	call	LCD_Send_Byte_D
	
	goto	LCG	
	
	
	
LCG  ; x_n+1 = (a*x_n + c) mod m
	movlw	0x05	    ; set conv_count to 0
	movwf	conv_count
	
	
	movlw	0xD5	; set a
	movwf	a_con
	
	movf	a_con, 0	;move a to wreg
	mulwf	x_n	;a * current x_n
	movff	PRODL, lowb ;move both  8 bit numbers from prod registers to file registers
	movff	PRODH, highb
	movlw	0x01 ;c to be added
	addwf	lowb ; adds
	movff	lowb,rawranno ;moves last 8  bits of multiplication into register usd by moulo
	call	modulo2
	movff	rawranno, x_n; moves result  backinto register storing x_n
	
	call	modulo
	
	
	movlw	0x00	; sets PORTE to not tri state
	movwf	TRISE
	
	movlw	0x01
	addwf	rawranno	; adds 1 to random number
	;decoding random number
	movf	rawranno,0
	cpfseq	four	    
	tstfsz	zero
	call	LEDone	; if random number is 4 call LEDone
	movf	rawranno,0
	cpfseq	two
	tstfsz	zero
	call	LEDtwo  ; if random number is 2 call LEDtwo
	movf	rawranno,0
	cpfseq	three
	tstfsz	zero
	call	LEDthree  ; if random number is 3 call LEDthree
	
	movff	randno, PORTE ; moves random number to PORTE
	
	movf	delayno,0	;  cycles of delay 
	movwf	delay_count
	call	delay	;delays caled
	
	
	movlw	0xFF; resets PORTE
	movwf	PORTE
	

	goto	Levcheck

	
	
	
	
	
	
modulo2
	movlw	0xFB	;m-1 used for modulo
	movwf	0x21	;regiser m-1 is stored in

check ; checks if remainder has been found
	movf	0x21,0	;moves m-1 into wreg
	cpfslt	rawranno	; compare possible result with wreg, skip if less than
	goto	subloop2    
	tstfsz	highb	; test if first 8 bits  from multipliction have ben decremented to 0
	tstfsz	zero	;unconitonal skip as zero is alays  0
	return	; result found
	decf	highb ; decement first 8 multplied bits

	
	
	
	
subloop2 ;loop subtracting m from rawranno
	movlw	0xFB	;m 
	subwf	rawranno	;rawranno-m
	goto	check	
	
	
modulo
	
	movlw	0x02	;m-1 used for modulo
	movwf	0x21	;regiser m-1 is stored in


checkloop ; checks if remainder has been found
	movf	0x21
	cpfsgt	rawranno
	return	;terminate everything 
	
subloop ;loop subtracting m from rawranno
	movlw	0x03	;m 
	subwf	rawranno	;rawranno-m
	goto	checkloop	
	
	

	
LEDone
	movlw	0x06
	movwf	randno	; move  6 to randno
	return
LEDtwo
	movlw	0x05
	movwf	randno; move  5 to randno
	return
LEDthree
	movlw	0x03
	movwf	randno; move  3 to randno
	return

ADC_Setup
	bsf	    TRISA,RA0	    ; use pin A0(==AN0) for input
	bsf	    ANCON0,ANSEL0   ; set A0 to analog
	movlw   0x01	    ; select AN0 for measurement
	movwf   ADCON0	    ; and turn ADC on
	movlw   0x18	    ; Select 2.048V positive reference
	movwf   ADCON1	    ; 0V for -ve reference and -ve input
	movlw   0xF6	    ; Right justified output
	movwf   ADCON2	    ; Fosc/64 clock and acquisition times
	return

ADC_Read
	bsf	    ADCON0,GO	    ; Start conversion
adc_loop
	btfsc   ADCON0,GO	    ; check to see if finished
	bra	    adc_loop
	return	
	
    
keyboardcheck
	
	bsf	PADCFG1, REPU, BANKED ; sets up keyboard for input
	clrf	LATJ	; clear latch
	movlw	0x0F
	movwf	TRISJ	    ; sets half the bit to input and half to output
	

	
	
	movf	eight,0
	cpfseq	PORTJ	; if input is = 8, decode using  key_input_two
	tstfsz	zero
	call	key_input_two
	movf	four, 0
	cpfseq	PORTJ  ; if input is =4, decode using key_input_three
	tstfsz	zero
	call	key_input_three
	return
	
	
key_input_two
	movlw   0x03
	movwf	keyboard_input  ; keyboard_input =  3
	return
	
inputfour
	movf	input, 0    ;move inout to wreg
	cpfseq	one	; if input = 1 skip
	return
	movff	six,input ; set input to 6 if = 1
	return
		
	
key_input_three
	movlw   0x05
	movwf	keyboard_input ; ; keyboard_input =  5
	return
 
pollADC
	decf	conv_count ; decrment this loopcounter
	call	ADC_Read    ;  read voltage of microphone
	movlw	0x10	
	cpfsgt	ADRESH
	tstfsz	zero	
	incf	pos; if above high threshold, increment pos

	movlw	0x09                                                                                                                         
	cpfslt	ADRESH
	tstfsz	zero
	incf	pos	;if below low threshold, increment pos
	
	
	
	
	tstfsz	conv_count ; if count = 0 exit loop
	bra	pollADC
	return
 
	
LCDmodulo
	
	movlw	0x09	;m-1 used for modulo
	movwf	0x41	;regiser m-1 is stored in


LCDcheckloop ; checks if remainder has been found
	movf	0x41,0
	cpfsgt	unitcount
	return	;terminate everything 
	
LCDsubloop ;loop subtracting m from unitcount
	movlw	0x0A	;m 
	subwf	unitcount	;unitcount-m
	incf	tencount
	goto	LCDcheckloop	
	
		
	
    
the_end	
	movlw	0x07	; signal end light
	movwf	PORTE
	
	goto	the_end
	
    end
