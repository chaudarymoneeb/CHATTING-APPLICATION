// lib/helpers/connectivity_helper.dart

// ignore_for_file: depend_on_referenced_packages

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityHelper {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device is online
  static Future<bool> isOnline() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('Connectivity error: $e');
      return true; // Assume online if error
    }
  }

  /// Listen to connectivity changes
  static Stream<bool> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged
        .map((result) => !result.contains(ConnectivityResult.none))
        .distinct(); // Only emit when state changes
  }
}
