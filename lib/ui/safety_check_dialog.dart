import 'package:flutter/material.dart';
import 'dart:async';

class SafetyCheckDialog extends StatefulWidget {
  final Function onCancel;
  final Function onConfirm;
  final Duration countdownDuration;

  const SafetyCheckDialog({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.countdownDuration = const Duration(seconds: 10),
  });

  @override
  State<SafetyCheckDialog> createState() => _SafetyCheckDialogState();
}

class _SafetyCheckDialogState extends State<SafetyCheckDialog> {
  late Timer _countdownTimer;
  late Duration _remainingTime;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.countdownDuration;
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
          _confirmAlert();
        }
      }
    });
  }

  void _cancelAlert() {
    if (_dismissed) return;
    _dismissed = true;
    _countdownTimer.cancel();
    widget.onCancel();
    Navigator.of(context).pop();
  }

  void _confirmAlert() {
    if (_dismissed) return;
    _dismissed = true;
    _countdownTimer.cancel();
    widget.onConfirm();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = widget.countdownDuration.inSeconds.toDouble();
    final elapsedSeconds = (widget.countdownDuration - _remainingTime).inMilliseconds / 1000.0;
    final progress = (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
    final secondsRemaining = _remainingTime.inSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _cancelAlert();
      },
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
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with alert icon
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF6B35),
                          Color(0xFFFF8C42),
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
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            size: 48,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Safety Check',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                          'We detected a potential fall or emergency.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1F1F1F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Are you okay?',
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
                                minHeight: 8,
                                value: progress,
                                backgroundColor: Color(0xFFEEEEEE),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  secondsRemaining <= 3
                                      ? Color(0xFFFF6B35)
                                      : Color(0xFFFF8C42),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sending SOS in ${secondsRemaining}s',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondsRemaining <= 3
                                    ? Color(0xFFFF6B35)
                                    : Color(0xFF707070),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // I am OK button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _cancelAlert,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade500,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'I Am OK',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Send SOS button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _confirmAlert,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFFFF6B35),
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Send SOS Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF6B35),
                              ),
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
      ),
    );
  }
}
