# Safety Timer Integration Guide

## Routes Configuration

To enable the Safety Timer page in your app, add the following route to your `main.dart` or routing configuration:

### In main.dart (MaterialApp routes)

```dart
import 'package:safety_app/ui/safety_timer_page.dart';

MaterialApp(
  // ... other config ...
  routes: {
    '/home': (context) => const HomePage(),
    '/profile': (context) => const ProfilePage(),
    '/contacts': (context) => const ContactsPage(),
    '/map': (context) => const MapPage(),
    '/settings': (context) => const SettingsPage(),
    '/soundMonitor': (context) => const SoundMonitorPage(),
    '/safetyTimer': (context) => const SafetyTimerPage(),  // ← ADD THIS
    // ... other routes ...
  },
)
```

## Service Initialization

The SafetyTimerService should be initialized early in your app (typically in `main()` or in HomePage's `initState`):

```dart
// In main.dart before runApp()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize all services
  await EmergencyService.instance.initialize();
  
  await SafetyTimerService.instance.initialize(
    onTimerEvent: (event) {
      print('Safety Timer Event: $event');
    },
    onSosTriggered: () {
      print('Safety Timer expired - SOS triggered');
    },
  );
  
  runApp(const SafetyApp());
}
```

## Navigation from HomePage

The Safety Timer card is already added to the HomePage dashboard. When tapped, it navigates to the Safety Timer page:

```dart
onTap: () {
  Navigator.pushNamed(context, '/safetyTimer');
}
```

## Notification Integration (Optional)

To show notifications when check-in is triggered, integrate with your NotificationService:

```dart
// In SafetyTimerService._startTimerTick(), when check-in triggered:

if (remaining <= _checkInWarningDuration) {
  if (_lastCheckInNotificationTime == null) {
    _lastCheckInNotificationTime = now;
    
    // Show notification
    await NotificationService.instance.showCheckInNotification(
      title: 'Are you OK?',
      body: 'Your safety timer is about to expire',
      payload: 'safety_timer_check_in',
    );
  }
}
```

## Push Notifications with Tap Handler

For full integration with push notifications, you can handle taps:

```dart
// In your notification service listener:

_firebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  if (message.data['type'] == 'safety_timer_check_in') {
    showDialog(
      context: context,
      builder: (context) => SafetyTimerCheckInDialog(
        remainingSeconds: safetyTimerService.getCurrentState()?.remainingSeconds ?? 0,
        onStopTimer: () => safetyTimerService.stopTimer(),
        onExtend5: () => safetyTimerService.extendTimer(Duration(minutes: 5)),
        onExtend15: () => safetyTimerService.extendTimer(Duration(minutes: 15)),
        onSos: () => emergencyService.sendManualSos(),
      ),
    );
  }
});
```

## Files to Import

```dart
// In HomePage
import 'services/safety_timer_service.dart';

// In SafetyTimerPage
import '../services/safety_timer_service.dart';
import '../ui/safety_timer_checkin_dialog.dart';
```

## Complete Integration Example

Here's a minimal example of full integration:

```dart
// main.dart
import 'services/safety_timer_service.dart';
import 'ui/safety_timer_page.dart';
import 'ui/safety_timer_checkin_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Safety Timer Service
  await SafetyTimerService.instance.initialize(
    onTimerEvent: (event) {
      print('📱 Timer Event: $event');
    },
    onSosTriggered: () {
      print('🚨 Timer SOS triggered');
    },
  );
  
  runApp(const SafetyApp());
}

// In HomePage or main app routing:
MaterialApp(
  routes: {
    '/safetyTimer': (context) => const SafetyTimerPage(),
  },
)
```

## Testing the Integration

1. **Start a timer**
   ```
   Open app → Home → Safety Timer card → Select 15 minutes
   ```

2. **Monitor countdown**
   ```
   Watch the timer count down in real-time
   ```

3. **Test check-in notification (at 5 minutes)**
   ```
   Dialog should appear asking "Are you OK?"
   ```

4. **Test extension**
   ```
   Tap "+5 min" → Timer should add 5 minutes
   ```

5. **Test stop**
   ```
   Tap "I'm OK - Stop Timer" → Timer should clear
   ```

6. **Test auto SOS**
   ```
   Set 1-minute timer → Wait → SOS should trigger automatically
   ```

7. **Test app restart**
   ```
   Start timer → Kill app → Restart → Timer should continue
   ```

## Troubleshooting

### Timer doesn't persist after app restart
- Check that SharedPreferences is properly initialized
- Verify the `initialize()` method is called on app startup

### Check-in notification not showing
- Ensure NotificationService is integrated
- Check notification permissions on device
- Verify 5-minute warning duration in SafetyTimerService config

### SOS doesn't trigger
- Verify EmergencyService.sendManualSos() is available
- Check that emergency contacts are configured
- Test with internet disabled (SMS fallback should work)

### Timer state not updating UI
- Ensure setState() or ValueNotifier listeners are attached
- Check that _onTimerStateChanged() is called properly
- Verify TimerState ValueNotifier is being updated

---

## That's it! 🎉

The Safety Timer feature is now fully integrated into your safety app. Users can set timers for their activities and get automatic SOS protection if they don't check in.
