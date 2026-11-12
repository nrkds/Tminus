import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// T-Minus: up to 7 countdowns to dated events (race, vacation, birthday,
// flight, doctor appointment, custom), each with an end-of-countdown
// alarm setting. The app opens on the countdown list. Events can also be
// edited in the Garmin Connect / Express app settings.
class CountdownApp extends Application.AppBase {

    public function initialize() {
        AppBase.initialize();
    }

    public function onStart(state as Dictionary?) as Void {
    }

    public function onStop(state as Dictionary?) as Void {
    }

    public function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new LaunchView(), new LaunchDelegate()];
    }

    public function getGlanceView() as [WatchUi.GlanceView] or [WatchUi.GlanceView, WatchUi.GlanceViewDelegate] or Null {
        return [new CountdownGlance()];
    }

    public function onSettingsChanged() as Void {
        // Garmin Connect pushed new settings: the phone-side set replaces
        // the stored slots (see EventStore.importFromProperties).
        EventStore.importFromProperties();
        WatchUi.requestUpdate();
    }
}

// The app must not return a Menu2 from getInitialView (that fails app
// start), so this plain splash view pushes the countdown list as soon as
// it is shown, once per app session. BACK from the list lands here, and
// BACK again exits the app.
class LaunchView extends WatchUi.View {

    private var _pushed as Boolean = false;

    public function initialize() {
        View.initialize();
    }

    public function onShow() as Void {
        if (!_pushed) {
            _pushed = true;
            var menu = new CountdownMenu();
            WatchUi.pushView(menu, new CountdownMenuDelegate(menu), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_MEDIUM,
            "T-MINUS", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class LaunchDelegate extends WatchUi.BehaviorDelegate {
    public function initialize() {
        BehaviorDelegate.initialize();
    }
}
