# Hyper-Realistic Call Simulator Implementation

## Overview
The Smart Fake Call feature has been upgraded to a **Hyper-Realistic Call Simulator** with two distinct screens and sophisticated hardware integration.

## Architecture Flow
```
User Selects Scenario (Social/Safety)
           ↓
SmartFakeCallScreen (router)
           ↓
IncomingCallScreen (ringing state)
           ↓
User Accepts/Declines
           ↓
ActiveCallScreen (active call with Smart VAD)
```

---

## Part 1: IncomingCallScreen

### Location
[lib/features/fake_call/incoming_call_screen.dart](lib/features/fake_call/incoming_call_screen.dart)

### Features

#### 1.1 UI Components
- **Gradient Background**: Theme-based (Teal for Social, Deep Orange for Safety)
- **Pulsing Avatar**: Animated avatar with smooth scale animation
- **Caller Information**: 
  - Caller name (Mama/Safety Alert)
  - Caller type (Mobile/Emergency)
  - Ringer mode indicator (Sound & Vibration / Vibrate Only / Silent)
- **Action Buttons**: Accept (green) and Decline (red) with smooth slide animation
- **Blur Effects**: Professional iOS/Android-like incoming call UI

#### 1.2 Ringer Mode Detection (Critical)
The app detects the device's **Ringer Mode** and responds accordingly:

| Ringer Mode | Behavior |
|---|---|
| **Normal** | Plays `assets/sounds/ringtone.mp3` (looping) + Vibration pattern (1s wait, 0.5s vibrate) |
| **Vibrate** | Vibration pattern only, no sound |
| **Silent** | UI updates only, no sound or vibration |

**Implementation**:
- Uses `RingerModeService` (Dart) with native Android channel
- Calls `AudioManager.ringerMode` on Android
- Values: 0 (Silent), 1 (Vibrate), 2 (Normal)

#### 1.3 Audio Handling
- Uses `audioplayers` package for ringtone playback
- Respects ringer mode during initialization
- Stops immediately when user accepts or declines

#### 1.4 Haptic Feedback
- Vibration pattern: 1 second wait, then 500ms vibration, repeating
- Brief haptic pulse on acceptance
- Uses `vibration` package for cross-platform support

#### 1.5 User Actions
- **Accept**: Stops ringtone/vibration and navigates to `ActiveCallScreen`
- **Decline**: Stops all audio/vibration and returns to home
- **Back Button**: Triggers decline action

---

## Part 2: ActiveCallScreen

### Location
[lib/features/fake_call/active_call_screen.dart](lib/features/fake_call/active_call_screen.dart)

### Features

#### 2.1 Audio Routing (Speakerphone)
**Control**: Speaker button in the control panel

| State | Behavior |
|---|---|
| **Earpiece (Default)** | Audio plays through ear speaker |
| **Speaker** | Audio plays through loudspeaker |

**Implementation**:
- Uses `audio_session` package for audio session management
- `AudioRoutingService` handles routing logic
- Configured for voice communication (AVAudioSessionCategoryPlayAndRecord)

#### 2.2 Mute Button
**Control**: Mute/Unmute toggle button

| State | Behavior |
|---|---|
| **Unmuted** | VAD (Voice Activity Detection) is active and monitoring |
| **Muted** | VAD pauses; no random AI responses triggered |

**VAD Logic**:
- When muted, `_isVadActive` is set to false
- Prevents the AI assistant from generating responses based on background noise
- Shows VAD status indicator: "VAD: Active" or "VAD: Paused"

#### 2.3 Keypad Button
**Control**: Opens bottom sheet modal with DTMF keypad

**Features**:
- Numeric grid (1-9, 0, *, #)
- Visual feedback on press
- Haptic vibration (50ms) on each key
- Optional: DTMF tone playback (prepared for future implementation)

#### 2.4 Call Duration Timer
- Starts immediately when `ActiveCallScreen` initializes
- Format: MM:SS (00:00)
- Updates every second
- Displayed in top-right corner

#### 2.5 Call Status Indicator
- Green dot + "In Call" text in top-left
- Shows real-time call state

#### 2.6 Smart VAD Integration
**Framework Ready**:
- VAD check timer runs every 100ms
- Pauses when user mutes (critical for preventing false AI triggers)
- Prepared for real-time audio analysis integration
- Status indicator shows: "VAD: Active" or "VAD: Paused"

#### 2.7 End Call Button
- Red button at bottom
- Stops all audio and timers
- Navigates to call-ended confirmation screen

---

## Part 3: SmartFakeCallScreen (Router)

### Location
[lib/features/fake_call/smart_fake_call_screen.dart](lib/features/fake_call/smart_fake_call_screen.dart)

### Behavior
- Acts as a router/entry point
- Immediately navigates to `IncomingCallScreen` on initialization
- Shows brief loading state during transition
- Ensures seamless flow from scenario selection to incoming call

---

## Supporting Services

### RingerModeService
**Location**: [lib/services/ringer_mode_service.dart](lib/services/ringer_mode_service.dart)

```dart
enum RingerMode { normal, vibrate, silent }

// Main method
Future<RingerMode> getRingerMode()
```

**Methods**:
- `getRingerMode()`: Returns current ringer mode
- `isSilentMode()`: Boolean check for silent mode
- `isVibrateMode()`: Boolean check for vibrate mode
- `isNormalMode()`: Boolean check for normal mode

**Platform Channel**: `com.safety_app/ringer_mode`

---

### AudioRoutingService
**Location**: [lib/services/audio_routing_service.dart](lib/services/audio_routing_service.dart)

```dart
class AudioRoutingService {
  Future<void> initializeCallAudioSession()
  Future<void> enableSpeaker()
  Future<void> disableSpeaker()
  Future<void> toggleSpeaker()
  bool get isSpeakerEnabled
}
```

**Features**:
- Singleton pattern for global audio routing control
- Initializes audio session with call configuration
- Handles speaker/earpiece switching
- Logs all state changes

---

## Android Integration

### MainActivity.kt Updates
**File**: [android/app/src/main/kotlin/com/example/safety_app/MainActivity.kt](android/app/src/main/kotlin/com/example/safety_app/MainActivity.kt)

**New Method Channel**:
```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.safety_app/ringer_mode")
  .setMethodCallHandler { call, result ->
    when (call.method) {
      "getRingerMode" -> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        result.success(audioManager.ringerMode)
        // 0 = SILENT, 1 = VIBRATE, 2 = NORMAL
      }
    }
  }
```

### AndroidManifest.xml Updates
**File**: [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

**New Permission**:
```xml
<uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
```

This permission allows reading the ringer mode on Android 5.1+.

---

## Packages Added

| Package | Version | Purpose |
|---|---|---|
| `audioplayers` | ^6.1.0 | Audio playback with routing support |
| `audio_session` | ^0.1.18 | Audio session configuration for calls |
| `flutter_ringer_mode` | ^0.1.2 | Alternative ringer mode detection (optional) |

**Note**: `vibration` package was already present in dependencies.

---

## Asset Requirements

Ensure these audio files exist:
- `assets/sounds/ringtone.mp3` - Standard phone ringtone
- `assets/sounds/social_1.mp3` - Social scenario conversation (optional)
- `assets/sounds/social_2.mp3` - Social scenario conversation (optional)
- `assets/sounds/safety_1.mp3` - Safety scenario conversation (optional)
- `assets/sounds/safety_2.mp3` - Safety scenario conversation (optional)

---

## User Flow

### Scenario 1: Normal Ringer Mode
1. User selects Social/Safety scenario
2. `SmartFakeCallScreen` routes to `IncomingCallScreen`
3. Ringtone plays + vibration pattern starts
4. User sees "With sound and vibration" indicator
5. User taps Accept
6. Transitions to `ActiveCallScreen`
7. User can control Mute, Speaker, Keypad, Timer

### Scenario 2: Vibrate Mode
1. User selects Social/Safety scenario
2. `SmartFakeCallScreen` routes to `IncomingCallScreen`
3. Only vibration pattern plays (no sound)
4. User sees "Vibrate only" indicator
5. User taps Accept
6. Transitions to `ActiveCallScreen`

### Scenario 3: Silent Mode
1. User selects Social/Safety scenario
2. `SmartFakeCallScreen` routes to `IncomingCallScreen`
3. No sound or vibration
4. User sees "Silent mode" indicator
5. UI animations still play (visual feedback)
6. User taps Accept
7. Transitions to `ActiveCallScreen`

---

## Smart VAD (Voice Activity Detection) Integration

### Current State
- Framework prepared for real-time audio analysis
- VAD check timer: 100ms interval
- Pause mechanism: Mute button disables VAD

### Future Integration
To enable real-time VAD with your audio analysis service:

1. **In `ActiveCallScreen._simulateVadDetection()`**:
   ```dart
   void _simulateVadDetection() {
     // Replace with actual audio analysis
     // Example: analyzer.analyzeAudioFrame(audioData);
     // if (voiceDetected) { /* trigger AI response */ }
   }
   ```

2. **Connect to your YAMNet/TensorFlow audio analysis**:
   - Hook into `flutter_audio_capture` stream
   - Analyze every frame with your model
   - Trigger AI responses only when VAD is active AND user is unmuted

---

## Testing Checklist

- [ ] Test ringer mode detection on different Android versions
- [ ] Verify vibration patterns on various devices
- [ ] Test speaker/earpiece switching
- [ ] Test mute button VAD pause logic
- [ ] Verify keypad modal opens/closes correctly
- [ ] Test call timer accuracy
- [ ] Verify seamless transition from Incoming to Active
- [ ] Test call-ended navigation flow
- [ ] Test back button behavior on Incoming screen
- [ ] Verify audio stops completely on decline/end

---

## Known Limitations

1. **DTMF Tone Playback**: Prepared but not implemented (tone sounds on keypad)
2. **Audio Analysis**: VAD runs as framework; integrate real audio analysis
3. **iOS Support**: Platform-specific audio routing may require iOS implementation
4. **Accessibility**: Consider adding accessibility labels to all buttons

---

## Next Steps

1. **Test on physical Android device** with different ringer modes
2. **Integrate real-time audio analysis** with YAMNet for actual VAD
3. **Implement DTMF tones** for keypad feedback (optional)
4. **Add iOS support** if needed (similar pattern channel approach)
5. **Localize ringer mode detection** for other platforms if required

