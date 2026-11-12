import Toybox.Attention;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;

// End-of-countdown alarm (open-only design, per requirements): while the
// app is open, when a countdown enters its final 9 minutes (or is already
// inside that window, up to 9 minutes past the end, when the app opens),
// the alarm pattern runs: three beeps + a three-burst vibration for
// "alarm & vibrate", vibration only for "vibrate only". Pressing START
// anywhere in the app silences it; a silenced countdown does not re-fire
// during the same app session.
module Alarm {

    var LEAD_SECONDS as Number = 540; // 9 minutes before the end

    var _activeSlot as Number = -1;
    var _alarmType as Number = 0;
    var _silenced as Dictionary = {} as Dictionary;
    var _timer as Timer.Timer or Null = null;
    var _ticker as AlarmTicker or Null = null;
    var _step as Number = 0;

    public function isActive() as Boolean {
        return _activeSlot >= 0;
    }

    public function activeSlot() as Number {
        return _activeSlot;
    }

    // Called about once a second while the list or detail view is open.
    public function check() as Void {
        if (_activeSlot >= 0) {
            return;
        }
        var events = EventStore.loadEvents();
        var now = Time.now().value();
        for (var i = 0; i < events.size(); i++) {
            var ev = events[i];
            if (_silenced.hasKey(ev.slotIndex)) {
                continue;
            }
            var remaining = ev.target.value() - now;
            if (remaining <= LEAD_SECONDS && remaining >= -LEAD_SECONDS) {
                start(ev);
                return;
            }
        }
    }

    function start(ev as CountdownEvent) as Void {
        _activeSlot = ev.slotIndex;
        _alarmType = ev.alarm;
        _step = 0;
        if (Attention has :backlight) {
            Attention.backlight(true);
        }
        if (_ticker == null) {
            _ticker = new AlarmTicker();
        }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start((_ticker as AlarmTicker).method(:onTick), 450, true);
        onPatternTick();
    }

    // Pattern cycle: 6 steps x 450ms. Step 0 fires the three-burst
    // vibration; steps 0-2 fire one beep each ("beep-beep-beep").
    public function onPatternTick() as Void {
        if (_activeSlot < 0) {
            return;
        }
        if (_step == 0 && (Attention has :vibrate)) {
            var pattern = [
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 250),
                new Attention.VibeProfile(0, 150),
                new Attention.VibeProfile(100, 250)
            ] as Array<Attention.VibeProfile>;
            Attention.vibrate(pattern);
        }
        if (_step <= 2 && _alarmType == 0 && (Attention has :playTone)) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
        _step = (_step + 1) % 6;
    }

    public function silence() as Void {
        if (_activeSlot >= 0) {
            _silenced.put(_activeSlot, true);
        }
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
        _activeSlot = -1;
    }
}

class AlarmTicker {
    public function onTick() as Void {
        Alarm.onPatternTick();
    }
}
