import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';

/// Service responsible for managing continuous distance-streamed location updates
/// and executing nearby location-based radar searches.
class LocationTrackingService {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  static LocationTrackingService get instance => _instance;

  LocationTrackingService._internal();

  StreamSubscription<Position>? _positionStreamSub;
  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;
  Position? _lastUploadedPosition;
  DateTime? _lastUploadTime;
  bool _isUploading = false;
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Start lifecycle location streaming with a 30-meter distance filter
  /// to ensure the server is never hammered by frequent updates.
  Future<void> startLocationTracking() async {
    if (_isTracking) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("LocationTrackingService: Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint(
              "LocationTrackingService: Location permissions are denied.");
          return;
        }
      }

      _isTracking = true;

      // 1. Initial quick non-blocking snapshot upload from cache
      try {
        final initialPos = await Geolocator.getLastKnownPosition();
        if (initialPos != null) {
          _lastKnownPosition = initialPos;
          await _uploadLocationToServer(
              initialPos.latitude, initialPos.longitude);
        }
      } catch (e) {
        debugPrint(
            "LocationTrackingService initial position snapshot error: $e");
      }

      // 2. Stream distance-based updates (30m threshold)
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 30, // triggers only on 30m change
      );

      _positionStreamSub?.cancel();
      _positionStreamSub =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        _lastKnownPosition = position;
        _uploadLocationToServer(position.latitude, position.longitude);
      }, onError: (e) {
        debugPrint("LocationTrackingService position stream error: $e");
      });

      debugPrint(
          "LocationTrackingService: Location stream active (30m filter)");
    } catch (e) {
      debugPrint("LocationTrackingService.startLocationTracking error: $e");
    }
  }

  /// Send location update to backend (/location/update) with distance & time guards
  Future<void> _uploadLocationToServer(double lat, double lng) async {
    if (_isUploading) return;

    final now = DateTime.now();

    // Guard: ignore if moved less than 25m and last sync was less than 30s ago
    if (_lastUploadedPosition != null && _lastUploadTime != null) {
      final movedMeters = Geolocator.distanceBetween(
        _lastUploadedPosition!.latitude,
        _lastUploadedPosition!.longitude,
        lat,
        lng,
      );
      if (movedMeters < 25.0 && now.difference(_lastUploadTime!).inSeconds < 30) {
        return;
      }
    }

    _isUploading = true;
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return;

      final baseUrl = AppVariables.get<String>('baseurl')?.trim() ??
          'https://chitzchat.com/api/v1';

      final response = await http.post(
        Uri.parse('$baseUrl/location/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': lat,
          'longitude': lng,
        }),
      );

      if (response.statusCode == 200) {
        _lastUploadTime = now;
        _lastUploadedPosition = _lastKnownPosition;
        debugPrint("LocationTrackingService: Location synced ($lat, $lng)");
      } else {
        debugPrint(
            "LocationTrackingService: Sync returned ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("LocationTrackingService._uploadLocationToServer error: $e");
    } finally {
      _isUploading = false;
    }
  }

  /// Fetch nearby users by GPS location from server (/location/nearby)
  Future<List<Map<String, dynamic>>> fetchNearbyUsers(
      {double radiusKm = 10.0}) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return [];

      final baseUrl = AppVariables.get<String>('baseurl')?.trim() ??
          'https://chitzchat.com/api/v1';

      Position? pos = _lastKnownPosition;
      if (pos == null) {
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 6),
          );
          _lastKnownPosition = pos;
        } catch (_) {}
      }

      if (pos == null) return [];

      final response = await http.post(
        Uri.parse('$baseUrl/location/nearby'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'radiusKm': radiusKm,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      } else {
        debugPrint(
            "LocationTrackingService.fetchNearbyUsers failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("LocationTrackingService.fetchNearbyUsers error: $e");
    }
    return [];
  }

  /// Stop location tracking
  void stop() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _isTracking = false;
  }
}
