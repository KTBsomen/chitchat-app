import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:deep_link_router/deep_link_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recovers and consumes deep link context across the app lifecycle.
///
/// Owns three responsibilities so the rest of the app does not have to
/// coordinate them:
///   1. Capturing the cold-start [AppLinks.getInitialLink] URI exactly once.
///   2. Recovering a deferred deep link after first install (Play Install
///      Referrer on Android, clipboard fallback, server fingerprint).
///   3. Dispatching whatever URI is pending through the registered
///      [DeepLinkRouter] in a way that survives [BuildContext] churn during
///      route transitions.
///
/// The canonical public deep link host is `groups.chitzchat.com`. Only paths
/// matching that host are considered supported.
class DeferredLinkService {
  static const String deepLinkDomain = 'groups.chitzchat.com';

  static const String _kDeferredLink = 'deferred_deep_link';
  static const String _kDeferredLinkChecked = 'deferred_link_checked';
  static const String _kPendingDeepLinkUri = '__pending_deep_link_uri';

  /// Single shared [AppLinks] instance — calling
  /// [AppLinks.getInitialLink] from multiple instances has caused racy
  /// behaviour on iOS, so we centralise it here.
  static final AppLinks _appLinks = AppLinks();

  static bool _initialAppLinkCaptured = false;
  static Future<Uri?>? _initialAppLinkFuture;

  // ───────────────────────── Cold-start capture ─────────────────────────

  /// Captures both direct cold-start app links and first-install deferred
  /// links. Idempotent — safe to call from multiple places, the actual work
  /// only runs once per process.
  static Future<void> checkAndStoreStartupLinks() async {
    await captureInitialAppLink();
    await checkAndStoreDeferredLink();
  }

  /// Captures the cold-start [AppLinks.getInitialLink] URI and stores it for
  /// later dispatch. Subsequent calls return the cached result instead of
  /// re-querying the platform channel.
  static Future<Uri?> captureInitialAppLink() {
    return _initialAppLinkFuture ??= _captureInitialAppLinkOnce();
  }

  static Future<Uri?> _captureInitialAppLinkOnce() async {
    if (_initialAppLinkCaptured) return null;
    _initialAppLinkCaptured = true;

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink == null || !_isSupportedDeepLink(initialLink)) {
        return null;
      }
      await DeepLinkRouter.storePendingDeepLink(initialLink);
      debugPrint('[DeferredLinkService] Captured initial app link: '
          '$initialLink');
      return initialLink;
    } catch (e) {
      debugPrint('[DeferredLinkService] Initial app link check failed: $e');
      return null;
    }
  }

  // ───────────────────────── Deferred recovery ─────────────────────────

  /// Called once on first-ever app launch. If a path is found through one of
  /// the recovery channels, it is stored for later consumption.
  static Future<void> checkAndStoreDeferredLink() async {
    if (await _hasAlreadyChecked()) return;

    String? recoveredPath;

    if (Platform.isAndroid) {
      recoveredPath = await _checkInstallReferrer();
    }

    recoveredPath ??= await _checkClipboard();
    recoveredPath ??= await _checkServerFingerprint();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDeferredLinkChecked, true);

    if (recoveredPath != null && recoveredPath.isNotEmpty) {
      await prefs.setString(_kDeferredLink, recoveredPath);
      debugPrint(
          '[DeferredLinkService] Recovered deferred link: $recoveredPath');
    }
  }

  /// Returns the stored deferred link as a full URI, or null if none exists.
  static Future<Uri?> getPendingDeferredLink() async {
    final prefs = await SharedPreferences.getInstance();
    final path = _normalizeRecoveredPath(prefs.getString(_kDeferredLink));
    if (path == null) return null;
    return Uri.parse('https://$deepLinkDomain$path');
  }

  // ───────────────────────── Pending URI plumbing ─────────────────────────

  /// Ensures either the router's pending URI or a deferred URI is staged for
  /// [dispatchPendingDeepLink].
  static Future<Uri?> preparePendingDeepLinkForRouter() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingUri =
        _tryParseSupportedUri(prefs.getString(_kPendingDeepLinkUri));
    if (pendingUri != null) return pendingUri;

    if (prefs.containsKey(_kPendingDeepLinkUri)) {
      await prefs.remove(_kPendingDeepLinkUri);
    }

    final deferredUri = await getPendingDeferredLink();
    if (deferredUri == null) return null;

    await DeepLinkRouter.storePendingDeepLink(deferredUri);
    return deferredUri;
  }

  /// Stores [uri] for later dispatch. Convenience wrapper around
  /// [DeepLinkRouter.storePendingDeepLink] with a supported-host check.
  static Future<void> storePendingDeepLink(Uri uri) async {
    if (!_isSupportedDeepLink(uri)) return;
    await DeepLinkRouter.storePendingDeepLink(uri);
  }

  /// Reads the pending URI (router URI first, then deferred fallback) and
  /// dispatches it through [DeepLinkRouter] using the registered navigator
  /// key. Always scheduled on a post-frame callback so the navigator is
  /// attached before any push is attempted.
  ///
  /// Returns `true` if a link was found and successfully dispatched. The
  /// post-install [_kDeferredLink] entry is only cleared on a successful
  /// dispatch so the same URI can be retried on the next post-auth screen.
  static Future<bool> dispatchPendingDeepLink() async {
    final pending = await preparePendingDeepLinkForRouter();
    if (pending == null) return false;

    final completer = Completer<bool>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final handled = await DeepLinkRouter.dispatchPendingNavigation();
        if (handled) {
          await consumeDeferredLink();
        }
        completer.complete(handled);
      } catch (e) {
        debugPrint('[DeferredLinkService] Dispatch failed: $e');
        completer.complete(false);
      }
    });
    return completer.future;
  }

  /// Clears the post-install deferred link entry. Called automatically by
  /// [dispatchPendingDeepLink] on success, but exposed for callers that need
  /// to drop a stuck entry manually.
  static Future<void> consumeDeferredLink() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDeferredLink);
    debugPrint('[DeferredLinkService] Deferred link consumed');
  }

  // ───────────────────────── Recovery channels ─────────────────────────

  static Future<bool> _hasAlreadyChecked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDeferredLinkChecked) ?? false;
  }

  static Future<String?> _checkInstallReferrer() async {
    try {
      final referrer = await AndroidPlayInstallReferrer.installReferrer;
      return _extractPathFromReferrer(referrer.installReferrer);
    } catch (e) {
      debugPrint('[DeferredLinkService] Install referrer check failed: $e');
      return null;
    }
  }

  static String? _extractPathFromReferrer(String? rawReferrer) {
    if (rawReferrer == null || rawReferrer.trim().isEmpty) return null;

    final decoded = Uri.decodeComponent(rawReferrer.trim());
    final referrerUri = Uri.tryParse('https://$deepLinkDomain?$decoded');
    if (referrerUri != null) {
      final pathValue = referrerUri.queryParameters['path'] ??
          referrerUri.queryParameters['deep_link'] ??
          referrerUri.queryParameters['deeplink'];
      if (pathValue != null && pathValue.trim().isNotEmpty) {
        final extraParams =
            Map<String, String>.from(referrerUri.queryParameters)
              ..remove('path')
              ..remove('deep_link')
              ..remove('deeplink');
        final normalizedPath =
            _normalizePathWithExtraParams(pathValue, extraParams);
        if (normalizedPath != null) return normalizedPath;
      }
    }

    return _normalizeRecoveredPath(decoded);
  }

  static Future<String?> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      return _normalizeRecoveredPath(clipboardData?.text);
    } catch (e) {
      debugPrint('[DeferredLinkService] Clipboard check failed: $e');
      return null;
    }
  }

  static Future<String?> _checkServerFingerprint() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final fingerprint = await _buildFingerprint();
      final baseUrl =
          AppVariables.get<String>('baseurl') ?? 'https://chitzchat.com/api/v1';
      final uri = Uri.parse('$baseUrl/deferred-link?fp=$fingerprint');

      final request = await client.getUrl(uri);
      request.headers.set('Content-Type', 'application/json');

      final response =
          await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;

      return _normalizeRecoveredPath(data['path'] as String?);
    } catch (e) {
      debugPrint('[DeferredLinkService] Server fingerprint check failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Best-effort low-entropy fingerprint matching the landing page snippet in
  /// docs/deferred_deep_linking_backend.md.
  static Future<String> _buildFingerprint() async {
    final window = WidgetsBinding.instance.platformDispatcher.views.first;
    final screenSize = window.physicalSize;
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final timezoneMinutes = DateTime.now().timeZoneOffset.inMinutes;
    final platform = Platform.isIOS
        ? 'ios'
        : Platform.isAndroid
            ? 'android'
            : Platform.operatingSystem;

    final raw = '${screenSize.width.round()}x${screenSize.height.round()}'
        '|${locale.toLanguageTag()}'
        '|$timezoneMinutes'
        '|$platform';

    final bytes = utf8.encode(raw);
    int hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash + byte) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ───────────────────────── URI helpers ─────────────────────────

  static Uri? _tryParseSupportedUri(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !_isSupportedDeepLink(uri)) return null;
    return uri;
  }

  static String? _normalizePathWithExtraParams(
    String value,
    Map<String, String> extraParams,
  ) {
    final trimmed = value.trim();
    final parsed = Uri.tryParse(trimmed);
    Uri? uri;

    if (parsed != null && parsed.hasScheme) {
      if (parsed.host != deepLinkDomain) return null;
      uri = parsed;
    } else {
      final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      uri = Uri.tryParse('https://$deepLinkDomain$path');
    }

    if (uri == null) return null;
    if (uri.query.isEmpty && extraParams.isNotEmpty) {
      uri = uri.replace(queryParameters: extraParams);
    }

    return _normalizeRecoveredPath(_pathWithQuery(uri));
  }

  static String? _normalizeRecoveredPath(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      if (!_isSupportedDeepLink(uri)) return null;
      return _pathWithQuery(uri);
    }

    final domainPrefixed = trimmed.startsWith(deepLinkDomain)
        ? Uri.tryParse('https://$trimmed')
        : null;
    if (domainPrefixed != null && _isSupportedDeepLink(domainPrefixed)) {
      return _pathWithQuery(domainPrefixed);
    }

    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final pathUri = Uri.tryParse('https://$deepLinkDomain$path');
    if (pathUri == null || !_isSupportedDeepLink(pathUri)) return null;
    return _pathWithQuery(pathUri);
  }

  static bool _isSupportedDeepLink(Uri uri) {
    if (uri.scheme != 'https' || uri.host != deepLinkDomain) return false;
    if (uri.path == '/join' && uri.queryParameters.containsKey('group')) {
      return true;
    }
    if (uri.path == '/invite') return true;

    final segments = uri.pathSegments;
    return (segments.length == 3 && segments[0] == 'user') ||
        (segments.length == 2 && segments[0] == 'post');
  }

  static String _pathWithQuery(Uri uri) {
    return uri.path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
  }
}
