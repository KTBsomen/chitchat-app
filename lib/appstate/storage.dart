import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Interface for serializable objects
abstract class JsonSerializable {
  Map<String, dynamic> toJson();
}

/// Type factory for object deserialization
typedef FromJsonFactory<T> = T Function(Map<String, dynamic> json);

class PrefsHelper {
  static final Map<Type, FromJsonFactory> _factories = {};
  static SharedPreferences? _prefs;

  // Initialize shared preferences

  // Register type factories
  static void registerType<T>(FromJsonFactory<T> factory) {
    _factories[T] = factory;
  }

  // Generic setter
  static Future<bool> set<T>(String key, T value) async {
    _prefs ??= await SharedPreferences.getInstance();

    try {
      if (T == String) {
        return _prefs!.setString(key, value as String);
      } else if (T == int) {
        return _prefs!.setInt(key, value as int);
      } else if (T == double) {
        return _prefs!.setDouble(key, value as double);
      } else if (T == bool) {
        return _prefs!.setBool(key, value as bool);
      } else if (value is List<String>) {
        return _prefs!.setStringList(key, value);
      } else if (value is DateTime) {
        return _prefs!.setString(key, value.toIso8601String());
      } else if (value is JsonSerializable) {
        return _prefs!.setString(key, jsonEncode(value.toJson()));
      } else if (value is List) {
        final serializedList = value.map((item) {
          if (item is JsonSerializable) return item.toJson();
          return item;
        }).toList();
        return _prefs!.setString(key, jsonEncode(serializedList));
      } else if (value is Map) {
        return _prefs!.setString(key, jsonEncode(value));
      } else if (value is Set) {
        return _prefs!.setString(key, jsonEncode(value.toList()));
      } else {
        throw UnsupportedError('Type ${T.toString()} not supported');
      }
    } catch (e) {
      print('Error setting preference: $e');
      return false;
    }
  }

  // Generic getter with type conversion
  static Future<T?> get<T>(String key) async {
    _prefs ??= await SharedPreferences.getInstance();

    try {
      if (!_prefs!.containsKey(key)) return null;

      if (T == String) {
        return _prefs!.getString(key) as T?;
      } else if (T == int) {
        return _prefs!.getInt(key) as T?;
      } else if (T == double) {
        return _prefs!.getDouble(key) as T?;
      } else if (T == bool) {
        return _prefs!.getBool(key) as T?;
      } else if (T == List<String>) {
        return _prefs!.getStringList(key) as T?;
      } else if (T == DateTime) {
        final str = _prefs!.getString(key);
        return str != null ? DateTime.parse(str) as T : null;
      } else {
        final str = _prefs!.getString(key);
        if (str == null) return null;

        final decoded = jsonDecode(str);
        return _convertToType<T>(decoded);
      }
    } catch (e) {
      print('Error getting preference: $e');
      return null;
    }
  }

  // Type conversion helper
  static T? _convertToType<T>(dynamic decoded) {
    try {
      if (T.toString().startsWith('Map<String, bool>')) {
        if (decoded is Map) {
          return Map<String, bool>.from(decoded.map(
              (key, value) => MapEntry(key.toString(), value as bool))) as T;
        }
      } else if (T.toString().startsWith('Map<String, int>')) {
        if (decoded is Map) {
          return Map<String, int>.from(decoded.map(
              (key, value) => MapEntry(key.toString(), value as int))) as T;
        }
      } else if (T.toString().startsWith('Map<String, double>')) {
        if (decoded is Map) {
          return Map<String, double>.from(decoded.map(
              (key, value) => MapEntry(key.toString(), value as double))) as T;
        }
      } else if (T.toString().startsWith('Map<String, String>')) {
        if (decoded is Map) {
          return Map<String, String>.from(decoded.map(
              (key, value) => MapEntry(key.toString(), value.toString()))) as T;
        }
      } else if (T.toString().startsWith('List<')) {
        if (decoded is List) {
          if (_factories.containsKey(T)) {
            return decoded.map((item) => _factories[T]!(item)).toList() as T;
          }
          return decoded as T;
        }
      } else if (T.toString().startsWith('Set<')) {
        if (decoded is List) {
          return decoded.toSet() as T;
        }
      } else if (_factories.containsKey(T)) {
        return _factories[T]!(decoded as Map<String, dynamic>);
      }

      return decoded as T;
    } catch (e) {
      print('Error converting type: $e');
      return null;
    }
  }

  // Utility methods
  static Future<bool> remove(String key) async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.remove(key);
  }

  static Future<bool> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.clear();
  }

  static Future<bool> containsKey(String key) async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.containsKey(key);
  }
}
