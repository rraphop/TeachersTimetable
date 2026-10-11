# TeachersTimetable

SwiftUI iPhone app for "수업 알리미".

## Releases

- [`v1.0-build.5`](https://github.com/rraphop/TeachersTimetable/releases/tag/v1.0-build.5): current iPhone app, version 1.0 (build 5).
- [`v1.0-build.1`](https://github.com/rraphop/TeachersTimetable/releases/tag/v1.0-build.1): archived iPhone + Apple Watch app, version 1.0 (build 1).

Each tag contains its matching Xcode project at the repository root. Releases provide source code, not a signed IPA. Only the two available source snapshots are published; builds 2–4 are unavailable. See [CHANGELOG.md](CHANGELOG.md) for details.

## Targets

- `TeachersTimetable`: iPhone app

## Bundle Identifiers

- iPhone app: `com.chail.TeachersTimetable`

## Build Notes

Open `TeachersTimetable.xcodeproj`, select your signing team for the iPhone target, and keep Automatically manage signing enabled.

The app keeps the original timetable UI, UserDefaults-based snapshot storage, and UserNotifications scheduling flow. No App Groups, SwiftData, CloudKit, or unrelated architecture changes are used.

For install verification, delete "수업 알리미" from the iPhone, run Clean Build Folder, then install the iPhone target on the physical iPhone.
