import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);

  String? _userEmail;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    
    if (!mounted) return;
    setState(() {
      _userEmail = email;
    });

    try {
      final userData = await AuthService.instance.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1F1F1F)),
        title: const Text(
          'Profile',
          style: TextStyle(color: Color(0xFF1F1F1F)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: _orange.withValues(alpha: 0.2),
                      child: Text(
                        (_userEmail != null && _userEmail!.isNotEmpty)
                            ? _userEmail!.substring(0, 1).toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _orange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userEmail ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                    if (_userData != null && _userData!['createdAt'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Member since ${_formatDate(_userData!['createdAt'])}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Profile Information Section
                    _ProfileSection(
                      title: 'Account Information',
                      children: [
                        _ProfileInfoTile(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: _userEmail ?? 'Not available',
                        ),
                        if (_userData != null && _userData!['id'] != null)
                          _ProfileInfoTile(
                            icon: Icons.badge_outlined,
                            label: 'User ID',
                            value: _userData!['id'].toString(),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Safety Features Section
                    _ProfileSection(
                      title: 'Safety Features',
                      children: [
                        _ProfileInfoTile(
                          icon: Icons.shield_outlined,
                          label: 'SOS Alerts',
                          value: 'Enabled',
                          valueColor: Colors.green,
                        ),
                        _ProfileInfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Location Sharing',
                          value: 'Active',
                          valueColor: Colors.green,
                        ),
                        _ProfileInfoTile(
                          icon: Icons.contacts_outlined,
                          label: 'Emergency Contacts',
                          value: 'Configured',
                          valueColor: Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    _ProfileSection(
                      title: 'Quick Actions',
                      children: [
                        _ActionTile(
                          icon: Icons.contacts_outlined,
                          title: 'Manage Contacts',
                          subtitle: 'Add or edit emergency contacts',
                          onTap: () {
                            Navigator.pushNamed(context, '/contacts');
                          },
                        ),
                        _ActionTile(
                          icon: Icons.settings_outlined,
                          title: 'Settings',
                          subtitle: 'App preferences and permissions',
                          onTap: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateStr = date.toString();
      // Try to parse ISO date string
      final dateTime = DateTime.parse(dateStr);
      return '${dateTime.day}.${dateTime.month}.${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F1F1F),
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF8C42)),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF777777),
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: valueColor ?? const Color(0xFF1F1F1F),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.end,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF8C42)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF777777),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

