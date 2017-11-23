//
// MIT License
//
// Copyright (c) 2017 Scribe Labs Inc
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

using Toybox.Application as App;

class RunScribeDataFieldApp extends App.AppBase {
    
    var mDataField;
    
    function initialize() {
        AppBase.initialize();
    }
    
    function getInitialView() {
        var antRate = getProperty("aR");
        
        var sensorLeft;
        var sensorRight;
        
        try {       
            sensorLeft = new RunScribeSensor(11, 62, 8192 >> antRate);
            sensorRight = new RunScribeSensor(12, 64, 8192 >> antRate);
        } catch(e) {
            sensorLeft = null;
            sensorRight = null;
        }
        
        var settings = System.getDeviceSettings();
        mDataField = new RunScribeDataField(sensorLeft, sensorRight, settings.screenShape, settings.screenHeight);
        return [mDataField];
    }
    
    function onStop(state) {
        if (mDataField.mSensorLeft != null) {
            mDataField.mSensorLeft.closeChannel();
            mDataField.mSensorRight.closeChannel();
        }
        return false;
    }
    
    function onSettingsChanged() {
        mDataField.onSettingsChanged();
    }
}
