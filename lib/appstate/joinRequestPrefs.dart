import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which groups the current user has pending join requests for.
/// Stores a mapping of groupId → { requestId, groupName, timestamp, expiresAt }
/// Persisted via SharedPreferences, scoped per user account.
class JoinRequestPrefs {
  static const String _keyPrefix = 'pending_join_requests_';
  static const Duration _defaultExpiry = Duration(days: 1);

  /// groupId → request metadata
  static final Map<String, Map<String, dynamic>> _cache = {};
  static bool _initialized = false;
  static String? _lastUserId;

  // ── helpers ──────────────────────────────────────────────────────────

  static String _getUserId() {
    final profile = AppVariables.get<Map<String, dynamic>>('profile');
    return profile?['_id'] ?? 'default';
  }

  static String get _key => '$_keyPrefix${_getUserId()}';

  // ── init / load ──────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_initialized && _lastUserId == _getUserId()) return;
    _cache.clear();
    _lastUserId = _getUserId();
    await _loadFromPrefs();
    purgeExpired();
  }

  static Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data != null) {
      try {
        final Map<String, dynamic> map = jsonDecode(data);
        map.forEach((k, v) {
          if (v is Map) {
            _cache[k] = Map<String, dynamic>.from(v);
          } else if (v is String) {
            // Migrate old format (groupId → requestId string)
            _cache[k] = {
              'requestId': v,
              'timestamp': DateTime.now().toIso8601String(),
              'expiresAt': DateTime.now().add(_defaultExpiry).toIso8601String(),
            };
          }
        });
      } catch (e) {
        print('JoinRequestPrefs: Error loading: $e');
      }
    }
    _initialized = true;
  }

  // ── public API ───────────────────────────────────────────────────────

  /// Mark a group as having a pending join request.
  static Future<void> markRequested(String groupId, String requestId,
      {String? groupName, Duration? expiry}) async {
    await _ensureCorrectUser();
    final now = DateTime.now();
    _cache[groupId] = {
      'requestId': requestId,
      'groupName': groupName,
      'timestamp': now.toIso8601String(),
      'expiresAt': now.add(expiry ?? _defaultExpiry).toIso8601String(),
      'votes': 0,
      'totalMembers': 0,
    };
    await _persist();
  }

  static Future<void> unmarkRequested(String groupId) async {
    await _ensureCorrectUser();
    _cache.remove(groupId);
    await _persist();
  }

  /// Synchronous check — caller must ensure [init] was called first.
  static bool hasRequestedSync(String groupId) {
    final currentUserId = _getUserId();
    if (_lastUserId != currentUserId) return false;
    return _cache.containsKey(groupId);
  }

  /// Get the stored request ID for a group (null if none).
  static String? getRequestId(String groupId) {
    return _cache[groupId]?['requestId'] as String?;
  }

  /// Get all pending (non-expired) request entries.
  /// Returns list of { groupId, requestId, groupName, timestamp, expiresAt, votes, totalMembers }
  static List<Map<String, dynamic>> getAllPending() {
    purgeExpired();
    return _cache.entries.map((e) => {'groupId': e.key, ...e.value}).toList();
  }

  /// Get all request IDs for the batch status API.
  static List<String> getAllRequestIds() {
    purgeExpired();
    return _cache.values
        .map((v) => v['requestId'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();
  }

  /// Update statuses from server batch response.
  /// [results] = list of { _id, votes, totalMembers, status, groupName, groupPic, ... }
  /// Missing IDs from server → expired/rejected → remove from prefs.
  static Future<void> updateStatuses(
      List<Map<String, dynamic>> results, List<String> queriedIds) async {
    await _ensureCorrectUser();

    final returnedIds = results.map((r) => r['_id'] as String).toSet();

    // Remove entries whose request ID was queried but not returned (expired/rejected)
    _cache.removeWhere((groupId, meta) {
      final reqId = meta['requestId'] as String?;
      return reqId != null &&
          queriedIds.contains(reqId) &&
          !returnedIds.contains(reqId);
    });

    // Update returned entries with vote info
    for (final result in results) {
      final reqId = result['_id'] as String?;
      if (reqId == null) continue;

      // Find the cache entry with this requestId
      final entry = _cache.entries.firstWhere(
        (e) => e.value['requestId'] == reqId,
        orElse: () => MapEntry('', {}),
      );
      if (entry.key.isNotEmpty) {
        _cache[entry.key]!['votes'] = result['votes'] ?? 0;
        _cache[entry.key]!['totalMembers'] = result['totalMembers'] ?? 1;
        _cache[entry.key]!['status'] = result['status'];
        if (result['groupName'] != null) {
          _cache[entry.key]!['groupName'] = result['groupName'];
        }
        if (result['groupPic'] != null) {
          _cache[entry.key]!['groupPic'] = result['groupPic'];
        }
      }
    }

    await _persist();
  }

  /// Remove entries past their expiry time.
  static void purgeExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, meta) {
      final expiresAt = meta['expiresAt'] as String?;
      if (expiresAt == null) return false;
      try {
        return DateTime.parse(expiresAt).isBefore(now);
      } catch (_) {
        return false;
      }
    });
    _persist(); // fire and forget
  }

  static Future<void> resetForUser() async {
    _initialized = false;
    _lastUserId = null;
    _cache.clear();
    await init();
  }

  // ── internal ─────────────────────────────────────────────────────────

  static Future<void> _ensureCorrectUser() async {
    final currentUserId = _getUserId();
    if (_lastUserId != currentUserId) {
      _cache.clear();
      _initialized = false;
      _lastUserId = currentUserId;
      await _loadFromPrefs();
    }
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cache));
  }
}
