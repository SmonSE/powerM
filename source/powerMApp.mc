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
        //_powerMView.onStart(self, state);
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        //_powerMView.onStop(self, state);
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ _powerMView ];
    }
    //function getInitialView() as Array<Views or InputDelegates>? {
    //    return [ new powerMView() ] as Array<Views or InputDelegates>;
    //}

    // return value from user settings without checking
    //function getProp(prop) {
	//    return getProperty(prop);
    //}

    // update displayed field from user settings
    function onSettingsChanged() {
    	_powerMView.requestUpdate();
		_powerMView.onUpdate();
    }
}

function getApp() as powerMApp {
    return Application.getApp() as powerMApp;
}