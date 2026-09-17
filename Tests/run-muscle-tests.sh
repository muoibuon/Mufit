#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /private/tmp/mufit-muscle-tests.XXXXXX)
target="$(uname -m)-apple-macos14.0"
common=(Shared/Models/Enums.swift Shared/Models/Nutrition.swift)
xcrun swiftc -target "$target" -module-name MufitStoreTest "${common[@]}" \
  Tests/Fixtures/TrainingBeforeAnatomy.swift Tests/Fixtures/ProfileBeforeMuscleNotes.swift Tests/MigrationFixture.swift -o "$test_dir/fixture"
"$test_dir/fixture" "$test_dir/legacy.store"
xcrun swiftc -target "$target" -module-name MufitStoreTest "${common[@]}" \
  Shared/Models/Training.swift Shared/Models/Profile.swift Shared/Services/BackupPayload.swift \
  App/Services/WeeklyMuscleTracker.swift App/Services/WeeklyMuscleTracker+Models.swift \
  App/Services/AnatomicalMuscle.swift App/Services/AnatomicalTrainingTracker.swift \
  App/Services/MuscleTrainingGuidance.swift App/Services/WorkoutDraft.swift Tests/MusclePersistenceTests.swift -o "$test_dir/persistence"
"$test_dir/persistence" "$test_dir/legacy.store"
xcrun swiftc Shared/Models/Enums.swift App/Services/WeeklyMuscleTracker.swift \
  Tests/WeeklyMuscleTrackerTests.swift -o "$test_dir/weekly"
"$test_dir/weekly"
xcrun swiftc Shared/Models/Enums.swift App/Services/WeeklyMuscleTracker.swift \
  App/Services/AnatomicalMuscle.swift App/Services/AnatomicalTrainingTracker.swift \
  App/Views/Body/MuscleAnatomyGeometry.swift Tests/AnatomyTests.swift -o "$test_dir/anatomy"
"$test_dir/anatomy"
printf 'Test artifacts: %s\n' "$test_dir"
