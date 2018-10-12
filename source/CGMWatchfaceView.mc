//! TODO
//! Proof layout on vivoactive 3
//! 

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Time.Gregorian as Gregorian;
using Toybox.ActivityMonitor as Act;

var height, width;
var anzeigeSGV = "", anzeigeBasal = "", anzeigeIOB = "", verzoegerung;
var outdatedSGV = false;
var wert, anzeigeDelta, anzeigeFehler;
var heartAnzeige, stepsAnzeige, sgvAnzeige;
var plotSGV;
var noAAPS = 0;
var correction = false;

class CGMWatchfaceView extends Ui.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
    	//Sys.println("OnLayout");
        setLayout(Rez.Layouts.WatchFace(dc));
        height = dc.getHeight();
        width = dc.getWidth();
        var temp = App.Storage.getValue("punkteWatchface");
        if( temp!=null && temp instanceof Lang.Array) {
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
        //Sys.println("onUpdate");
        var timeFormat = "$1$:$2$";
        var clockTime = Sys.getClockTime();
        var now = Time.now();
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var datum = info.day + "." + info.month.format("%02d")+ "."; //  + info.year.toString().substring(2,4);
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
        var stepGoal = Act.getInfo().stepGoal;   
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

    	// CGM Daten verarbeiten
    	noAAPS = height / 6 - 20;
    	//punkte = null;
    	if( punkte != null && punkte instanceof Lang.Array) { 
    		//Sys.println("CGM Daten");
        	// Einheiten            
        	if( punkte[0]["units_hint"] != null ) {
            	if( punkte[0]["units_hint"].equals("mmol") ) {
            		masseinheit = 1;
            	} else {
                	masseinheit = 0;
               	}
            } 
    		if( masseinheit != null && masseinheit == 1 ) {  
              	anzeigeSGV =  punkte[0]["sgv"] ? (0.05556 * punkte[0]["sgv"]).format("%.1f").toString() : "--";
               	// Delta in mmol, in String umwandeln, bei positiven Werten + davor
           		if( punkte[0]["delta"] != null ) {
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
           		if( punkte[0]["delta"] != null ) {
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
			outdatedSGV = ( verzoegerung != null && verzoegerung > 11 ) ? true : false;
        	
        	// AAPS
        	//punkte[0]["aaps"] = "10.06U";
        	//punkte[0]["aaps"] = "240% 10.06U(8.27|8.34) -17,24 35g"; 
        	//punkte[0]["aaps"] = null;
        	if( punkte[0]["aaps"] != null ) {
        		//Sys.println("AAPS");
             	aaps = punkte[0]["aaps"].toString();   
             	if( aaps != null && aaps.equals("") == false ) {
        			var index1 = aaps.find(" ");
        			anzeigeBasal = index1 != null ? aaps.substring(0,index1) : "--%";
        			if( index1 ) {
        				var aapsPart = aaps.substring(index1,20);
        				var index2 = aapsPart.find("U");        			
                   		anzeigeIOB = index2 != null ? aapsPart.substring(1,index2-1) : "--";
                   	} else if( index1 == null && aaps.find("U") != null ) {
                   		// Nur IOB angezeigt
                   		var index3 = aaps.find("U");
                   		anzeigeIOB = aaps.substring(0,index3-1);
                   	} else {
                   		anzeigeIOB = "--";
                   	}
            		noAAPS = 0;
            	}
			} else {
					noAAPS = height / 6 - 20;
					anzeigeBasal = "";
					anzeigeIOB = "";
			}             	        	
            if( punkte[0]["aaps-ts"] != null) { // Meldung AAPS Status nicht aktuell
                var verzoegerungAAPS = minutesFromTimestamp(Time.now().value(), punkte[0]["aaps-ts"]); 
                if( verzoegerungAAPS != null && verzoegerungAAPS > 20 ) {  
                	anzeigeBasal = "--%";
					anzeigeIOB = "--";
				}
            }
            
			anzeigeFehler = "";
		} else {
			//Sys.println("Keine CGM Daten");
			anzeigeFehler = "Wait max. 5'";
			verzoegerung = "--";
			anzeigeSGV = "---";
			anzeigeDelta = "--";
		}
		
		// Fehleranzeige	
		//Sys.println("Fehler:" + fehler );
 		if( fehler != null && fehler == true ) { anzeigeFehler = "Error: " + fehler_code; } 

        // Update the view
        var time = View.findDrawableById("TimeLabel");
        time.setText(timeString);
        
        var date = View.findDrawableById("DateLabel");
        date.setText(datum);

        var verzAnzeige = View.findDrawableById("verzLabel");
        verzAnzeige.setText(verzoegerung.toString()+"'");
        if( noAAPS != null && noAAPS > 0 && correction == false ) {
        	verzAnzeige.setLocation(
        		verzAnzeige.locX, 
        	    verzAnzeige.locY + noAAPS 
        	);
        }
        
        sgvAnzeige = View.findDrawableById("sgvLabel");
        sgvAnzeige.setText(anzeigeSGV);
        if( noAAPS != null && noAAPS > 0 && correction == false ) {
        	sgvAnzeige.setLocation(
        		sgvAnzeige.locX, 
        	    sgvAnzeige.locY + noAAPS 
        	);
        }          
        
        var deltaAnzeige = View.findDrawableById("deltaLabel");
        deltaAnzeige.setText(anzeigeDelta);
        if( noAAPS != null && noAAPS > 0 && correction == false ) {
        	deltaAnzeige.setLocation(
        		deltaAnzeige.locX, 
        	    deltaAnzeige.locY + noAAPS 
        	);
        }
        
        if( noAAPS != null && noAAPS > 0 && correction == false ) {
        	correction = true;
        }
        
        if( anzeigeBasal != null && anzeigeBasal.equals("") == false ) {
        	var basalAnzeige = View.findDrawableById("basalLabel");
        	basalAnzeige.setText(anzeigeBasal);
        }
        
        if( anzeigeIOB != null && anzeigeIOB.equals("") == false ) {
        	var iobAnzeige = View.findDrawableById("iobLabel");
        	iobAnzeige.setText(anzeigeIOB);
        }
        
        if( steps != null ) {
            stepsAnzeige = View.findDrawableById("stepsLabel");
        	stepsAnzeige.setText(steps.toString());
        }
        
        if( heartrate != null ) {
            heartAnzeige = View.findDrawableById("heartrateLabel");
        	heartAnzeige.setText(heartrate.toString());
        	if( steps == null ) {
        		stepsAnzeige = View.findDrawableById("stepsLabel");
        		heartAnzeige.setLocation(
        			stepsAnzeige.locX, 
        			stepsAnzeige.locY
        		);
        	}       	
        }
        
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        //Sys.println("View.onUpdate");
        
		//! Ui without layout.xml        
        // Balken
        if( punkte != null && punkte instanceof Array  && punkte[0]["sgv"] != null && 70 < punkte[0]["sgv"] && punkte[0]["sgv"] < 180 ) {
        	dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT);
        } else {
        	dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        }
        dc.fillRectangle(
        	width*2/3-22, 
        	0, 
        	13, 
        	height
        );
        
        // Trennlinien
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(
        	0, 
        	height/3+10,
        	width*2/3-25, 
        	height/3+10
        );
        dc.drawLine(
        	0, 
        	height*2/3+10,
        	width*2/3-25,
        	height*2/3+10
        );
        
        // Zu alter Blutzucker
        //outdatedSGV = true;
        if( outdatedSGV != null && outdatedSGV == true && anzeigeSGV != null ) {
        	dc.fillRectangle(
        		sgvAnzeige.locX - 2, 
        		sgvAnzeige.locY + dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM) / 2 + noAAPS,  
        		dc.getTextWidthInPixels(anzeigeSGV, Gfx.FONT_NUMBER_MEDIUM)+4,
        		6
        	);
        }
        
        // Graph
        if( punkte != null && punkte instanceof Array ) {      
        	dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);
            var now = Time.now().value();
            var lowValue = 1000, highValue = 0;
            var factor = 0.0033; // Faktor: 1/300
            var correction = 0; 
            for( var i = 0; i < punkte.size(); i++ ) {
            	if( lowValue > punkte[i]["sgv"] ) { lowValue = punkte[i]["sgv"]; }
            	if( highValue < punkte[i]["sgv"] ) { highValue = punkte[i]["sgv"]; }
            }
            var difference = highValue - lowValue;
            if( difference != null && difference <= 90 ) {
            	factor = 0.01; // 1/100     	
   				correction = (100-difference)/2; 
            } else { 
            	factor = 1.toFloat()/(difference+10); // 1/200
            	correction = 5; 
            	Sys.println("Faktor: " + factor + "\n");
            	Sys.println("Differenz: " + difference + "\n");
            }
            
            for( var i = 0; i < punkte.size(); i++ ) {
            	if(punkte[i]["sgv"] != null && punkte[i]["date"] != null ) {
            		plotSGV = (punkte[i]["sgv"] - lowValue) + correction;
            	    // plotSGV = 300;
                	var plotBreite = width*2/3 - 27 - 3 - (minutesFromTimestamp(now, punkte[i]["date"]) * ( (width*2/3-27) * 0.0111) ); // Faktor 1 / 90 
                	var plotHoehe = height/3+10 - ( plotSGV * ((height/3)*factor) + 10); 
                	if( 70 <= punkte[i]["sgv"] && punkte[i]["sgv"] <= 180 ) {
                		dc.setColor(Gfx.COLOR_GREEN, Gfx.COLOR_TRANSPARENT); 
                	} else {
                		dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT); 
                	}
                	dc.fillCircle( 
                		plotBreite, 
                		height/3+10 + plotHoehe,
                		2
                	);
                }                           
            }
        }
        
        if( anzeigeFehler != null ) {
        	dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        	dc.drawText(
        		width*2/3-30, 
        		height*2/3+10-dc.getFontHeight(Gfx.FONT_SMALL)-5, 
        		Gfx.FONT_SMALL, 
        		anzeigeFehler,
        		Gfx.TEXT_JUSTIFY_RIGHT 
        	);
        }
        
        if( adjustTime != null && adjustTime == true) {
        	var bmp = Ui.loadResource(Rez.Drawables.stopwatch);
        	dc.drawBitmap(
        		width*2/3+3+dc.getTextWidthInPixels(verzoegerung.toString()+"'", Gfx.FONT_SMALL),
        		height/3+10-dc.getFontAscent(Gfx.FONT_SMALL)-7+noAAPS, 
        		bmp
        	);
        }
        
        if( steps != null) {
        	var bmp = Ui.loadResource(Rez.Drawables.steps);
        	dc.drawBitmap(
        		stepsAnzeige.locX + 5, //width*2/3-45,
        		stepsAnzeige.locY + 5, //height*2/3+10+8,
        		bmp
        	);
        }
        
        if( heartrate != null ) {
        	var bmp = Ui.loadResource(Rez.Drawables.heart);
        	if( steps != null ) {
        		dc.drawBitmap(
        			heartAnzeige.locX + 5, //width*2/3-45,
        			heartAnzeige.locY + 5, //height*2/3+10+8+dc.getFontAscent(Gfx.FONT_SMALL)+5,
        			bmp
        		);
        	} else {
        		stepsAnzeige = View.findDrawableById("stepsLabel");
        		dc.drawBitmap(
        			stepsAnzeige.locX + 5, //width*2/3-45,
        			stepsAnzeige.locY + 5, //height*2/3+10+8,,
        			bmp
        		);
        	}
        }
        
        // Batteriestand
        //Sys.println("Batteriestand");
        var symbolAnzeige = View.findDrawableById("symbols");
        var batteryLoad = Sys.getSystemStats().battery;
        if( batteryLoad < 20 ) {
        	dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
        } else {
        	dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
        }
        // Battery body
        dc.fillRoundedRectangle(
        	symbolAnzeige.locX, //158 // width*2/3-2,
        	symbolAnzeige.locY, // 27 //height/3+12-dc.getFontHeight(Gfx.FONT_SMALL)-dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM), 
        	14, 
        	22,
        	2
        );
        // Battery contact
        dc.fillRectangle(
        	symbolAnzeige.locX + 4, //width*2/3-2+4, 
        	symbolAnzeige.locY - 2, //height/3+12-dc.getFontHeight(Gfx.FONT_SMALL)-dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM)-2,
        	6,
        	2
        );
        // Battery state
        var battery = batteryLoad * 18 / 100;
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Füllung
        dc.fillRoundedRectangle(
        	symbolAnzeige.locX + 2, //width*2/3, 
        	symbolAnzeige.locY + 2, //height/3+14-dc.getFontHeight(Gfx.FONT_SMALL)-dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM),
        	10,
        	18-battery, 
        	2
        );
                
        //Bluetooth connected
        if( System.getDeviceSettings().phoneConnected ) {	
        	var bmp = Ui.loadResource(Rez.Drawables.bluetooth);
        	dc.drawBitmap(
        		symbolAnzeige.locX + 19, //width*2/3+17,
        		symbolAnzeige.locY - 2, //height/3+10-dc.getFontHeight(Gfx.FONT_SMALL)-dc.getFontHeight(Gfx.FONT_NUMBER_MEDIUM), 
        		bmp
        	);
        }
        
        // Schritte-Ziel
        if( steps != null && stepGoal != null ) {
			var polygonPosition = height - ( (steps * height) / stepGoal);
			if( polygonPosition > (height - 10) ) { polygonPosition = height - 10; }
			if( polygonPosition < -10 ) { polygonPosition = -10; }
        	dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK); // Füllung
        	var polygon = [
        		[width*2/3-16, polygonPosition], 
        		[width*2/3-15+8, polygonPosition+6], 
        		[width*2/3-15+8, polygonPosition+20], 
        		[width*2/3-16, polygonPosition+14],
        		[width*2/3-15-9, polygonPosition+20],
        		[width*2/3-15-9, polygonPosition+6]
        	];
        	dc.fillPolygon(polygon);
    	}            
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    	if( punkte!=null && punkte instanceof Array) {
    		App.Storage.setValue("punkteWatchface", punkte);  
    	}
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }    
        
    // Verzoegerung ermitteln
    function minutesFromTimestamp(now, timestamp) {
    	return( (now - timestamp/1000) / 60 );
    }

}
