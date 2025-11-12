import 'package:flutter/material.dart';
import 'services/location_service.dart';
import 'services/sms_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Culori folosite în ecran
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _orangeDark = Color(0xFFFF6B35);

  int _selectedIndex = 0;

  void _onBottomNavTap(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      // Alerts screen - coming soon
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alerts screen coming soon')),
      );
    } else if (index == 2) {
      // Navigate to Profile
      Navigator.pushNamed(context, '/profile').then((_) {
        // Reset to home when returning
        setState(() => _selectedIndex = 0);
      });
    }
  }

  void _onSosPressed() {
    _sendSos();
  }

  void _openSettingsSheet() {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: salut + icon setări
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Hi there,',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF707070),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Welcome to Safety App',
                            // dacă vrei, îl poți rupe și pe 2 rânduri:
                            // 'Welcome to\nSafety App',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F1F1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openSettingsSheet,
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Settings',
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // SOS BUTTON
              Center(
                child: GestureDetector(
                  onTap: _onSosPressed,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_orange, _orangeDark],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _orangeDark.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Center(
                child: Text(
                  'Tap to send alert to your\ntrusted contacts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF555555),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // DASHBOARD CARDS
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardCard(
                              title: 'Location',
                              subtitle: 'Live · Your city',
                              icon: Icons.location_on_rounded,
                              iconBackground: _orange.withValues(alpha: 0.18),
                              child: Container(
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF2E7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Map preview',
                                    style: TextStyle(
                                      color: Color(0xFFB36B33),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/map');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardCard(
                              title: 'Recent alert',
                              subtitle: 'None yet',
                              icon: Icons.history_rounded,
                              iconBackground:
                                  Colors.blueGrey.withValues(alpha: 0.12),
                              child: const Padding(
                                padding: EdgeInsets.only(top: 8.0),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'When you send an alert,\n'
                                    'it will appear here.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF777777),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardCard(
                              title: 'Share location',
                              subtitle: 'Send your live position',
                              icon: Icons.near_me_rounded,
                              iconBackground:
                                  _orange.withValues(alpha: 0.18),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Demo: sharing location (not implemented).'),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardCard(
                              title: 'Manage contacts',
                              subtitle: 'Edit trusted contacts',
                              icon: Icons.group_rounded,
                              iconBackground:
                                  Colors.green.withValues(alpha: 0.15),
                              onTap: () {
                                Navigator.pushNamed(context, '/contacts');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // BOTTOM NAVIGATION
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        backgroundColor: Colors.white,
        selectedItemColor: _orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

extension on _HomePageState {
  Future<void> _sendSos() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending SOS...')),
    );
    final position = await LocationService.instance.getCurrentPosition();
    if (position == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location unavailable')),
      );
      return;
    }
    final contacts = await SmsService.instance.loadEmergencyContacts();
    if (contacts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contacts configured')),
      );
      return;
    }
    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);
    final message =
        'SOS! Am nevoie de ajutor. Locația mea: https://maps.google.com/?q=$lat,$lon';

    // Trimite direct SMS în background (Android). Dacă vrei interactiv, folosește sendSms().
    final sent = await SmsService.instance.sendSmsSilentlyToMultiple(
      phoneNumbers: contacts,
      message: message,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent
            ? 'SOS sent'
            : 'SOS failed. Check SMS permission and balance.'),
      ),
    );
  }
}

// Widget reutilizabil pentru cardurile din dashboard
class _DashboardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconBackground;
  final Widget? child;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.iconBackground,
    this.subtitle,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1F1F1F),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF777777),
                ),
              ),
            ],
            if (child != null) ...[
              const SizedBox(height: 8),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}
