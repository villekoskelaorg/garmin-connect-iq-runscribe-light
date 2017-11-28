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

    hidden var mVisibleMetrics;
    hidden var mVisibleMetricCount;
    hidden var mMetricOffset;

    // Common
    hidden var mMetricTitleY;
    hidden var mMetricValueY;
        
    // Font values
    hidden var mDataFont;
    hidden var mDataFontHeight;
    
    hidden var mCurrentLapFont;
    hidden var mPreviousLapFont;
    
    var mSensorLeft;
    var mSensorRight;
    
    hidden var mScreenShape;
    hidden var mScreenHeight;
    
    hidden var mCenterX;
    hidden var mCenterY;
    
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
        
        for (var i = 0; i < 32; ++i) {
            valuesLeft.add(0.0);
            valuesRight.add(0.0);
        }
        
        mValues.add(valuesLeft);
        mValues.add(valuesRight);
    }
    
    function onSettingsChanged() {
        var app = App.getApp();
        var metricCount = mMetricTypes.size();
        
        // Read the metric types only once since contributors are created based on what selected
        if (metricCount == 0) {

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
            
            var d = {};
            var units = "units";
            var hasPower = 0;
            
            for (var i = 0; i < mMetricTypes.size(); ++i) {
                var metricType = mMetricTypes[i]; 
                if (metricType < 6) {
                    d[units] = "";
                    if (metricType < 2) {
                        d[units] = "G";
                    } 
                    if (metricType == 3) {
                        d[units] = "D";
                    } 
                    if (metricType == 4) {
                        d[units] = "%";
                    } 
                    if (metricType == 5) {
                        d[units] = "ms";
                    } 
                
                    var metricName = getMetricName(metricType);
                    mMetricContributorsLeft.add(createField(metricName + "_L", metricType, Fit.DATA_TYPE_FLOAT, d));
                    mMetricContributorsRight.add(createField(metricName + "_R", metricType + 6, Fit.DATA_TYPE_FLOAT, d));
                } else {
                    hasPower = 1;
                }
            }
    
            if (hasPower > 0) {
                d[units] = "W";
                mPowerContributor = createField("Power", 12, Fit.DATA_TYPE_FLOAT, d);
            }
        }
        
        // Visible metric can be edited also later
        mVisibleMetrics = app.getProperty("vM");
        if (metricCount < mVisibleMetrics) {
            mVisibleMetrics = metricCount;
        }

        mMetricOffset = (app.getProperty("fM") - 1) % metricCount;

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
    }    
        
    function updateMetrics(sensor, contributors, index) {
    
        // openChannel has check for not opening if not needed. 
        sensor.openChannel();
       
        sensor.idleTime++;
        if (sensor.idleTime > 30) {
            sensor.closeChannel();
        }
        
        var metricTypes = mMetricTypes;
        var contributorIndex = 0;

        // Skip the power metric - different contributor        
        for (var i = 0; i < metricTypes.size(); ++i) {
            var metricType = metricTypes[i];
            if (metricType < 6) {
                contributors[contributorIndex].setData(sensor.data[metricType]);
                ++contributorIndex;
            }
        }

        // Uber        
        var slotIndex = (mUpdateCount / mUpdatesPerValue) % 32;
        var updateOffset = (mUpdateCount % mUpdatesPerValue) * 1.0;
        var updateOffsetPlusOne = updateOffset + 1.0;
        
        var value = sensor.data[metricTypes[mMetricOffset]] * 1.0;

        var values = mValues[index]; 
        values[slotIndex] = (values[slotIndex] * updateOffset + value) / updateOffsetPlusOne;
        
        updateOffset = mLapUpdateCount * 1.0;
        updateOffsetPlusOne = updateOffset + 1.0;

        mCurrentLaps[index] = (mCurrentLaps[index] * updateOffset + value) / updateOffsetPlusOne;
    }
    
    function compute(info) {
    
        //System.print(System.getSystemStats().usedMemory + ":");
    
        var power = 0;
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
        
        if (height < mScreenHeight) {
            visibleMetricCount = 1;
        }
        
        mCenterX = width / 2;
        mCenterY = height / 2;
                
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
        mCurrentLapFont = font;

        font = selectFont(dc, width * 0.075, "00.0");
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
            return "Flight";
        } 
        if (metricType == 5) {
            return "GCT";
        } 
        if (metricType == 6) {
            return "Power";
        }
        
        return null;
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

        var metX = mCenterX;
        var centerY = mCenterY;

        var sensorLeft = mSensorLeft;
        var sensorRight = mSensorRight;
        var screenShape = mScreenShape;

        // Update status - both sensors are either null or not null
        if ((sensorLeft != null) && (sensorRight.searching * sensorLeft.searching == 0)) {
            var metricTypes = mMetricTypes;
            var metricOffset = mMetricOffset;
            var metricCount = metricTypes.size();
            
            var firstMetric = metricTypes[metricOffset];
            
            var visibleMetricCount = mVisibleMetricCount;
            var met1y, met2y = 0;
            var yOffset = centerY * 0.55;
        
            if (screenShape == System.SCREEN_SHAPE_SEMI_ROUND || screenShape == System.SCREEN_SHAPE_RECTANGLE) {
                yOffset *= 1.15;
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

                drawMetricOffset(dc, metX, centerY + yOffset, metricTypes[(visibleMetricCount - 1 + metricOffset) % metricCount], 0);
            }
            
            if (visibleMetricCount == 1 && firstMetric != 6 && dc.getHeight() == mScreenHeight) {
                drawSingleMetric(dc, metX, met1y, firstMetric);
            }
            else {
                drawMetricOffset(dc, metX, met1y, firstMetric, 0);
                if (visibleMetricCount >= 2) {
                    var deltaX = 0;
                    if (visibleMetricCount > 3)
                    {
                        deltaX = mCenterX * 0.5;
                    }         
                    
                    drawMetricOffset(dc, metX - deltaX, met2y, metricTypes[(1 + metricOffset) % metricCount], 0);
                    if (visibleMetricCount > 3)
                    {
                        drawMetricOffset(dc, metX + deltaX, met2y, metricTypes[(2 + metricOffset) % metricCount], 0);
                    }
                }
            }
        } else {
            var message = "Searching (1.00)...";
            if (sensorLeft == null) {
                message = "No Channel!";
            }
            
            dc.drawText(metX, centerY - dc.getFontHeight(Gfx.FONT_MEDIUM) / 2, Gfx.FONT_MEDIUM, message, Gfx.TEXT_JUSTIFY_CENTER);
        }        
    }

    hidden function drawMetricOffset(dc, x, y, metricType, titleOffset) {
        if (titleOffset == 0) {
            titleOffset = mMetricTitleY;
        }

        dc.drawText(x, y + titleOffset, Gfx.FONT_XTINY, getMetricName(metricType), Gfx.TEXT_JUSTIFY_CENTER);
        
        var metricValueY = y + mMetricValueY;
        var dataFont = mDataFont;

        var format = "%.1f";        
        if (metricType == 2 || metricType == 5) {
            format = "%d";
        }
        
        var dataLeft = mSensorLeft.data;
        var dataRight = mSensorRight.data;
        
        if (metricType == 6) {
            // Power metric presents a single value
            dc.drawText(x, metricValueY, dataFont, ((dataLeft[6] + dataRight[6]) / 2).format(format), Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(x - 8, metricValueY, dataFont, dataLeft[metricType].format(format), Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x + 8, metricValueY, dataFont, dataRight[metricType].format(format), Gfx.TEXT_JUSTIFY_LEFT);
            
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

        var yDelta = mCenterY;

        if (mScreenShape == System.SCREEN_SHAPE_ROUND) {
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
            var deltaX1 = mCenterX * (0.48 + xMargin);
            var deltaX2 = mCenterX * (0.48 - xMargin);
            var deltaY = yDelta * 0.48;
    
            var previousLapFontHeight = dc.getFontHeight(mPreviousLapFont) * 0.5;
            var currentLapFontHeight = dc.getFontHeight(mCurrentLapFont) * 0.5;
    
            dc.drawText(x - deltaX1, y - deltaY - previousLapFontHeight, mPreviousLapFont, mPreviousLapLeft.format(format), Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x - deltaX2, y - deltaY - currentLapFontHeight, mCurrentLapFont, mCurrentLaps[0].format(format), Gfx.TEXT_JUSTIFY_LEFT);
    
            dc.drawText(x + deltaX2, y - deltaY - currentLapFontHeight, mCurrentLapFont, mCurrentLaps[1].format(format), Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x + deltaX1, y - deltaY - previousLapFontHeight, mPreviousLapFont, mPreviousLapRight.format(format), Gfx.TEXT_JUSTIFY_LEFT);
    
            drawTrendLine(dc, x - mCenterX * 0.65, y + yDelta * 0.8, 0, mUpdateCount);
            drawTrendLine(dc, x + mCenterX * 0.1, y + yDelta * 0.8, 1, mUpdateCount);
        }
    }    
    
    hidden function drawTrendLine(dc, x, y, sensorIndex, updateCount) {
        var startIndex = 0;
        var limit = 32 - 1;
        
        var step = updateCount / mUpdatesPerValue; 
        
        if (step >= 32) {
            startIndex = (1 + step) % 32;  
        } else {
            limit = step;
        }
        
        var index = startIndex;
        
        var values = mValues[sensorIndex];
        var min = values[index];
        var max = values[index];
        
        for (var i = 1; i < limit; ++i) {
            index = (i + startIndex) % 32;
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
        
        var deltaX = (mCenterX * 0.55 / (32 - 1));
        var deltaY = mCenterY * 0.3 / delta;

        limit -= 1; 
        
        for (var i = startIndex; i < startIndex + limit; ++i) {
            var start = (values[i % 32] * 1.0 - min);
            var end = (values[(i + 1) % 32] * 1.0 - min);
            
            dc.drawLine(x, y - deltaY * start, x + deltaX, y - deltaY * end);
            x += deltaX;
        }        
    }    
}
