import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/app_theme.dart';
import '../services/alerts_service.dart';
import '../services/live_location_share_service.dart';
import '../services/sms_service.dart';

class ShareLocationDialog extends StatefulWidget {
  final Function(String duration, String method) onShare;

  const ShareLocationDialog({super.key, required this.onShare});

  @override
  State<ShareLocationDialog> createState() => _ShareLocationDialogState();
}

class _ShareLocationDialogState extends State<ShareLocationDialog> {
  String? _selectedDuration;
  final List<String> _durations = ['30 Minutes', '1 Hour', '3 Hours'];
  final Map<String, int> _durationMinutes = {
    '30 Minutes': 30,
    '1 Hour': 60,
    '3 Hours': 180,
  };

  void _proceedToShareMethod() {
    if (_selectedDuration == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a duration')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _ShareMethodSheet(
        duration: _selectedDuration!,
        durationMinutes: _durationMinutes[_selectedDuration]!,
        onShare: widget.onShare,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? AppTheme.darkGradientTop
        : const Color(0xFFFFF8F2);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Share Your Location',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.textPrimary
                    : const Color(0xFF1F1F1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select how long to share your live location',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDarkMode
                    ? AppTheme.textSecondary
                    : const Color(0xFF707070),
              ),
            ),
            const SizedBox(height: 24),

            ...List.generate(_durations.length, (index) {
              final duration = _durations[index];
              final isSelected = _selectedDuration == duration;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedDuration = duration);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFFF8C42)
                              : (isDarkMode ? Colors.white12 : Colors.black12),
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? const Color(0xFFFF8C42).withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFFF8C42),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFFFF8C42),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            duration,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode
                                      ? AppTheme.textPrimary
                                      : const Color(0xFF1F1F1F),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _proceedToShareMethod,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C42),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : const Color(0xFF707070),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareMethodSheet extends StatelessWidget {
  final String duration;
  final int durationMinutes;
  final Function(String duration, String method) onShare;

  const _ShareMethodSheet({
    required this.duration,
    required this.durationMinutes,
    required this.onShare,
  });

  Future<void> _shareLiveLocation(
    BuildContext context, {
    required String method,
  }) async {
    try {
      List<String> contacts = const [];
      if (method == 'sms') {
        contacts = await SmsService.instance.loadEmergencyContacts();
        if (contacts.isEmpty) {
          throw Exception('No emergency contacts are saved.');
        }
      }

      final session = await LiveLocationShareService.instance.startSharing(
        durationMinutes: durationMinutes,
      );

      final message = LiveLocationShareService.instance.buildShareMessage(
        durationLabel: duration,
        shareUri: session.shareUri,
      );

      if (method == 'sms') {
        final report = await SmsService.instance.sendSmsSilentlyWithReport(
          phoneNumbers: contacts,
          message: message,
        );

        if (!report.allSent) {
          final failed = report.failed
              .map((item) => item.phoneNumber)
              .join(', ');
          throw Exception(
            report.hasPartialSuccess
                ? 'Live location sent only to some contacts: $failed'
                : 'Could not send the live location SMS.',
          );
        }
      } else {
        await Share.share(message, subject: 'Live Location Sharing');
      }

      onShare(duration, method);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Live location sharing started for $duration'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      try {
        await AlertsService.instance.logAlert(
          status: 'sent',
          contactsReached: method == 'sms' ? contacts.length : 0,
          message: message,
        );
      } catch (e) {
        debugPrint('Eroare la salvarea alertei: $e');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _shareViaApp(BuildContext context) async {
    await _shareLiveLocation(context, method: 'app');
  }

  void _sendViaContacts(BuildContext context) async {
    await _shareLiveLocation(context, method: 'sms');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode
        ? AppTheme.darkGradientTop
        : const Color(0xFFFFF8F2);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Sharing Method',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.textPrimary
                    : const Color(0xFF1F1F1F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your location will be shared for $duration',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDarkMode
                    ? AppTheme.textSecondary
                    : const Color(0xFF707070),
              ),
            ),
            const SizedBox(height: 20),

            _ShareMethodButton(
              icon: Icons.contact_emergency_rounded,
              title: 'Send to Emergency Contacts',
              subtitle: 'Uses SMS to send location link',
              isDarkMode: isDarkMode,
              onTap: () => _sendViaContacts(context),
            ),
            const SizedBox(height: 12),

            _ShareMethodButton(
              icon: Icons.share_rounded,
              title: 'Share via App',
              subtitle: 'WhatsApp, Messenger, Instagram, etc.',
              isDarkMode: isDarkMode,
              onTap: () => _shareViaApp(context),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode
                      ? AppTheme.textSecondary
                      : const Color(0xFF707070),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareMethodButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _ShareMethodButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.black12,
            ),
            color: isDarkMode
                ? AppTheme.glassDarkMedium
                : const Color(0xFFFF8C42).withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFFF8C42), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? AppTheme.textPrimary
                            : const Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkMode
                            ? AppTheme.textSecondary
                            : const Color(0xFF707070),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_rounded,
                color: isDarkMode
                    ? AppTheme.textSecondary
                    : const Color(0xFF707070),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
