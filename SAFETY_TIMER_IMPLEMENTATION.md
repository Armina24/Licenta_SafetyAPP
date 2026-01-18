# Safety Timer (Dead Man's Switch) - Implementation Guide

## Overview
The Safety Timer is a "Dead Man's Switch" feature that provides protection for solo activities like jogging, traveling, or night work. Instead of immediately triggering SOS when internet is lost (causing false alarms), users set a timer and automatically receive alerts if they don't check in.

## Problem Solved
**Old System (No Internet Trigger)**:
```
✗ User enters elevator → Internet lost → Immediate SOS sent
✗ User goes through tunnel → Internet lost → Immediate SOS sent
✗ Too many false alarms = user disables the feature
```

**New System (Safety Timer)**:
```
✓ User sets "60-minute Safety Timer" before starting activity
✓ Timer counts down in background
✓ At 5 minutes, receives notification: "Are you OK?"
✓ User taps "I'm OK" to stop timer
✓ If timer expires (no check-in), then SOS triggers
✓ User can extend timer if needed
```

---

## Architecture

### 1. **SafetyTimerService** 
📄 `lib/services/safety_timer_service.dart`

Core logic for managing the safety timer.

#### Key Classes

**SafetyTimerState**
```dart
class SafetyTimerState {
  final bool isActive;              // Timer running?
  final int remainingSeconds;       // Time left
  final DateTime endTime;           // When expires
  final bool isCheckInWarning;      // < 5 minutes?
  
  String get remainingTimeFormatted; // "02:45" or "1:30:00"
}
```

**SafetyTimerEvent**
```dart
enum SafetyTimerEvent {
  timerStarted,         // User started timer
  timerExtended,        // User extended timer
  timerStopped,         // User stopped timer (safe)
  checkInNotification,  // 5 minutes remaining - ask if OK
  sosTriggered,         // Timer expired - SOS sent
}
```

#### API

```dart
// Initialize
await SafetyTimerService.instance.initialize(
  onTimerEvent: (event) { /* handle */ },
  onSosTriggered: () { /* handle */ },
);

// Start timer (15, 30, 60+ minutes)
await safetyTimer.startTimer(Duration(minutes: 30));

// Extend timer
await safetyTimer.extendTimer(Duration(minutes: 15));

// Stop timer (user is safe)
await safetyTimer.stopTimer();

// Check current state
final state = safetyTimer.getCurrentState();
final isActive = safetyTimer.isActive;

// Listen to state changes
safetyTimer.timerState.addListener(() {
  final newState = safetyTimer.getCurrentState();
});
```

#### Implementation Details

**Persistence**: Uses SharedPreferences to survive app restart
```dart
_keyTimerActive        // Is timer active?
_keyTimerEndTime       // Unix timestamp of expiration
_keyCheckInNotified    // When check-in notification shown
```

**Debouncing**: 
- Debounce duration between check-in notifications: 1 second polling
- Check-in warning triggered only once per timer session

**Automatic SOS**:
- When timer hits 0:00, automatically calls `EmergencyService.sendManualSos()`
- Works even without internet (uses SMS service)
- 3-second delay allows user to cancel if dialog shown

---

### 2. **SafetyTimerPage**
📄 `lib/ui/safety_timer_page.dart`

Main UI for the Safety Timer feature.

#### Features
- ✅ Preset timer buttons (15, 30, 60, 120 minutes)
- ✅ Large countdown display when timer active
- ✅ Color change warnings (red when < 5 minutes)
- ✅ "I'm OK" button to stop timer
- ✅ Quick extend buttons (+5, +15, +30 minutes)
- ✅ Educational cards explaining feature

#### UI States

**Inactive State** (no timer running):
```
┌─────────────────────────────┐
│   🛡️ Safety Timer          │
│   Dead Man's Switch         │
├─────────────────────────────┤
│                             │
│ [15 minutes - Quick jog]    │
│ [30 minutes - Short outing] │
│ [60 minutes - Travel]       │
│ [120 minutes - Long journey]│
│                             │
│ ℹ️ How it works:             │
│ 1. Set timer               │
│ 2. Counts down              │
│ 3. Check-in at 5 min        │
│ 4. Extend or stop           │
│ 5. Auto SOS if expired      │
└─────────────────────────────┘
```

**Active State** (timer counting down):
```
┌─────────────────────────────┐
│   🛡️ Safety Timer          │
│   Dead Man's Switch         │
├─────────────────────────────┤
│                             │
│        ⭕                  │
│      01:27:53               │ ← Large countdown
│                             │
│ [✅ I'm OK - Stop Timer]    │
│ [+5 min] [+15 min] [+30 min]│
│                             │
│ Auto SOS will trigger...    │
└─────────────────────────────┘
```

**Warning State** (< 5 minutes):
```
┌─────────────────────────────┐
│        ⚠️                  │
│      00:04:32               │ ← Red circle & text
│                             │
│ ⚠️ Less than 5 min remaining│
│                             │
│ [✅ I'm OK - Stop Timer]    │
│ [+5 min] [+15 min] [+30 min]│
│                             │
│ SENDING SOON                │
└─────────────────────────────┘
```

---

### 3. **SafetyTimerCheckInDialog**
📄 `lib/ui/safety_timer_checkin_dialog.dart`

Modal dialog shown when 5 minutes remain on timer.

#### Features
- ✅ "Are You OK?" question
- ✅ Countdown display
- ✅ "I'm OK - Stop Timer" button (green)
- ✅ "+5 min" and "+15 min" extend buttons
- ✅ "I Need Help Now - Send SOS" button (red)
- ✅ Auto-dismissal if user doesn't respond

#### Dialog States

**Normal Countdown**:
```
┌──────────────────────────┐
│ 🤔 Are You OK?          │
│ Timer expiring in 04:53  │
├──────────────────────────┤
│                          │
│ [✅ I'm OK - Stop]       │
│ [+5 min] [+15 min]       │
│ [🆘 I Need Help - SOS]   │
│                          │
│ ℹ️ If no response, SOS   │
│    sends automatically   │
└──────────────────────────┘
```

---

## User Flow Diagram

```
START
  ↓
User opens Safety Timer
  ↓
┌──────────────────┐
│ Select Duration  │
│ (15/30/60/120m)  │
└──────────────────┘
  ↓
Timer starts
  ↓
┌─────────────────────────┐
│   Timer counting down    │
│  (background process)   │
└─────────────────────────┘
  ↓
[Multiple possible outcomes]
  ↙          ↓          ↖
  
A) User taps "Stop"    B) 5 min before        C) Timer
   within 5 min          expiry                 expires
   ↓                     ↓                      ↓
   ✅ Timer             [Check-In Dialog]     🚨 Auto SOS
      stopped           ↙         ↖            sent
      "I'm OK"          |         |
      logged             |         |
                    ┌────┴────┬────┴────┐
                    │         │         │
                 "I'm OK"   Extend   "Need Help"
                    ↓         ↓         ↓
                  ✅       Reset    🚨 SOS
                  Stop    timer     Now
```

---

## Integration with Other Services

### Emergency Service
```dart
// When SOS triggered, calls:
await EmergencyService.instance.sendManualSos();
```

### Connectivity Service
- ✅ Works WITHOUT internet (uses SMS fallback)
- ✅ No longer triggers on "No Internet" connectivity change

### Notification Service
```dart
// Shows check-in notification at 5 minutes
await NotificationService.instance.showSafetyTimerCheckIn();
```

### Background Service
- Timer persists in background
- Survives app termination
- Restores on app restart

---

## Configuration

### Preset Durations
Currently hardcoded presets:
- 15 minutes (Quick jog, errand)
- 30 minutes (Short outing)
- 60 minutes (Travel, hiking)
- 120 minutes (Long journey, commute)

**To add custom durations**, modify `SafetyTimerPage._buildTimerButton()`:
```dart
_startTimer(45),  // Add 45-minute option
```

### Check-In Warning
```dart
static const Duration _checkInWarningDuration = Duration(minutes: 5);
```
Change to trigger notification earlier/later.

### SOS Delay
```dart
static const Duration _sosDelay = Duration(seconds: 3);
```
Delay before sending SOS (allows user to cancel if UI shown).

---

## Data Persistence

### SharedPreferences Keys
```dart
'safety_timer_active'        // bool - Is timer running?
'safety_timer_end_time'      // int  - Unix milliseconds
'safety_timer_check_in_notified' // int - When notified
```

### Restore on App Restart
```dart
// On app startup, SafetyTimerService.initialize() restores:
if (isActive && endTime < now) {
  // Timer expired while app was closed
  await _triggerSos();
} else if (isActive) {
  // Resume existing timer
  _startTimerTick();
}
```

---

## API Endpoints / Integrations

None required. All local device operations.

---

## Testing Scenarios

### Scenario 1: Normal Timer Completion
1. Set 1-minute timer (for testing)
2. Close app
3. Wait 1 minute
4. Reopen app
5. **Expected**: SOS dialog shown automatically

### Scenario 2: Check-In Response
1. Set 2-minute timer
2. Wait 1:55 (55 seconds before expiry)
3. Dialog appears: "Are you OK?"
4. Tap "+5 min"
5. **Expected**: Timer reset to 5:00

### Scenario 3: Emergency Override
1. Set timer
2. Dialog appears at 5 min remaining
3. Tap "I Need Help Now"
4. **Expected**: SOS sent immediately (no timer wait)

### Scenario 4: App Restart
1. Set 60-minute timer
2. Kill app
3. Restart app
4. **Expected**: Timer continues from where it left off

### Scenario 5: No Internet SOS
1. Set timer
2. Disable internet
3. Wait for timer to expire
4. **Expected**: SMS SOS sent (no internet needed)

---

## Error Handling

**Device doesn't support notifications**: 
- Check-in dialog still works via app UI

**SharedPreferences unavailable**:
- Timer lost on app restart
- Recovery: User restarts timer

**Emergency service unavailable**:
- Timer still triggers SOS call
- Fallback to SMS service

---

## User Guide

### For Joggers
```
1. Start jogging
2. Open Safety App → Safety Timer
3. Tap "15 minutes"
4. App counts down
5. After 15 min: Check-in dialog
6. If you're home, tap "I'm OK - Stop"
7. Parents notified you're safe
```

### For Solo Travelers
```
1. Start long drive
2. Set "60 minutes" timer
3. Drive with app in background
4. Every 55 minutes: Get notification
5. Tap "+15 min" to extend
6. If you crash/incapacitated: SOS auto-triggers
```

### For Night Workers
```
1. Start night shift
2. Set "480 minutes" (8 hours)
3. Work normally
4. At end of shift, stop timer
5. If something happens, SOS auto-sends
```

---

## Security & Privacy

🔒 **Data Stored Locally**:
- Timer data only in SharedPreferences
- No cloud sync
- Not uploaded to servers
- User location not tracked during timer

📍 **On SOS Trigger**:
- User location sent to emergency contacts
- Current timestamp logged
- None of this violates privacy (expected for emergency)

---

## Future Enhancements

- 🗺️ **Route sharing**: Share route with trusted contacts during timer
- 📍 **Geofence-based**: Auto-extend if still moving, auto-SOS if stationary
- 👥 **Shared timers**: Multiple users in group, any can check-in
- 📊 **Analytics**: Track activity patterns, suggest timer durations
- 🔊 **Audio alert**: Play siren sound during check-in countdown
- 🎯 **Predictive SOS**: ML model predicts if user needs help

---

## Summary

The Safety Timer feature:
1. ✅ Eliminates false alarms from "no internet" detection
2. ✅ Gives users full control (stop/extend anytime)
3. ✅ Provides automatic protection (SOS if not dismissed)
4. ✅ Works offline (SMS fallback)
5. ✅ Persists across app restarts
6. ✅ Professional, intuitive UI
7. ✅ Production-ready

Perfect for solo activities, travel, and peace of mind! 🛡️
