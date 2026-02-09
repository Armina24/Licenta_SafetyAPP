# Installation & Setup Guide

## Step 1: Download New Packages

Run the following command in your project root to fetch and install the new packages:

```bash
flutter pub get
```

This will download and integrate:
- `audioplayers` - Audio playback with routing support
- `audio_session` - Audio session configuration
- `flutter_ringer_mode` - Alternative ringer mode detection

## Step 2: Android Configuration (Already Done)

The Android platform channel has been configured in:
- [MainActivity.kt](android/app/src/main/kotlin/com/example/safety_app/MainActivity.kt)
- [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

The `ACCESS_NOTIFICATION_POLICY` permission has been added to read ringer mode.

## Step 3: Verify Asset Files

Ensure these audio files exist in your `assets/sounds/` directory:
- `ringtone.mp3` (required)
- `social_1.mp3` (optional)
- `social_2.mp3` (optional)
- `safety_1.mp3` (optional)
- `safety_2.mp3` (optional)

If using placeholder audio, ensure `pubspec.yaml` includes:
```yaml
flutter:
  assets:
    - assets/sounds/
```

## Step 4: Run Your App

```bash
flutter run
```

## Step 5: Test the Features

### Test Incoming Call Screen:
1. Navigate to Fake Call feature
2. Select a scenario (Social or Safety)
3. Verify ringer mode is detected correctly
4. Test with different device ringer modes:
   - Normal: Should play sound + vibrate
   - Vibrate: Should vibrate only
   - Silent: Should show UI only

### Test Active Call Screen:
1. Accept the incoming call
2. Test mute button (check VAD status indicator)
3. Test speaker button (toggle audio output)
4. Test keypad button (verify modal opens)
5. Verify call timer counts correctly
6. Test end call button

## Troubleshooting

### Issue: "Target of URI doesn't exist" error after `flutter pub get`

**Solution**: The error should disappear after running `flutter pub get`. If it persists:
1. Clean the build: `flutter clean`
2. Get packages again: `flutter pub get`
3. Rebuild: `flutter run`

### Issue: Ringer mode always returns "Normal"

**Possible causes**:
1. Emulator may not support ringer mode detection properly
2. Test on a physical device for accurate ringer mode detection
3. Check that `ACCESS_NOTIFICATION_POLICY` permission is granted

### Issue: Audio doesn't play

**Possible causes**:
1. Asset files don't exist at `assets/sounds/ringtone.mp3`
2. Audio volume is muted
3. Check device ringer mode
4. Review logs: `flutter logs`

### Issue: Vibration doesn't work

**Possible causes**:
1. Device doesn't support vibration
2. Vibration is disabled in device settings
3. App doesn't have vibration permission (already included in manifest)

## Next: Integration with Voice Detection

To connect the Smart VAD system to your audio analysis:

1. **Get audio stream from device**:
   - Use `flutter_audio_capture` (already in pubspec)
   - Or hook into `AudioPlayer` output stream

2. **Analyze audio frames**:
   - Feed frames to your YAMNet/TensorFlow model
   - Detect voice activity

3. **Update VAD state in ActiveCallScreen**:
   - When voice detected and user unmuted: trigger AI response
   - When muted: pause analysis
   - Respect VAD pause state

See [HYPER_REALISTIC_CALL_SIMULATOR.md](HYPER_REALISTIC_CALL_SIMULATOR.md) for more details on Smart VAD integration.

