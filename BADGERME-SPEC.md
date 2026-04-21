I'm starting a new project called Badgerme. Please read the Product Specifications document and then suggest things that should be done to help Claude support this project eggectively.

**Version:** 1.0  
**Status:** Pre-development  
**Last Updated:** April 2026  
**Prepared for:** Claude Code / Xcode development workflow

---

## Table of Contents

1. [Product Vision](#1-product-vision)
2. [Core Concept](#2-core-concept)
3. [Target Users](#3-target-users)
4. [Use Cases](#4-use-cases)
5. [Feature Scope — V1](#5-feature-scope--v1)
6. [Feature Scope — Future Versions](#6-feature-scope--future-versions)
7. [Notification Design & Platform Constraints](#7-notification-design--platform-constraints)
8. [Data Models](#8-data-models)
9. [Architecture](#9-architecture)
10. [Notification Engine](#10-notification-engine)
11. [Trigger Sources](#11-trigger-sources)
12. [UI & Navigation Structure](#12-ui--navigation-structure)
13. [Watch App](#13-watch-app)
14. [Settings & Configuration](#14-settings--configuration)
15. [Design Requirements](#15-design-requirements)
16. [Pricing & Distribution](#16-pricing--distribution)
17. [Technical Requirements](#17-technical-requirements)
18. [Developer Notes for Claude Code](#18-developer-notes-for-claude-code)
19. [Open Questions](#19-open-questions)

---

## 1. Product Vision

BadgerMe is a focused iOS utility that delivers escalating notifications for tasks the user has committed to completing — and keeps delivering them until the user explicitly responds.

**The core problem it solves:** Standard reminders fire once and disappear. If you're in flow, on a call, or simply ignoring your phone, a single notification achieves nothing. BadgerMe treats unacknowledged reminders as an active problem and escalates its response until you deal with it.

**What makes it different from existing tools:**

- **Due** (the closest competitor) does repeating reminders but with fixed behavior and opaque pricing bundled into app suites. It has no configurable per-level action ladder and no acknowledgment-aware escalation.
- **Apple Reminders** fires once. That's it.
- **Other to-do apps** treat notifications as an afterthought.

BadgerMe makes the acknowledgment loop the entire product. The app knows whether you've seen, snoozed, or ignored a notification — and it acts accordingly.

**Positioning:**  
_"Notifications that don't give up until you do."_

---

## 2. Core Concept

### The Badger

A **Badger** is the unit of work in BadgerMe. It represents a single task or commitment that the user needs to be reminded about with escalating intensity until they respond.

Each Badger has:

- A title and optional notes
- A start time (when badgering begins)
- An **Escalation Ladder** (a sequence of configurable notification levels)
- A **Nuclear Option** (what happens if all levels are exhausted with no response)
- An acknowledgment state

### The Escalation Ladder

The ladder is a user-configured sequence of levels. Each level defines:

- What notification action to take (sound, haptic, speak, etc.)
- How long to wait before advancing to the next level

Example ladder:

```
Level 1: Soft chime → wait 5 minutes
Level 2: Standard alert sound → wait 10 minutes
Level 3: Loud alert + speak task title aloud → wait 15 minutes
Level 4 (Nuclear): Repeat Level 3 every 5 minutes indefinitely
```

### Acknowledgment

The user can respond to any notification with:

- **Done** — marks the Badger complete, stops escalation
- **Snooze** — pauses escalation for a configurable duration, then restarts from Level 1
- **Dismiss** — stops badgering without completing (logged)

The key insight: BadgerMe knows the difference between _seen and handled_, _seen and snoozed_, and _ignored_. Standard reminders don't.

---

## 3. Target Users

### Primary: Self-Directed Knowledge Workers

People who manage their own schedules, work with high autonomy, and struggle with task switching or hyperfocus. They need something that will interrupt their flow state when important commitments are being missed.

**Characteristics:**

- Uses Reminders or a similar task manager
- Has important, time-sensitive tasks mixed with routine work
- Tends to silence phone during focus periods
- Wants to be interrupted for the right things, at the right intensity

### Secondary: Power Users / Automation Enthusiasts

Users who run home automation setups, n8n/Home Assistant workflows, or personal AI assistants. They want a reliable delivery mechanism for programmatic nudges — BadgerMe as the notification endpoint for their automation stack.

**Characteristics:**

- Comfortable with webhook configuration
- May run local servers (Tailscale, home network)
- Wants fine-grained control over behavior

### Non-Target

- Enterprise/team use (out of scope — no shared data, no accounts)
- Medical/safety use (Critical Alerts entitlement not pursued in V1)
- Users who just want a simple to-do app

---

## 4. Use Cases

### UC-1: The Overdue Task

**Scenario:** A task in Apple Reminders is past due. The user is in focus mode and hasn't noticed.

**Flow:**

1. BadgerMe detects the overdue reminder via EventKit polling
2. A Badger is automatically created using the default ladder
3. Level 1 notification fires — soft sound, dismissible banner
4. User doesn't respond
5. After 10 minutes: Level 2 — louder sound, stays on screen
6. After another 10 minutes: Level 3 — app speaks the task title aloud
7. User taps Done → Badger marked complete, Reminder marked complete in system

---

### UC-2: The Commitment I Made to Myself

**Scenario:** The user needs to leave for an appointment in 30 minutes and wants to be progressively warned.

**Flow:**

1. User creates a manual Badger: "Leave for dentist" starting at 2:00 PM
2. Configures a custom ladder: gentle at 2:00, firm at 2:15, aggressive at 2:25
3. At 2:25, the notification speaks "Leave for dentist NOW" through the phone speaker
4. User taps Done → Badger resolved

---

### UC-3: The Ignored Snooze Loop

**Scenario:** User snoozes a Badger. Then snoozes again. The app escalates snooze behavior.

**Flow:**

1. Badger fires Level 2 notification
2. User taps Snooze 15 minutes
3. 15 minutes later, Badger restarts at Level 1
4. User snoozes again
5. After a configurable maximum snooze count, BadgerMe skips to a higher level on restart

---

### UC-4: The Automation Trigger (Power User)

**Scenario:** User's n8n workflow detects an overdue Todoist task and wants to badger the user.

**Flow:**

1. n8n sends a webhook POST to BadgerMe's local listener (Tailscale-accessible)
2. Payload includes task title, optional URL, and desired ladder profile
3. BadgerMe creates a Badger and begins escalation immediately
4. User responds via notification actions; outcome posted back to n8n callback URL

---

### UC-5: The Watch Confirmation

**Scenario:** User's phone is in another room. The Watch taps and displays the Badger.

**Flow:**

1. Notification mirrors to Apple Watch automatically
2. Watch shows task title with Done / Snooze / Dismiss actions
3. User taps Done on watch
4. Badger marked complete on phone via WatchConnectivity

---

### UC-6: The Nuclear Option

**Scenario:** User has been ignoring a Badger for 45 minutes. All ladder levels exhausted.

**Flow (configurable options):**

- Repeat the final level indefinitely at a fixed interval
- Phone calls itself (using URL scheme trick — aggressive but effective)
- Sends a message to a nominated contact ("Amos still hasn't done X")
- Gives up and logs as abandoned (soft option)

---

## 5. Feature Scope — V1

V1 is deliberately scoped to deliver the core loop reliably. No features that don't serve the acknowledgment engine.

### ✅ Included in V1

**Badger Management**

- Create manual Badgers with title, notes, start time
- View active, snoozed, and completed Badgers
- Delete or edit pending Badgers
- Badger history log

**Escalation Engine**

- Global default ladder (user-configured in Settings)
- Per-Badger ladder override (optional — can inherit default)
- Ladder levels: sound selection, haptic, speak text, wait duration
- Maximum snooze count per Badger before escalation on re-fire
- Nuclear option configuration (repeat forever / give up / message contact)

**Notification Actions**

- Done (completes Badger)
- Snooze — 5, 15, 30, 60 minutes (configurable options)
- Dismiss (stops without completing)
- All actions available from notification without opening app

**Trigger Sources**

- Manual Badger creation (in-app)
- Apple Reminders integration via EventKit (overdue items, selected lists)
- Webhook listener for local network triggers (power user feature, opt-in)

**Notification Types Available**

- Standard alert with custom sound
- Time Sensitive (breaks through Focus modes — requires user opt-in for Focus settings)
- Speak Text via AVSpeechSynthesizer (plays through speaker at configured volume)
- Torch flash (brief, accessible pattern)

**Watch Support**

- Notification mirrors to Watch automatically
- Done / Snooze / Dismiss action buttons on Watch notification
- WatchConnectivity sync for acknowledgment state

**Settings**

- Default escalation ladder editor
- Notification permission management
- Reminders integration (list selection, polling interval)
- Webhook listener toggle + port configuration
- Snooze duration options
- Nuclear option configuration
- Sound library (system sounds + custom import)

### ❌ Explicitly Excluded from V1

- Todoist integration (V2)
- APNs / remote push from external servers (V2 — adds complexity, provisioning overhead)
- iCloud sync across devices (V2)
- Sharing Badgers with others
- Critical Alerts (requires Apple entitlement — not pursing for personal productivity use case)
- Home screen widgets
- Shortcuts app integration (V2 — useful but not core)
- CarPlay support

---

## 6. Feature Scope — Future Versions

**V2 Candidates**

- Todoist integration via OAuth (direct API polling, no server required)
- Apple Shortcuts integration (expose BadgerMe as a Shortcuts action — receive triggers, report state)
- iCloud sync for Badgers across devices
- APNs support for remote push triggers
- Widget showing active Badger count and next escalation time
- Repeat Badgers (daily standup, medication, etc.)
- Badger templates (reusable ladder configurations)

**V3 Candidates**

- Mac Catalyst or native macOS app
- Contact notification on nuclear (iMessage to a nominated contact)
- Siri integration ("Hey Siri, start badgering me about X")
- HealthKit integration (trigger on inactivity / sedentary time)

---

## 7. Notification Design & Platform Constraints

### What BadgerMe Can Do (Without Special Entitlements)

| Action                                   | Works? | Notes                                                                             |
| ---------------------------------------- | ------ | --------------------------------------------------------------------------------- |
| Standard alert + sound                   | ✅     | Full control                                                                      |
| Time Sensitive (breaks Focus)            | ✅     | Requires `.timeSensitive` entitlement — free, no Apple approval needed            |
| Speak text aloud (AVSpeechSynthesizer)   | ✅     | Runs when app is foregrounded by notification tap; cannot run mid-background      |
| Speak text via notification (in-process) | ⚠️     | Limited — app must be brought to foreground or use Notification Service Extension |
| Torch flash                              | ✅     | Via AVCaptureDevice — brief accessible alert                                      |
| Watch haptic + notification mirror       | ✅     | Automatic with notification delivery                                              |
| Repeat notification at interval          | ✅     | Via scheduling multiple UNNotificationRequests                                    |
| Critical Alerts (bypasses mute/DND)      | ❌     | Requires Apple entitlement — not suitable for productivity use case               |

### Time Sensitive Notifications

The `.timeSensitive` notification interruption level is the practical ceiling for BadgerMe. It:

- Breaks through Focus modes that don't explicitly allow the app
- Appears on lock screen even in restricted Focus
- Does NOT bypass silent/mute switch
- Does NOT bypass Do Not Disturb on Apple Watch
- Requires the user to grant "Time Sensitive" permission per-app in Settings

**Developer note:** Request `.timeSensitive` entitlement in Xcode capabilities. No Apple approval needed — just user permission at runtime.

### Speak Text Implementation

AVSpeechSynthesizer cannot run reliably from a background state triggered by a notification alone. The correct implementation:

1. Notification fires with a custom sound (works from background)
2. If user doesn't interact, next notification fires at escalation interval
3. For Speak Text levels: include a notification action "Hear Task" that, when tapped, foregrounds the app and speaks the title
4. Alternative: Pre-render speech as a custom notification sound file and embed in the notification payload — this works from background without app foreground

**Recommendation:** Pre-render common speech patterns (task title) as audio files at Badger creation time using AVSpeechSynthesizer, cache them, and attach as custom notification sounds. This is the most reliable approach.

### Background Execution

BadgerMe's escalation engine relies on scheduled `UNNotificationRequest` objects — these survive app suspension cleanly because they're owned by the system, not the app process. The engine does NOT need background execution to fire notifications.

However, **EventKit polling** (checking for overdue Reminders) does require occasional background access:

- Use `BGAppRefreshTask` for periodic Reminders polling
- Register in `Info.plist` under `BGTaskSchedulerPermittedIdentifiers`
- Apple controls actual frequency — typically 15–30 minute intervals
- Supplement with foreground refresh on app launch and scene activation

**Key principle:** Pre-schedule all notification requests when a Badger is created. Don't depend on background wakeups to schedule the next level. Schedule the entire ladder upfront; cancel future requests when the user acknowledges.

---

## 8. Data Models

### Badger

```swift
@Model
class Badger {
    var id: UUID
    var title: String
    var notes: String?
    var createdAt: Date
    var startsAt: Date
    var state: BadgerState          // active, snoozed, completed, dismissed, abandoned
    var currentLevel: Int           // which ladder level is currently active
    var snoozeCount: Int            // how many times snoozed total
    var acknowledgedAt: Date?
    var sourceType: TriggerSource   // manual, reminders, webhook
    var sourceIdentifier: String?   // EKReminder identifier, webhook ID, etc.

    // Ladder — if nil, inherits from global default
    var customLadder: EscalationLadder?

    // Computed
    var nextEscalationAt: Date?
    var isOverdue: Bool
}

enum BadgerState: String, Codable {
    case active
    case snoozed
    case completed
    case dismissed
    case abandoned
}

enum TriggerSource: String, Codable {
    case manual
    case reminders
    case webhook
}
```

### EscalationLadder

```swift
@Model
class EscalationLadder {
    var id: UUID
    var name: String                    // "Default", "Urgent", "Gentle", etc.
    var levels: [EscalationLevel]       // ordered array
    var nuclearOption: NuclearOption
    var maxSnoozeCount: Int             // after this many snoozes, escalate on re-fire
    var snoozeRestartLevel: Int         // which level to restart from after snooze
}

struct EscalationLevel: Codable, Identifiable {
    var id: UUID
    var order: Int
    var waitDurationSeconds: Int        // how long before advancing
    var actions: [EscalationAction]     // what happens at this level
}

struct EscalationAction: Codable {
    var type: ActionType
    var config: ActionConfig
}

enum ActionType: String, Codable {
    case sound
    case speakText
    case torchFlash
    case notificationBanner
}

struct ActionConfig: Codable {
    var soundName: String?              // system sound name or custom filename
    var soundVolume: Float?             // 0.0 – 1.0
    var speechText: String?            // nil = use Badger title
    var speechVolume: Float?
    var torchDuration: Double?         // seconds
    var notificationTitle: String?
    var notificationBody: String?
    var interruptionLevel: String?     // "active", "timeSensitive"
}

enum NuclearOption: String, Codable {
    case repeatForever                  // keep repeating last level
    case giveUp                         // stop, mark abandoned
    case notifyContact                  // send iMessage to nominated contact (V2)
}
```

### AppSettings

```swift
// Stored in UserDefaults via @AppStorage
// Not a SwiftData model — settings are global, not relational

struct AppSettings {
    var defaultLadderId: UUID
    var reminderPollingEnabled: Bool
    var reminderListIdentifiers: [String]   // EKCalendar identifiers
    var webhookListenerEnabled: Bool
    var webhookPort: Int                    // default 8765
    var snoozeDurations: [Int]              // minutes: [5, 15, 30, 60]
    var timeSensitiveRequested: Bool
    var onboardingComplete: Bool
}
```

### BadgerEvent (Audit Log)

```swift
@Model
class BadgerEvent {
    var id: UUID
    var badgerId: UUID
    var timestamp: Date
    var eventType: BadgerEventType
    var levelAtEvent: Int
    var notes: String?
}

enum BadgerEventType: String, Codable {
    case created
    case levelFired
    case snoozed
    case completed
    case dismissed
    case abandoned
    case escalated
}
```

---

## 9. Architecture

### Overview

BadgerMe follows a **layered architecture** with clear separation between data, business logic, and UI. Given that SwiftUI views function as view models in modern patterns, the architecture avoids adding a redundant ViewModel layer for simple views while introducing explicit service objects for complex business logic.

```
┌─────────────────────────────────────┐
│           SwiftUI Views             │  ← Presentation only
├─────────────────────────────────────┤
│          Service Layer              │  ← Business logic, orchestration
│  BadgerEngine | RemindersService    │
│  NotificationService | WebhookServer│
├─────────────────────────────────────┤
│          Data Layer                 │  ← Persistence
│  SwiftData (Badger, Ladder, Event)  │
│  UserDefaults (AppSettings)         │
│  EventKit (Reminders access)        │
├─────────────────────────────────────┤
│        System Frameworks            │
│  UNUserNotificationCenter           │
│  AVSpeechSynthesizer                │
│  WatchConnectivity                  │
│  EventKit                           │
│  BGTaskScheduler                    │
│  Network (webhook listener)         │
└─────────────────────────────────────┘
```

### Key Services

#### BadgerEngine

The central coordinator. Responsible for:

- Creating and persisting Badgers
- Scheduling notification request sequences (entire ladder upfront)
- Canceling pending notifications on acknowledgment
- Advancing escalation level state
- Handling snooze logic and snooze count escalation
- Triggering nuclear options
- Writing BadgerEvent audit entries
- Exposing `@Observable` state to views

```swift
@Observable
@MainActor
final class BadgerEngine {
    private let modelContext: ModelContext
    private let notificationService: NotificationService
    private let settings: AppSettings

    var activeBadgers: [Badger]
    var recentHistory: [Badger]

    func createBadger(title: String, ladder: EscalationLadder?, startAt: Date) async
    func acknowledge(badger: Badger, action: AcknowledgmentAction) async
    func snooze(badger: Badger, duration: TimeInterval) async
    func handleNotificationResponse(_ response: UNNotificationResponse) async
}
```

#### NotificationService

Owns all interaction with `UNUserNotificationCenter`:

- Schedules notification request sequences for a Badger's full ladder
- Cancels pending requests by Badger ID
- Registers notification categories and actions
- Handles foreground presentation
- Pre-renders speech audio as custom sound files

```swift
final class NotificationService {
    func scheduleLadder(for badger: Badger, ladder: EscalationLadder) async throws
    func cancelAll(for badgerId: UUID)
    func requestPermissions() async -> Bool
    func prerenderSpeech(text: String, badgerId: UUID) async -> String? // returns filename
}
```

**Critical implementation detail:** Each Badger's full notification ladder is scheduled as a series of `UNNotificationRequest` objects when the Badger is created. Identifiers follow the pattern `badger-{uuid}-level-{n}`. When the user acknowledges at any level, all remaining requests for that Badger are canceled via `removePendingNotificationRequests(withIdentifiers:)`.

#### RemindersService

Wraps EventKit:

- Requests access to Reminders
- Fetches overdue incomplete reminders from configured lists
- Creates Badgers for newly overdue items (deduplicates by `sourceIdentifier`)
- Marks Reminders complete when Badger is acknowledged as Done
- Called on app foreground and BGAppRefreshTask

```swift
final class RemindersService {
    func requestAccess() async -> Bool
    func fetchOverdueReminders(from lists: [String]) async -> [EKReminder]
    func markComplete(_ reminder: EKReminder) async throws
}
```

#### WebhookServer (Optional, Power User)

A lightweight HTTP server that listens on a local port for incoming Badger trigger requests. Disabled by default; enabled in Settings.

- Implemented with Network framework (`NWListener`) — no third-party dependencies
- Accepts POST `/badger` with JSON payload
- Authenticates via a user-generated token (stored in Keychain)
- Creates a Badger via BadgerEngine
- Optionally posts outcome to a callback URL when Badger is acknowledged

```swift
final class WebhookServer {
    func start(port: UInt16) throws
    func stop()
    var isRunning: Bool
}

// Incoming payload
struct WebhookBadgerRequest: Decodable {
    var title: String
    var notes: String?
    var ladderId: UUID?         // nil = use default
    var callbackURL: URL?       // where to POST acknowledgment result
    var token: String
}
```

#### WatchConnectivityService

Manages bidirectional communication with the Watch app:

- Sends active Badger state to Watch on change
- Receives acknowledgment actions from Watch
- Routes Watch acknowledgments through BadgerEngine

---

## 10. Notification Engine

### Scheduling Strategy

The notification engine uses a **pre-schedule-everything** approach. This is the most reliable strategy for iOS because:

1. `UNNotificationRequest` objects survive app termination
2. No background execution is required to fire scheduled notifications
3. Cancellation via identifier is instant and reliable

When a Badger is created with start time T and a 3-level ladder:

```
T+0:00  → Schedule notification: Level 1 request (id: badger-{uuid}-level-1)
T+5:00  → Schedule notification: Level 2 request (id: badger-{uuid}-level-2)
T+15:00 → Schedule notification: Level 3 request (id: badger-{uuid}-level-3)
T+30:00 → Schedule notification: Nuclear repeat sequence...
```

When user taps Done on Level 2 notification:

```swift
UNUserNotificationCenter.current()
    .removePendingNotificationRequests(withIdentifiers: [
        "badger-{uuid}-level-3",
        "badger-{uuid}-nuclear-1",
        // all remaining
    ])
```

### Notification Action Registration

Register categories and actions at app launch:

```swift
let doneAction = UNNotificationAction(
    identifier: "DONE",
    title: "✅ Done",
    options: [.foreground] // foreground needed to sync state
)

let snooze15Action = UNNotificationAction(
    identifier: "SNOOZE_15",
    title: "⏱ Snooze 15m",
    options: []
)

let dismissAction = UNNotificationAction(
    identifier: "DISMISS",
    title: "Dismiss",
    options: [.destructive]
)

let badgerCategory = UNNotificationCategory(
    identifier: "BADGER",
    actions: [doneAction, snooze15Action, dismissAction],
    intentIdentifiers: [],
    options: []
)
```

Snooze actions should be dynamically configured based on AppSettings snooze durations. Register multiple categories if needed (BADGER_SHORT_SNOOZE, BADGER_LONG_SNOOZE).

### Notification Payload Design

Each notification's `userInfo` dictionary carries the data needed to handle any response without fetching from SwiftData:

```swift
content.userInfo = [
    "badgerId": badger.id.uuidString,
    "level": level.order,
    "title": badger.title,
    "sourceType": badger.sourceType.rawValue,
    "sourceIdentifier": badger.sourceIdentifier ?? ""
]
```

### Speak Text Implementation

Pre-render speech at Badger creation time:

```swift
func prerenderSpeech(text: String, badgerId: UUID) async -> String? {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = 0.45
    utterance.volume = 1.0

    // Render to audio file in app's documents directory
    // Use AVAudioEngine + AVSpeechSynthesizer offline render
    // Save as .caf file (Core Audio Format — required for notification sounds)
    // File must be < 30 seconds and < 5MB

    let filename = "speech-\(badgerId.uuidString).caf"
    // ... render and save
    return filename
}
```

The resulting `.caf` file is used as `UNNotificationSoundName` in the notification content. This plays even when the app is fully suspended.

---

## 11. Trigger Sources

### Manual (V1)

User creates a Badger directly in the app. Simplest path — sets title, optional notes, start time, and optionally overrides the default ladder.

### Apple Reminders via EventKit (V1)

**Setup:**

- User grants access to Reminders in Settings
- User selects which Reminder lists BadgerMe monitors
- BadgerMe polls for overdue, incomplete items

**Polling strategy:**

- On app foreground (ScenePhase change to `.active`)
- On BGAppRefreshTask wakeup (system-controlled, ~15-30 min)
- Deduplication: check `sourceIdentifier` against existing Badgers before creating

**Completion sync:**

- When user marks Badger Done, call `EventStore.save(reminder)` with `isCompleted = true`
- This updates the item in the system Reminders app

**Important limitation:** EventKit does not provide real-time change notifications for Reminders in a reliable, background-safe way. Polling is the correct approach.

### Webhook (V1, Power User)

See WebhookServer service above. User enables in Settings, copies their auth token, configures their automation tool (n8n, Home Assistant, etc.) to POST to `http://[device-tailscale-ip]:8765/badger`.

**Security considerations:**

- Token stored in Keychain, not UserDefaults
- Token regeneration option in Settings
- Listener only on local network interface (not exposed to internet directly)
- Rate limiting: max 10 requests per minute per IP

---

## 12. UI & Navigation Structure

### Navigation

BadgerMe uses `NavigationStack` (iOS 16+) with a tab bar for primary navigation.

```
TabView
├── Active Tab        → List of active + snoozed Badgers
├── History Tab       → Completed, dismissed, abandoned Badgers
└── Settings Tab      → All configuration
```

### Active Tab

```
Active Badgers (NavigationStack)
├── BadgerListView
│   ├── ActiveBadgerRow (per Badger)
│   │   ├── Title, time since started
│   │   ├── Current level indicator
│   │   └── Next escalation countdown
│   └── FAB: + New Badger
└── BadgerDetailView
    ├── Full escalation ladder visualization
    ├── Event timeline (when each level fired)
    ├── Done / Snooze / Dismiss inline actions
    └── Edit Badger
```

### New Badger Sheet

```
NewBadgerView (sheet)
├── Title field
├── Notes field (optional)
├── Start time picker (default: now)
├── Ladder picker
│   ├── Use Default
│   └── Custom (opens ladder editor)
└── Create button
```

### Settings Tab

```
SettingsView
├── Notifications
│   ├── Permission status + re-request button
│   └── Time Sensitive toggle + explanation
├── Default Escalation Ladder
│   └── LadderEditorView (full ladder configuration)
├── Snooze Options
│   └── Configurable snooze duration set
├── Reminders Integration
│   ├── Permission status
│   ├── List picker (multi-select from EKCalendar list)
│   └── Polling interval (foreground only / every 15m via background)
├── Webhook (Advanced)
│   ├── Enable toggle
│   ├── Port field
│   ├── Auth token display + regenerate
│   └── Test endpoint button
├── Nuclear Option
│   └── NuclearOptionPickerView
└── About / Version
```

### Ladder Editor

The ladder editor is a critical UI component. It must be:

- Easy to understand at a glance (each level is a card)
- Dragable to reorder levels
- Tappable to expand/edit a level's actions
- Clear about time gaps between levels

```
LadderEditorView
├── Level cards (reorderable list)
│   └── LevelCard
│       ├── Level number + wait duration
│       └── Action chips (Sound, Speak, Flash...)
│           └── Tap to expand action editor
├── + Add Level button
├── Nuclear Option picker (at bottom)
└── Save / Cancel
```

---

## 13. Watch App

### Scope

The Watch app is minimal — it's an acknowledgment surface, not a management interface. Users should not be expected to create or configure Badgers on Watch.

### Watch Notification Actions

When a Badger notification mirrors to Watch, the user sees:

- Title of the Badger
- Current level indicator
- Three actions: Done / Snooze / Dismiss

### Watch Complication (V1 — Optional)

A simple complication showing:

- Count of active Badgers
- Time until next escalation

Implemented as a `WidgetKit` complication (required for watchOS 7+).

### WatchConnectivity Implementation

Use `WCSession` for bidirectional messaging:

```swift
// Phone → Watch: send active Badger summary
session.sendMessage(["activeBadgers": encodedSummary], replyHandler: nil)

// Watch → Phone: send acknowledgment
session.sendMessage([
    "action": "done",
    "badgerId": badger.id.uuidString
], replyHandler: nil)
```

Handle messages on the phone side in `WatchConnectivityService`, route to `BadgerEngine`.

---

## 14. Settings & Configuration

### Default Escalation Ladder (Factory Default)

Ship with a sensible default that users can modify:

```
Level 1: Standard notification sound — wait 5 minutes
Level 2: Louder sound (custom) — wait 10 minutes
Level 3: Speak task title aloud — wait 15 minutes
Nuclear: Repeat Level 3 every 10 minutes
Max snooze count: 3 (after 3rd snooze, restart at Level 2 instead of Level 1)
```

### Named Ladder Presets

Ship with 3 built-in named ladders (user can add custom):

- **Gentle** — long waits, soft sounds, no speech
- **Default** — as above
- **Urgent** — short waits, loud sounds, speech at Level 2

### Sound Library

V1 sounds:

- System default notification sound
- 3–5 custom bundled sounds of increasing intensity
- Support for user-imported audio (copy to app's documents via Files)

All custom notification sounds must be `.caf` format, < 30 seconds.

---

## 15. Design Requirements

### Visual Design Principles

- **Native-first.** Use system components, SF Symbols, and Apple's spacing/typography conventions. Don't design against the grain of iOS.
- **Functional over decorative.** Every visual element should communicate state. Avoid animations that don't convey information.
- **Clarity under stress.** The app is used when the user is distracted or overwhelmed. Information hierarchy must be immediately readable.
- **Dark mode first.** Design for dark mode, verify light mode. Most use cases occur in low-light focus environments.

### Color Usage

- Escalation levels should have a visual temperature: cool (blue/green) → warm (yellow) → hot (orange/red)
- Active Badgers: accent color
- Snoozed Badgers: muted/secondary
- Completed Badgers: system green check, then gray
- Abandoned: system gray with strikethrough

### Typography

- SF Pro throughout (system default)
- Task titles: `.title3` or `.headline` — must be readable at a glance
- Level indicators: monospaced if showing countdown timers
- No custom fonts in V1 — reduces complexity, ensures accessibility compliance

### Accessibility

- Full VoiceOver support required — all interactive elements labeled
- Dynamic Type support required — no fixed font sizes
- Sufficient color contrast (WCAG AA minimum)
- Haptic feedback for all confirmation actions (use `UIImpactFeedbackGenerator`)
- Notification sounds must be paired with visual indicators (support for users with hearing impairments)

### HIG Compliance

- Follow Apple Human Interface Guidelines strictly in V1
- Use standard navigation patterns (no custom gesture recognizers on primary flows)
- Destructive actions require confirmation
- Settings use grouped `Form` layout

---

## 16. Pricing & Distribution

### Distribution

- App Store (primary)
- TestFlight for beta testing and personal use during development

### Pricing Model

**Free tier:**

- Unlimited manual Badgers
- Default escalation ladder (view-only editing)
- Apple Reminders integration (one list)
- Basic sounds
- Watch notification mirroring

**One-time purchase ("BadgerMe Pro"):**

- Custom escalation ladders (create, edit, name)
- Multiple Reminders list monitoring
- Webhook listener
- Custom sound import
- Named ladder presets
- Full audit history

**Pricing target:** $4.99 one-time. Competitive with useful utilities, not subscription-taxing a productivity tool.

**No subscription.** One-time purchase is the right model for a utility that runs locally with no backend service.

### App Store Metadata Notes

- Category: Productivity
- Age rating: 4+
- Privacy: No data collected, no accounts, no analytics (emphasize this — it's a differentiator)
- Keywords: reminders, notifications, focus, productivity, alerts, escalating, timer, task

---

## 17. Technical Requirements

### Minimum Deployment Target

- **iOS 17.0** — required for SwiftData
- **watchOS 10.0** — required for modern Watch notification actions

### Frameworks & Dependencies

**System frameworks only in V1 — no third-party dependencies.**

| Framework         | Purpose                                    |
| ----------------- | ------------------------------------------ |
| SwiftUI           | All UI                                     |
| SwiftData         | Persistence (Badger, Ladder, Event models) |
| UserNotifications | Scheduling and handling notifications      |
| EventKit          | Reminders integration                      |
| AVFoundation      | Speech synthesis, audio rendering          |
| WatchConnectivity | Phone ↔ Watch communication                |
| WidgetKit         | Watch complication                         |
| BackgroundTasks   | BGAppRefreshTask for Reminders polling     |
| Network           | Webhook listener (NWListener)              |
| Security          | Keychain for webhook auth token            |

**No third-party package dependencies.** This keeps the app auditable, reduces supply chain risk, and aligns with the privacy-first positioning.

### Xcode Project Structure

```
BadgerMe/
├── BadgerMeApp.swift              ← App entry point, service initialization
├── Models/
│   ├── Badger.swift
│   ├── EscalationLadder.swift
│   ├── EscalationLevel.swift
│   ├── BadgerEvent.swift
│   └── AppSettings.swift
├── Services/
│   ├── BadgerEngine.swift
│   ├── NotificationService.swift
│   ├── RemindersService.swift
│   ├── WebhookServer.swift
│   └── WatchConnectivityService.swift
├── Views/
│   ├── ActiveTab/
│   │   ├── BadgerListView.swift
│   │   ├── BadgerRowView.swift
│   │   └── BadgerDetailView.swift
│   ├── NewBadger/
│   │   └── NewBadgerView.swift
│   ├── History/
│   │   └── HistoryView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── LadderEditorView.swift
│   │   ├── LevelEditorView.swift
│   │   └── WebhookSettingsView.swift
│   └── Shared/
│       ├── LevelIndicatorView.swift
│       ├── CountdownView.swift
│       └── EscalationLadderPreview.swift
├── Resources/
│   ├── Sounds/                    ← Bundled .caf sound files
│   └── BadgerMe.entitlements
├── BadgerMe.xcodeproj
└── BadgerMeWatch/                 ← Watch app target
    ├── BadgerMeWatchApp.swift
    ├── NotificationController.swift
    └── ComplicationView.swift
```

### Entitlements Required

```xml
<!-- BadgerMe.entitlements -->
<dict>
    <!-- Time Sensitive notifications — no Apple approval needed -->
    <key>com.apple.developer.usernotifications.time-sensitive</key>
    <true/>

    <!-- EventKit Reminders access -->
    <!-- Declared via Info.plist NSRemindersUsageDescription -->

    <!-- No Critical Alerts — not pursing this entitlement in V1 -->
</dict>
```

### Info.plist Keys Required

```xml
<key>NSRemindersUsageDescription</key>
<string>BadgerMe monitors your selected Reminder lists to detect overdue tasks and begin badgering you about them.</string>

<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.badgerme.reminders-refresh</string>
</array>

<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
```

---

## 18. Developer Notes for Claude Code

These notes are intended to guide a Claude Code session working in Xcode with XcodeBuildMCP.

### Starting Point

1. Create a new Xcode project: iOS App, SwiftUI interface, SwiftData storage
2. Add a watchOS target immediately — easier to add at project creation than later
3. Set minimum deployment to iOS 17.0 / watchOS 10.0
4. Add entitlements file and configure Time Sensitive notifications capability in Xcode

### Build Order

Implement in this sequence to maintain a working build at each stage:

1. **Data models** — `Badger`, `EscalationLadder`, `EscalationLevel`, `BadgerEvent` with SwiftData `@Model`
2. **NotificationService skeleton** — permission request, category registration, basic scheduling
3. **BadgerEngine skeleton** — create Badger, schedule notifications, basic acknowledgment
4. **Active Tab UI** — list view, new Badger sheet, basic row display
5. **Notification response handling** — wire `UNUserNotificationCenterDelegate` through to BadgerEngine
6. **Ladder editor UI** — the most complex UI component; build iteratively
7. **Settings UI** — standard Form-based, relatively straightforward
8. **RemindersService** — EventKit access, polling, deduplication logic
9. **BGAppRefreshTask** — register and implement background Reminders polling
10. **Speech pre-rendering** — AVSpeechSynthesizer offline render to .caf
11. **WatchConnectivity** — service + Watch app target
12. **WebhookServer** — NWListener implementation, last because it's optional

### Known Complexity Points

**Notification scheduling with cancellation:**  
Each Badger's entire ladder must be scheduled as individual `UNNotificationRequest` objects upfront. Use a consistent naming convention: `"badger-\(badger.id.uuidString)-level-\(level.order)"`. Cancellation uses `removePendingNotificationRequests(withIdentifiers:)` with all IDs for that Badger.

**SwiftData + background contexts:**  
`ModelContext` is `@MainActor`. Background work (BGAppRefreshTask, webhook handler) must create a separate `ModelContext` from the `ModelContainer`. Pass `ModelContainer` through the environment and create task-scoped contexts as needed.

**EventKit access pattern:**  
`EKEventStore` authorization is per-entity-type. Request `.reminders` specifically. The `requestFullAccessToReminders()` async method is the current API (iOS 17+). Older `requestAccess(to:completion:)` is deprecated.

**AVSpeechSynthesizer offline render:**  
Offline rendering to an audio buffer (not real-time playback) requires `AVAudioEngine` with `AVSpeechSynthesizer.write(_:toBufferCallback:)`. The output is AVAudioPCMBuffer objects that must be concatenated and written to a `.caf` file. This is non-trivial — allocate time for this component. The resulting file must be placed in the app's Library/Sounds directory (not Documents) for `UNNotificationSound` to find it. Actually, for `UNNotificationSoundName`, the sound file must be in the app bundle or copied to the Library/Sounds directory of the app container. Test this carefully.

**Watch notification actions:**  
Actions defined in `UNNotificationCategory` on the phone automatically appear on the Watch for mirrored notifications. The Watch does not need separate category registration. However, the response is delivered on the phone via `UNUserNotificationCenterDelegate`, not on the Watch. The Watch app target only needs a `WKNotificationScene` or `WKUserNotificationHostingController` if displaying a custom Watch notification UI.

**Background task frequency:**  
`BGAppRefreshTask` frequency is controlled by iOS based on usage patterns. During development, simulate background tasks via LLDB: `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.badgerme.reminders-refresh"]`

### Testing Strategy

- Test notification scheduling/cancellation thoroughly in Simulator
- Use `UNUserNotificationCenter.current().getPendingNotificationRequests` to verify scheduled state
- Test acknowledgment from notification (don't just test from in-app)
- Test with Focus modes enabled on a real device
- Test Watch actions on a real Watch — Simulator is unreliable for WatchConnectivity
- Test BGAppRefreshTask via LLDB simulation

### SwiftData Schema Migration

If the data model changes during development, use `VersionedSchema` and `SchemaMigrationPlan`. Don't rely on automatic migration for breaking changes. Plan the V1 schema carefully and freeze it before TestFlight.

---

## 19. Open Questions

These require decisions before or during development:

1. **Snooze durations:** Should snooze options be fixed app-wide (from Settings) or configurable per notification action? Per-action requires dynamic category registration, which is more complex.

2. **Multiple active Badgers:** When multiple Badgers are active simultaneously, should their notifications be staggered to avoid simultaneous firing? Probably yes — add a small offset per Badger.

3. **Speech voice selection:** Should users be able to select a voice (Siri voices, if available) or just use the system default? V1: system default only.

4. **Webhook callback reliability:** If the user closes the app between receiving a webhook and acknowledging, can the callback URL be stored and POSTed later? Yes — store in Badger model, send on acknowledgment regardless of timing.

5. **Onboarding flow:** The app needs to request Notifications permission and explain the Time Sensitive escalation concept on first launch. Design a minimal 2–3 screen onboarding that explains the core concept and gets permissions in place.

6. **Badger limit:** Should there be a reasonable limit on simultaneous active Badgers? iOS limits total pending notification requests to 64. With a 4-level ladder per Badger, that's 16 concurrent active Badgers maximum. Surface this limit gracefully in the UI.

7. **Deletion behavior:** When a Badger is deleted, all pending notifications must be canceled. Confirm destructive delete with an alert.

8. **App icon:** The badger animal is a natural mascot. Consider a minimalist SF Symbol-based icon for V1 (no custom illustration overhead). The `figure.badminton` symbol doesn't work — use a geometric/abstract treatment.

---

_This specification is a living document. Update it as architectural decisions are made during development. Keep it in the Xcode project root as `BADGERME-SPEC.md` so Claude Code can reference it in future sessions._
