import 'package:chitchat/appstate/storage.dart';
import 'package:flutter/widgets.dart';

class AppVariables {
  static final AppVariables _instance = AppVariables._internal();

  factory AppVariables() {
    return _instance;
  }

  AppVariables._internal();

  static final Map<String, dynamic> _variables = {};
  static final Map<String, List<Function(dynamic)>> _listeners = {};
  static final List<State> _uiStates = [];
  static Map<String, dynamic> getAllVariables() {
    return _variables;
  }

  static void setPersistent<T>(String key, T value) {
    if (value is T) {
      _variables[key] = value;
      PrefsHelper.set<T>(key, value);
      _notifyListeners(key, value);
      _notifyUIUpdateCallbacks();
    } else {
      throw ArgumentError("Value type does not match expected type $T");
    }
  }

  static Future<T?>? getPersistent<T>(String key) async {
    final value = await PrefsHelper.get<T>(key);
    return value is T ? value : null;
  }

  static T? set<T>(String key, T value) {
    if (value is T) {
      _variables[key] = value;
      _notifyListeners(key, value);
      _notifyUIUpdateCallbacks();
    } else {
      throw ArgumentError("Value type does not match expected type $T");
    }
  }

  static T? get<T>(String key) {
    final value = _variables[key];
    return value is T ? value : null;
  }

  static void update(String key, dynamic value) {
    _variables[key] = value;
    _notifyListeners(key, value);
    _notifyUIUpdateCallbacks();
  }

  static void addListener<T>(String key, Function(T) listener) {
    if (_listeners[key] == null) {
      _listeners[key] = [];
    }
    _listeners[key]!.add((value) {
      if (value is T) {
        listener(value);
      }
    });
  }

  static void removeListener<T>(String key, Function(T) listener) {
    _listeners[key]?.removeWhere((element) =>
        element ==
        (value) {
          if (value is T) {
            listener(value);
          }
        });
  }

  static void registerState(State state) {
    if (!_uiStates.contains(state)) {
      _uiStates.add(state);
    }
  }

  static void unregisterState(State state) {
    _uiStates.remove(state);
  }

  static void _notifyListeners(String key, dynamic value) {
    if (_listeners[key] != null) {
      for (var listener in _listeners[key]!) {
        listener(value);
      }
    }
  }

  static void _notifyUIUpdateCallbacks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var state in _uiStates) {
        if (state.mounted) {
          state.setState(() {});
        }
      }
    });
  }
}
