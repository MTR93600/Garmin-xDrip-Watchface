//! TODO
//!
//!

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.Background;
using Toybox.ActivityMonitor;
using Toybox.Activity;

var sgv, aaps, timestamp, duration, masseinheit = 0, auswahlPfeil;
var height, width, hHeight, hWidth, hoeheBalken, hoeheGraph, breiteGraph;
var constSpace, constSpaceCenterH, constSpaceBar, constAscentFontSmall, constAscentFontNumber, constDescentFontNumber;
var fontTime;
var outdatedSGV = false;
var wert, anzeigeDelta, anzeigeFehler;
var heartAnzeige, stepsAnzeige;
var plotSGV;
var isAAPS = true;
var oldAAPS = true;
var changedAAPS = true;
var anzeigeSGV = "", anzeigeBasal = "", anzeigeIOB = "", anzeigeCOB = "", verzoegerung;
var showActivity = 0, counterActivityAnzeige = 0;
var showNotification = 0;
var BGFarbe = false, BarsFarbe = true;

class CGMWatchfaceView extends Ui.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        height = dc.getHeight();
        width = dc.getWidth();
        hHeight = height/2;
        hWidth = width/2;
        constSpace = height < 400 ? 5 : 12;
        constSpaceCenterH = height < 400 ? 8 : 16;
        constSpaceBar = width < 400 ? 10 : 15;
        fontTime = Gfx.FONT_NUMBER_MEDIUM;
        constAscentFontSmall = dc.getFontAscent(Gfx.FONT_SMALL);
        if( dc.getTextWidthInPixels("24:24", fontTime) + constSpaceBar > hWidth ) {
            fontTime = Gfx.FONT_NUMBER_MILD;
        }
        constAscentFontNumber = dc.getFontAscent(fontTime);
        constDescentFontNumber = dc.getFontDescent(fontTime);
        hoeheBalken = hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)-2;
        hoeheGraph = -dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)+constAscentFontSmall;
        breiteGraph = hWidth - constSpaceBar;

        masseinheit = App.getApp().getProperty("Einheiten").toNumber();
        zielbereichLow = App.getApp().getProperty("Zielbereich1").toNumber();
        zielbereichHigh = App.getApp().getProperty("Zielbereich2").toNumber();
        delay = App.getApp().getProperty("Delay").toNumber();
        pinfit = App.getApp().getProperty("pinfit").toNumber();
        showNotification = App.getApp().getProperty("Notification").toNumber();
        lowPowerModeEnabled = App.getApp().getProperty("lowPowerMode").toNumber() == 0 ? true : false;
        if( masseinheit == null ) { masseinheit = 0; }
        if( zielbereichLow == null ) { zielbereichLow = 70; }
        if( zielbereichHigh == null ) { zielbereichHigh = 180; }
        if( delay == null ) { delay = 20; }
        if( pinfit == null ) { pinfit = 0; }
        if( showNotification == null ) { showNotification = 1; }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        //BTL
        isClosing = false;
        var temp = App.Storage.getValue("punkteWatchface");
        if( temp != null && temp instanceof Lang.Array) {
            punkte = temp;
            calculation = true;
        }
        temp = App.Storage.getValue("bgReadingsAccumulatedWatchface");
        if( temp != null && temp instanceof Lang.Array) {
            bgReadingsAccumulated = temp;
        }
    }

    // Update the view
    function onUpdate(dc) {
        //BTL
        // Don't draw an update if we are closing or it will cause sluggish
        // peformance as the screen has to redraw before switching pages
        if(isClosing){
            return;
        }

        var dev = Sys.getDeviceSettings();

        setLayout(Rez.Layouts.WatchFace(dc));

        var farbeZielbereich = Gfx.COLOR_GREEN, farbeAlarm = Gfx.COLOR_YELLOW;
        farbeZielbereich = App.getApp().getProperty("FarbeZielbereich").toNumber() == 1 ? Gfx.COLOR_BLUE : Gfx.COLOR_GREEN;
        farbeAlarm = App.getApp().getProperty("FarbeAlarm").toNumber() == 1 ? Gfx.COLOR_RED : Gfx.COLOR_YELLOW;
        BGFarbe = App.getApp().getProperty("BGFarbe").toNumber();
        BarsFarbe = App.getApp().getProperty("BarsFarbe").toNumber();
        if( farbeZielbereich == null ) { farbeZielbereich = Gfx.COLOR_GREEN; }
        if( farbeAlarm == null ) { farbeAlarm = Gfx.COLOR_YELLOW; }
        if( BGFarbe == null ) { BGFarbe = 0; }
        if( BarsFarbe == null ) { BarsFarbe = 0; }

        // Get the current time and format it correctly
        //Sys.println("onUpdate");
        var clockTime = Sys.getClockTime();
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var datum = info.day_of_week.substring(0,3) + " " + info.day;
        var hours = clockTime.hour;
        if( dev.is24Hour == false ) {
            if (hours == 0) {
                hours = 12;
            } else if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeString = Lang.format("$1$:$2$", [hours, clockTime.min.format("%02d")]);

        // Background-Prozess neu starten, falls gestoppt
        if( Sys has :ServiceDelegate && dev.phoneConnected ) {
            var lastTime = Background.getLastTemporalEventTime();
            if (lastTime == null || ( lastTime != null && lastTime.value() < Time.now().value() - 600) ) {
                Background.registerForTemporalEvent(Time.now());
                adjustTime = false;
            }
        }


        // Heartrate & Steps
        // Schritte einlesen
        var activity, steps, stepGoal, stairs, heartrate;
        if( isHighPower == true || lowPowerModeEnabled == false) {
            activity = ActivityMonitor.getInfo();
            steps = activity has :steps ? activity.steps : null;
            stepGoal = activity has :stepGoal ? activity.stepGoal : null;
            stairs = activity has :floorsClimbed ? activity.floorsClimbed : null;
            // Heartrate einlesen
            heartrate = Activity.getActivityInfo().currentHeartRate;
            if( heartrate == null && ActivityMonitor has :getHeartRateHistory) {
                var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
                heartrate = hrIterator.next().heartRate;
                if ( heartrate != null && heartrate == ActivityMonitor.INVALID_HR_SAMPLE ) {   // check for invalid samples
                    heartrate = null;
                }
            }
        }
        // CGM Daten verarbeiten
        if( punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 ) {
            //Sys.println("CGM Daten");
            anzeigeFehler = "";
            if( calculation == true ) {
                calculation = false;

                // Restore bg values for graph
                // Check for need of 1 minute values 
                if( punkte.size() > 1 && punkte[0]["date"] != null && punkte[1]["date"] != null && (punkte[0]["date"] - punkte[1]["date"]) * 0.001 < 4 * 60 ) {                   
                    numberValuesTotal = 60;
                    newValues = 5;
                    minutes = 1;
                } else {
                    numberValuesTotal = 24;
                    newValues = 1;
                    minutes = 5;
                }
                // Adjust array size
                if( punkte.size() > numberValuesTotal ) {
                    punkte = new [1];
                    punkte[0] = { "date" => 0, "sgv" => 0};
                }
                if( bgReadingsAccumulated.size() != numberValuesTotal ) {
                    var temp = new [numberValuesTotal];
                    for( var i = 0; i < punkte.size(); i++ ) {
                        temp[i] = punkte[i];
                    }
                    for( var i = punkte.size(); i < numberValuesTotal; i++) {
                        temp[i] = { "date" => 0, "sgv" => 0};
                    }
                    bgReadingsAccumulated = temp;
                    App.Storage.setValue("bgReadingsAccumulatedWatchface", bgReadingsAccumulated);
                }
                if( bgReadingsAccumulated[0]["date"] < punkte[0]["date"] ) {    
                    for( var i = numberValuesTotal-1; i >= punkte.size(); i-- ) {
                        var k = i-newValues;
                        bgReadingsAccumulated[i]["date"] = bgReadingsAccumulated[k]["date"] ? bgReadingsAccumulated[k]["date"] : 0;
                        bgReadingsAccumulated[i]["sgv"] = bgReadingsAccumulated[k]["sgv"] ? bgReadingsAccumulated[k]["sgv"] : 0;
                    }
                    for( var i = 0; i < punkte.size(); i++ ) {
                        bgReadingsAccumulated[i]["date"] = punkte[i]["date"];
                        bgReadingsAccumulated[i]["sgv"] = punkte[i]["sgv"];
                    }
                    App.Storage.setValue("bgReadingsAccumulatedWatchface", bgReadingsAccumulated); 
                }

                // Units: mmol/l or mg/dl
                if( punkte[0]["units_hint"] != null ) {
                    masseinheit = punkte[0]["units_hint"].equals("mmol") ? 1 : 0;
                }
                // Calculate delta
                var delta_errechnet;
                if( punkte.size() > 1 && punkte[0]["sgv"] != null && punkte[0]["date"] != null && punkte[1]["sgv"] != null && punkte[1]["date"] != null && punkte[0]["date"] > punkte[1]["date"] ) {
                    delta_errechnet = ( punkte[0]["sgv"] - punkte[1]["sgv"] ) / ( (punkte[0]["date"] - punkte[1]["date"]) * 0.001 )  *  minutes * 60;
                } else if ( punkte[0]["delta"] != null ) {
                    delta_errechnet = punkte[0]["delta"];
                } else {
                    delta_errechnet = null;
                }
                // Calculate Trend Arrow
                if( delta_errechnet != null ) {
                    if( delta_errechnet <= -17.5 ) { auswahlPfeil = "DoubleDown"; }
                    else if( delta_errechnet <= -10 ) { auswahlPfeil = "SingleDown"; }
                    else if( delta_errechnet <= -5 ) { auswahlPfeil = "FortyFiveDown"; }
                    else if( delta_errechnet <= 5 ) { auswahlPfeil = "Flat"; }
                    else if( delta_errechnet <= 10 ) { auswahlPfeil = "FortyFiveUp"; }
                    else if( delta_errechnet <= 17.5 ) { auswahlPfeil = "SingleUp"; }
                    else { auswahlPfeil = "DoubleUp"; }
                }

                // SGV and Delta
                if( masseinheit != null && masseinheit == 1 && delta_errechnet != null ) {
                    // mmol
                    anzeigeSGV =  punkte[0]["sgv"] ? (0.05556 * punkte[0]["sgv"]).format("%.1f").toString() : "--";
                    // Delta in mmol, in String umwandeln, bei positiven Werten + davor
                    delta_errechnet = 0.05556 * delta_errechnet;
                    anzeigeDelta = delta_errechnet > 0 ? "+" : "";
                    anzeigeDelta += delta_errechnet.format("%.1f");
                } else if( delta_errechnet != null ) {
                    // mg
                    anzeigeSGV = punkte[0]["sgv"] != null ? punkte[0]["sgv"].toString() : "--";
                    // Delta in String umwandeln, bei positiven Werten + davor
                    anzeigeDelta = delta_errechnet > 0 ? "+" : "";
                    anzeigeDelta += delta_errechnet.format("%.0f");
                } else {
                    anzeigeDelta = "--";
                }

                // AAPS
                //punkte[0]["aaps"] = "No Status";
                //punkte[0]["aaps"] = "10,06U";
                //punkte[0]["aaps"] = "240% 10,06U(8.27|8.34) -17,24 0g";
                //punkte[0]["aaps"] = "0,85U/h -0,36U(8.27|8.34) -17,24 35g";
                //punkte[0]["aaps"] = "0,85U/h -0,36U(8.27|8.34) -17,24 35(17)g";
                //punkte[0]["aaps"] = "1,81U -1,35 11g";
                //punkte[0]["aaps"] = "Loop deaktiviert\n0,46U(0,46|0,00)";
                //punkte[0]["aaps"] = null;
                isAAPS = false;
                if( punkte[0]["aaps"] != null ) {
                    isAAPS = true;
                    anzeigeIOB = "Source:";
                    anzeigeCOB = "AAPS";
                    anzeigeBasal = "Choose";

                }
                // IOB and COB -> spike, AAPS
                //punkte[0]["iob"] = 0.01;
                //punkte[0]["cob"] = 10.000001;
                //punkte[0]["tbr"] = "120%";
                if( punkte[0]["iob"] != null || punkte[0]["cob"] != null ) {
                    isAAPS = true;
                    anzeigeIOB = punkte[0]["iob"] != null ? punkte[0]["iob"].format("%.1f") + " U" : "-- U";
                    anzeigeCOB = punkte[0]["cob"] != null ? punkte[0]["cob"].format("%.0f") + " g" : "-- g";
                    if( punkte[0]["tbr"] != null ) {
                        if( punkte[0]["tbr"] instanceof Lang.String ) {
                            anzeigeBasal = punkte[0]["tbr"];
                        } else {
                            anzeigeBasal = punkte[0]["tbr"].toString() + "%";
                        }
                    } else {
                        anzeigeBasal = "-- %";
                    }
                }
            }

            // Delay in minutes, proof if SGV is outdated
            verzoegerung = punkte[0]["date"] != null ? minutesFromTimestamp(Time.now().value(), punkte[0]["date"]) : "999";
            outdatedSGV = ( verzoegerung != null && verzoegerung > 11 ) ? true : false;

        } else {
            anzeigeFehler = "Wait max.\n5 min";
            verzoegerung = "--";
            anzeigeSGV = "---";
            anzeigeDelta = "--";
        }

        // Fehleranzeige
        if( fehler != null && fehler == true ) {
            // https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html
            anzeigeFehler = "Error: " + fehler_code;
            if( fehler_code == -104 || fehler_code == -1 || fehler_code == -2 ) {
                // BLE_CONNECTION_UNAVAILABLE, BLE_ERROR, BLE_HOST_TIMEOUT
                anzeigeFehler += "\nBluetooth?";
            } else if( fehler_code == -300 ) {
                // NETWORK_REQUEST_TIMED_OUT
                anzeigeFehler += "\nSettings?";
            } else if( fehler_code == -403) {
                // NETWORK_RESPONSE_OUT_OF_MEMORY
                anzeigeFehler += "\nDevice Memory!";
            } else if( fehler_code == -404) {
                // PAGE_NOT_FOUND
                anzeigeFehler += "\nURL Settings?";
            } else if( fehler_code == -401) {
                // UNAUTHORIZED (nightscout token missing / wrong?)
                anzeigeFehler += "\nNS TOKEN?";
            }
        }
        if( anzeigeFehler.equals("") == false && System.getDeviceSettings().phoneConnected == false ) {
            anzeigeFehler = "Bluetooth!";
        }

        //Test
        //anzeigeSGV = "22.4";
        //verzoegerung = "12";
        //anzeigeDelta = "+14.2";
        //anzeigeBasal = "120%";
        //anzeigeIOB = "12,1";*/

//! HIGH POWER
        if( isHighPower == true || lowPowerModeEnabled == false) {
            // Update the view
            var time = View.findDrawableById("TimeLabel");
            time.setText(timeString);
            time.setFont(fontTime);
            time.setLocation(
                hWidth-constSpaceBar,
                hHeight-constSpaceCenterH-constAscentFontNumber
            );

            var date = View.findDrawableById("DateLabel");
            date.setText(datum);
            date.setLocation(
                hWidth-constSpaceBar,
                hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)
            );

            var sgvAnzeige = View.findDrawableById("sgvLabel");
            sgvAnzeige.setText(anzeigeSGV);
            sgvAnzeige.setFont(fontTime);
            sgvAnzeige.setLocation(
                hWidth+constSpaceBar,
                hHeight-constSpaceCenterH-constAscentFontNumber
            );
            if( BGFarbe == 0 && punkte != null && punkte instanceof Lang.Array && punkte[0]["sgv"] != null ) {
                if( punkte[0]["sgv"] >= zielbereichLow && punkte[0]["sgv"] <= zielbereichHigh ) {
                    sgvAnzeige.setColor(farbeZielbereich);
                } else {
                    sgvAnzeige.setColor(farbeAlarm);
                }
            }

            var deltaAnzeige = View.findDrawableById("deltaLabel");
            deltaAnzeige.setText(anzeigeDelta);
            deltaAnzeige.setLocation(
                hWidth+constSpaceBar,
                hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)
            );

            var verzAnzeige = View.findDrawableById("verzLabel");
            verzAnzeige.setText(verzoegerung.toString()+" m");
            verzAnzeige.setLocation(
                hWidth+constSpaceBar,
                hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-dc.getFontAscent(Gfx.FONT_SMALL)-1
            );

            var iobAnzeige = View.findDrawableById("iobLabel");
            var cobAnzeige = View.findDrawableById("cobLabel");
            var basalAnzeige = View.findDrawableById("basalLabel");

            var spaceBigDisplay = width > 300 ? 10 : 0;

            if( isAAPS == false ) {
                anzeigeIOB = steps != null ? steps.toString() : "--";
                iobAnzeige.setColor(Gfx.COLOR_WHITE);
                anzeigeBasal = stairs != null ? stairs.toString() : "--";
                cobAnzeige.setColor(Gfx.COLOR_WHITE);
                anzeigeCOB = heartrate != null ? heartrate.toString() : "--";
                basalAnzeige.setColor(Gfx.COLOR_WHITE);
            }

            if( anzeigeIOB != null && anzeigeIOB.equals("") == false ) {
                iobAnzeige.setText(anzeigeIOB);
                iobAnzeige.setLocation(
                    hWidth+constSpaceBar+25+spaceBigDisplay,
                    hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)
                );
            }

            if( anzeigeBasal != null && anzeigeBasal.equals("") == false ) {
                basalAnzeige.setText(anzeigeBasal);
                basalAnzeige.setLocation(
                    hWidth+constSpaceBar+25+spaceBigDisplay,
                    hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+constAscentFontSmall+constSpace
                );
            }

            if( anzeigeCOB != null && anzeigeCOB.equals("") == false ) {
                cobAnzeige.setText(anzeigeCOB);
                cobAnzeige.setLocation(
                    hWidth+constSpaceBar+25+spaceBigDisplay,
                    hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)
                );
            }

            // Call the parent onUpdate function to redraw the layout
            View.onUpdate(dc);
            //Sys.println("View.onUpdate");

            //! Ui without layout.xml
            // Balken
            if( BarsFarbe == 1 ) {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            } else if( punkte != null && punkte instanceof Lang.Array  && punkte[0]["sgv"] != null && zielbereichLow <= punkte[0]["sgv"] && punkte[0]["sgv"] <= zielbereichHigh ) {
                dc.setColor(farbeZielbereich, Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(farbeAlarm, Gfx.COLOR_TRANSPARENT);
            }
            dc.setPenWidth(6);
            dc.drawLine(
                hWidth,
                0,
                hWidth,
                hoeheBalken
            );
            // Horizontale Trennlinien
            dc.setPenWidth(2);
            dc.drawLine(
                0,
                hHeight,
                hWidth-6,
                hHeight
            );
            dc.drawLine(
                hWidth+7,
                hHeight,
                width,
                hHeight
            );
            // Progress-Bar
            if( steps != null && stepGoal != null && stepGoal != 0 ) {
                var barHeight = hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)+constAscentFontSmall;
                var polygonPosition = barHeight - ( (steps * barHeight) / stepGoal);
                if( polygonPosition < -5 ) { polygonPosition = -5; }

                dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Fuellung
                var polygon = [
                    [hWidth+3, polygonPosition+12],
                    [hWidth+3, polygonPosition],
                    [hWidth-3, polygonPosition+4],
                    [hWidth-3, polygonPosition+16]
                ];
                dc.fillPolygon(polygon);
            }

            // Zu alter Blutzucker
            //outdatedSGV = true;
            if( outdatedSGV != null && outdatedSGV == true && anzeigeSGV != null ) {
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
                dc.fillRectangle(
                    hWidth + 4 + 7 - 2,
                    hHeight - 7 - (constAscentFontNumber-constDescentFontNumber)/2,
                    dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_MEDIUM)+4,
                    6
                );
            }
            // Graph
            if( punkte != null && punkte instanceof Lang.Array ) {
                var lowValue = 1000, highValue = 0;
                var factorY = 0.0033; // Faktor: 1/300
                var graphCorr = 0;
                for( var i = 0; i < bgReadingsAccumulated.size(); i++ ) {
                    if( bgReadingsAccumulated[i]["sgv"] != null && bgReadingsAccumulated[i]["sgv"] > 0 ) {
                        lowValue = lowValue > bgReadingsAccumulated[i]["sgv"] ? bgReadingsAccumulated[i]["sgv"] : lowValue;
                        highValue = highValue < bgReadingsAccumulated[i]["sgv"] ? bgReadingsAccumulated[i]["sgv"] : highValue;
                    }
                }
                var difference = highValue - lowValue;
                if( difference != null && difference <= 90 ) {
                    factorY = 0.01; // 1/100
                    graphCorr = (100-difference)/2;
                } else {
                    factorY = 1/(difference+10).toFloat(); // 1/200
                    graphCorr = 5;
                }
                // Border Graph Area
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_LT_GRAY);
                dc.setPenWidth(1);
                dc.drawRectangle(
                    -1,
                    hHeight + constSpaceCenterH,
                    breiteGraph + 1,
                    hoeheGraph
                );
                //In range lines
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_DK_GRAY);
                dc.setPenWidth(4);
                plotSGV = (zielbereichLow - lowValue) + graphCorr;
                if( 0 < plotSGV * (hoeheGraph*factorY) ) {
                    dc.drawLine(
                        0,
                        hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY)),
                        breiteGraph - 2,
                        hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY))
                    );
                }
                plotSGV = (zielbereichHigh - lowValue) + graphCorr;
                if( 0 < plotSGV * (hoeheGraph*factorY) && plotSGV * (hoeheGraph*factorY) < hoeheGraph ) {
                    dc.drawLine(
                        0,
                        hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY)),
                        breiteGraph - 2,
                        hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY))
                    );
                }
                dc.setPenWidth(1);
                // Plot bloodglucose
                for( var i = 0; i < bgReadingsAccumulated.size(); i++ ) {
                    if( bgReadingsAccumulated[i]["sgv"] != null && bgReadingsAccumulated[i]["date"] != null && bgReadingsAccumulated[i]["sgv"] > 0 ) {
                        plotSGV = (bgReadingsAccumulated[i]["sgv"] - lowValue) + graphCorr;
                        // Factor for stretching / compressing the values on the x-axis depending on the number of sgv values
                        var factorX = 1/(minutes * bgReadingsAccumulated.size()).toFloat(); // 1 / ( 5 minutes * x readings )
                        var plotBreite = breiteGraph - 3 - (minutesFromTimestamp(Time.now().value(), bgReadingsAccumulated[i]["date"]) * ( (breiteGraph-3) * factorX) );
                        var plotHoehe = hoeheGraph - ( plotSGV * ((hoeheGraph)*factorY));
                        if( zielbereichLow <= bgReadingsAccumulated[i]["sgv"] && bgReadingsAccumulated[i]["sgv"] <= zielbereichHigh ) {
                            dc.setColor(farbeZielbereich, Gfx.COLOR_TRANSPARENT);
                        } else {
                            dc.setColor(farbeAlarm, Gfx.COLOR_TRANSPARENT);
                        }
                        if( 0 < plotBreite - 3 ) {
                            dc.fillCircle(
                                plotBreite,
                                height*0.5 + 9 + plotHoehe,
                                3
                            );
                        }
                    }
                }
            }

            // Show communication errors
            if( anzeigeFehler != null ) {
                dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_WHITE);
                dc.drawText(
                    breiteGraph - 2,
                    hHeight+constSpaceCenterH,
                    Gfx.FONT_XTINY,
                    anzeigeFehler,
                    Gfx.TEXT_JUSTIFY_RIGHT
                );
            }

            //adjustTime = true;
            if( bmpStopwatch == null ) {
                bmpStopwatch = Ui.loadResource(Rez.Drawables.stopwatch);
            }
            if( adjustTime != null && adjustTime == true && anzeigeSGV != null ) {
                dc.drawBitmap(
                   hWidth+constSpaceBar+dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_MEDIUM)+constSpace,
                   hHeight-constSpaceCenterH-0.5*(constAscentFontNumber-constDescentFontNumber)-10,
                   bmpStopwatch
                );
            }

            // Batteriestand
            var batteryLoad = Sys.getSystemStats().battery;
            if( batteryLoad > 20 ) {
                dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            } else if( batteryLoad > 10 ) {
                dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            }
            // Battery body
            dc.fillRoundedRectangle(
                hWidth-constSpaceBar-14,
                hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-22,
                14,
                22,
                2
            );
            // Battery contact
            dc.fillRectangle(
                hWidth-constSpaceBar-10,
                hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-22-2,
                6,
                2
            );
            // Battery state
            var battery = batteryLoad * 18 / 100;
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT); // Fuellung
            dc.fillRoundedRectangle(
                hWidth-constSpaceBar-14+2,
                hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-22+2,
                10,
                18-battery,
                2
            );

            //Bluetooth connected
            var btSymbolOffset = 0;
            if ( dev.phoneConnected ) {
                if( bmpBluetooth == null ) {
                    bmpBluetooth = Ui.loadResource(Rez.Drawables.bluetooth);
                }
                if( bmpBluetooth != null ) {
                    dc.drawBitmap(
                        hWidth-constSpaceBar-14-constSpace-15,
                        hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-25,
                        bmpBluetooth
                    );
                    btSymbolOffset = 22;
                }
            }

            // Alarm clock
            if ( dev.alarmCount > 0 ) {
                if( bmpAlarmclock == null ) {
                    bmpAlarmclock = Ui.loadResource(Rez.Drawables.alarmclock);
                }
                dc.drawBitmap(
                    hWidth-constSpaceBar-12-constSpace-btSymbolOffset-15,
                    hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-5-dc.getFontHeight(Gfx.FONT_MEDIUM)-0-25,
                    bmpAlarmclock
                );
            }

            // Draw Trend Arrow
            if (auswahlPfeil != null ) {
                var bmp;
                if (auswahlPfeil.equals("DoubleDown")) { bmp = Ui.loadResource(Rez.Drawables.id_1); }
                else if (auswahlPfeil.equals("SingleDown")) { bmp = Ui.loadResource(Rez.Drawables.id_2); }
                else if (auswahlPfeil.equals("FortyFiveDown")) { bmp = Ui.loadResource(Rez.Drawables.id_3); }
                else if (auswahlPfeil.equals("Flat")) { bmp = Ui.loadResource(Rez.Drawables.id_4); }
                else if (auswahlPfeil.equals("FortyFiveUp")) { bmp = Ui.loadResource(Rez.Drawables.id_5); }
                else if (auswahlPfeil.equals("SingleUp")) { bmp = Ui.loadResource(Rez.Drawables.id_6); }
                else if (auswahlPfeil.equals("DoubleUp")) { bmp = Ui.loadResource(Rez.Drawables.id_7); }
                dc.drawBitmap(
                    hWidth+constSpaceBar+dc.getTextWidthInPixels(anzeigeDelta, Gfx.FONT_MEDIUM)+constSpace,
                    hHeight-constSpaceCenterH-constAscentFontNumber+constDescentFontNumber-constSpace-0.5*dc.getFontHeight(Gfx.FONT_MEDIUM)-12,
                    bmp
                );
            }

            // Reload Icons?
            if( isAAPS == oldAAPS ) {
                changedAAPS = false;
            } else {
                changedAAPS = true;
                oldAAPS = isAAPS;
            }

            // steps, stairs and heartrate OR iob, tbr and cob
            if( bmpStairs == null || changedAAPS == true ) {
                if( height > 300 ) {
                    bmpSteps = isAAPS == false ? Ui.loadResource(Rez.Drawables.steps30) : Ui.loadResource(Rez.Drawables.iob30);
                    bmpStairs = isAAPS == false ? Ui.loadResource(Rez.Drawables.stairs30) : Ui.loadResource(Rez.Drawables.tbr30);
                    bmpHeart = isAAPS == false ? Ui.loadResource(Rez.Drawables.heart30) : Ui.loadResource(Rez.Drawables.cob30);
                } else {
                    bmpSteps = isAAPS == false ? Ui.loadResource(Rez.Drawables.steps20) : Ui.loadResource(Rez.Drawables.iob20);
                    bmpStairs = isAAPS == false ? Ui.loadResource(Rez.Drawables.stairs20) : Ui.loadResource(Rez.Drawables.tbr20);
                    bmpHeart = isAAPS == false ? Ui.loadResource(Rez.Drawables.heart20) : Ui.loadResource(Rez.Drawables.cob20);
                }
            }

            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.drawBitmap(
                hWidth+constSpaceBar,
                hHeight+constSpaceCenterH,
                bmpSteps
            );

            dc.drawBitmap(
                hWidth+constSpaceBar,
                hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+constAscentFontSmall+2*constSpace+1,
                bmpStairs
            );

            dc.drawBitmap(
                hWidth+constSpaceBar,
                hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)+constSpace+1,
                bmpHeart
            );

            if( isAAPS == false ) {
                if( showNotification == 0 && dev.notificationCount > 0 ) {
                    dc.drawText(
                        hWidth-constSpace+1,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                        Gfx.FONT_SMALL,
                        dev.notificationCount.toString(),
                        Gfx.TEXT_JUSTIFY_RIGHT
                    );
                    if( bmpNotification == null ) {
                        bmpNotification = height > 300 ? Ui.loadResource(Rez.Drawables.notification36) : Ui.loadResource(Rez.Drawables.notification18);
                    }
                    dc.drawBitmap(
                        hWidth+constSpace-1,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+8,
                        bmpNotification
                    );
                } else {
                    dc.drawText(
                        hWidth,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+4,
                        Gfx.FONT_TINY,
                        ":-)",
                        Gfx.TEXT_JUSTIFY_CENTER
                    );
                }
            } else {
                //var spaceKombiDisplay = height > 300 ? 5 : 0;
                if( pinfit == 0 && Time.now().value() >= counterActivityAnzeige + 5 ) {
                    counterActivityAnzeige = Time.now().value();
                    showActivity += 1;
                    if( showActivity > 2 ) { showActivity = 1; }
                    if( heartrate == null && showActivity == 1) { showActivity = 2; }
                    if( steps == null && showActivity == 2) { showActivity = 1; }
                } else if ( pinfit == 1 ) {
                        showActivity = 1;
                        stairs = null;
                } else if ( pinfit == 2 ) {
                        showActivity = 2;
                }
                if( showNotification == 0 && dev.notificationCount > 0 ) {
                    dc.drawText(
                        hWidth-constSpace+1,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                        Gfx.FONT_SMALL,
                        dev.notificationCount.toString(),
                        Gfx.TEXT_JUSTIFY_RIGHT
                    );
                    if( bmpNotification == null ) {
                        bmpNotification = height > 300 ? Ui.loadResource(Rez.Drawables.notification36) : Ui.loadResource(Rez.Drawables.notification18);
                    }
                    dc.drawBitmap(
                        hWidth+constSpace-1,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+8,
                        bmpNotification
                    );
                } else if( showActivity == 1 && heartrate != null && stairs == null) {
                    dc.drawText(
                        hWidth+(15+constSpace)/2,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                        Gfx.FONT_SMALL,
                        heartrate.toString(),
                        Gfx.TEXT_JUSTIFY_CENTER
                    );
                    if( bmpHeart2 == null ) {
                        bmpHeart2 = height > 300 ? Ui.loadResource(Rez.Drawables.heart30) : Ui.loadResource(Rez.Drawables.heart20);
                    }
                    dc.drawBitmap(
                        hWidth-(15+constSpace)/2-dc.getTextWidthInPixels(heartrate.toString(), Gfx.FONT_SMALL)/2 - spaceBigDisplay,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+4,
                        bmpHeart2
                    );
                } else if( showActivity == 1 && heartrate != null && stairs != null) {
                    var heightHeartStairs = hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace);
                    dc.drawText(
                        hWidth-16-5-spaceBigDisplay*0.5,
                        heightHeartStairs,
                        Gfx.FONT_TINY,
                        heartrate.toString(),
                        Gfx.TEXT_JUSTIFY_RIGHT
                    );
                    dc.drawText(
                        hWidth+16+5+spaceBigDisplay,
                        heightHeartStairs,
                        Gfx.FONT_TINY,
                        stairs.toString(),
                        Gfx.TEXT_JUSTIFY_LEFT
                    );
                    if( bmpHeartStairs == null ) {
                        bmpHeartStairs = height > 300 ? Ui.loadResource(Rez.Drawables.heart_stairs30) : Ui.loadResource(Rez.Drawables.heart_stairs20);
                    }
                    dc.drawBitmap(
                        hWidth-16-spaceBigDisplay*0.5,
                        heightHeartStairs+5,
                        bmpHeartStairs
                    );
                } else if( showActivity == 2 && steps != null ) {
                    var kombiAnzeige = steps.toString();
                    dc.drawText(
                        hWidth+(15+constSpace)/2,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                        Gfx.FONT_TINY,
                        kombiAnzeige,
                        Gfx.TEXT_JUSTIFY_CENTER
                    );
                    if( bmpSteps2 == null ) {
                        bmpSteps2 = height > 300 ? Ui.loadResource(Rez.Drawables.steps30) : Ui.loadResource(Rez.Drawables.steps20);
                    }
                    dc.drawBitmap(
                        hWidth-(15+constSpace)/2-dc.getTextWidthInPixels(kombiAnzeige, Gfx.FONT_SMALL)/2 - spaceBigDisplay,
                        hHeight+constSpaceCenterH-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+4,
                        bmpSteps2
                    );
                }
            }
        } else {
//! LOW POWER
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.clear();
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_BLACK);
            dc.drawText(
                hWidth,
                hHeight -  dc.getFontHeight(Gfx.FONT_NUMBER_HOT) * 0.5 - dc.getFontHeight(Gfx.FONT_LARGE),
                Gfx.FONT_LARGE,
                datum,
                Gfx.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                hWidth,
                hHeight,
                Gfx.FONT_NUMBER_HOT,
                timeString,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                hWidth,
                hHeight +  dc.getFontHeight(Gfx.FONT_NUMBER_HOT) * 0.5,
                Gfx.FONT_LARGE,
                anzeigeSGV + " " + anzeigeDelta + " @ " + verzoegerung.toString() + " m",
                Gfx.TEXT_JUSTIFY_CENTER
            );
        }
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
        if( isBackground != null && false == isBackground && punkte != null && punkte instanceof Lang.Array ) {
            App.Storage.setValue("punkteWatchface", punkte);
        }
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        //BTL
        isHighPower = true;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        //BTL
        isHighPower = false;
    }

    // Verzoegerung ermitteln
    function minutesFromTimestamp(now, timestamp) {
        return( (now - timestamp/1000) / 60 );
    }

}
