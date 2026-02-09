# Smart Fake Call - Audio Setup Guide

## Required Directory Structure

Create the following directory and add your audio files:

```
assets/
└── sounds/
    ├── ringtone.mp3      # Generic phone ringtone
    ├── social_1.mp3      # Social conversation audio #1
    ├── social_2.mp3      # Social conversation audio #2
    ├── safety_1.mp3      # Safety conversation audio #1
    └── safety_2.mp3      # Safety conversation audio #2
```

## Audio File Specifications

### ringtone.mp3
- **Purpose**: Plays during incoming call (looped)
- **Duration**: 5-10 seconds
- **Format**: MP3
- **Suggested**: Standard phone ringtone sound
- **Example Sources**: 
  - https://freesound.org (search: "phone ringtone")
  - https://pixabay.com/sound-effects/search/ringtone/

### social_1.mp3 & social_2.mp3
- **Purpose**: Conversation audio for Social scenario
- **Caller Name Display**: "Mama"
- **Context**: Escape awkward meetings/situations
- **Duration**: 30-60 seconds
- **Content Suggestions**:
  - Casual conversation
  - "Hi, are you free? Can you call me back?"
  - "Just checking in, when will you be home?"
  - Light background noise (home environment)

### safety_1.mp3 & safety_2.mp3
- **Purpose**: Conversation audio for Safety scenario
- **Caller Name Display**: "Safety"
- **Context**: Emergency/unsafe situation
- **Duration**: 20-40 seconds
- **Content Suggestions**:
  - Urgent but calm tone
  - "Hey, where are you? We're waiting for you."
  - "Are you coming? Call me when you get this."
  - Professional/concerned tone

## Adding Files to Your Project

1. **Create Directory** (if not exists):
   ```bash
   mkdir -p assets/sounds
   ```

2. **Copy Audio Files**:
   - Place all 5 MP3 files in `assets/sounds/`

3. **Verify pubspec.yaml**:
   ```yaml
   flutter:
     assets:
       - assets/sounds/
   ```

4. **Run Flutter Commands**:
   ```bash
   flutter pub get
   flutter clean
   flutter run
   ```

## Quick Test (Without Audio)

If you want to test the feature without audio files:

1. The app will log errors but continue to work
2. UI and animations will function normally
3. Only audio playback will be skipped
4. Error messages in debug console: "Error playing ringtone: ..."

## Audio Creation Options

### Option 1: Text-to-Speech (TTS)
Use online TTS services to generate conversation audio:
- https://ttsmaker.com/
- https://www.naturalreaders.com/online/
- Google Cloud Text-to-Speech

### Option 2: Record Your Own
- Use a voice recorder app
- Record casual conversations
- Edit with Audacity (free): https://www.audacityteam.org/

### Option 3: Use Royalty-Free Audio
- Pixabay: https://pixabay.com/sound-effects/
- Freesound: https://freesound.org/
- BBC Sound Effects: https://sound-effects.bbcrewind.co.uk/

### Option 4: Professional Voice Actor
- Fiverr: https://www.fiverr.com/
- Search for "voice actor" or "voice over"

## File Format Conversion

If you have audio in other formats (WAV, M4A, etc.):

### Using FFmpeg (Command Line):
```bash
# Install FFmpeg first: https://ffmpeg.org/download.html

# Convert WAV to MP3
ffmpeg -i input.wav -codec:a libmp3lame -qscale:a 2 output.mp3

# Convert M4A to MP3
ffmpeg -i input.m4a -codec:a libmp3lame -qscale:a 2 output.mp3
```

### Using Online Converter:
- https://cloudconvert.com/
- https://online-audio-converter.com/

## Testing Audio

After adding files, test each scenario:

1. **Launch App**
2. **Tap "Smart Fake Call"**
3. **Select "Social"** → Should play ringtone, then social audio
4. **Go Back**
5. **Select "Safety"** → Should play ringtone, then safety audio

## Troubleshooting

### Audio Not Playing?
- ✅ Check files are in `assets/sounds/` directory
- ✅ File names match exactly (case-sensitive)
- ✅ Run `flutter clean` and `flutter pub get`
- ✅ Check debug console for error messages

### Wrong Audio Playing?
- ✅ Verify file names: social_1.mp3, not Social_1.mp3
- ✅ Clear app data and reinstall

### Audio Cuts Off?
- ✅ Ensure MP3 files aren't corrupted
- ✅ Try re-encoding with FFmpeg

## Example Audio Scripts

### Social Scenario Example:
```
"Hi sweetheart, are you busy? Can we talk for a minute? 
I wanted to ask you about dinner plans tonight. 
Let me know when you're free, okay? Love you!"
```

### Safety Scenario Example:
```
"Hey, I've been trying to reach you. Where are you right now? 
We need to talk about something urgent. Can you call me back 
as soon as you get this? Thanks."
```

---

**Need Help?** Check the main documentation: `SMART_FAKE_CALL_IMPLEMENTATION.md`
