import Toybox.Application;

class DataManager {
    static function getDistance() {
        return Application.Properties.getValue("dis");
    }

    static function setDistance(dis) {
        Application.Properties.setValue("dis", dis);
    }
    
}
