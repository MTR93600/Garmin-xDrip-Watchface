using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Background;
using Toybox.Time;

var fehler, fehler_code = "";
var delay = 20;
var adjustTime = true;
var zielbereichLow, zielbereichHigh;
var pinfit = 0;
var punkte;
var bgReadingsAccumulated = new [1];
var numberValuesTotal = 36, newValues = 1, minutes = 5;
var calculation = true;
var nextTime;
var bmpStopwatch, bmpBluetooth, bmpAlarmclock, bmpSteps, bmpStairs, bmpHeart, bmpSteps2, bmpHeart2, bmpHeartStairs, bmpNotification;

//BTL
var isBackground = false;
var isClosing = false;
var isHighPower = true;

var lowPowerModeEnabled = false;

(:background)
class CGMWatchfaceApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
        //BTL
        //Indicate the face has returned and we can draw updates again
        isClosing = false;
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
        //BTL
        //Indicate the watch has navigated away for some reason, whether it was changing
        //widgets, settings menu, activity, etc. This will always be called in a watch
        //face when the face is hidden.
        isClosing = true;
        Background.deleteTemporalEvent();
        //Make sure we are not currently in the background thread, since you cannot use
        //the object store in the background context
        if( isBackground != null && false == isBackground /*&& punkte != null && punkte instanceof Lang.Array && bgReadingsAccumulated != null*/) {
            //App.Storage.setValue("punkteWatchface", punkte);
            //App.Storage.setValue("bgReadingsAccumulatedWatchface", bgReadingsAccumulated); 
        
            // Free resources
            bmpStopwatch = null;
            bmpBluetooth = null;
            bmpAlarmclock = null;
            bmpSteps = null;
            bmpStairs = null;
            bmpHeart = null;
            bmpNotification = null;
            bmpHeartStairs = null;
        }
    }

    // Return the initial view of your application here
    function getInitialView() {
        if( Toybox.System has :ServiceDelegate && System.getDeviceSettings().phoneConnected ) {
            //Sys.println("InitialView: has Service Delegate");
            var lastTime = Background.getLastTemporalEventTime();
            if (lastTime != null) {
                var nextTime = lastTime.add(new Time.Duration(5 * 60));
                Background.registerForTemporalEvent(nextTime);
            } else {
                Background.registerForTemporalEvent(Time.now());
            }
            adjustTime = false;
        }
        return [ new CGMWatchfaceView() ];
    }

    function onBackgroundData(data) {
        //BTL
        //Indicate we are no longer in the background, so we can store data in the object store
        isBackground = false;
        fehler = data.toString().substring(0,1).equals("[") ? false : true;
        var lastTime = Background.getLastTemporalEventTime();
        var calcDuration = 0;
        if( fehler == false && data != null && data instanceof Toybox.Lang.Array && data.size() > 0 && data[0]["date"] != null ) {
            punkte = data;
            App.Storage.setValue("punkteWatchface", punkte);
            calculation = true;
            // date may be unix-seconds (AAPS) or milliseconds (xDrip/NS)
            var rawDate = data[0]["date"];
            var dateSec = rawDate;
            if (rawDate > Time.now().value() + 86400 || rawDate > 2000000000) {
                dateSec = rawDate / 1000;
            }
            var differenz = Time.now().value() - dateSec;
            if( delay == 999 || (minutes != null && minutes == 1) ) {
                // Time adjustment deactivated or BG values per minute
                calcDuration = 300;
            } else if( differenz != null && differenz > (40 + delay)) {
                // Delay greater than 40 seconds,
                // adjust the time by waiting up to 10 minutes
                adjustTime = true;
                calcDuration = 600 - differenz + 15 + delay;              
            } else {
                // Distance to measurement very small or correct
                adjustTime = false;
                calcDuration = differenz != null && differenz < (10 + delay) ? 300 + 15 + delay : 300;
            }
            if( calcDuration < 0 ) {
                // If the last measurement is more than 10 minutes ago,
                // a negative difference occurs; sett 300 sec to avoid exception
                calcDuration = 300;
            } else if( calcDuration < 300 ) {
                // Distance to measurement greater than 5 minutes,
                // thus the difference is less than 5 minutes
                calcDuration = calcDuration + 300;
            }
        } else {
            // Error during query, try again in 5 minutes
            fehler_code = data;
            calcDuration = 300;
        }
        // Register the background process
        nextTime = lastTime != null ? lastTime.add(new Time.Duration(calcDuration)) : Time.now();
        Background.registerForTemporalEvent(nextTime);
    }

    function getServiceDelegate(){
        return [new CGMWatchfaceBGServiceDelegate()];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
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

}