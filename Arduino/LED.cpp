#include "LED.h"
#include "Arduino.h"

LED::LED() {
}

LED::LED(int pin, int interval) {
    this->_pin = pin;
    this->_interval = interval;
    this->_on = false;
    pinMode(this->_pin, OUTPUT);
    delay(1);
    digitalWrite(this->_pin, HIGH);
}

void LED::set() {
    this->_on = true;
    digitalWrite(this->_pin, LOW);
    
    if (this->_interval > 0) {
        delay(this->_interval);
    }
}

void LED::reset() {
    this->_on = false;
    digitalWrite(this->_pin, HIGH);
    
    if (this->_interval > 0) {
        delay(this->_interval);
    }
}

bool LED::on() {
    return this->_on;
}

void LED::setPin(int pin) {
    this->_pin = pin;
}

int LED::pin() {
    return this->_pin;
}

void LED::setInterval(int interval) {
    this->_interval = interval;
}

int LED::interval() {
    return this->_interval;
}
