import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged async* {
    yield await hasInternetNow();

    yield* _connectivity.onConnectivityChanged.asyncMap((results) async {
      return results.any((result) => result != ConnectivityResult.none);
    });
  }

  Future<bool> hasInternetNow() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
