import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor;

class powerMView extends WatchUi.DataField {

    //getActivityInfo
    var actInfo = Activity.getActivityInfo();

    hidden var sValue as Numeric;   // Speed
    hidden var mValue as Numeric;   // Distance
    hidden var wValue as Numeric;   // Watt
    hidden var aValue as Numeric;   // Ascent
    hidden var dValue as Numeric;   // Ambient Pressure
    hidden var hValue as Numeric;   // Heartrate

    var startWatt = false;
    var start = false;

    var count = 0;                  // Time Counter
    var drop = 0;                   // Höhenunterschied 
    var rise = 0;                   // Aufstieg / Anstieg
    var speedMS = 0;                // Geschwindigkeit meter pro sekunde
    var weightOverall = 0;          // Gewicht Fahrer + Bike + Equipment
    var riseDec = 0;                // Aufstieg / 100 
    var speedVertical = 0;          // Vertikale Geschwindigkeit (Geschwindigkeit/Aufstieg)

    var weightRider = 85;           // Gewicht Fahrer (daten aus Garmin Profil laden)
    var bikeEquipWeight = 15;       // Gewicht Bike + Equipment
    var drag = 0.28;                // Cw*a
    var airDensity = 1.20;          // Luftdichte
    var rollingDrag = 0.005;        // Rollreibungsgrad 0.005 Rennrad : MTB ??
    var g = 9.81;                   // Die Fallbeschleunigung hat auf der Erde den Wert g = 9,81 ms2

    var startPressure = 0;
    var paMeter = 0;
    var calcPressure = 0;

    var powerTotal = 0;
    var powerWind = 0;
    var powerResistance = 0;
    var powerRise = 0;

    var newDistance = 0.00;

    function initialize() {
        DataField.initialize();
        sValue = 0.00f;
        mValue = 0.00f;
        wValue = 0.00f;
        aValue = 0.00f;
        dValue = 0.00f;
        hValue = 0.00f;
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc as Dc) as Void {
        var obscurityFlags = DataField.getObscurityFlags();

        // Top left quadrant so we'll use the top left layout
        if (obscurityFlags == (OBSCURE_TOP | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.TopLeftLayout(dc));

        // Top right quadrant so we'll use the top right layout
        } else if (obscurityFlags == (OBSCURE_TOP | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.TopRightLayout(dc));

        // Bottom left quadrant so we'll use the bottom left layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_LEFT)) {
            View.setLayout(Rez.Layouts.BottomLeftLayout(dc));

        // Bottom right quadrant so we'll use the bottom right layout
        } else if (obscurityFlags == (OBSCURE_BOTTOM | OBSCURE_RIGHT)) {
            View.setLayout(Rez.Layouts.BottomRightLayout(dc));

        // Use the generic, centered layout
        } else {
            View.setLayout(Rez.Layouts.MainLayout(dc));

            var lSpeedView = View.findDrawableById("labelSpeed");
            lSpeedView.locY = lSpeedView.locY - 120;
            lSpeedView.locX = lSpeedView.locX - 60;

            var speedView = View.findDrawableById("speed");
            speedView.locY = speedView.locY - 90;
            speedView.locX = speedView.locX - 60;

            var lDistanceView = View.findDrawableById("labelDistance");
            lDistanceView.locY = lDistanceView.locY - 120;
            lDistanceView.locX = lDistanceView.locX + 60;
            
            var distanceView = View.findDrawableById("distance");
            distanceView.locY = distanceView.locY - 90;
            distanceView.locX = distanceView.locX + 60;

            var lAscentView = View.findDrawableById("labelAscent");
            lAscentView.locY = lAscentView.locY - 40;
            lAscentView.locX = lAscentView.locX - 60;
            
            var ascentView = View.findDrawableById("ascent");
            ascentView.locY = ascentView.locY - 10;
            ascentView.locX = ascentView.locX - 60;

            var lAPressureView = View.findDrawableById("labelAPressure");
            lAPressureView.locY = lAPressureView.locY - 40;
            lAPressureView.locX = lAPressureView.locX + 60;
            
            var aPressureView = View.findDrawableById("aPressure");
            aPressureView.locY = aPressureView.locY - 10;
            aPressureView.locX = aPressureView.locX + 60;

            var lHrView = View.findDrawableById("labelBpm");
            lHrView.locY = lHrView.locY + 30;
            lHrView.locX = lHrView.locX + 0;

            var hrView = View.findDrawableById("bpm");
            hrView.locY = hrView.locY + 60;
            hrView.locX = hrView.locX + 0;

            var lWattView = View.findDrawableById("labelWatt");
            lWattView.locY = lWattView.locY + 90;
            lWattView.locX = lWattView.locX + 0;
            
            var wattView = View.findDrawableById("watt");
            wattView.locY = wattView.locY + 120;
            wattView.locX = wattView.locX + 0;
        }
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().
    function compute(info as Activity.Info) as Void {
        // See Activity.Info in the documentation for available information.
        if(info has :currentSpeed){
            if(info.currentSpeed != null){
                sValue = info.currentSpeed as Number * 3.6;     // from mps to kmh
            } else {
                sValue = 0.00f;
            }
        }

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
        if(info has :ambientPressure){
            if(info.ambientPressure != null){
                if (start == false) {
                    startPressure = info.ambientPressure as Number; 
                    startPressure = startPressure.toFloat() * 0.010197162129779;    // convert PA to cm 
                    start = true;
                }   
                
                dValue = info.ambientPressure as Number;                            
                dValue = dValue.toFloat() * 0.010197162129779;                      // convert PA to cm 

                calcPressure = startPressure - dValue;
                paMeter = calcPressure * 10;                                        // value 0.10 = 1Meter

                startPressure = dValue;                                             // 
                dValue = paMeter;

            } else {
                dValue = 0.00f;
            }
        }

        // Watt
        if(info has :currentSpeed){
            if(info.currentSpeed != null){
                rise = paMeter / (Math.sqrt(10 * 10 - paMeter * paMeter)) * 100;
                speedMS = sValue / 3.6;                                             // Speed in m per sec
                weightOverall = weightRider + bikeEquipWeight;
                riseDec = rise / 100;
                speedVertical = riseDec * speedMS / ((1 + riseDec * riseDec) * (1 + riseDec * riseDec));

                powerWind = drag * 0.5 * airDensity * speedMS * speedMS * speedMS;
                powerResistance = weightOverall * g * rollingDrag * speedMS;
                powerRise = weightOverall * g * speedVertical;

                powerTotal = powerWind + powerResistance + powerRise;
                //Sys.println("DEBUG: onUpdate() KM/H    : " + sValue);
                //Sys.println("DEBUG: onUpdate() WATT    : " + powerTotal);
                //Sys.println("DEBUG: onUpdate() PRESSURE: " + paMeter);
                wValue = powerTotal;
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
        labelSpeed.setText("SPEED");

        var speed = View.findDrawableById("speed") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            speed.setColor(Graphics.COLOR_WHITE);
        } else {
            speed.setColor(Graphics.COLOR_BLACK);
        }
        speed.setText(sValue.format("%.2f"));

        var labelDistance = View.findDrawableById("labelDistance") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelDistance.setColor(Graphics.COLOR_WHITE);
        } else {
            labelDistance.setColor(Graphics.COLOR_BLACK);
        }
        labelDistance.setText("KM");

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
        labelHr.setText("HRM");

        var hr = View.findDrawableById("bpm") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            hr.setColor(Graphics.COLOR_WHITE);
        } else {
            hr.setColor(Graphics.COLOR_BLACK);
        }
        hr.setText(hValue.format("%i"));

        var labelAscent = View.findDrawableById("labelAscent") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelAscent.setColor(Graphics.COLOR_WHITE);
        } else {
            labelAscent.setColor(Graphics.COLOR_BLACK);
        }
        labelAscent.setText("UP");

        var ascent = View.findDrawableById("ascent") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            ascent.setColor(Graphics.COLOR_WHITE);
        } else {
            ascent.setColor(Graphics.COLOR_BLACK);
        }
        ascent.setText(aValue.format("%.2f"));

        var labelAPressure = View.findDrawableById("labelAPressure") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelAPressure.setColor(Graphics.COLOR_WHITE);
        } else {
            labelAPressure.setColor(Graphics.COLOR_BLACK);
        }
        labelAPressure.setText("PA/m");

        var aPressure = View.findDrawableById("aPressure") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            aPressure.setColor(Graphics.COLOR_WHITE);
        } else {
            aPressure.setColor(Graphics.COLOR_BLACK);
        }
        aPressure.setText(dValue.format("%.2f"));

        var labelWatt = View.findDrawableById("labelWatt") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            labelWatt.setColor(Graphics.COLOR_WHITE);
        } else {
            labelWatt.setColor(Graphics.COLOR_BLACK);
        }
        labelWatt.setText("WATT");

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

        var checkMValue = mValue.toDouble();
        var checkNewDistance = newDistance.toDouble();
        //Sys.println("DEBUG: onUpdate() check: " + checkMValue + " == " + checkNewDistance);

        if (checkMValue >= checkNewDistance) {
            newDistance = newDistance + 0.01;
            count = count + 1;

            if (count == 1) {
                if (wValue.toFloat() > 0) {
                    watt.setText(wValue.format("%i"));
                }
                count = 0;
            }  
        } else {
            //Sys.println("DEBUG: onUpdate() else");
        }

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }

}
