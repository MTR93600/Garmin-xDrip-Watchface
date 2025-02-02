using Toybox.Application as App;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;
using Toybox.ActivityMonitor;
using Toybox.Lang as Lang;
using Toybox.Time;

(:background)
class CGMWatchfaceBGServiceDelegate extends Toybox.System.ServiceDelegate {

    function initialize() {
        Sys.ServiceDelegate.initialize();
        // BTL
        isBackground = true;
    }

    function onTemporalEvent() {
        var xDripSpike = App.getApp().getProperty("xDripSpike").toNumber();
        if( xDripSpike == null ) {
            xDripSpike = 0;
        }
         // Heartrate & Steps
        var steps = ActivityMonitor.getInfo().steps;
        var avgHeartrate = 0;
        if( ActivityMonitor has :getHeartRateHistory && (xDripSpike == 0 || xDripSpike == 4) ) {
            var heartrate;
            var avgCounter = 0;
            var hrHistory =  ActivityMonitor.getHeartRateHistory(4, true);
            for (var i = 0; i < 4; i++ ) {
                var sample = hrHistory.next();
                if( sample ) {
                    heartrate = sample.heartRate;
                    if( heartrate && heartrate != ActivityMonitor.INVALID_HR_SAMPLE ) { // Plausibilitaet des Wertes pruefen
                        avgHeartrate += heartrate;
                        avgCounter ++;
                    }
                }
                //Sys.println(avgCounter + ":" + avgHeartrate);
            }
            if (avgHeartrate != 0 && avgCounter != 0) {
                avgHeartrate = (avgHeartrate.toFloat() / avgCounter.toFloat()).toNumber();
                //Sys.println(avgHeartrate);
            }
        }
        // Build URL & WebRequest
        var url = "http://127.0.0.1:17580/sgv.json?brief_mode=Y&count=18&all_data=Y"; // xDrip+-URL
        if(steps != null) {
            url = url + "&steps=" + steps;
        }
        if( avgHeartrate != 0) {
            url = url + "&heart=" + avgHeartrate;
        }
        if( xDripSpike == 4 ) {
            url = "http://127.0.0.1:28891/sgv.json?brief_mode=true&count=24"; // AAPS-URL
            if( avgHeartrate != 0 ) {
                var hrEnd = Time.now().value();
                var hrStart = hrEnd - 300;
                url = url + "&hr=" + avgHeartrate + "&hrStart=" + hrStart + "&hrEnd=" + hrEnd + "&device=" + "Garmin-Watchface";
            }
        } else if( xDripSpike == 1 ) {
            url = "http://127.0.0.1:1979/sgv.json?brief_mode=Y&count=18&all_data=Y"; // Spike-URL
        } else if ( xDripSpike >= 2 ) {
            var nightscoutURL = App.getApp().getProperty("URL").toString();
            if( nightscoutURL != null ) {
                url = "https://" + nightscoutURL + "/api/v1/entries/sgv.json?count=11"; // Nightscout-URL
            }
            var nightscoutToken = App.getApp().getProperty("NsToken").toString();
            if( xDripSpike == 3 && nightscoutToken != null ) {
                url = url + "&token=" + nightscoutToken; // add Nightscout Token
            }
        }
        //Sys.println(url);
        Communications.makeWebRequest( url, {},
            { :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},
            method(:verarbeiteWerte) );
    }

    function verarbeiteWerte( responseCode, data ) {
        //Sys.println("verarbeite Werte, Code:" + responseCode);
        //Sys.println(data);
        if( responseCode == 200 ) { 
            if( data != null && data instanceof Lang.Array && data.size() > 0 && data[0]["date"] != null ) {
                var xDripSpike = App.getApp().getProperty("xDripSpike").toNumber();
                if( xDripSpike == 1 ) {
                    // Spike
                    data[0] = { 
                        "date" => data[0]["date"].toLong(), 
                        "sgv" => data[0]["sgv"],
                        "units_hint" => data[0]["units_hint"],
                        "delta" => data[0]["delta"],
                        "iob" => data[0]["IOB"],
                        "cob" => data[0]["COB"],
                    };
                } else {
                    // Nighscout, xDrip+, AAPS
                    data[0] = { 
                        "date" => data[0]["date"].toLong(), 
                        "sgv" => data[0]["sgv"],
                        "units_hint" => data[0]["units_hint"],
                        "delta" => data[0]["delta"],
                        "aaps" => data[0]["aaps"],
                        "aaps-ts" => data[0]["aaps-ts"],
                        "iob" => data[0]["iob"],
                        "cob" => data[0]["cob"],
                        "tbr" => data[0]["tbr"]
                    };
                }
                
                for( var i = 1; i < data.size(); i++ ) {
                    if( data[i]["date"] != null ) {
                        data[i] = { "date" => data[i]["date"].toLong(), "sgv" => data[i]["sgv"] };
                    }                 
                }
            }
            Background.exit(data); 
        } else { Background.exit(responseCode); }
    }

}
