# Working on Mini Altimeter

A barometric altimeter and GPS speedometer for iPhone, with a Live Activity,
home-screen widgets and a watch app. One screen, no network, no account. This file is what a fresh Claude session needs to be useful here
without rediscovering it all.

## Build and run

Xcode 26+, iOS 17 / watchOS 10 deployment targets, no package dependencies.
Three targets: `Barometer` (iPhone app), `AltimeterWidgets` (widget extension
with the Live Activity) and `Mini Altimeter Watch`. Building the app scheme
builds and embeds the other two.

```bash
# Build for the simulator
xcodebuild -project Barometer.xcodeproj -scheme Barometer -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build CODE_SIGNING_ALLOWED=NO
```

Fast type-check without a full build — much quicker when iterating:

```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -swift-version 6 -D DEBUG $(find Barometer Shared -name '*.swift')

# Widgets need the extension flag; the watch needs its own SDK
xcrun swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
  -swift-version 6 -D DEBUG -application-extension $(find Widgets Shared -name '*.swift')
WSDK=$(xcrun --sdk watchsimulator --show-sdk-path)
xcrun swiftc -typecheck -sdk "$WSDK" -target arm64-apple-watchos10.0-simulator \
  -swift-version 6 -D DEBUG $(find Watch Shared -name '*.swift')
```

The project is kept clean under **Swift 6 strict concurrency** as well as Swift 5.
Check both before claiming a change is done; the project itself compiles in
Swift 5 mode, so Swift 6 problems do not surface unless you ask for them.

## The one thing that will mislead you

**The Simulator has no barometer.** `CMAltimeter.isRelativeAltitudeAvailable()`
is false there, so the BARO column reads "No sensor" and altitude falls back to
GPS. Worse, `xcrun simctl location` delivers fixes with no vertical accuracy, so
`gpsAltitude` stays nil too — **both altitude columns are empty in the Simulator**
and there is nothing wrong with the app.

To see the dashboard populated (for design work or App Store screenshots),
temporarily point the app at the preview factory:

```swift
// BarometerApp.swift — TEMPORARY, revert before committing
@State private var instrument = Instrument.preview(
    sensors: .preview(pressure: 871.6, gpsAltitude: 1254.0, speed: 3.6, course: 47)
)
```

To screenshot a particular theme without touching Settings, pass it as a launch
argument — `UserDefaults` reads it ahead of the stored value:

```bash
xcrun simctl launch booted com.woodenshark.barometer -theme lcd
```

Speed *can* be exercised for real:

```bash
xcrun simctl location booted start --speed=14 --distance=3 46.5197,6.6323 46.6000,6.7000
```

## Architecture

`Shared/` is compiled into all three targets; everything in it must build for
iOS, an app extension (no `UIApplication.shared`) and watchOS.

| File | Holds |
|---|---|
| `Shared/Core/Atmosphere.swift` | ISA pressure↔altitude maths. Pure functions, no state. |
| `Shared/Core/SensorEngine.swift` | `CMAltimeter` + `CLLocationManager`. Publishes raw readings only, no interpretation. Background updates are a switch, only on during a trip. |
| `Shared/Core/AltitudeTrack.swift` | Rolling 15-min window. Backs the trace, vertical speed and ascent totals from one array so they cannot disagree. |
| `Shared/Core/Instrument.swift` | Folds sensors + settings into the numbers actually shown. The view model. Owns the trip lifecycle. |
| `Shared/Core/Settings.swift` | Preferences, mirrored to `UserDefaults`. |
| `Shared/Core/Snapshot.swift` | The readings flattened for the island, widgets and watch. Saved to the App Group. |
| `Shared/Core/TripAttributes.swift` | The Live Activity's attributes; its state is a `Snapshot`. |
| `Shared/Design/Theme.swift` | The four themes (Glass, Phosphor, Paper, LCD) as `Theme` values in the environment. A theme is colours, typeface, trace renderer and cell chrome — never layout. |
| `Shared/Design/Components.swift` | Readout, trace, cells. All read `@Environment(\\.theme)`. |
| `Barometer/Views/` | Dashboard, calibration sheet, settings sheet. |
| `Barometer/Trip/TripBroadcaster.swift` | Every 3 s: writes the snapshot, updates the Live Activity, nudges WidgetKit, sends to the watch. |
| `Barometer/Trip/PhoneLink.swift` | `WCSession` sender. Application context only. |
| `Widgets/` | `AltitudeWidget` (small/medium, last reading with its age) and `TripLiveActivity` (island + lock screen). Glass look only. |
| `Watch/` | Standalone `Instrument` when the watch has a barometer, mirror of the phone's snapshot when it does not. |
| `Tools/MakeIcon.swift` | Draws the app icon with Core Graphics. Regenerate, don't edit the PNG. The watch icon is the same dial at scale 1.14 so it fills the circular mask: `MakeIcon Watch/Assets.xcassets/AppIcon.appiconset/AppIcon.png 1.14`. |
| `Tools/asc.swift` | Mints an App Store Connect API token. See *Distribution*. |

`SensorEngine`, `Instrument` and `Settings` are all `@MainActor @Observable`.
`LocationProxy` is a separate `NSObject` because `CLLocationManagerDelegate` is
an Objective-C protocol; its conformance is `@preconcurrency`.

## Decisions that look wrong until you know why

**Altitude is computed from raw pressure, not `startAbsoluteAltitudeUpdates`.**
The absolute-altitude API is the obvious choice and it is the wrong one: it needs
a location fix, and Apple's own forums carry long-standing reports of it stalling
uncalibrated and of it silently collapsing to the GPS value. Computing from
`CMAltitudeData.pressure` keeps the altimeter alive indoors, in a canyon and in
airplane mode. Don't "simplify" this back.

**Both altitudes are always shown, side by side.** Not one behind a toggle. The
two sensors fail in uncorrelated ways, so the delta between them is the only
honest trust signal — and it is measured, not estimated. The dot marks which one
feeds the trace and the trip totals.

**iPhone only.** `TARGETED_DEVICE_FAMILY = 1`. An earlier build was rejected by
Apple because iPad requires all four orientations for multitasking, and this is a
single portrait column. Supporting iPad means designing a landscape layout that
does not exist.

**Never show a number you do not have.** No speed fix says so in words rather
than showing `0` — and not a dash either: at readout size a dash is a slab that
reads as redacted. There is no climb rate without an altitude, no `±` without a
reading, and no average before enough moving time has accrued. Preserve this when
adding readouts.

**A trip is the only background mode.** Start trip turns on background
location updates (the blue indicator), keeps the barometer alive through them,
and starts the Live Activity. End trip stops all three. Outside a trip the
sensors stop the moment the app leaves the screen, as before. This keeps the
battery cost something the user chose.

**The widget shows its age.** WidgetKit cannot be live, so the home-screen
widget says "as of N min ago" with a relative-date `Text` that ticks without
reloads. The app only asks for a reload when a figure actually moved.

**Monospaced digits everywhere.** Proportional numerals shift sideways as digits
change, which makes an instrument look unsteady.

## Accuracy

Single-layer troposphere approximation: within 0.15 m of the ISA table below
3000 m, ~4 m at 5000 m, ~10 m at 8000 m. Calibration round-trips exactly at any
altitude. A stale reference costs about **8 m per hectopascal**, which dwarfs the
model error anywhere people walk — hence the staleness warning after 6 hours.

## Distribution

Bundle ID `com.woodenshark.barometer` · App Store Connect app ID `6804415278`'s
successor **`6804417354`** ("Mini Altimeter") · team `V7YK72YLFF`.

Archive, sign and upload in one step:

```bash
xcodebuild archive -project Barometer.xcodeproj -scheme Barometer \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath /tmp/MA.xcarchive -allowProvisioningUpdates \
  -authenticationKeyPath "$PWD/AuthKey_XXXXXXXXXX.p8" \
  -authenticationKeyID XXXXXXXXXX -authenticationKeyIssuerID <issuer-uuid>

xcodebuild -exportArchive -archivePath /tmp/MA.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath /tmp/MA-export \
  -allowProvisioningUpdates -authenticationKeyPath "$PWD/AuthKey_XXXXXXXXXX.p8" \
  -authenticationKeyID XXXXXXXXXX -authenticationKeyIssuerID <issuer-uuid>
```

`ExportOptions.plist` has `destination: upload`, so export *is* the upload.
**Bump `CURRENT_PROJECT_VERSION` first** — Apple refuses a repeated build number.
Once a `MARKETING_VERSION` has been approved on the App Store that train is
closed: bump it (1.0 → 1.1) or the upload fails with error 90186. Keep the
three targets' versions identical; Apple checks they match.

With Xcode signed in to the team, neither the API key nor the two
`-authenticationKey*` flags are needed: `-allowProvisioningUpdates` alone
signs and uploads.

### Setting up a new machine

The API key is deliberately **not** in this repo (`*.p8` and `AuthKey_*` are
gitignored). To work on distribution elsewhere:

1. App Store Connect → Users and Access → Integrations → App Store Connect API.
2. Use the existing team key if you still have the `.p8`; Apple only lets you
   download it once, so otherwise generate a new one (Admin role if you need to
   manage testers).
3. Put it in the repo root or `~/.appstoreconnect/private_keys/`, `chmod 600`.
4. The **Key ID** is in the key's filename (`AuthKey_<KeyID>.p8`). The
   **Issuer ID** is on that same page, one per team; it is not on disk anywhere
   and searching a machine for it wastes time — read it off the website.

Signing needs no Xcode sign-in: `-allowProvisioningUpdates` with the API key
mints the certificate and profile itself.

### App Store Connect API gotchas

These each cost real time to rediscover:

- **`curl` eats the brackets** in `filter[app]=…`. Use `%5B` / `%5D`, or `-g`.
- **Relationship data is omitted** from responses unless you ask: append
  `?include=primaryCategory` or you will think a successful PATCH did nothing.
- **No API creates an app record.** `apps` allows GET and UPDATE only.
- **No API answers the App Privacy questionnaire.** The app record exposes 40
  relationships and none of them cover privacy. Manual in the web UI.
- **Screenshots cannot be touched while a version is in review** — Apple returns
  "Can't Create Screenshot Set while In Review".
- Token: `Tools/asc.swift` mints one. `swiftc -O Tools/asc.swift -o /tmp/asc`
  then `/tmp/asc <key.p8> <keyID> <issuerID>`. Valid 15 minutes.

## Known issues

- **Never run on real hardware.** The barometric path — the app's whole point —
  has only ever been checked against the ISA table and in the Simulator, which
  has no barometer. Calibrate against a known elevation before trusting it.
- **The watch mirror path has only been exercised in code.** Testing it needs a
  paired watch simulator (`xcrun simctl pair <watch> <phone>`) or real hardware.
  The App Group `group.com.woodenshark.barometer` must exist on the team; automatic
  signing registers it on the first device build.
- **The Live Activity uses the Glass palette regardless of theme.** The extension
  would need the theme name in the App Group to follow it.
- **GPS is configured for maximum power draw**: `kCLLocationAccuracyBestForNavigation`,
  `distanceFilter = kCLDistanceFilterNone`, and `keepScreenAwake` defaults on. Fine
  for an instrument you are looking at; do not market the app as battery-light
  without changing this first.
- Screenshots exist for the 6.9" iPhone slot (iPhone 17 Pro Max simulator,
  1320×2868) and the Series 10 watch slot (Series 11 46 mm simulator, 416×496).
  6.5"/6.1"/5.8"/4.7" would be nice; 3.5"/4.0"/5.5" are pointless because no
  iOS 17 device has those screens. The island and lock-screen shots need a trip
  started by hand and the Live Activities prompt allowed on the lock screen.

## Localization

Twenty languages besides English, all in `Shared/Localizable.xcstrings` (one
catalog, compiled into all three targets) plus `InfoPlist.xcstrings` in the
app and watch folders for the permission prompts. Every UI string is a
`LocalizedStringKey`; components take keys, not `String`, so a literal at a
call site is localized and a computed value is not. Model-level names
(`AltitudeUnit.name`, `AppTheme.name`, `AltitudeSource.detail`) go through
`String(localized:)`.

`xcodebuild build` does **not** update the catalog; extract new keys with

```bash
xcodebuild -exportLocalizations -project Barometer.xcodeproj \
  -localizationPath /tmp/loc -exportLanguage en
# then copy "/tmp/loc/en.xcloc/Source Contents/Shared/Localizable.xcstrings" back
```

Test a language without changing the Simulator: `xcrun simctl launch booted
com.woodenshark.barometer -AppleLanguages "(ja)"`. Symbols (BARO, GPS, unit
symbols, `± %@ %@`) are marked do-not-translate in the catalog.

The App Store listing exists in the same 20 locales on version 1.1, pushed via
the API; the English screenshots are reused for every locale.

## Conventions

Comments explain *why*, never *what* — the code already says what. Match the
existing density; these files are commented at decision points and nowhere else.
Sentence case in UI strings. Em dashes, not hyphens, in prose.
