using Toybox.Application as App;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications as Comm;
using Toybox.ActivityMonitor as Act;

(:background)
class CGMWatchfaceBGServiceDelegate extends Toybox.System.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
		// BTL
		isBackground = true;
	}
	
    function onTemporalEvent() {        
         // Heartrate & Steps
        var steps = Act.getInfo().steps;  
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
		// Build URL & WebRequest
		var url = "http://127.0.0.1:17580/sgv.json?brief_mode=Y&count=18&all_data=Y"; // xDrip+-URL
		var xDripSpike = App.getApp().getProperty("xDripSpike").toNumber(); 
		if( xDripSpike == null ) {
			xDripSpike = 0;
		}
    	if( xDripSpike == 1 ) {
			url = "http://127.0.0.1:1979/sgv.json?brief_mode=Y&count=18&all_data=Y"; // Spike-URL
		} else if ( xDripSpike == 2 ) {
			var nightscoutURL = App.getApp().getProperty("URL").toString(); 
			if( nightscoutURL != null ) {
				url = "https:/" + nightscoutURL + "/api/v1/entries/sgv.json?count=12"; // Nightscout-URL
			}				
		}
		if(steps != null) {
   			url = url + "&steps=" + steps;
		}
		if( heartrate != null) {
			url = url + "&heart=" + heartrate;
		}
 		//Sys.println(url);
        Comm.makeWebRequest( url, {}, { :headers => { "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED }, :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON}, method(:verarbeiteWerte) );
    }
    
    function verarbeiteWerte( responseCode, data ) {
    	//Sys.println("verarbeite Werte, Code:" + responseCode);
    	//Sys.println(data);
    	if( responseCode == 200 ) { Background.exit(data); }
        else { Background.exit(responseCode); }
    }

}
