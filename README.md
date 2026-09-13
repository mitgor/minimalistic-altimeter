# Mini Altimeter

A minimal altimeter for iPhone and Apple Watch. Barometric and GPS altitude side
by side, ground speed from GNSS, on one screen, with no network at any point.
Trips can be recorded and read back as statistics shaped to what you were doing.
Live altitude in the Dynamic Island and on the lock screen, home-screen widgets,
four looks, and twenty languages.

## Running it

Open `Barometer.xcodeproj`, set your signing team on the three targets — the
app, the widget extension and the watch app — and run the `Barometer` scheme.
Deployment targets are iOS 17 and watchOS 10.

The dashboard has `#Preview` blocks — calibrated, uncalibrated, and
no-barometer — so the design can be judged in the canvas without a device.

**The Simulator cannot exercise the barometer.** There is no pressure sensor to
emulate, so `CMAltimeter.isRelativeAltitudeAvailable()` is false there and the app
falls back to GPS altitude. The barometric path — the whole point of the app —
only runs on a real iPhone (6s or later). `simctl` fixes also carry no vertical
accuracy, so GPS altitude stays blank in the Simulator too; what you can verify
there is the layout, the speed path, and calibration.

To drive the speed readout in the Simulator:

```bash
xcrun simctl location booted start --speed=14 --distance=3 46.5197,6.6323 46.6000,6.7000
```

## How the altitude is worked out

`CMAltimeter` reports *station pressure* — the raw pressure wherever the phone
is. Turning that into an altitude needs a second number: the pressure at sea
level, the QNH. `Atmosphere` does the conversion both ways.

The app deliberately does **not** use `startAbsoluteAltitudeUpdates`. It is the
obvious API for this, but it requires a location fix, and Apple's own developer
forums carry long-standing reports of it stalling in an uncalibrated state and of
it silently collapsing to the GPS value. Computing from pressure ourselves keeps
the altimeter working indoors, in a canyon, and in airplane mode.

The cost is that the reference has to be set by hand. Three ways, in `Calibrate`:

- **Match GPS** — take the fix as truth and back-solve the QNH. Best default.
- **Known altitude** — a trailhead sign, a summit marker, a chart.
- **Sea-level pressure** — a published QNH from a nearby airfield.

The maths round-trips exactly: calibrate at 1200 m and it reads 1200 m. Against
the full ISA table the single-layer approximation is within 0.15 m below 3000 m,
about 4 m at 5000 m, and about 10 m at 8000 m — all far smaller than the error
from a stale reference, which runs about **8 m per hectopascal**. That is why the
source pill turns amber after six hours: not because the sensor drifted, but
because the weather did.

## Trips

**Start trip** on the dashboard turns on background location (the blue
indicator), keeps the barometer alive through it, and starts a Live Activity:
the current altitude in the Dynamic Island, and both altitudes with climb rate,
ascent, descent and speed on the lock screen. **End trip** stops all of it.
Outside a trip the sensors stop the moment the app leaves the screen, so the
battery cost is always something you chose.

Every trip is also recorded — one sample a second of barometric altitude, GPS
altitude, speed and pressure, and nothing else. Open the history icon for the
list; open a trip for its statistics. The **activity** decides which figures are
shown and which profile is drawn:

| Activity | Figures |
|---|---|
| Hiking | duration, moving time, distance, pace, ascent, descent, highest, lowest |
| Motorcycle | duration, moving time, distance, max and average speed, ascent, highest, lowest, plus a speed profile |
| Skydiving | exit altitude, deployment altitude, freefall time, max sink, landing altitude, total descent |
| Soaring | flight time, highest, height gained, thermals, max climb, max sink, distance, glide ratio |

The activity is **recognised from the track**. Each one has a physical tell no
other shares — freefall at 25 m/s, sustained climbs at flying speed, road speed
with little climb, walking pace — so the rules are short and can be argued with;
`Tools/classifier-check` holds four synthetic tracks they must name. On iOS 26
with Apple Intelligence, the on-device model is asked for a second opinion on
the same summary and overrides only when confident, and only until you pick the
activity yourself.

## Widgets and watch

Home-screen widgets show the last altitude, pressure, ascent and speed, and say
how long ago the reading was taken — WidgetKit cannot be live, so the widget is
honest about its age instead.

The watch app runs as a complete altimeter on watches with a barometer, using
the phone's calibration and units. On watches without one it mirrors the
phone's readings over Watch Connectivity and says "From iPhone".

## Looks

Four themes, chosen in Settings: **Glass** (true black, lit numerals),
**Phosphor** (a green terminal with a dot-matrix trace), **Paper** (ink on
white) and **LCD** (a grey-green segment display with a bar trace). A theme is
colour, typeface, trace renderer and cell chrome — never layout, so every number
stays where you learned to find it.

## Design

Researched against the current crop of instrument apps and Apple's own. What the
good ones agree on, and what this follows:

- **One focal point per metric, and as few metrics as possible.** Altitude and
  speed are the two heroes. Everything else is either a thin strip at the bottom
  or in a sheet.
- **True black** in the default look. Free on OLED, and it makes the readouts
  read as lit rather than printed.
- **Monospaced digits, always.** Proportional numerals shift sideways as they
  change, which makes an instrument look unsteady.
- **Left-aligned heroes.** A flush-left column scans in one downward movement,
  which is the whole job when you are glancing at this on a handlebar.
- **One accent colour**, spent only on what is live or wrong.
- **Never show a number you do not have.** No speed fix says "Waiting for a fix",
  not `0` — and not a dash either: at readout size a dash is a slab that reads as
  redacted. There is no climb rate without an altitude, no `±` without a reading,
  and no average before enough moving time has accrued to mean anything.

## Layout

```
                                    ▮▮▯  ⚙
ALTITUDE
● BARO              GPS
1256 m              1329 m
↓ 0.9 m/s   Δ 73 m             Calibrate
   ╭────────╮
╭──╯        ╰───╮                     ← 15-minute trace
────────────────────────────────────────
SPEED
50 km/h
MAX 70     AVG 48     NE
────────────────────────────────────────
871.2 hPa   ↑97 m   ↓7 m   4.86 km
```

**Both altitudes are always on screen**, side by side, whether or not the fix is
locked. The two sensors fail in different and uncorrelated ways — the barometer
drifts with the weather, the fix wanders indoors and under trees — so seeing them
together is what tells you whether to believe either one. Hiding the other behind
a toggle would throw that away.

The dot marks the **primary**: the column the trace, climb rate, and ascent
totals are computed from. Tap the other column to switch. Everything else about
the two is symmetric.

`Δ` is the gap between them. With a fresh calibration it sits within a few
metres; it turns amber past 30. It is worth more than either quoted `±`, because
it is measured rather than estimated — when only one source is reading, that
source's own error bar takes its place.

## Structure

`Shared/` is compiled into all three targets.

| | |
|---|---|
| `Shared/Core/Atmosphere.swift` | ISA conversions. Pure functions, no state. |
| `Shared/Core/SensorEngine.swift` | `CMAltimeter` + `CLLocationManager`. Publishes raw readings only. |
| `Shared/Core/AltitudeTrack.swift` | Rolling 15-minute window. Backs the trace, vertical speed, and ascent totals from one array so they cannot disagree. |
| `Shared/Core/Instrument.swift` | Folds sensors and preferences into the numbers shown. Owns the trip lifecycle and recording. |
| `Shared/Core/Trip.swift` | `Trip`, `TripSummary` (every derived figure) and the rule-based `ActivityClassifier`. |
| `Shared/Core/TripStore.swift` | One JSON file per trip in Application Support. |
| `Shared/Core/Snapshot.swift` | The readings flattened for the Live Activity, widgets and watch. |
| `Shared/Core/Settings.swift` | Preferences, mirrored to `UserDefaults`. |
| `Shared/Design/` | The four themes, type scale, and the readout components. |
| `Shared/Localizable.xcstrings` | Every UI string, in 21 languages. |
| `Barometer/Views/` | Dashboard, calibration, settings, trips. |
| `Barometer/Trip/` | Live Activity and widget publishing, the watch link, the on-device model hook. |
| `Widgets/` | Home-screen widget and the Live Activity. |
| `Watch/` | The watch app. |
| `Tools/MakeIcon.swift` | Draws the app icon. Run it to regenerate rather than editing the PNG. |
| `Tools/classifier-check/` | The activity classifier's contract. |

Vertical speed is fitted by least squares over the last 8 seconds rather than
differenced between two samples — a single noisy reading would otherwise swing
it wildly. Ascent and descent only accumulate past a 2 m threshold, or standing
still would book hundreds of metres. Distance integrates ground speed rather than
summing fixes, and ignores anything under 0.5 m/s, so GPS jitter while stationary
does not inflate the trip.

## Icon

The icon is drawn, not painted — `Tools/MakeIcon.swift` renders it with Core
Graphics, so it is regenerated rather than edited:

```bash
swiftc -O Tools/MakeIcon.swift -o /tmp/makeicon && /tmp/makeicon Barometer/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

It is an altimeter face in outline. Staying clear of looking like a clock came
down to three things: ten graduations rather than twelve, pointers that taper to
a point instead of rounded bars, and a length ratio between them far wider than
an hour and minute hand. The numerals and the warning hatching on a real
instrument are left out — they turn to mush at tile size.

## Languages

English plus German, French, Spanish, Italian, Japanese, Korean, Simplified and
Traditional Chinese, Brazilian Portuguese, Russian, Ukrainian, Polish, Dutch,
Swedish, Turkish, Arabic, Hindi, Indonesian, Thai and Vietnamese, following the
iPhone's language setting. Sensor names and unit symbols are left as they are.

## Privacy

No networking code, no analytics, no third-party dependencies. Location and
motion are read on-device. Recorded trips are stored on the phone only and hold
altitude, speed and pressure — never coordinates. See [PRIVACY.md](PRIVACY.md).

## Support

support@woodenshark.com
