import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoryPrefs {
  static const String _keyPrefix = 'viewed_stories_';
  static const Duration _expiryDuration = Duration(days: 2);

  static final Map<String, DateTime> _cache = {};
  static bool _initialized = false;
  static String? _lastUserId;

  /// Get the current user ID for account-specific storage
  static String _getUserId() {
    final profile = AppVariables.get<Map<String, dynamic>>('profile');
    return profile?['_id'] ?? 'default';
  }

  /// Get the storage key for current user
  static String get _key => '$_keyPrefix${_getUserId()}';

  /// Check if user changed and reinitialize if needed
  static Future<void> _ensureCorrectUser() async {
    final currentUserId = _getUserId();
    if (_lastUserId != currentUserId) {
      // User changed, reinitialize
      _cache.clear();
      _initialized = false;
      _lastUserId = currentUserId;
      await _loadFromPrefs();
    }
  }

  /// Load data from SharedPreferences
  static Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);

    if (data != null) {
      try {
        Map<String, dynamic> viewedStories = jsonDecode(data);
        final now = DateTime.now();

        viewedStories.forEach((id, timestamp) {
          final viewedTime = DateTime.tryParse(timestamp);
          if (viewedTime != null &&
              now.difference(viewedTime) <= _expiryDuration) {
            _cache[id] = viewedTime;
          }
        });
      } catch (e) {
        print('Error loading story prefs: $e');
      }
    }
    _initialized = true;
  }

  /// Reset when user changes (call this on logout/admin switch)
  static Future<void> resetForUser() async {
    _initialized = false;
    _lastUserId = null;
    _cache.clear();
    await init();
  }

  /// Initialize cache (should be called once at app start or after user change)
  static Future<void> init() async {
    if (_initialized && _lastUserId == _getUserId()) return;

    _cache.clear();
    _lastUserId = _getUserId();
    await _loadFromPrefs();
    await cleanExpired();
  }

  /// Save a story as viewed (updates cache + prefs)
  static Future<void> markAsViewed(String storyId) async {
    await _ensureCorrectUser();
    final prefs = await SharedPreferences.getInstance();
    _cache[storyId] = DateTime.now();
    await _persist(prefs);
  }

  static Future<void> unmarkAsViewed(String storyId) async {
    await _ensureCorrectUser();
    final prefs = await SharedPreferences.getInstance();
    _cache.remove(storyId);
    await _persist(prefs);
  }

  /// Check if a story is viewed (instant check from cache)
  /// Note: This is synchronous so it can't check user change - caller should ensure init() was called
  static bool hasViewedSync(String storyId) {
    // Check if user might have changed
    final currentUserId = _getUserId();
    if (_lastUserId != currentUserId) {
      // User changed but we can't async reload here - return false to be safe
      // The next async operation will reload the correct data
      return false;
    }

    if (!_cache.containsKey(storyId)) return false;
    final viewedTime = _cache[storyId]!;
    if (DateTime.now().difference(viewedTime) > _expiryDuration) {
      _cache.remove(storyId);
      return false;
    }
    return true;
  }

  /// Optional: clear expired + persist
  static Future<void> cleanExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    _cache.removeWhere((id, date) => now.difference(date) > _expiryDuration);
    await _persist(prefs);
  }

  /// Optional: manually clear all for current user
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    _cache.clear();
    await prefs.remove(_key);
  }

  static Future<void> _persist(SharedPreferences prefs) async {
    final data = _cache.map((id, date) => MapEntry(id, date.toIso8601String()));
    await prefs.setString(_key, jsonEncode(data));
  }
}
