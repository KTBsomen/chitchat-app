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

  // Register type factories
  static void registerType<T>(FromJsonFactory<T> factory) {
    _factories[T] = factory;
  }

  // Generic setter
  static Future<bool> set<T>(String key, T value) async {
    _prefs ??= await SharedPreferences.getInstance();

    if (T == String) {
      return _prefs!.setString(key, value as String);
    } else if (T == int) {
      return _prefs!.setInt(key, value as int);
    } else if (T == double) {
      return _prefs!.setDouble(key, value as double);
    } else if (T == bool) {
      return _prefs!.setBool(key, value as bool);
    } else if (T == List<String>) {
      return _prefs!.setStringList(key, value as List<String>);
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
  }

  // Generic getter
  static Future<T?> get<T>(String key) async {
    _prefs ??= await SharedPreferences.getInstance();

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

      final dynamic decoded = jsonDecode(str);

      if (_isListType<T>()) {
        return _handleListType<T>(decoded);
      } else if (_isSetType<T>()) {
        return _handleSetType<T>(decoded);
      } else if (_isMapType<T>()) {
        return _handleMapType<T>(decoded);
      } else {
        return _handleCustomType<T>(decoded);
      }
    }
  }

  // Type checking helpers
  static bool _isListType<T>() => T.toString().startsWith('List<');
  static bool _isSetType<T>() => T.toString().startsWith('Set<');
  static bool _isMapType<T>() => T.toString().startsWith('Map<');

  // Handle complex types
  static T? _handleListType<T>(dynamic decoded) {
    if (decoded is! List) return null;
    final itemType = T.toString().split('<')[1].split('>')[0];
    final factory = _factories[itemType];
    if (factory != null) {
      return decoded.map((item) => factory(item)).toList() as T;
    }
    return decoded as T;
  }

  static T? _handleSetType<T>(dynamic decoded) {
    if (decoded is! List) return null;
    final itemType = T.toString().split('<')[1].split('>')[0];
    final factory = _factories[itemType];
    if (factory != null) {
      return decoded.map((item) => factory(item)).toSet() as T;
    }
    return Set<dynamic>.from(decoded) as T;
  }

  static T? _handleMapType<T>(dynamic decoded) {
    if (decoded is! Map) return null;
    final valueType = T.toString().split(',')[1].split('>')[0].trim();
    final factory = _factories[valueType];
    if (factory != null) {
      return decoded.map((key, value) => MapEntry(key, factory(value))) as T;
    }
    return decoded as T;
  }

  static T? _handleCustomType<T>(dynamic decoded) {
    final factory = _factories[T];
    return factory != null ? factory(decoded) : decoded as T;
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
