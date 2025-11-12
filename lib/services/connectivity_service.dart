// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Stream simplu: true = ai net, false = nu ai.
  Stream<bool> get onConnectivityChanged async* {
    // trimite starea curentă la început
    yield await hasInternetNow();

    // apoi ascultă schimbările
    yield* _connectivity.onConnectivityChanged.asyncMap((results) async {
      return results.any((result) => result != ConnectivityResult.none);
    });
  }

  /// Verifică în acest moment dacă ai internet.
  Future<bool> hasInternetNow() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
