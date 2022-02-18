using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Background;
using Toybox.Time;

var fehler, fehler_code = "";
var delay = 20;
var adjustTime = true;
var zielbereichLow, zielbereichHigh;
var energy = 1;
var pinfit = 0;
var eco = 0;
var punkte;
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
        //Make sure we are not currently in the background thread, since you cannot use
        //the object store in the background context
        if( false == isBackground ) {
            App.Storage.setValue("punkteWatchface", punkte);
        }
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
        if( fehler == false && data != null && data instanceof Toybox.Lang.Array && data.size() > 0 && data[0]["date"] != null ) {
            punkte = data;
            App.Storage.setValue("punkteWatchface", punkte);
            calculation = true;
            var differenz = Time.now().value() - data[0]["date"]/1000;
            if( differenz != null && differenz > (35 + delay) && differenz < 300 ) {
                adjustTime = true;
                duration = new Time.Duration(600 - differenz + 15 + delay);
            } else {
                adjustTime = false;
                var delta_errechnet;
                if( data.size() > 1 && data[0]["sgv"] != null && data[0]["date"] != null && data[1]["sgv"] != null && data[1]["date"] != null  && punkte[0]["date"] > punkte[1]["date"] ) {
                    delta_errechnet = ( data[0]["sgv"] - data[1]["sgv"] ) / ( (data[0]["date"] - data[1]["date"]) * 0.001 )  * 5 * 60;
                    //ecoMode
                    if( eco == 1 ) {
                        energy = (data[0]["sgv"] < 120 && delta_errechnet <= -5) || delta_errechnet <= -10 || data[0]["sgv"] < 90 ? 1 : 2;
                    } else {
                        energy = 1;
                    }
                } else {
                    delta_errechnet = null;
                    energy = 1;
                }
                duration = differenz != null && differenz < (10 + delay) ? new Time.Duration(energy * 5 * 60 + 15 + delay) : new Time.Duration(energy * 5 * 60);
            }
            nextTime = lastTime != null ? lastTime.add(duration) : Time.now();
        } else {
            fehler_code = data;
            nextTime = lastTime != null ? lastTime.add(new Time.Duration(5 * 60)) : Time.now();
        }
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
        eco = App.getApp().getProperty("eco").toNumber();
        lowPowerModeEnabled = App.getApp().getProperty("lowPowerMode").toNumber() == 0 ? true : false;
        if( masseinheit == null ) { masseinheit = 0; }
        if( zielbereichLow == null ) { zielbereichLow = 70; }
        if( zielbereichHigh == null ) { zielbereichHigh = 180; }
        if( delay == null ) { delay = 20; }
        if( eco == null ) { eco = 0; }
        if( pinfit == null ) { pinfit = 0; }
        if( showNotification == null ) { showNotification = 1; }
    }

}