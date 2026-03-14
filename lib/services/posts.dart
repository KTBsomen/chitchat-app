import 'dart:convert';

import 'package:chitchat/components/comments.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/services/user.dart';
import 'package:http/http.dart' as http;

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/fcm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class PostService {
  static String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  // static String? token =
  //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

  static Future<Map<String, dynamic>> fetchMyPosts(
      {required String userid, int limit = 10, String? next}) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.get(
        Uri.parse(
            "$baseurl/auth/posts/$userid?limit=$limit${next != null ? "&next=$next" : ""}"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchUserPosts(
      {required String userid, int limit = 10, String? next}) async {
    try {
      final response = await http.get(
        Uri.parse(
            "$baseurl/posts/$userid?limit=$limit${next != null ? "&next=$next" : ""}"),
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchGroupPosts(
      {required String groupId, int limit = 10, String? next}) async {
    try {
      final response = await http.get(
        Uri.parse(
            "$baseurl/posts/group/$groupId?limit=$limit${next != null ? "&next=$next" : ""}"),
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchMyGroupPosts(
      {required String groupId, int limit = 10, String? next}) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.get(
          Uri.parse(
              "$baseurl/auth/posts/group/$groupId?limit=$limit${next != null ? "&next=$next" : ""}"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          });

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> createPost(
      {required List<String> files,
      required bool isGroupPost,
      required String myGroupId,
      String? memoryId,
      bool isMemory = false,
      int? memoryDBIndex}) async {
    List<Map<String, dynamic>> media = [];
    for (String file in files) {
      String mediaType;
      if (file.endsWith('.mp4')) {
        mediaType = 'video';
      } else if (file.endsWith('.mp3')) {
        mediaType = 'audio';
      } else {
        mediaType = 'image';
      }
      media.add({
        "type": mediaType,
        "url": file,
      });
    }
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.post(Uri.parse("$baseurl/posts"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode({
            "content": "This is a new post",
            "media": media,
            "groupId": myGroupId,
            "isGroupPost": isGroupPost,
            "isMemory": isMemory,
            "memoryId": memoryId,
            "memoryDBIndex": memoryDBIndex
          }));

      if (response.statusCode == 201) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchPostById(String postId) async {
    try {
      String? token = await UserService.getAccessToken();
      final response = await http.get(
        Uri.parse("$baseurl/posts/post/$postId"),
        headers: token != null ? {"Authorization": "Bearer $token"} : {},
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch post",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.delete(
        Uri.parse('$baseurl/posts/$postId'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": "Post deleted successfully",
        };
      } else {
        return {
          "success": false,
          "error": "Failed to delete Post",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchMyGroupMemories(
      {required String groupId, int limit = 10, String? next}) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.get(
          Uri.parse(
              "$baseurl/memories/$groupId?limit=$limit${next != null ? "&next=$next" : ""}"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          });

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> createMemories(
      {required List<String> files, required String myGroupId}) async {
    List<Map<String, dynamic>> media = [];
    for (String file in files) {
      String mediaType;
      if (file.endsWith('.mp4')) {
        mediaType = 'video';
      } else if (file.endsWith('.mp3')) {
        mediaType = 'audio';
      } else {
        mediaType = 'image';
      }
      media.add({
        "type": mediaType,
        "url": file,
      });
    }
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.post(Uri.parse("$baseurl/memories"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode({
            "media": media,
            "groupId": myGroupId,
          }));

      if (response.statusCode == 201) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch memories",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  /// Delete a memory by its ID
  /// DELETE /memories/:memoryId
  static Future<Map<String, dynamic>> deleteMemory(
      {required String memoryId}) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.delete(
        Uri.parse('$baseurl/memories/$memoryId'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": "Memory deleted successfully",
        };
      } else if (response.statusCode == 403) {
        return {
          "success": false,
          "error": "Unauthorized - you can only delete your own memories",
        };
      } else if (response.statusCode == 404) {
        return {
          "success": false,
          "error": "Memory not found",
        };
      } else {
        return {
          "success": false,
          "error": "Failed to delete memory",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  /// Toggle the public visibility of a memory
  /// PUT /memories/public/:memoryId
  static Future<Map<String, dynamic>> toggleMemoryPublic({
    required String memoryId,
    required bool isPublic,
  }) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.put(
        Uri.parse('$baseurl/memories/public/$memoryId'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "public": isPublic,
        }),
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else if (response.statusCode == 403) {
        return {
          "success": false,
          "error": "Unauthorized - you can only edit your own memories",
        };
      } else if (response.statusCode == 404) {
        return {
          "success": false,
          "error": "Memory not found",
        };
      } else {
        return {
          "success": false,
          "error": "Failed to update memory visibility",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>?> fetchRelatedPosts({
    required String postId,
    int limit = 10,
    String? groupPostsCursor,
    String? memberPostsCursor,
    String? authorPostsCursor,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      if (groupPostsCursor != null) {
        queryParams['groupPostsCursor'] = groupPostsCursor;
      }
      if (memberPostsCursor != null) {
        queryParams['memberPostsCursor'] = memberPostsCursor;
      }
      if (authorPostsCursor != null) {
        queryParams['authorPostsCursor'] = authorPostsCursor;
      }

      final uri = Uri.parse('$baseurl/posts/$postId/related')
          .replace(queryParameters: queryParams);
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": json.decode(response.body),
        };
      } else {
        print('Failed to load posts: ${response.statusCode}');
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      print('Network error: $e');
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> toggleLikeOnPost(String postId) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.post(
        Uri.parse('$baseurl/posts/$postId/like'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": "Like removed",
        };
      } else if (response.statusCode == 201) {
        return {
          "success": true,
          "message": "Post liked",
        };
      } else {
        return {
          "success": false,
          "error": "Failed to toggle like",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchComments(String postId,
      {String? lastId, int limit = 10}) async {
    try {
      // Construct the URL with pagination parameters
      final uri = Uri.parse('$baseurl/posts/$postId/comments')
          .replace(queryParameters: {
        if (lastId != null) 'lastId': lastId,
        'limit': limit.toString(),
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        // Parse the response
        final Map<String, dynamic> responseData = json.decode(response.body);

        List<Comment> comments = (responseData['comments'] as List)
            .map((json) => Comment.fromJson(json))
            .toList();

        return {
          "comments": comments,
          "hasMore": responseData['hasMore'],
          "lastId": responseData['lastId']
        };
      } else {
        throw Exception('Failed to load comments');
      }
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  static Future<Map<String, dynamic>> createComment({
    required String comment,
    required List<String> files,
    required String postId,
  }) async {
    List<Map<String, dynamic>> media = [];
    for (String file in files) {
      String mediaType;
      if (file.endsWith('.mp4')) {
        mediaType = 'video';
      } else if (file.endsWith('.mp3')) {
        mediaType = 'audio';
      } else {
        mediaType = 'image';
      }
      media.add({
        "type": mediaType,
        "url": file,
      });
    }
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.post(
          Uri.parse('$baseurl/posts/$postId/comments'),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode({
            "content": comment,
            "media": media,
          }));
      print(response.body);
      if (response.statusCode == 201) {
        return {
          "success": true,
          "data": Comment.fromJson(jsonDecode(response.body)),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch posts",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> editComment({
    required String commentId,
    required String content,
    required List<String> mediaFiles,
  }) async {
    List<Map<String, dynamic>> media = [];
    for (String file in mediaFiles) {
      String mediaType;
      if (file.endsWith('.mp4')) {
        mediaType = 'video';
      } else if (file.endsWith('.mp3')) {
        mediaType = 'audio';
      } else {
        mediaType = 'image';
      }
      media.add({
        "type": mediaType,
        "url": file,
      });
    }
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.put(
        Uri.parse('$baseurl/comments/$commentId'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "content": content,
          "media": media,
        }),
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to edit comment",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> deleteComment(String commentId) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.delete(
        Uri.parse('$baseurl/comments/$commentId'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "message": "Comment deleted successfully",
        };
      } else {
        return {
          "success": false,
          "error": "Failed to delete comment",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> toggleLikeOnComment(
      String commentId) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) {
        return {
          "success": false,
          "error": "User not authenticated",
        };
      }
      final response = await http.post(
        Uri.parse('$baseurl/comments/$commentId/like'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        return {
          "success": true,
          "status": "unliked",
          "message": "Like removed",
        };
      } else if (response.statusCode == 201) {
        return {
          "success": true,
          "status": "liked",
          "message": "Comment liked",
        };
      } else {
        return {
          "success": false,
          "error": "Failed to toggle like",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}
