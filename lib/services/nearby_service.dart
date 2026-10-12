import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothState;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:beacon_broadcaster/beacon_broadcaster.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/beacon_extractor.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/utils/object_id_converter.dart';

/// Top-level callback required for FlutterForegroundTask
@pragma('vm:entry-point')
void startNearbyCallback() {
  FlutterForegroundTask.setTaskHandler(NearbyForegroundTaskHandler());
}

class NearbyForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('NearbyForegroundTaskHandler: Started by ${starter.name}');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep-alive heartbeat
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('NearbyForegroundTaskHandler: Destroyed (timeout: $isTimeout)');
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'stop') {
      await NearbyService.instance.stopAll();
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

class NearbyService {
  static final NearbyService _instance = NearbyService._internal();
  static NearbyService get instance => _instance;

  NearbyService._internal();

  static const String _prefNearbyEnabled = 'nearby_beacon_enabled';

  final BeaconBroadcaster _broadcaster = BeaconBroadcaster();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothState>? _broadcasterStateSubscription;

  final ValueNotifier<bool> isBroadcastingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, NearbyUserFound>> usersFoundNotifier =
      ValueNotifier<Map<String, NearbyUserFound>>({});

  final Set<String> _pendingFetchIds = {};
  Timer? _fetchDebounceTimer;

  bool _isServiceInitialized = false;

  /// Check if user has explicitly enabled nearby beacon discovery and permissions are granted
  Future<bool> hasUserEnabledNearby() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefNearbyEnabled) ?? false;
  }

  /// Check if actual system permissions are granted
  Future<bool> arePermissionsGranted() async {
    if (Platform.isAndroid) {
      final scan = await Permission.bluetoothScan.isGranted;
      final adv = await Permission.bluetoothAdvertise.isGranted;
      final conn = await Permission.bluetoothConnect.isGranted;
      final loc = await Permission.location.isGranted;
      // On Android 12+, Bluetooth permissions are required
      return (scan && adv && conn) || loc;
    } else if (Platform.isIOS) {
      final bt = await Permission.bluetooth.isGranted;
      final loc = await Permission.location.isGranted;
      return bt && loc;
    }
    return true;
  }

  /// Request all required permissions with user consent
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Request Bluetooth and Location
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.location,
          Permission.notification,
        ].request();

        bool granted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) ||
            (statuses[Permission.location]?.isGranted ?? false);

        if (granted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_prefNearbyEnabled, true);

          // Request ignoring battery optimization to prevent OS from killing beacon broadcast
          if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
            await FlutterForegroundTask.requestIgnoreBatteryOptimization();
          }

          await startForegroundService();
          await startBroadcasting();
          return true;
        } else {
          return false;
        }
      } else if (Platform.isIOS) {
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetooth,
          Permission.locationWhenInUse,
        ].request();

        bool granted = statuses[Permission.bluetooth]?.isGranted ?? false;
        if (granted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_prefNearbyEnabled, true);
          await startBroadcasting();
          return true;
        }
        return false;
      }
      return false;
    } catch (e) {
      debugPrint("Error requesting permissions: $e");
      return false;
    }
  }

  /// Called at app launch to resume foreground service and broadcasting if enabled
  static Future<void> initOnAppLaunch() async {
    final service = NearbyService.instance;
    final enabled = await service.hasUserEnabledNearby();
    if (!enabled) return;

    final userId = await UserService.getUserId();
    if (userId == null || userId.isEmpty) return;

    debugPrint("NearbyService: Initializing on app launch for user $userId");
    await service.startForegroundService();
    await service.startBroadcasting();
  }

  /// Initialize and start the foreground task service
  Future<void> startForegroundService() async {
    if (Platform.isAndroid) {
      if (!_isServiceInitialized) {
        FlutterForegroundTask.init(
          androidNotificationOptions: AndroidNotificationOptions(
            channelId: 'chitchat_nearby_beacon',
            channelName: 'Nearby Discovery Service',
            channelDescription:
                'Broadcasts BLE beacon to discover and connect with nearby friends.',
            channelImportance: NotificationChannelImportance.LOW,
            priority: NotificationPriority.LOW,
            onlyAlertOnce: true,
          ),
          iosNotificationOptions: const IOSNotificationOptions(
            showNotification: false,
            playSound: false,
          ),
          foregroundTaskOptions: ForegroundTaskOptions(
            eventAction: ForegroundTaskEventAction.repeat(15000),
            autoRunOnBoot: true,
            autoRunOnMyPackageReplaced: true,
            allowWakeLock: true,
            allowWifiLock: false,
          ),
        );
        _isServiceInitialized = true;
      }

      if (await FlutterForegroundTask.isRunningService) {
        return;
      }

      await FlutterForegroundTask.startService(
        serviceId: 101,
        notificationTitle: 'Chitchat Nearby Active',
        notificationText: 'Broadcasting your presence to nearby college friends',
        notificationButtons: [
          const NotificationButton(
            id: 'stop',
            text: 'Stop',
          ),
        ],
        callback: startNearbyCallback,
      );
    }
  }

  /// Stop foreground task service
  Future<void> stopForegroundService() async {
    if (Platform.isAndroid && await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// Start beacon broadcasting using beacon_broadcaster
  Future<void> startBroadcasting() async {
    final userId = await UserService.getUserId();
    if (userId == null || userId.length != 24) {
      debugPrint("NearbyService.startBroadcasting: Invalid userId: $userId");
      return;
    }

    try {
      final encodedUUID = objectIdToUUID(userId);
      debugPrint("NearbyService: Starting beacon advertising with UUID: $encodedUUID");

      _broadcasterStateSubscription?.cancel();
      _broadcasterStateSubscription = _broadcaster.bluetoothState.listen((state) {
        debugPrint("NearbyService: Broadcaster state: $state");
        isBroadcastingNotifier.value = (state == BluetoothState.beaconing);
      });

      await _broadcaster.stopAdvertising();

      await _broadcaster.startAdvertising(
        uuid: encodedUUID,
        major: 100,
        minor: 1,
        txPower: -59,
        advertiseMode: AndroidBleAdvertiseSettings.advertiseModeBalanced,
        advertiseTxPower: AndroidBleAdvertiseSettings.advertiseTxPowerMedium,
      );

      isBroadcastingNotifier.value = true;
    } catch (e) {
      debugPrint("NearbyService.startBroadcasting error: $e");
    }
  }

  /// Stop beacon broadcasting
  Future<void> stopBroadcasting() async {
    try {
      await _broadcaster.stopAdvertising();
      isBroadcastingNotifier.value = false;
      await _broadcasterStateSubscription?.cancel();
      _broadcasterStateSubscription = null;
    } catch (e) {
      debugPrint("NearbyService.stopBroadcasting error: $e");
    }
  }

  /// Start scanning for nearby beacons
  Future<void> startScanning() async {
    if (isScanningNotifier.value) return;

    try {
      // Ensure Bluetooth is on
      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }

      await _scanSubscription?.cancel();
      isScanningNotifier.value = true;

      // Start BLE scan with continuous updates for dynamic distance estimation
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 45),
        continuousUpdates: true,
      );

      final myUserId = await UserService.getUserId();

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          // Look for iBeacon manufacturer data
          final beaconData = BeaconExtractor.extractIBeacon(
            r.advertisementData.manufacturerData,
            r.rssi,
          ) ?? BeaconExtractor.extractAltBeacon(
            r.advertisementData.manufacturerData,
            r.rssi,
          );

          if (beaconData != null) {
            final String targetUserId = beaconData['objectId'];
            final double distanceMeters = beaconData['distanceMeters'];
            final String distanceFormatted = beaconData['distanceFormatted'];
            final int rssi = beaconData['rssi'];

            // Skip discovering oneself
            if (myUserId != null && targetUserId == myUserId) {
              continue;
            }

            _onBeaconDiscovered(
              targetUserId,
              distanceMeters,
              distanceFormatted,
              rssi,
            );
          }
        }
      });
    } catch (e) {
      debugPrint("NearbyService.startScanning error: $e");
      isScanningNotifier.value = false;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      isScanningNotifier.value = false;
    } catch (e) {
      debugPrint("NearbyService.stopScanning error: $e");
    }
  }

  /// Internal handler when a beacon is found or updated
  void _onBeaconDiscovered(
    String userId,
    double distanceMeters,
    String distanceFormatted,
    int rssi,
  ) {
    final currentMap = Map<String, NearbyUserFound>.from(usersFoundNotifier.value);

    if (currentMap.containsKey(userId)) {
      currentMap[userId]!.updateDistance(distanceMeters, rssi);
      usersFoundNotifier.value = currentMap;
    } else {
      currentMap[userId] = NearbyUserFound(
        id: userId,
        distanceMeters: distanceMeters,
        distanceFormatted: distanceFormatted,
        rssi: rssi,
        isLoading: true,
      );
      usersFoundNotifier.value = currentMap;
      _queueFetchUserDetails(userId);
    }
  }

  /// Queue a user ID to fetch details from backend
  void _queueFetchUserDetails(String userId) {
    _pendingFetchIds.add(userId);
    _fetchDebounceTimer?.cancel();
    _fetchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (_pendingFetchIds.isNotEmpty) {
        final idsToFetch = List<String>.from(_pendingFetchIds);
        _pendingFetchIds.clear();
        _fetchUserDetailsBatch(idsToFetch);
      }
    });
  }

  /// Batch fetch user details from server
  Future<void> _fetchUserDetailsBatch(List<String> userIds) async {
    final baseurl =
        AppVariables.get<String>('baseurl')?.trim() ?? 'https://chitzchat.com/api/v1';
    final token = await UserService.getAccessToken();

    List<Map<String, dynamic>> results = [];

    // Attempt 1: POST /getDetailsForIds
    try {
      final response = await http.post(
        Uri.parse('$baseurl/getDetailsForIds'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'ids': userIds}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          results = decoded.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint("Error fetching from /getDetailsForIds: $e");
    }

    // Attempt 2: If empty, try /get/user/likes endpoint
    if (results.isEmpty) {
      try {
        final likeRes = await UserService.fetchUserLikes(ids: userIds);
        if (likeRes['success'] == true && likeRes['data'] != null) {
          final data = likeRes['data'];
          if (data is List) {
            results = data.cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        debugPrint("Error fetching from fetchUserLikes: $e");
      }
    }

    // Update usersFoundNotifier with fetched details
    final currentMap = Map<String, NearbyUserFound>.from(usersFoundNotifier.value);
    final returnedIds = <String>{};

    for (final userMap in results) {
      final uid = (userMap['_id'] ?? userMap['id'])?.toString();
      if (uid != null && currentMap.containsKey(uid)) {
        currentMap[uid]!.details = userMap;
        currentMap[uid]!.isLoading = false;
        returnedIds.add(uid);
      }
    }

    // Fallback: If any IDs were not returned in batch, fetch individual public profile
    for (final id in userIds) {
      if (!returnedIds.contains(id) && currentMap.containsKey(id)) {
        try {
          final profileRes =
              await UserService.fetchUserPublicProfile(dbIndex: '0', uid: id);
          if (profileRes['success'] == true && profileRes['data'] != null) {
            currentMap[id]!.details = profileRes['data'] as Map<String, dynamic>;
            currentMap[id]!.isLoading = false;
          } else {
            // Keep with basic placeholder if not found
            currentMap[id]!.isLoading = false;
          }
        } catch (_) {
          currentMap[id]!.isLoading = false;
        }
      }
    }

    usersFoundNotifier.value = currentMap;
  }

  /// Stop all nearby services (scan, broadcast, foreground service)
  Future<void> stopAll() async {
    await stopScanning();
    await stopBroadcasting();
    await stopForegroundService();
  }
}
