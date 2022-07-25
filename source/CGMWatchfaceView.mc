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

var sgv, aaps, timestamp, duration, masseinheit = 0;
var height, width, hHeight, hWidth;
var constAscentFontTiny;
var outdatedSGV = false;
var wert, anzeigeDelta, anzeigeFehler;
var anzeigeSGV = "", verzoegerung;
var showNotification = 0;
var screenCenterPoint;
var screenShape;

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
        constAscentFontTiny = dc.getFontAscent(Gfx.FONT_TINY);
        screenCenterPoint = [dc.getWidth()/2, dc.getHeight()/2];

        masseinheit = App.getApp().getProperty("Einheiten").toNumber();
        delay = App.getApp().getProperty("Delay").toNumber();
        showNotification = App.getApp().getProperty("Notification").toNumber();
        eco = App.getApp().getProperty("eco").toNumber();
        lowPowerModeEnabled = App.getApp().getProperty("lowPowerMode").toNumber() == 0 ? true : false;
        if( masseinheit == null ) { masseinheit = 0; }
        if( delay == null ) { delay = 20; }
        if( eco == null ) { eco = 0; }
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

        var dev = Sys.getDeviceSettings();

        setLayout(Rez.Layouts.WatchFace(dc));
        var accentColor = Gfx.COLOR_WHITE; //Gfx.COLOR_BLUE;
        var secondColor = Gfx.COLOR_DK_GRAY; //Gfx.COLOR_DK_BLUE;

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

            // Call the parent onUpdate function to redraw the layout
            View.onUpdate(dc);
            //Sys.println("View.onUpdate");

            // Draw the tick marks around the edges of the screen
            var sX, sY;
            var eX, eY;
            var outerRad = width / 2;
            var innerRad = outerRad - 7;
            // Loop through each 5 minute block and draw tick marks.
            dc.setPenWidth(1);
            dc.setColor(accentColor, Gfx.COLOR_BLACK);
            for (var i = Math.PI / 30; i <= 60 * Math.PI / 30; i += (Math.PI / 30)) {
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
            }
            // Loop through each 15 minute block and draw tick marks.
            dc.setPenWidth(2);
            //dc.setColor(secondColor, Gfx.COLOR_BLACK);
            for (var i = Math.PI / 6; i <= 12 * Math.PI / 6; i += (Math.PI / 6)) {
                // Partially unrolled loop to draw two tickmarks in 15 minute block.
                sY = outerRad + innerRad * Math.sin(i);
                eY = outerRad + outerRad * Math.sin(i);
                sX = outerRad + innerRad * Math.cos(i);
                eX = outerRad + outerRad * Math.cos(i);
                dc.drawLine(sX, sY, eX, eY);
            }

            // Critical battery
            var batteryLoad = Sys.getSystemStats().battery;
            if (batteryLoad < 50) {
                if( batteryLoad > 20 ) {
                    bmpBattery = WatchUi.loadResource(Rez.Drawables.BatteryHalf);
                } else {
                    bmpBattery = WatchUi.loadResource(Rez.Drawables.Battery);
                }
                dc.drawBitmap(
                    hWidth - Math.sin(Math.PI/3)*hWidth + 10,
                    hHeight - Math.cos(Math.PI/3)*hHeight,
                    bmpBattery);
            }

            // Bluetooth
            if ( dev.phoneConnected == false ) {
                if( bmpBluetooth == null ) {
                    bmpBluetooth = Ui.loadResource(Rez.Drawables.Bluetooth);
                }
                dc.drawBitmap(
                    hWidth - Math.sin(Math.PI/3)*hWidth + 10,
                    hHeight + Math.cos(Math.PI/3)*hHeight - 25,
                    bmpBluetooth
                );
            }

            // Alarm
            if (dev.alarmCount > 0 ) {
                if( bmpAlarm == null ) {
                    bmpAlarm = WatchUi.loadResource(Rez.Drawables.Alarm);
                }
                dc.drawBitmap(
                    Math.sin(Math.PI/3)*hWidth + hWidth - 36,
                    hHeight - Math.cos(Math.PI/3)*hHeight,
                    bmpAlarm);
            }

            // Notification
            if( dev.notificationCount > 0 ) {
                if( bmpNotification == null ) {
                    bmpNotification = Ui.loadResource(Rez.Drawables.Notification);
                }
                dc.drawBitmap(
                    Math.sin(Math.PI/3)*hWidth + hWidth - 36,
                    hHeight + Math.cos(Math.PI/3)*hHeight - 25,
                    bmpNotification
                );
            }

            // Date
            dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            dc.drawText(
                width-16,
                hHeight-1,
                Gfx.FONT_TINY,
                datum,
                Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER
            );

           // BG as background
           dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
           dc.drawText(
                16,
                hHeight-1,
                Gfx.FONT_MEDIUM,
                verzoegerung + " m",
                Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                hWidth,
                height * 0.25 + 2,
                Gfx.FONT_NUMBER_THAI_HOT,
                anzeigeSGV,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER
            );
            dc.drawText(
                hWidth,
                height * 0.75 -7,
                Gfx.FONT_NUMBER_THAI_HOT,
                anzeigeDelta,
                Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER
            );
            // Strike outdated BG
            if (outdatedSGV == true) {
                dc.setPenWidth(5);
                dc.drawLine(
                    hWidth - dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_THAI_HOT)/2,
                    height * 0.25 + 5,
                    hWidth + dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_THAI_HOT)/2,
                    height * 0.25 + 5
                );
            }

            // Error
            if ( fehler == true ) {
                dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_BLACK);
                dc.drawText(
                    hWidth,
                    10,
                    Gfx.FONT_XTINY,
                    anzeigeFehler,
                    Gfx.TEXT_JUSTIFY_CENTER
                );
            }

            // Draw the hour hand
            var hourHandAngle = (((clockTime.hour % 12) * 60) + clockTime.min);
            hourHandAngle = hourHandAngle / (12 * 60.0);
            hourHandAngle = hourHandAngle * Math.PI * 2;
            dc.setColor(accentColor, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon(generateHandCoordinates(screenCenterPoint, hourHandAngle, 75, 0, 6));
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon(generateHandCoordinates(screenCenterPoint, hourHandAngle, 40, 0, 6));
            dc.setColor(secondColor, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon(generateHandCoordinates(screenCenterPoint, hourHandAngle, 35, 0, 6));


            // Draw the minute hand
            var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;
            dc.setColor(accentColor, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon(generateHandCoordinates(screenCenterPoint, minuteHandAngle, 102, 0, 6)); // 105
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon(generateHandCoordinates(screenCenterPoint, minuteHandAngle, 40, 0, 6));
            dc.setColor(secondColor, Gfx.COLOR_TRANSPARENT);
            dc.fillPolygon(generateHandCoordinates(screenCenterPoint, minuteHandAngle, 35, 0, 6));

            // White Point
            dc.setColor(accentColor, Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(hWidth, hHeight, 5);
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.drawCircle(hWidth, hHeight, 6);

            // Draw CGM
            /*var textCGM = " " + anzeigeSGV + " " + anzeigeDelta + " " + verzoegerung + "'";
            dc.setPenWidth(2);
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.fillRoundedRectangle(
                -7,
                hHeight-constAscentFontTiny/2-6,
                dc.getTextWidthInPixels(textCGM, Gfx.FONT_TINY)+14,
                constAscentFontTiny+12,
                5
            );
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_BLACK);
            dc.drawRoundedRectangle(
                -7,
                hHeight-constAscentFontTiny/2-7,
                dc.getTextWidthInPixels(textCGM, Gfx.FONT_TINY)+15,
                constAscentFontTiny+13,
                5
            );
            if( outdatedSGV == false ) {
                dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
            }
            dc.drawText(
                0,
                hHeight-1,
                Gfx.FONT_TINY,
                textCGM,
                Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER
            ); */


        } else {
//! LOW POWER
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
            dc.clear();
            dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_BLACK);
            dc.drawText(
                hWidth,
                hHeight - dc.getFontAscent(Gfx.FONT_NUMBER_HOT) - 5,
                Gfx.FONT_NUMBER_HOT,
                timeString,
                Gfx.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                hWidth,
                hHeight + 20,
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

    function generateHandCoordinates(centerPoint, angle, handLength, tailLength, width) {
        // Map out the coordinates of the watch hand
        var coords = [[-(width / 2), tailLength], [-(width / 2), -handLength], [width / 2, -handLength], [width / 2, tailLength]];
        var result = new [4];
        var cos = Math.cos(angle);
        var sin = Math.sin(angle);

        // Transform the coordinates
        for (var i = 0; i < 4; i += 1) {
            var x = (coords[i][0] * cos) - (coords[i][1] * sin) + 0.5;
            var y = (coords[i][0] * sin) + (coords[i][1] * cos) + 0.5;

            result[i] = [centerPoint[0] + x, centerPoint[1] + y];
        }

        return result;
    }

}
