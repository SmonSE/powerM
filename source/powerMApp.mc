import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;


class powerMApp extends Application.AppBase {

    hidden var _powerMView;

    function initialize() {
        AppBase.initialize();
        _powerMView = new powerMView(self);
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ _powerMView ];
    }
}

function getApp() as powerMApp {
    return Application.getApp() as powerMApp;
}