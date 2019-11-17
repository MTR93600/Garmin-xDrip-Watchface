using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Background;
using Toybox.Time;

var fehler, fehler_code = ""; 
var adjustAAPS = 0, delay = 0;
var adjustTime = true;
var zielbereichLow, zielbereichHigh;
var basalorcob;
var energy = 1;
var eco = 0;
var punkte;

//BTL
var isBackground = false;
var isClosing = false;
//var isHighPower = false;

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
    	     
        adjustTime = false;
        fehler = data.toString().substring(0,1).equals("[") ? false : true;
        if( fehler == false && data != null && data instanceof Toybox.Lang.Array && data.size() > 0 && data[0]["date"] != null ) { 
        	punkte = data;                   	
        	var differenz = Time.now().value() - data[0]["date"]/1000;
        	if( differenz != null && differenz > (30 + adjustAAPS + delay) && differenz < 300 ) {
        		duration = new Time.Duration(600 - differenz + 15 + adjustAAPS + delay);
        		adjustTime = true;
        		energy = 1;
        	} else {
        		var delta_errechnet;
            	if( data.size() > 1 && data[0]["sgv"] != null && data[0]["date"] != null && data[1]["sgv"] != null && data[1]["date"] != null ) {
            		delta_errechnet = ( data[0]["sgv"] - data[1]["sgv"] ) / ( (data[0]["date"] - data[1]["date"]) * 0.001 )  * 5 * 60;
            		//ecoMode
            		if( eco == 1 ) {
            			if( (data[0]["sgv"] < 120 && delta_errechnet <= -5) || delta_errechnet <= -10 || data[0]["sgv"] < 90  ) {
            				energy = 1;
            			} else {
            				energy = 2;
            			}
            		} else {
            			energy = 1;
            		}    	       	
            	} else {
            		delta_errechnet = null;
            		energy = 1;
            	} 
        		if( differenz != null && differenz < (10 + adjustAAPS + delay) ) {
        			duration = new Time.Duration(energy * 5 * 60 + 15 + adjustAAPS + delay); 
        		} else {
        			duration = new Time.Duration(energy * 5 * 60);
        		}
        	}
        	var lastTime = Background.getLastTemporalEventTime();
        	if (lastTime != null ) {
        		var nextTime = lastTime.add(duration);
        		Background.registerForTemporalEvent(nextTime);	
        	} else {
    			Background.registerForTemporalEvent(Time.now());
        	}
        } else {
            fehler_code = data;
    		var lastTime = Background.getLastTemporalEventTime();
    		if (lastTime != null) {
				var nextTime = lastTime.add(new Time.Duration(5 * 60));	
				Background.registerForTemporalEvent(nextTime);
			} else {
    			Background.registerForTemporalEvent(Time.now());
    		}
    		energy = 1;
        }
	}
	
	function getServiceDelegate(){
        return [new CGMWatchfaceBGServiceDelegate()];
    }
    
    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
    	zielbereichLow = App.getApp().getProperty("Zielbereich1").toNumber(); 
        zielbereichHigh = App.getApp().getProperty("Zielbereich2").toNumber();
        basalorcob = App.getApp().getProperty("BasalorCOB").toNumber();
        delay = App.getApp().getProperty("Delay").toNumber();
        eco = App.getApp().getProperty("eco").toNumber();
        if( zielbereichLow == null ) { zielbereichLow = 70; }
        if( zielbereichHigh == null ) { zielbereichHigh = 180; }
        if( basalorcob == null ) { basalorcob = 0; }
        if( delay == null ) { delay = 0; }
        if( eco == null ) { eco = 0; }
    }

}