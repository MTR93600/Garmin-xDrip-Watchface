using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications as Comm;
using Toybox.ActivityMonitor as Act;

// The Service Delegate is the main entry point for background processes
// our onTemporalEvent() method will get run each time our periodic event
// is triggered by the system.

(:background)
class CGMWatchfaceBGServiceDelegate extends Toybox.System.ServiceDelegate {
	
	function initialize() {
		Sys.ServiceDelegate.initialize();
	}
	
    function onTemporalEvent() {
    	var now=Sys.getClockTime();
    	var ts=now.hour+":"+now.min.format("%02d");
        Sys.println("bg exit: "+ts);
        
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
		
		var url = "http://127.0.0.1:17580/sgv.json?brief_mode=Y&count=18&all_data=Y";
		if( steps != null || heartrate != null ) {
			if(steps != null) {
    			url = url + "&steps=" + steps;
			}
			if( heartrate != null) {
				url = url + "&heart=" + heartrate;
			}
		}
		Sys.println(url); 
 		//url = "https://maysbz.herokuapp.com/api/v1/entries/sgv.json?count=18";
        Comm.makeWebRequest( url, {}, { :headers => { "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED }, :responseType => Comm.HTTP_RESPONSE_CONTENT_TYPE_JSON}, method(:verarbeiteWerte) );
    }
    
    function verarbeiteWerte( responseCode, data ) {
    	Sys.println("verarbeite Werte, Code:" + responseCode);
        if( responseCode == 200 ) { Background.exit(data); }
        else { Background.exit(responseCode); }
    }

}
