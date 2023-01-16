import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

using Toybox.System as Sys;
using Toybox.Application as App;
using Toybox.ActivityMonitor;

class powerMView extends WatchUi.DataField {

    hidden var sValue as Numeric;   // Speed
    hidden var mValue as Numeric;   // Distance
    hidden var wValue as Numeric;   // Watt
    hidden var aValue as Numeric;   // Ascent
    hidden var dValue as Numeric;   // Descent

    var count = 0;                  // Time Counter
    var drop = 0;                   // Höhenunterschied 
    var rise = 0;                   // Aufstieg / Anstieg
    var speedMS = 0;                // Geschwindigkeit meter pro sekunde
    var weightOverall = 0;          // Gewicht Fahrer + Bike + Equipment
    var riseDec = 0;                // Aufstieg / 100 
    var speedVertical = 0;          // 

    var weightRider = 85;
    var bikeEquipWeight = 15;
    var drag = 0.28;                // Cw*a
    var airDensity = 1.20;          // Luftdichte
    var rollingDrag = 0.005;        // Rollreibungsgrad 0.005 Rennrad : MTB ??
    var g = 9.81;                   // Die Fallbeschleunigung hat auf der Erde den Wert g = 9,81 ms2

    var powerTotal = 0;
    var powerAir = 0;
    var powerRoll = 0;
    var powerRise = 0;

    var newDistance = 0.00;
    var newAscent = 0;
    var calcAscent = 0;

    var nowAscent = false;
    var getAscentNow = 0;

    var down;
    var up;

    //getActivityInfo
    var actInfo = Activity.getActivityInfo();
    var speedRounded;
    var distanceRounded;
    var currentWatt;
    var ascent;
    var descent;

    function initialize() {
        DataField.initialize();
        sValue = 0.00f;
        mValue = 0.00f;
        wValue = 0.00f;
        aValue = 0.00f;
        dValue = 0.00f;
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
            
            var valueView = View.findDrawableById("speed");
            valueView.locY = valueView.locY - 60;
            
            var distanceView = View.findDrawableById("distance");
            distanceView.locY = distanceView.locY -30;
            
            var ascentView = View.findDrawableById("ascent");
            ascentView.locY = ascentView.locY + 0;
            
            var descentView = View.findDrawableById("descent");
            descentView.locY = descentView.locY + 30;
            
            var wattView = View.findDrawableById("watt");
            wattView.locY = wattView.locY + 60;
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

        // Descent
        if(info has :totalDescent){
            if(info.totalDescent != null){
                dValue = info.totalDescent as Number; 
            } else {
                dValue = 0.00f;
            }
        }

        // Watt
        if(info has :currentSpeed){
            if(info.currentSpeed != null){

                    //rise = drop / (Math.sqrt(distance * distance - drop * drop)) * 100;
                    rise = calcAscent / (Math.sqrt(100 * 100 - calcAscent * calcAscent)) * 100;
                    speedMS = sValue / 3.6;   // Speed in m per sec
                    weightOverall = weightRider + bikeEquipWeight;
                    riseDec = rise / 100;
                    speedVertical = riseDec * speedMS / ((1 + riseDec * riseDec) * (1 + riseDec * riseDec));

                    powerAir = drag * 0.5 * airDensity * speedMS * speedMS * speedMS;
                    powerRoll = weightOverall * g * rollingDrag * speedMS;
                    powerRise = weightOverall * g * speedVertical;

                    powerTotal = powerAir + powerRoll + powerRise;
                    //Sys.println("DEBUG: onUpdate() powerTotal: " + powerTotal);
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
        var value = View.findDrawableById("speed") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            value.setColor(Graphics.COLOR_WHITE);
        } else {
            value.setColor(Graphics.COLOR_BLACK);
        }
        value.setText(sValue.format("%.2f") + " km/h");

        var distance = View.findDrawableById("distance") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            distance.setColor(Graphics.COLOR_WHITE);
        } else {
            distance.setColor(Graphics.COLOR_BLACK);
        }
        distance.setText(mValue.format("%.2f") + " km");

        var ascent = View.findDrawableById("ascent") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            ascent.setColor(Graphics.COLOR_WHITE);
        } else {
            ascent.setColor(Graphics.COLOR_BLACK);
        }
        ascent.setText(aValue.format("%.2f") + " m");

        var descent = View.findDrawableById("descent") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            descent.setColor(Graphics.COLOR_WHITE);
        } else {
            descent.setColor(Graphics.COLOR_BLACK);
        }
        descent.setText(dValue.format("%.2f") + " m");

        var watt = View.findDrawableById("watt") as Text;
        if (getBackgroundColor() == Graphics.COLOR_BLACK) {
            watt.setColor(Graphics.COLOR_WHITE);
        } else {
            watt.setColor(Graphics.COLOR_BLACK);
        }
        watt.setText(wValue.format("%.2f") + " watt");

        speedRounded = sValue.toNumber();
        distanceRounded = mValue.toNumber();
        currentWatt = wValue.toNumber();
        ascent = aValue.toNumber();
        descent = dValue.toNumber();

        var checkMValue = mValue.toDouble();
        var checkNewDistance = newDistance.toDouble();

        Sys.println("DEBUG: onUpdate() check: " + checkMValue + " == " + checkNewDistance);

        if (checkMValue >= checkNewDistance) {
            if (nowAscent == false) {
                getAscentNow = aValue.toDouble();
                //Sys.println("DEBUG: onUpdate() getAscentNow: " + getAscentNow);
                nowAscent = true;
            }
            newDistance = newDistance + 0.01;
            //Sys.println("DEBUG: onUpdate() newDistance2: " + newDistance);
            count = count + 1;
            Sys.println("DEBUG: onUpdate() count: " + count);
            if (count == 10) {
                if(actInfo has :totalAscent){
                    if(aValue != null){
                        var currentAscent = aValue.toDouble();
                        calcAscent = currentAscent - getAscentNow; 
                        Sys.println("DEBUG: onUpdate() calcAscent: " + calcAscent);
                        nowAscent = false;
                    } else {
                        calcAscent = 0.00f;
                        //Sys.println("DEBUG: onUpdate() calcAscent: " + calcAscent);
                    }
                    count = 0;
                }
            }
        } else {
            //Sys.println("DEBUG: onUpdate() else");
        }


        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);

        // ----------------------------------------------------------- //
    }

}

