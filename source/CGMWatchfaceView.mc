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
var constSpace, constSpaceBar, constAscentFontSmall, constAscentFontNumber, constDescentFontNumber;
var outdatedSGV = false;
var wert, anzeigeDelta, anzeigeFehler;
var heartAnzeige, stepsAnzeige;
var plotSGV;
var noAAPS = true;
var anzeigeSGV = "", anzeigeBasal = "", anzeigeIOB = "", anzeigeCOB = "", verzoegerung;
var showActivity = 0, counterActivityAnzeige = 0;
var showNotification = 0;
var farbeZielbereich, farbeAlarm, BGFarbe, BarsFarbe;
var bmp;

class CGMWatchfaceView extends Ui.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        height = dc.getHeight();
        width = dc.getWidth();
        hHeight = height/2;
        hWidth = width/2 + 2;
        constSpace = 5;
        constSpaceBar = 4+8;
        constAscentFontSmall = dc.getFontAscent(Gfx.FONT_SMALL);
        constAscentFontNumber = dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM);
        constDescentFontNumber = dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM);
        hoeheBalken = hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace);
        hoeheGraph = -dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)+constAscentFontSmall;
        breiteGraph = hWidth - constSpaceBar;

        masseinheit = App.getApp().getProperty("Einheiten").toNumber();
        zielbereichLow = App.getApp().getProperty("Zielbereich1").toNumber();
        zielbereichHigh = App.getApp().getProperty("Zielbereich2").toNumber();
        delay = App.getApp().getProperty("Delay").toNumber();
        pinfit = App.getApp().getProperty("pinfit").toNumber();
        showNotification = App.getApp().getProperty("Notification").toNumber();
        eco = App.getApp().getProperty("eco").toNumber();
        if( masseinheit == null ) { masseinheit = 0; }
        if( zielbereichLow == null ) { zielbereichLow = 70; }
        if( zielbereichHigh == null ) { zielbereichHigh = 180; }
        if( delay == null ) { delay = 20; }
        if( eco == null ) { eco = 0; }
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
    }

    // Update the view
    function onUpdate(dc) {
        //BTL
        // Don't draw an update if we are closing or it will cause sluggish
        // peformance as the screen has to redraw before switching pages
        if(isClosing){
            return;
        }

        setLayout(Rez.Layouts.WatchFace(dc));
        farbeZielbereich = App.getApp().getProperty("FarbeZielbereich").toNumber() == 1 ? Gfx.COLOR_BLUE : Gfx.COLOR_GREEN;
        farbeAlarm = App.getApp().getProperty("FarbeAlarm").toNumber() == 1 ? Gfx.COLOR_RED : Gfx.COLOR_YELLOW;
        BGFarbe = App.getApp().getProperty("BGFarbe").toNumber() == 0 ? true : false;
        BarsFarbe = App.getApp().getProperty("BarsFarbe").toNumber() == 0 ? true : false;


        // Get the current time and format it correctly
        //Sys.println("onUpdate");
        var timeFormat = "$1$:$2$";
        var clockTime = Sys.getClockTime();
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var datum = info.day_of_week.substring(0,3) + " " + info.day;
        var hours = clockTime.hour;
        if( !Sys.getDeviceSettings().is24Hour ) {
            if (hours == 0) {
                hours = 12;
            } else if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);

        // Background-Prozess neu starten, falls gestoppt
        if( Sys has :ServiceDelegate && Sys.getDeviceSettings().phoneConnected ) {
            var lastTime = Background.getLastTemporalEventTime();
            if (lastTime == null || ( lastTime != null && lastTime.value() < Time.now().value() - 600) ) {
                Background.registerForTemporalEvent(Time.now());
                adjustTime = false;
            }
        }

        // Heartrate & Steps
        // Schritte einlesen
        var activity = ActivityMonitor.getInfo();
        var steps = activity has :steps ? activity.steps : null;
        var stepGoal = activity has :stepGoal ? activity.stepGoal : null;
        var stairs = activity has :floorsClimbed ? activity.floorsClimbed : null;
        // Heartrate einlesen
        var heartrate;
        /*if (ActivityMonitor has :getHeartRateHistory) {
            var hrHistory =  ActivityMonitor.getHeartRateHistory(1, true);
            heartrate = hrHistory.next().heartRate;
            if( heartrate == ActivityMonitor.INVALID_HR_SAMPLE ) { // Plausibilität des Wertes prüfen
                heartrate = null; // Wenn nicht plausibel, Variable leeren
            }
        } else {
            heartrate = null;
        }*/
        heartrate = Activity.getActivityInfo().currentHeartRate;
        if( heartrate == null && ActivityMonitor has :getHeartRateHistory) {
            var hrIterator = ActivityMonitor.getHeartRateHistory(1, true);
            heartrate = hrIterator.next().heartRate;
            if ( heartrate != null && heartrate == ActivityMonitor.INVALID_HR_SAMPLE ) {   // check for invalid samples
                heartrate = null;
            }
        }
        // CGM Daten verarbeiten
        if( punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 ) {
            //Sys.println("CGM Daten");
            anzeigeFehler = "";
            if( calculation == true ) {
                calculation = false;
                // Units: mmol/l or mg/dl
                if( punkte[0]["units_hint"] != null ) {
                    masseinheit = punkte[0]["units_hint"].equals("mmol") ? 1 : 0;
                }
                // Calculate delta
                var delta_errechnet;
                if( punkte.size() > 1 && punkte[0]["sgv"] != null && punkte[0]["date"] != null && punkte[1]["sgv"] != null && punkte[1]["date"] != null && punkte[0]["date"] > punkte[1]["date"] ) {
                    delta_errechnet = ( punkte[0]["sgv"] - punkte[1]["sgv"] ) / ( (punkte[0]["date"] - punkte[1]["date"]) * 0.001 )  * 5 * 60;
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
                noAAPS = true;
                if( punkte[0]["aaps"] != null ) {
                    aaps = punkte[0]["aaps"].toString();
                    noAAPS = false;
                    var index1 = null, index2 = null, index3 = null, index4 = null, index5 = null;
                    if( aaps != null && aaps.equals("") == false ) {
                        anzeigeIOB = "-- U";
                        anzeigeCOB = "-- g";
                        anzeigeBasal = "--%";
                        var deleteText = aaps.find("\n");
                        if( deleteText != null ) {
                            aaps = aaps.substring(deleteText+1,aaps.length());
                        }
                        if( aaps.equals("No Status") == false) {
                            index1 = aaps.find(" ");
                            index2 = aaps.find("%");
                            index3 = aaps.find("U/h");
                            index4 = aaps.find("U");
                            // Basal
                            if( index2 != null ) {
                                anzeigeBasal = aaps.substring(0,index2+1);
                            } else if( index3 != null ) {
                                anzeigeBasal =  aaps.substring(0,index3) + " U/h";
                            } else if( index3 == null && index4 != null ) {
                                anzeigeBasal = "100%";
                            }
                            // IOB
                            if(index2 == null && index3 == null && index4 != null ) {
                                anzeigeIOB = aaps.substring(0,index4-1) + " U";
                            } else if( index1 != null ) {
                                var aapsPart1 = aaps.substring(index1+1,aaps.length()) + " U";
                                index4 = aapsPart1.find("U");
                                if( index4 != null ) {
                                    anzeigeIOB = aapsPart1.substring(0,index4-1) + " U";
                                }
                            }
                            // COB
                            if( aaps.find("g") != null ) {
                                var length = aaps.length();
                                var aapsPart2 = aaps.substring(length-8, length);
                                index5 = aapsPart2.find(" ");
                                if( index5 != null ) {
                                    var cob = aapsPart2.substring((index5+1),(aapsPart2.length()-1));
                                    anzeigeCOB = cob.toString() + " g";
                                }
                            }
                        }
                    }
                    if( punkte[0]["aaps-ts"] != null) { // Meldung AAPS Status nicht aktuell
                        var verzoegerungAAPS = minutesFromTimestamp(Time.now().value(), punkte[0]["aaps-ts"]);
                        if( verzoegerungAAPS != null && verzoegerungAAPS > 20 ) {
                            anzeigeIOB = "-- U";
                            anzeigeCOB = "-- g";
                            anzeigeBasal = "--%";
                        }
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
            anzeigeFehler = "Error: " + fehler_code;
            if( fehler_code == -104 || fehler_code == -1 || fehler_code == -2 ) {
                anzeigeFehler += "\nBluetooth?";
            } else if( fehler_code == -300 ) {
                anzeigeFehler += "\nSettings?";
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

        // Update the view
        var time = View.findDrawableById("TimeLabel");
        time.setText(timeString);
        time.setLocation(
            hWidth-constSpaceBar,
            hHeight-8-constAscentFontNumber
        );

        var date = View.findDrawableById("DateLabel");
        date.setText(datum);
        date.setLocation(
            hWidth-constSpaceBar,
            hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)
        );

        var sgvAnzeige = View.findDrawableById("sgvLabel");
        sgvAnzeige.setText(anzeigeSGV);
        sgvAnzeige.setLocation(
            hWidth+constSpaceBar,
            hHeight-8-constAscentFontNumber
        );
        if( BGFarbe == true ) {
            if( anzeigeSGV.toNumber() > zielbereichLow && anzeigeSGV.toNumber() < zielbereichHigh ) {
                sgvAnzeige.setColor(farbeZielbereich);
            } else {
                sgvAnzeige.setColor(farbeAlarm);
            }
        }

        var deltaAnzeige = View.findDrawableById("deltaLabel");
        deltaAnzeige.setText(anzeigeDelta);
        deltaAnzeige.setLocation(
            hWidth+constSpaceBar,
            hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)
        );

        var iobAnzeige = View.findDrawableById("iobLabel");
        var cobAnzeige = View.findDrawableById("cobLabel");
        var basalAnzeige = View.findDrawableById("basalLabel");

        if( noAAPS == true ) {
            anzeigeIOB = steps != null ? steps.toString() : "--";
            iobAnzeige.setColor(Gfx.COLOR_LT_GRAY);
            anzeigeBasal = stairs != null ? stairs.toString() : "--";
            cobAnzeige.setColor(Gfx.COLOR_LT_GRAY);
            anzeigeCOB = heartrate != null ? heartrate.toString() : "--";
            basalAnzeige.setColor(Gfx.COLOR_LT_GRAY);
        }

        if( anzeigeIOB != null && anzeigeIOB.equals("") == false ) {
            iobAnzeige.setText(anzeigeIOB);
            iobAnzeige.setLocation(
                hWidth+constSpaceBar,
                hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)
            );
        }

        if( anzeigeBasal != null && anzeigeBasal.equals("") == false ) {
            basalAnzeige.setText(anzeigeBasal);
            basalAnzeige.setLocation(
                hWidth+constSpaceBar,
                hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+constAscentFontSmall+constSpace
            );
        }

        if( anzeigeCOB != null && anzeigeCOB.equals("") == false ) {
            cobAnzeige.setText(anzeigeCOB);
            cobAnzeige.setLocation(
                hWidth+constSpaceBar,
                hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)
            );
        }

        var verzAnzeige = View.findDrawableById("verzLabel");
        verzAnzeige.setText(verzoegerung.toString()+"'");
        if( energy == 1 ) {
            verzAnzeige.setText(verzoegerung.toString()+" m");
        } else {
            verzAnzeige.setText(verzoegerung.toString()+"' e");
        }
        verzAnzeige.setLocation(
            hWidth+constSpaceBar,
            hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-dc.getFontHeight(Gfx.FONT_SMALL)
        );

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        //Sys.println("View.onUpdate");

        //! Ui without layout.xml
        // Balken
        if( BarsFarbe == false ) {
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
            hWidth-4-2,
            hHeight
        );
        dc.drawLine(
            hWidth+4+2,
            hHeight,
            width,
            hHeight
        );
        // Progress-Bar
        if( steps != null && stepGoal != null && stepGoal != 0 ) {
            var barHeight = hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)+constAscentFontSmall;
            var polygonPosition = barHeight - ( (steps * barHeight) / stepGoal);
            if( polygonPosition < -5 ) { polygonPosition = -5; }
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Füllung
            var polygon = [
                [hWidth+4, polygonPosition+12],
                [hWidth+4, polygonPosition],
                [hWidth-4, polygonPosition+4],
                [hWidth-4, polygonPosition+16]
            ];
            dc.fillPolygon(polygon);
        }

        // Zu alter Blutzucker
        //outdatedSGV = true;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if( outdatedSGV != null && outdatedSGV == true && anzeigeSGV != null ) {
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
            for( var i = 0; i < punkte.size(); i++ ) {
                if( lowValue > punkte[i]["sgv"] ) { lowValue = punkte[i]["sgv"]; }
                if( highValue < punkte[i]["sgv"] ) { highValue = punkte[i]["sgv"]; }
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
                0,
                hHeight + 8,
                breiteGraph,
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
                    breiteGraph,
                    hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY))
                );
            }
            plotSGV = (zielbereichHigh - lowValue) + graphCorr;
            if( 0 < plotSGV * (hoeheGraph*factorY) && plotSGV * (hoeheGraph*factorY) < hoeheGraph ) {
                dc.drawLine(
                    0,
                    hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY)),
                    breiteGraph,
                    hHeight + 9 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY))
                );
            }
            dc.setPenWidth(1);
            // Plot bloodglucose
            for( var i = 0; i < punkte.size(); i++ ) {
                if(punkte[i]["sgv"] != null && punkte[i]["date"] != null ) {
                    plotSGV = (punkte[i]["sgv"] - lowValue) + graphCorr;
                    // Factor for stretching / compressing the values on the x-axis depending on the number of sgv values
                    var factorX = 1/(5 * punkte.size()).toFloat(); // 1 / ( 5 minutes * x readings )
                    var plotBreite = breiteGraph - 3 - (minutesFromTimestamp(Time.now().value(), punkte[i]["date"]) * ( (breiteGraph-3) * factorX) );
                    var plotHoehe = hoeheGraph - ( plotSGV * ((hoeheGraph)*factorY));
                    if( zielbereichLow <= punkte[i]["sgv"] && punkte[i]["sgv"] <= zielbereichHigh ) {
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
                hHeight+8,
                Gfx.FONT_XTINY,
                anzeigeFehler,
                Gfx.TEXT_JUSTIFY_RIGHT
            );
        }

        //adjustTime = true;
        if( adjustTime != null && adjustTime == true) {
            var bmp = Ui.loadResource(Rez.Drawables.stopwatch);
            dc.drawBitmap(
               hWidth+constSpaceBar+dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_MEDIUM)+constSpace,
               hHeight-8-0.5*(constAscentFontNumber-constDescentFontNumber)-10,
               bmp
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
            hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-22,
            14,
            22,
            2
        );
        // Battery contact
        dc.fillRectangle(
            hWidth-constSpaceBar-10,
            hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-22-2,
            6,
            2
        );
        // Battery state
        var battery = batteryLoad * 18 / 100;
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Füllung
        dc.fillRoundedRectangle(
            hWidth-constSpaceBar-14+2,
            hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-dc.getFontHeight(Gfx.FONT_MEDIUM)-constSpace-22+2,
            10,
            18-battery,
            2
        );

        //Bluetooth connected
        var dev = Sys.getDeviceSettings();
        if( dev.phoneConnected ) {
            var bmp = Ui.loadResource(Rez.Drawables.bluetooth);
            dc.drawBitmap(
                hWidth-constSpaceBar-14-constSpace-15,
                hHeight-8-constAscentFontNumber+constDescentFontNumber-5-dc.getFontHeight(Gfx.FONT_MEDIUM)-4-25,
                bmp
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
                hHeight-8-constAscentFontNumber+constDescentFontNumber-constSpace-0.5*dc.getFontHeight(Gfx.FONT_MEDIUM)-12,
                bmp
            );
        }

        // heartrate and steps
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        if( noAAPS == true ) {
            var bmp = Ui.loadResource(Rez.Drawables.steps);
            dc.drawBitmap(
                hWidth+constSpaceBar+dc.getTextWidthInPixels(anzeigeIOB, Gfx.FONT_SMALL)+5,
                hHeight+8+1,
                bmp
            );
            bmp = Ui.loadResource(Rez.Drawables.stairs);
            dc.drawBitmap(
                hWidth+constSpaceBar+dc.getTextWidthInPixels(anzeigeBasal, Gfx.FONT_SMALL)+5,
                hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+constAscentFontSmall+2*constSpace+1,
                bmp
            );
            bmp = Ui.loadResource(Rez.Drawables.heart);
            dc.drawBitmap(
                hWidth+constSpaceBar+dc.getTextWidthInPixels(anzeigeCOB, Gfx.FONT_SMALL)+5,
                hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+2*(constAscentFontSmall+constSpace)+constSpace+1,
                bmp
            );
            if( showNotification == 0 && dev.notificationCount > 0 ) {
                dc.drawText(
                    hWidth-constSpace+1,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                    Gfx.FONT_SMALL,
                    dev.notificationCount.toString(),
                    Gfx.TEXT_JUSTIFY_RIGHT
                );
                bmp = Ui.loadResource(Rez.Drawables.notification);
                dc.drawBitmap(
                    hWidth+constSpace-1,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+8,
                    bmp
                );
            } else {
                dc.drawText(
                    hWidth,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+4,
                    Gfx.FONT_TINY,
                    ":-)",
                    Gfx.TEXT_JUSTIFY_CENTER
                );
            }
        } else {
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
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                    Gfx.FONT_SMALL,
                    dev.notificationCount.toString(),
                    Gfx.TEXT_JUSTIFY_RIGHT
                );
                bmp = Ui.loadResource(Rez.Drawables.notification);
                dc.drawBitmap(
                    hWidth+constSpace-1,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+8,
                    bmp
                );
            } else if( showActivity == 1 && heartrate != null && stairs == null) {
                dc.drawText(
                    hWidth+(15+constSpace)/2,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                    Gfx.FONT_SMALL,
                    heartrate.toString(),
                    Gfx.TEXT_JUSTIFY_CENTER
                );
                bmp = Ui.loadResource(Rez.Drawables.heart);
                dc.drawBitmap(
                    hWidth-(15+constSpace)/2-dc.getTextWidthInPixels(heartrate.toString(), Gfx.FONT_SMALL)/2,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+4,
                    bmp
                );
            } else if( showActivity == 1 && heartrate != null && stairs != null) {
                var heightHeartStairs = hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace);
                dc.drawText(
                    hWidth-16-5,
                    heightHeartStairs,
                    Gfx.FONT_TINY,
                    heartrate.toString(),
                    Gfx.TEXT_JUSTIFY_RIGHT
                );
                dc.drawText(
                    hWidth+16+5,
                    heightHeartStairs,
                    Gfx.FONT_TINY,
                    stairs.toString(),
                    Gfx.TEXT_JUSTIFY_LEFT
                );
                bmp = Ui.loadResource(Rez.Drawables.heart_stairs);
                dc.drawBitmap(
                    hWidth-16,
                    heightHeartStairs+4,
                    bmp
                );
            } else if( showActivity == 2 && steps != null ) {
                var kombiAnzeige = steps.toString();
                dc.drawText(
                    hWidth+(15+constSpace)/2,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace),
                    Gfx.FONT_TINY,
                    kombiAnzeige,
                    Gfx.TEXT_JUSTIFY_CENTER
                );
                bmp = Ui.loadResource(Rez.Drawables.steps);
                dc.drawBitmap(
                    hWidth-(15+constSpace)/2-dc.getTextWidthInPixels(kombiAnzeige, Gfx.FONT_SMALL)/2,
                    hHeight+8-dc.getFontDescent(Gfx.FONT_SMALL)+3*(constAscentFontSmall+constSpace)+4,
                    bmp
                );
            }
        }

    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        //BTL
        //isHighPower = true;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        //BTL
        //isHighPower = false;
    }
    // Verzoegerung ermitteln
    function minutesFromTimestamp(now, timestamp) {
        return( (now - timestamp/1000) / 60 );
    }

}
