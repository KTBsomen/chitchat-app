import 'package:chitchat/appstate/notification_store.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/services/notification_manager.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AppNotification {
  final String? title;
  final String? body;
  final String? type;
  final String? icon;
  final List<String>? image;
  final Map<String, dynamic>? data;
  final String? clickAction;
  final String? link;
  final String? id;

  const AppNotification({
    this.title,
    this.body,
    this.type,
    this.icon,
    this.image,
    this.data,
    this.clickAction,
    this.link,
    this.id,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;

    final rawData = json['data'];
    if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    } else if (rawData is String) {
      try {
        parsedData = Map<String, dynamic>.from(jsonDecode(rawData));
      } catch (_) {
        parsedData = null;
      }
    }

    return AppNotification(
      title: json['title'] as String?,
      body: json['body'] as String?,
      type: json['type'] as String?,
      icon: json['icon'] as String?,
      image: (json['image'] as List?)?.map((e) => e as String).toList(),
      data: parsedData,
      clickAction: (json['click_action'] ?? json['clickAction']) as String?,
      link: json['link'] as String?,
      id: json['_id'] as String? ?? _generateContentId(json),
    );
  }

  /// Generate a deterministic ID from notification content so the same
  /// notification always produces the same key (prevents duplicates when
  /// the server doesn't provide an _id).
  static String _generateContentId(Map<String, dynamic> json) {
    final seed =
        '${json['title']}|${json['body']}|${json['type']}|${json['icon']}';
    // Simple hash — deterministic across parses.
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return 'gen_$hash';
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'icon': icon,
      'image': image,
      'data': data,
      'click_action': clickAction,
      'link': link,
      'id': id,
    }..removeWhere((_, v) => v == null);
  }

  /// Convert to a map suitable for NotificationStore.
  Map<String, dynamic> toStoreMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'icon': icon,
      'image': image,
      'data': data,
      'clickAction': clickAction,
      'link': link,
      'sourceType': 'redis',
    };
  }

  /// Reconstruct from NotificationStore map.
  factory AppNotification.fromStoreMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String?,
      title: map['title'] as String?,
      body: map['body'] as String?,
      type: map['type'] as String?,
      icon: map['icon'] as String?,
      image: (map['image'] as List?)?.map((e) => e.toString()).toList(),
      data: map['data'] is Map ? Map<String, dynamic>.from(map['data']) : null,
      clickAction: map['clickAction'] as String?,
      link: map['link'] as String?,
    );
  }

  AppNotification copyWith({
    String? title,
    String? body,
    String? type,
    String? icon,
    List<String>? image,
    Map<String, dynamic>? data,
    String? clickAction,
    String? link,
    String? id,
  }) {
    return AppNotification(
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      image: image ?? this.image,
      data: data ?? this.data,
      clickAction: clickAction ?? this.clickAction,
      link: link ?? this.link,
      id: id ?? this.id,
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, body: $body, type: $type, icon: $icon, image: $image, data: $data, clickAction: $clickAction, link: $link)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification &&
        other.title == title &&
        other.body == body &&
        other.type == type &&
        other.icon == icon &&
        other.image == image &&
        _mapEquals(other.data, data) &&
        other.clickAction == clickAction &&
        other.link == link &&
        other.id == id;
  }

  @override
  int get hashCode {
    return Object.hash(
      title,
      body,
      type,
      icon,
      image,
      data == null ? null : _deepMapHash(data!),
      clickAction,
      link,
      id,
    );
  }

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  static int _deepMapHash(Map<String, dynamic> m) {
    var h = 0;
    m.forEach((k, v) {
      h = h ^ k.hashCode ^ (v?.hashCode ?? 0);
    });
    return h;
  }
}

class NotificationService {
  static bool _isLoading = false;
  static String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';

  // Show loader
  static void showLoader(BuildContext context) {
    if (!_isLoading) {
      _isLoading = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
    }
  }

  // Hide loader
  static void hideLoader(BuildContext context) {
    if (_isLoading) {
      _isLoading = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // Show popup
  static void showPopup(BuildContext context, String message,
      {VoidCallback? onRefresh}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (onRefresh != null) onRefresh();
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  /// Fetch notifications from server, store locally, then clear from Redis.
  ///
  /// The server keeps notifications in Redis indefinitely (GET /notifications).
  /// After storing them in NotificationStore (which deduplicates by id), we
  /// call DELETE /notifications/clear to empty the Redis list so subsequent
  /// fetches only return genuinely new notifications.
  static Future<List<AppNotification>?> getNotifications(BuildContext? context,
      {bool showMessage = true, bool showLoaders = true}) async {
    try {
      String? accessToken = await UserService.getAccessToken();
      if (showLoaders && context != null) {
        showLoader(context);
      }
      final response = await http.get(
        Uri.parse("$baseurl/notifications"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      if (showLoaders && context != null) {
        hideLoader(context);
      }

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch notifications");
      }

      final data = jsonDecode(response.body);

      // Parse notifications
      List<AppNotification> notifications = List<AppNotification>.from(
          data.map((notif) => AppNotification.fromJson(notif)));

      // Store new notifications locally (deduplicates by id)
      final storeMaps = notifications
          .where((n) => n.id != null)
          .map((n) => n.toStoreMap())
          .toList();
      final added = await NotificationStore.addNotifications(storeMaps);
      if (added > 0) {
        NotificationManager.instance.refreshCount();
      }

      // Clear Redis so next fetch only returns new notifications
      if (notifications.isNotEmpty) {
        _clearServerNotifications();
      }

      return notifications;
    } catch (error) {
      if (showMessage && context != null) {
        hideLoader(context);
        showPopup(context, error.toString());
      }
      return [];
    }
  }

  /// Fire-and-forget: clear the server's Redis notification list.
  static Future<void> _clearServerNotifications() async {
    try {
      String? accessToken = await UserService.getAccessToken();
      await http.delete(
        Uri.parse("$baseurl/notifications/clear"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );
    } catch (_) {
      // Best-effort; failure here just means next fetch may re-deliver.
    }
  }

  /// Get all locally stored notifications (for display in the UI).
  static List<Map<String, dynamic>> getStoredNotifications() {
    return NotificationStore.getAll();
  }

  /// Clear all notifications from server.
  static Future<bool> clearAllNotificationsfromServer(
      BuildContext context) async {
    try {
      String? accessToken = await UserService.getAccessToken();
      final response = await http.delete(
        Uri.parse(
            "$baseurl/notifications/clear?id=${await UserService.getUserId()}"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception("Failed to clear notifications");
      }

      print(data["message"] ?? "Notifications cleared");
      return true;
    } catch (error) {
      print(error.toString());
      return false;
    }
  }

  /// Fetch join requests for a group (for group members to vote on).
  static Future<List<Map<String, dynamic>>?> getGroupJoinRequests(
      BuildContext context, String groupId,
      {bool showMessage = true, bool showLoaders = true}) async {
    try {
      String? accessToken = await UserService.getAccessToken();

      if (showLoaders) {
        showLoader(context);
      }
      final response = await http.get(
        Uri.parse("$baseurl/group/joinrequests/$groupId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      final data = jsonDecode(response.body);
      if (showLoaders) {
        hideLoader(context);
      }

      if (response.statusCode == 404) {
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch join requests");
      }

      // Store as group-source notifications locally
      final joinRequests =
          List<Map<String, dynamic>>.from(data["joinRequests"]);
      final storeMaps = joinRequests
          .map((req) => {
                'id': req['_id'],
                'title': 'Join Request',
                'body':
                    '${req['requestBody']?['memberName'] ?? 'Someone'} wants to join',
                'type': req['requestType'] ?? 'joinGroup',
                'sourceType': 'api',
                'data': req,
              })
          .toList();
      await NotificationStore.addNotifications(storeMaps);
      NotificationManager.instance.refreshCount();

      return joinRequests;
    } catch (error) {
      if (showMessage) {
        hideLoader(context);
        showPopup(context, error.toString());
      }
      return [];
    }
  }

  /// Fetch post requests.
  static Future<List<Map<String, dynamic>>?> getGroupPostRequests(
      BuildContext context, String postId,
      {bool showMessage = true, bool showLoaders = true}) async {
    try {
      String? accessToken = await UserService.getAccessToken();

      if (showLoaders) {
        showLoader(context);
      }
      final response = await http.get(
        Uri.parse("$baseurl/group/postrequests/$postId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      final data = jsonDecode(response.body);
      if (showLoaders) {
        hideLoader(context);
      }

      if (response.statusCode == 404) {
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch post requests");
      }

      return List<Map<String, dynamic>>.from(data["postRequests"]);
    } catch (error) {
      if (showMessage) {
        hideLoader(context);
        showPopup(context, error.toString());
      }
      return [];
    }
  }

  /// Batch check join request statuses.
  /// Sends request IDs to /groups/notification/join/status
  /// Returns list of { _id, votes, totalMembers, status, groupName, groupPic, ... }
  static Future<List<Map<String, dynamic>>> checkJoinRequestStatuses(
      List<String> requestIds) async {
    if (requestIds.isEmpty) return [];

    try {
      String? accessToken = await UserService.getAccessToken();
      final response = await http.post(
        Uri.parse("$baseurl/groups/notification/join/status"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode({"ids": requestIds}),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data["results"] ?? []);
    } catch (e) {
      print('Error checking join request statuses: $e');
      return [];
    }
  }

  // Vote function
  static Future<bool> vote(BuildContext context, String voteId,
      {required Function onRefresh}) async {
    try {
      showLoader(context);
      String? accessToken = await UserService.getAccessToken();
      final response = await http.post(
        Uri.parse("$baseurl/vote/$voteId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      final data = jsonDecode(response.body);
      hideLoader(context);

      if (response.statusCode != 200) {
        throw Exception(data["message"]);
      }

      if (data["approved"] == true) {
        showPopup(
          context,
          data["message"] ?? "User is now in your group",
          onRefresh: () => onRefresh(),
        );
        return true;
      } else if (data["message"] == "You have already voted for this group") {
        showPopup(context, data["message"]);
        return false;
      } else {
        showPopup(context, data["message"]);
        return true;
      }
    } catch (error) {
      hideLoader(context);
      showPopup(context, error.toString());
      return false;
    }
  }
}
