# Smart Fake Call - Feature Flow Diagram

## User Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         HOME PAGE                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         [Smart Fake Call Button]                   │    │
│  │         📞 Smart Fake Call                         │    │
│  └────────────────────────────────────────────────────┘    │
│                            │                                 │
└────────────────────────────┼─────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   FAKE CALL MENU SCREEN                     │
│                   Choose Your Scenario                      │
│                                                              │
│  ┌──────────────────────────┐  ┌──────────────────────────┐│
│  │    🏢 SOCIAL MODE        │  │   🛡️ SAFETY MODE         ││
│  │    ┌──────────┐          │  │   ┌──────────┐           ││
│  │    │  ☕      │ Teal     │  │   │  🛡️     │ Orange    ││
│  │    └──────────┘          │  │   └──────────┘           ││
│  │  Escape awkward          │  │  Get help in             ││
│  │  meetings                │  │  unsafe areas            ││
│  └──────────────────────────┘  └──────────────────────────┘│
│              │                              │                │
└──────────────┼──────────────────────────────┼────────────────┘
               │                              │
               ▼                              ▼
        Social Scenario                Safety Scenario
               │                              │
               └──────────────┬───────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               SMART FAKE CALL SCREEN                        │
│                                                              │
│  State 1: INCOMING CALL                                     │
│  ┌────────────────────────────────────────────────────┐    │
│  │                  📱 Incoming Call                   │    │
│  │                                                     │    │
│  │              ┌─────────────┐                       │    │
│  │              │   (pulse)   │  ← Animated           │    │
│  │              │   👤 / 🛡️  │  ← Icon based         │    │
│  │              │             │     on scenario       │    │
│  │              └─────────────┘                       │    │
│  │                                                     │    │
│  │              Mama / Safety  ← Name based           │    │
│  │                               on scenario          │    │
│  │              Mobile / Emergency Contact            │    │
│  │                                                     │    │
│  │    🔴 Decline          ✅ Accept                   │    │
│  │                                                     │    │
│  │    [Ringtone Playing in Loop]                      │    │
│  └────────────────────────────────────────────────────┘    │
│                              │                              │
│                              │ User taps Accept             │
│                              ▼                              │
│  State 2: ACTIVE CALL                                       │
│  ┌────────────────────────────────────────────────────┐    │
│  │                  📱 In Call                        │    │
│  │                  ⏱️ 00:23                          │    │
│  │                                                     │    │
│  │              ┌─────────────┐                       │    │
│  │              │             │                       │    │
│  │              │   👤 / 🛡️  │  ← Static            │    │
│  │              │             │                       │    │
│  │              └─────────────┘                       │    │
│  │                                                     │    │
│  │              Mama / Safety                         │    │
│  │              Mobile / Emergency Contact            │    │
│  │                                                     │    │
│  │    🔇 Mute    📟 Keypad    🔊 Speaker             │    │
│  │                                                     │    │
│  │              🔴 End Call                           │    │
│  │                                                     │    │
│  │    [Conversation Audio Playing]                    │    │
│  └────────────────────────────────────────────────────┘    │
│                              │                              │
│                              │ User taps End Call           │
│                              ▼                              │
│                        Back to Previous Screen              │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    FakeCallScenario Enum                    │
│                    ┌──────────┬──────────┐                  │
│                    │  social  │  safety  │                  │
│                    └──────────┴──────────┘                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              SmartFakeCallScreen (receives)                 │
│                    scenario: FakeCallScenario               │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  initState() {                                     │    │
│  │    if (scenario == social) {                       │    │
│  │      _currentAudioList = _socialAudios             │    │
│  │      // ['social_1.mp3', 'social_2.mp3']          │    │
│  │    } else {                                        │    │
│  │      _currentAudioList = _safetyAudios             │    │
│  │      // ['safety_1.mp3', 'safety_2.mp3']          │    │
│  │    }                                               │    │
│  │  }                                                 │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  _getCallerName() {                                │    │
│  │    return scenario == social                       │    │
│  │      ? "Mama"                                      │    │
│  │      : "Safety"                                    │    │
│  │  }                                                 │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │  _getThemeColor() {                                │    │
│  │    return scenario == social                       │    │
│  │      ? Colors.teal                                 │    │
│  │      : Colors.deepOrange                           │    │
│  │  }                                                 │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Audio Playback Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     INCOMING CALL STATE                     │
│                                                              │
│  _playRingtone()                                            │
│       │                                                      │
│       ▼                                                      │
│  AudioPlayer.setLoopMode(LoopMode.one)                      │
│       │                                                      │
│       ▼                                                      │
│  AudioPlayer.setAsset('assets/sounds/ringtone.mp3')         │
│       │                                                      │
│       ▼                                                      │
│  AudioPlayer.play()                                         │
│       │                                                      │
│       │ [Loops until answered or declined]                  │
│       │                                                      │
└───────┼──────────────────────────────────────────────────────┘
        │
        │ User taps "Accept"
        ▼
┌─────────────────────────────────────────────────────────────┐
│                     ACTIVE CALL STATE                       │
│                                                              │
│  _answerCall()                                              │
│       │                                                      │
│       ▼                                                      │
│  AudioPlayer.stop()  // Stop ringtone                       │
│       │                                                      │
│       ▼                                                      │
│  Select audio from _currentAudioList                        │
│       │                                                      │
│       ├─── if social → 'social_1.mp3' or 'social_2.mp3'    │
│       └─── if safety → 'safety_1.mp3' or 'safety_2.mp3'    │
│       │                                                      │
│       ▼                                                      │
│  AudioPlayer.setAsset('assets/sounds/${selectedAudio}')     │
│       │                                                      │
│       ▼                                                      │
│  AudioPlayer.play()                                         │
│       │                                                      │
│       │ [Plays once until completion or end call]           │
│       │                                                      │
└───────┼──────────────────────────────────────────────────────┘
        │
        │ User taps "End Call"
        ▼
   AudioPlayer.stop()
   Navigator.pop()
```

## Component Hierarchy

```
FakeCallMenuScreen
├── Scaffold
│   ├── AppBar
│   │   └── Text: "Smart Fake Call"
│   └── Container (gradient background)
│       └── Column
│           ├── Icon: phone_forwarded
│           ├── Text: "Choose Your Scenario"
│           ├── _ScenarioCard: Social
│           │   ├── Icon: local_cafe_outlined
│           │   ├── Text: "Social"
│           │   ├── Text: "Escape awkward meetings"
│           │   └── onTap → Navigate(FakeCallScenario.social)
│           ├── _ScenarioCard: Safety
│           │   ├── Icon: shield_outlined
│           │   ├── Text: "Safety"
│           │   ├── Text: "Get help in unsafe areas"
│           │   └── onTap → Navigate(FakeCallScenario.safety)
│           └── Info Container
│
SmartFakeCallScreen
├── Scaffold
│   └── Container (gradient background based on scenario)
│       └── Column
│           ├── Row: Status Bar
│           │   ├── Text: "Incoming Call" / "In Call"
│           │   └── Text: Timer (if answered)
│           ├── AnimatedBuilder
│           │   └── Container: Avatar (pulse if ringing)
│           │       └── Icon: person (social) / shield (safety)
│           ├── Text: Caller Name (Mama / Safety)
│           ├── Text: Subtitle
│           └── if (!answered)
│               ├── _CallActionButton: Decline
│               └── _CallActionButton: Accept
│           └── if (answered)
│               ├── Row: Quick Actions
│               │   ├── _SmallCallButton: Mute
│               │   ├── _SmallCallButton: Keypad
│               │   └── _SmallCallButton: Speaker
│               └── _CallActionButton: End Call
```

## File Dependencies

```
features/fake_call/
├── fake_call_scenario.dart
│   └── enum FakeCallScenario { social, safety }
│
├── fake_call_menu_screen.dart
│   ├── imports: fake_call_scenario.dart
│   ├── imports: smart_fake_call_screen.dart
│   └── class FakeCallMenuScreen
│       └── class _ScenarioCard
│
├── smart_fake_call_screen.dart
│   ├── imports: fake_call_scenario.dart
│   ├── imports: just_audio
│   └── class SmartFakeCallScreen
│       ├── class _SmartFakeCallScreenState
│       ├── class _CallActionButton
│       └── class _SmallCallButton
│
└── fake_call.dart (exports all)

home_page.dart
└── imports: features/fake_call/fake_call_menu_screen.dart
```

## State Management

```
SmartFakeCallScreen State Variables:
┌─────────────────────────────────────────────────┐
│ _audioPlayer: AudioPlayer                      │
│ _pulseController: AnimationController          │
│ _pulseAnimation: Animation<double>             │
│ _isCallAnswered: bool = false                  │
│ _callTimer: Timer? = null                      │
│ _callDuration: int = 0                         │
│ _currentAudioList: List<String> = []           │
└─────────────────────────────────────────────────┘
                    │
                    ▼
          State Transitions:
┌─────────────────────────────────────────────────┐
│ Initial State                                   │
│   - _isCallAnswered = false                    │
│   - Ringtone playing (looped)                  │
│   - Pulse animation active                     │
│   - Show Answer/Decline buttons               │
│                                                 │
│         User taps "Accept"                     │
│                 │                              │
│                 ▼                              │
│ Answered State                                 │
│   - _isCallAnswered = true                     │
│   - Conversation audio playing                 │
│   - Pulse animation stopped                    │
│   - Timer started (_callDuration++)           │
│   - Show in-call controls + End button        │
│                                                 │
│         User taps "End Call"                   │
│                 │                              │
│                 ▼                              │
│ Disposed State                                 │
│   - Audio stopped                              │
│   - Timer cancelled                            │
│   - Navigator.pop()                            │
└─────────────────────────────────────────────────┘
```

## Color Scheme Map

```
Social Mode (FakeCallScenario.social)
├── Caller Name: "Mama"
├── Subtitle: "Mobile"
├── Theme Color: Colors.teal
├── Gradient: teal.shade900 → teal.shade500
├── Icon: Icons.person
└── Audio: social_1.mp3, social_2.mp3

Safety Mode (FakeCallScenario.safety)
├── Caller Name: "Safety"
├── Subtitle: "Emergency Contact"
├── Theme Color: Colors.deepOrange
├── Gradient: deepOrange.shade900 → deepOrange.shade500
├── Icon: Icons.shield
└── Audio: safety_1.mp3, safety_2.mp3

Menu Screen
├── Theme Color: Colors.deepPurple
├── Gradient: deepPurple.shade50 → white
└── Social Card: teal.withOpacity(0.1-0.05)
└── Safety Card: deepOrange.withOpacity(0.1-0.05)
```

---

**Legend:**
- `→` : Leads to / Transitions to
- `│` : Hierarchy / Contains
- `├──` : Has child / Contains
- `└──` : Last child
- `▼` : Flow direction / Next step
- `[...]` : Process / Action
