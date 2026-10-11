# TeachersTimetable

SwiftUI iPhone app + Apple Watch companion app for "수업 알리미".

## Targets

- `TeachersTimetable`: iPhone app
- `TeachersTimetable Watch App`: watchOS SwiftUI app embedded in the iPhone app

## Bundle Identifiers

- iPhone app: `com.chail.classReminderClean`
- Watch app: `com.chail.classReminderClean.watchapp`

The previous Watch App Extension target has been removed. The Watch app now builds as a single extensionless watchOS app target with its own SwiftUI `@main` entry point.

## Build Notes

Open `TeachersTimetable.xcodeproj`, select your signing team for both targets, and keep Automatically manage signing enabled.

The migrated app keeps the original timetable UI, UserDefaults-based snapshot storage, UserNotifications scheduling, and WatchConnectivity synchronization flow. No App Groups, SwiftData, CloudKit, or unrelated architecture changes were added.

For install verification, delete "수업 알리미" from both iPhone and Apple Watch, run Clean Build Folder, install the iPhone target on the physical iPhone, then install the Watch app from the iPhone Watch app.
