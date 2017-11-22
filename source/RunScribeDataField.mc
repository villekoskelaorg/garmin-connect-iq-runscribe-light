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
using Toybox.FitContributor as Fit;

class RunScribeDataField extends Ui.DataField {

    hidden var mMetricTypes = [];  // 0 - Impact GS, 1 - Braking GS, 2 - FS Type, 3 - Pronation, 4 - Flight Ratio, 5 - Contact Time, 6 - Power

    hidden var mMetricCount = 0;
    hidden var mVisibleMetrics;

    hidden var mVisibleMetricCount;
    hidden var mFullScreen;

    // Common
    hidden var mMetricTitleY;
    hidden var mMetricValueY;
    hidden var mMetricValueOffsetX;
        
    // Font values
    hidden var mDataFont;
    hidden var mDataFontHeight;
    
    hidden var mCurrentLapFont;
    hidden var mCurrentLapFontHeight;
    
    hidden var mPreviousLapFont;
    hidden var mPreviousLapFontHeight;
    
    var mSensorLeft;
    var mSensorRight;
    
    hidden var mScreenShape;
    hidden var mScreenHeight;
    
    hidden var xCenter;
    hidden var yCenter;
    
    hidden var mUpdateLayout = 0;
    
    // FIT Contributions variables
    hidden var mMetricContributorsLeft = [];
    hidden var mMetricContributorsRight = [];

    hidden var mPowerContributor;
    
    // Uber screen
    hidden var mUpdatesPerValue = 5;
    
    hidden var mValues = [];

    hidden var mUpdateCount = 0;
    hidden var mLapUpdateCount = 0;
         
    hidden var mCurrentLaps = [0.0, 0.0];
    
    hidden var mPreviousLapLeft = 0.0;
    hidden var mPreviousLapRight = 0.0;
    
    
    // Constructor
    function initialize(sensorL, sensorR, screenShape, screenHeight) {
        DataField.initialize();
        
        mScreenShape = screenShape;
        mScreenHeight = screenHeight;
        
        // Reads what metrics chosen and removes duplicate metrics
        onSettingsChanged();
        
        mSensorLeft = sensorL;
        mSensorRight = sensorR;

        // Uber
        var valuesLeft = [];
        var valuesRight = [];
        
        for (var i = 0; i < 16; ++i) {
            valuesLeft.add(0.0);
            valuesRight.add(0.0);
        }
        
        mValues.add(valuesLeft);
        mValues.add(valuesRight);
    }
    
    function onSettingsChanged() {
        var app = App.getApp();
        var metricCount = mMetricCount;
        
        if (mMetricContributorsLeft.size() == 0 && mPowerContributor == null) {
            metricCount = 0;
            mMetricTypes = [];
            var filter = 0;
            var name = "tM";

            for (var i = 0; i < 4; ++i) {
                var metricType = app.getProperty(name + (i + 1));
                var metricFilter = 1 << metricType;
                
                if (filter & metricFilter == 0) {
                    mMetricTypes.add(metricType);
                    ++metricCount;
                    filter = filter | metricFilter;
                }
            }
            
            mMetricCount = metricCount;
        }
        
        mVisibleMetrics = app.getProperty("vM");
        if (metricCount < mVisibleMetrics) {
            mVisibleMetrics = metricCount;
        }

        // Uber        
        mUpdatesPerValue = app.getProperty("tLI");
        mUpdateCount = 0;
        mLapUpdateCount = 0;   
        
        mUpdateLayout = 1;
    }
    
    function onTimerStart() {
        // Uber
        onTimerLap();    
    }
    
    
    function onTimerLap() {
        // Uber
        mPreviousLapLeft = mCurrentLaps[0];
        mPreviousLapRight = mCurrentLaps[1];
        
        mLapUpdateCount = 0;
        
        var d = {};
        var units = "units";

        var hasPower = 0;
        
        if (mMetricContributorsLeft.size() == 0 && mPowerContributor == null) {
            for (var i = 0; i < mMetricTypes.size(); ++i) {
                var metricType = mMetricTypes[i]; 
                if (metricType < 6) {
                    d[units] = getMetricUnit(metricType);
                    mMetricContributorsLeft.add(createField("", metricType, Fit.DATA_TYPE_FLOAT, d));
                    mMetricContributorsRight.add(createField("", metricType + 6, Fit.DATA_TYPE_FLOAT, d));
                } else {
                    hasPower = 1;
                }
            }
    
            if (hasPower > 0) {
                d[units] = "W";
                mPowerContributor = createField("", 12, Fit.DATA_TYPE_FLOAT, d);
            }
        }        
    }    
        
    function updateMetrics(sensor, contributors, index) {
    
        if (!sensor.isChannelOpen) {
            sensor.openChannel();
        }
       
        sensor.idleTime++;
        if (sensor.idleTime > 30) {
            sensor.closeChannel();
        }
    
        for (var i = 0; i < contributors.size(); ++i) {
            if (contributors[i] != null) {
                contributors[i].setData(sensor.data[mMetricTypes[i]]);
            }
        }

        // Uber        
        var slotIndex = (mUpdateCount / mUpdatesPerValue) % 16;
        var updateOffset = (mUpdateCount % mUpdatesPerValue) * 1.0;
        var updateOffsetPlusOne = updateOffset + 1.0;
        
        var value = sensor.data[mMetricTypes[0]] * 1.0;

        var values = mValues[index]; 
        values[slotIndex] = values[slotIndex] * (updateOffset / updateOffsetPlusOne) + value / updateOffsetPlusOne;
        
        updateOffset = mLapUpdateCount * 1.0;
        updateOffsetPlusOne = updateOffset + 1.0;

        mCurrentLaps[index] = mCurrentLaps[index] * (updateOffset / updateOffsetPlusOne) + value / updateOffsetPlusOne;
    }
    
    function compute(info) {
    
        //System.print(System.getSystemStats().usedMemory + ":");
    
        var power = 0.0;
        var sensorCount = 0;
        
        var sensorLeft = mSensorLeft;
        var sensorRight = mSensorRight;
    
        if (sensorLeft != null) {
            updateMetrics(sensorLeft, mMetricContributorsLeft, 0);
            power = sensorLeft.data[6];
            ++sensorCount;
        }

        if (sensorRight != null) {
            updateMetrics(sensorRight, mMetricContributorsRight, 1);
            power += sensorRight.data[6];
            ++sensorCount;
        }

        ++mUpdateCount;
        ++mLapUpdateCount;
                
        if (mPowerContributor != null && sensorCount > 0) {
            mPowerContributor.setData(power / sensorCount);
        }
    }

    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        var visibleMetricCount = mVisibleMetrics;
        mFullScreen = 1;
        
        if (height < mScreenHeight) {
            visibleMetricCount = 1;
            mFullScreen = 0;
        }
        
        xCenter = width / 2;
        yCenter = height / 2;
                
        mMetricValueOffsetX = dc.getTextWidthInPixels(" ", Gfx.FONT_XTINY) + 2;

        // Compute data width/height for horizintal layouts
        var metricNameFontHeight = dc.getFontHeight(Gfx.FONT_XTINY) + 2;
        if (visibleMetricCount == 2) {
            width *= 1.6;
        } else if (visibleMetricCount == 1) {
            width *= 2.0;
        }
        
        mVisibleMetricCount = visibleMetricCount;

        var font = selectFont(dc, width * 0.225, "00.0-");       
        mDataFontHeight = dc.getFontHeight(font);    
        mDataFont = font;
    
        font = selectFont(dc, width * 0.1, "00.0");
        mCurrentLapFontHeight = dc.getFontHeight(font) * 0.5;
        mCurrentLapFont = font;

        font = selectFont(dc, width * 0.075, "00.0");
        mPreviousLapFontHeight = dc.getFontHeight(font) * 0.5;
        mPreviousLapFont = font;    
            
        var metricTitleY = -(mDataFontHeight + metricNameFontHeight) * 0.5;
        if (mScreenShape == System.SCREEN_SHAPE_ROUND) {
            metricTitleY *= 1.1;
        } 
        
        mMetricValueY = metricTitleY + metricNameFontHeight;
        mMetricTitleY = metricTitleY;
        
        mUpdateLayout = 0;
    }
    
    hidden function selectFont(dc, width, testString) {
        var fontIdx;
        var dimensions;
        
        var fonts = [Gfx.FONT_XTINY, Gfx.FONT_TINY, Gfx.FONT_SMALL, Gfx.FONT_MEDIUM, Gfx.FONT_LARGE,
                    Gfx.FONT_NUMBER_MILD, Gfx.FONT_NUMBER_MEDIUM, Gfx.FONT_NUMBER_HOT, Gfx.FONT_NUMBER_THAI_HOT];
                     
        //Search through fonts from biggest to smallest
        for (fontIdx = 8; fontIdx > 0; --fontIdx) {
            dimensions = dc.getTextDimensions(testString, fonts[fontIdx]);
            if ((dimensions[0] <= width)) {
                // If this font fits, it is the biggest one that does
                break;
            }
        }
        
        return fonts[fontIdx];
    }
    
    hidden function getMetricName(metricType) {
        if (metricType == 0) {
            return "Impact";
        } 
        if (metricType == 1) {
            return "Braking";
        } 
        if (metricType == 2) {
            return "Footstrike";
        } 
        if (metricType == 3) {
            return "Pronation";
        } 
        if (metricType == 4) {
            return "Flight (%)";
        } 
        if (metricType == 5) {
            return "GCT (ms)";
        } 
        if (metricType == 6) {
            return "Power (W)";
        }
        
        return null;
    }
    
    hidden function getMetricUnit(metricType) {
        if (metricType < 2) {
            return "G";
        } 
        if (metricType == 2) {
            return "";
        } 
        if (metricType == 3) {
            return "D";
        } 
        if (metricType == 4) {
            return "%";
        } 
        if (metricType == 5) {
            return "ms";
        } 
        
        return null;
    }
    
        
    hidden function getMetric(metricType, sensor) {
        var data = sensor.data[metricType];
        
        if (metricType == 2 || metricType == 5) {
            return data.format("%d");
        }
        
        return data.format("%.1f");
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
        
        if (mUpdateLayout != 0) {
            onLayout(dc);
        }

        var metX = xCenter;
        var centerY = yCenter;

        var sensorLeft = mSensorLeft;
        var sensorRight = mSensorRight;
        var screenShape = mScreenShape;

        // Update status
        if ((sensorLeft != null && sensorRight != null) && (sensorRight.searching == 0 || sensorLeft.searching == 0)) {
            
            var visibleMetricCount = mVisibleMetricCount;
            var met1y, met2y = 0, met3y = 0;
            var yOffset = centerY * 0.55;
        
            if (screenShape == System.SCREEN_SHAPE_SEMI_ROUND) {
                yOffset *= 1.15;
            }
            if (screenShape == System.SCREEN_SHAPE_RECTANGLE) {
                yOffset *= 1.35;
            }
        
            if (visibleMetricCount == 1) {
                met1y = centerY;
            }
            else if (visibleMetricCount == 2) {
                met1y = centerY - yOffset * 0.6;
                met2y = centerY + yOffset * 0.6;
            } else { 
                met1y = centerY - yOffset;
                met2y = centerY;
                met3y = centerY + yOffset;  
            }
            
            var metricTypes = mMetricTypes;
            var firstMetric = metricTypes[0];
            
            if (visibleMetricCount == 1 && firstMetric != 6 && mFullScreen) {
                drawSingleMetric(dc, metX, met1y, firstMetric);
            }
            else {
                drawMetricOffset(dc, metX, met1y, firstMetric, 0);
                if (visibleMetricCount >= 2) {         
                    drawMetricOffset(dc, metX, met2y, metricTypes[1], 0);
                    if (visibleMetricCount >= 3) {
                        drawMetricOffset(dc, metX, met3y, metricTypes[2], 0);
                    } 
                }
            }
        } else {
            var message = "Searching(1.30)...";
            if (sensorLeft == null || sensorRight == null) {
                message = "No Channel!";
            }
            
            dc.drawText(metX, centerY - dc.getFontHeight(Gfx.FONT_MEDIUM) / 2, Gfx.FONT_MEDIUM, message, Gfx.TEXT_JUSTIFY_CENTER);
        }        
    }

    hidden function drawMetricOffset(dc, x, y, metricType, titleOffset) {
    
        var metricLeft = getMetric(metricType, mSensorLeft);
        var metricRight = getMetric(metricType, mSensorRight);
        
        if (titleOffset == 0) {
            titleOffset = mMetricTitleY;
        }

        dc.drawText(x, y + titleOffset, Gfx.FONT_XTINY, getMetricName(metricType), Gfx.TEXT_JUSTIFY_CENTER);
        
        var metricValueY = y + mMetricValueY;
        var dataFont = mDataFont;
        
        if (metricType == 6) {
            // Power metric presents a single value
            dc.drawText(x, metricValueY, dataFont, ((mSensorLeft.data[6] + mSensorRight.data[6]) / 2).format("%d"), Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(x - mMetricValueOffsetX, metricValueY, dataFont, metricLeft, Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x + mMetricValueOffsetX, metricValueY, dataFont, metricRight, Gfx.TEXT_JUSTIFY_LEFT);
            
            // Draw line
            dc.drawLine(x, metricValueY, x, metricValueY + mDataFontHeight);
        }    
    }
    
    // Uber
    hidden function drawSingleMetric(dc, x, y, metricType) {
    
        var format = "%.1f";

        if (metricType == 2 || metricType == 5) {
            format = "%d";
        }

        var yDelta = yCenter;

        if (mScreenShape != System.SCREEN_SHAPE_SEMI_ROUND) {
            yDelta *= 0.85;
        }   
        
        var xMargin = 0.04;
        if (mScreenShape == System.SCREEN_SHAPE_ROUND) {
           xMargin = 0.025;
        }

        drawMetricOffset(dc, x, y, metricType, -yDelta * 0.98);
        
        // Draw line
        dc.drawLine(x, y + yDelta * 0.8, x, y - yDelta * 0.7);
         
        if (dc.getHeight() == mScreenHeight) {
        
            //dc.drawText(x, y - yDelta * 0.98, Gfx.FONT_XTINY, getMetricName(metricType), Gfx.TEXT_JUSTIFY_CENTER);
        
            var deltaX1 = xCenter * (0.48 + xMargin);
            var deltaX2 = xCenter * (0.48 - xMargin);
            var deltaY = yDelta * 0.48;
    
            dc.drawText(x - deltaX1, y - deltaY - mPreviousLapFontHeight, mPreviousLapFont, mPreviousLapLeft.format(format), Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x - deltaX2, y - deltaY - mCurrentLapFontHeight, mCurrentLapFont, mCurrentLaps[0].format(format), Gfx.TEXT_JUSTIFY_LEFT);
    
            dc.drawText(x + deltaX2, y - deltaY - mCurrentLapFontHeight, mCurrentLapFont, mCurrentLaps[1].format(format), Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x + deltaX1, y - deltaY - mPreviousLapFontHeight, mPreviousLapFont, mPreviousLapRight.format(format), Gfx.TEXT_JUSTIFY_LEFT);
    
            drawTrendLine(dc, x - xCenter * 0.7, y + yDelta * 0.7, 0, mUpdateCount);
            drawTrendLine(dc, x + xCenter * 0.1, y + yDelta * 0.7, 1, mUpdateCount);
        }
    }    
    
    hidden function drawTrendLine(dc, x, y, index, updateCount) {
        var startIndex = 0;
        var limit = 16 - 1;
        
        var step = updateCount / mUpdatesPerValue; 
        
        if (step >= 16) {
            startIndex = (1 + step) % 16;  
        } else {
            limit = step;
        }
        
        var index = startIndex;
        
        var values = mValues[index];
        var min = values[index];
        var max = values[index];
        
        for (var i = 1; i < limit; ++i) {
            index = (i + startIndex) % 16;
            var value = values[index];
            if (value < min) {
                min = value;
            }
            if (value > max) {
                max = value;
            }
        }
        
        var delta = max - min;
        if (delta == 0) {
            delta = 1;
        }
        
        var deltaX = (xCenter * 0.6 / 15);
        var deltaY = yCenter * 0.3 / delta;

        limit -= 1; 
        
        for (var i = startIndex; i < startIndex + limit; ++i) {
            var start = (values[i % 16] * 1.0 - min);
            var end = (values[(i + 1) % 16] * 1.0 - min);
            
            dc.drawLine(x, y - deltaY * start, x + deltaX, y - deltaY * end);
            x += deltaX;
        }        
    }    
}
