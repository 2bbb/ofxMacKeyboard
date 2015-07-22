//
//  ofxMacKeyboardEventStealer.h
//
//  Created by ISHII 2bit on 2015/07/21.
//
//

#pragma once

#include "ofEvents.h"

namespace ofxMacKeyboardEventStealer {
    typedef struct {
        uint16_t keyCode;
        uint8_t isModifierKey:1;
        uint8_t isKeyDown:1;
        uint8_t isShiftEnabled:1;
        uint8_t isCommandEnabled:1;
        uint8_t isOptionEnabled:1;
        uint8_t isControlEnabled:1;
        uint8_t isFunctionnEnabled:1;
        uint8_t isCapsEnabled:1;
    } ofxMacKeyboardEventArg;
    
    extern ofEvent<ofxMacKeyboardEventArg> ofxMacKeyboardEvent;
    
    void ofxMacKeyboardStartStealKeyboardEvent(string appName = "cc.openFrameworks.ofapp");
    void ofxMacKeyboardStopStealKeyboardEvent();
    const char * const ofxMacKeyboardConvertKeyCodeWithUSKeyboard(ofxMacKeyboardEventArg &event);
    const char * const ofxMacKeyboardConvertKeyCodeWithJISKeyboard(ofxMacKeyboardEventArg &event);
    
    ostream &operator<<(ostream &os, const ofxMacKeyboardEventArg &event);
}

using namespace ofxMacKeyboardEventStealer;