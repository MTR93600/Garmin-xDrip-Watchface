//! TODO
//!
//!

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.ActivityMonitor as Act;
using Toybox.Background;

var sgv, aaps, timestamp, duration, masseinheit = 0;
var height, width;
var outdatedSGV = false;
var wert, anzeigeDelta, anzeigeFehler;
var heartAnzeige, stepsAnzeige, sgvAnzeige, verzAnzeige;
var plotSGV;
var noAAPS = 0;
var anzeigeSGV = "", anzeigeBasal = "", anzeigeIOB = "", anzeigeCOB = "", verzoegerung;

// noAAPS nur einmal hinzurechnen (sgv, verz und delta), für die Uhr und den Strich durch den BZ ist
// das dann nicht mehr nötig.

class CGMWatchfaceView extends Ui.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        //Sys.println("OnLayout");
        //setLayout(Rez.Layouts.WatchFace(dc));
        height = dc.getHeight();
        width = dc.getWidth();
        noAAPS = height / 6 - 20;
        masseinheit = App.getApp().getProperty("Einheiten").toNumber();
        zielbereichLow = App.getApp().getProperty("Zielbereich1").toNumber();
        zielbereichHigh = App.getApp().getProperty("Zielbereich2").toNumber();
        basalorcob = App.getApp().getProperty("BasalorCOB").toNumber();
        delay = App.getApp().getProperty("Delay").toNumber();
        eco = App.getApp().getProperty("eco").toNumber();
        if( masseinheit == null || masseinheit == 2 ) { masseinheit = 0; }
        if( zielbereichLow == null ) { zielbereichLow = 70; }
        if( zielbereichHigh == null ) { zielbereichHigh = 180; }
        if( basalorcob == null ) { basalorcob = 0; }
        if( delay == null ) { delay = 0; }
        if( eco == null ) { eco = 0; }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        //BTL
        isClosing = false;
        var temp = App.Storage.getValue("punkteWatchface");
        if( temp!= null && temp instanceof Lang.Array) {
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
        // Get the current time and format it correctly
        //Sys.println("onUpdate");
        var timeFormat = "$1$:$2$";
        var clockTime = Sys.getClockTime();
        var now = Time.now();
        // var info = Gregorian.info(now, Time.FORMAT_SHORT);
        //var datum = info.day + "." + info.month.format("%02d")+ ".";
        var info = Gregorian.info(now, Time.FORMAT_MEDIUM);
        var datum = info.day_of_week.substring(0,3) + " " + info.day;
        var hours = clockTime.hour;
        if (!Sys.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);

        // Background-Prozess neu starten, falls gestoppt
        if( Toybox.System has :ServiceDelegate && System.getDeviceSettings().phoneConnected ) {
            var lastTime = Background.getLastTemporalEventTime();
            if (lastTime == null || ( lastTime != null && lastTime.value() < now.value() - 600) ) {
                Background.registerForTemporalEvent(Time.now());
                adjustTime = false;
            }
        }

        // Heartrate & Steps
        // Schritte einlesen
        var steps = Act.getInfo().steps;
        var stepGoal = Act.getInfo().stepGoal;
        // Heartrate einlesen
        var heartrate;
        if (Act has :getHeartRateHistory) {
            var hrHistory =  Act.getHeartRateHistory(1, true);
            heartrate = hrHistory.next().heartRate;
            if( heartrate == ActivityMonitor.INVALID_HR_SAMPLE ) { // Plausibilität des Wertes prüfen
                heartrate = null; // Wenn nicht plausibel, variable leeren
            }
        } else {
            heartrate = null;
        }

        // CGM Daten verarbeiten

        //punkte = null;
        if( punkte != null && punkte instanceof Lang.Array && punkte.size() > 0 ) {
            //Sys.println("CGM Daten");
            if( calculation == true ) {
                calculation = false;
                // Units: mmol/l or mg/dl
                if( punkte[0]["units_hint"] != null ) {
                    if( punkte[0]["units_hint"].equals("mmol") ) {
                        masseinheit = 1;
                    } else {
                        masseinheit = 0;
                    }
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

                if( masseinheit != null && masseinheit == 1 ) {
                    // mmol
                    anzeigeSGV =  punkte[0]["sgv"] ? (0.05556 * punkte[0]["sgv"]).format("%.1f").toString() : "--";
                    // Delta in mmol, in String umwandeln, bei positiven Werten + davor
                    if( delta_errechnet != null ) {
                        delta_errechnet = 0.05556 * delta_errechnet;
                        if( delta_errechnet > 0 ) {
                            anzeigeDelta = "+" + delta_errechnet.format("%.1f").toString();
                        } else {
                            anzeigeDelta= delta_errechnet.format("%.1f").toString();
                        }
                    } else {
                        anzeigeDelta = "--";
                    }
                } else {
                    // mg
                    anzeigeSGV = punkte[0]["sgv"] != null ? punkte[0]["sgv"].toString() : "--";
                    // Delta in String umwandeln, bei positiven Werten + davor
                    if( delta_errechnet != null ) {
                        if( delta_errechnet > 0 ) {
                            anzeigeDelta = "+" + delta_errechnet.format("%.0f").toString();
                        } else {
                            anzeigeDelta = delta_errechnet.format("%.0f").toString();
                        }
                    } else {
                        anzeigeDelta = "--";
                    }
                }

                // AAPS
                //punkte[0]["aaps"] = "No Status";
                //punkte[0]["aaps"] = "10,06U";
                //punkte[0]["aaps"] = "240% 10,06U(8.27|8.34) -17,24 0g";
                //punkte[0]["aaps"] = "0,85U/h -0,36U(8.27|8.34) -17,24 35g";
                //punkte[0]["aaps"] = "1,81U -1,35 11g";
                //punkte[0]["aaps"] = "Loop deaktiviert\n0,46(0,46|0,00)";
                //punkte[0]["aaps"] = null;
                if( punkte[0]["aaps"] != null ) {
                    aaps = punkte[0]["aaps"].toString();
                    noAAPS = 0;
                    //Sys.println("AAPS: " + aaps + "\n");
                    var index1 = null, index2 = null, index3 = null, index4 = null, index5 = null;
                    if( aaps != null && aaps.equals("") == false ) {
                        if( aaps.equals("No Status") ) {
                            anzeigeBasal = "--%";
                            anzeigeIOB = "--";
                        } else if( aaps.find("oop") == true ) {
                            anzeigeBasal = "--%";
                            anzeigeIOB = "--";
                        } else {
                            index1 = aaps.find(" ");
                            index2 = aaps.find("%");
                            index3 = aaps.find("U/h");
                            index4 = aaps.find("U");
                            // Basal
                            if( index2 != null ) {
                                anzeigeBasal = aaps.substring(0,index2+1);
                            } else if( index3 != null ) {
                                anzeigeBasal = "100%";
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
                                var aapsPart2 = aaps.substring(length-6, length);
                                index5 = aapsPart2.find(" ");
                                if( index5 != null ) {
                                    var cob = aapsPart2.substring((index5+1),(aapsPart2.length()-1));
                                    anzeigeCOB = cob.toString() + " g";
                                }
                            }
                        }
                    }
                } else {
                    noAAPS = height / 6 - 20;
                    anzeigeBasal = "data.";
                    anzeigeIOB = "No";
                    anzeigeCOB = "loop";
                }
                if( punkte[0]["aaps-ts"] != null) { // Meldung AAPS Status nicht aktuell
                    var verzoegerungAAPS = minutesFromTimestamp(Time.now().value(), punkte[0]["aaps-ts"]);
                    if( verzoegerungAAPS != null && verzoegerungAAPS > 20 ) {
                        anzeigeBasal = "--%";
                        anzeigeIOB = "-- IOB";
                    }
                }
                anzeigeFehler = "";
            }

            // Delay in minutes, proof if SGV is outdated
            verzoegerung = punkte[0]["date"] != null ? minutesFromTimestamp(Time.now().value(), punkte[0]["date"]) : "999";
            outdatedSGV = ( verzoegerung != null && verzoegerung > 11 ) ? true : false;

        } else {
            //Sys.println("Keine CGM Daten");
            anzeigeFehler = "Wait max.\n5 min";
            verzoegerung = "--";
            anzeigeSGV = "---";
            anzeigeDelta = "--";
        }
        //Sys.println(noAAPS);

        // Fehleranzeige
        //Sys.println("Fehler:" + fehler );
        if( fehler != null && fehler == true ) {
            anzeigeFehler = "Error: " + fehler_code;
        }
        if( fehler != null && fehler == true && (fehler_code == -104 || fehler_code == -1 || fehler_code == -2) ) {
            anzeigeFehler += "\nBluetooth?";
        }
        if( fehler != null && fehler == true && (fehler_code == -300) ) {
            anzeigeFehler += "\nSettings?";
        }
        if( anzeigeFehler.equals("") == false && System.getDeviceSettings().phoneConnected == false ) {
            anzeigeFehler = "Bluetooth!";
        }

        //Test
        /* anzeigeSGV = "224";
        verzoegerung = "12";
        anzeigeDelta = "+14";
        anzeigeBasal = "120%";
        anzeigeIOB = "12,1"; */

        // Update the view
        var time = View.findDrawableById("TimeLabel");
        time.setText(timeString);
        time.setLocation(
            width/2-4-8,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)
        );

        var date = View.findDrawableById("DateLabel");
        date.setText(datum);
        date.setLocation(
            width/2-4-8,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)
        );

        sgvAnzeige = View.findDrawableById("sgvLabel");
        sgvAnzeige.setText(anzeigeSGV);
        sgvAnzeige.setLocation(
            width/2+4+8,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)
        );

        Sys.println(dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM) + " - " + dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM) + " - " + dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM));

        var deltaAnzeige = View.findDrawableById("deltaLabel");
        deltaAnzeige.setText(anzeigeDelta);
        deltaAnzeige.setLocation(
            width/2+4+8+dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_MEDIUM)+5,
            height/2-8-(dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)-dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM))*0.5
        );



        if( anzeigeIOB != null && anzeigeIOB.equals("") == false ) {
            var iobAnzeige = View.findDrawableById("iobLabel");
            iobAnzeige.setText(anzeigeIOB);
            iobAnzeige.setLocation(
                width/2+4+8,
                height/2+8-dc.getFontDescent(Gfx.FONT_SMALL)
            );
        }

        if( anzeigeCOB != null && anzeigeCOB.equals("") == false ) {
            var cobAnzeige = View.findDrawableById("cobLabel");
            cobAnzeige.setText(anzeigeCOB);
            cobAnzeige.setLocation(
                width/2+4+8,
                height/2+8-dc.getFontDescent(Gfx.FONT_SMALL)+dc.getFontAscent(Gfx.FONT_SMALL)+5
            );
        }

        if( anzeigeBasal != null && anzeigeBasal.equals("") == false ) {
            var basalAnzeige = View.findDrawableById("basalLabel");
            basalAnzeige.setText(anzeigeBasal);
            basalAnzeige.setLocation(
                width/2+4+8,
                height/2+8-dc.getFontDescent(Gfx.FONT_SMALL)+dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)+5
            );
        }

        verzAnzeige = View.findDrawableById("verzLabel");
        //if( energy == 2 ) { verzAnzeige.setColor(0x33ff33); }
        verzAnzeige.setText(verzoegerung.toString()+"'");
        if( energy == 1 ) {
            verzAnzeige.setText(verzoegerung.toString()+" min");
        } else {
            verzAnzeige.setText(verzoegerung.toString()+"' eco");
            //verzAnzeige.setColor(Gfx.COLOR_GREEN);
        }
        verzAnzeige.setLocation(
            width/2+4+8,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)
        );

/*        stepsAnzeige = View.findDrawableById("stepsLabel");
        if( steps != null ) {
            stepsAnzeige.setText(steps.toString());
            stepsAnzeige.setLocation(
                width*0.5+5+15+8,
                height*0.5-8-20-5
            );
        }
*/
        heartAnzeige = View.findDrawableById("heartrateLabel");
        if( heartrate != null ) {
            heartAnzeige.setLocation(
                width/2-4-8,
                height/2+8-dc.getFontDescent(Gfx.FONT_SMALL)+dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)+5
            );
            heartAnzeige.setText(heartrate.toString());
        } else {
            heartAnzeige.setText("");
        }


        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        //Sys.println("View.onUpdate");

        //! Ui without layout.xml
        // Balken
        if( punkte != null && punkte instanceof Lang.Array  && punkte[0]["sgv"] != null && zielbereichLow <= punkte[0]["sgv"] && punkte[0]["sgv"] <= zielbereichHigh ) {
            dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_TRANSPARENT);
        }
        dc.setPenWidth(8);
        dc.drawLine(
            width/2,
            0,
            width/2,
            height
        );
        // Horizontale Trennlinien
        dc.setPenWidth(1);
        dc.drawLine(
            0,
            height/2,
            width/2-4-2,
            height/2
        );
        dc.drawLine(
            width/2+4+2,
            height/2,
            width,
            height/2
        );

        // Zu alter Blutzucker
        //outdatedSGV = true;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        if( outdatedSGV != null && outdatedSGV == true && anzeigeSGV != null ) {
            dc.fillRectangle(
                width/2 + 4 + 7 - 2,
                height/2 - 7 - (dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)-dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM))/2,
                dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_MEDIUM)+4,
                6
            );
        }

        // Graph
        var hoeheGraph = dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)-dc.getFontDescent(Gfx.FONT_SMALL);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_LT_GRAY);
        dc.fillRectangle(
            0,
            height/2+8,
            width/2-4-8,
            hoeheGraph
        );

        if( punkte != null && punkte instanceof Lang.Array ) {
            var now = Time.now().value();
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
                //Sys.println("Faktor: " + factorY + "\n");
                //Sys.println("Differenz: " + difference + "\n");
            }
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_BLACK);
            dc.setPenWidth(3);
            plotSGV = (70 - lowValue) + graphCorr;
            if( 0 < plotSGV * (hoeheGraph*factorY) ) {
                dc.drawLine(
                    0,
                    height/2 + 7 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY)),
                    width/2-4-8,
                    height/2 + 7 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY))
                );
            } else {
                dc.drawLine(
                    0,
                    height/2 + 7 + hoeheGraph,
                    width/2-4-8,
                    height/2 + 7 + hoeheGraph
                );
            }
            plotSGV = (180 - lowValue) + graphCorr;

            if( hoeheGraph > plotSGV * (hoeheGraph*factorY) ) {
                dc.drawLine(
                    0,
                    height/2 + 7 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY)),
                    width/2-4-8,
                    height/2 + 7 + hoeheGraph - ( plotSGV * (hoeheGraph*factorY))
                );
            } else {
                dc.drawLine(
                    0,
                    height/2 + 7,
                    width/2-4-8,
                    height/2 + 7
                );
            }
            dc.setPenWidth(1);

            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            for( var i = 0; i < punkte.size(); i++ ) {
                if(punkte[i]["sgv"] != null && punkte[i]["date"] != null ) {
                    plotSGV = (punkte[i]["sgv"] - lowValue) + graphCorr;
                    // plotSGV = 300;
                    // Factor for stretching / compressing the values on the x-axis depending on the number of sgv values
                    var factorX = 1/(5 * (punkte.size() + 1)).toFloat(); // 1 / ( 5 minutes * x readings )
                    var plotBreite = width*0.5 - 4 - 7 - 4 - (minutesFromTimestamp(now, punkte[i]["date"]) * ( (width*0.5-8) * factorX) );
                    var plotHoehe = hoeheGraph - ( plotSGV * ((hoeheGraph)*factorY)); // früher: + 10 / + 10
                    if( zielbereichLow <= punkte[i]["sgv"] && punkte[i]["sgv"] <= zielbereichHigh ) {
                        dc.setColor(Gfx.COLOR_DK_GREEN, Gfx.COLOR_TRANSPARENT);
                    } else {
                        dc.setColor(Gfx.COLOR_DK_RED, Gfx.COLOR_TRANSPARENT);
                    }
                    dc.fillCircle(
                        plotBreite,
                        height*0.5 + 7 + plotHoehe, // vorher:  +10
                        3
                    );
                }
            }
        }

        if( anzeigeFehler != null ) {
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.drawText(
                width/2-4-8-5,
                height/2+8,
                Gfx.FONT_XTINY,
                anzeigeFehler,
                Gfx.TEXT_JUSTIFY_RIGHT
            );
        }

        //adjustTime = true;
        if( adjustTime != null && adjustTime == true) {
            var bmp = Ui.loadResource(Rez.Drawables.stopwatch);
            dc.drawBitmap(
               width/2+4+8+15+5,
               height/2-4-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)-22,
               bmp
            );
        }
/*
        if( steps != null) {
            var bmp = Ui.loadResource(Rez.Drawables.steps);
            dc.drawBitmap(
                width*0.5+4+5, //width*2/3-45,
                height*0.5-8-20, //height*2/3+10+8,
                bmp
            );
        }
*/
        if( heartrate != null ) {
            var bmp = Ui.loadResource(Rez.Drawables.heart);
            dc.drawBitmap(
                width/2+4+8,
                height/2+8-dc.getFontDescent(Gfx.FONT_SMALL)+dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)+5+dc.getFontAscent(Gfx.FONT_SMALL)+5+5,
                bmp
            );
        }

        // Batteriestand
        var batteryLoad = Sys.getSystemStats().battery;
        if( batteryLoad < 20 ) {
            dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        }
        // Battery body
        dc.fillRoundedRectangle(
            width/2-4-8-14,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)-5-22,
            14,
            22,
            2
        );
        // Battery contact
        dc.fillRectangle(
            width/2-4-8-14+4,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)-5-22-2,
            6,
            2
        );
        // Battery state
        var battery = batteryLoad * 18 / 100;
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Füllung
        dc.fillRoundedRectangle(
            width/2-4-8-14+2,
            height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)-5-22+2,
            10,
            18-battery,
            2
        );

        //Bluetooth connected
        if( System.getDeviceSettings().phoneConnected ) {
            var bmp = Ui.loadResource(Rez.Drawables.bluetooth);
            dc.drawBitmap(
                width/2+4+8,
                height/2-8-dc.getFontAscent(Gfx.FONT_NUMBER_MEDIUM)+dc.getFontDescent(Gfx.FONT_NUMBER_MEDIUM)-5-dc.getFontHeight(Gfx.FONT_SMALL)-4-25,
                bmp
            );
        }

        // Schritte-Ziel
        if( steps != null && stepGoal != null && stepGoal != 0 ) {
            var polygonPosition = height - ( (steps * height) / stepGoal);
            if( polygonPosition < -5 ) { polygonPosition = -5; }
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Füllung
            var polygon = [
                [width/2+4, polygonPosition+12],
                [width/2+4, polygonPosition],
                [width/2-4, polygonPosition+4],
                [width/2-4, polygonPosition+16]
            ];
            dc.fillPolygon(polygon);
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
