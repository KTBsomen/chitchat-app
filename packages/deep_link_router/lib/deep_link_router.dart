library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';

typedef DeepLinkHandlerFn = Future<bool> Function(
    BuildContext context, Uri uri);

class DeepLinkRoute {
  final bool Function(Uri uri) matcher;
  final DeepLinkHandlerFn handler;

  DeepLinkRoute({required this.matcher, required this.handler});

  static Map<String, dynamic> toJson(DeepLinkRoute route) {
    return {
      'matcher': route.matcher.toString(),
      'handler': route.handler.toString(),
    };
  }
}

/// Routing layer that listens for warm-start deep links via [AppLinks] and
/// dispatches them through a navigator key.
///
/// Cold-start link capture and post-auth deferred-link consumption are
/// intentionally NOT handled here — the host app does that through its own
/// service so it can coordinate with auth state. This class only:
///   * Owns the warm-link stream subscription.
///   * Provides a navigator-key based dispatch helper that survives
///     [BuildContext] churn during route transitions.
class DeepLinkRouter {
  static final DeepLinkRouter instance = DeepLinkRouter._internal();

  factory DeepLinkRouter() => instance;

  DeepLinkRouter._internal();

  late List<DeepLinkRoute> routes;
  DeepLinkHandlerFn? onUnhandled;
  GlobalKey<NavigatorState>? navigatorKey;

  static const String _pendingUriKey = '__pending_deep_link_uri';
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _uriSub;

  /// When `false`, the warm-link stream listener is a no-op.  The host app
  /// must call [markReadyForWarmLinks] once the initial navigation is
  /// complete so that only genuine warm-start links are dispatched.
  bool _readyForWarmLinks = false;

  /// Configures routes and an optional fallback handler.
  ///
  /// Pass a [navigatorKey] so the router can dispatch links without depending
  /// on a [BuildContext] that may unmount during route transitions.
  void configure({
    required List<DeepLinkRoute> routes,
    DeepLinkHandlerFn? onUnhandled,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    this.routes = routes;
    this.onUnhandled = onUnhandled;
    this.navigatorKey = navigatorKey;
  }

  /// Starts listening for warm-start deep links. Must be called after
  /// [configure].
  ///
  /// This intentionally does NOT consume the cold-start initial link — the
  /// host app's deferred link service is the single owner of
  /// [AppLinks.getInitialLink] to avoid racing with itself.
  Future<void> initialize() async {
    if (routes.isEmpty) {
      throw StateError(
        'DeepLinkRouter not configured. Call configure(...) before initialize().',
      );
    }
    _appLinks ??= AppLinks();
    await _uriSub?.cancel();
    _uriSub = _appLinks!.uriLinkStream.listen(
      _onWarmLink,
      onError: (_) {},
    );
  }

  /// Stops listening to the warm-link stream. Useful for tests / hot restart.
  Future<void> dispose() async {
    await _uriSub?.cancel();
    _uriSub = null;
  }

  /// Signals that the app has finished its cold-start navigation and is ready
  /// to accept warm-link dispatches.  Must be called exactly once after the
  /// initial route (e.g. HomePage) is settled and any cold-start deep link has
  /// been consumed.
  void markReadyForWarmLinks() {
    _readyForWarmLinks = true;
  }

  void _onWarmLink(Uri uri) {
    if (!_readyForWarmLinks) {
      // Ignore links that arrive before the app is done with cold-start
      // navigation — those are handled by DeferredLinkService.
      debugPrint('[DeepLinkRouter] Ignoring warm-link during cold start: $uri');
      return;
    }
    // Defer to the next frame so the navigator is in a stable state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _matchAndHandle(uri);
    });
  }

  /// Reads any pending deep link URI from prefs and dispatches it through the
  /// configured navigator key. Safe to call from any context — does not depend
  /// on [BuildContext.mounted].
  ///
  /// Returns `true` if a pending link was found and dispatched, `false`
  /// otherwise. The pending URI is only cleared from prefs once the matched
  /// handler returns `true`, so a failed dispatch can be retried later.
  static Future<bool> dispatchPendingNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pendingUriKey);
    if (stored == null) return false;

    final uri = Uri.tryParse(stored);
    if (uri == null) {
      await prefs.remove(_pendingUriKey);
      return false;
    }

    return instance._matchAndHandle(uri);
  }

  /// Backwards-compatible alias for [dispatchPendingNavigation]. The optional
  /// [context] is ignored — dispatch always goes through the registered
  /// navigator key. Kept so existing call sites keep compiling.
  static Future<void> completePendingNavigation([BuildContext? context]) async {
    await dispatchPendingNavigation();
  }

  /// Returns the pending deep link URI without consuming it.
  static Future<Uri?> getPendingDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pendingUriKey);
    if (stored == null) return null;
    return Uri.tryParse(stored);
  }

  /// Stores [uri] as the pending deep link without dispatching it.
  static Future<void> storePendingDeepLink(Uri uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingUriKey, uri.toString());
  }

  /// Clears any stored pending deep link URI.
  static Future<void> clearPendingDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUriKey);
  }

  /// Resolves a [BuildContext] from the registered navigator key. Falls back
  /// to a `null` value, in which case dispatched handlers will simply receive
  /// `null` as the context — handlers that route via the navigator key
  /// directly are unaffected.
  BuildContext? get _dispatchContext => navigatorKey?.currentContext;

  Future<bool> _matchAndHandle(Uri uri) async {
    if (routes.isEmpty) return false;

    for (final route in routes) {
      if (route.matcher(uri)) {
        await storePendingDeepLink(uri);
        // Resolve the navigator context AFTER the prefs await so we are
        // looking at the current navigator element, not a stale one. The
        // navigator key's currentContext lives for the app's lifetime, so
        // it is safe to use across async gaps once re-resolved.
        final ctx = _dispatchContext;
        bool handled = false;
        if (ctx != null) {
          try {
            handled = await route.handler(ctx, uri);
          } catch (_) {
            handled = false;
          }
        }
        if (handled) {
          await clearPendingDeepLink();
        }
        return handled;
      }
    }

    if (onUnhandled != null) {
      await storePendingDeepLink(uri);
      final ctx = _dispatchContext;
      if (ctx != null) {
        try {
          await onUnhandled!(ctx, uri);
        } catch (_) {}
      }
    }
    return false;
  }
}
