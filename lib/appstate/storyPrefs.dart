import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StoryPrefs {
  static const String _key = 'viewed_stories';
  static const Duration _expiryDuration = Duration(days: 2);

  static final Map<String, DateTime> _cache = {};
  static bool _initialized = false;

  /// Initialize cache (should be called once at app start)
  static Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);

    if (data != null) {
      Map<String, dynamic> viewedStories = jsonDecode(data);
      final now = DateTime.now();

      viewedStories.forEach((id, timestamp) {
        final viewedTime = DateTime.tryParse(timestamp);
        if (viewedTime != null &&
            now.difference(viewedTime) <= _expiryDuration) {
          _cache[id] = viewedTime;
        }
      });
    }
    await cleanExpired();
    _initialized = true;
  }

  /// Save a story as viewed (updates cache + prefs)
  static Future<void> markAsViewed(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    _cache[storyId] = DateTime.now();
    await _persist(prefs);
  }

  static Future<void> unmarkAsViewed(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    _cache.remove(storyId);
    await _persist(prefs);
  }

  /// Check if a story is viewed (instant check from cache)
  static bool hasViewedSync(String storyId) {
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

  /// Optional: manually clear all
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
