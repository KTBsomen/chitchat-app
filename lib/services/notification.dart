import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String? title;
  final String? body;
  final String? type;
  final String? icon;
  final List<String>? image;
  final Map<String, dynamic>? data;
  final String? clickAction;
  final String? link;

  const AppNotification({
    this.title,
    this.body,
    this.type,
    this.icon,
    this.image,
    this.data,
    this.clickAction,
    this.link,
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
      // support both snake_case and camelCase keys
      clickAction: (json['click_action'] ?? json['clickAction']) as String?,
      link: json['link'] as String?,
    );
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
    }..removeWhere((_, v) => v == null);
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
    );
  }

  @override
  String toString() {
    return 'AppNotification(title: $title, body: $body, type: $type, icon: $icon, image: $image, data: $data, clickAction: $clickAction, link: $link)';
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
        other.link == link;
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

// Save unique unread IDs and update count
  static Future<void> storeUnreadIds(List<String> newIds) async {
    final prefs = await SharedPreferences.getInstance();

    // Get already stored unread IDs
    List<String> storedIds = prefs.getStringList("unreadIds") ?? [];

    // Add only new unique IDs
    for (String id in newIds) {
      if (!storedIds.contains(id)) {
        storedIds.add(id);
      }
    }

    // Save updated unique list
    await prefs.setStringList("unreadIds", storedIds);

    // Update unread count
    await prefs.setInt("unreadcount", storedIds.length);
  }

// Get unread count
  static Future<int> getNotificationCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("unreadcount") ?? 0;
  }

// Get stored unread IDs
  static Future<List<String>> getUnreadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList("unreadIds") ?? [];
  }

// Check if a specific notification ID is unread
  static Future<bool> isUnread(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> storedIds = prefs.getStringList("unreadIds") ?? [];
    return storedIds.contains(id);
  }

// Remove a specific notification ID when read
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> storedIds = prefs.getStringList("unreadIds") ?? [];

    // Remove the ID if it exists
    if (storedIds.contains(id)) {
      storedIds.remove(id);
      await prefs.setStringList("unreadIds", storedIds);
      await prefs.setInt("unreadcount", storedIds.length);
    }
  }

//clear all unread notifications
  static Future<void> clearAllUnreadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("unreadIds");
    await prefs.remove("unreadcount");
  }

// fetch notifications
  static Future<List<AppNotification>?> getNotifications(BuildContext context,
      {bool showMessage = true, bool showLoaders = true}) async {
    try {
      String? accessToken = await UserService.getAccessToken();

      if (showLoaders) {
        showLoader(context);
      }
      final response = await http.get(
        Uri.parse(
            "$baseurl/notifications?id=${await UserService.getUserId()}&invalidate=true"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
      );

      final data = jsonDecode(response.body);
      if (showLoaders) {
        hideLoader(context);
      }

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch notifications");
      }

      // Parse and return the notifications
      List<AppNotification> notifications = List<AppNotification>.from(
          data.map((notif) => AppNotification.fromJson(notif)));

      return notifications;

      // Extract unique notification IDs
      // List<String> newUnreadIds = data["notifications"]
      //     .where((notif) => notif["isRead"] == false)
      //     .map<String>((notif) => notif["_id"].toString())
      //     .toList();

      // // Store only unique IDs
      // await storeUnreadIds(newUnreadIds);

      // return List<Map<String, dynamic>>.from(data["notifications"]);
    } catch (error) {
      if (showMessage) {
        hideLoader(context);
        showPopup(context, error.toString());
      }
      return [];
    }
  }

// Fetch join requests and update unread notifications
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
        await storeUnreadIds([]); // Reset unread count if no data
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch join requests");
      }

      // Extract unique notification IDs
      List<String> newUnreadIds = data["joinRequests"]
          .map<String>((req) => req["_id"].toString())
          .toList();

      // Store only unique IDs
      await storeUnreadIds(newUnreadIds);

      return List<Map<String, dynamic>>.from(data["joinRequests"]);
    } catch (error) {
      if (showMessage) {
        hideLoader(context);
        showPopup(context, error.toString());
      }
      return [];
    }
  }

// Fetch post requests and update unread notifications
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
        await storeUnreadIds([]); // Reset unread count if no data
        return [];
      }

      if (response.statusCode != 200) {
        throw Exception("Failed to fetch join requests");
      }

      // Extract unique notification IDs
      List<String> newUnreadIds = data["postRequests"]
          .map<String>((req) => req["_id"].toString())
          .toList();

      // Store only unique IDs
      await storeUnreadIds(newUnreadIds);

      return List<Map<String, dynamic>>.from(data["postRequests"]);
    } catch (error) {
      if (showMessage) {
        hideLoader(context);
        showPopup(context, error.toString());
      }
      return [];
    }
  }

  // Vote function
  static Future<bool> vote(BuildContext context, String voteId) async {
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
          onRefresh: () => Navigator.of(context).pop(), // Refresh group
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
