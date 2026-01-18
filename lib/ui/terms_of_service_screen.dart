import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.transparent : const Color(0xFFFFF8F2);
    final textColor =
        isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);
    final secondaryTextColor =
        isDarkMode ? AppTheme.textSecondary : const Color(0xFF707070);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Terms of Service',
          style: TextStyle(color: textColor),
        ),
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
            _SectionTitle('Terms of Service', isDarkMode, textColor),
            const SizedBox(height: 16),
            _buildContent(isDarkMode, textColor, secondaryTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDarkMode, Color textColor, Color secondaryTextColor) {
    final sections = [
      (
        '1. Acceptance of Terms',
        'By downloading, installing, or using the Kore Safety App, you agree to be bound by these Terms of Service. If you do not agree with any provision, you must not use the App.'
      ),
      (
        '2. Service Description',
        'The Kore Safety App is a personal safety tool designed to:\n\n• Provide emergency alerting to designated contacts\n• Enable real-time location sharing\n• Monitor for environmental threats\n• Facilitate communication during emergencies\n\nThe App is provided "AS IS" without warranties of any kind.'
      ),
      (
        '3. Liability Disclaimer - IMPORTANT',
        'The Kore Safety App is a SUPPLEMENTARY tool and is NOT a replacement for emergency services (911, 112, or equivalent in your region).\n\nIN CASE OF IMMEDIATE DANGER OR MEDICAL EMERGENCY, ALWAYS CONTACT LOCAL EMERGENCY SERVICES DIRECTLY.\n\nNeither the Company nor its developers shall be liable for:\n\n• Failure to detect threats or transmit alerts\n• Delays in emergency response\n• Inaccuracy of location data\n• Interruptions or unavailability of service\n• Any direct, indirect, incidental, or consequential damages arising from use or inability to use the App\n\nYou use the App entirely at your own risk.'
      ),
      (
        '4. User Responsibilities',
        'You agree to:\n\n• Provide accurate information during registration\n• Maintain the confidentiality of your account\n• Use the App only for lawful purposes\n• Not reverse-engineer, decompile, or attempt to discover source code\n• Not use the App to harass, threaten, or endanger others\n• Not share your account credentials with others'
      ),
      (
        '5. Permissions and Data Access',
        'By using the App, you grant permission to access:\n\n• Your device location\n• Microphone for audio monitoring\n• Contact information for emergency contacts\n• Notification permissions\n• Camera (if using Black Box feature)\n\nYou may revoke these permissions at any time through device settings, though this may limit App functionality.'
      ),
      (
        '6. Termination',
        'We reserve the right to terminate or suspend your account if:\n\n• You violate these Terms of Service\n• You use the App for illegal purposes\n• You repeatedly fail to respect user policies\n• You misuse emergency alert systems\n\nTermination may be immediate and without notice.'
      ),
      (
        '7. Modifications to Service',
        'We may modify, suspend, or discontinue the App or any features at any time without notice. We are not liable for any losses resulting from such modifications or discontinuation.'
      ),
      (
        '8. Intellectual Property',
        'All content, features, and functionality of the App (including design, text, graphics, logos, and software) are owned by the Company and are protected by copyright and other intellectual property laws.'
      ),
      (
        '9. Third-Party Services',
        'The App may integrate with third-party services (maps, SMS gateways, etc.). We are not responsible for these services and recommend reviewing their terms and privacy policies independently.'
      ),
      (
        '10. Governing Law',
        'These Terms of Service are governed by the laws of [Your Jurisdiction] without regard to its conflict of law provisions. You agree to submit to the exclusive jurisdiction of the courts in [Your Jurisdiction].'
      ),
      (
        '11. Dispute Resolution',
        'Any disputes arising from this agreement shall first be addressed through good-faith negotiation. If not resolved, disputes shall be submitted to binding arbitration or court proceedings as applicable in your jurisdiction.'
      ),
      (
        '12. Severability',
        'If any provision of these Terms is found to be invalid or unenforceable, that provision shall be modified to the minimum extent necessary to make it valid, and the remaining provisions shall continue in full force and effect.'
      ),
      (
        '13. Entire Agreement',
        'These Terms of Service, along with our Privacy Policy, constitute the entire agreement between you and the Company regarding the App and supersede all prior understandings and agreements.'
      ),
      (
        '14. Contact Information',
        'For questions regarding these Terms of Service, please contact:\n\nEmail: legal@safetyapp.com\nAddress: [Company Address]\nPhone: [Support Phone Number]'
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
