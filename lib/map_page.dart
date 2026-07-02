import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'services/location_service.dart';
import 'ui/scaffold_wrapper.dart';
import 'config/app_theme.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  LatLng? _currentLatLng;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
      });

      LocationService.instance.getPositionStream().listen((p) {
        setState(() {
          _currentLatLng = LatLng(p.latitude, p.longitude);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDarkMode
        ? AppTheme.textPrimary
        : const Color(0xFF1F1F1F);

    if (_currentLatLng == null) {
      final loadingScaffold = Scaffold(
        appBar: AppBar(
          title: const Text('Map'),
          backgroundColor: isDarkMode
              ? Colors.transparent
              : colorScheme.primary,
          foregroundColor: isDarkMode ? AppTheme.textPrimary : Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );

      if (isDarkMode) {
        return ScaffoldWrapper(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Map'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return loadingScaffold;
    }

    final mapContent = Column(
      children: [
        if (!_hasInternet)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: isDarkMode
                ? AppTheme.accentOrange.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.1),
            child: Text(
              'Nu există conexiune la internet. Harta poate să nu se actualizeze, '
              'dar funcțiile de siguranță rămân active.\n'
              'Un SMS cu ultima locație poate fi trimis către contactele tale.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor),
            ),
          ),
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLatLng!,
              initialZoom: 15,
              maxZoom: 18,
              minZoom: 3,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.safety_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLatLng!,
                    width: 60,
                    height: 60,
                    child: Icon(
                      Icons.location_pin,
                      color: AppTheme.accentTeal,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (isDarkMode) {
      return ScaffoldWrapper(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Map'),
        ),
        body: mapContent,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: mapContent,
    );
  }
}
