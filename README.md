# T-Minus — Countdown Timer (Connect IQ widget)
First compile + simulator test on your Mac. SDK 9.3.

## What's in this zip
- `manifest.xml`, `monkey.jungle`, `source/`, `resources/` — the app
- `developer_key.der` — our signing key. Keep it in this folder, don't regenerate it.

## 1. Open in VS Code
1. Unzip, open the `TMinus` folder in VS Code (File → Open Folder).
2. Cmd+Shift+P → `Monkey C: Verify Installation` — fix anything it flags.
3. Cmd+Shift+P → `Monkey C: Editor Settings` is NOT needed; if VS Code asks
   for the developer key, point it at `developer_key.der` in this folder.

## 2. First build + simulator run (do this one first)
1. Cmd+Shift+P → `Monkey C: Build for Device` → pick **fenix7** → output folder `bin`.
   Expected: `bin/TMinus.prg` created, no errors.
2. Cmd+Shift+P → `Monkey C: Run App` → pick **fenix7**.
   The Connect IQ Simulator opens with the widget running.

Terminal alternative (same result):
```
cd TMinus
SDK=$(ls -d ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-*/ | tail -1)
"$SDK/bin/monkeyc" -d fenix7 -f monkey.jungle -o bin/TMinus.prg -y developer_key.der -w
"$SDK/bin/monkeydo" bin/TMinus.prg fenix7
```
(monkeydo needs the simulator already open: `"$SDK/bin/connectiq"`)

## 3. What to check in the simulator
- Glance view: next sample event, big countdown, "+2 more"
- Open the widget: list of 3 sample events (Flight +2d, Race +9d, Birthday +23d), ticking
- Select one: detail page, countdown + event date/time + time zone label
- Detail → Edit and "+ Add event": wizard runs (name → type → date → time → zone → review → save)
- Detail → Delete: confirmation, event disappears

## 4. Report back
- Build succeeded? Yes/no
- If it failed: paste the FULL error text (or screenshot) — exact wording matters
- Simulator: what the glance and list show (screenshot is best)

## Notes
- Phone app settings do NOT work on simulator/sideload builds like this one —
  use the simulator's App Settings Editor, or the on-watch wizard. Expected, not a bug.
- Targets in manifest: fenix7/7s/7x, fenix8 43/47, fr255/265/955/965/970.
  Build fenix7 only for this first pass.
