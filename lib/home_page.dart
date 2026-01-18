import 'package:flutter/material.dart';
import 'services/emergency_service.dart';
import 'services/shake_detection_service.dart';
import 'services/alert_manager.dart';
import 'ui/scaffold_wrapper.dart';
import 'config/app_theme.dart';

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
  bool _isSendingSos = false;
  late final EmergencyService _emergencyService;
  late final ShakeDetectionService _shakeDetectionService;

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

  void _openSettingsSheet() {
    Navigator.pushNamed(context, '/settings');
  }

  @override
  void initState() {
    super.initState();
    _emergencyService = EmergencyService.instance;
    _emergencyService.backgroundEvents.addListener(_onBackgroundEvent);
    // Consumă eventuale evenimente deja emise înainte de a fi construit widgetul.
    _onBackgroundEvent();

    // Initialize advanced shake detection
    _shakeDetectionService = ShakeDetectionService.instance;
    _shakeDetectionService.startListening(
      onDangerousShake: _onDangerousShakeDetected,
    );
  }

  /// Called when dangerous shake is detected (fall or struggle)
  void _onDangerousShakeDetected(ShakeDangerType dangerType) {
    if (!mounted) return;

    debugPrint('🚨 DANGEROUS SHAKE DETECTED: $dangerType');

    // Fire a background-friendly pre-alarm notification with countdown.
    AlertManager.instance.triggerPreAlarm(
      source: 'Shake detected ($dangerType)',
    );
  }

  @override
  void dispose() {
    _emergencyService.backgroundEvents.removeListener(_onBackgroundEvent);
    _shakeDetectionService.stopListening();
    super.dispose();
  }

  void _onBackgroundEvent() {
    if (!mounted) return;
    final event = _emergencyService.popBackgroundEvent();
    if (event == null) return;

    String? message;
    switch (event.type) {
      case EmergencyBackgroundEventType.offlineAlertSent:
        message = event.message;
        break;
      case EmergencyBackgroundEventType.offlineAlertPartialFailure:
        message = event.message;
        break;
      case EmergencyBackgroundEventType.offlineAlertFailed:
        message = event.message;
        break;
      case EmergencyBackgroundEventType.noContacts:
        message = 'Nu există contacte de urgență salvate pentru alertele automate.';
        break;
      case EmergencyBackgroundEventType.offlineAlertSkipped:
        // Nu afișăm mesaj pentru skip, ca să evităm spam-ul.
        break;
      case EmergencyBackgroundEventType.offlineAlertRequested:
        message =
            'Ai rămas fără internet. Am trimis o notificare pentru a trimite manual SMS-ul de urgență.';
        break;
    }

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _sendSos({bool isAutomatic = false}) async {
    if (_isSendingSos) return;
    setState(() {
      _isSendingSos = true;
    });

    final result = await _emergencyService.sendManualSos();

    if (!mounted) return;

    setState(() {
      _isSendingSos = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.userMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : _bgColor;
    final greetingColor = isDarkMode ? AppTheme.textSecondary : const Color(0xFF707070);
    final titleColor = isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);
    final subtleColor = isDarkMode ? AppTheme.textSecondary : const Color(0xFF555555);

    final bodyContent = SafeArea(
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
                    children: [
                      Text(
                        'Hi there,',
                        style: TextStyle(
                          fontSize: 16,
                          color: greetingColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Welcome to Safety App',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openSettingsSheet,
                  icon: Icon(Icons.settings_outlined, color: titleColor),
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 24),
            // SOS BUTTON
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: _isSendingSos ? null : _sendSos,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isSendingSos ? 0.7 : 1.0,
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
                  if (_isSendingSos)
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tap to send alert to your\ntrusted contacts',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtleColor,
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
                            isDarkMode: isDarkMode,
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? AppTheme.glassDarkMedium
                                    : const Color(0xFFFFF2E7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  'Map preview',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? AppTheme.accentOrange
                                        : const Color(0xFFB36B33),
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
                            isDarkMode: isDarkMode,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'When you send an alert,\nit will appear here.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subtleColor,
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
                            isDarkMode: isDarkMode,
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
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.pushNamed(context, '/contacts');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _DashboardCard(
                        title: 'Safety Timer',
                        subtitle: 'Dead Man\'s Switch',
                        icon: Icons.schedule_rounded,
                        iconBackground:
                            Colors.purple.withValues(alpha: 0.15),
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.pushNamed(context, '/safetyTimer');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _DashboardCard(
                        title: 'Black Box Recordings',
                        subtitle: 'View captured audio & photos',
                        icon: Icons.videocam_rounded,
                        iconBackground:
                            Colors.red.withValues(alpha: 0.15),
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.pushNamed(context, '/recordings');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _DashboardCard(
                        title: 'Monitor sunete',
                        subtitle: 'Detectează țipete, aglomerație, spargeri',
                        icon: Icons.hearing_rounded,
                        iconBackground:
                            Colors.purple.withValues(alpha: 0.15),
                        isDarkMode: isDarkMode,
                        onTap: () {
                          Navigator.pushNamed(context, '/soundMonitor');
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDarkMode) {
      return ScaffoldWrapper(
        body: bodyContent,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTap,
          backgroundColor: AppTheme.darkGradientBottom.withOpacity(0.8),
          selectedItemColor: AppTheme.accentOrange,
          unselectedItemColor: AppTheme.textSecondary,
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

    return Scaffold(
      backgroundColor: bgColor,
      body: bodyContent,
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

// Widget reutilizabil pentru cardurile din dashboard
class _DashboardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconBackground;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isDarkMode;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.iconBackground,
    this.subtitle,
    this.child,
    this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);
    final subtitleColor = isDarkMode ? AppTheme.textSecondary : const Color(0xFF777777);
    
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.glassDarkMedium : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isDarkMode
              ? Border.all(color: AppTheme.glassBorder, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: titleColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
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
