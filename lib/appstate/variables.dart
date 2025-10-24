import 'package:chitchat/appstate/storage.dart';
import 'package:flutter/widgets.dart';

class AppVariables {
  static final AppVariables _instance = AppVariables._internal();

  factory AppVariables() {
    return _instance;
  }

  AppVariables._internal();

  static final Map<String, dynamic> _variables = {};
  static Map<String, Map<Function, Function(dynamic)>>? _listenersMap;
  static final List<State> _uiStates = [];

  static Map<String, Map<Function, Function(dynamic)>> get _listeners {
    if (_listenersMap == null) {
      _listenersMap = {};
    }
    return _listenersMap!;
  }

  static Map<String, dynamic> getAllVariables() {
    return _variables;
  }

  static void setPersistent<T>(String key, T value) {
    _variables[key] = value;
    PrefsHelper.set<T>(key, value);
    _notifyListeners(key, value);
    _notifyUIUpdateCallbacks();
  }

  static Future<T?>? getPersistent<T>(String key) async {
    final value = await PrefsHelper.get<T>(key);
    return value is T ? value : null;
  }

  static void set<T>(String key, T value) {
    _variables[key] = value;
    _notifyListeners(key, value);
    _notifyUIUpdateCallbacks();
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

  /// Checks if a function is anonymous (closure without a name)
  static bool _isAnonymousFunction(Function function) {
    final functionString = function.toString();

    // Anonymous functions/closures typically look like:
    // "Closure: (Type) => void from Function '<anonymous closure>'"
    // or "Closure: (Type) => void"
    // Named methods look like:
    // "Closure: (Type) => void from Function '_handlePostsUpdate'"

    return functionString.contains('<anonymous closure>') ||
        functionString.contains('() =>') ||
        (functionString.contains('Closure:') &&
            !RegExp(r"from Function '[_a-zA-Z]").hasMatch(functionString));
  }

  static void addListener<T>(String key, Function(T) listener) {
    // Check for anonymous functions
    if (_isAnonymousFunction(listener)) {
      throw ArgumentError(
          '❌ Anonymous functions are not allowed as listeners!\n'
          '\n'
          '🚫 BAD:\n'
          'AppVariables.addListener("$key", (value) { ... });\n'
          '\n'
          '✅ GOOD (Option 1 - Store in variable):\n'
          'final _listener = (value) { ... };\n'
          'AppVariables.addListener("$key", _listener);\n'
          '\n'
          '✅ GOOD (Option 2 - Use method reference):\n'
          'void _handleUpdate(value) { ... }\n'
          'AppVariables.addListener("$key", _handleUpdate);\n'
          '\n'
          '💡 Why? Anonymous functions cannot be removed in dispose(),\n'
          '   causing memory leaks and duplicate listeners!');
    }

    if (_listeners[key] == null) {
      _listeners[key] = {};
    }

    // Store both the original listener and the wrapper
    final wrapper = (dynamic value) {
      if (value is T) {
        listener(value);
      } else {
        print(
            '⚠️ Type mismatch for key "$key": expected $T, got ${value.runtimeType}');
      }
    };

    _listeners[key]![listener] = wrapper;
    print('✅ Listener added for "$key" (total: ${_listeners[key]!.length})');
  }

  static void removeListener<T>(String key, Function(T) listener) {
    if (_listeners[key] != null) {
      final removed = _listeners[key]!.remove(listener);
      if (removed != null) {
        print(
            '🗑️ Listener removed for "$key" (remaining: ${_listeners[key]!.length})');
      } else {
        print('⚠️ Listener not found for "$key" - was it already removed?');
      }
      if (_listeners[key]!.isEmpty) {
        _listeners.remove(key);
      }
    }
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
      final listenersToNotify = List.from(_listeners[key]!.values);
      for (var wrapper in listenersToNotify) {
        try {
          wrapper(value);
        } catch (e) {
          print('❌ Error notifying listener for key "$key": $e');
        }
      }
    }
  }

  static void _notifyUIUpdateCallbacks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var state in List.from(_uiStates)) {
        if (state.mounted) {
          state.setState(() {});
        }
      }
    });
  }

  static void debugListeners() {
    print('🔍 Active listeners:');
    _listeners.forEach((key, listeners) {
      print('  📌 $key: ${listeners.length} listener(s)');
    });
  }

  static void clearAllListeners() {
    _listenersMap?.clear();
    _listenersMap = {};
    print('🧹 All listeners cleared');
  }
}
