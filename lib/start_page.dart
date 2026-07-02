import 'dart:ui';
import 'package:flutter/material.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  bool _showLogo = false;
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _showLogo = true;
      });
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() {
        _showButtons = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8C42);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/kore_light_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.05)),
          ),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  AnimatedScale(
                    scale: _showLogo ? 1.0 : 0.75,
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.elasticOut,
                    child: AnimatedOpacity(
                      opacity: _showLogo ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: orange.withValues(alpha: 0.35),
                            width: 2.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(0),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/kore_logo_new.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  AnimatedOpacity(
                    opacity: _showLogo ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 1000),
                    child: Column(
                      children: [
                        const Text(
                          'Kore',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Protected. Connected. Prepared.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: const Color(0xFF4F4F4F),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  AnimatedOpacity(
                    opacity: _showButtons ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 800),
                    child: AnimatedSlide(
                      offset: _showButtons
                          ? Offset.zero
                          : const Offset(0, 0.15),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Welcome',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F1F1F),
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _showButtons
                                          ? () {
                                              Navigator.pushNamed(
                                                context,
                                                '/signup',
                                              );
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        elevation: 4,
                                        shadowColor: orange.withValues(
                                          alpha: 0.3,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Sign up',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: _showButtons
                                          ? () {
                                              Navigator.pushNamed(
                                                context,
                                                '/login',
                                              );
                                            }
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: orange,
                                        side: BorderSide(
                                          color: orange.withValues(alpha: 0.5),
                                          width: 1.8,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
