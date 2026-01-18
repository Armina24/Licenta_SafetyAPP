import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';
import 'ui/scaffold_wrapper.dart';
import 'ui/privacy_policy_screen.dart';
import 'ui/terms_of_service_screen.dart';
import 'config/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);

  bool _locationEnabled = false;
  bool _smsEnabled = false;
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('userEmail');
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });

    // Check location permission
    final locationStatus = await Permission.location.status;
    setState(() {
      _locationEnabled = locationStatus.isGranted;
    });

    // Check SMS permission
    final smsStatus = await Permission.sms.status;
    setState(() {
      _smsEnabled = smsStatus.isGranted;
    });
  }

  Future<void> _toggleLocation() async {
    if (_locationEnabled) {
      // Request to disable - just update UI
      setState(() => _locationEnabled = false);
    } else {
      final status = await Permission.location.request();
      if (!mounted) return;
      setState(() => _locationEnabled = status.isGranted);
      if (status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission granted')),
        );
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location permission is required for the SOS feature. Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleSms() async {
    if (_smsEnabled) {
      setState(() => _smsEnabled = false);
    } else {
      final status = await Permission.sms.request();
      if (!mounted) return;
      setState(() => _smsEnabled = status.isGranted);
      if (status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS permission granted')),
        );
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('SMS Permission Required'),
              content: const Text(
                'SMS permission is required to send emergency alerts. Please enable it in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _notificationsEnabled = !_notificationsEnabled);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
  }

  Future<void> _toggleDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = !_isDarkMode);
    await prefs.setBool('isDarkMode', _isDarkMode);
    // Update app theme using the ValueNotifier
    MyApp.themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _logout() async{
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/start', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarBgColor = isDarkMode ? Colors.transparent : _bgColor;
    final titleColor = isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);

    final scaffoldContent = Scaffold(
      backgroundColor: isDarkMode ? Colors.transparent : _bgColor,
      appBar: AppBar(
        backgroundColor: appBarBgColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Account Section
            _SectionHeader(title: 'Account'),
            _SettingsTile(
              leading: const Icon(Icons.email_outlined),
              title: 'Email',
              subtitle: _userEmail ?? 'Not available',
              trailing: null,
            ),
            const SizedBox(height: 8),

            // Permissions Section
            _SectionHeader(title: 'Permissions'),
            _SettingsTile(
              leading: const Icon(Icons.location_on_outlined),
              title: 'Location Access',
              subtitle: _locationEnabled
                  ? 'Enabled'
                  : 'Required for SOS alerts',
              trailing: Switch(
                value: _locationEnabled,
                onChanged: (_) => _toggleLocation(),
                activeThumbColor: _orange,
              ),
            ),
            _SettingsTile(
              leading: const Icon(Icons.sms_outlined),
              title: 'SMS Access',
              subtitle: _smsEnabled
                  ? 'Enabled'
                  : 'Required to send alerts',
              trailing: Switch(
                value: _smsEnabled,
                onChanged: (_) => _toggleSms(),
                activeThumbColor: _orange,
              ),
            ),
            const SizedBox(height: 8),

            // Appearance Section
            _SectionHeader(title: 'Appearance'),
            _SettingsTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: 'Dark Mode',
              subtitle: _isDarkMode
                  ? 'Dark theme enabled'
                  : 'Light theme enabled',
              trailing: Switch(
                value: _isDarkMode,
                onChanged: (_) => _toggleDarkMode(),
                activeThumbColor: _orange,
              ),
            ),
            const SizedBox(height: 8),

            // Notifications Section
            _SectionHeader(title: 'Notifications'),
            _SettingsTile(
              leading: const Icon(Icons.notifications_outlined),
              title: 'Push Notifications',
              subtitle: _notificationsEnabled
                  ? 'Enabled'
                  : 'Disabled',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (_) => _toggleNotifications(),
                activeThumbColor: _orange,
              ),
            ),
            const SizedBox(height: 8),

            // About Section
            _SectionHeader(title: 'About'),
            _SettingsTile(
              leading: const Icon(Icons.info_outline),
              title: 'App Version',
              subtitle: '1.0.0',
              trailing: null,
            ),
            _SettingsTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _SettingsTile(
              leading: const Icon(Icons.description_outlined),
              title: 'Terms of Service',
              subtitle: 'View terms and conditions',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('Log out'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (isDarkMode) {
      return ScaffoldWrapper(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
          title: const Text(
            'Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Account Section
              _SectionHeader(title: 'Account'),
              _SettingsTile(
                leading: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                title: 'Email',
                subtitle: _userEmail ?? 'Not available',
                trailing: null,
              ),
              const SizedBox(height: 8),
              // Permissions Section
              _SectionHeader(title: 'Permissions'),
              _SettingsTile(
                leading: Icon(Icons.location_on_outlined, color: AppTheme.accentTeal),
                title: 'Location Access',
                subtitle: _locationEnabled ? 'Enabled' : 'Required for SOS alerts',
                trailing: Switch(
                  value: _locationEnabled,
                  onChanged: (_) => _toggleLocation(),
                  activeThumbColor: AppTheme.accentOrange,
                ),
              ),
              _SettingsTile(
                leading: Icon(Icons.sms_outlined, color: AppTheme.accentBlue),
                title: 'SMS Access',
                subtitle: _smsEnabled ? 'Enabled' : 'Required to send alerts',
                trailing: Switch(
                  value: _smsEnabled,
                  onChanged: (_) => _toggleSms(),
                  activeThumbColor: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 8),
              // Appearance Section
              _SectionHeader(title: 'Appearance'),
              _SettingsTile(
                leading: Icon(Icons.dark_mode_outlined, color: AppTheme.accentPurple),
                title: 'Dark Mode',
                subtitle: _isDarkMode ? 'Dark theme enabled' : 'Light theme enabled',
                trailing: Switch(
                  value: _isDarkMode,
                  onChanged: (_) => _toggleDarkMode(),
                  activeThumbColor: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 8),
              // Notifications Section
              _SectionHeader(title: 'Notifications'),
              _SettingsTile(
                leading: Icon(Icons.notifications_outlined, color: AppTheme.accentGreen),
                title: 'Push Notifications',
                subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (_) => _toggleNotifications(),
                  activeThumbColor: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 8),
              // About Section
              _SectionHeader(title: 'About'),
              _SettingsTile(
                leading: Icon(Icons.info_outline, color: AppTheme.textSecondary),
                title: 'App Version',
                subtitle: '1.0.0',
                trailing: null,
              ),
              _SettingsTile(
                leading: Icon(Icons.privacy_tip_outlined, color: AppTheme.textSecondary),
                title: 'Privacy Policy',
                subtitle: 'View our privacy policy',
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
              ),
              _SettingsTile(
                leading: Icon(Icons.description_outlined, color: AppTheme.textSecondary),
                title: 'Terms of Service',
                subtitle: 'View terms and conditions',
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TermsOfServiceScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Logout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return scaffoldContent;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? AppTheme.textTertiary : const Color(0xFF777777),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isDarkMode ? 8 : 0,
      color: isDarkMode
          ? AppTheme.glassDarkMedium
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
              ? AppTheme.glassBorder
              : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDarkMode ? AppTheme.textSecondary : const Color(0xFF777777),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

