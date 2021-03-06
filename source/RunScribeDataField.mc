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

using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.Graphics as Gfx;


class RunScribeDataField extends Ui.DataField {
    
    hidden var mMetricCount;
    
    // Metric 1
    hidden var mMetric1Type = 3; // 1 - Impact GS, 2 - Braking GS, 3 - FS Type, 4 - Pronation, 5 - Flight Ratio, 6 - Contact Time
    hidden var mMetric1Name;
    
    // Metric 2
    hidden var mMetric2Type = 1; // 1 - Impact GS, 2 - Braking GS, 3 - FS Type, 4 - Pronation, 5 - Flight Ratio, 6 - Contact Time
    hidden var mMetric2Name;
    
    // Metric 3
    hidden var mMetric3Type = 2; // 0 - None, 1 - Impact GS, 2 - Braking GS, 3 - FS Type, 4 - Pronation, 5 - Flight Ratio, 6 - Contact Time
    hidden var mMetric3Name;
    
    // Metric 4
    hidden var mMetric4Type = 6; // 0 - None, 1 - Impact GS, 2 - Braking GS, 3 - FS Type, 4 - Pronation, 5 - Flight Ratio, 6 - Contact Time
    hidden var mMetric4Name;
    
    // Common
    hidden var mMetricTitleY;
    hidden var mMetricValueY;
    hidden var mMetricValueOffsetX;
    
    // Fit Contributor
    hidden var mFitContributor;
    
    // Font values
    hidden var mDataFont;
    hidden var mDataFontHeight;
    
    var mSensorLeft;
    var mSensorRight;
    
    hidden var mScreenShape;
    
    hidden var xCenter;
    hidden var yCenter;
    
    // Constructor
    function initialize(sensorL, sensorR, screenShape) {
    	mScreenShape = screenShape;
        DataField.initialize();
        onSettingsChanged();
        
        mSensorLeft = sensorL;
        mSensorRight = sensorR;
    }
    
    function onSettingsChanged() {
        mMetric1Type = App.getApp().getProperty("typeMetric1");
        mMetric2Type = App.getApp().getProperty("typeMetric2");
        mMetric3Type = App.getApp().getProperty("typeMetric3");
        mMetric4Type = App.getApp().getProperty("typeMetric4");
        
        // Save memory, allow only 2-4 metrics, not 1
        if (mMetric3Type == 0) {
            mMetric3Type = mMetric4Type;
            mMetric4Type = 0;
        }
        
        if (mMetric4Type != 0) {
            mMetricCount = 4; 
        } else if (mMetric3Type != 0) {
            mMetricCount = 3;
            mMetric4Type = mMetric3Type;
            mMetric3Type = 0;
        } else {
            mMetricCount = 2;
        }
        
        mMetric1Name = getMetricName(mMetric1Type);
        mMetric2Name = getMetricName(mMetric2Type);
        mMetric3Name = getMetricName(mMetric3Type);
        mMetric4Name = getMetricName(mMetric4Type);
    }
    
    function compute(info) {
        if (mFitContributor == null) {
            mFitContributor = new RunScribeFitContributor(self);
        }
        
        mFitContributor.compute(mSensorLeft, mSensorRight);
    }
    
    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        xCenter = width / 2;
        yCenter = height / 2;
        
        mMetricValueOffsetX = dc.getTextWidthInPixels(" ", Gfx.FONT_XTINY) + 2;
        
        // Compute data width/height for horizintal layouts
       	var metricNameFontHeight = dc.getFontHeight(Gfx.FONT_XTINY);
        mDataFont = selectFont(dc, width * 0.5, height * 0.4 - metricNameFontHeight, "00.0 - 00.0");
        mDataFontHeight = dc.getFontHeight(mDataFont);    
            
        mMetricTitleY = -(height * 0.12); 
        mMetricValueY = mMetricTitleY + metricNameFontHeight;
    }
    
    hidden function selectFont(dc, width, height, testString) {
        var fontIdx;
        var dimensions;
        
        var fonts = [Gfx.FONT_XTINY,Gfx.FONT_TINY,Gfx.FONT_SMALL,Gfx.FONT_MEDIUM,Gfx.FONT_LARGE, 
        Gfx.FONT_NUMBER_MILD,Gfx.FONT_NUMBER_MEDIUM,Gfx.FONT_NUMBER_HOT,Gfx.FONT_NUMBER_THAI_HOT];
        
        // Search through fonts from biggest to smallest
        for (fontIdx = (fonts.size() - 1); fontIdx > 0; --fontIdx) {
            dimensions = dc.getTextDimensions(testString, fonts[fontIdx]);
            if ((dimensions[0] <= width) && (dimensions[1] <= height)) {
                // If this font fits, it is the biggest one that does
                break;
            }
        }
        
        return fonts[fontIdx];
    }
    
    hidden function getMetricName(metricType) {
        if (metricType == 1) {
            return "Impact Gs";
        } else if (metricType == 2) {
            return "Braking Gs";
        } else if (metricType == 3) {
            return "Footstrike";
        } else if (metricType == 4) {
            return "Pronation";
        } else if (metricType == 5) {
            return "Flight (%)";
        } else if (metricType == 6) {
            return "GCT (ms)";
        } else if (metricType == 7) {
            return "Power (W)";
        }
        
        return null;
    }
    
    hidden function getMetric(metricType, sensor) {
        var floatFormat = "%.1f";
        if (sensor != null && sensor.data != null) {
            if (metricType == 1) {
                return sensor.data.impact_gs.format(floatFormat);
            } else if (metricType == 2) {
                return sensor.data.braking_gs.format(floatFormat);
            } else if (metricType == 3) {
                return sensor.data.footstrike_type.format("%d");
            } else if (metricType == 4) {
                return sensor.data.pronation_excursion_fs_mp.format(floatFormat);
            } else if (metricType == 5) {
                return sensor.data.flight_ratio.format(floatFormat);
            } else if (metricType == 6) {
                return sensor.data.contact_time.format("%d");
            }
        }
        return "0";
    }
    
    // Handle the update event
    function onUpdate(dc) {
        var bgColor = getBackgroundColor();
        var fgColor = Gfx.COLOR_WHITE;
        
        if (bgColor == Gfx.COLOR_WHITE) {
            fgColor = Gfx.COLOR_BLACK;
        }
        
        dc.setColor(fgColor, bgColor);
        dc.clear();
        
        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        
        // Update status
        if (mSensorRight == null || mSensorLeft == null) {
            drawTextInCenter(dc, "No Channel!");
        } else if (true == mSensorRight.searching && true == mSensorLeft.searching) {
            drawTextInCenter(dc, "Searching...");
        } else {
            if (mScreenShape == System.SCREEN_SHAPE_RECTANGLE) {
                if (mMetricCount >= 3) {
                    var xOffset = xCenter * 0.5;
                    var yOffset = yCenter * 0.5;
                    
                    drawMetricOffset(dc, xCenter - xOffset, yCenter - yOffset, mMetric1Name, mMetric1Type);
                    drawMetricOffset(dc, xCenter + xOffset, yCenter - yOffset, mMetric2Name, mMetric2Type);
                    
                    if (mMetricCount == 4) {
                        drawMetricOffset(dc, xCenter - xOffset, yCenter + yOffset, mMetric3Name, mMetric3Type);  
                        drawMetricOffset(dc, xCenter + xOffset, yCenter + yOffset, mMetric4Name, mMetric4Type);
                    } else {
                        drawMetricOffset(dc, xCenter, yCenter + yOffset, mMetric4Name, mMetric4Type);  
                    }
                }
            } else if (mMetricCount >= 3) {
                drawMetricOffset(dc, xCenter, yCenter - yCenter * 0.6, mMetric1Name, mMetric1Type);
                drawMetricOffset(dc, xCenter, yCenter + yCenter * 0.6, mMetric4Name, mMetric4Type);
                
                if (mMetricCount == 4) {
                    drawMetricOffset(dc, xCenter - xCenter * 0.5, yCenter, mMetric2Name, mMetric2Type);  
                    drawMetricOffset(dc, xCenter + xCenter * 0.5, yCenter, mMetric3Name, mMetric3Type);
                } else {
                    drawMetricOffset(dc, xCenter, yCenter, mMetric2Name, mMetric2Type);  
                }
            }
            
            if (mMetricCount == 2) {
                drawMetricOffset(dc, xCenter, yCenter - yCenter * 0.4, mMetric1Name, mMetric1Type);
                drawMetricOffset(dc, xCenter, yCenter + yCenter * 0.4, mMetric2Name, mMetric2Type);
            }
        }
    }
    
    hidden function drawMetricOffset(dc, x, y, metricName, metricType) {
        var metricLeft = getMetric(metricType, mSensorLeft);
        var metricRight = getMetric(metricType, mSensorRight);
        
        if (metricType == 7) {
            metricLeft = ((mSensorLeft.data.power + mSensorRight.data.power) / 2).format("%d");
        }
        
        dc.drawText(x, y + mMetricTitleY, Gfx.FONT_XTINY, metricName, Gfx.TEXT_JUSTIFY_CENTER);
        
        if (metricType == 7) {
        	// Power metric presents a single value
        	dc.drawText(x, y + mMetricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            drawLRValues(dc, x, y + mMetricValueY, metricLeft, metricRight);
        }
    }
    
    hidden function drawTextInCenter(dc, text) {
        dc.drawText(xCenter, yCenter - dc.getFontHeight(Gfx.FONT_MEDIUM) / 2, Gfx.FONT_MEDIUM, text, Gfx.TEXT_JUSTIFY_CENTER);
    }
    
    hidden function drawLRValues(dc, metricValueX, metricValueY, metricLeft, metricRight) {
        dc.drawText(metricValueX - mMetricValueOffsetX, metricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(metricValueX + mMetricValueOffsetX, metricValueY, mDataFont, metricRight, Gfx.TEXT_JUSTIFY_LEFT);
        
        // Draw line
       	dc.drawLine(metricValueX, metricValueY, metricValueX, metricValueY + mDataFontHeight);
    }
}
