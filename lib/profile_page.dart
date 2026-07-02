import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'services/auth_service.dart';
import 'services/profile_service.dart';
import 'services/user_profile_storage.dart';
import 'ui/scaffold_wrapper.dart';
import 'ui/account_info_screen.dart';
import 'config/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _bgColor = Color(0xFFFFF8F2);
  static const Color _orange = Color(0xFFFF8C42);

  String? _userEmail;
  String? _fullName;
  String? _profileImagePath;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  late TextEditingController _nameEditController;

  @override
  void initState() {
    super.initState();
    _nameEditController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameEditController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    final fullName = UserProfileStorage.getString(prefs, 'fullName');
    final imagePath = UserProfileStorage.getString(prefs, 'profileImagePath');

    if (!mounted) return;
    setState(() {
      _userEmail = email;
      _fullName = fullName;
      _profileImagePath = imagePath;
      _nameEditController.text = fullName ?? '';
      _isLoading = false;
    });

    try {
      final userData = await AuthService.instance.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _userData = userData;
      });
    } catch (e) {
      debugPrint('Failed to fetch user data from server: $e');
    }
  }

  Future<void> _deleteProfilePicture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile Picture'),
        content: const Text(
          'Are you sure you want to delete your profile picture?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm ?? false) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await UserProfileStorage.remove(prefs, 'profileImagePath');

        if (mounted) {
          setState(() {
            _profileImagePath = null;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture deleted'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting picture: $e')));
        }
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    try {
      PermissionStatus status = await Permission.storage.request();

      if (!status.isGranted) {
        status = await Permission.mediaLibrary.request();
      }

      if (!status.isGranted) {
        if (status.isDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Photo library permission is required to upload a profile picture',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (status.isPermanentlyDenied) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Photo Library Permission Required'),
                content: const Text(
                  'Photo library permission is required to upload a profile picture. Please enable it in app settings.',
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
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await UserProfileStorage.setString(
          prefs,
          'profileImagePath',
          image.path,
        );

        if (mounted) {
          setState(() {
            _profileImagePath = image.path;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading picture: $e')));
      }
    }
  }

  Future<void> _editName() async {
    if (_nameEditController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name')));
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await UserProfileStorage.setString(
        prefs,
        'fullName',
        _nameEditController.text,
      );

      await ProfileService.instance.updateProfile(
        displayName: _nameEditController.text,
      );

      if (mounted) {
        setState(() {
          _fullName = _nameEditController.text;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating name: $e')));
      }
    }
  }

  void _showNameEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDarkMode
            ? AppTheme.darkGradientTop
            : const Color(0xFFFFF8F2);
        final textColor = isDarkMode
            ? AppTheme.textPrimary
            : const Color(0xFF1F1F1F);

        return AlertDialog(
          backgroundColor: bgColor,
          title: Text('Edit Name', style: TextStyle(color: textColor)),
          content: TextField(
            controller: _nameEditController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: isDarkMode ? AppTheme.glassBorder : Colors.grey,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : const Color(0xFF707070),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _editName();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C42),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : _bgColor;
    final appBarColor = isDarkMode ? Colors.transparent : _bgColor;
    final titleColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);
    final subtitleColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF707070);
    final iconColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF1F1F1F);

    final appBar = AppBar(
      backgroundColor: appBarColor,
      elevation: 0,
      iconTheme: IconThemeData(color: iconColor),
      title: Text('Profile', style: TextStyle(color: titleColor)),
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
    );

    final body = SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: isDarkMode
                              ? AppTheme.glassDarkMedium
                              : _orange.withValues(alpha: 0.2),
                          backgroundImage:
                              _profileImagePath != null &&
                                  File(_profileImagePath!).existsSync()
                              ? FileImage(File(_profileImagePath!))
                                    as ImageProvider
                              : null,
                          child:
                              _profileImagePath == null ||
                                  !File(_profileImagePath!).existsSync()
                              ? Text(
                                  (_fullName?.isNotEmpty ?? false)
                                      ? _fullName!.substring(0, 1).toUpperCase()
                                      : (_userEmail?.isNotEmpty ?? false)
                                      ? _userEmail!
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF8C42),
                                  ),
                                )
                              : null,
                        ),

                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFFF8C42),
                              border: Border.all(
                                color: bgColor == Colors.transparent
                                    ? Colors.white
                                    : _bgColor,
                                width: 3,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _uploadProfilePicture,
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_profileImagePath != null &&
                            File(_profileImagePath!).existsSync())
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withValues(alpha: 0.8),
                                border: Border.all(
                                  color: bgColor == Colors.transparent
                                      ? Colors.white
                                      : _bgColor,
                                  width: 3,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _deleteProfilePicture,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _fullName?.isNotEmpty ?? false
                                ? _fullName!
                                : 'Add your name',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showNameEditDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _orange.withValues(alpha: 0.2),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: _orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_userData != null && _userData!['createdAt'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Member since ${_formatDate(_userData!['createdAt'])}',
                        style: TextStyle(fontSize: 14, color: subtitleColor),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AccountInfoScreen(userEmail: _userEmail),
                        ),
                      ).then((_) {
                        _loadProfile();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_circle_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _ProfileSection(
                    title: 'Safety Features',
                    isDarkMode: isDarkMode,
                    children: [
                      _ProfileInfoTile(
                        icon: Icons.shield_outlined,
                        label: 'SOS Alerts',
                        value: 'Enabled',
                        valueColor: Colors.green,
                        isDarkMode: isDarkMode,
                      ),
                      _ProfileInfoTile(
                        icon: Icons.location_on_outlined,
                        label: 'Location Sharing',
                        value: 'Active',
                        valueColor: Colors.green,
                        isDarkMode: isDarkMode,
                      ),
                      _ProfileInfoTile(
                        icon: Icons.contacts_outlined,
                        label: 'Emergency Contacts',
                        value: 'Configured',
                        valueColor: Colors.green,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _ProfileSection(
                    title: 'Quick Actions',
                    isDarkMode: isDarkMode,
                    children: [
                      _ActionTile(
                        icon: Icons.contacts_outlined,
                        title: 'Manage Contacts',
                        subtitle: 'Add or edit emergency contacts',
                        onTap: () {
                          Navigator.pushNamed(context, '/contacts');
                        },
                        isDarkMode: isDarkMode,
                      ),
                      _ActionTile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'App preferences and permissions',
                        onTap: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );

    if (isDarkMode) {
      return ScaffoldWrapper(appBar: appBar, body: body);
    }

    return Scaffold(backgroundColor: bgColor, appBar: appBar, body: body);
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateStr = date.toString();

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
  final bool isDarkMode;

  const _ProfileSection({
    required this.title,
    required this.children,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
        ),
        Card(
          elevation: 0,
          color: isDarkMode ? AppTheme.glassDarkMedium : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode
                  ? AppTheme.glassBorder
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
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
  final bool isDarkMode;

  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF777777);
    final valueDefaultColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);

    return ListTile(
      leading: Icon(icon, color: AppTheme.accentOrange),
      title: Text(label, style: TextStyle(fontSize: 14, color: labelColor)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: valueColor ?? valueDefaultColor,
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
  final bool isDarkMode;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
    final chevronColor = isDarkMode ? AppTheme.textSecondary : Colors.grey;

    return ListTile(
      leading: Icon(icon, color: AppTheme.accentOrange),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: subtitleColor),
      ),
      trailing: Icon(Icons.chevron_right, color: chevronColor),
      onTap: onTap,
    );
  }
}
