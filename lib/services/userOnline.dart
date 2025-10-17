import 'dart:async';
import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Call PresenceManager.init() once user logs in.
/// Call PresenceManager.dispose() on app exit.
class PresenceManager with WidgetsBindingObserver {
  static final PresenceManager _instance = PresenceManager._internal();
  factory PresenceManager() => _instance;
  PresenceManager._internal();

  String? userId;
  String? baseUrl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  String? token;

  final ValueNotifier<String> _status = ValueNotifier<String>('offline');
  bool _isOnChatPage = false;
  bool _hasInternet = true;
  Timer? _debounceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  ValueNotifier<String> get statusNotifier => _status;

  // ----------------------------------------------------------
  // INIT / DISPOSE
  // ----------------------------------------------------------
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // Monitor connectivity
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChange);

    // Set initial state
    final connectivity = await Connectivity().checkConnectivity();
    _hasInternet =
        connectivity.contains(ConnectivityResult.none) ? false : true;
    _updateStatus();
  }

  void dispose() {
    _connectivitySub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  // ----------------------------------------------------------
  // APP LIFECYCLE
  // ----------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _updateStatus();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _setOffline();
        break;
      case AppLifecycleState.detached:
        _setOffline();
        break;
    }
  }

  // ----------------------------------------------------------
  // CONNECTIVITY CHANGES
  // ----------------------------------------------------------
  void _onConnectivityChange(List<ConnectivityResult> result) {
    _hasInternet = result.contains(ConnectivityResult.none) ? false : true;
    _updateStatus();
  }

  // ----------------------------------------------------------
  // CHAT PAGE STATE (public methods)
  // ----------------------------------------------------------
  void onChatPageOpened() {
    _isOnChatPage = true;
    _updateStatus();
  }

  void onChatPageClosed() {
    _isOnChatPage = false;
    _updateStatus();
  }

  // ----------------------------------------------------------
  // STATUS LOGIC
  // ----------------------------------------------------------
  void _updateStatus() {
    if (!_hasInternet) return _setOffline();

    final newStatus = _isOnChatPage ? 'online' : 'away';
    if (_status.value != newStatus) {
      _status.value = newStatus;
      _notifyServer(newStatus);
    }
  }

  void _setOffline() {
    if (_status.value != 'offline') {
      _status.value = 'offline';
      _notifyServer('offline');
    }
  }

  // ----------------------------------------------------------
  // API CALL
  // ----------------------------------------------------------
  void _notifyServer(String status) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$baseUrl/api/presence/update');
      token = await UserService.getAccessToken();

      try {
        await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'status': status,
            'timestamp': timestamp,
          }),
        );
        debugPrint('Presence updated → $status');
      } catch (e) {
        debugPrint('Presence update failed: $e');
      }
    });
  }

  Future<Map<String, dynamic>> fetchMembersStatus({
    required List<String> userIds,
  }) async {
    final uri = Uri.parse('$baseUrl/api/presence/all');
    token = await UserService.getAccessToken();
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'userIds': userIds}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(
          response.body); // returns Map<userId, {status, lastSeen}>
    } else {
      throw Exception('Failed to fetch presence data');
    }
  }
}
