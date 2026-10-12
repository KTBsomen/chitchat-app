import 'package:flutter_test/flutter_test.dart';
import 'package:chitchat/utils/object_id_converter.dart';
import 'package:chitchat/services/beacon_extractor.dart';

void main() {
  group('ObjectId <-> UUID conversion tests', () {
    test('Round-trip conversion preserves 24-character MongoDB ObjectId', () {
      final sampleObjectIds = [
        "507f1f77bcf86cd799439011",
        "67d59d04ee8e18f79b52bec1",
        "673f607d6fbb68a8c5368967",
        "000000000000000000000000",
        "ffffffffffffffffffffffff",
      ];

      for (final id in sampleObjectIds) {
        final uuid = objectIdToUUID(id);
        expect(uuid.length, 36);
        expect(uuid[14], '4'); // UUID v4 version bit
        expect(['8', '9', 'a', 'b'].contains(uuid[19].toLowerCase()), isTrue); // UUID RFC variant bits

        final recoveredId = uuidToObjectId(uuid);
        expect(recoveredId, id.toLowerCase());
      }
    });

    test('BeaconExtractor correctly calculates distance and extracts iBeacon data', () {
      const appleManufacturerId = 0x004C;
      final rawObjectId = "507f1f77bcf86cd799439011";
      final uuidStr = objectIdToUUID(rawObjectId).replaceAll('-', '');

      // Parse 16 bytes UUID
      final uuidBytes = <int>[];
      for (int i = 0; i < 32; i += 2) {
        uuidBytes.add(int.parse(uuidStr.substring(i, i + 2), radix: 16));
      }

      // Build iBeacon 23 bytes payload
      final payload = <int>[
        0x02, 0x15, // iBeacon header
        ...uuidBytes,
        0x00, 0x64, // Major = 100
        0x00, 0x01, // Minor = 1
        197, // TxPower = -59 (in 8-bit unsigned: 256 - 59 = 197)
      ];

      final manufacturerData = {
        appleManufacturerId: payload,
      };

      final extracted = BeaconExtractor.extractIBeacon(manufacturerData, -65);
      expect(extracted, isNotNull);
      expect(extracted!['type'], 'iBeacon');
      expect(extracted['objectId'], rawObjectId.toLowerCase());
      expect(extracted['major'], 100);
      expect(extracted['minor'], 1);
      expect(extracted['txPower'], -59);
      expect(extracted['distanceMeters'], greaterThan(0));
    });

    test('Nearby threshold caps radar display at 15 and calculates extra count', () {
      final List<NearbyUserFound> users = List.generate(
        22,
        (i) => NearbyUserFound(
          id: '60c72b2f9b1d8b2bad1234${i.toString().padLeft(2, '0')}',
          distanceMeters: (i + 1) * 0.8,
          distanceFormatted: "${((i + 1) * 0.8).toStringAsFixed(1)}m",
          rssi: -60,
        ),
      );

      const int maxRadarPlanets = 15;
      final displayedUsers = users.length > maxRadarPlanets
          ? users.take(maxRadarPlanets).toList()
          : users;
      final extraCount = users.length > maxRadarPlanets
          ? users.length - maxRadarPlanets
          : 0;

      expect(displayedUsers.length, 15);
      expect(extraCount, 7);
      expect(users.length, 22);
    });
  });
}
