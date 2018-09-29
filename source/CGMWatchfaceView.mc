using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.ActivityMonitor as Act;

var height, width;
var anzeigeSGV = "", anzeigeBasal = "", anzeigeIOB = "", verzoegerung;
var wert, anzeigeDelta, anzeigeFehler;
var plotSGV;
var noAAPS;

class CGMWatchfaceView extends Ui.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }
    
    // Verzoegerung ermitteln
    function minutesFromTimestamp(now, timestamp) {
    	return( (now - timestamp/1000) / 60 );
    }

    // Load your resources here
    function onLayout(dc) {
    	Sys.println("OnLayout");
        setLayout(Rez.Layouts.WatchFace(dc));
        height = dc.getHeight();
        width = dc.getWidth();
        var temp = App.Storage.getValue("punkte");
        if( temp!=null && temp instanceof Array) {
        	punkte = temp; 
        }
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
        // Get the current time and format it correctly
        Sys.println("onUpdate");
        var timeFormat = "$1$:$2$";
        var clockTime = Sys.getClockTime();
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var datum = info.day + "." + info.month + "." + info.year;
        Sys.println(datum);
        var hours = clockTime.hour;
        if (!Sys.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);
        
        // Heartrate & Steps
        // Schritte einlesen
        var steps = Act.getInfo().steps;      
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
		Sys.println("S+H:" + steps + " - " + heartrate);
    	// CGM Daten verarbeiten
    	noAAPS = dc.getFontHeight(Gfx.FONT_SYSTEM_TINY);
    	//punkte = null;
    	if( punkte != null ) { 
    		Sys.println("CGM Daten");
        	// Einheiten            
        	if( punkte[0]["units_hint"] ) {
            	if( punkte[0]["units_hint"].equals("mmol") ) {
            		masseinheit = 1;
            	} else {
                	masseinheit = 0;
               	}
            } 
    		if( masseinheit == 1 ) {  
              	anzeigeSGV =  punkte[0]["sgv"] ? (0.05556 * punkte[0]["sgv"]).format("%.1f").toString() : "--";
               	// Delta in mmol, in String umwandeln, bei positiven Werten + davor
           		if( punkte[0]["delta"] ) {
               		delta = 0.05556 * punkte[0]["delta"];
               	 	if(delta > 0 ) {
               			anzeigeDelta = "+" + delta.format("%.1f").toString();
           			} else {
           				anzeigeDelta= delta.format("%.1f").toString();
           			}
           		} else {
           			anzeigeDelta = "--";
           		}  
           	} else {
           		// mg
               	anzeigeSGV = punkte[0]["sgv"] ? punkte[0]["sgv"].toString() : "--";
               	// Delta in String umwandeln, bei positiven Werten + davor
           		if( punkte[0]["delta"] ) {
           			delta = punkte[0]["delta"];
           			if( delta > 0 ) {
              			anzeigeDelta = "+" + delta.format("%.0f").toString();
           			} else {
           				anzeigeDelta = delta.format("%.0f").toString();
           			} 
           		} else {
           			anzeigeDelta = "--";
           		}                	
           	} 
			verzoegerung = punkte[0]["date"] ? minutesFromTimestamp(Time.now().value(), punkte[0]["date"]) : "999";
        	
        	
        	//punkte[0]["aaps"] = "240% 10.06U(8.27|8.34) -17,24 35g"; 
        	if( punkte[0]["aaps"] ) {
        		Sys.println("AAPS");
             	aaps = punkte[0]["aaps"].toString();   
             	if( aaps != null && aaps.equals("") == false ) {
        			var index = aaps.find("%");
            		anzeigeBasal = aaps.substring(0,index+1);
            		var index2 = aaps.find("U");
            		anzeigeIOB = aaps.substring(index+2,index2-1)+"U";
            		noAAPS = 0;
            	}
			} else {
					noAAPS = dc.getFontHeight(Gfx.FONT_SYSTEM_TINY);
					anzeigeBasal = "";
					anzeigeIOB = "";
			}             	        	
            if( punkte[0]["aaps-ts"] ) { // Meldung AAPS Status nicht aktuell
                var verzoegerungAAPS = minutesFromTimestamp(Time.now().value(), punkte[0]["aaps-ts"]); 
                if( verzoegerungAAPS > 20 ) {  
                	anzeigeBasal = "--%";
					anzeigeIOB = "--U";
				}
            }
            
            
			anzeigeFehler = "";
		} else {
			Sys.println("Keine CGM Daten");
			anzeigeFehler = "Wait max. 5'";
			verzoegerung = "--";
			anzeigeSGV = "---";
			anzeigeDelta = "--";
		}
		
		// Fehleranzeige	
		Sys.println("Fehler:" + fehler );
 		if( fehler == true ) { anzeigeFehler = "Error: " + fehler_code; } 

        // Update the view
        var time = View.findDrawableById("TimeLabel");
        time.setText(timeString);
        time.setLocation(width*2/3-15, height/3-dc.getFontHeight(Gfx.FONT_TINY)-dc.getFontHeight(Gfx.FONT_LARGE));
        var date = View.findDrawableById("DateLabel");
        date.setText(datum);
        date.setLocation(width*2/3-15, height/3-dc.getFontHeight(Gfx.FONT_TINY)-5);
        
        var verzAnzeige = View.findDrawableById("verzLabel");
        verzAnzeige.setText(verzoegerung.toString()+"'");
        verzAnzeige.setLocation(width*2/3+5, height/3-dc.getFontHeight(Gfx.FONT_TINY)-5 + noAAPS);
        var sgvAnzeige = View.findDrawableById("sgvLabel");
        sgvAnzeige.setText(anzeigeSGV);
        sgvAnzeige.setLocation(width*2/3+5, height/3-7 + noAAPS);              
        var deltaAnzeige = View.findDrawableById("deltaLabel");
        deltaAnzeige.setText(anzeigeDelta);
        deltaAnzeige.setLocation(width*2/3+5, height/3+dc.getFontAscent(Gfx.FONT_LARGE)-4 + noAAPS);
        
        if( anzeigeBasal.equals("") == false ) {
        	var basalAnzeige = View.findDrawableById("basalLabel");
        	basalAnzeige.setText(anzeigeBasal);
        	basalAnzeige.setLocation(width*2/3+5, height/3+dc.getFontAscent(Gfx.FONT_LARGE)+dc.getFontAscent(Gfx.FONT_MEDIUM)+2);           //width*2/3-15, height*2/3+5);
        }
        if( anzeigeIOB.equals("") == false ) {
        	var iobAnzeige = View.findDrawableById("iobLabel");
        	iobAnzeige.setText(anzeigeIOB);
        	iobAnzeige.setLocation(width*2/3+5, height/3+dc.getFontAscent(Gfx.FONT_LARGE)+dc.getFontAscent(Gfx.FONT_MEDIUM)+dc.getFontAscent(Gfx.FONT_TINY)+7);
        }
        
        if( steps ) {
            var stepsAnzeige = View.findDrawableById("stepsLabel");
        	stepsAnzeige.setText(steps.toString());
        	stepsAnzeige.setLocation(width*2/3-35, height*2/3+5);
        }
        if( heartrate ) {
            var heartAnzeige = View.findDrawableById("heartrateLabel");
        	heartAnzeige.setText(heartrate.toString());
        	if( steps ) {
        		heartAnzeige.setLocation(width*2/3-35, height*2/3+5+dc.getFontAscent(Gfx.FONT_TINY)+5);
        	} else {
        		heartAnzeige.setLocation(width*2/3-35, height*2/3+5);
        	}
        	
        }
        
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        Sys.println("View.onUpdate");
        
        dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        dc.fillRectangle(width*2/3-10, 0, 10, height);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(0, height/3, width*2/3-15, height/3);
        dc.drawLine(0, height*2/3, width*2/3-15, height*2/3);
        
        if( punkte != null ) {      
        	dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            var now = Time.now().value();
            for( var i = 0; i < punkte.size(); i++ ) {
            	if(punkte[i]["sgv"] && punkte[i]["date"] ) {
            		plotSGV = ( punkte[i]["sgv"] > 300 ) ? 300 : punkte[i]["sgv"];
            	    // plotSGV = 300;
                	var plotBreite = width*2/3 - 15 - 3 - (minutesFromTimestamp(now, punkte[i]["date"]) * ( (width*2/3-15) * 0.0111) ); // Faktor 1 / 90 
                	var plotHoehe = height/3 - ( plotSGV * (height/3*0.0033) - 5); // Faktor: 1/300
                	if( 70 <= punkte[i]["sgv"] && punkte[i]["sgv"] <= 180 ) {
                		dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT); 
                	} else {
                		dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT); 
                	}
                	dc.fillCircle( plotBreite, height/3 + plotHoehe, 3 );
                }                           
            }
        }
        
        if( anzeigeFehler ) {
        	dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        	dc.drawText(width*2/3-15, height*2/3-dc.getFontHeight(Gfx.FONT_TINY)-5, Gfx.FONT_TINY, anzeigeFehler, Gfx.TEXT_JUSTIFY_RIGHT );
        }
        
        if( System.getDeviceSettings().phoneConnected ) {	
        	var bmp = Ui.loadResource(Rez.Drawables.bluetooth);
        	dc.drawBitmap(width*2/3+5, height/3-dc.getFontHeight(Gfx.FONT_TINY)-dc.getFontAscent(Gfx.FONT_LARGE), bmp);
        }
        
        if( adjustTime ) {
        	var bmp = Ui.loadResource(Rez.Drawables.stopwatch);
        	dc.drawBitmap(width*2/3+10+dc.getTextWidthInPixels(verzoegerung.toString()+"'", Gfx.FONT_TINY), height/3-dc.getFontAscent(Gfx.FONT_TINY)-7+noAAPS, bmp);
        }
        
        if( steps ) {
        	var bmp = Ui.loadResource(Rez.Drawables.steps);
        	dc.drawBitmap(width*2/3-30, height*2/3+8, bmp);
        }
        if( heartrate ) {
        	var bmp = Ui.loadResource(Rez.Drawables.heart);
        	if( steps ) {
        		dc.drawBitmap(width*2/3-30, height*2/3+8+dc.getFontAscent(Gfx.FONT_TINY)+5, bmp);
        	} else {
        		dc.drawBitmap(width*2/3-30, height*2/3+8, bmp);
        	}
        }
        
        // Batteriestand
        Sys.println("Batteriestand");
        dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(width*2/3+5, height/3+dc.getFontAscent(Gfx.FONT_LARGE)+dc.getFontAscent(Gfx.FONT_MEDIUM)+2*dc.getFontAscent(Gfx.FONT_TINY)+17, 25, 10, 2);
        dc.drawRoundedRectangle(width*2/3+5, height/3+dc.getFontAscent(Gfx.FONT_LARGE)+dc.getFontAscent(Gfx.FONT_MEDIUM)+2*dc.getFontAscent(Gfx.FONT_TINY)+18, 24, 10, 2);
        dc.fillRectangle(width*2/3+5+25, height/3+dc.getFontAscent(Gfx.FONT_LARGE)+dc.getFontAscent(Gfx.FONT_MEDIUM)+2*dc.getFontAscent(Gfx.FONT_TINY)+20, 2, 4);
        var battery = Sys.getSystemStats().battery * 25 / 100;
        dc.fillRoundedRectangle(width*2/3+5, height/3+dc.getFontAscent(Gfx.FONT_LARGE)+dc.getFontAscent(Gfx.FONT_MEDIUM)+2*dc.getFontAscent(Gfx.FONT_TINY)+17, battery, 10, 2);
             
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    	if( punkte!=null && punkte instanceof Array) {
    		App.Storage.setValue("punkte", punkte);  
    	}
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

}
