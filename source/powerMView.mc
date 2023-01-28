import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor;
using Toybox.UserProfile;
using Toybox.FitContributor as Fit;

class powerMView extends WatchUi.DataField {

    //getActivityInfo
    var actInfo = Activity.getActivityInfo();
    var userProfile = UserProfile.getProfile();

    hidden var sValue  as Numeric;                      // Speed
    hidden var mValue  as Numeric;                      // Distance
    hidden var wValue  as Numeric;                      // Watt
    hidden var aValue  as Numeric;                      // Ascent
    hidden var dValue  as Numeric;                      // Ambient Pressure
    hidden var hValue  as Numeric;                      // Heartrate
    hidden var avValue as Numeric;                      // Watt Average
    hidden var asValue as Numeric;                      // Average Speed
    hidden var kgValue as Numeric;                      // Watt / kg

    hidden var bikeEquipWeight  as Numeric;
    hidden var cdA              as Numeric;
    hidden var airDensity       as Numeric;
    hidden var rollingDrag      as Numeric;
    hidden var soil             as Numeric;

    var startWatt = false;                              // Set Watt value at the beginning to avoid empty data field
    var start = false;                                  // Set StartPresure once at the beginning
    var stopCount = false;                              // Stop Counting if speed is 0

    var count = 0;                                      // Time Counter
    var drop = 0;                                       // Höhenunterschied 
    var rise = 0;                                       // Aufstieg / Anstieg
    var speedMS = 0;                                    // Geschwindigkeit meter pro sekunde
    var weightOverall = 0;                              // Gewicht Fahrer + Bike + Equipment
    var riseDec = 0;                                    // Aufstieg / 100 
    var speedVertical = 0;                              // Vertikale Geschwindigkeit (Geschwindigkeit/Aufstieg)
    var weightRider = 0;                                // Gewicht Fahrer (value wird aus Garmin Profil geholt und überschrieben)
    var g = 9.81;                                       // Die Fallbeschleunigung hat auf der Erde den Wert g = 9,81 ms2

    var startPressure = 0;
    var totalPressureUp = 0;
    var paMeter = 0;
    var calcPressure = 0;

    var Pa = 0;
    var Pr = 0;
    var Pc = 0;
    var Pm = 0;
    var k = 0;

    var powerTotal = 0;
    var powerOverall = 0;
    var powerAverage = 0;
    var powerCount = 0;
    var newDistance = 0.00;

    var fitField1;
    var fitField2;
    var fitField3;

    function initialize(app) {
        DataField.initialize();
        
        sValue  = 0.00f;
        mValue  = 0.00f;
        wValue  = 0.00f;
        aValue  = 0.00f;
        dValue  = 0.00f;
        hValue  = 0.00f;
        avValue = 0.00f;
        asValue = 0.00f;
        kgValue = 0.00f;

        //weightRider = userProfile.weight / 1000;                            // Get Weight from User Profil on init
        weightRider = app.getProperty("riderWeight_prop").toFloat();
        bikeEquipWeight = app.getProperty("bike_Equip_Weight").toFloat();   // Gewicht Bike + Equipment
        cdA = app.getProperty("drag_prop").toNumber();                     // Luftreibungzahl Cw*A [m2], CdA = drag area -> Rollertrainer: 0.25, MTB: 0.525, Road: 0.28, 
        airDensity = app.getProperty("airDensity_prop").toFloat();          // Luftdichte: 1.205 -> API: 3.2.0 weather can be calculated .. not for edge 130 :(
        rollingDrag = app.getProperty("rollingDrag_prop").toNumber();       // Rollreibungszahl cr des Reifens / Rollentrainer: 0.004, Race: 0.006, Tour: 0.008, Enduro: 0.009
        soil = app.getProperty("soil_prop").toNumber();                     // Faktor für Untergrund Trainer, Asphalt, Schotterweg, Waldweg

        switch ( cdA ) {
            case 1: {
                cdA = 0.25;
                break;
            }
            case 2: {
                cdA = 0.28;
                break;
            }
            case 3: {
                cdA = 0.45;
                break;
            }
            case 4: {
                cdA = 0.525;
                break;
            }
            default: {
                cdA = 0.00;
                break;
            }
        }

        switch ( rollingDrag ) {
            case 1: {
                rollingDrag = 0.004;
                break;
            }
            case 2: {
                rollingDrag = 0.006;
                break;
            }
            case 3: {
                rollingDrag = 0.008;
                break;
            }
            case 4: {
                rollingDrag = 0.009;
                break;
            }
            default: {
                rollingDrag = 0.00;
                break;
            }
        }

        switch ( soil ) {
            case 1: {
                soil = 0.85;
                break;
            }
            case 2: {
                soil = 1;
                break;
            }
            case 3: {
                soil = 1.5;
                break;
            }
            case 4: {
                soil = 3.0;
                break;
            }
            default: {
                soil = 0.00;
                break;
            }
        }

        // Create the custom FIT data field we want to record.
        fitField1 = DataField.createField("watt_time", 0, Fit.DATA_TYPE_SINT16, {:mesgType=>Fit.MESG_TYPE_RECORD, :units=>"watt/time"});
        fitField1.setData(0); 

        fitField2 = DataField.createField("watt_kg", 1, Fit.DATA_TYPE_SINT16, {:mesgType=>Fit.MESG_TYPE_RECORD, :units=>"watt/kg"});
        fitField2.setData(0);

        fitField3 = DataField.createField("watt_average", 2, Fit.DATA_TYPE_SINT16, {:mesgType=>Fit.MESG_TYPE_RECORD, :units=>"watt/average"});
        fitField3.setData(0);  
       
        Sys.println("DEBUG: Properties ( riderWeight     ): " + weightRider);
        Sys.println("DEBUG: Properties ( bikeEquipWeight ): " + bikeEquipWeight);
        Sys.println("DEBUG: Properties ( cdA             ): " + cdA);
        Sys.println("DEBUG: Properties ( airDensity      ): " + airDensity);
        Sys.println("DEBUG: Properties ( rolling drag    ): " + rollingDrag);
        Sys.println("DEBUG: Properties ( soil            ): " + soil);
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void {
        var obscurityFlags = DataField.getObscurityFlags();
        View.setLayout(Rez.Layouts.MainLayout(dc));

        var lSpeedView = View.findDrawableById("labelSpeed");
        lSpeedView.locY = lSpeedView.locY - 120;
        lSpeedView.locX = lSpeedView.locX - 55;

        var speedView = View.findDrawableById("speed");
        speedView.locY = speedView.locY - 90;
        speedView.locX = speedView.locX - 55;

        var lDistanceView = View.findDrawableById("labelDistance");
        lDistanceView.locY = lDistanceView.locY - 120;
        lDistanceView.locX = lDistanceView.locX + 55;
            
        var distanceView = View.findDrawableById("distance");
        distanceView.locY = distanceView.locY - 90;
        distanceView.locX = distanceView.locX + 55;

        var lAscentView = View.findDrawableById("labelAscent");
        lAscentView.locY = lAscentView.locY - 50;
        lAscentView.locX = lAscentView.locX - 55;
            
        var ascentView = View.findDrawableById("ascent");
        ascentView.locY = ascentView.locY - 20;
        ascentView.locX = ascentView.locX - 55;

        var lAPressureView = View.findDrawableById("labelAPressure");
        lAPressureView.locY = lAPressureView.locY - 50;
        lAPressureView.locX = lAPressureView.locX + 55;
            
        var aPressureView = View.findDrawableById("aPressure");
        aPressureView.locY = aPressureView.locY - 20;
        aPressureView.locX = aPressureView.locX + 55;

        var lHrView = View.findDrawableById("labelBpm");
        lHrView.locY = lHrView.locY + 20;
        lHrView.locX = lHrView.locX + 55;

        var hrView = View.findDrawableById("bpm");
        hrView.locY = hrView.locY + 50;
        hrView.locX = hrView.locX + 55;

        var lWAView = View.findDrawableById("labelWAverage");
        lWAView.locY = lWAView.locY + 20;
        lWAView.locX = lWAView.locX - 55;

        var wAView = View.findDrawableById("wAverage");
        wAView.locY = wAView.locY + 50;
        wAView.locX = wAView.locX - 55;

        var lKgWattView = View.findDrawableById("lKgWatt");
        lKgWattView.locY = lKgWattView.locY + 90;
        lKgWattView.locX = lKgWattView.locX - 55;
            
        var kgView = View.findDrawableById("kgWatt");
        kgView.locY = kgView.locY + 120;
        kgView.locX = kgView.locX - 55;

        var lWattView = View.findDrawableById("labelWatt");
        lWattView.locY = lWattView.locY + 90;
        lWattView.locX = lWattView.locX + 55;
            
        var wattView = View.findDrawableById("watt");
        wattView.locY = wattView.locY + 120;
        wattView.locX = wattView.locX + 55;
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void {
        // See Activity.Info in the documentation for available information.

        // Speed in km/h
        if(info has :currentSpeed){
            if(info.currentSpeed != null){
                sValue = info.currentSpeed as Number * 3.6;     // from mps to kmh
            } else {
                sValue = 0.00f;
            }
        }

        // Average Speed in km/h
        if(info has :averageSpeed){
            if(info.averageSpeed != null){
                asValue = info.averageSpeed as Number * 3.6;     // from mps to kmh
            } else {
                asValue = 0.00f;
            }
        }

        // Heartrate in bpm
        if(info has :currentHeartRate){
            if(info.currentHeartRate != null){
                hValue = info.currentHeartRate as Number;     // bpm
            } else {
                hValue = 0.00f;
            }
        }

        // Distance
        if(info has :elapsedDistance){
            if(info.elapsedDistance != null){
                mValue = info.elapsedDistance as Number / 1000; // from m to km
            } else {
                mValue = 0.00f;
            }
        }

        // Ascent
        if(info has :totalAscent){
            if(info.totalAscent != null){
                aValue = info.totalAscent as Number; 
            } else {
                aValue = 0.00f;
            }
        }

        // Ambient Pressure / Change to Barometer
        if(info has :meanSeaLevelPressure){
            if(info.meanSeaLevelPressure != null){
                if (start == false) {
                    startPressure = info.meanSeaLevelPressure as Number; 
                    startPressure = startPressure.toFloat() * 0.01;             // convert pa to hpa
                    Sys.println("DEBUG: startPressure() :" + startPressure); 
                    start = true;
                } 

                dValue = info.meanSeaLevelPressure as Number; 

                var checkMValue = mValue.toDouble();
                var checkNewDistance = newDistance.toDouble();
                //Sys.println("DEBUG: onUpdate() check: " + checkMValue + " == " + checkNewDistance);
                if (checkMValue >= checkNewDistance) {
                    newDistance = newDistance + 0.01;
                    count = count + 1;

                    if (count == 1) {
                        dValue = dValue.toFloat() * 0.01;                             // convert pa to hpa
                        Sys.println("DEBUG: dValue(startPressure) :" + dValue + " >= " + startPressure);
                        if (dValue >= startPressure) {
                            calcPressure = dValue - startPressure;
                            paMeter = calcPressure * 8.4;                             // 1 hPa 8,2 m bzw. 100 m 12,2 hPa.                              
                            paMeter = (paMeter * 100);                           // this fomula makes the magic part
                            totalPressureUp += paMeter;      
                            startPressure = dValue;                                              
                            dValue = paMeter;
                            Sys.println("DEBUG: paMeter( up ) :" + paMeter);

                            // k = (h/a) * 100 
                            k = (paMeter/10) * 100;
                        } else {
                            startPressure = dValue;
                            Sys.println("DEBUG: paMeter(down) :" + paMeter);
                        } 

                        count = 0;
                    }  
                } 

            } else {
                dValue = 0.00f;
            }
        }

        // Watt
        if(info has :currentSpeed){
            if(info.currentSpeed != null){
                // Pa = Luftwiderstand
                // Pr = Rollwiderstand / Rollreibungszahl = 0,009
                // Pc = Steigungswiderstand
                // Pm = Mechanische Widerstand

                // Weight of Fahrer + Fahrrad + Ausrüstung(Trinken etc.)
                weightOverall = weightRider + bikeEquipWeight;

                // Pr = C1 * m * g * v  -> Pr = (C1 * Soil) * m * g * v
                Pr = rollingDrag * weightOverall * g * (sValue/3.6);

                // Pa = 0.5 * p * cdA * v * (v-vw)2
                Pa = 0.5 * airDensity * cdA * (sValue/3.6) * ((sValue/3.6) * (sValue/3.6));

                // Pc = (i/100) * m * g * v
                Pc = (k/109) * weightOverall * g * (sValue/3.6);

                // Pm = (Pr + Pa + Pc) * 0.025
                Pm = (Pr + Pa + Pc) * 0.025;

                // powerTotal = Pr + Pa + Pc + Pm   -> Pm not needed at Trainer * 1.0
                powerTotal = Pr + Pa + Pc + Pm;

                Sys.println("DEBUG: onUpdate() KM/H       : " + sValue);
                Sys.println("DEBUG: onUpdate() KM         : " + mValue);
                Sys.println("DEBUG: onUpdate() HÖHENMETER : " + aValue);
                Sys.println("DEBUG: onUpdate() PreassureUP: " + totalPressureUp);
                Sys.println("DEBUG: onUpdate() WATT       : " + powerTotal);
                wValue = powerTotal;

                if (sValue > 0) { 
                    // Watt Average
                    powerOverall = powerOverall + powerTotal;
                    powerCount = powerCount + 1;
                    powerAverage = powerOverall / powerCount;
                    avValue = powerAverage;
                    //Sys.println("DEBUG: onUpdate() powerAverage    : " + powerAverage);

                    // Watt / KG
                    kgValue = powerAverage / weightRider;
                    //Sys.println("DEBUG: onUpdate() kgValue         : " + kgValue);

                    // Add Values to FitContributor
                    fitField1.setData(wValue.toNumber()); 
                    fitField2.setData(kgValue.toNumber()); 
                    fitField3.setData(avValue.toNumber());
                }
            } else {
                wValue = 0.00f;
            }
        }
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc as Dc) as Void {
        // Set the background color
        (View.findDrawableById("Background") as Text).setColor(getBackgroundColor());

        // Set the foreground color and value
        var labelSpeed = View.findDrawableById("labelSpeed") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelSpeed.setColor(Graphics.COLOR_WHITE);
        } else {
            labelSpeed.setColor(Graphics.COLOR_BLACK);
        }
        labelSpeed.setText("km/h Ø");

        var speed = View.findDrawableById("speed") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            speed.setColor(Graphics.COLOR_WHITE);
        } else {
            speed.setColor(Graphics.COLOR_BLACK);
        }
        speed.setText(asValue.format("%.2f"));

        var labelDistance = View.findDrawableById("labelDistance") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelDistance.setColor(Graphics.COLOR_WHITE);
        } else {
            labelDistance.setColor(Graphics.COLOR_BLACK);
        }
        labelDistance.setText("km");

        var distance = View.findDrawableById("distance") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            distance.setColor(Graphics.COLOR_WHITE);
        } else {
            distance.setColor(Graphics.COLOR_BLACK);
        }
        distance.setText(mValue.format("%.2f"));

        var labelHr = View.findDrawableById("labelBpm") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelHr.setColor(Graphics.COLOR_WHITE);
        } else {
            labelHr.setColor(Graphics.COLOR_BLACK);
        }
        labelHr.setText("hrm");

        var hr = View.findDrawableById("bpm") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            hr.setColor(Graphics.COLOR_WHITE);
        } else {
            hr.setColor(Graphics.COLOR_BLACK);
        }
        hr.setText(hValue.format("%i"));

        var lWAverage = View.findDrawableById("labelWAverage") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            lWAverage.setColor(Graphics.COLOR_WHITE);
        } else {
            lWAverage.setColor(Graphics.COLOR_BLACK);
        }
        lWAverage.setText("watt/Ø");

        var wAverage = View.findDrawableById("wAverage") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            wAverage.setColor(Graphics.COLOR_WHITE);
        } else {
            wAverage.setColor(Graphics.COLOR_BLACK);
        }
        wAverage.setText(avValue.format("%i"));

        var labelAscent = View.findDrawableById("labelAscent") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelAscent.setColor(Graphics.COLOR_WHITE);
        } else {
            labelAscent.setColor(Graphics.COLOR_BLACK);
        }
        labelAscent.setText("hPa m");

        var ascent = View.findDrawableById("ascent") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            ascent.setColor(Graphics.COLOR_WHITE);
        } else {
            ascent.setColor(Graphics.COLOR_BLACK);
        }
        ascent.setText(paMeter.format("%.2f"));

        var labelAPressure = View.findDrawableById("labelAPressure") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelAPressure.setColor(Graphics.COLOR_WHITE);
        } else {
            labelAPressure.setColor(Graphics.COLOR_BLACK);
        }
        labelAPressure.setText("hPA/m");

        var aPressure = View.findDrawableById("aPressure") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            aPressure.setColor(Graphics.COLOR_WHITE);
        } else {
            aPressure.setColor(Graphics.COLOR_BLACK);
        }
        aPressure.setText(totalPressureUp.format("%.2f"));

        var lKgWatt = View.findDrawableById("lKgWatt") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            lKgWatt.setColor(Graphics.COLOR_WHITE);
        } else {
            lKgWatt.setColor(Graphics.COLOR_BLACK);
        }
        lKgWatt.setText("watt/kg");

        var kgWatt = View.findDrawableById("kgWatt") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            kgWatt.setColor(Graphics.COLOR_WHITE);
        } else {
            kgWatt.setColor(Graphics.COLOR_BLACK);
        }
        kgWatt.setText(kgValue.format("%.2f"));

        var labelWatt = View.findDrawableById("labelWatt") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelWatt.setColor(Graphics.COLOR_WHITE);
        } else {
            labelWatt.setColor(Graphics.COLOR_BLACK);
        }
        labelWatt.setText("watt");

        var watt = View.findDrawableById("watt") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            watt.setColor(Graphics.COLOR_WHITE);
        } else {
            watt.setColor(Graphics.COLOR_BLACK);
        }

        // Watt will be updated every 10m -> if to avoid empty data field
        if (startWatt == false) {
            watt.setText(wValue.format("%i"));
            startWatt = true;
        } 
        if (wValue.toFloat() > 0) {
            watt.setText(wValue.format("%i"));          
        }
        

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }

}
