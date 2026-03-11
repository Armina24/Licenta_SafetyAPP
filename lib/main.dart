import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_actions/quick_actions.dart';

import 'services/emergency_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'services/background_sound_service.dart';
import 'services/alert_manager.dart';
import 'services/safety_timer_service.dart';
import 'config/app_theme.dart';

import 'start_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'signup_contacts_page.dart';
import 'signup_location_page.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'settings_page.dart';
import 'contacts_page.dart';
import 'profile_page.dart';
import 'ui/sound_monitor_page.dart';
import 'ui/safety_timer_page.dart';
import 'ui/recordings_viewer_page.dart';
import 'features/fake_call/active_call_screen.dart';
import 'features/fake_call/incoming_call_screen.dart';
import 'features/fake_call/fake_call_scenario.dart';
import 'features/fake_call_ai/demo_entry.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.initialize(
    onSelectNotification: (payload) async {
      if (payload == NotificationService.offlineAlertPayload) {
        await EmergencyService.instance.sendOfflineAlertManually();
      }
    },
  );

  await EmergencyService.instance.initialize();

  await AlertManager.instance.initialize(
    onSendSos: () async {
      await EmergencyService.instance.sendManualSos();
    },
    onTimerAction: (actionId) async {
      // Handle timer notification actions
      if (actionId == 'action_timer_stop') {
        await SafetyTimerService.instance.stopTimer();
        debugPrint('🛡️ Timer stopped via notification action');
      } else if (actionId == 'action_timer_add5') {
        await SafetyTimerService.instance.extendTimer(const Duration(minutes: 5));
        debugPrint('⏱️ Timer extended by 5 minutes via notification');
      } else if (actionId == 'action_timer_add15') {
        await SafetyTimerService.instance.extendTimer(const Duration(minutes: 15));
        debugPrint('⏱️ Timer extended by 15 minutes via notification');
      } else if (actionId == 'action_timer_add30') {
        await SafetyTimerService.instance.extendTimer(const Duration(minutes: 30));
        debugPrint('⏱️ Timer extended by 30 minutes via notification');
      }
    },
  );

  await AppBackgroundService.instance.initialize();  //pornim serviciul de background

  // Start dedicated background sound monitoring (foreground service)
  await BackgroundSoundService.instance.initialize();

  // Permisiunea SEND_SMS va fi cerută de canalul nativ la nevoie.

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn, isDarkMode: isDarkMode));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final bool isDarkMode;

  const MyApp({super.key, required this.isLoggedIn, required this.isDarkMode});

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    MyApp.themeNotifier.value = widget.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    MyApp.themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    MyApp.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safety App',
      themeMode: MyApp.themeNotifier.value,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8C42),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: AppTheme.darkTheme(),
      initialRoute: widget.isLoggedIn ? '/home' : '/start',
      routes: {
        '/start': (_) => const StartPage(),
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignupPage(),
        '/signupContacts': (_) => const SignupContactsPage(),
        '/signupLocation': (_) => const SignupLocationPage(),
        '/home': (_) => const HomePage(),
        '/map': (_) => const MapPage(),
        '/settings': (_) => const SettingsPage(),
        '/contacts': (_) => const ContactsPage(),
        '/profile': (_) => const ProfilePage(),
        '/soundMonitor': (_) => const SoundMonitorPage(),
        '/safetyTimer': (_) => const SafetyTimerPage(),
        '/recordings': (_) => const RecordingsViewerPage(),
        '/fake_call_social': (_) => const ActiveCallScreen(scenario: FakeCallScenario.social),
        '/fake_call_safety': (_) => const ActiveCallScreen(scenario: FakeCallScenario.safety),
        '/fake_call_ai_demo': (_) => const FakeCallAIDemoEntry(),
      },
      onGenerateRoute: (settings) {
        // Handle /incoming_call route with arguments
        if (settings.name == '/incoming_call') {
          final scenario = settings.arguments as FakeCallScenario?;
          if (scenario != null) {
            return MaterialPageRoute(
              builder: (_) => IncomingCallScreen(scenario: scenario),
            );
          }
        }
        return null;
      },
    );
  }
}
