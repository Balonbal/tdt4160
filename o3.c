#include "o3.h"
#include "gpio.h"
#include "systick.h"

/**************************************************************************//**
 * @brief Konverterer nummer til string 
 * Konverterer et nummer mellom 0 og 99 til string
 *****************************************************************************/
void int_to_string(char *timestamp, unsigned int offset, int i) {
    if (i > 99) {
        timestamp[offset]   = '9';
        timestamp[offset+1] = '9';
        return;
    }

    while (i > 0) {
	    if (i >= 10) {
		    i -= 10;
		    timestamp[offset]++;
		
	    } else {
		    timestamp[offset+1] = '0' + i;
		    i=0;
	    }
    }
}

/**************************************************************************//**
 * @brief Konverterer 3 tall til en timestamp-string
 * timestamp-argumentet må være et array med plass til (minst) 7 elementer.
 * Det kan deklareres i funksjonen som kaller som "char timestamp[7];"
 * Kallet blir dermed:
 * char timestamp[7];
 * time_to_string(timestamp, h, m, s);
 *****************************************************************************/
void time_to_string(char *timestamp, int h, int m, int s) {
    timestamp[0] = '0';
    timestamp[1] = '0';
    timestamp[2] = '0';
    timestamp[3] = '0';
    timestamp[4] = '0';
    timestamp[5] = '0';
    timestamp[6] = '\0';

    int_to_string(timestamp, 0, h);
    int_to_string(timestamp, 2, m);
    int_to_string(timestamp, 4, s);
}

#define LED_PORT GPIO_PORT_E
#define LED_PIN 2
#define BUTTON_PORT GPIO_PORT_B
#define PB_0_PIN 9
#define PB_1_PIN 10
#define STATE_SEC 0
#define STATE_MIN 1
#define STATE_HOUR 2
#define STATE_CTDN 3
#define STATE_ALRM 4
	typedef struct {
		volatile word CTRL;
		volatile word MODEL;
		volatile word MODEH;
		volatile word DOUT;
		volatile word DOUTSET;
		volatile word DOUTCLR;
		volatile word DOUTTGL;
		volatile word DIN;
		volatile word PINLOCKN;
	} gpio_port_map_t;

	typedef struct {
		volatile gpio_port_map_t ports[6];
		volatile word unused[10];
		volatile word EXTIPSELL;
		volatile word EXTIPSELH;
		volatile word EXTIRISE;
		volatile word EXTIFALL;
		volatile word IEN;
		volatile word IF;
		volatile word IFS;
		volatile word IFC;
		volatile word ROUTE;
		volatile word INSENSE;
		volatile word LOCK;
		volatile word CTRL;
		volatile word CMD;
		volatile word EM4WUEN;
		volatile word EM4WUPOL;
		volatile word EM4UCAUSE;
	} gpio_map_t;

typedef struct {
	volatile word CTRL;
	volatile word LOAD;
	volatile word VAL;
	volatile word CALIB;
} systick_map_t;

volatile gpio_map_t* gpio;
volatile systick_map_t* systick;
int hours, minutes, seconds, state;

void led(int on) {
	if (on == 1) {
		gpio->ports[LED_PORT].DOUTSET = 0b0100;
	} else {
		gpio->ports[LED_PORT].DOUTCLR = 0b0100;
	}
}


void GPIO_ODD_IRQHandler(void) {
	switch (state) {
		case STATE_SEC:
			seconds++;
			break;
		case STATE_MIN:
			minutes++;
			break;
		case STATE_HOUR:
			hours++;
			break;
	}
	gpio->IFC = gpio->IFC | (1 << (PB_0_PIN));
}

void GPIO_EVEN_IRQHandler(void) {
	if (state == STATE_CTDN) {}
	else if (++state > STATE_ALRM) {
		state = STATE_SEC;
		seconds = 0;
		minutes = 0;
		hours = 0;
		led(0);
	} else if (state == STATE_CTDN) {
		systick->CTRL = 0b0111;
	}
	gpio->IFC = gpio->IFC | (1 << (PB_1_PIN));
}

void SysTick_Handler(void) {
	//Ikke gjør noe i feil state
	if (seconds + minutes + hours == 0) {
		led(1);
		state = STATE_ALRM;
		systick->CTRL = 0b0110;
	}
	if (state == STATE_CTDN) {
		if (--seconds == -1) {
			seconds = 59;
			if (--minutes == -1) {
				hours--;
				minutes = 59;
			}
		}
	}


}

int main(void) {
    	init();
	//Startverdier
	seconds = 0;
	minutes = 0;
	hours   = 0;
	state = STATE_SEC;

	gpio = (gpio_map_t*) GPIO_BASE;
	systick = (systick_map_t*) SYSTICK_BASE;	
	systick->CTRL = 0b0110;

	systick->LOAD = FREQUENCY;
	systick->VAL = 0;

	//Sette opp I/O
	gpio->ports[LED_PORT].DOUT = 0;
	gpio->ports[LED_PORT].MODEL = (~(0b1111 << (LED_PIN * 4)) & gpio->ports[LED_PORT].MODEL) | (GPIO_MODE_OUTPUT << (LED_PIN * 4));
	
	//gpio->ports[LED_PORT].DOUTSET = 0b0100;	
	
	gpio->ports[BUTTON_PORT].DOUT =0;
	gpio->ports[BUTTON_PORT].MODEH = (~(0b1111 << ((PB_0_PIN - 8) * 4)) & gpio->ports[BUTTON_PORT].MODEH) | (GPIO_MODE_INPUT << ((PB_0_PIN - 8) * 4));
	gpio->ports[BUTTON_PORT].MODEH = (~(0b1111 << ((PB_1_PIN - 8) * 4)) & gpio->ports[BUTTON_PORT].MODEH) | (GPIO_MODE_INPUT << ((PB_1_PIN - 8) * 4));
	//Sette opp interrupts

	gpio->EXTIPSELH = (~(0b1111 << ((PB_0_PIN - 8) * 4))&gpio->EXTIPSELH)|(0b0001<<((PB_0_PIN - 8) * 4));
	gpio->EXTIPSELH = (~(0b1111 << ((PB_1_PIN - 8) * 4))&gpio->EXTIPSELH)|(0b0001<<((PB_1_PIN - 8) * 4));

	//Setter 1 på både PB0 og PB1
	gpio->EXTIFALL = (1 << PB_0_PIN) | gpio->EXTIFALL;
	gpio->IFC = (1 << PB_0_PIN) | gpio->IFC;
	gpio->IEN = (1 << PB_0_PIN) | gpio->IEN;
	
	gpio->EXTIFALL = (1 << PB_1_PIN) | gpio->EXTIFALL;
	gpio->IFC = (1 << PB_1_PIN) | gpio->IFC;
	gpio->IEN = (1 << PB_1_PIN) | gpio->IEN;

	while (1) {
		char str[7];
		time_to_string(str, hours, minutes, seconds);
		lcd_write(str);

	}
	
	return 0;
}

