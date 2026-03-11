import 'package:flutter/material.dart';
import '../services/safety_timer_service.dart';
import '../config/app_theme.dart';

class SafetyTimerPage extends StatefulWidget {
  const SafetyTimerPage({super.key});

  @override
  State<SafetyTimerPage> createState() => _SafetyTimerPageState();
}

class _SafetyTimerPageState extends State<SafetyTimerPage> {
  late final SafetyTimerService _safetyTimerService;

  @override
  void initState() {
    super.initState();
    _safetyTimerService = SafetyTimerService.instance;
    // Listen for state changes
    _safetyTimerService.timerState.addListener(_onTimerStateChanged);
  }

  void _onTimerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _safetyTimerService.timerState.removeListener(_onTimerStateChanged);
    super.dispose();
  }

  void _startTimer(int minutes) {
    _safetyTimerService.startTimer(Duration(minutes: minutes));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Safety Timer started for $minutes minutes'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _extendTimer(int minutes) {
    _safetyTimerService.extendTimer(Duration(minutes: minutes));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Timer extended by $minutes minutes'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _stopTimer() {
    _safetyTimerService.stopTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Safety Timer stopped'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentState = _safetyTimerService.getCurrentState();
    final isActive = currentState?.isActive ?? false;
    final isWarning = currentState?.isCheckInWarning ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Timer'),
        backgroundColor: const Color(0xFFFF8C42),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFF8C42),
                        const Color(0xFFFF6B35),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Safety Timer',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 4),
                      const Text(
                        'Automatic emergency alert if you don\'t check in',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Timer display (if active)
                if (isActive)
                  Column(
                    children: [
                      // Timer value
                      Text(
                        currentState!.remainingTimeFormatted,
                        style: TextStyle(
                          fontSize: 45,
                          fontWeight: FontWeight.bold,
                          color: isWarning ? Colors.red : const Color(0xFFFF8C42),
                          fontFamily: 'Courier',
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Warning message if < 5 min
                      if (isWarning)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Less than 5 minutes remaining',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Timer active - Auto SOS will trigger at 00:00',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Action buttons (when timer active)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _stopTimer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'I\'m OK - Stop Timer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Quick extend buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _extendTimer(5),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF8C42)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                '+5 min',
                                style: TextStyle(color: Color(0xFFFF8C42)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _extendTimer(15),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF8C42)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                '+15 min',
                                style: TextStyle(color: Color(0xFFFF8C42)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _extendTimer(30),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF8C42)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                '+30 min',
                                style: TextStyle(color: Color(0xFFFF8C42)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  )
                else
                  // Timer not active - show preset options
                  Column(
                    children: [
                      Text(
                        'Set your safety timer:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Preset timer buttons
                      _buildTimerButton(
                        label: '15 minutes',
                        duration: 6,
                        icon: Icons.directions_run,
                        description: 'Quick jog or errand',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 12),
                      _buildTimerButton(
                        label: '30 minutes',
                        duration: 30,
                        icon: Icons.directions_walk,
                        description: 'Short outing',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 12),
                      _buildTimerButton(
                        label: '60 minutes',
                        duration: 60,
                        icon: Icons.public,
                        description: 'Travel or outdoor activity',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 12),
                      _buildTimerButton(
                        label: '120 minutes',
                        duration: 120,
                        icon: Icons.directions_car,
                        description: 'Long journey',
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),

                // Info section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppTheme.glassDarkMedium : const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode ? AppTheme.glassBorder : const Color(0xFFFFE0CC),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it works:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoItem(
                        '1',
                        'Set a timer for your activity (jogging, traveling, etc.)',
                        isDarkMode: isDarkMode,
                      ),
                      _buildInfoItem(
                        '2',
                        'Timer counts down in background',
                        isDarkMode: isDarkMode,
                      ),
                      _buildInfoItem(
                        '3',
                        '5 minutes before expiry, you get a notification',
                        isDarkMode: isDarkMode,
                      ),
                      _buildInfoItem(
                        '4',
                        'Tap "I\'m OK" to stop, or extend if you need more time',
                        isDarkMode: isDarkMode,
                      ),
                      _buildInfoItem(
                        '5',
                        'If timer reaches 0:00, emergency alert sent automatically',
                        isDarkMode: isDarkMode,
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

  Widget _buildTimerButton({
    required String label,
    required int duration,
    required IconData icon,
    required String description,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: () => _startTimer(duration),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.glassDarkMedium : Colors.white,
          border: Border.all(
            color: isDarkMode ? AppTheme.glassBorder : const Color(0xFFE0E0E0),
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C42).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFFF8C42),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? AppTheme.textSecondary : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFFFF8C42),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String number, String text, {required bool isDarkMode}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFFF8C42),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? AppTheme.textSecondary : const Color(0xFF555555),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
