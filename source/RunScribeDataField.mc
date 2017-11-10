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
    
    hidden var mMetric1Type; // 1 - Impact GS, 2 - Braking GS, 3 - FS Type, 4 - Pronation, 5 - Flight Ratio, 6 - Contact Time

    // Common
    hidden var mMetricTitleY;
    hidden var mMetricValueY;
    hidden var mMetricValueOffsetX;
        
    // Font values
    hidden var mDataFont;
    hidden var mDataFontHeight;
    
    var mSensorLeft;
    var mSensorRight;
    
    hidden var mScreenShape;
    hidden var mScreenHeight;
    
    hidden var xCenter;
    hidden var yCenter;
    
    hidden var mUpdateLayout = 0;
    
    // FIT Contributions variables
    hidden var mCurrentBGFieldLeft;
    /*
    hidden var mCurrentIGFieldLeft;
    hidden var mCurrentFSFieldLeft;
    hidden var mCurrentPronationFieldLeft;
    hidden var mCurrentFlightFieldLeft;
    hidden var mCurrentGCTFieldLeft;
	*/
    hidden var mCurrentBGFieldRight;
    /*
    hidden var mCurrentIGFieldRight;
    hidden var mCurrentFSFieldRight;
    hidden var mCurrentPronationFieldRight;
    hidden var mCurrentFlightFieldRight;
    hidden var mCurrentGCTFieldRight;    

    hidden var mCurrentPowerField;
    */
    hidden var mMesgPeriod;
    
    
    
    // Constructor
    function initialize(screenShape, screenHeight) {
        DataField.initialize();
        
        mScreenShape = screenShape;
        mScreenHeight = screenHeight;
        
        onSettingsChanged();        

        var d = {};
        var units = "units";

        //mCurrentFSFieldLeft = createField("FS_L", 2, Fit.DATA_TYPE_SINT8, d);
        //mCurrentFSFieldRight = createField("FS_R", 8, Fit.DATA_TYPE_SINT8, d);

        d[units] = "G";       
        mCurrentBGFieldLeft = createField("BG_L", 0, Fit.DATA_TYPE_FLOAT, d);
        //mCurrentIGFieldLeft = createField("IG_L", 1, Fit.DATA_TYPE_FLOAT, d);
        mCurrentBGFieldRight = createField("BG_R", 6, Fit.DATA_TYPE_FLOAT, d);
        //mCurrentIGFieldRight = createField("IG_R", 7, Fit.DATA_TYPE_FLOAT, d);
        
        /*
        d[units] = "D";        
        mCurrentPronationFieldLeft = createField("P_L", 3, Fit.DATA_TYPE_SINT16, d);
        mCurrentPronationFieldRight = createField("P_R", 9, Fit.DATA_TYPE_SINT16, d);
        
        d[units] = "%";
        mCurrentFlightFieldLeft = createField("FR_L", 4, Fit.DATA_TYPE_SINT8, d);
        mCurrentFlightFieldRight = createField("FR_R", 10, Fit.DATA_TYPE_SINT8, d);
       
        d[units] = "ms";
        mCurrentGCTFieldLeft = createField("GCT_L", 5, Fit.DATA_TYPE_SINT16, d);
        mCurrentGCTFieldRight = createField("GCT_R", 11, Fit.DATA_TYPE_SINT16, d);
        
        d[units] = "W";
        mCurrentPowerField = createField("Power", 18, Fit.DATA_TYPE_SINT16, d);
        */
    }
    
    function onSettingsChanged() {
        var app = App.getApp();
        
        var antRate = app.getProperty("antRate");
        mMesgPeriod = 8192 >> antRate;        
        
        mMetric1Type = app.getProperty("tM1");

        mUpdateLayout = 1;
    }
    
    function compute(info) {
    
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
        
            var braking = mSensorLeft.braking_gs;
            /*
            var impact = mSensorLeft.impact_gs;
            var footstrike = mSensorLeft.footstrike_type;
            var pronation = mSensorLeft.pronation_excursion_fs_mp;
            var flight = mSensorLeft.flight_ratio;
            var contact = mSensorLeft.contact_time;
            */                
            mCurrentBGFieldLeft.setData(braking);
            /*
            mCurrentIGFieldLeft.setData(impact);
            mCurrentFSFieldLeft.setData(footstrike);
            mCurrentPronationFieldLeft.setData(pronation);
            mCurrentFlightFieldLeft.setData(flight);
            mCurrentGCTFieldLeft.setData(contact);
            
            if (mSensorRight != null) {
                mCurrentPowerField.setData((mSensorLeft.power + mSensorRight.power) * 0.5);
            }
            */
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
            
            // Separate left / right recording
            mCurrentBGFieldRight.setData(mSensorRight.braking_gs);
            /*
            mCurrentIGFieldRight.setData(mSensorRight.impact_gs);
            mCurrentFSFieldRight.setData(mSensorRight.footstrike_type);
            mCurrentPronationFieldRight.setData(mSensorRight.pronation_excursion_fs_mp);
            mCurrentFlightFieldRight.setData(mSensorRight.flight_ratio);
            mCurrentGCTFieldRight.setData(mSensorRight.contact_time);
            */
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
        var metricNameFontHeight = dc.getFontHeight(Gfx.FONT_XTINY) + 2;
        width *= 2.0;

        mDataFont = selectFont(dc, width * 0.2225, height - metricNameFontHeight, "00.0-");
            
        mDataFontHeight = dc.getFontHeight(mDataFont);    
            
        mMetricTitleY = -(mDataFontHeight + metricNameFontHeight) * 0.5;
        if (mScreenShape == System.SCREEN_SHAPE_ROUND) {
            mMetricTitleY *= 1.1;
        } 
        
        mMetricValueY = mMetricTitleY + metricNameFontHeight;
        
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
        if (metricType == 7) {
            return "RSPower";
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
            
            drawMetricOffset(dc, met1x, met1y, mMetric1Type);         
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

        if (metricType == 7) {
            // Power metric presents a single value
            dc.drawText(x, y + mMetricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(x - mMetricValueOffsetX, y + mMetricValueY, mDataFont, metricLeft, Gfx.TEXT_JUSTIFY_RIGHT);
            dc.drawText(x + mMetricValueOffsetX, y + mMetricValueY, mDataFont, metricRight, Gfx.TEXT_JUSTIFY_LEFT);
            
            // Draw line
            dc.drawLine(x, y + mMetricValueY, x, y + mMetricValueY + mDataFontHeight);
        }    
    }
}
