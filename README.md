# ofxMacKeyboard

control keyboard with program

## Dependencies

* Security.framework

## Preparing

if you get only modifier key event, then you open "System Preference" and go "Security & Privacy", select "Privacy" tab, choise "accessibility".
and you add your app.

## API

### Control Keyboard

TODO

### Steal Keyboard Event

#### void ofxMacKeyboardStartStealKeyboardEvent(string appName = "cc.openFrameworks.ofapp");

#### void ofxMacKeyboardStopStealKeyboardEvent();

start/stop listeing callback.

#### const char * const ofxMacKeyboardConvertKeyCodeWithUSKeyboard(ofxMacKeyboardEventArg &event);

#### const char * const ofxMacKeyboardConvertKeyCodeWithJISKeyboard(ofxMacKeyboardEventArg &event);

convert to string

#### ofEvent<ofxMacKeyboardEventArg> ofxMacKeyboardEvent;

target ofEvent

#### struct ofxMacKeyboardEventArg;

	uint16_t keyCode;
	uint8_t  isModifierKey:1;
	uint8_t  isKeyDown:1;
	uint8_t  isShiftEnabled:1;
	uint8_t  isCommandEnabled:1;
	uint8_t  isOptionEnabled:1;
	uint8_t  isControlEnabled:1;
	uint8_t  isFunctionnEnabled:1;
	uint8_t  isCapsEnabled:1;

## Update history

### 2015/07/22 ver 0.01 release

## License

MIT License.

## Author

* ISHII 2bit [bufferRenaiss co., ltd.]
* ishii[at]buffer-renaiss.com

## At the last

Please create new issue, if there is a problem.
And please throw pull request, if you have a cool idea!!