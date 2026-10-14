import 'dart:math';
import 'package:convert/convert.dart';
import 'package:chitchat/utils/object_id_converter.dart';

/// A model representing a nearby user discovered via Bluetooth beacon.
class NearbyUserFound {
  final String id; // MongoDB ObjectId
  double distanceMeters;
  String distanceFormatted;
  int rssi;
  Map<String, dynamic>? details;
  bool isLoading;
  DateTime lastSeen;
  String discoverySource;

  NearbyUserFound({
    required this.id,
    required this.distanceMeters,
    required this.distanceFormatted,
    required this.rssi,
    this.details,
    this.isLoading = true,
    DateTime? lastSeen,
    this.discoverySource = 'bluetooth',
  }) : lastSeen = lastSeen ?? DateTime.now();

  void updateDistance(double newDistance, int newRssi) {
    // Apply smoothing to reduce jitter in RSSI/distance estimates
    distanceMeters = (distanceMeters * 0.4) + (newDistance * 0.6);
    distanceFormatted = "${distanceMeters.toStringAsFixed(1)}m";
    rssi = newRssi;
    lastSeen = DateTime.now();
  }

  bool get isRecentlyActive {
    return DateTime.now().difference(lastSeen).inMinutes < 5;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'distanceMeters': distanceMeters,
        'distanceFormatted': distanceFormatted,
        'rssi': rssi,
        'details': details,
        'isLoading': isLoading,
        'lastSeen': lastSeen.toIso8601String(),
        'discoverySource': discoverySource,
      };

  factory NearbyUserFound.fromJson(Map<String, dynamic> json) => NearbyUserFound(
        id: json['id']?.toString() ?? '',
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 50.0,
        distanceFormatted: json['distanceFormatted']?.toString() ?? 'Nearby',
        rssi: (json['rssi'] as num?)?.toInt() ?? -70,
        details: json['details'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['details'])
            : (json['details'] is Map ? Map<String, dynamic>.from(json['details']) : null),
        isLoading: json['isLoading'] ?? false,
        lastSeen: json['lastSeen'] != null
            ? DateTime.tryParse(json['lastSeen'].toString()) ?? DateTime.now()
            : DateTime.now(),
        discoverySource: json['discoverySource']?.toString() ?? 'bluetooth',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyUserFound &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A utility class to extract beacon data from BLE advertisements and calculate distance.
class BeaconExtractor {
  /// Extracts iBeacon data from manufacturer data and calculates estimated distance.
  static Map<String, dynamic>? extractIBeacon(
      Map<int, List<int>> manufacturerData, int rssi) {
    const appleManufacturerId = 0x004C;
    if (!manufacturerData.containsKey(appleManufacturerId)) return null;

    final rawData = manufacturerData[appleManufacturerId]!;
    // Standard iBeacon packet is 23+ bytes starting with 0x02, 0x15
    if (rawData.length < 23 || rawData[0] != 0x02 || rawData[1] != 0x15) {
      return null;
    }

    try {
      final uuidHex = hex.encode(rawData.sublist(2, 18));
      final formattedUuid = _formatUuid(uuidHex);
      final objectId = uuidToObjectId(formattedUuid);
      final txPower = _toSigned(rawData[22]);
      final distance = _calculateDistance(txPower, rssi);

      return {
        'type': 'iBeacon',
        'uuid': formattedUuid,
        'objectId': objectId,
        'major': (rawData[18] << 8) + rawData[19],
        'minor': (rawData[20] << 8) + rawData[21],
        'txPower': txPower,
        'distanceMeters': distance,
        'distanceFormatted': '${distance.toStringAsFixed(1)}m',
        'rssi': rssi,
      };
    } catch (e) {
      // If conversion fails (not a valid encoded ObjectId), skip silently
      return null;
    }
  }

  /// Extracts AltBeacon data from manufacturer data and calculates estimated distance.
  static Map<String, dynamic>? extractAltBeacon(
      Map<int, List<int>> manufacturerData, int rssi) {
    const altBeaconManufacturerId = 0x0118; // Radius Networks
    if (!manufacturerData.containsKey(altBeaconManufacturerId)) return null;

    final rawData = manufacturerData[altBeaconManufacturerId]!;
    if (rawData.length < 25 || rawData[0] != 0xBE || rawData[1] != 0xAC) {
      return null;
    }

    try {
      final uuidHex = hex.encode(rawData.sublist(4, 20));
      final formattedUuid = _formatUuid(uuidHex);
      final objectId = uuidToObjectId(formattedUuid);
      final txPower = _toSigned(rawData[2]);
      final distance = _calculateDistance(txPower, rssi);

      return {
        'type': 'AltBeacon',
        'uuid': formattedUuid,
        'objectId': objectId,
        'major': (rawData[20] << 8) + rawData[21],
        'minor': (rawData[22] << 8) + rawData[23],
        'txPower': txPower,
        'distanceMeters': distance,
        'distanceFormatted': '${distance.toStringAsFixed(1)}m',
        'rssi': rssi,
      };
    } catch (e) {
      return null;
    }
  }

  /// Formats a raw 32-character hexadecimal string into canonical 8-4-4-4-12 UUID.
  static String _formatUuid(String uuid) {
    if (uuid.length != 32) return uuid;
    return '${uuid.substring(0, 8)}-'
        '${uuid.substring(8, 12)}-'
        '${uuid.substring(12, 16)}-'
        '${uuid.substring(16, 20)}-'
        '${uuid.substring(20)}';
  }

  /// Converts an unsigned 8-bit integer to a signed integer (-128 to 127).
  static int _toSigned(int value) {
    return value > 127 ? value - 256 : value;
  }

  /// Estimates distance in meters using RSSI and Tx Power:
  /// Formula: d = 10 ^ ((TxPower - RSSI) / (10 * N))
  /// where N is the path loss exponent (~2.0 - 2.5 indoors).
  static double _calculateDistance(int txPower, int rssi) {
    if (rssi == 0) return -1.0;
    const double pathLossExponent = 2.2;
    final ratio = (txPower - rssi) / (10.0 * pathLossExponent);
    double dist = pow(10, ratio).toDouble();
    if (dist < 0.1) dist = 0.1;
    if (dist > 100.0) dist = 100.0;
    return dist;
  }
}
