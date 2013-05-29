#ifndef LED_h
#define LED_h

#include "Arduino.h"

class LED {
    bool _on;
    int _pin;
    int _interval;
    
    public:
        LED();
        LED(int pin, int interval);
        void set();
        void reset();
        bool on();
        void setPin(int pin);
        int pin();
        void setInterval(int interval);
        int interval();
};

#endif
