# Muscle map checks

Run from the project directory on macOS with Xcode installed:

```sh
bash Tests/run-muscle-tests.sh
```

The script uses a newly created temporary database, never the app's live store.
It checks Monday/Sunday boundaries, DST, year boundaries, training-day deduplication,
primary/secondary sets, skipped and future records, old-store migration, note persistence,
backup round trips and decoding backups without notes. The fixture model is the original
Profile.swift from before the optional muscleNotesJSON field was added.

Build the app and widget:

```sh
xcodebuild -project Mufit.xcodeproj -scheme Mufit -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/mufit-muscle-map-build CODE_SIGNING_ALLOWED=NO build
```

Manual UI check: open Cơ thể → Bản đồ cơ tuần này, switch Nam/Nữ and Mặt trước/Mặt sau,
tap a muscle, save a note, then reopen it. Complete a session with an actual working set;
the main and explicitly assigned assisting muscles should turn green. A warmup-only or
zero-repetition session should not change the map. A new calendar week clears only the
current-week indicators. Notes and historical sessions remain stored.
