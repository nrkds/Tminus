import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// Add / edit working copy + attribute list, per the on-device entry
// requirements: one attribute list (Name, Date, Time, Time zone, Event
// type, Alarm, and Delete for existing countdowns). Selecting a row opens
// that attribute's editor; BACK from an editor returns to the list; BACK
// from the list saves everything at once and lands on the detail view.
class EditSession {

    public var slotIndex as Number; // -1 = new countdown
    public var name as String;
    public var type as Number;
    public var year as Number;
    public var month as Number;
    public var day as Number;
    public var hour as Number;
    public var minute as Number;
    public var tz as Number;
    public var alarm as Number; // 0 = alarm & vibrate, 1 = vibrate only

    public function initialize(slot as Number, raw as Dictionary or Null) {
        slotIndex = slot;
        if (raw != null) {
            name = rawString(raw, "n");
            var t = raw.get("t");
            type = (t instanceof Number) ? t as Number : 5;
            var d = EventStore.parseFields(rawString(raw, "d"), "-");
            var nowInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            year = d.size() == 3 ? d[0] : (nowInfo.year as Number);
            month = d.size() == 3 ? d[1] : (nowInfo.month as Number);
            day = d.size() == 3 ? d[2] : (nowInfo.day as Number);
            var tm = EventStore.parseFields(rawString(raw, "h"), ":");
            hour = tm.size() >= 2 ? tm[0] : 9;
            minute = tm.size() >= 2 ? tm[1] : 0;
            var z = raw.get("z");
            tz = (z instanceof Number) ? z as Number : EventStore.TZ_WATCH;
            var a = raw.get("a");
            alarm = (a instanceof Number) ? a as Number : 0;
        } else {
            // New countdown defaults (per requirements): 7 days out,
            // 9:00 AM, watch time zone, type Event, alarm & vibrate,
            // name blank (falls back to the type name when saved).
            name = "";
            type = 5;
            var target = new Time.Moment(Time.now().value() + (7 * 86400));
            var info = Gregorian.info(target, Time.FORMAT_SHORT);
            year = info.year as Number;
            month = info.month as Number;
            day = info.day as Number;
            hour = 9;
            minute = 0;
            tz = EventStore.TZ_WATCH;
            alarm = 0;
        }
    }

    private function rawString(raw as Dictionary, key as String) as String {
        var v = raw.get(key);
        return (v instanceof String) ? v as String : "";
    }

    public static function forNew() as EditSession {
        return new EditSession(-1, null);
    }

    public static function forEvent(ev as CountdownEvent) as EditSession {
        return new EditSession(ev.slotIndex, ev.raw);
    }

    public function toRaw() as Dictionary {
        return {
            "n" => name,
            "t" => type,
            "d" => year.format("%04d") + "-" + month.format("%02d") + "-" + day.format("%02d"),
            "h" => hour.format("%02d") + ":" + minute.format("%02d"),
            "z" => tz,
            "a" => alarm
        } as Dictionary;
    }

    public function save() as Void {
        EventStore.saveSlot(slotIndex, toRaw());
    }

    public function displayName() as String {
        return name.length() > 0 ? name : EventStore.TYPE_NAMES[type];
    }

    public function dateLabel() as String {
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[month - 1] + " " + day.format("%d") + ", " + year.format("%d");
    }

    public function timeLabel() as String {
        return EventStore.formatClock(hour, minute);
    }

    public function tzLabel() as String {
        for (var i = 0; i < EventStore.TZ_OPTIONS.size(); i++) {
            if ((EventStore.TZ_OPTIONS[i][0] as Number) == tz) {
                return EventStore.TZ_OPTIONS[i][1] as String;
            }
        }
        return "Watch time zone";
    }

    public function alarmLabel() as String {
        return alarm == 0 ? "Alarm & vibrate" : "Vibrate only";
    }
}

class AttributeListMenu extends WatchUi.Menu2 {

    private var _session as EditSession;
    private var _itemCount as Number = 0;

    public function initialize(session as EditSession) {
        _session = session;
        Menu2.initialize({:title => session.slotIndex >= 0 ? session.displayName() : "New countdown"});
        rebuildItems();
    }

    public function onShow() as Void {
        rebuildItems();
        setTitle(_session.slotIndex >= 0 ? _session.displayName() : "New countdown");
    }

    public function rebuildItems() as Void {
        for (var i = _itemCount - 1; i >= 0; i--) {
            deleteItem(i);
        }
        _itemCount = 0;
        addRow("Name", _session.name.length() > 0 ? _session.name : "(tap to set)", "name");
        addRow("Date", _session.dateLabel(), "date");
        addRow("Time", _session.timeLabel(), "time");
        addRow("Time zone", _session.tzLabel(), "tz");
        addRow("Event type", EventStore.TYPE_NAMES[_session.type], "type");
        addRow("Alarm", _session.alarmLabel(), "alarm");
        if (_session.slotIndex >= 0) {
            addRow("Delete countdown", "Remove this countdown", "del");
        }
    }

    private function addRow(label as String, sub as String, id as String) as Void {
        addItem(new WatchUi.MenuItem(label, sub, id, {}));
        _itemCount++;
    }
}

class AttributeListDelegate extends WatchUi.MenuInputDelegate {

    private var _session as EditSession;

    public function initialize(session as EditSession) {
        MenuInputDelegate.initialize();
        _session = session;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        // START silences a sounding alarm before doing anything else.
        if (Alarm.isActive()) {
            Alarm.silence();
            return;
        }
        var id = item.getId() as String;
        if (id.equals("name")) {
            if (WatchUi has :TextPicker) {
                WatchUi.pushView(
                    new WatchUi.TextPicker(_session.name),
                    new SessionNameDelegate(_session),
                    WatchUi.SLIDE_LEFT);
            }
        } else if (id.equals("date")) {
            pushDatePicker();
        } else if (id.equals("time")) {
            pushTimePicker();
        } else if (id.equals("tz")) {
            var menu = new WatchUi.Menu2({:title => "Time zone"});
            for (var i = 0; i < EventStore.TZ_OPTIONS.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(EventStore.TZ_OPTIONS[i][1] as String, null, i, {}));
            }
            WatchUi.pushView(menu, new SessionMenuDelegate(_session, "tz"), WatchUi.SLIDE_LEFT);
        } else if (id.equals("type")) {
            var menu = new WatchUi.Menu2({:title => "Event type"});
            for (var i = 0; i < EventStore.TYPE_NAMES.size(); i++) {
                menu.addItem(new WatchUi.MenuItem(EventStore.TYPE_NAMES[i], null, i, {}));
            }
            WatchUi.pushView(menu, new SessionMenuDelegate(_session, "type"), WatchUi.SLIDE_LEFT);
        } else if (id.equals("alarm")) {
            var menu = new WatchUi.Menu2({:title => "Alarm"});
            menu.addItem(new WatchUi.MenuItem("Alarm & vibrate", null, 0, {}));
            menu.addItem(new WatchUi.MenuItem("Vibrate only", null, 1, {}));
            WatchUi.pushView(menu, new SessionMenuDelegate(_session, "alarm"), WatchUi.SLIDE_LEFT);
        } else if (id.equals("del")) {
            var ev = EventStore.eventAtSlot(_session.slotIndex);
            if (ev != null) {
                WatchUi.pushView(
                    new WatchUi.Confirmation("Delete \"" + ev.name + "\"?"),
                    new DeleteConfirmDelegate(ev, 2),
                    WatchUi.SLIDE_UP);
            }
        }
    }

    private function pushDatePicker() as Void {
        var curYear = (Gregorian.info(Time.now(), Time.FORMAT_SHORT).year) as Number;
        var monthFactory = new StringFactory(
            ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
            {:font => Graphics.FONT_SMALL});
        var dayFactory = new NumberFactory(1, 31, 1, {:format => "%02d", :font => Graphics.FONT_MEDIUM});
        var yearFactory = new NumberFactory(curYear, curYear + 10, 1, {:format => "%04d", :font => Graphics.FONT_MEDIUM});
        var title = new WatchUi.Text({
            :text => "Date", :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        var picker = new WatchUi.Picker({
            :title => title,
            :pattern => [monthFactory, dayFactory, yearFactory],
            :defaults => [_session.month - 1, dayFactory.getIndex(_session.day), yearFactory.getIndex(_session.year)]
        });
        WatchUi.pushView(picker, new SessionDateDelegate(_session, monthFactory), WatchUi.SLIDE_LEFT);
    }

    private function pushTimePicker() as Void {
        var hourFactory = new NumberFactory(0, 23, 1, {:format => "%02d", :font => Graphics.FONT_NUMBER_MEDIUM});
        var minFactory = new NumberFactory(0, 59, 1, {:format => "%02d", :font => Graphics.FONT_NUMBER_MEDIUM});
        var separator = new WatchUi.Text({
            :text => ":", :color => Graphics.COLOR_WHITE, :font => Graphics.FONT_NUMBER_MEDIUM,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
        var title = new WatchUi.Text({
            :text => "Time (24h)", :color => Graphics.COLOR_WHITE,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER, :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
        });
        var picker = new WatchUi.Picker({
            :title => title,
            :pattern => [hourFactory, separator, minFactory],
            :defaults => [hourFactory.getIndex(_session.hour), 0, minFactory.getIndex(_session.minute)]
        });
        WatchUi.pushView(picker, new SessionTimeDelegate(_session), WatchUi.SLIDE_LEFT);
    }

    // Navigating off either end of the menu: no wrap.
    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }

    // BACK from the attribute list: save everything and land on the
    // countdown's detail view (for an edit, the detail view is already
    // underneath; for a new countdown, push it).
    public function onBack() as Void {
        var wasNew = _session.slotIndex < 0;
        _session.save();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (wasNew) {
            var slot = EventStore.storedCount() - 1;
            if (slot >= 0 && EventStore.eventAtSlot(slot) != null) {
                WatchUi.pushView(
                    new CountdownDetailView(slot),
                    new CountdownDetailDelegate(slot),
                    WatchUi.SLIDE_LEFT);
            }
        }
    }
}

class SessionNameDelegate extends WatchUi.TextPickerDelegate {
    private var _session as EditSession;
    public function initialize(session as EditSession) {
        TextPickerDelegate.initialize();
        _session = session;
    }
    // The system dismisses the picker itself after these callbacks; the
    // attribute list underneath rebuilds its rows when it is shown again,
    // so nothing needs to be pushed or popped here.
    public function onTextEntered(text as String, changed as Boolean) as Boolean {
        _session.name = text;
        return true;
    }
    public function onCancel() as Boolean {
        return true;
    }
}

class SessionMenuDelegate extends WatchUi.MenuInputDelegate {
    private var _session as EditSession;
    private var _kind as String;
    public function initialize(session as EditSession, kind as String) {
        MenuInputDelegate.initialize();
        _session = session;
        _kind = kind;
    }
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Number;
        if (_kind.equals("tz")) {
            _session.tz = EventStore.TZ_OPTIONS[id][0] as Number;
        } else if (_kind.equals("type")) {
            _session.type = id;
        } else if (_kind.equals("alarm")) {
            _session.alarm = id;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }
}

class SessionDateDelegate extends WatchUi.PickerDelegate {
    private var _session as EditSession;
    private var _monthFactory as StringFactory;
    public function initialize(session as EditSession, monthFactory as StringFactory) {
        PickerDelegate.initialize();
        _session = session;
        _monthFactory = monthFactory;
    }
    public function onAccept(values as Array) as Boolean {
        _session.month = _monthFactory.getIndex(values[0] as String) + 1;
        _session.day = values[1] as Number;
        _session.year = values[2] as Number;
        var maxDay = EventStore.daysInMonth(_session.year, _session.month);
        if (_session.day > maxDay) {
            _session.day = maxDay;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

class SessionTimeDelegate extends WatchUi.PickerDelegate {
    private var _session as EditSession;
    public function initialize(session as EditSession) {
        PickerDelegate.initialize();
        _session = session;
    }
    public function onAccept(values as Array) as Boolean {
        _session.hour = values[0] as Number;
        _session.minute = values[2] as Number;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
