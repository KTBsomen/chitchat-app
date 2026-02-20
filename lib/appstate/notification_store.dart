import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local notification store.
///
/// Persists notifications fetched from the server so they survive
/// across app restarts. Handles deduplication, read/unread tracking,
/// and 7-day auto-purge.
class NotificationStore {
  static const String _keyPrefix = 'notif_store_';
  static const String _dismissedPrefix = 'notif_dismissed_';
  static const Duration _retentionPeriod = Duration(days: 7);

  /// In-memory cache: id → stored notification map
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// IDs the user explicitly dismissed — stored as {id: dismissedAt ISO string}.
  /// Auto-purged after 30 days.
  static final Map<String, String> _dismissed = {};
  static bool _initialized = false;
  static String? _lastUserId;

  // ── helpers ──────────────────────────────────────────────────────────

  static String _getUserId() {
    final profile = AppVariables.get<Map<String, dynamic>>('profile');
    return profile?['_id'] ?? 'default';
  }

  static String get _key => '$_keyPrefix${_getUserId()}';
  static String get _dismissedKey => '$_dismissedPrefix${_getUserId()}';

  // ── init / load ──────────────────────────────────────────────────────

  static Future<void> init() async {
    final uid = _getUserId();
    if (_initialized && _lastUserId == uid) return;
    _cache.clear();
    _dismissed.clear();
    _lastUserId = uid;
    await _loadFromPrefs();
    purgeOlderThan(_retentionPeriod);
    _initialized = true;
  }

  static Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        decoded.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            _cache[k] = v;
          } else if (v is Map) {
            _cache[k] = Map<String, dynamic>.from(v);
          }
        });
      } catch (e) {
        print('NotificationStore: Error loading: $e');
      }
    }
    // Load dismissed map
    final dismissedRaw = prefs.getString(_dismissedKey);
    if (dismissedRaw != null) {
      try {
        final decoded = jsonDecode(dismissedRaw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is String) _dismissed[k as String] = v;
          });
        } else if (decoded is List) {
          // Migrate old Set format → Map with current timestamp
          final now = DateTime.now().toIso8601String();
          for (final id in decoded) {
            _dismissed[id as String] = now;
          }
        }
      } catch (_) {}
    }
    _purgeDismissed();
  }

  /// Remove dismissed entries older than 30 days.
  static void _purgeDismissed() {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    _dismissed.removeWhere((_, v) {
      try {
        return DateTime.parse(v).isBefore(cutoff);
      } catch (_) {
        return true;
      }
    });
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cache));
    await prefs.setString(_dismissedKey, jsonEncode(_dismissed));
  }

  // ── public API ───────────────────────────────────────────────────────

  /// Add notifications, deduplicating by id. New ones are marked unread.
  /// Returns the number of genuinely new notifications added.
  static Future<int> addNotifications(
      List<Map<String, dynamic>> notifications) async {
    await _ensureCorrectUser();
    int added = 0;

    for (final notif in notifications) {
      final id = notif['id'] as String?;
      if (id == null) continue;

      // Skip notifications the user already dismissed
      if (_dismissed.containsKey(id)) continue;

      if (!_cache.containsKey(id)) {
        _cache[id] = {
          ...notif,
          'isRead': false,
          'storedAt': DateTime.now().toIso8601String(),
        };
        added++;
      }
    }

    if (added > 0) {
      await _persist();
    }
    return added;
  }

  /// Mark a single notification as read (keeps it in store).
  static Future<void> markAsRead(String id) async {
    await _ensureCorrectUser();
    if (_cache.containsKey(id)) {
      _cache[id]!['isRead'] = true;
      await _persist();
    }
  }

  /// Mark all notifications as read.
  static Future<void> markAllAsRead() async {
    await _ensureCorrectUser();
    for (final entry in _cache.values) {
      entry['isRead'] = true;
    }
    await _persist();
  }

  /// Remove a single notification from the store and remember its ID
  /// so it won't be re-added on next server fetch.
  static Future<void> removeNotification(String id) async {
    await _ensureCorrectUser();
    _cache.remove(id);
    _dismissed[id] = DateTime.now().toIso8601String();
    await _persist();
  }

  /// Check if a notification is unread.
  static bool isUnread(String id) {
    return _cache.containsKey(id) && _cache[id]!['isRead'] == false;
  }

  /// Get all stored notifications, sorted newest first.
  static List<Map<String, dynamic>> getAll() {
    final list = _cache.values.toList();
    list.sort((a, b) {
      final aTime = a['storedAt'] as String? ?? '';
      final bTime = b['storedAt'] as String? ?? '';
      return bTime.compareTo(aTime); // newest first
    });
    return list;
  }

  /// Get total unread count.
  static int getUnreadCount() {
    return _cache.values.where((n) => n['isRead'] == false).length;
  }

  /// Get unread count for a specific source type ('redis' or 'api').
  static int getUnreadCountForSource(String sourceType) {
    return _cache.values
        .where((n) => n['isRead'] == false && n['sourceType'] == sourceType)
        .length;
  }

  /// Remove all entries older than [duration].
  static void purgeOlderThan(Duration duration) {
    final cutoff = DateTime.now().subtract(duration);
    _cache.removeWhere((_, v) {
      final storedAt = v['storedAt'] as String?;
      if (storedAt == null) return true;
      try {
        return DateTime.parse(storedAt).isBefore(cutoff);
      } catch (_) {
        return true;
      }
    });
    // persist asynchronously — fire and forget
    _persist();
  }

  /// Clear all stored notifications.
  static Future<void> clearAll() async {
    _cache.clear();
    await _persist();
  }

  // ── internal ─────────────────────────────────────────────────────────

  static Future<void> _ensureCorrectUser() async {
    final currentUserId = _getUserId();
    if (_lastUserId != currentUserId) {
      _cache.clear();
      _dismissed.clear();
      _initialized = false;
      _lastUserId = currentUserId;
      await _loadFromPrefs();
    }
  }
}
