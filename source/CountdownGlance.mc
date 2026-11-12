import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance: features the next upcoming countdown.
//   RACE  Marathon
//   9d 06h          (+2 more)
// NOTE: no (:glance) annotation anywhere in this app on purpose: once any
// code is annotated, the glance process links ONLY annotated code, and
// calls into the un-annotated EventStore die with Illegal Access.
class CountdownGlance extends WatchUi.GlanceView {

    public function initialize() {
        GlanceView.initialize();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        GlanceView.onUpdate(dc);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var events = EventStore.loadEvents();
        var next = EventStore.nextEvent(events);

        var lineH = dc.getFontHeight(Graphics.FONT_GLANCE);

        if (next == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(0, (h - lineH) / 2, Graphics.FONT_GLANCE, "No countdowns", Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        var tag = EventStore.TYPE_TAGS[next.type];
        var name = next.name;
        // Trim the name until it fits next to the tag.
        var tagW = dc.getTextWidthInPixels(tag + "  ", Graphics.FONT_GLANCE);
        while (name.length() > 0
                && tagW + dc.getTextWidthInPixels(name, Graphics.FONT_GLANCE) > w) {
            name = name.substring(0, name.length() - 1);
        }

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, 0, Graphics.FONT_GLANCE, tag, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(tagW, 0, Graphics.FONT_GLANCE, name, Graphics.TEXT_JUSTIFY_LEFT);

        // Countdown on the second line; "+N more" shares that line at the
        // right edge (bottom-corner placement clipped on the real watch).
        var remain = EventStore.formatRemaining(next.remainingSeconds());
        var y2 = lineH + 4;
        dc.drawText(0, y2, Graphics.FONT_GLANCE, remain, Graphics.TEXT_JUSTIFY_LEFT);

        if (events.size() > 1) {
            var more = "+" + (events.size() - 1).format("%d") + " more";
            var remainW = dc.getTextWidthInPixels(remain, Graphics.FONT_GLANCE);
            var moreW = dc.getTextWidthInPixels(more, Graphics.FONT_GLANCE);
            if (remainW + 12 + moreW <= w) {
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(w, y2, Graphics.FONT_GLANCE, more, Graphics.TEXT_JUSTIFY_RIGHT);
            }
        }
    }
}
