import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:vibration/vibration.dart';
import 'services/emergency_service.dart';
import 'services/shake_detection_service.dart';
import 'services/alert_manager.dart';
import 'services/audio_yamnet/audio_monitor_service.dart';
import 'services/audio_yamnet/audio_threat_detection_service.dart';
import 'ui/scaffold_wrapper.dart';
import 'ui/share_location_dialog.dart';
import 'config/app_theme.dart';
import 'services/background_sound_service.dart';
import 'features/fake_call/fake_call_menu_screen.dart';
import 'features/fake_call/fake_call_scenario.dart';

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
  bool _isSafetyShieldActive = false;
  bool _isSoundMonitoringActive = false;
  
  late final EmergencyService _emergencyService;
  late final ShakeDetectionService _shakeDetectionService;
  late final AudioThreatDetectionService _threatDetectionService;
  late final QuickActions _quickActions;

  void _onBottomNavTap(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      // Navigate to Map screen
      Navigator.pushNamed(context, '/map').then((_) {
        // Reset to home when returning
        setState(() => _selectedIndex = 0);
      });
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

  /// Load the Safety Shield state from SharedPreferences
  Future<void> _loadSafetyShieldState() async {
    final prefs = await SharedPreferences.getInstance();
    final isActive = prefs.getBool('safety_shield_active') ?? false;
    setState(() {
      _isSafetyShieldActive = isActive;
    });
    
    // Apply the state to services
    if (isActive) {
      _enableSafetyShield();
    } else {
      _disableSafetyShield();
    }
  }

  /// Enable audio monitoring (foreground)
  Future<void> _enableAudioMonitoring() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isGranted) {
        await AudioMonitorService.instance.startMonitoring(
          onAlert: (result) {
            // Process sound through threat detection service
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
    
    // If permission denied or error, revert state
    setState(() {
      _isSoundMonitoringActive = false;
    });
  }

  /// Disable audio monitoring
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

  /// Toggle sound monitoring independently (foreground with mic icon visible)
  Future<void> _toggleSoundMonitoring() async {
    final newState = !_isSoundMonitoringActive;
    
    if (newState) {
      await _enableAudioMonitoring();
      if (mounted && _isSoundMonitoringActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎙️ Sound Monitoring Enabled'),
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

  /// Enable all safety monitoring services
  Future<void> _enableSafetyShield() async {
    // Start shake detection
    _shakeDetectionService.startListening(
      onDangerousShake: _onDangerousShakeDetected,
    );
    
    // Automatically enable sound monitoring when safety shield is activated
    await _enableAudioMonitoring();
    
    debugPrint('Safety Shield ACTIVATED - All monitoring services enabled');
  }

  /// Disable all safety monitoring services
  Future<void> _disableSafetyShield() async {
    // Stop shake detection
    _shakeDetectionService.stopListening();
    
    // Stop audio monitoring
    await _disableAudioMonitoring();
    
    debugPrint('Safety Shield DEACTIVATED - All monitoring services disabled');
  }

  /// Toggle the Safety Shield on/off
  Future<void> _toggleSafetyShield() async {
    final newState = !_isSafetyShieldActive;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
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
    // Consumă eventuale evenimente deja emise înainte de a fi construit widgetul.
    _onBackgroundEvent();

    // Initialize shake detection service
    _shakeDetectionService = ShakeDetectionService.instance;
    
    // Initialize audio threat detection service
    _threatDetectionService = AudioThreatDetectionService.instance;
    _threatDetectionService.initialize(
      onThreatDetected: _onThreatDetected,
      onPreAlarmConfirmed: _onPreAlarmConfirmed,
      onPreAlarmCancelled: _onPreAlarmCancelled,
    );
    
    // Load Safety Shield state and apply it
    _loadSafetyShieldState();
    
    // Initialize Quick Actions
    _initializeQuickActions();
  }
  
  /// Initialize Quick Actions for app shortcuts
  void _initializeQuickActions() {
    _quickActions = const QuickActions();
    
    // Set up shortcut items
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
    
    // Handle shortcut actions
    _quickActions.initialize((String shortcutType) {
      _handleQuickAction(shortcutType);
    });
  }
  
  /// Handle quick action shortcuts with realism delay
  Future<void> _handleQuickAction(String shortcutType) async {
    if (!mounted) return;
    
    debugPrint('Quick Action triggered: $shortcutType');
    
    // 1. Immediate Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Command received. Call incoming in 5 seconds...'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.blueGrey,
      ),
    );
    
    // 2. Delay for realism (allows putting phone in pocket)
    await Future.delayed(const Duration(seconds: 5));
    
    // Safety check after delay
    if (!mounted) return;
    
    // 3. Vibration to simulate phone starting to ring
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 500);
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
    
    // Safety check before navigation
    if (!mounted) return;
    
    // 4. Navigate to incoming call screen (realistic ring screen)
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
    
    // Use mounted check before using context
    if (!mounted) return;
    
    Navigator.pushNamed(
      context,
      '/incoming_call',
      arguments: scenario,
    );
  }
  
  /// Called when a threat is detected
  void _onThreatDetected(ThreatDetectionEvent event) {
    debugPrint('Threat detected: ${event.threatType}');
  }

  /// Called when pre-alarm is confirmed
  void _onPreAlarmConfirmed(ThreatDetectionEvent event) {
    debugPrint('Pre-alarm confirmed - executing SOS');
  }

  /// Called when pre-alarm is cancelled
  void _onPreAlarmCancelled(ThreatDetectionEvent event, String reason) {
    debugPrint('Pre-alarm cancelled: $reason');
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
      child: Column(
        children: [
          // HEADER: salut + icon setări
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
                        'Hi there,',
                        style: TextStyle(
                          fontSize: 16,
                          color: greetingColor,
                        ),
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
          // SCROLLABLE CONTENT: SOS Button + Dashboard Cards
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // SOS BUTTON
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
                    // SAFETY SHIELD BUTTON (styled like Sound Monitor)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleSafetyShield,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSafetyShieldActive
                              ? Colors.red.withValues(alpha: 0.8)
                              : (isDarkMode
                                  ? AppTheme.glassDarkMedium
                                  : const Color(0xFFFFE0B2)), // Pale orange for light mode
                          foregroundColor: _isSafetyShieldActive
                              ? Colors.white
                              : (isDarkMode
                                  ? AppTheme.textPrimary
                                  : const Color(0xFF1F1F1F)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                    // DASHBOARD CARDS - NEW GRID LAYOUT
                    
                    // Row 1: Manage Contacts + Share Location
                    Row(
                      children: [
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DashboardCard(
                            title: 'Share location',
                            subtitle: 'Send your live position',
                            icon: Icons.near_me_rounded,
                            iconBackground:
                                _orange.withValues(alpha: 0.18),
                            isDarkMode: isDarkMode,
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => ShareLocationDialog(
                                  onShare: (duration, method) {
                                    // Handle the share action
                                    // duration: "30 Minutes", "1 Hour", "3 Hours"
                                    // method: "sms" or "app"
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Row 2: Safety Timer + Black Box Recordings
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardCard(
                            title: 'Safety Timer',
                            subtitle: 'Set your free time',
                            icon: Icons.schedule_rounded,
                            iconBackground:
                                Colors.purple.withValues(alpha: 0.15),
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
                            iconBackground:
                                Colors.red.withValues(alpha: 0.15),
                            isDarkMode: isDarkMode,
                            onTap: () {
                              Navigator.pushNamed(context, '/recordings');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Row 3: Sound Monitoring (Full Width)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleSoundMonitoring,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isSoundMonitoringActive
                              ? Colors.green.withValues(alpha: 0.7)
                              : (isDarkMode
                                  ? AppTheme.glassDarkMedium
                                  : const Color(0xFFE8F5E9)), // Pale green for light mode
                          foregroundColor: _isSoundMonitoringActive
                              ? Colors.white
                              : (isDarkMode
                                  ? AppTheme.textPrimary
                                  : const Color(0xFF1F1F1F)),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                    
                    // Row 4: Smart Fake Call (Full Width)
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
                              : const Color(0xFFE3F2FD), // Pale blue for light mode
                          foregroundColor: isDarkMode
                              ? AppTheme.textPrimary
                              : const Color(0xFF1F1F1F),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
                              color: isDarkMode ? Colors.lightBlue : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Smart Fake Call',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
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
}

// Widget reutilizabil pentru cardurile din dashboard
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
    final titleColor = isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);
    final subtitleColor = isDarkMode ? AppTheme.textSecondary : const Color(0xFF777777);
    
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 180, // Increased from 150 to show full text
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
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
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
