# Privacy Policy — Mini Altimeter

_Last updated: 23 August 2026_

Mini Altimeter collects nothing, stores nothing about you, and sends nothing
anywhere.

## What the app reads

**Barometric pressure**, from the pressure sensor built into the device. This is
what the altimeter is computed from. It never leaves the device.

**Location**, while you are using the app, from the device's satellite receiver.
It supplies the GPS altitude and your ground speed. It is used only to draw those
numbers on screen. It is never recorded, never stored between launches, and never
transmitted.

## What leaves the device

Nothing. The app contains no networking code of any kind — no analytics, no
crash reporting, no advertising, no third-party SDKs. It links only Apple's
CoreLocation, CoreMotion, SwiftUI, UIKit and Foundation frameworks. You can
verify this yourself: the source is public at
https://github.com/mitgor/minimalistic-altimeter

The app works fully offline, in airplane mode, with no account and no sign-in.

## What is stored

Your preferences only — units, which altitude source is primary, the calibration
reference, and whether the screen stays awake. These live in the app's own
storage on your device and are removed when you delete the app.

The altitude trace behind the readout is held in memory for the last fifteen
minutes and is discarded when the app closes.

## Children

The app collects no data from anyone, of any age.

## Changes

Any change to this policy will be published at this address with a revised date.

## Contact

Questions: open an issue at
https://github.com/mitgor/minimalistic-altimeter/issues
