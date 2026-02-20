import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:chitchat/appstate/notification_store.dart';
import 'package:chitchat/services/chats.dart';

/// Centralized notification polling manager.
///
/// This singleton ensures only ONE polling timer exists across the entire app,
/// preventing duplicate API calls that cause rate limiting.
class NotificationManager {
  static NotificationManager? _instance;
  static NotificationManager get instance {
    if (_instance == null) {
      _instance = NotificationManager._();
      _instance!.initialize();
    }
    return _instance!;
  }

  NotificationManager._();

  // ValueNotifiers for reactive UI updates
  final ValueNotifier<int> notificationCount = ValueNotifier<int>(0);
  final ValueNotifier<int> messageCount = ValueNotifier<int>(0);

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isInitialized = false;

  // Rate limit backoff
  int _consecutiveFailures = 0;
  static const int _maxBackoffSeconds = 300;

  /// Initialize the notification manager and start polling.
  /// Call this once at app startup (e.g., in main.dart after login).
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Initialize the local notification store
    await NotificationStore.init();

    // Fetch initial counts from local store
    _syncCountFromStore();

    // Start polling every 30 seconds
    _startPolling();
  }

  /// Stop polling (call on logout)
  void dispose() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isInitialized = false;
    _consecutiveFailures = 0;
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchCounts();
    });
  }

  Future<void> _fetchCounts() async {
    if (_isPolling) {
      debugPrint('NotificationManager: Skipping poll (previous still running)');
      return;
    }

    _isPolling = true;

    try {
      // Sync notification count from local store
      _syncCountFromStore();

      // Fetch message count
      final msgCount = await ChatServices.getMessageNotificationCount();
      messageCount.value = msgCount;

      _consecutiveFailures = 0;

      debugPrint(
          'NotificationManager: counts fetched - notif=${notificationCount.value}, msg=$msgCount');
    } catch (e) {
      _consecutiveFailures++;
      debugPrint(
          'NotificationManager: Error fetching counts: $e (failures: $_consecutiveFailures)');

      if (_consecutiveFailures >= 3) {
        final backoffSeconds =
            (_consecutiveFailures * 30).clamp(30, _maxBackoffSeconds);
        debugPrint(
            'NotificationManager: Applying backoff of ${backoffSeconds}s');
        _pollingTimer?.cancel();
        _pollingTimer = Timer(Duration(seconds: backoffSeconds), () {
          _startPolling();
          _fetchCounts();
        });
      }
    } finally {
      _isPolling = false;
    }
  }

  /// Sync the notification count from the local store.
  void _syncCountFromStore() {
    notificationCount.value = NotificationStore.getUnreadCount();
  }

  /// Mark a notification as read and update count.
  Future<void> markAsRead(String id) async {
    await NotificationStore.markAsRead(id);
    _syncCountFromStore();
  }

  /// Mark all notifications as read and update count.
  Future<void> markAllAsRead() async {
    await NotificationStore.markAllAsRead();
    _syncCountFromStore();
  }

  /// Called after new notifications are added to the store.
  void refreshCount() {
    _syncCountFromStore();
  }

  /// Reset message notification count
  Future<void> resetMessageCount() async {
    await ChatServices.resetMessageNotificationCount();
    messageCount.value = 0;
  }

  /// Force refresh notification count
  Future<void> refresh() async {
    await _fetchCounts();
  }
}
