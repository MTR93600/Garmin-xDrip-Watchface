using Toybox.Application as App;
using Toybox.Background;
using Toybox.System as Sys;
using Toybox.Communications;
using Toybox.ActivityMonitor;
using Toybox.Lang as Lang;
using Toybox.Time;

(:background)
class CGMWatchfaceBGServiceDelegate extends Toybox.System.ServiceDelegate {

    // Epoch seconds of the newest HR sample included in this request. Saved only after HTTP 200.
    var pendingHrSentUntil;

    function initialize() {
        Sys.ServiceDelegate.initialize();
        // BTL
        isBackground = true;
        pendingHrSentUntil = null;
    }

    function onTemporalEvent() {
        pendingHrSentUntil = null;
        var xDripSpike = App.getApp().getProperty("xDripSpike").toNumber();
        if( xDripSpike == null ) {
            xDripSpike = 0;
        }
         // Heartrate & Steps. xDrip keeps a 4-sample average. AAPS sends each sample below.
        var steps = ActivityMonitor.getInfo().steps;
        var avgHeartrate = 0;
        if( ActivityMonitor has :getHeartRateHistory && xDripSpike == 0 ) {
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
            url = "http://127.0.0.1:28891/sgv.json?brief_mode=true&count=48"; // AAPS — more pts so journal stays current
            if(steps != null) {
                url = url + "&steps=" + steps;
            }
            url = url + aapsHeartRateQuery();
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

    // HR samples since the previous successful AAPS call, oldest first, each with its own time.
    // hrSamples=epoch:bpm,epoch:bpm  Cursor advances only for samples actually put on the URL.
    function aapsHeartRateQuery() {
        pendingHrSentUntil = null;
        if (!(ActivityMonitor has :getHeartRateHistory)) {
            return "";
        }
        var nowSec = Time.now().value();
        var sentUntil = null;
        try {
            sentUntil = App.Storage.getValue("aapsHrSentUntil");
        } catch (ex) {
            sentUntil = null;
        }
        if (sentUntil != null) {
            sentUntil = sentUntil.toNumber();
        }
        // No previous call: the same 5-minute span as the poll, but each sample keeps its time.
        var since = nowSec - 300;
        if (sentUntil != null && sentUntil > 0 && sentUntil < nowSec) {
            since = sentUntil;
        }
        var span = nowSec - since;
        if (span < 60) {
            span = 60;
        } else if (span > 6 * 3600) {
            span = 6 * 3600;
        }
        var hrHistory = ActivityMonitor.getHeartRateHistory(new Time.Duration(span), false);
        var encoded = "";
        var count = 0;
        var lastSent = null;
        var guard = 0;
        var sample = hrHistory.next();
        while (sample != null && count < 60 && guard < 500) {
            guard = guard + 1;
            var bpm = sample.heartRate;
            var whenSec = sample.when != null ? sample.when.value() : null;
            if (bpm != null && bpm != ActivityMonitor.INVALID_HR_SAMPLE && bpm > 10 && whenSec != null && whenSec > since) {
                if (count > 0) {
                    encoded = encoded + ",";
                }
                encoded = encoded + whenSec + ":" + bpm;
                lastSent = whenSec;
                count = count + 1;
            }
            sample = hrHistory.next();
        }
        if (count == 0) {
            return "";
        }
        pendingHrSentUntil = lastSent;
        return "&hrSamples=" + encoded + "&device=Garmin-Watchface";
    }

    function verarbeiteWerte( responseCode, data ) {
        //Sys.println("verarbeite Werte, Code:" + responseCode);
        //Sys.println(data);
        if( responseCode == 200 ) {
            if (pendingHrSentUntil != null) {
                try {
                    App.Storage.setValue("aapsHrSentUntil", pendingHrSentUntil);
                } catch (ex) {}
            }
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
                        "tbr" => data[0]["tbr"],
                        "target" => data[0]["target"],
                        "mode" => data[0]["mode"],
                        "tbrMins" => data[0]["tbrMins"],
                        "tir" => data[0]["tir"],
                        "basalHistory" => data[0]["basalHistory"],
                        "smbHistory" => data[0]["smbHistory"]
                    };
                }
                if (pendingHrSentUntil != null) {
                    data[0]["hrSentUntil"] = pendingHrSentUntil;
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
