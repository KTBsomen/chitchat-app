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
import 'package:chitchat/services/personal_chat_service.dart';
import 'package:chitchat/services/location_service.dart';
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
  static const String _prefCachedUsers = 'cached_nearby_users_v1';

  final BeaconBroadcaster _broadcaster = BeaconBroadcaster();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothState>? _broadcasterStateSubscription;

  final ValueNotifier<bool> isBroadcastingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Map<String, NearbyUserFound>> usersFoundNotifier =
      ValueNotifier<Map<String, NearbyUserFound>>({});
  final ValueNotifier<Map<String, dynamic>?> myActiveTagNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  final Set<String> _pendingFetchIds = {};
  Timer? _fetchDebounceTimer;

  bool _isServiceInitialized = false;
  bool _shouldScan = false;
  bool _isStartingScan = false;
  DateTime? _lastScanStartTime;
  Timer? _scanWatchdogTimer;
  Timer? _stalePruneTimer;
  Timer? _locationScanTimer;
  Timer? _cacheDebounceTimer;

  /// Load cached users from SharedPreferences into usersFoundNotifier
  /// and refetch their current profile details and tags from backend.
  Future<void> loadCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedUsers);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final currentMap =
              Map<String, NearbyUserFound>.from(usersFoundNotifier.value);
          final List<String> idsToRefetch = [];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final user = NearbyUserFound.fromJson(item);
              if (user.id.isNotEmpty && !currentMap.containsKey(user.id)) {
                currentMap[user.id] = user;
                idsToRefetch.add(user.id);
              }
            }
          }
          usersFoundNotifier.value = currentMap;
          if (idsToRefetch.isNotEmpty) {
            _fetchUserDetailsBatch(idsToRefetch);
          }
        }
      }
    } catch (e) {
      debugPrint("NearbyService.loadCachedUsers error: $e");
    }
  }

  /// Debounced save of current users to SharedPreferences
  void saveCachedUsersDebounced() {
    _cacheDebounceTimer?.cancel();
    _cacheDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      saveCachedUsers();
    });
  }

  /// Save current users to SharedPreferences
  Future<void> saveCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersList =
          usersFoundNotifier.value.values.map((u) => u.toJson()).toList();
      await prefs.setString(_prefCachedUsers, jsonEncode(usersList));
    } catch (e) {
      debugPrint("NearbyService.saveCachedUsers error: $e");
    }
  }

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

  /// Called at app launch to resume foreground service, load cached profiles, and broadcasting if enabled
  static Future<void> initOnAppLaunch() async {
    final service = NearbyService.instance;
    await service.loadCachedUsers();

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
            eventAction: ForegroundTaskEventAction.repeat(30000),
            autoRunOnBoot: false,
            autoRunOnMyPackageReplaced: false,
            allowWakeLock: false,
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

  /// Start scanning for nearby beacons continuously
  Future<void> startScanning() async {
    _shouldScan = true;
    isScanningNotifier.value = true;

    try {
      // 0. Ensure cached users are loaded from local storage
      await loadCachedUsers();

      // Ensure Bluetooth is on
      if (Platform.isAndroid) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }

      // 1. Setup scan results listener BEFORE starting the scan
      if (_scanSubscription == null) {
        final myUserId = await UserService.getUserId();

        _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
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
      }

      // 2. Safely trigger scan without recursive listeners
      await _triggerScan();

      // 3. Heartbeat watchdog timer every 25s to keep scan continuously active
      _scanWatchdogTimer?.cancel();
      _scanWatchdogTimer = Timer.periodic(const Duration(seconds: 25), (t) {
        if (!_shouldScan) {
          t.cancel();
          return;
        }
        if (!FlutterBluePlus.isScanningNow) {
          debugPrint("NearbyService watchdog: scanner inactive. Triggering scan...");
          _triggerScan();
        }
      });

      // 4. Periodic UI tick: preserves cached users and triggers UI refresh for active (green) vs inactive (gray) borders
      _stalePruneTimer?.cancel();
      _stalePruneTimer = Timer.periodic(const Duration(seconds: 25), (t) {
        if (!_shouldScan) {
          t.cancel();
          return;
        }
        usersFoundNotifier.value =
            Map<String, NearbyUserFound>.from(usersFoundNotifier.value);
      });

      // 5. Periodic Location Search: search backend with GPS coordinates
      _locationScanTimer?.cancel();
      _locationScanTimer =
          Timer.periodic(const Duration(seconds: 20), (t) {
        if (!_shouldScan) {
          t.cancel();
          return;
        }
        triggerLocationSearch();
      });
      triggerLocationSearch();
    } catch (e) {
      debugPrint("NearbyService.startScanning error: $e");
    }
  }

  Future<void> _triggerScan() async {
    if (!_shouldScan) return;
    if (_isStartingScan) return;
    if (FlutterBluePlus.isScanningNow) return;

    // Cooldown check: Android enforces maximum 5 scan starts per 30 seconds (status 6 SCAN_FAILED_SCANNING_TOO_FREQUENTLY)
    final now = DateTime.now();
    if (_lastScanStartTime != null &&
        now.difference(_lastScanStartTime!).inSeconds < 8) {
      debugPrint("NearbyService: scan trigger throttled by cooldown");
      return;
    }

    _isStartingScan = true;
    _lastScanStartTime = now;

    try {
      debugPrint("NearbyService: starting BLE scan...");
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.balanced,
      );
      debugPrint("NearbyService: BLE scan started successfully");
    } catch (e) {
      debugPrint("NearbyService._triggerScan error: $e");
    } finally {
      _isStartingScan = false;
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    _shouldScan = false;
    _scanWatchdogTimer?.cancel();
    _scanWatchdogTimer = null;
    _stalePruneTimer?.cancel();
    _stalePruneTimer = null;
    _locationScanTimer?.cancel();
    _locationScanTimer = null;
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
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
    final currentMap =
        Map<String, NearbyUserFound>.from(usersFoundNotifier.value);

    if (currentMap.containsKey(userId)) {
      currentMap[userId]!.updateDistance(distanceMeters, rssi);
      currentMap[userId]!.lastSeen = DateTime.now();
      usersFoundNotifier.value = currentMap;
      if (currentMap[userId]!.details == null) {
        _queueFetchUserDetails(userId);
      }
    } else {
      currentMap[userId] = NearbyUserFound(
        id: userId,
        distanceMeters: distanceMeters,
        distanceFormatted: distanceFormatted,
        rssi: rssi,
        isLoading: true,
        lastSeen: DateTime.now(),
        discoverySource: 'bluetooth',
      );
      usersFoundNotifier.value = currentMap;
      _queueFetchUserDetails(userId);
    }
    saveCachedUsersDebounced();
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
      final actualUser = userMap.containsKey('_doc') && userMap['_doc'] is Map
          ? Map<String, dynamic>.from(userMap['_doc'] as Map)
          : Map<String, dynamic>.from(userMap);

      final uid = (actualUser['_id'] ?? actualUser['id'] ?? userMap['_id'] ?? userMap['id'])?.toString();
      if (uid != null && currentMap.containsKey(uid)) {
        if (userMap.containsKey('activeTag') && userMap['activeTag'] != null) {
          actualUser['activeTag'] = userMap['activeTag'];
        }
        currentMap[uid]!.details = actualUser;
        currentMap[uid]!.isLoading = false;
        returnedIds.add(uid);
        debugPrint("NearbyService: User $uid activeTag -> ${actualUser['activeTag']}");
      }
    }

    // Fallback: If any IDs were not returned in batch, fetch individual public profile
    for (final id in userIds) {
      if (!returnedIds.contains(id) && currentMap.containsKey(id)) {
        try {
          final profileRes =
              await UserService.fetchUserPublicProfile(dbIndex: '0', uid: id);
          if (profileRes['success'] == true && profileRes['data'] != null) {
            final profileData = Map<String, dynamic>.from(profileRes['data'] as Map);
            currentMap[id]!.details = profileData;
            currentMap[id]!.isLoading = false;
            debugPrint("NearbyService: Fallback fetched profile for $id, activeTag -> ${profileData['activeTag']}");
          } else {
            currentMap[id]!.isLoading = false;
          }
        } catch (_) {
          currentMap[id]!.isLoading = false;
        }
      }
    }

    usersFoundNotifier.value = currentMap;
    saveCachedUsersDebounced();
  }

  /// Trigger a location-based nearby query from backend
  Future<void> triggerLocationSearch() async {
    try {
      final results =
          await LocationTrackingService.instance.fetchNearbyUsers();
      if (results.isNotEmpty) {
        addLocationDiscoveredUsers(results);
      }
    } catch (e) {
      debugPrint("NearbyService.triggerLocationSearch error: $e");
    }
  }

  /// Process users discovered via server location search
  void addLocationDiscoveredUsers(
      List<Map<String, dynamic>> locationUsers) async {
    final myUserId = await UserService.getUserId();
    final currentMap =
        Map<String, NearbyUserFound>.from(usersFoundNotifier.value);
    bool changed = false;

    for (final userMap in locationUsers) {
      final actualUser = userMap.containsKey('_doc') && userMap['_doc'] is Map
          ? Map<String, dynamic>.from(userMap['_doc'] as Map)
          : Map<String, dynamic>.from(userMap);

      final uid = (actualUser['_id'] ??
              actualUser['id'] ??
              userMap['_id'] ??
              userMap['id'])
          ?.toString();
      if (uid == null || uid.isEmpty || uid == myUserId) continue;

      final distMeters =
          (userMap['distanceMeters'] as num?)?.toDouble() ?? 50.0;
      final distFormatted = userMap['distanceFormatted']?.toString() ??
          (distMeters < 1000
              ? "${distMeters.toStringAsFixed(0)}m"
              : "${(distMeters / 1000).toStringAsFixed(1)}km");

      if (currentMap.containsKey(uid)) {
        final existing = currentMap[uid]!;
        existing.details = actualUser;
        existing.isLoading = false;
        existing.lastSeen = DateTime.now();
        if (existing.discoverySource == 'location') {
          existing.distanceMeters = distMeters;
          existing.distanceFormatted = distFormatted;
        }
        changed = true;
      } else {
        currentMap[uid] = NearbyUserFound(
          id: uid,
          distanceMeters: distMeters,
          distanceFormatted: distFormatted,
          rssi: -60,
          details: actualUser,
          isLoading: false,
          lastSeen: DateTime.now(),
          discoverySource: 'location',
        );
        changed = true;
      }
    }

    if (changed) {
      usersFoundNotifier.value = currentMap;
      saveCachedUsersDebounced();
    }
  }

  /// Fetch the current user's active nearby tag from server
  Future<void> fetchMyActiveTag() async {
    try {
      final res = await PersonalChatService.getMyNearbyTag();
      if (res['success'] == true) {
        final tag = res['tag'];
        if (tag is Map) {
          myActiveTagNotifier.value = Map<String, dynamic>.from(tag);
        } else {
          myActiveTagNotifier.value = null;
        }
      }
    } catch (e) {
      debugPrint("NearbyService.fetchMyActiveTag error: $e");
    }
  }

  /// Delete / Clear the current user's active nearby tag from server
  Future<bool> deleteMyActiveTag() async {
    try {
      final res = await PersonalChatService.deleteNearbyTag();
      if (res['success'] == true) {
        myActiveTagNotifier.value = null;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("NearbyService.deleteMyActiveTag error: $e");
      return false;
    }
  }

  /// Stop all nearby services (scan, broadcast, foreground service)
  Future<void> stopAll() async {
    await stopScanning();
    await stopBroadcasting();
    await stopForegroundService();
  }
}
