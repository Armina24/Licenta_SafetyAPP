import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class GoogleGeocodingService {
  final String apiKey;

  const GoogleGeocodingService(this.apiKey);

  Future<LatLng> geocode(String address) async {
    final uri = Uri.parse('https://maps.googleapis.com/maps/api/geocode/json')
        .replace(
          queryParameters: {
            'address': address,
            'key': apiKey,
            'region': 'ro',
            'language': 'ro',
          },
        );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Geocoding failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];
    if (results.isEmpty) {
      throw Exception('Nu am găsit adresa.');
    }

    final location =
        results.first['geometry']['location'] as Map<String, dynamic>;
    return LatLng(
      (location['lat'] as num).toDouble(),
      (location['lng'] as num).toDouble(),
    );
  }
}

class GoogleRoutesService {
  final String apiKey;

  const GoogleRoutesService(this.apiKey);

  Future<GoogleRoute> computeRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.legs.steps.navigationInstruction,routes.legs.steps.endLocation',
      },
      body: jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'WALK',
        'routingPreference': 'ROUTING_PREFERENCE_UNSPECIFIED',
        'computeAlternativeRoutes': false,
        'languageCode': 'ro',
        'units': 'METRIC',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Routes failed: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? [];
    if (routes.isEmpty) {
      throw Exception('Nu am găsit traseu.');
    }

    final route = routes.first as Map<String, dynamic>;
    final polyline =
        (route['polyline'] as Map<String, dynamic>)['encodedPolyline']
            as String;

    final legs = (route['legs'] as List?) ?? [];
    final steps = <NavStep>[];
    for (final leg in legs) {
      final legSteps = (leg as Map<String, dynamic>)['steps'] as List? ?? [];
      for (final step in legSteps) {
        final stepMap = step as Map<String, dynamic>;
        final instruction =
            (stepMap['navigationInstruction']
                    as Map<String, dynamic>?)?['instructions']
                as String?;
        final endLoc =
            (stepMap['endLocation'] as Map<String, dynamic>?)?['latLng']
                as Map<String, dynamic>?;
        if (instruction == null || endLoc == null) {
          continue;
        }
        steps.add(
          NavStep(
            instruction: instruction,
            endLocation: LatLng(
              (endLoc['latitude'] as num).toDouble(),
              (endLoc['longitude'] as num).toDouble(),
            ),
          ),
        );
      }
    }

    return GoogleRoute(
      polyline: decodePolyline(polyline),
      steps: steps,
      distanceMeters: (route['distanceMeters'] as num?)?.toInt() ?? 0,
      duration: route['duration'] as String?,
    );
  }
}

class GoogleRoute {
  final List<LatLng> polyline;
  final List<NavStep> steps;
  final int distanceMeters;
  final String? duration;

  const GoogleRoute({
    required this.polyline,
    required this.steps,
    required this.distanceMeters,
    this.duration,
  });
}

List<LatLng> decodePolyline(String encoded) {
  final List<LatLng> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}
