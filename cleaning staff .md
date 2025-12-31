# Cleaning Staff Application Documentation

This document is the canonical product and technical overview for the Cleaning Staff app. It covers roles, features, key workflows, data models, logic flows, and platform behavior. Use this as the single source of truth for feature understanding, QA, and deployment readiness.

## Audience
- Stakeholders and product owners
- Developers and QA
- Deployment/ops engineers

## Roles
- Admin
  - Manages staff, shifts, recurring tasks, task assignments, notifications, reports, and settings.
- Staff
  - Receives tasks, performs work, checks in/out, views notifications, and interacts with the chatbot (Help).

## High-Level Features
1) Authentication
- Email/password sign in and out using Firebase Authentication.
- Device token saved per user for push notifications.

2) Dashboard (Admin)
- Metrics displayed live from Realtime Database:
  - Total Tasks
  - Pending Tasks
  - Completed Tasks
  - Total Staff
- Charts:
  - Task Status Pie Chart
  - Tasks per Area Bar Chart
- Priority Tasks: highlights overdue and urgent tasks within next 24h.

3) Dashboard (Staff)
- Personal greeting and quick stats.
- Performance analytics tailored by selected time period.
- Status cards: Today’s shift time (if any) and attendance status (Check In/Check Out).
- Recurring tasks overview (active subset).
- Priority tasks summary.

4) Tasks Management
- Admin:
  - List, filter (status, area, staff, time period), sort.
  - Assign/reassign tasks to staff.
  - Create one-time or recurring tasks (via Recurring Tasks module).
  - Delete tasks.
- Staff:
  - View assigned tasks.
  - Update task status (Pending → In Progress → Completed).

5) Recurring Tasks
- Admin creates recurring templates with:
  - Title, description, area
  - Frequency (daily/weekly/monthly/quarterly/annually)
  - Preferred time and preferred days
  - Assigned staff
- System generates one-time CleaningTask instances from templates (manual generation supported; scheduled generation provided by service).

6) Shifts
- Admin creates and manages shifts per staff member with start/end times.
- Staff view their daily shift on dashboard.

7) Attendance
- Staff can Check In and Check Out.
- Daily attendance stored per staff/date.

8) Notifications
- Admin can send notifications to all staff or specific staff members.
- Staff receive notifications and can view Notification History.
- Local notifications show for foreground events; push notifications supported via FCM.

9) Security & Settings
- Admin and Staff settings separated.
- Admin can change app-level configurations.
- Password change supported.

10) Offline/Cache (Foundations)
- Basic offline awareness and caching hooks/services are present.
- The UI surfaces offline state and retries where applicable.

11) Audit Logs (Foundations)
- Admin actions may be recorded in audit logs for traceability.

## Navigation and Drawer
- Admin drawer order:
  1. Home
  2. Staff Management
  3. Shift Management
  4. Attendance Tracking
  5. Recurring Tasks
  6. Admin Task Report
  7. Notification History
  8. Settings
  9. Logout

- Staff drawer order:
  1. Home
  2. Tasks
  3. Help (Chatbot)
  4. Notification History
  5. Settings
  6. Logout

## Data Models (Key Fields)

### CleaningTask
- id: string
- title: string
- description: string
- area: CleaningArea
- assignedTo: string (userId)
- assignedToName: string
- dueDate: DateTime (ms epoch)
- frequency: CleaningFrequency (for context only; one-time tasks usually weekly by default if missing)
- lastCleanedDate?: DateTime (ms epoch)
- status: CleaningStatus (pending/inProgress/completed)
- proofOfWorkUrl?: string
- creatorUid: string
- creatorName: string
- compositeKey: string (title|area|dueDay|assignedTo) for deduplication

### RecurringTask
- id: string
- title, description, area
- frequency: CleaningFrequency
- preferredTime?: TimeOfDay
- preferredDays: List<int> (Mon..Sun → 1..7)
- assignedTo, assignedToName
- status: RecurringTaskStatus (active/paused/cancelled)
- currentOccurrences: int
- maxOccurrences?: int
- createdAt: DateTime

### Shift
- id: string
- userId, userName
- startTime, endTime

### Attendance
- id: string
- userId
- date: Date (start-of-day)
- checkInTime: DateTime
- checkOutTime?: DateTime

### AppUserData
- uid
- email
- role: 'admin' | 'staff'
- name?
- deviceToken?

### AppNotification
- id
- title, message
- recipientUserId
- createdAt
- read: bool

## Logic Flows

### 1) Authentication & App Start
1. App initializes Firebase and local notifications (no startup test messages; no exact alarm permission requested).
2. AuthWrapper listens to auth state and routes:
   - If logged in → MainScreen with role-based tabs.
   - If not logged in → Login screen.
3. Device token saved for logged-in user.

### 2) Admin Assigns a Task
1. Admin opens Tasks screen.
2. Admin creates task or reassigns from list:
   - Assign staff, title/description/area, due date.
3. Creation checks compositeKey to avoid duplicate tasks identical by title/area/due day/assignee.
4. Notification optionally sent to assigned staff.

### 3) Staff Task Execution
1. Staff views assigned tasks on My Tasks.
2. Staff updates status as work progresses.
3. Completed tasks appear reflected in dashboards and history.

### 4) Recurring Task Generation
1. Admin configures recurring template (frequency, days/time, assignee).
2. System or admin triggers generation → creates actual CleaningTask adhering to deduplication.
3. Recurring view shows active templates and next due dates.

### 5) Attendance
1. Staff dashboard shows Today’s Shift.
2. Staff taps Check In to record daily attendance (date + checkInTime).
3. End of day, staff taps Check Out to set checkOutTime for that attendance record.

### 6) Notifications
1. Admin composes a message for a specific staff or broadcast.
2. Push and local notifications are delivered where applicable.
3. Staff view Notification History with read status.

### 7) Analytics & Dashboard (Admin)
1. Counts are computed directly from Realtime Database streams (total/pending/completed tasks and total staff).
2. Charts update live based on selected time period filtering (daily/weekly/monthly/annually).

## Realtime Database Indexing (Recommended)
To reduce warnings and improve performance, configure indexes in Firebase console rules:
- users: .indexOn ["role"]
- tasks: .indexOn ["assignedTo", "status"]
- shifts: .indexOn ["userId"]
- attendance: .indexOn ["userId"]
- recurring_tasks: .indexOn ["status", "assignedTo"]
- notifications: .indexOn ["recipientUserId"]

## Platform Behavior
- Android
  - Using @mipmap/launcher_icon for notifications.
  - Back invoked callback enabled in AndroidManifest for Android 13+.
  - No exact alarm permission requested at startup.
- iOS
  - Uses Foreground presentation options for notifications.
- Web
  - Basic web build supported.

## Non-Functional
- Input validation on forms.
- Error handling services for load/retry states.
- Offline awareness (surface states and retry paths).
- Audit logs for admin actions (where configured).

## Deployment Summary
- Android: flutter build appbundle --release (Play Store), or flutter build apk --release
- iOS (macOS): flutter build ipa --release
- Web: flutter build web

## Known Non-Blocking Notes
- MissingPluginException during hot reload stream teardown (debug only).
- Firebase App Check not configured (optional; can be added later).

## Changelog Highlights (Stability)
- Removed startup test notification.
- Suppressed exact alarm permission prompt on launch.
- Fixed Tasks tab overflow and drawer ordering (admin and staff).
- Metrics pulled directly from database.
- Deduplication and prevention of duplicate task creation.

---
End of document.
