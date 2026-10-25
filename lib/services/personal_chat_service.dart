import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PersonalChatService {
  static String get baseUrl =>
      AppVariables.get<String>('baseurl')?.trim() ?? 'http://localhost:3000';

  /// Fetch active chats and pending message requests
  static Future<Map<String, dynamic>> getPersonalChats() async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/personal/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'activeChats': data['activeChats'] ?? [],
          'pendingRequests': data['pendingRequests'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ' + response.statusCode.toString(),
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Request a chat with another user (profile visit normal path)
  static Future<Map<String, dynamic>> sendChatRequest({
    required String targetUserId,
    required String initialMessage,
  }) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/personal/chat/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'targetUserId': targetUserId,
          'initialMessage': initialMessage,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to send chat request',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reply to a nearby broadcast tag -> automatically creates/accepts personal chat
  static Future<Map<String, dynamic>> replyToTag({
    required String targetUserId,
    String? replyText,
    String? replyMessage,
    String? broadcastTagText,
  }) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final actualReplyText = (replyText ?? replyMessage ?? '').trim();
      if (actualReplyText.isEmpty) {
        return {'success': false, 'error': 'Reply text cannot be empty'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/personal/chat/reply-tag'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'targetUserId': targetUserId,
          'replyText': actualReplyText,
          'replyMessage': actualReplyText,
          'broadcastTagText': broadcastTagText ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? data['message'] ?? 'Failed to reply to tag',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Broadcast a nearby tag with custom message or predefined tag and configurable TTL in seconds
  static Future<Map<String, dynamic>> broadcastNearbyTag({
    required String message,
    String? tagType,
    int ttlSeconds = 86400,
  }) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/nearby/tag'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'ttlSeconds': ttlSeconds,
          if (tagType != null) 'tagType': tagType,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'tag': data['tag']};
      } else {
        return {
          'success': false,
          'error':
              data['message'] ?? data['error'] ?? 'Failed to broadcast tag',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get the current user's active nearby tag (if any)
  static Future<Map<String, dynamic>> getMyNearbyTag() async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.get(
        Uri.parse('$baseUrl/nearby/tag'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'tag': data['tag']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? 'Failed to get tag',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Delete / Clear the current user's active nearby tag
  static Future<Map<String, dynamic>> deleteNearbyTag() async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.delete(
        Uri.parse('$baseUrl/nearby/tag'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? data['error'] ?? 'Failed to delete tag',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Block user
  static Future<Map<String, dynamic>> blockUser(String targetUserId) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/user/' + targetUserId + '/block'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to block user',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Report user
  static Future<Map<String, dynamic>> reportUser({
    required String targetUserId,
    required String reason,
  }) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.post(
        Uri.parse('$baseUrl/users/' + targetUserId + '/report'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['message'] ?? 'Failed to report user',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Helper: Check if a chat has an unseen message locally
  static Future<bool> isChatUnseen(
      String pairKey, String? latestMessageId) async {
    if (latestMessageId == null || latestMessageId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastSeenId = prefs.getString('last_seen_' + pairKey);
    return lastSeenId != latestMessageId;
  }

  /// Helper: Mark a chat as seen up to messageId
  static Future<void> markChatAsSeen(
      String pairKey, String? latestMessageId) async {
    if (latestMessageId == null || latestMessageId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_' + pairKey, latestMessageId);
  }

  /// Fetch predefined tag suggestions from backend (vibe and update status tags)
  static Future<Map<String, List<String>>> getTagSuggestions(
      {bool fresh = false}) async {
    try {
      final url =
          Uri.parse('$baseUrl/tags/suggestions${fresh ? '?fresh=true' : ''}');
      final response = await http.get(
        url,
        headers: {'Cache-Control': 'max-age=3600'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final vibeRaw = data['vibe'] as List? ?? [];
        final updatesRaw = data['updates'] as List? ?? [];

        final vibe = vibeRaw
            .map((t) {
              if (t is Map) return (t['label'] ?? '').toString();
              return t.toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();

        final updates = updatesRaw
            .map((t) {
              if (t is Map) return (t['label'] ?? '').toString();
              return t.toString();
            })
            .where((s) => s.isNotEmpty)
            .toList();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tag_vibe', jsonEncode(vibe));
        await prefs.setString('cached_tag_updates', jsonEncode(updates));

        return {'vibe': vibe, 'updates': updates};
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final cVibe = prefs.getString('cached_tag_vibe');
      final cUpdates = prefs.getString('cached_tag_updates');
      if (cVibe != null && cUpdates != null) {
        return {
          'vibe': List<String>.from(jsonDecode(cVibe)),
          'updates': List<String>.from(jsonDecode(cUpdates)),
        };
      }
    } catch (_) {}

    return {
      'vibe': [
        '🗣️ Chatterbox',
        '👂 Good Listener',
        '😌 Chill Vibes',
        '🤪 Goofy',
        '🧠 Deep Thinker',
        '🫂 Social Butterfly',
        '🌙 Night Owl',
        '🫣 Shy at First',
        '😈 Mischief Maker',
        '💬 Always Down to Talk',
        '💃 Dance Addict',
        '🎶 Music Person',
        '🍻 Drinks & Vibes',
        '🚬 Smoker',
        '☕ Coffee & Conversations',
        '🍜 Foodie',
        '🏃 Always Outdoor',
        '🎮 Game Nights',
      ],
      'updates': [
        '☕ Coffee Break',
        '📚 Library Study',
        '💻 Coding Project',
        '🍔 Grabbing Food',
        '🏀 Playing Sports',
        '💬 Open to Chat',
      ],
    };
  }

  /// Get current user's My Vibe list from backend
  static Future<List<String>> getMyVibe() async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/user/vibe'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['myVibe'] is List) {
          return List<String>.from(data['myVibe']);
        }
      }
    } catch (e) {
      // ignore
    }
    return [];
  }

  /// Update user's My Vibe in user profile model
  static Future<Map<String, dynamic>> updateMyVibe(List<String> vibes) async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.put(
        Uri.parse('$baseUrl/user/vibe'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'vibes': vibes}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'myVibe': List<String>.from(data['myVibe'] ?? [])
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update vibes'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Clear user's My Vibe
  static Future<Map<String, dynamic>> deleteMyVibe() async {
    try {
      final token = await UserService.getAccessToken();
      if (token == null) return {'success': false, 'error': 'Not logged in'};

      final response = await http.delete(
        Uri.parse('$baseUrl/user/vibe'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'myVibe': []};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to clear vibes'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
