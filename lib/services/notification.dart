import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
