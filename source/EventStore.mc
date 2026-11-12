import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

// One countdown event (computed from a raw slot).
class CountdownEvent {
    public var name as String;
    public var type as Number; // 0 race, 1 vacation, 2 birthday, 3 flight, 4 doctor, 5 custom
    public var target as Time.Moment;
    public var tzLabel as String;
    public var whenLabel as String;
    public var slotIndex as Number; // index into the stored slot array
    public var raw as Dictionary;   // the stored slot this was computed from
    public var alarm as Number;     // 0 = alarm & vibrate, 1 = vibrate only

    public function initialize(n as String, t as Number, tgt as Time.Moment, tz as String, wl as String, slot as Number, r as Dictionary, a as Number) {
        name = n;
        type = t;
        target = tgt;
        tzLabel = tz;
        whenLabel = wl;
        slotIndex = slot;
        raw = r;
        alarm = a;
    }

    public function remainingSeconds() as Number {
        return target.value() - Time.now().value();
    }
}

// Event data lives in on-device Storage as raw slots:
//   {"n"=>name, "t"=>type, "d"=>"YYYY-MM-DD", "h"=>"HH:MM", "z"=>tz}
// where tz is 9999 for "watch time zone" or a UTC offset in minutes.
// Garmin Connect settings edit the same fields through app properties;
// onSettingsChanged imports them over the stored slots (full-set replace).
module EventStore {

    public var TYPE_TAGS as Array<String> = ["RACE", "TRIP", "BDAY", "FLY", "DOC", "MISC"];
    public var TYPE_NAMES as Array<String> = ["Race", "Vacation", "Birthday", "Flight", "Doctor", "Event"];
    public var MAX_EVENTS as Number = 7;
    public var TZ_WATCH as Number = 9999;

    // [tz minutes, label] — mirrors the settings list.
    public var TZ_OPTIONS as Array<Array> = [
        [9999, "Watch time zone"],
        [-600, "Hawaii (UTC-10)"],
        [-540, "Alaska (UTC-9)"],
        [-480, "Pacific US (UTC-8)"],
        [-420, "Mountain US (UTC-7)"],
        [-360, "Central US (UTC-6)"],
        [-300, "Eastern US (UTC-5)"],
        [-240, "Atlantic (UTC-4)"],
        [0, "UTC / London (UTC+0)"],
        [60, "Central Europe (UTC+1)"],
        [120, "Eastern Europe (UTC+2)"],
        [330, "India (UTC+5:30)"],
        [480, "China (UTC+8)"],
        [540, "Japan (UTC+9)"],
        [600, "Sydney (UTC+10)"]
    ];

    var MONTHS as Array<String> = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var _slots as Array<Dictionary> or Null = null;
    var _events as Array<CountdownEvent> or Null = null;
    var _dirty as Boolean = true; // list view rebuild flag

    // ---- slot management -------------------------------------------------

    public function storedCount() as Number {
        return slots().size();
    }

    public function slots() as Array<Dictionary> {
        if (_slots == null) {
            _slots = loadSlots();
        }
        return _slots as Array<Dictionary>;
    }

    function loadSlots() as Array<Dictionary> {
        var stored = Application.Storage.getValue("slots");
        if (stored instanceof Array && (stored as Array).size() > 0) {
            return stored as Array<Dictionary>;
        }
        var imported = slotsFromProperties();
        if (imported.size() > 0) {
            Application.Storage.setValue("slots", imported);
            return imported;
        }
        var seeds = seedSlots();
        Application.Storage.setValue("slots", seeds);
        return seeds;
    }

    // Called when Garmin Connect pushes new settings: the phone-side set
    // replaces the stored set (only when the phone actually has events).
    public function importFromProperties() as Void {
        var imported = slotsFromProperties();
        if (imported.size() > 0) {
            _slots = imported;
            Application.Storage.setValue("slots", imported);
            _events = null;
            _dirty = true;
        }
    }

    public function saveSlot(slotIndex as Number, raw as Dictionary) as Void {
        var s = slots();
        if (slotIndex >= 0 && slotIndex < s.size()) {
            s[slotIndex] = raw;
        } else if (s.size() < MAX_EVENTS) {
            s.add(raw);
        }
        persist();
    }

    public function deleteSlot(slotIndex as Number) as Void {
        var s = slots();
        if (slotIndex >= 0 && slotIndex < s.size()) {
            s.remove(s[slotIndex]);
        }
        persist();
    }

    function persist() as Void {
        Application.Storage.setValue("slots", _slots);
        _events = null;
        _dirty = true;
    }

    public function consumeDirty() as Boolean {
        var d = _dirty;
        _dirty = false;
        return d;
    }

    // ---- computed events -------------------------------------------------

    public function loadEvents() as Array<CountdownEvent> {
        if (_events != null) {
            return _events as Array<CountdownEvent>;
        }
        var s = slots();
        var events = [] as Array<CountdownEvent>;
        for (var i = 0; i < s.size(); i++) {
            var ev = buildEvent(s[i], i);
            if (ev != null) {
                events.add(ev);
            }
        }
        sortByTarget(events);
        _events = events;
        return events;
    }

    public function nextEvent(events as Array<CountdownEvent>) as CountdownEvent or Null {
        for (var i = 0; i < events.size(); i++) {
            if (events[i].remainingSeconds() >= 0) {
                return events[i];
            }
        }
        return events.size() > 0 ? events[events.size() - 1] : null;
    }

    // Compute a CountdownEvent from a raw slot; null if the slot is invalid.
    public function buildEvent(raw as Dictionary, slotIndex as Number) as CountdownEvent or Null {
        var dateStr = raw.get("d");
        if (!(dateStr instanceof String) || (dateStr as String).length() == 0) {
            return null;
        }
        var d = parseFields(dateStr as String, "-");
        if (d.size() != 3) {
            return null;
        }
        var year = d[0];
        var month = d[1];
        var day = d[2];
        if (year < 2000 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) {
            return null;
        }

        var hour = 9;
        var minute = 0;
        var timeStr = raw.get("h");
        if (timeStr instanceof String && (timeStr as String).length() > 0) {
            var t = parseFields(timeStr as String, ":");
            if (t.size() >= 2 && t[0] >= 0 && t[0] <= 23 && t[1] >= 0 && t[1] <= 59) {
                hour = t[0];
                minute = t[1];
            }
        }

        var typeRaw = raw.get("t");
        var typeNum = (typeRaw instanceof Number) ? typeRaw as Number : 5;
        if (typeNum < 0 || typeNum > 5) {
            typeNum = 5;
        }

        var tzRaw = raw.get("z");
        var tzVal = (tzRaw instanceof Number) ? tzRaw as Number : TZ_WATCH;

        var naive = Gregorian.moment({
            :year => year, :month => month, :day => day,
            :hour => hour, :minute => minute, :second => 0
        });

        var offsetSec = 0;
        var tzLabel = "";
        if (tzVal == TZ_WATCH) {
            offsetSec = localOffsetSeconds(naive);
            var first = new Time.Moment(naive.value() - offsetSec);
            offsetSec = localOffsetSeconds(first);
            tzLabel = "Watch TZ";
        } else {
            offsetSec = tzVal * 60;
            tzLabel = formatOffset(tzVal);
        }
        var target = new Time.Moment(naive.value() - offsetSec);

        var shown = Gregorian.utcInfo(new Time.Moment(target.value() + offsetSec), Time.FORMAT_SHORT);
        var whenLabel = MONTHS[(shown.month as Number) - 1] + " " + shown.day + ", " + shown.year
            + " - " + formatClock(shown.hour, shown.min);

        var nameRaw = raw.get("n");
        var name = (nameRaw instanceof String && (nameRaw as String).length() > 0)
            ? nameRaw as String : TYPE_NAMES[typeNum];

        var alarmRaw = raw.get("a");
        var alarmNum = (alarmRaw instanceof Number) ? alarmRaw as Number : 0;
        if (alarmNum < 0 || alarmNum > 1) {
            alarmNum = 0;
        }

        return new CountdownEvent(name, typeNum, target, tzLabel, whenLabel, slotIndex, raw, alarmNum);
    }

    public function eventAtSlot(slotIndex as Number) as CountdownEvent or Null {
        var events = loadEvents();
        for (var i = 0; i < events.size(); i++) {
            if (events[i].slotIndex == slotIndex) {
                return events[i];
            }
        }
        return null;
    }

    // ---- properties import ------------------------------------------------

    function slotsFromProperties() as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        for (var slot = 1; slot <= MAX_EVENTS; slot++) {
            var dateStr = propString("date" + slot);
            if (dateStr == null || dateStr.length() == 0) {
                continue;
            }
            var name = propString("name" + slot);
            var typeNum = propNumber("type" + slot);
            var timeStr = propString("time" + slot);
            var tzVal = propNumber("tz" + slot);
            out.add({
                "n" => (name != null) ? name : "",
                "t" => (typeNum != null) ? typeNum : 5,
                "d" => dateStr,
                "h" => (timeStr != null) ? timeStr : "09:00",
                "z" => (tzVal != null) ? tzVal : TZ_WATCH,
                "a" => 0
            } as Dictionary);
        }
        return out;
    }

    function propString(key as String) as String or Null {
        try {
            var v = Application.Properties.getValue(key);
            return (v instanceof String) ? v as String : null;
        } catch (e) {
            return null;
        }
    }

    function propNumber(key as String) as Number or Null {
        try {
            var v = Application.Properties.getValue(key);
            return (v instanceof Number) ? v as Number : null;
        } catch (e) {
            return null;
        }
    }

    // ---- seeds --------------------------------------------------------------

    function seedSlots() as Array<Dictionary> {
        var now = Time.now().value();
        var out = [] as Array<Dictionary>;
        out.add(seedSlot("Flight to Denver", 3, now + (2 * 86400) + (3 * 3600) + (20 * 60)));
        out.add(seedSlot("Marathon", 0, now + (9 * 86400) + (6 * 3600)));
        out.add(seedSlot("Mom's Birthday", 2, now + (23 * 86400) + (11 * 3600)));
        return out;
    }

    function seedSlot(name as String, typeNum as Number, epoch as Number) as Dictionary {
        var li = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        var dateStr = (li.year as Number).format("%04d") + "-" + (li.month as Number).format("%02d") + "-" + (li.day as Number).format("%02d");
        var timeStr = (li.hour as Number).format("%02d") + ":" + (li.min as Number).format("%02d");
        return {"n" => name, "t" => typeNum, "d" => dateStr, "h" => timeStr, "z" => TZ_WATCH} as Dictionary;
    }

    // ---- helpers -------------------------------------------------------------

    // Seconds the watch's local zone is ahead of UTC at the given moment.
    function localOffsetSeconds(m as Time.Moment) as Number {
        var li = Gregorian.info(m, Time.FORMAT_SHORT);
        var asUtc = Gregorian.moment({
            :year => li.year, :month => li.month, :day => li.day,
            :hour => li.hour, :minute => li.min, :second => li.sec
        });
        return asUtc.value() - m.value();
    }

    public function formatOffset(minutes as Number) as String {
        var sign = minutes < 0 ? "-" : "+";
        var abs = minutes < 0 ? -minutes : minutes;
        var h = abs / 60;
        var m = abs % 60;
        if (m == 0) {
            return "UTC" + sign + h.format("%d");
        }
        return "UTC" + sign + h.format("%d") + ":" + m.format("%02d");
    }

    public function formatClock(hour as Number, min as Number) as String {
        var suffix = hour >= 12 ? "PM" : "AM";
        var h12 = hour % 12;
        if (h12 == 0) {
            h12 = 12;
        }
        return h12.format("%d") + ":" + min.format("%02d") + " " + suffix;
    }

    public function parseFields(s as String, delim as String) as Array<Number> {
        // String.split needs API 6.0.3 and fenix7 is below that (runtime
        // Symbol Not Found), so scan manually with find/substring (API 1.0).
        var out = [] as Array<Number>;
        var rest = s;
        while (true) {
            var idx = rest.find(delim);
            if (idx == null) {
                var last = rest.toNumber();
                out.add(last != null ? last : -1);
                break;
            }
            var part = rest.substring(0, idx);
            var n = (part != null) ? part.toNumber() : null;
            out.add(n != null ? n : -1);
            var next = rest.substring(idx + delim.length(), null);
            if (next == null || (next as String).length() == 0) {
                break;
            }
            rest = next as String;
        }
        return out;
    }

    function sortByTarget(events as Array<CountdownEvent>) as Void {
        for (var i = 1; i < events.size(); i++) {
            var j = i;
            while (j > 0 && events[j - 1].target.value() > events[j].target.value()) {
                var tmp = events[j - 1];
                events[j - 1] = events[j];
                events[j] = tmp;
                j--;
            }
        }
    }

    //   >= 2 days:  "12d 04h"
    //   1 day:      "1d 04h 12m"
    //   < 1 day:    "04:12:33"
    //   passed:     "Done"
    public function formatRemaining(secs as Number) as String {
        if (secs < 0) {
            return "Done";
        }
        var d = secs / 86400;
        var h = (secs % 86400) / 3600;
        var m = (secs % 3600) / 60;
        var s = secs % 60;
        if (d >= 2) {
            return d.format("%d") + "d " + h.format("%02d") + "h";
        }
        if (d == 1) {
            return "1d " + h.format("%02d") + "h " + m.format("%02d") + "m";
        }
        return h.format("%02d") + ":" + m.format("%02d") + ":" + s.format("%02d");
    }

    public function daysInMonth(year as Number, month as Number) as Number {
        var days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
            return 29;
        }
        return days[month - 1];
    }
}
