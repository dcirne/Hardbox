#include "LED.h"
#include <ble.h>
#include <SPI.h>

#define NUMBER_OF_LEDS 7

LED *leds;

void setup() {
    SPI.setDataMode(SPI_MODE0);
    SPI.setBitOrder(LSBFIRST);
    SPI.setClockDivider(SPI_CLOCK_DIV16);
    SPI.begin();

    ble_begin();

    leds = new LED[NUMBER_OF_LEDS];

    LED led;
    for (int i = 0; i < NUMBER_OF_LEDS; ++i) {
        LED led(i, 0);
        leds[i] = led;
    }
  
    pinMode(13, OUTPUT);
    digitalWrite(13, LOW);
}

void loop() {
    byte i;
    LED led;
    
    while(ble_available()) {
        byte activeLed = ble_read();
        
        for (i = 0; i < NUMBER_OF_LEDS; ++i) {
            led = leds[i];
            
            if (i == activeLed) {
                led.set();
            } else {
                led.reset();
            }
        }
    }
    
    ble_do_events();  
}

