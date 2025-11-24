import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/emergency_service.dart';
import 'services/notification_service.dart';

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

  // Permisiunea SEND_SMS va fi cerută de canalul nativ la nevoie.

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safety App',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFFFF8F2),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF8C42),
          brightness: Brightness.light,
        ),
      ),
      initialRoute: isLoggedIn ? '/home' : '/start',
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
      },
    );
  }
}
