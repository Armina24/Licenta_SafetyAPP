import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// ScaffoldWrapper applies the deep dark gradient background and wraps Scaffold.
/// Use this instead of plain Scaffold in dark mode to get the glassmorphism look.
class ScaffoldWrapper extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool extendBodyBehindAppBar;
  final BottomNavigationBar? bottomNavigationBar;
  final Drawer? drawer;

  const ScaffoldWrapper({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.extendBodyBehindAppBar = false,
    this.bottomNavigationBar,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.darkGradientTop,
            AppTheme.darkGradientBottom,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        drawer: drawer,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      ),
    );
  }
}
