# Diagrama UML - Safety App

## Relații Generale în Aplicație

```
                                    ┌─────────────────┐
                                    │   MyApp         │
                                    │  (StatefulWidget)│
                                    └────────┬────────┘
                                             │
                                    ┌────────▼────────┐
                                    │  HomePage       │
                                    │ (StatefulWidget)│
                                    └────────┬────────┘
                                             │
                 ┌───────────────────────────┼───────────────────────────┐
                 │                           │                           │
        ┌────────▼─────────┐      ┌──────────▼──────────┐      ┌─────────▼────────┐
        │   MapPage        │      │   ProfilePage       │      │  SettingsPage    │
        │ (StatefulWidget) │      │ (StatefulWidget)    │      │ (StatefulWidget) │
        └──────────────────┘      └─────────────────────┘      └──────────────────┘
```

## Servicii de Core (Singleton Pattern)

```
┌────────────────────────────────────────────────────────────────────────┐
│                      SERVICIILE PRINCIPALE                             │
└────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────────────┐
    │  EmergencyService        │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              ├─ uses ──► LocationService  │
              ├─ uses ──► SmsService       │
              ├─ uses ──► ConnectivityService
              ├─ uses ──► BlackBoxRecorderService
              └─ uses ──► NotificationService

    ┌──────────────────────────┐
    │  AlertManager            │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              ├─ uses ──► FlutterLocalNotificationsPlugin
              ├─ uses ──► Vibration
              └─ notifies ──► EmergencyService

    ┌──────────────────────────┐
    │  SafetyTimerService      │◄─── uses ──┐
    │  (Singleton/Dead Man's   │           │
    │   Switch)                │           │
    └──────────────────────────┘           │
              │                             │
              ├─ uses ──► SharedPreferences│
              ├─ uses ──► AlertManager    │
              ├─ uses ──► EmergencyService
              └─ triggers ──► SOS if not checked-in

    ┌──────────────────────────┐
    │  LocationService         │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              └─ uses ──► Geolocator

    ┌──────────────────────────┐
    │  ShakeDetectionService   │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              ├─ uses ──► SensorManager   │
              └─ triggers ──► SOS on shake

    ┌──────────────────────────┐
    │  AudioMonitorService     │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              └─ uses ──► AudioThreatDetectionService

    ┌──────────────────────────┐
    │  BackgroundService       │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              └─ runs services in background

    ┌──────────────────────────┐
    │  ConnectivityService     │◄─── uses ──┐
    │  (Singleton)             │           │
    └──────────────────────────┘           │
              │                             │
              └─ monitors internet connection
```

## Diagrama Detaliată cu Flux de Date

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      FLUX DE ALERTE ȘI SOS                              │
└─────────────────────────────────────────────────────────────────────────┘

UTILIZATOR INACTIV / PERICLITAT
        │
        │ (manual SOS / shake / audio threat detected / timer expired)
        ▼
┌─────────────────────────┐
│  AlertManager           │
│  - Afișează pre-alarm   │
│  - Vibrează            │
│  - Countdown           │
└──────────┬──────────────┘
           │
           │ (dacă nu e anulat în X secunde)
           ▼
┌─────────────────────────┐
│  EmergencyService       │
│  - Obține locația GPS   │
│  - Înregistrează black box
│  - Trimite SMS-uri      │
│  - Trimite POST request │
│    la server            │
└──────────┬──────────────┘
           │
           ├─ uses ──► LocationService (GPS)
           ├─ uses ──► SmsService (SMS via Twilio)
           ├─ uses ──► ApiClient (HTTP POST)
           └─ uses ──► BlackBoxRecorderService
```

## Componente Autentificare

```
┌──────────────────────────┐
│  StartPage               │
│  - Splash screen         │
└──────────┬───────────────┘
           │
     ┌─────┴─────┐
     │            │
     ▼            ▼
┌─────────┐  ┌──────────────────┐
│LoginPage│  │SignupPage        │
└────┬────┘  └────────┬─────────┘
     │                │
     └────────┬───────┘
              │
              ▼
     ┌──────────────────────┐
     │SignupContactsPage    │
     │(select emergency     │
     │ contacts)            │
     └──────────┬───────────┘
                │
                ▼
     ┌──────────────────────┐
     │SignupLocationPage    │
     │(set safe zones)      │
     └──────────┬───────────┘
                │
                ▼
          ┌──────────┐
          │HomePage  │
          └──────────┘
```

## Servicii Audio și Detecție

```
┌────────────────────────────────────┐
│  AudioMonitorService               │
│  (Background Sound Service)         │
│  - Monitorizează sunetele          │
│  - Constantă inregistrare          │
└──────────┬─────────────────────────┘
           │
           │ uses
           ▼
┌────────────────────────────────────┐
│  AudioThreatDetectionService       │
│  - Utilizează TFLite model         │
│  - Detectează violență, glasuri    │
│  - Reține ultimele X secunde       │
└──────────┬─────────────────────────┘
           │
           │ triggers
           ▼
┌────────────────────────────────────┐
│  BlackBoxRecorderService           │
│  - Inregistrează audio criptat     │
│  - Pentru dovezi legale            │
│  - Trimite pe server pentru upload │
└────────────────────────────────────┘
```

## Features Fake Call

```
┌────────────────────────────────┐
│  FakeCallScenario              │
│  - Setează tip apel            │
│  - Persoană contact             │
│  - Mesaj voce personalizat      │
└──────────┬─────────────────────┘
           │
     ┌─────┴──────┐
     │             │
     ▼             ▼
┌──────────────┐  ┌────────────────────┐
│IncomingCall  │  │ActiveCallScreen    │
│ Screen       │  │ - Simuleaza apel   │
└──────────────┘  │ - Timeline         │
                  │ - Conversatie text │
                  └────────────────────┘
```

## Features Shake Detection

```
┌────────────────────────────────────┐
│  ShakeDetectionService             │
│  - Monitorizează accelerometrul    │
│  - Calculeaza magnitudine          │
└──────────┬─────────────────────────┘
           │
           │ triggers on shake
           ▼
┌────────────────────────────────────┐
│  Alert (EmergencyService)          │
│  - Pre-alarm 5 secunde             │
│  - SOS dacă nu e anulat            │
└────────────────────────────────────┘
```

## Safety Timer (Dead Man's Switch)

```
┌────────────────────────────────────┐
│  SafetyTimerPage                   │
│  - Set timer (5-120 min)           │
│  - Indicator activ                 │
└──────────┬─────────────────────────┘
           │ calls
           ▼
┌────────────────────────────────────┐
│  SafetyTimerService                │
│  - Tick fiecare secundă            │
│  - Check-in warning -5 min         │
│  - Pre-alarm -3 min                │
└──────────┬─────────────────────────┘
           │
      ┌────┴─────────┬────────────┐
      │              │            │
      ▼              ▼            ▼
   ┌─────┐  ┌──────────────┐  ┌────────┐
   │User │  │AlertManager  │  │SharedPref
   │checks│  │(warning)     │  │(save state)
   │in OK │  └──────────────┘  └────────┘
   └─────┘
      │
      └──► Timer resetat/oprit
      
   Dacă timer expira:
   ┌────────────────────────┐
   │ EmergencyService       │
   │ Trimite SOS automat    │
   └────────────────────────┘
```

## Baza de Date și Storage

```
┌─────────────────────────────────────┐
│  SharedPreferences                  │
│  - User logged in state             │
│  - Theme mode                       │
│  - Emergency contacts               │
│  - Safe zones                       │
│  - Timer state                      │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Local SQLite (cu Drift/Sqflite)    │
│  - Recording history                │
│  - SOS logs                         │
│  - Location history                 │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  Server Backend                     │
│  - User accounts                    │
│  - Contacts                         │
│  - SOS records                      │
│  - Audio recordings (encrypted)     │
│  - Location trails                  │
└─────────────────────────────────────┘
```

## Relații Notificări

```
┌──────────────────────────┐
│  AlertManager            │
│  - Pre-alarm notification│
│  - Timer warning         │
└──────────┬───────────────┘
           │
           ├─ HIGH priority action
           │  └─► "Am-OK" button (anulare)
           │
           ├─ Timer warning
           │  ├─► Stop
           │  ├─► +5 min
           │  ├─► +15 min
           │  └─► +30 min
           │
           └─ uses ──► FlutterLocalNotificationsPlugin
                       └─ Android: High priority + heads-up
                       └─ iOS: Alert + sound
```

## API Calls - EmergencyService → Backend

```
POST /api/sos
{
  "latitude": float,
  "longitude": float,
  "accuracy": float,
  "timestamp": ISO string,
  "userId": string,
  "contacts": [phone1, phone2],
  "reason": "shake|audio_threat|timer|manual",
  "blackBoxId": string (optional)
}

POST /api/audio-upload
- Criptat audio file
- Metadata cu encryption key
- User ID

POST /api/check-in
- SafetyTimer check-in
- Timestamp
- User status "safe" / "unsafe"
```

## Permisiuni Necesare

```
┌────────────────────────────────────┐
│  Permisiuni Android/iOS            │
│                                    │
│  - LOCATION (background)           │
│  - RECORD_AUDIO                    │
│  - SEND_SMS                        │
│  - SENSORS (accelerometer)         │
│  - CAMERA (video recording opt)    │
│  - CONTACTS                        │
│  - POST_NOTIFICATIONS              │
│  - FOREGROUND_SERVICE              │
│  - BLUETOOTH (optional)            │
└────────────────────────────────────┘
```

## Flowchart - SOS Trigger

```
START
  │
  ├─────────────────────────────────────────┐
  │                                         │
  ▼                                         │
User Inactiv / Shake / Audio / Timer        │ Manual SOS click
  │                                         │
  └──────────────────────┬──────────────────┘
                         │
                         ▼
         ┌────────────────────────────┐
         │ AlertManager.showPreAlarm()│
         │ - Vibrație                 │
         │ - Notificare              │
         │ - Countdown 5 sec         │
         └────────────┬───────────────┘
                      │
         ┌────────────┴──────────────┐
         │                           │
    User "Am OK"              Timer Expira
    Anulează                    │
         │                      ▼
         ▼          ┌───────────────────────┐
    DONE            │ EmergencyService.sendSOS()│
                    │ 1. Get GPS Location   │
                    │ 2. Record Audio       │
                    │ 3. Send SMS           │
                    │ 4. POST server        │
                    │ 5. Notify contacts    │
                    └───────────────────────┘
                              │
                              ▼
                         DONE - SOS SENT
```

## Relații Clase - Inheritance

```
┌──────────────────────────────────┐
│  StatefulWidget                  │
└────────┬─────────────────────────┘
         │
    ┌────┴────────────────────────┬──────────────────┬────────────────┐
    │                             │                  │                │
    ▼                             ▼                  ▼                ▼
HomePage                       MapPage          ProfilePage      SettingsPage
|                              |                |                |
|--> _HomePageState            |--> MapPageState |--> ProfilePage |--> SettingsPageState
                                                 State             

┌──────────────────────────────────┐
│  Service (Singleton)             │
└────────┬─────────────────────────┘
         │
    ┌────┴────┬───────┬────────┬─────────┬──────────────┬──────────────┐
    │          │       │        │         │              │              │
    ▼          ▼       ▼        ▼         ▼              ▼              ▼
EmergencyService
AlertManager
SafetyTimerService
LocationService
ConnectivityService
SmsService
BlackBoxRecorderService
ShakeDetectionService
```

## Dependențe Externe

```
┌─────────────────────────────────────┐
│  Dependențe Externe (pubspec.yaml)  │
├─────────────────────────────────────┤
│  shared_preferences: ^2.2.2         │ Storage persistență
│  http: ^1.2.2                       │ API calls
│  flutter_map: ^7.0.0                │ Hartă interactivă
│  latlong2: ^0.9.0                   │ Coordonate GPS
│  geolocator: ^12.0.0                │ Locație GPS
│  connectivity_plus: ^6.0.0          │ Internet connectivity
│  vibration: ^0.0.0                  │ Vibrație haptic
│  flutter_local_notifications        │ Notificări locale
│  permission_handler                 │ Permisiuni
│  flutter_background_service         │ Serviciu background
│  record: ^5.0.0                     │ Înregistrare audio
│  just_audio: ^0.9.0                 │ Redare audio
│  tflite_flutter                     │ ML inference
│  image_picker: ^1.0.0               │ Selectare imagini
│  camera: ^0.10.0                    │ Acces cameră
│  flutter_contacts: ^1.1.0           │ Contacte
│  geolocator: ^12.0.0                │ GPS
│  sensors_plus: ^2.0.0               │ Accelerometru
└─────────────────────────────────────┘
```
