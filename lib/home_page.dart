import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:vibration/vibration.dart';
import 'services/emergency_service.dart';
import 'services/shake_detection_service.dart';
import 'services/alert_manager.dart';
import 'services/alerts_service.dart';
import 'services/audio_yamnet/audio_monitor_service.dart';
import 'services/audio_yamnet/audio_threat_detection_service.dart';
import 'ui/scaffold_wrapper.dart';
import 'ui/share_location_dialog.dart';
import 'config/app_theme.dart';
import 'services/background_sound_service.dart';
import 'features/fake_call/fake_call_menu_screen.dart';
import 'features/fake_call/fake_call_scenario.dart';
import 'profile_page.dart';
import 'services/user_profile_storage.dart';
import 'main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);
  static const Color _orangeDark = Color(0xFFFF6B35);

  int _selectedIndex = 0;
  bool _isSendingSos = false;
  bool _isSafetyShieldActive = false;
  bool _isSoundMonitoringActive = false;
  String? _fullName = 'User';
  late final EmergencyService _emergencyService;
  late final ShakeDetectionService _shakeDetectionService;
  late final AudioThreatDetectionService _threatDetectionService;
  late final QuickActions _quickActions;

  void _onBottomNavTap(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      Navigator.pushNamed(context, '/map').then((_) {
        setState(() => _selectedIndex = 0);
      });
    } else if (index == 2) {
      Navigator.pushNamed(context, '/profile').then((_) {
        setState(() => _selectedIndex = 0);
      });
    }
  }

  void _openSettingsSheet() {
    Navigator.pushNamed(context, '/settings');
  }

  Future<void> _loadSafetyShieldState() async {
    final prefs = await SharedPreferences.getInstance();

    final isActive =
        UserProfileStorage.getBool(
          prefs,
          'safety_shield_active',
          legacyKeys: const ['safety_shield_active'],
        ) ??
        false;
    setState(() {
      _isSafetyShieldActive = isActive;
    });

    if (isActive) {
      _enableSafetyShield();
    } else {
      _disableSafetyShield();
    }
  }

  Future<void> _enableAudioMonitoring() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isGranted) {
        await AudioMonitorService.instance.startMonitoring(
          onAlert: (result) {
            _threatDetectionService.processSoundDetection(result);
          },
        );
        setState(() {
          _isSoundMonitoringActive = true;
        });
        debugPrint('Audio monitoring started');
        return;
      }
    } catch (e) {
      debugPrint('Error starting audio monitoring: $e');
    }

    setState(() {
      _isSoundMonitoringActive = false;
    });
  }

  Future<void> _disableAudioMonitoring() async {
    try {
      await AudioMonitorService.instance.stopMonitoring();
      setState(() {
        _isSoundMonitoringActive = false;
      });
      debugPrint('Audio monitoring stopped');
    } catch (e) {
      debugPrint('Error stopping audio monitoring: $e');
    }
  }

  Future<void> _loadProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = UserProfileStorage.getString(prefs, 'fullName');

    if (!mounted) return;

    if (savedName != null && savedName.isNotEmpty) {
      setState(() {
        _fullName = savedName;
      });
    }
  }

  Future<void> _syncGlobalContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final globalCsv = prefs.getString('emergency_contacts') ?? '';
      if (globalCsv.isEmpty) {
        final contactsJson = UserProfileStorage.getString(
          prefs,
          'emergency_contacts_list',
        );
        if (contactsJson != null && contactsJson.isNotEmpty) {
          final List<String> phones = contactsJson
              .split('|')
              .map((item) {
                final parts = item.split('::');
                return parts.length == 2 ? parts[1].trim() : '';
              })
              .where((phone) => phone.isNotEmpty)
              .toList();
          if (phones.isNotEmpty) {
            await prefs.setString('emergency_contacts', phones.join(','));
            debugPrint(
              'Sync: Re-populated global emergency_contacts from user-scoped storage',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing global contacts: $e');
    }
  }

  Future<void> _toggleSoundMonitoring() async {
    final newState = !_isSoundMonitoringActive;

    if (newState) {
      await _enableAudioMonitoring();
      if (mounted && _isSoundMonitoringActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sound Monitoring Enabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _disableAudioMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sound Monitoring Disabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _enableSafetyShield() async {
    _shakeDetectionService.startListening(
      onDangerousShake: _onDangerousShakeDetected,
    );

    await _enableAudioMonitoring();

    debugPrint('Safety Shield ACTIVATED - All monitoring services enabled');
  }

  Future<void> _disableSafetyShield() async {
    _shakeDetectionService.stopListening();

    await _disableAudioMonitoring();

    debugPrint('Safety Shield DEACTIVATED - All monitoring services disabled');
  }

  Future<void> _toggleSafetyShield() async {
    final newState = !_isSafetyShieldActive;

    final prefs = await SharedPreferences.getInstance();
    await UserProfileStorage.setBool(prefs, 'safety_shield_active', newState);
    await prefs.setBool('safety_shield_active', newState);

    setState(() {
      _isSafetyShieldActive = newState;
    });

    if (newState) {
      await _enableSafetyShield();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safety Shield Activated - Monitoring enabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _disableSafetyShield();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safety Shield Deactivated - Monitoring disabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _emergencyService = EmergencyService.instance;
    _emergencyService.backgroundEvents.addListener(_onBackgroundEvent);

    _onBackgroundEvent();

    _shakeDetectionService = ShakeDetectionService.instance;

    _threatDetectionService = AudioThreatDetectionService.instance;
    _threatDetectionService.initialize(
      onThreatDetected: _onThreatDetected,
      onPreAlarmConfirmed: _onPreAlarmConfirmed,
      onPreAlarmCancelled: _onPreAlarmCancelled,
    );

    _loadSafetyShieldState();

    _loadUserTheme();

    _initializeQuickActions();

    _loadProfileName();
    _syncGlobalContacts();
  }

  Future<void> _loadUserTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode =
        UserProfileStorage.getBool(
          prefs,
          'isDarkMode',
          legacyKeys: const ['isDarkMode'],
        ) ??
        false;
    MyApp.themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _initializeQuickActions() {
    _quickActions = const QuickActions();

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_social',
        localizedTitle: 'Social Call',
        icon: 'icon_social',
      ),
      const ShortcutItem(
        type: 'action_emergency',
        localizedTitle: 'Emergency Call',
        icon: 'icon_safety',
      ),
    ]);

    _quickActions.initialize((String shortcutType) {
      _handleQuickAction(shortcutType);
    });
  }

  Future<void> _handleQuickAction(String shortcutType) async {
    if (!mounted) return;

    debugPrint('Quick Action triggered: $shortcutType');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command received. Call incoming in 5 seconds...'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.blueGrey,
      ),
    );

    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }

    if (!mounted) return;

    FakeCallScenario scenario;
    switch (shortcutType) {
      case 'action_social':
        scenario = FakeCallScenario.social;
        break;
      case 'action_emergency':
        scenario = FakeCallScenario.safety;
        break;
      default:
        debugPrint('Unknown quick action: $shortcutType');
        return;
    }

    if (!mounted) return;

    Navigator.pushNamed(context, '/incoming_call', arguments: scenario);
  }

  void _onThreatDetected(ThreatDetectionEvent event) {
    debugPrint('Threat detected: ${event.threatType}');

    AlertManager.instance.triggerPreAlarm(
      source:
          '${event.threatType.name} detected at ${event.confidenceScore.toStringAsFixed(2)} confidence',
    );
  }

  void _onPreAlarmConfirmed(ThreatDetectionEvent event) {
    debugPrint('Pre-alarm confirmed - executing SOS');
  }

  void _onPreAlarmCancelled(ThreatDetectionEvent event, String reason) {
    debugPrint('Pre-alarm cancelled: $reason');
  }

  void _onDangerousShakeDetected(ShakeDangerType dangerType) {
    if (!mounted) return;

    debugPrint('DANGEROUS SHAKE DETECTED: $dangerType');

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
        message =
            'Nu există contacte de urgență salvate pentru alertele automate.';
        break;
      case EmergencyBackgroundEventType.offlineAlertSkipped:
        break;
      case EmergencyBackgroundEventType.offlineAlertRequested:
        message =
            'Ai rămas fără internet. Am trimis o notificare pentru a trimite manual SMS-ul de urgență.';
        break;
    }

    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.userMessage)));

    try {
      await AlertsService.instance.logAlert(
        status: result.success ? 'sent' : 'failed',
        contactsReached: result.success ? 1 : 0,
        message: result.userMessage,
      );
    } catch (e) {
      debugPrint('Eroare la salvarea alertei: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : _bgColor;
    final greetingColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF707070);
    final titleColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);
    final subtleColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF555555);

    final bodyContent = SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, $_fullName!',
                        style: TextStyle(fontSize: 16, color: greetingColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Welcome to Kore',
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
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
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
                                      color: _orangeDark.withValues(
                                        alpha: 0.35,
                                      ),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
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
                        style: TextStyle(fontSize: 14, color: subtleColor),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleSafetyShield,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSafetyShieldActive
                              ? Colors.red.withValues(alpha: 0.8)
                              : (isDarkMode
                                    ? AppTheme.glassDarkMedium
                                    : const Color(0xFFFFE0B2)),
                          foregroundColor: _isSafetyShieldActive
                              ? Colors.white
                              : (isDarkMode
                                    ? AppTheme.textPrimary
                                    : const Color(0xFF1F1F1F)),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _isSafetyShieldActive
                                  ? Colors.red.withValues(alpha: 0.6)
                                  : (isDarkMode
                                        ? AppTheme.glassBorder
                                        : const Color(0xFFFFD699)),
                              width: 1.5,
                            ),
                          ),
                          elevation: _isSafetyShieldActive ? 4 : 1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSafetyShieldActive
                                  ? Icons.shield_rounded
                                  : Icons.shield_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _isSafetyShieldActive
                                    ? 'Safety Features: ACTIVE'
                                    : 'Activate Safety Features',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: _DashboardCard(
                            title: 'Manage contacts',
                            subtitle: 'Edit trusted contacts',
                            icon: Icons.group_rounded,
                            iconBackground: Colors.green.withValues(
                              alpha: 0.15,
                            ),
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.pushNamed(context, '/contacts');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashboardCard(
                            title: 'Share location',
                            subtitle: 'Send your live position',
                            icon: Icons.near_me_rounded,
                            iconBackground: _orange.withValues(alpha: 0.18),
                            isDarkMode: isDarkMode,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => ShareLocationDialog(
                                  onShare: (duration, method) {},
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _DashboardCard(
                            title: 'Safety Timer',
                            subtitle: 'Set your free time',
                            icon: Icons.schedule_rounded,
                            iconBackground: Colors.purple.withValues(
                              alpha: 0.15,
                            ),
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.pushNamed(context, '/safetyTimer');
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashboardCard(
                            title: 'Emergency Recordings',
                            subtitle: 'Photos & Recordings',
                            icon: Icons.videocam_rounded,
                            iconBackground: Colors.red.withValues(alpha: 0.15),
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.pushNamed(context, '/recordings');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleSoundMonitoring,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSoundMonitoringActive
                              ? Colors.green.withValues(alpha: 0.7)
                              : (isDarkMode
                                    ? AppTheme.glassDarkMedium
                                    : const Color(0xFFE8F5E9)),
                          foregroundColor: _isSoundMonitoringActive
                              ? Colors.white
                              : (isDarkMode
                                    ? AppTheme.textPrimary
                                    : const Color(0xFF1F1F1F)),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _isSoundMonitoringActive
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : (isDarkMode
                                        ? AppTheme.glassBorder
                                        : const Color(0xFFC8E6C9)),
                              width: 1.5,
                            ),
                          ),
                          elevation: _isSoundMonitoringActive ? 4 : 1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSoundMonitoringActive
                                  ? Icons.hearing_rounded
                                  : Icons.hearing_outlined,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Sound Monitoring',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FakeCallMenuScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode
                              ? AppTheme.glassDarkMedium
                              : const Color(0xFFE3F2FD),
                          foregroundColor: isDarkMode
                              ? AppTheme.textPrimary
                              : const Color(0xFF1F1F1F),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDarkMode
                                  ? AppTheme.glassBorder
                                  : const Color(0xFFBBDEFB),
                              width: 1.5,
                            ),
                          ),
                          elevation: 1,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_forwarded,
                              size: 20,
                              color: isDarkMode
                                  ? Colors.lightBlue
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Smart Fake Call',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? AppTheme.textPrimary
                                      : const Color(0xFF1F1F1F),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isDarkMode) {
      return ScaffoldWrapper(
        body: bodyContent,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTap,
          backgroundColor: AppTheme.darkGradientBottom.withValues(alpha: 0.8),
          selectedItemColor: AppTheme.accentOrange,
          unselectedItemColor: AppTheme.textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Map',
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
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconBackground;
  final VoidCallback? onTap;
  final bool isDarkMode;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.iconBackground,
    this.subtitle,
    this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);
    final subtitleColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF777777);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 180,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: titleColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
