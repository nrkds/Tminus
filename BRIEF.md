# Garmin Widget — Project Brief

Started 2026-10-23 in the "Random coding projects" chat. Jolly = PM + developer + tester; store upload/approval management comes later, only when the user says go.

**Workflow update 2026-11-11 (Product chat):** No full Mac access. Jolly supplies code + build instructions; the user compiles and tests on his own Mac and reports back errors/results.

## Direction (user, 2026-10-23)
- Build a Connect IQ **widget with a glance** for Garmin watches.
- Initial targets: **Tactix, Fenix, Forerunner** families.
- **Prototype first in a test environment.** App submission / approval process is explicitly deferred.

## Concept — LOCKED 2026-10-23 (user)
**"T-Minus" (working name): up to 7 countdown timers to dated events.**
Each event: **name**, **type** (race / vacation / birthday / flight / doctor appointment / custom), **date**, **time**, and the **event's time zone**. The watch counts down from now to the event.

### Design decisions (PM, 2026-10-23)
- **Data entry via Garmin Connect / Express app settings** — the standard pattern for data-heavy CIQ apps; on-watch text entry is a poor experience. Schema: 7 slots × (name, type list, date "YYYY-MM-DD", time "HH:MM" 24h, time zone list) — built in `prototype/resources/settings.xml` + `properties.xml`.
- **Time zones:** list offers "Watch time zone" (default — offset resolved at the event's date from the device's own zone rules, so DST is handled) plus fixed UTC offsets with city labels (UTC−10 Hawaii … UTC+10 Sydney, incl. India +5:30). Fixed offsets don't auto-shift for DST — the user picks the offset in effect on the event date. Target epoch = entered wall time − offset, computed in `EventStore.mc`.
- **Glance:** next upcoming event only — type tag (RACE/TRIP/BDAY/FLY/DOC/MISC), name (trimmed to fit), big countdown, "+N more" when others exist.
- **Full view:** native Menu2 list, soonest first, sub-labels tick every second; select → detail page (big countdown, event date/time shown in the event's own zone, zone label). Past events read "Done".
- **Countdown format:** ≥2 days "12d 04h" · 1 day "1d 04h 12m" · <1 day "04:12:33" ticking.
- **Prototype seeding:** with no settings configured, 3 sample events (flight +2d, race +9d, birthday +23d, relative to first run) exercise glance/list/detail anywhere.
- **Known platform caveat:** app settings only function on store-installed builds — sideloaded .prg builds never surface settings. So the test path is: compile → simulator (settings editable via the sim's App Settings Editor) → **beta store upload titled "DO NOT APPROVE"** (installable by the developer account only, settings fully live) → on-watch test → public submission only on the user's word.
- On-watch event creation/editing: possible later (TextPicker + date pickers); out of scope for v1 unless the user asks.

### On-device creation — ADDED 2026-10-23 (user: "a must")
- **Storage model:** events live on-device in `Application.Storage` as raw slots (`n` name, `t` type, `d` date, `h` time, `z` tz). Garmin Connect settings remain a full-set editor: when Connect pushes settings, `onSettingsChanged` imports them over the stored slots (only if the phone set is non-empty). First run seeds the 3 samples *into storage*, so samples are editable/deletable like real events.
- **Wizard** (`source/EventWizard.mc`): from the list's "+ Add event" item (shown while < 7 slots) or Detail → Edit. Steps: Name (`WatchUi.TextPicker`, auto-skipped on devices without it) → Type (menu) → Date (Picker: month/day/year columns, day clamped to month length incl. leap years) → Time (Picker: HH : MM, 24h) → Time zone (menu, same list as settings) → Review screen (live countdown preview; Select = Save, Back = Cancel). Each step replaces itself on the view stack; Back anywhere exits without saving.
- **Delete:** Detail → Delete → `WatchUi.Confirmation`; pops back to the list, which rebuilds (dirty flag).
- Picker factories (`source/Factories.mc`) follow Garmin's SDK Picker sample patterns (`NumberFactory`, string factory); Menu2 rebuild uses `deleteItem`/`addItem`.

## Environment (this VM) — set up 2026-10-23
- ✅ OpenJDK 17 installed.
- ✅ Connect IQ **SDK 9.3.0** (released 2026-10-20, latest per Garmin's sdks.json) at `~/.Garmin/ConnectIQ/Sdks/` — downloaded directly from developer.garmin.com, no account needed.
- ✅ Developer signing key generated: `~/workspace/garmin-widget/developer_key.der` (+ .pem). Keep private; all store uploads must use this same key.
- ✅ SDK Manager also downloaded at `tools/sdkmanager/` (GUI; needs libsecret + a display — Xvfb is available).
- ⛔ **Device definitions are the one blocker.** Compiling for any device needs the per-device files in `~/.Garmin/ConnectIQ/Devices/`, which Garmin only serves to a **signed-in** SDK Manager session (device API returns HTTP 401 without auth; verified 2026-10-23). Compile attempt confirms: `ERROR: Invalid device id specified: 'fenix7'`.

### Unblock options (pick when ready — no store involvement either way)
1. **Mac route (easiest):** user installs SDK Manager on his Mac, signs in with his Garmin account, downloads the Fenix 7 / Tactix 7 / Forerunner device packs; Jolly copies the Devices folder into this VM.
2. ~~**VM route:** SDK Manager under Xvfb here~~ — **dead end, verified 2026-10-23:** the Linux SDK Manager binary links WebKitGTK 4.0 / libsoup 2.4, which Ubuntu 24.04 no longer ships (4.1 / soup3 only); don't retry. Jolly can still drive the Mac's GUI via computer control once the Mac is online — user only needs to type his Garmin password at the sign-in step.
3. Defer until the submission phase, when the developer account gets set up anyway.

## Prototype scaffold (`prototype/`)
- `manifest.xml` — app type `widget`, minApiLevel 3.2.0 (glance-capable), app id `b9f520ee-0edd-4f8b-a24c-a03822b3337b`. Products: fenix7/7s/7x, fenix8 43/47mm, fr255/265/955/965/970. Tactix product IDs (tactix7 / tactix7amold) to verify against the downloaded device list before adding.
- `source/ProtoApp.mc` — AppBase with `getGlanceView()` + `getInitialView()`.
- `source/ProtoGlance.mc` — GlanceView: "DAY GLANCE" + steps / battery line.
- `source/ProtoView.mc` — full view: date, steps vs goal, heart rate (ActivityMonitor history), battery; 1-minute refresh timer.
- `resources/` — AppName string + placeholder launcher icon.
- Build (once devices exist): `~/.Garmin/ConnectIQ/Sdks/bin/monkeyc -d fenix7 -f monkey.jungle -o bin/proto.prg -y ../developer_key.der -w`

## Test plan (after unblock)
1. Compile `.prg` per target family (one per product id).
2. Simulator pass (Connect IQ simulator — GUI; run on the Mac or under Xvfb here): glance renders, full view opens, no crashes on empty sensor data.
3. Sideload to a real watch over USB (`GARMIN/APPS` folder) for on-wrist testing — needs a physical Tactix/Fenix/Forerunner + cable.
4. Later (user-gated): store beta upload with "DO NOT APPROVE" in the title for settings/dashboard testing, then public submission + Garmin review (typically ~2 business days per dev reports).

## Notes
- Garmin developer account is free; registration is the user's (name/identity), Jolly can drive the browser flow with him. Required only for device downloads (SDK Manager sign-in) and store upload — not for compiling/sideloading.
- App settings (Garmin Connect / Express) only work for store-installed builds, not sideloads — relevant if the widget later needs user configuration.

## Addendum — on-device entry redesign (his written requirements, 2026-11-11 evening)
Replaces the linear wizard. App starts on the countdown LIST. List START on a countdown → detail view; START on detail → edit mode. Edit/Add share ONE attribute list: Name, Date, Time, Time zone, Event type, Alarm, Delete (edit only, last, with confirmation). Selecting a row opens that attribute's editor; BACK returns to the list; BACK from the list saves all changes at once — edits land back on the detail view, adds land on the new countdown's detail view; BACK from detail → list. New-countdown defaults: +7 days, 9:00 AM, watch TZ, type Event, alarm & vibrate, name blank → type name. New attribute: alarm type (0 = alarm & vibrate, 1 = vibrate only; stored as slot key "a", default 0). Alarm: open-only; fires 9 min before the end (his 8–10 window), incl. when the app opens already inside the window (±9 min); pattern = 3 beeps + 3-burst vibration (vibrate-only per attribute); START anywhere silences; silenced countdown doesn't re-fire that session. Implemented in v7 (LaunchView trampoline → CountdownMenu; EditSession.mc; Alarm.mc; wizard + home view removed).
