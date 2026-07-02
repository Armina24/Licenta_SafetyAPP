import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : const Color(0xFFFFF8F2);
    final textColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);
    final secondaryTextColor = isDarkMode
        ? AppTheme.textSecondary
        : const Color(0xFF707070);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text('Privacy Policy', style: TextStyle(color: textColor)),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Privacy Policy', isDarkMode, textColor),
            const SizedBox(height: 16),
            _buildContent(isDarkMode, textColor, secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
  ) {
    final sections = [
      (
        ' 1. Introduction',
        'Kore Safwty App ("we," "us," "our," or "Company") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application (the "App").',
      ),
      (
        '2. Location Data Usage',
        'Our App collects and processes your real-time location data primarily to:\n\n• Enable emergency services to locate you quickly\n• Provide live location sharing with designated emergency contacts\n• Display your position on the safety map interface\n• Generate location-based threat alerts\n\nLocation data is only collected when the App is in use and only shared with your explicitly selected emergency contacts. You can disable location sharing at any time through the Settings menu.',
      ),
      (
        '3. Microphone Access and Audio Processing',
        'The Safety App requests microphone access to:\n\n• Monitor environmental audio for potential threats (glass breaking, gunshots, etc.)\n• Provide real-time threat detection using machine learning\n• Send pre-alarm notifications if potential threats are detected\n\nAll audio processing happens locally on your device. Raw audio files are NOT stored on our servers unless you explicitly enable audio recording through the Black Box feature.',
      ),
      (
        '4. Local Data Storage',
        'The following data is stored locally on your device and is NOT sent to external servers:\n\n• Your emergency contacts information\n• Location history cache\n• Notification preferences\n• User settings and configurations\n• Threat detection logs\n\nThis data remains under your exclusive control and is deleted if you uninstall the App.',
      ),
      (
        '5. Server Communication',
        'The App communicates with our servers ONLY for:\n\n• Authentication (login/signup)\n• Emergency alert transmission (with your permission)\n• User account management\n• App analytics (anonymous usage statistics)\n\nNo personal data is shared with third parties without your explicit consent.',
      ),
      (
        '6. Data Security',
        'We implement industry-standard encryption and security protocols to protect your data:\n\n• End-to-end encryption for emergency messages\n• Secure HTTPS connections for all server communication\n• Regular security audits\n• Compliance with GDPR and local privacy regulations',
      ),
      (
        '7. User Rights',
        'You have the right to:\n\n• Access all personal data we hold about you\n• Request correction of inaccurate data\n• Request deletion of your account and associated data\n• Opt-out of analytics collection\n• Export your data in a portable format',
      ),
      (
        '8. Changes to This Policy',
        'We may update this Privacy Policy periodically. We will notify you of any material changes via in-app notification or email. Your continued use of the App constitutes acceptance of the updated Privacy Policy.',
      ),
      (
        '9. Contact Us',
        'For privacy concerns or to exercise your data rights, please contact us at:\n\nEmail: privacy@safetyapp.com\nAddress: [Company Address]\nPhone: [Support Phone Number]',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        sections.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sections[index].$1,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sections[index].$2,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDarkMode;
  final Color textColor;

  const _SectionTitle(this.title, this.isDarkMode, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }
}
