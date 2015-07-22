#include "ofMain.h"

#include "ofxMacKeyboardEventStealer.h"

class ofApp : public ofBaseApp{
public:
    void setup() {
        ofAddListener(ofxMacKeyboardEvent, this, &ofApp::keyboardCallback);
    }
    
    void update() {
        
    }
    
    void draw() {
        ofBackground(ofColor::black);
        ofSetColor(ofColor::white);
        ofDrawBitmapString("s: start steal", 20, 40);
        ofDrawBitmapString("S: stop steal", 20, 70);
    }
    
    void keyboardCallback(ofxMacKeyboardEventArg &arg) {
        ofLogNotice() << arg << endl;
    }
    
    void keyPressed(int key) {
        if(key == 's') {
            ofxMacKeyboardStartStealKeyboardEvent();
        } else if(key == 'S') {
            ofxMacKeyboardStopStealKeyboardEvent();
        }
    }
    void keyReleased(int key) {}
    void mouseMoved(int x, int y) {}
    void mouseDragged(int x, int y, int button) {}
    void mousePressed(int x, int y, int button) {}
    void mouseReleased(int x, int y, int button) {}
    void windowResized(int w, int h) {}
    void dragEvent(ofDragInfo dragInfo) {}
    void gotMessage(ofMessage msg) {}
};

//========================================================================
int main() {
    ofSetupOpenGL(200, 200, OF_WINDOW);
    ofRunApp(new ofApp());
    
}
