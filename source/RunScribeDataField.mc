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
    hidden var mMetricTitleY;
    hidden var mMetricValueY;
    hidden var mMetricValueOffsetX;
        
    // Font values
    hidden var mDataFont;
    hidden var mDataFontHeight;
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
	hidden var mUpdatesPerSlot = 5;
	hidden var mUpdateSlotCount = 15;
    
    hidden var mLeftSlots;
    hidden var mRightSlots;
    
    // Constructor
    function initialize(screenShape, screenHeight) {
        DataField.initialize();
        
        mScreenShape = screenShape;
        mScreenHeight = screenHeight;
        
        mLeftSlots = [];
        mRightSlots = [];
        
        for (var i = 0; i < mUpdateSlotCount; ++i) {
        	mLeftSlots.add(0.0);
        	mRightSlots.add(0.0);
        }
        
        onSettingsChanged();        

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
    
    function onSettingsChanged() {
        var app = App.getApp();
        
        var antRate = app.getProperty("antRate");
        mMesgPeriod = 8192 >> antRate;        
        
        mMetricType = app.getProperty("tM1");

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
        	
    		slotIndex = (mUpdateCountLeft / mUpdatesPerSlot) % mUpdateSlotCount;
    		updateOffset = (mUpdateCountLeft % mUpdatesPerSlot) * 1.0;
	    	++mUpdateCountLeft;
        	
        	value = getMetricValue(mMetricType, mSensorLeft);
        	mLeftSlots[slotIndex] = mLeftSlots[slotIndex] * (updateOffset / (updateOffset + 1.0)); 
        	mLeftSlots[slotIndex] += (value * 1.0) / (updateOffset + 1.0);
        	
            mFieldLeft.setData(value);
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
            if (mSensorRight.idleTime > 7) {
                mSensorRight.closeChannel();
            }
            
    		slotIndex = (mUpdateCountRight / mUpdatesPerSlot) % mUpdateSlotCount;
    		updateOffset = (mUpdateCountRight % mUpdatesPerSlot) * 1.0;
	    	++mUpdateCountRight;
            
        	value = getMetricValue(mMetricType, mSensorRight) * 1.0;
        	mRightSlots[slotIndex] = mRightSlots[slotIndex] * (updateOffset / (updateOffset + 1.0)); 
        	mRightSlots[slotIndex] = mRightSlots[slotIndex] + ((value * 1.0) / (updateOffset + 1.0));
        	
        	System.print("Value: " + value);
        	System.print("AVG: " + mRightSlots[slotIndex]);
        	
            mFieldRight.setData(value);

        }
    }

    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        
       	if (height < mScreenHeight) {
        }
        
        xCenter = width / 2;
        yCenter = height / 2;
                
        mMetricValueOffsetX = dc.getTextWidthInPixels(" ", Gfx.FONT_XTINY) + 2;

        // Compute data width/height for horizintal layouts
        mMetricNameFontHeight = dc.getFontHeight(Gfx.FONT_XTINY) + 2;
        width *= 2.0;

        mDataFont = selectFont(dc, width * 0.2225, height - mMetricNameFontHeight, "00.0-");
            
        mDataFontHeight = dc.getFontHeight(mDataFont);    
            
        mMetricTitleY = -(yCenter);
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
            
            var met1x, met1y, met2x = 0, met2y = 0, met3x = 0, met3y = 0, met4x = 0, met4y = 0;
            
            var yOffset = yCenter * 0.55;
            var xOffset = xCenter * 0.45;
        
            if (mScreenShape == System.SCREEN_SHAPE_SEMI_ROUND) {
                yOffset *= 1.15;
            }
        
            met1x = xCenter;
            met1y = yCenter;
            
            drawMetricOffset(dc, met1x, met1y, mMetricType);         
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
        
        if (metricType == 7) {
            metricLeft = ((mSensorLeft.power + mSensorRight.power) / 2).format("%d");
        }
         
        dc.drawText(x, y + mMetricTitleY, Gfx.FONT_XTINY, getMetricName(metricType), Gfx.TEXT_JUSTIFY_CENTER);

        dc.drawText(x - xCenter * 0.5, y - yCenter * 0.65, Gfx.FONT_MEDIUM, 320, Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(x - xCenter * 0.4, y - yCenter * 0.65, Gfx.FONT_MEDIUM, 321, Gfx.TEXT_JUSTIFY_LEFT);

        dc.drawText(x + xCenter * 0.5, y - yCenter * 0.65, Gfx.FONT_MEDIUM, 324, Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(x + xCenter * 0.4, y - yCenter * 0.65, Gfx.FONT_MEDIUM, 322, Gfx.TEXT_JUSTIFY_RIGHT);

        if (metricType == 7) {
            // Power metric presents a single value
            dc.drawText(x, y + mMetricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(x - mMetricValueOffsetX, y + mMetricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x + mMetricValueOffsetX, y + mMetricValueY, mDataFont, metricRight, Gfx.TEXT_JUSTIFY_LEFT);
            
            // Draw line
            dc.drawLine(x, y + yCenter * 0.8, x, y - yCenter * 0.7);
        }    
        
        var slotIndexLeft = 0;
        var slotIndexRight = 0;
        var limitLeft = mLeftSlots.size();
        var limitRight = mRightSlots.size();

        if (mUpdateCountLeft / mUpdatesPerSlot >= mUpdateSlotCount) {
        	slotIndexLeft = (mUpdateCountLeft / mUpdatesPerSlot) % mUpdateSlotCount;  
        } else {
        	limitLeft = mUpdateCountLeft / mUpdatesPerSlot;
        }

        if (mUpdateCountRight / mUpdatesPerSlot >= mUpdateSlotCount) {
        	slotIndexLeft = (mUpdateCountRight / mUpdatesPerSlot) % mUpdateSlotCount;  
        } else {
        	limitRight = mUpdateCountRight / mUpdatesPerSlot;
        }

        drawTrendLine(dc, x - xCenter * 0.7, y + yCenter * 0.7, mLeftSlots, slotIndexLeft, limitLeft);
        drawTrendLine(dc, x + xCenter * 0.1, y + yCenter * 0.7, mRightSlots, slotIndexRight, limitRight);
    }
    
    hidden function drawTrendLine(dc, x, y, values, startIndex, limit) {
        if (values.size() == 0) {
            return;
        }
        
        values[0] *= 1.0;
        
        var min = values[0];
        var max = values[0];
        
        
        for (var i = 1; i < limit; ++i) {
            values[i] *= 1.0;
            if (values[i] < min) {
                min = values[i];
            }
            if (values[i] > max) {
                max = values[i];
            }
        }
        
        var delta = max - min;
        if (delta == 0) {
            delta = 1;
        }
        
        for (var i = 0; i < limit - 1; ++i) {
            var start = (values[(i + startIndex) % mUpdateSlotCount] - min) / delta;
            var end = (values[(i + 1 + startIndex) % mUpdateSlotCount] - min) / delta;
            
            dc.drawLine(x + (xCenter * 0.6 / (limit - 1)) * i, y - yCenter * 0.3 * start, x + (xCenter * 0.6 / (limit - 1)) * (i + 1), y - yCenter * 0.3 * end);
        }        
    }
    
}
