// lib/map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'services/location_service.dart';
import 'services/connectivity_service.dart';
import 'services/sms_service.dart';
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
  bool _hadInternetLastTime = true;

  List<String> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _listenConnectivity();
    _loadContacts();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
      });

      // Ascultă și stream-ul ca să se actualizeze markerul când te miști
      LocationService.instance.getPositionStream().listen((p) {
        setState(() {
          _currentLatLng = LatLng(p.latitude, p.longitude);
        });
      });
    }
  }

  void _listenConnectivity() {
    ConnectivityService.instance.onConnectivityChanged.listen((hasNet) async {
      setState(() {
        _hasInternet = hasNet;
      });

      // dacă tocmai ai pierdut netul (erai online și acum nu mai ești)
      if (!hasNet && _hadInternetLastTime) {
        await _sendLocationSms(autoTrigger: true);
      }

      _hadInternetLastTime = hasNet;
    });
  }

  Future<void> _loadContacts() async {
    final contacts = await SmsService.instance.loadEmergencyContacts();
    if (!mounted) return;
    setState(() {
      _emergencyContacts = contacts;
    });
  }

  Future<void> _sendLocationSms({bool autoTrigger = false}) async {
    if (_currentLatLng == null) return;
    if (_emergencyContacts.isEmpty) {
      if (mounted && !autoTrigger) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu ai contacte de urgență setate.')),
        );
      }
      return;
    }

    final sent = await SmsService.instance.sendLocationToContactsSilently(
      phoneNumbers: _emergencyContacts,
      latitude: _currentLatLng!.latitude,
      longitude: _currentLatLng!.longitude,
    );

    if (mounted && !autoTrigger) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Am trimis locația ta prin SMS.'
              : 'Nu am putut trimite SMS-ul. Verifică permisiunea și semnalul.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDarkMode ? AppTheme.textPrimary : const Color(0xFF1F1F1F);

    if (_currentLatLng == null) {
      final loadingScaffold = Scaffold(
        appBar: AppBar(
          title: const Text('Map'),
          backgroundColor: isDarkMode ? Colors.transparent : colorScheme.primary,
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
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _sendLocationSms,
            icon: const Icon(Icons.sms),
            label: const Text('Trimite locația mea prin SMS'),
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
