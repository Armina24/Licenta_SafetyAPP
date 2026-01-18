import 'package:flutter/material.dart';
import 'dart:async';

class SoundDetectionDialog extends StatefulWidget {
  final String threatType; // "Scream" or "Glass Breaking"
  final double confidenceScore; // 0.0 - 1.0
  final Function onFalseAlarm;
  final Function onHelpNow;
  final Function onTimeout;
  final Duration countdownDuration;

  const SoundDetectionDialog({
    super.key,
    required this.threatType,
    required this.confidenceScore,
    required this.onFalseAlarm,
    required this.onHelpNow,
    required this.onTimeout,
    this.countdownDuration = const Duration(seconds: 15),
  });

  @override
  State<SoundDetectionDialog> createState() => _SoundDetectionDialogState();
}

class _SoundDetectionDialogState extends State<SoundDetectionDialog>
    with SingleTickerProviderStateMixin {
  late Timer _countdownTimer;
  late Duration _remainingTime;
  late AnimationController _pulseController;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.countdownDuration;
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseController.repeat(reverse: true);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      setState(() {
        _remainingTime = _remainingTime - const Duration(milliseconds: 100);
        if (_remainingTime.isNegative) {
          _remainingTime = Duration.zero;
        }
      });

      if (_remainingTime == Duration.zero) {
        timer.cancel();
        if (!_dismissed && mounted) {
          _handleTimeout();
        }
      }
    });
  }

  void _handleFalseAlarm() {
    if (_dismissed) return;
    _dismissed = true;
    _countdownTimer.cancel();
    widget.onFalseAlarm();
    Navigator.of(context).pop();
  }

  void _handleHelpNow() {
    if (_dismissed) return;
    _dismissed = true;
    _countdownTimer.cancel();
    widget.onHelpNow();
    Navigator.of(context).pop();
  }

  void _handleTimeout() {
    if (_dismissed) return;
    _dismissed = true;
    _countdownTimer.cancel();
    widget.onTimeout();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.countdownDuration.inSeconds.toDouble();
    final elapsedSeconds = (widget.countdownDuration - _remainingTime).inMilliseconds / 1000.0;
    final progress = (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
    final secondsRemaining = _remainingTime.inSeconds;

    // Get threat icon and color based on threat type
    final threatColor = _getThreatColor();
    final threatIcon = _getThreatIcon();

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with threat icon - animated pulse effect
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          threatColor,
                          threatColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        // Pulsing icon
                        ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0)
                              .animate(_pulseController),
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              threatIcon,
                              size: 48,
                              color: threatColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${widget.threatType} Detected',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidence: ${(widget.confidenceScore * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Sending alert to your contacts in:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Is this a real emergency?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF707070),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Countdown progress indicator
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: progress,
                                backgroundColor: Color(0xFFEEEEEE),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  secondsRemaining <= 5
                                      ? Colors.red
                                      : threatColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${secondsRemaining}s remaining',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: secondsRemaining <= 5
                                        ? Colors.red
                                        : threatColor,
                                  ),
                                ),
                                if (secondsRemaining <= 5)
                                  Text(
                                    'SENDING SOON',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Action buttons
                        // Row 1: Primary action (Help Now)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleHelpNow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: threatColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            child: const Text(
                              'Help Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Secondary action (False Alarm)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _handleFalseAlarm,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Color(0xFF999999),
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'False Alarm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Info text
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF8F0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: threatColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: threatColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your location will be shared with emergency contacts.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF666666),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Color _getThreatColor() {
    if (widget.threatType.toLowerCase().contains('scream') ||
        widget.threatType.toLowerCase().contains('tipete')) {
      return Color(0xFFFF6B35); // Orange for screams
    } else if (widget.threatType.toLowerCase().contains('glass') ||
        widget.threatType.toLowerCase().contains('spargere')) {
      return Color(0xFF7B2CBF); // Purple for glass breaking
    }
    return Color(0xFFFF6B35); // Default
  }

  IconData _getThreatIcon() {
    if (widget.threatType.toLowerCase().contains('scream') ||
        widget.threatType.toLowerCase().contains('tipete')) {
      return Icons.volume_up_rounded;
    } else if (widget.threatType.toLowerCase().contains('glass') ||
        widget.threatType.toLowerCase().contains('spargere')) {
      return Icons.broken_image_rounded;
    }
    return Icons.warning_amber_rounded;
  }

  @override
  void didUpdateWidget(SoundDetectionDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdownDuration != widget.countdownDuration) {
      _countdownTimer.cancel();
      _remainingTime = widget.countdownDuration;
      _startCountdown();
    }
  }
}
