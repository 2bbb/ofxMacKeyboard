//
//  ofxMacKeyboardEventStealer.cpp
//
//  Created by ISHII 2bit on 2015/07/21.
//
//

#include "ofxMacKeyboardEventStealer.h"

#include "ofLog.h"
#include "ofUtils.h"

#include <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Security/Authorization.h>
#import <IOKit/hidsystem/IOLLEvent.h>
#include <Carbon/Carbon.h>

#define kVK_RightCommand 0x36

namespace ofxMacKeyboardEventStealer {
    ofEvent<ofxMacKeyboardEventArg> ofxMacKeyboardEvent;
    enum {
        OFX_MAC_KEYBOARD_SHIFT_MASK   = NX_DEVICELSHIFTKEYMASK | NX_DEVICERSHIFTKEYMASK,
        OFX_MAC_KEYBOARD_COMMAND_MASK = NX_DEVICELCMDKEYMASK   | NX_DEVICERCMDKEYMASK,
        OFX_MAC_KEYBOARD_OPTION_MASK  = NX_DEVICELALTKEYMASK   | NX_DEVICERALTKEYMASK,
        OFX_MAC_KEYBOARD_CONTROL_MASK = NX_DEVICELCTLKEYMASK   | NX_DEVICERCTLKEYMASK,
    };
    namespace {
        // cite: https://github.com/dannvix/keylogger-osx/blob/master/keylogger.c
        int eventFlagMaskForKeycode(uint16_t keycode)
        {
            switch (keycode) {
                case kVK_Command: return NX_DEVICELCMDKEYMASK;
                case kVK_Shift: return NX_DEVICELSHIFTKEYMASK;
                case kVK_CapsLock: return NX_ALPHASHIFTMASK;
                case kVK_Option: return NX_DEVICELALTKEYMASK;
                case kVK_Control: return NX_DEVICELCTLKEYMASK;
                case kVK_RightCommand: return NX_DEVICERCMDKEYMASK;
                case kVK_RightShift: return NX_DEVICERSHIFTKEYMASK;
                case kVK_RightOption: return NX_DEVICERALTKEYMASK;
                case kVK_RightControl: return NX_DEVICERCTLKEYMASK;
                case kVK_Function: return NX_SECONDARYFNMASK;
                default: return 0;
            }
        }
        
        CGEventRef keyboardStealer(CGEventTapProxy proxy,
                                   CGEventType type,
                                   CGEventRef event,
                                   void *refcon)
        {
            bool isKeyDown;
            switch(type) {
                case kCGEventKeyDown: isKeyDown = true;  break;
                case kCGEventKeyUp:   isKeyDown = false; break;
                case kCGEventFlagsChanged:
                default:
                    break;
            }
            
            CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
            int64_t flags = CGEventGetFlags(event);
            int64_t code = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
            int mask = eventFlagMaskForKeycode(code);
            if(mask != 0) {
                isKeyDown = (flags & mask) != 0;
            }
            ofxMacKeyboardEventArg arg = {
                .keyCode            = keyCode,
                .isModifierKey      = mask != 0 ? 1 : 0,
                .isKeyDown          = isKeyDown ? 1 : 0,
                .isShiftEnabled     = (flags & OFX_MAC_KEYBOARD_SHIFT_MASK) ? 1 : 0,
                .isCommandEnabled   = (flags & OFX_MAC_KEYBOARD_COMMAND_MASK) ? 1 : 0,
                .isOptionEnabled    = (flags & OFX_MAC_KEYBOARD_OPTION_MASK) ? 1 : 0,
                .isControlEnabled   = (flags & OFX_MAC_KEYBOARD_CONTROL_MASK) ? 1 : 0,
                .isFunctionnEnabled = (flags & NX_SECONDARYFNMASK) ? 1 : 0,
                .isCapsEnabled      = (flags & NX_ALPHASHIFTMASK) ? 1: 0
            };
            
            ofNotifyEvent(ofxMacKeyboardEvent, arg);
            return event;
        }
    }
    
    namespace {
        static CFMachPortRef ofxMacKeyboardEventPortRef = NULL;
        static CFRunLoopSourceRef ofxMacKeyboardRunLoopSource = NULL;
    }
    void ofxMacKeyboardStartStealKeyboardEvent(string appName) {
        if(ofxMacKeyboardEventPortRef != NULL) return;
        NSDictionary *options = @{(id)kAXTrustedCheckOptionPrompt: @YES};
        BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
        
        if(!accessibilityEnabled) {
            printf("not accessibilityEnabled\n");
            const char *command= "/usr/bin/sqlite3";
            string query = ofVAArgsToString("INSERT or REPLACE INTO access  VALUES('kTCCServiceAccessibility','%s',0,1,0,NULL);", appName.c_str()).c_str();
            char *query_buf = (char *)malloc(query.length() + 1);
            strcpy(query_buf, query.c_str());
            char * args[] = {
                "/Library/Application Support/com.apple.TCC/TCC.db",
                query_buf,
                nil
            };
            AuthorizationRef authRef;
            OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef);
            if (status == errAuthorizationSuccess) {
                status = AuthorizationExecuteWithPrivileges(authRef, command, kAuthorizationFlagDefaults, args, NULL);
                AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
                if(status != 0){
                    //handle errors...
                }
            }
        }
        
        CGEventMask eventMask   = CGEventMaskBit(kCGEventKeyUp)
                                | CGEventMaskBit(kCGEventKeyDown)
                                | CGEventMaskBit(kCGEventFlagsChanged);
        CGEventFlags flags = CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState);
        ofxMacKeyboardEventPortRef = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, keyboardStealer, &flags);
        if (!ofxMacKeyboardEventPortRef) {
            ofLogError("ofxMacKeyboard") << "failed to create event tap";
        }
        
        ofxMacKeyboardRunLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, ofxMacKeyboardEventPortRef, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), ofxMacKeyboardRunLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(ofxMacKeyboardEventPortRef, true);
    }
    
    void ofxMacKeyboardStopStealKeyboardEvent() {
        if(ofxMacKeyboardEventPortRef == NULL) return;
        
        CGEventTapEnable(ofxMacKeyboardEventPortRef, false);
        
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), ofxMacKeyboardRunLoopSource, kCFRunLoopCommonModes);

        CFRelease(ofxMacKeyboardRunLoopSource);
        ofxMacKeyboardRunLoopSource = NULL;
        CFRelease(ofxMacKeyboardEventPortRef);
        ofxMacKeyboardEventPortRef = NULL;
    }

    ostream &operator<<(ostream &os, const ofxMacKeyboardEventArg &event) {
        return os << "{\n  keyCode: " << event.keyCode
                  << ",\n  isModifier: " << (int)event.isModifierKey
                  << ",\n  isKeyDown: " << (int)event.isKeyDown
                  << ",\n  (shift, command, option, control, fn, caps)\n    = ("
                  << (int)event.isShiftEnabled << ", "
                  << (int)event.isCommandEnabled << ", "
                  << (int)event.isOptionEnabled << ", "
                  << (int)event.isControlEnabled << ", "
                  << (int)event.isFunctionnEnabled << ", "
                  << (int)event.isCapsEnabled << ")\n}";
    }

    const char * const ofxMacKeyboardConvertKeyCodeWithUSKeyboard(ofxMacKeyboardEventArg &event) {
        switch(event.keyCode) {
            case kVK_ANSI_A: return "A";
            case kVK_ANSI_S: return "S";
            case kVK_ANSI_D: return "D";
            case kVK_ANSI_F: return "F";
            case kVK_ANSI_H: return "H";
            case kVK_ANSI_G: return "G";
            case kVK_ANSI_Z: return "Z";
            case kVK_ANSI_X: return "X";
            case kVK_ANSI_C: return "C";
            case kVK_ANSI_V: return "V";
            case kVK_ANSI_B: return "B";
            case kVK_ANSI_Q: return "Q";
            case kVK_ANSI_W: return "W";
            case kVK_ANSI_E: return "E";
            case kVK_ANSI_R: return "R";
            case kVK_ANSI_Y: return "Y";
            case kVK_ANSI_T: return "T";
            case kVK_ANSI_1: return "1";
            case kVK_ANSI_2: return "2";
            case kVK_ANSI_3: return "3";
            case kVK_ANSI_4: return "4";
            case kVK_ANSI_6: return "6";
            case kVK_ANSI_5: return "5";
            case kVK_ANSI_Equal: return "=";
            case kVK_ANSI_9: return "9";
            case kVK_ANSI_7: return "7";
            case kVK_ANSI_Minus: return "-";
            case kVK_ANSI_8: return "8";
            case kVK_ANSI_0: return "0";
            case kVK_ANSI_RightBracket: return "]";
            case kVK_ANSI_O: return "O";
            case kVK_ANSI_U: return "U";
            case kVK_ANSI_LeftBracket: return "[";
            case kVK_ANSI_I: return "I";
            case kVK_ANSI_P: return "P";
            case kVK_ANSI_L: return "L";
            case kVK_ANSI_J: return "J";
            case kVK_ANSI_Quote: return "'";
            case kVK_ANSI_K: return "K";
            case kVK_ANSI_Semicolon: return ";";
            case kVK_ANSI_Backslash: return "\\";
            case kVK_ANSI_Comma: return ",";
            case kVK_ANSI_Slash: return "/";
            case kVK_ANSI_N: return "N";
            case kVK_ANSI_M: return "M";
            case kVK_ANSI_Period: return ".";
            case kVK_ANSI_Grave: return "`";
            case kVK_ANSI_KeypadDecimal: return "keypad decimal";
            case kVK_ANSI_KeypadMultiply: return "keypad multiply";
            case kVK_ANSI_KeypadPlus: return "keypad plus";
            case kVK_ANSI_KeypadClear: return "keypad clear";
            case kVK_ANSI_KeypadDivide: return "keypad divide";
            case kVK_ANSI_KeypadEnter: return "keypad enter";
            case kVK_ANSI_KeypadMinus: return "keypad minus";
            case kVK_ANSI_KeypadEquals: return "keypad equals";
            case kVK_ANSI_Keypad0: return "keypad 0";
            case kVK_ANSI_Keypad1: return "keypad 1";
            case kVK_ANSI_Keypad2: return "keypad 2";
            case kVK_ANSI_Keypad3: return "keypad 3";
            case kVK_ANSI_Keypad4: return "keypad 4";
            case kVK_ANSI_Keypad5: return "keypad 5";
            case kVK_ANSI_Keypad6: return "keypad 6";
            case kVK_ANSI_Keypad7: return "keypad 7";
            case kVK_ANSI_Keypad8: return "keypad 8";
            case kVK_ANSI_Keypad9: return "keypad 9";
            case kVK_Return: return "return";
            case kVK_Tab: return "tab";
            case kVK_Space: return "space";
            case kVK_Delete: return "delete";
            case kVK_Escape: return "esc";
            case kVK_Command: return "command";
            case kVK_Shift: return "shift";
            case kVK_CapsLock: return "caps";
            case kVK_Option: return "option";
            case kVK_Control: return "control";
            case kVK_RightCommand: return "right command";
            case kVK_RightShift: return "right shift";
            case kVK_RightOption: return "right option";
            case kVK_RightControl: return "right control";
            case kVK_Function: return "fn";
            case kVK_F17: return "F17";
            case kVK_VolumeUp: return "volume up";
            case kVK_VolumeDown: return "volume down";
            case kVK_Mute: return "mute";
            case kVK_F18: return "F18";
            case kVK_F19: return "F19";
            case kVK_F20: return "F20";
            case kVK_F5: return "F5";
            case kVK_F6: return "F6";
            case kVK_F7: return "F7";
            case kVK_F3: return "F3";
            case kVK_F8: return "F8";
            case kVK_F9: return "F9";
            case kVK_F11: return "F11";
            case kVK_F13: return "F13";
            case kVK_F16: return "F16";
            case kVK_F14: return "F14";
            case kVK_F10: return "F10";
            case kVK_F12: return "F12";
            case kVK_F15: return "F15";
            case kVK_Help: return "help";
            case kVK_Home: return "home";
            case kVK_PageUp: return "page up";
            case kVK_ForwardDelete: return "forward delete";
            case kVK_F4: return "F4";
            case kVK_End: return "end";
            case kVK_F2: return "F2";
            case kVK_PageDown: return "page down";
            case kVK_F1: return "F1";
            case kVK_LeftArrow: return "left arrow";
            case kVK_RightArrow: return "right arrow";
            case kVK_DownArrow: return "down arrow";
            case kVK_UpArrow: return "up arrow";
            case kVK_ISO_Section: return "section";
            case kVK_JIS_Yen: return "yen";
            case kVK_JIS_Underscore: return "_";
            case kVK_JIS_KeypadComma: return "keypad ,";
            case kVK_JIS_Eisu: return "eisu";
            case kVK_JIS_Kana: return "kana";
        }
        return "<unknown>";
    }
    
    const char * const ofxMacKeyboardConvertKeyCodeWithJISKeyboard(ofxMacKeyboardEventArg &event) {
        switch (event.keyCode) {
            case kVK_ANSI_A: return "A";
            case kVK_ANSI_S: return "S";
            case kVK_ANSI_D: return "D";
            case kVK_ANSI_F: return "F";
            case kVK_ANSI_H: return "H";
            case kVK_ANSI_G: return "G";
            case kVK_ANSI_Z: return "Z";
            case kVK_ANSI_X: return "X";
            case kVK_ANSI_C: return "C";
            case kVK_ANSI_V: return "V";
            case kVK_ANSI_B: return "B";
            case kVK_ANSI_Q: return "Q";
            case kVK_ANSI_W: return "W";
            case kVK_ANSI_E: return "E";
            case kVK_ANSI_R: return "R";
            case kVK_ANSI_Y: return "Y";
            case kVK_ANSI_T: return "T";
            case kVK_ANSI_1: return "1";
            case kVK_ANSI_2: return "2";
            case kVK_ANSI_3: return "3";
            case kVK_ANSI_4: return "4";
            case kVK_ANSI_6: return "6";
            case kVK_ANSI_5: return "5";
            case kVK_ANSI_Equal: return "^";
            case kVK_ANSI_9: return "9";
            case kVK_ANSI_7: return "7";
            case kVK_ANSI_Minus: return "-";
            case kVK_ANSI_8: return "8";
            case kVK_ANSI_0: return "0";
            case kVK_ANSI_RightBracket: return "[";
            case kVK_ANSI_O: return "O";
            case kVK_ANSI_U: return "U";
            case kVK_ANSI_LeftBracket: return "[";
            case kVK_ANSI_I: return "I";
            case kVK_ANSI_P: return "P";
            case kVK_ANSI_L: return "L";
            case kVK_ANSI_J: return "J";
            case kVK_ANSI_Quote: return ":";
            case kVK_ANSI_K: return "K";
            case kVK_ANSI_Semicolon: return ";";
            case kVK_ANSI_Backslash: return "]";
            case kVK_ANSI_Comma: return ",";
            case kVK_ANSI_Slash: return "/";
            case kVK_ANSI_N: return "N";
            case kVK_ANSI_M: return "M";
            case kVK_ANSI_Period: return ".";
            case kVK_ANSI_Grave: return "`";
            case kVK_ANSI_KeypadDecimal: return "keypad decimal";
            case kVK_ANSI_KeypadMultiply: return "keypad multiply";
            case kVK_ANSI_KeypadPlus: return "keypad plus";
            case kVK_ANSI_KeypadClear: return "keypad clear";
            case kVK_ANSI_KeypadDivide: return "keypad divide";
            case kVK_ANSI_KeypadEnter: return "keypad enter";
            case kVK_ANSI_KeypadMinus: return "keypad minus";
            case kVK_ANSI_KeypadEquals: return "keypad equals";
            case kVK_ANSI_Keypad0: return "keypad 0";
            case kVK_ANSI_Keypad1: return "keypad 1";
            case kVK_ANSI_Keypad2: return "keypad 2";
            case kVK_ANSI_Keypad3: return "keypad 3";
            case kVK_ANSI_Keypad4: return "keypad 4";
            case kVK_ANSI_Keypad5: return "keypad 5";
            case kVK_ANSI_Keypad6: return "keypad 6";
            case kVK_ANSI_Keypad7: return "keypad 7";
            case kVK_ANSI_Keypad8: return "keypad 8";
            case kVK_ANSI_Keypad9: return "keypad 9";
            case kVK_Return: return "return";
            case kVK_Tab: return "tab";
            case kVK_Space: return "space";
            case kVK_Delete: return "delete";
            case kVK_Escape: return "esc";
            case kVK_Command: return "command";
            case kVK_Shift: return "shift";
            case kVK_CapsLock: return "caps";
            case kVK_Option: return "option";
            case kVK_Control: return "control";
            case kVK_RightCommand: return "right command";
            case kVK_RightShift: return "right shift";
            case kVK_RightOption: return "right option";
            case kVK_RightControl: return "right control";
            case kVK_Function: return "fn";
            case kVK_F17: return "F17";
            case kVK_VolumeUp: return "volume up";
            case kVK_VolumeDown: return "volume down";
            case kVK_Mute: return "mute";
            case kVK_F18: return "F18";
            case kVK_F19: return "F19";
            case kVK_F20: return "F20";
            case kVK_F5: return "F5";
            case kVK_F6: return "F6";
            case kVK_F7: return "F7";
            case kVK_F3: return "F3";
            case kVK_F8: return "F8";
            case kVK_F9: return "F9";
            case kVK_F11: return "F11";
            case kVK_F13: return "F13";
            case kVK_F16: return "F16";
            case kVK_F14: return "F14";
            case kVK_F10: return "F10";
            case kVK_F12: return "F12";
            case kVK_F15: return "F15";
            case kVK_Help: return "help";
            case kVK_Home: return "home";
            case kVK_PageUp: return "page up";
            case kVK_ForwardDelete: return "forward delete";
            case kVK_F4: return "F4";
            case kVK_End: return "end";
            case kVK_F2: return "F2";
            case kVK_PageDown: return "page down";
            case kVK_F1: return "F1";
            case kVK_LeftArrow: return "left arrow";
            case kVK_RightArrow: return "right arrow";
            case kVK_DownArrow: return "down arrow";
            case kVK_UpArrow: return "up arrow";
            case kVK_ISO_Section: return "section";
            case kVK_JIS_Yen: return "yen";
            case kVK_JIS_Underscore: return "_";
            case kVK_JIS_KeypadComma: return "keypad ,";
            case kVK_JIS_Eisu: return "eisu";
            case kVK_JIS_Kana: return "kana";
        }
        return "<unknown>";
    }
}