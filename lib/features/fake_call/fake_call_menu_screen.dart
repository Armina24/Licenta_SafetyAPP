import 'package:flutter/material.dart';
import 'fake_call_scenario.dart';
import 'smart_fake_call_screen.dart';

/// Entry screen for selecting fake call scenario
class FakeCallMenuScreen extends StatelessWidget {
  const FakeCallMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryOrange = isDark ? const Color(0xFFFF8A50) : const Color(0xFFFF7A00);
    final secondaryOrange = isDark ? const Color(0xFFFF6F3D) : const Color(0xFFFF5A1F);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Fake Call'),
        centerTitle: true,
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    primaryOrange.withValues(alpha: 0.85),
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    primaryOrange.withValues(alpha: 0.15),
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header
                Icon(
                  Icons.phone_forwarded,
                  size: 64,
                  color: primaryOrange,
                ),
                const SizedBox(height: 16),
                Text(
                  'Choose Your Scenario',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF3B1B0D),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the type of fake call you need',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.grey[700]!,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Social Button
                _ScenarioCard(
                  title: 'Social',
                  description: 'Escape awkward meetings',
                  icon: Icons.local_cafe_outlined,
                  color: primaryOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SmartFakeCallScreen(
                          scenario: FakeCallScenario.social,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Emergency Button
                _ScenarioCard(
                  title: 'Emergency',
                  description: 'Get help in unsafe areas',
                  icon: Icons.shield_outlined,
                  color: secondaryOrange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SmartFakeCallScreen(
                          scenario: FakeCallScenario.safety,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // Info text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : primaryOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : primaryOrange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: primaryOrange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your phone will simulate a realistic incoming call',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scenario selection card widget
class _ScenarioCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ScenarioCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600]!,
                          ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
