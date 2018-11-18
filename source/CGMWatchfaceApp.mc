using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Background;
using Toybox.Time;
using Toybox.Lang as Lang;

var sgv, delta, aaps, timestamp, duration, masseinheit = 0, punkte;
var fehler, fehler_code = ""; 
var adjustAAPS = 0;
var adjustTime = true;

class CGMWatchfaceApp extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // Return the initial view of your application here
    function getInitialView() {
    	if(Toybox.System has :ServiceDelegate) {
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
        adjustTime = false;
        fehler = data.toString().substring(0,1).equals("[") ? false : true;
        if( fehler == false && data != null && data instanceof Array && data[0]["date"] != null ) { 
        	punkte = data;                   	
        	var differenz = Time.now().value() - data[0]["date"]/1000;
        	if( differenz != null && differenz > 30 && differenz < 300 ) {
        		duration = new Time.Duration(600 - differenz + 15 + adjustAAPS);
        		adjustTime = true;
        	} else {
        		if( differenz != null && differenz < (10 + adjustAAPS) ) {
        			duration = new Time.Duration(5 * 60 + 15 + adjustAAPS); 
        		} else {
        			duration = new Time.Duration(5 * 60);
        		}
        	}
        	var lastTime = Background.getLastTemporalEventTime();
        	if (lastTime != null) {
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
        }
        Ui.requestUpdate();
	}
	
	function getServiceDelegate(){
        return [new CGMWatchfaceBGServiceDelegate()];
    }
    
    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        Ui.requestUpdate();
    }

}