import 'dart:io';

import 'package:flutter/foundation.dart';

const String _envBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

class ApiClient {
  ApiClient._() : baseUrl = _resolveBaseUrl();

  static final ApiClient instance = ApiClient._();

  final String baseUrl;

  static String _resolveBaseUrl() {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:4000';
    }

    if (Platform.isAndroid) {
      return 'http://192.168.1.134:4000';
    }

    return 'http://localhost:4000';
  }

  Uri buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(baseUrl).replace(
      path: normalizedPath,
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}
