import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Full view: native scrollable menu of all countdowns, soonest first, plus
// a "+ Add event" entry (on-watch creation) while slots remain.
// Sub-labels tick every second while the view is open.
class CountdownMenu extends WatchUi.Menu2 {

    private var _timer as Timer.Timer or Null = null;
    private var _events as Array<CountdownEvent> = [] as Array<CountdownEvent>;
    private var _itemCount as Number = 0;

    public function initialize() {
        Menu2.initialize({:title => "Countdowns"});
        rebuildItems();
    }

    public function events() as Array<CountdownEvent> {
        return _events;
    }

    public function rebuildItems() as Void {
        for (var i = _itemCount - 1; i >= 0; i--) {
            deleteItem(i);
        }
        _itemCount = 0;
        _events = EventStore.loadEvents();
        for (var i = 0; i < _events.size(); i++) {
            addItem(new WatchUi.MenuItem(
                _events[i].name,
                subLabelFor(_events[i]),
                _events[i].slotIndex,
                {}
            ));
            _itemCount++;
        }
        if (EventStore.storedCount() < EventStore.MAX_EVENTS) {
            addItem(new WatchUi.MenuItem("+ Add event", "On-watch entry", -1, {}));
            _itemCount++;
        }
    }

    private function subLabelFor(ev as CountdownEvent) as String {
        return EventStore.formatRemaining(ev.remainingSeconds()) + "  -  " + ev.whenLabel;
    }

    public function onShow() as Void {
        if (EventStore.consumeDirty()) {
            rebuildItems();
        }
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
        for (var i = 0; i < _events.size(); i++) {
            var item = getItem(i);
            if (item != null) {
                item.setSubLabel(subLabelFor(_events[i]));
            }
        }
        WatchUi.requestUpdate();
    }
}

class CountdownMenuDelegate extends WatchUi.MenuInputDelegate {

    private var _menu as CountdownMenu;

    public function initialize(menu as CountdownMenu) {
        MenuInputDelegate.initialize();
        _menu = menu;
    }

    // BACK from the list exits the app to the glance loop: pop the list
    // and the launch view beneath it (popping the last view exits).
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    // Navigating off either end of the menu: no wrap.
    public function onWrap(key as WatchUi.Key) as Boolean {
        return false;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        // START silences a sounding alarm before doing anything else.
        if (Alarm.isActive()) {
            Alarm.silence();
            return;
        }
        var id = item.getId() as Number;
        if (id == -1) {
            var session = EditSession.forNew();
            var menu = new AttributeListMenu(session);
            WatchUi.pushView(menu, new AttributeListDelegate(session), WatchUi.SLIDE_LEFT);
            return;
        }
        if (EventStore.eventAtSlot(id) != null) {
            WatchUi.pushView(
                new CountdownDetailView(id),
                new CountdownDetailDelegate(id),
                WatchUi.SLIDE_LEFT);
        }
    }
}
