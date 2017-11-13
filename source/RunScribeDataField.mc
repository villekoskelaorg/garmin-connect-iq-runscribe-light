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

    var mSensorLeft;
    var mSensorRight;
    
    hidden var mMetricType; // 1 - Impact GS, 2 - Braking GS, 3 - FS Type, 4 - Pronation, 5 - Flight Ratio, 6 - Contact Time
    hidden var mMesgPeriod;

    // Common
    hidden var mMetricValueY;
    hidden var mMetricValueOffsetX;
        
    // Font values
    hidden var mDataFont;
    hidden var mDataFontHeight;
    
    hidden var mCurrentLapFont;
    hidden var mCurrentLapFontHeight;
    
    hidden var mPreviousLapFont;
    hidden var mPreviousLapFontHeight;
    
    hidden var mMetricNameFontHeight;
    
    hidden var mScreenShape;
    hidden var mScreenHeight;
    
    hidden var xCenter;
    hidden var yCenter;
    
    hidden var mUpdateLayout = 0;
    
    // FIT Contributions variables
    hidden var mFieldLeft;
    hidden var mFieldRight;

    hidden var mUpdateCountLeft = 0;
    hidden var mUpdateCountRight = 0;

    hidden var mLapUpdateCountLeft = 0;
    hidden var mLapUpdateCountRight = 0;

    hidden var mUpdatesPerValue = 5;
    hidden var mValueCount = 16;
    
    hidden var mValuesLeft;
    hidden var mValuesRight;
    
    hidden var mCurrentLapLeft = 0.0;
    hidden var mCurrentLapRight = 0.0;
    hidden var mPreviousLapLeft = 0.0;
    hidden var mPreviousLapRight = 0.0;
    
    // Constructor
    function initialize(screenShape, screenHeight) {
        DataField.initialize();
        
        mScreenShape = screenShape;
        mScreenHeight = screenHeight;
        
        mValuesLeft = [];
        mValuesRight = [];
        
        for (var i = 0; i < mValueCount; ++i) {
            mValuesLeft.add(0.0);
            mValuesRight.add(0.0);
        }
        
        onSettingsChanged();        
    }
    
    function onTimerStart() {
        if (mFieldLeft == null && mFieldRight == null) {
            var d = {};
            var units = "units";
            
            var metricName = getMetricName(mMetricType);
    
            if (mMetricType == 1 || mMetricType == 2) {
                d[units] = "G";
               } else if (mMetricType == 4) {
                   d[units] = "D";
               } else if (mMetricType == 5) {
                   d[units] = "%";
               } else if (mMetricType == 6) {
                   d[units] = "ms";
               }      
               
            mFieldLeft = createField(metricName + "_Left", mMetricType - 1, Fit.DATA_TYPE_FLOAT, d);
            mFieldRight = createField(metricName + "_Right", mMetricType - 1 + 6, Fit.DATA_TYPE_FLOAT, d);
        }    
        
        onTimerLap();    
    }

    function onTimerLap() {
        mPreviousLapLeft = mCurrentLapLeft;
        mPreviousLapRight = mCurrentLapRight;
        
        mLapUpdateCountLeft = 0;
        mLapUpdateCountRight = 0;
    }    
    
    function onSettingsChanged() {
        var app = App.getApp();
        
        var antRate = app.getProperty("antRate");
        mMesgPeriod = 8192 >> antRate;        
        
        if (mFieldLeft == null && mFieldRight == null) {
            var metricType = app.getProperty("typeMetric");
            if (mMetricType != metricType) {
                mMetricType = metricType;
                mUpdateCountLeft = 0;
                mUpdateCountRight = 0;
                mLapUpdateCountLeft = 0;
                mLapUpdateCountRight = 0;
            }
        }
        
        var updatesPerSlot = app.getProperty("trendLineInterval");
        if (mUpdatesPerValue != updatesPerSlot) {
            mUpdatesPerValue = updatesPerSlot;
            mUpdateCountLeft = 0;
            mUpdateCountRight = 0;            
        }
        
        mUpdateLayout = 1;
    }
    
    function compute(info) {
    
        var slotIndex = 0;
        var updateOffset = 0.0;
         var value = 0.0;
 
        if (mSensorLeft == null || !mSensorLeft.isChannelOpen) {
            if (mSensorLeft != null) {
                mSensorLeft = null;
            } else {
                try {
                    mSensorLeft = new RunScribeSensor(11, 62, mMesgPeriod);
                } catch(e) {
                    mSensorLeft = null;
                }
           }
        } else {

            ++mSensorLeft.idleTime;
            if (mSensorLeft.idleTime > 10) {
                mSensorLeft.closeChannel();
            }
            
            slotIndex = (mUpdateCountLeft / mUpdatesPerValue) % mValueCount;
            updateOffset = (mUpdateCountLeft % mUpdatesPerValue) * 1.0;
            ++mUpdateCountLeft;
            
            value = getMetricValue(mMetricType, mSensorLeft);
            mValuesLeft[slotIndex] = mValuesLeft[slotIndex] * (updateOffset / (updateOffset + 1.0)); 
            mValuesLeft[slotIndex] += (value * 1.0) / (updateOffset + 1.0);
            
            updateOffset = mLapUpdateCountLeft * 1.0;
            ++mLapUpdateCountLeft;

            mCurrentLapLeft = mCurrentLapLeft * (updateOffset / (updateOffset + 1.0));
            mCurrentLapLeft += (value * 1.0) / (updateOffset + 1.0);
            
            if (mFieldLeft != null) {
                mFieldLeft.setData(value);
            }
        }
        
        if (mSensorRight == null || !mSensorRight.isChannelOpen) {
            if (mSensorRight != null) {
                mSensorRight = null;
            } else {
                try {
                    mSensorRight = new RunScribeSensor(12, 64, mMesgPeriod);
                } catch(e) {
                    mSensorRight = null;
                }
            }
        } else {

            ++mSensorRight.idleTime;
            if (mSensorRight.idleTime > 8) {
                mSensorRight.closeChannel();
            }
            
            slotIndex = (mUpdateCountRight / mUpdatesPerValue) % mValueCount;
            updateOffset = (mUpdateCountRight % mUpdatesPerValue) * 1.0;
            ++mUpdateCountRight;
            
            value = getMetricValue(mMetricType, mSensorRight) * 1.0;
            mValuesRight[slotIndex] = mValuesRight[slotIndex] * (updateOffset / (updateOffset + 1.0)); 
            mValuesRight[slotIndex] += ((value * 1.0) / (updateOffset + 1.0));
            
            updateOffset = mLapUpdateCountRight * 1.0;
            ++mLapUpdateCountRight;

            mCurrentLapRight = mCurrentLapRight * (updateOffset / (updateOffset + 1.0));
            mCurrentLapRight += (value * 1.0) / (updateOffset + 1.0);
            
            if (mFieldRight != null) {
                mFieldRight.setData(value);
            }
        }
    }

    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        xCenter = width / 2;
        yCenter = height / 2;
                     
        mMetricValueOffsetX = dc.getTextWidthInPixels(" ", Gfx.FONT_XTINY) + 2;

        // Compute data width/height for horizintal layouts
        mMetricNameFontHeight = dc.getFontHeight(Gfx.FONT_XTINY) + 2;

        mDataFont = selectFont(dc, width * 0.45, height, "00.0-");
            
        mDataFontHeight = dc.getFontHeight(mDataFont);    
            
        mCurrentLapFont = selectFont(dc, width * 0.2, height, "00.0");
        mCurrentLapFontHeight = dc.getFontHeight(mCurrentLapFont);

        mPreviousLapFont = selectFont(dc, width * 0.15, height, "00.0");
        mPreviousLapFontHeight = dc.getFontHeight(mPreviousLapFont);
            
        mMetricValueY = -mDataFontHeight * 0.5;
        
        mUpdateLayout = 0;
    }
    
    hidden function selectFont(dc, width, height, testString) {
        var fontIdx;
        var dimensions;
        
        var fonts = [Gfx.FONT_XTINY, Gfx.FONT_TINY, Gfx.FONT_SMALL, Gfx.FONT_MEDIUM, Gfx.FONT_LARGE,
                    Gfx.FONT_NUMBER_MILD, Gfx.FONT_NUMBER_MEDIUM, Gfx.FONT_NUMBER_HOT, Gfx.FONT_NUMBER_THAI_HOT];
                     
        //Search through fonts from biggest to smallest
        for (fontIdx = 8; fontIdx > 0; --fontIdx) {
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
            return "ImpactGs";
        } 
        if (metricType == 2) {
            return "BrakingGs";
        } 
        if (metricType == 3) {
            return "Footstrike";
        } 
        if (metricType == 4) {
            return "Pronation";
        } 
        if (metricType == 5) {
            return "FlightRatio";
        } 
        if (metricType == 6) {
            return "ContactTime";
        }
        
        return null;
    }
        
    hidden function getMetric(metricType, sensor) {
        if (sensor != null) {
            var value = getMetricValue(metricType, sensor);
            if (metricType == 3 || metricType == 6) {
                return value.format("%d");
            }
            
            return value.format("%.1f"); 
        }
        return "0";
    }

    hidden function getMetricValue(metricType, sensor) {
        if (sensor != null) {
            if (metricType == 1) {
                return sensor.impact_gs;
            } 
            if (metricType == 2) {
                return sensor.braking_gs;
            } 
            if (metricType == 3) {
                return sensor.footstrike_type;
            } 
            if (metricType == 4) {
                return sensor.pronation_excursion_fs_mp;
            } 
            if (metricType == 5) {
                return sensor.flight_ratio;
            } 
            if (metricType == 6) {
                return sensor.contact_time;
            }
        }
        
        return 0.0;
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

        // Update status
        if (mSensorLeft != null && mSensorRight != null && (mSensorRight.searching == 0 || mSensorLeft.searching == 0)) {
            drawMetricOffset(dc, xCenter, yCenter, mMetricType);         
        } else {
            var message = "Searching(1.27)...";
            if (mSensorLeft == null || mSensorRight == null) {
                message = "No Channel!";
            }
            
            dc.drawText(xCenter, yCenter - dc.getFontHeight(Gfx.FONT_MEDIUM) / 2, Gfx.FONT_MEDIUM, message, Gfx.TEXT_JUSTIFY_CENTER);
        }        
    }

    hidden function drawMetricOffset(dc, x, y, metricType) {
    
        var metricLeft = getMetric(metricType, mSensorLeft);
        var metricRight = getMetric(metricType, mSensorRight);

        var leftCurrentLap = mCurrentLapLeft.format("%.1f");
        var rightCurrentLap = mCurrentLapRight.format("%.1f");
        var leftPreviousLap = mPreviousLapLeft.format("%.1f");
        var rightPreviousLap = mPreviousLapRight.format("%.1f");

        if (metricType == 3 || metricType == 6) {
            leftCurrentLap = mCurrentLapLeft.format("%d");
            rightCurrentLap = mCurrentLapRight.format("%d");
            leftPreviousLap = mPreviousLapLeft.format("%d");
            rightPreviousLap = mPreviousLapRight.format("%d");        
        }

        dc.drawText(x - mMetricValueOffsetX, y + mMetricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(x + mMetricValueOffsetX, y + mMetricValueY, mDataFont, metricRight, Gfx.TEXT_JUSTIFY_LEFT);

        var yDelta = yCenter;

        if (mScreenShape != System.SCREEN_SHAPE_SEMI_ROUND) {
            yDelta *= 0.85;
        }   
        
        var xMargin = 0.04;
        if (mScreenShape == System.SCREEN_SHAPE_ROUND) {
           xMargin = 0.025;
        }
        
        // Draw line
        dc.drawLine(x, y + yDelta * 0.8, x, y - yDelta * 0.7);
         
        if (dc.getHeight() == mScreenHeight) {
        
            dc.drawText(x, y - yDelta * 0.98, Gfx.FONT_XTINY, getMetricName(metricType), Gfx.TEXT_JUSTIFY_CENTER);
	
	        dc.drawText(x - xCenter * (0.48 + xMargin), y - yDelta * 0.48 - mPreviousLapFontHeight * 0.5, mPreviousLapFont, leftPreviousLap, Gfx.TEXT_JUSTIFY_RIGHT);
	        dc.drawText(x - xCenter * (0.48 - xMargin), y - yDelta * 0.48 - mCurrentLapFontHeight * 0.5, mCurrentLapFont, leftCurrentLap, Gfx.TEXT_JUSTIFY_LEFT);
	
	        dc.drawText(x + xCenter * (0.48 - xMargin), y - yDelta * 0.48 - mCurrentLapFontHeight * 0.5 , mCurrentLapFont, rightCurrentLap, Gfx.TEXT_JUSTIFY_RIGHT);
	        dc.drawText(x + xCenter * (0.48 + xMargin), y - yDelta * 0.48 - mPreviousLapFontHeight * 0.5, mPreviousLapFont, rightPreviousLap, Gfx.TEXT_JUSTIFY_LEFT);
	
	        var slotIndexLeft = 0;
	        var slotIndexRight = 0;
	        var limitLeft = mValuesLeft.size() - 1;
	        var limitRight = mValuesRight.size() - 1;
	
	        if (mUpdateCountLeft / mUpdatesPerValue >= mValueCount) {
	            slotIndexLeft = 1 + (mUpdateCountLeft / mUpdatesPerValue) % mValueCount;  
	        } else {
	            limitLeft = mUpdateCountLeft / mUpdatesPerValue;
	        }
	
	        if (mUpdateCountRight / mUpdatesPerValue >= mValueCount) {
	            slotIndexRight = 1 + (mUpdateCountRight / mUpdatesPerValue) % mValueCount;  
	        } else {
	            limitRight = mUpdateCountRight / mUpdatesPerValue;
	        }
	
	        drawTrendLine(dc, x - xCenter * 0.7, y + yDelta * 0.7, mValuesLeft, slotIndexLeft, limitLeft);
	        drawTrendLine(dc, x + xCenter * 0.1, y + yDelta * 0.7, mValuesRight, slotIndexRight, limitRight);
        }
     }
    
    hidden function drawTrendLine(dc, x, y, values, startIndex, limit) {
        if (values.size() == 0) {
            return;
        }
        
        var index = startIndex % mValueCount;
        values[index] *= 1.0;
        
        var min = values[index];
        var max = values[index];
        
        for (var i = 1; i < limit; ++i) {
            index = (i + startIndex) % mValueCount;
            values[index] *= 1.0;
            if (values[index] < min) {
                min = values[index];
            }
            if (values[index] > max) {
                max = values[index];
            }
        }
        
        var delta = max - min;
        if (delta == 0) {
            delta = 1;
        }
        
        limit -= 1; 
        
        for (var i = 0; i < limit; ++i) {
            var start = (values[(i + startIndex) % mValueCount] - min) / delta;
            var end = (values[(i + 1 + startIndex) % mValueCount] - min) / delta;
            
            dc.drawLine(x + (xCenter * 0.6 / limit) * i, y - yCenter * 0.3 * start, x + (xCenter * 0.6 / limit) * (i + 1), y - yCenter * 0.3 * end);
        }        
    }
    
}
