.thumb
.syntax unified

.include "gpio_constants.s"     // Register-adresser og konstanter for GPIO
.include "sys-tick_constants.s" // Register-adresser og konstanter for SysTick

.text
	.global Start
	
.global SysTick_Handler
.thumb_func
SysTick_Handler:
	PUSH {LR} //Lagre posisjonen
	BL IncTenth//Kall tiendelsfunksjonen
	POP {LR}  //Hente tilbake
	BX LR	  //returnere


.global GPIO_ODD_IRQHandler
.thumb_func
GPIO_ODD_IRQHandler:
	LDR R0, =SYSTICK_BASE
	LDR R1, [R0]
	AND R1, #1
	CMP R1, #1 //Sjekker om siste bit (enable) er 1
	BEQ Stop
	//Start klokke
	MOV R1, #0b111
	STR R1, [R0]

	PUSH {LR}
	BL SetIFC
	POP {LR}
	BX LR
Stop:
	//Stop klokke
	MOV R1, #0b110
	STR R1, [R0]
	PUSH {LR}
	BL SetIFC
	POP {LR}
	BX LR
ToggleLed:
	LDR R6, =seconds
	LDR R0, [R6]
	AND R3, R0, #1
	
	//Finn addressen til LED
	LDR R1, =LED_PORT
	LDR R2, =PORT_SIZE
	MUL R1, R1, R2
	LDR R2, =GPIO_BASE
	ADD R1, R1, R2
	
	//Riktig bit for LED
	MOV R2, #1
	LSL R2, #LED_PIN

	//Sammenligne med 0
	CMP R3, #0
	BEQ On

	LDR R0, =GPIO_PORT_DOUTCLR
	STR R2, [R1, R0]

	MOV PC, LR

On:
	LDR R0, =GPIO_PORT_DOUTSET
	STR R2, [R1, R0]
	MOV PC, LR
	
IncTenth:
	LDR R5, =tenths
	MOV R1, #1
	LDR R0, [R5]
	
	CMP R0, #9	//Legg til ett sekund
	BPL IncSec

	ADD R0, R0, R1
	STR R0, [R5]
	MOV PC, LR	
IncSec:
	//Toggle led
	PUSH {LR}
	BL ToggleLed
	POP {LR}

	LDR R5, =tenths //Hent addresser
	LDR R6, =seconds

	MOV R1, #0	//Sett tidelene til 0
	STR R1, [R5]

	LDR R0, [R6]
	CMP R0, #59	//Et minutt har gått
	BPL IncMinute

	MOV R1, #1

	ADD R0, R0, R1 	//Legg til en
	STR R0, [R6]	//Lagre tilbake til tenths
	
	MOV PC, LR	//Tilbake til der kallet kom fra
IncMinute:
	LDR R6, =seconds
	LDR R7, =minutes

	MOV R1, #0
	STR R1, [R6] 	//Sett sekunder til 0

	MOV R1, #1
	LDR R0, [R7]
	ADD R0, R0, R1 	//Legg til et minutt
	STR R0, [R7] 	//Lagre resultat	

	MOV PC, LR 	//returner
SetIFC:
	LDR R0, =GPIO_BASE
	LDR R1, =GPIO_IFC
	ADD R0, R0, R1
	LDR R1, [R0]
	
	MOV R2, #1
	LSL R2, #BUTTON_PIN
	ORR R1, R1, R2

	STR R1, [R0]

	MOV PC, LR
Start:
	// OPPSETT SysTick
	LDR R0, =SYSTICK_BASE
	LDR R1, =SYSTICK_CTRL 	//Denne er vel 0, så egt ikke nødvendig
	MOV R2, #0b110		//Setter CTRL til 110, siste 0 for å starte stoppet
	STR R2, [R0, R1]

	LDR R1, =SYSTICK_LOAD
	LDR R2, =FREQUENCY/10	//Så divisjon er implisitt.. javel
	STR R2, [R0, R1]

	LDR R1, =SYSTICK_VAL
	STR R2, [R0, R1]
	
	//GPIO Interrupt
	//EXTIPSELH
	LDR R0, =GPIO_BASE
	LDR R1, =GPIO_EXTIPSELH
	ADD R0, R0, R1 //Adressen til pselh

	MOV R1, #0b1111	//Bits
	LSL R1, R1, #4	//Left shift
	MVN R1, R1	//Inverter

	LDR R2, [R0]	//Last verdien fra selh
	AND R1, R1, R2	//AND
	
	LDR R2, =BUTTON_PORT
	LSL R2, R2, #4
	ORR R1, R1, R2
	STR R1, [R0]

	//EXTIFALL
	LDR R0, =GPIO_BASE
	LDR R1, =GPIO_EXTIFALL
	ADD R0, R0, R1

	MOV R1, #1
	LSL R1, #BUTTON_PIN 	//Left shift til button pin
	
	LDR R2, [R0]
	ORR R1, R1, R2		//ikke bytt ut gamle verdier
	
	STR R1, [R0]	

	//IF
	BL SetIFC

	//IFEN
	LDR R0, =GPIO_BASE
	LDR R1, =GPIO_IEN
	ADD R0, R0, R1

	MOV R1, #1
	LSL R1, #BUTTON_PIN
	LDR R2, [R0]

	ORR R1, R1, R2

	STR R1, [R0]
NOP // Behold denne på bunnen av fila

