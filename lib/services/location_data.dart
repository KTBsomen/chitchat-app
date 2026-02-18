import 'dart:convert';
import 'package:flutter/services.dart';

/// Service to load and provide access to India states and districts data
class LocationDataService {
  static List<Map<String, dynamic>>? _cachedData;
  static bool _isLoading = false;

  /// Load the states and districts data from assets
  static Future<void> loadData() async {
    if (_cachedData != null || _isLoading) return;

    _isLoading = true;
    try {
      final String jsonString = await rootBundle.loadString(
        'lib/constants/india-states-districts-latest.json',
      );
      final List<dynamic> data = json.decode(jsonString);
      _cachedData = data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error loading location data: $e');
      _cachedData = [];
    } finally {
      _isLoading = false;
    }
  }

  /// Get all states
  static Future<List<String>> getStates() async {
    await loadData();
    if (_cachedData == null) return [];

    return _cachedData!.map((item) => item['state'] as String).toList();
  }

  /// Get districts for a specific state
  static Future<List<String>> getDistricts(String stateName) async {
    await loadData();
    if (_cachedData == null) return [];

    final stateData = _cachedData!.firstWhere(
      (item) => item['state'] == stateName,
      orElse: () => {'districts': <String>[]},
    );

    return (stateData['districts'] as List<dynamic>)
        .map((d) => d as String)
        .toList();
  }

  /// Search states by query
  static Future<List<String>> searchStates(String query) async {
    final states = await getStates();
    if (query.isEmpty) return states;

    final lowerQuery = query.toLowerCase();
    return states
        .where((state) => state.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Search districts by query within a specific state
  static Future<List<String>> searchDistricts(
      String stateName, String query) async {
    final districts = await getDistricts(stateName);
    if (query.isEmpty) return districts;

    final lowerQuery = query.toLowerCase();
    return districts
        .where((district) => district.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Clear cached data (useful for testing or memory management)
  static void clearCache() {
    _cachedData = null;
  }
}
