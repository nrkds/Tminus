import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Individual countdown detail view. Reloads its event from storage on
// every draw, so edits saved from the attribute list show immediately.
// START opens edit mode (the attribute list); BACK returns to the
// countdown list. While the alarm is sounding, START silences it.
class CountdownDetailView extends WatchUi.View {

    private var _slot as Number;
    private var _timer as Timer.Timer or Null = null;

    public function initialize(slot as Number) {
        View.initialize();
        _slot = slot;
    }

    public function onShow() as Void {
        Alarm.check();
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), 1000, true);
    }

    public function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    public function onTick() as Void {
        Alarm.check();
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        View.onUpdate(dc);
        var w = dc.getWidth();
        var cx = w / 2;
        var gap = 4;
        var ev = EventStore.eventAtSlot(_slot);

        if (ev == null) {
            var msgH = dc.getFontHeight(Graphics.FONT_MEDIUM);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (dc.getHeight() - msgH) / 2, Graphics.FONT_MEDIUM, "Countdown deleted", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var tagH = dc.getFontHeight(Graphics.FONT_SMALL);
        var nameH = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var countH = dc.getFontHeight(Graphics.FONT_LARGE);
        var whenH = dc.getFontHeight(Graphics.FONT_SMALL);
        var tzH = dc.getFontHeight(Graphics.FONT_XTINY);
        var hintH = dc.getFontHeight(Graphics.FONT_XTINY);
        var alarming = Alarm.activeSlot() == _slot;

        var total = tagH + gap + nameH + gap + countH + gap + whenH + gap + tzH + gap + hintH;
        if (alarming) {
            total += hintH + gap;
        }
        var y = (dc.getHeight() - total) / 2;

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, EventStore.TYPE_TAGS[ev.type], Graphics.TEXT_JUSTIFY_CENTER);
        y += tagH + gap;

        var name = ev.name;
        while (name.length() > 0
                && dc.getTextWidthInPixels(name, Graphics.FONT_MEDIUM) > w - 16) {
            name = name.substring(0, name.length() - 1);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_MEDIUM, name, Graphics.TEXT_JUSTIFY_CENTER);
        y += nameH + gap;

        dc.drawText(cx, y, Graphics.FONT_LARGE,
            EventStore.formatRemaining(ev.remainingSeconds()), Graphics.TEXT_JUSTIFY_CENTER);
        y += countH + gap;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_SMALL, ev.whenLabel, Graphics.TEXT_JUSTIFY_CENTER);
        y += whenH + gap;
        dc.drawText(cx, y, Graphics.FONT_XTINY,
            ev.tzLabel + "  -  " + (ev.alarm == 0 ? "Alarm & vibrate" : "Vibrate only"),
            Graphics.TEXT_JUSTIFY_CENTER);
        y += tzH + gap;

        if (alarming) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_XTINY, "ALARM - START to silence", Graphics.TEXT_JUSTIFY_CENTER);
            y += hintH + gap;
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, Graphics.FONT_XTINY, "START: edit", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class CountdownDetailDelegate extends WatchUi.BehaviorDelegate {

    private var _slot as Number;

    public function initialize(slot as Number) {
        BehaviorDelegate.initialize();
        _slot = slot;
    }

    // START: silence a sounding alarm, otherwise open edit mode.
    public function onSelect() as Boolean {
        if (Alarm.isActive()) {
            Alarm.silence();
            return true;
        }
        var ev = EventStore.eventAtSlot(_slot);
        if (ev != null) {
            var session = EditSession.forEvent(ev);
            var menu = new AttributeListMenu(session);
            WatchUi.pushView(menu, new AttributeListDelegate(session), WatchUi.SLIDE_UP);
        }
        return true;
    }
}

// Delete confirmation from the attribute list. The system dismisses the
// Confirmation itself before onResponse runs (Garmin's
// ConfirmationDialog sample never pops there), so on YES we only pop the
// views underneath it: `pops` of them (attribute list + detail view).
class DeleteConfirmDelegate extends WatchUi.ConfirmationDelegate {

    private var _ev as CountdownEvent;
    private var _pops as Number;

    public function initialize(ev as CountdownEvent, pops as Number) {
        ConfirmationDelegate.initialize();
        _ev = ev;
        _pops = pops;
    }

    public function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            EventStore.deleteSlot(_ev.slotIndex);
            for (var i = 0; i < _pops; i++) {
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
        }
        return true;
    }
}
