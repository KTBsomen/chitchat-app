import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserStory {
  final String id; // Unique identifier for each story
  final String user;
  final String name;
  final String username;
  final String profilePic;
  final List<MediaItem> media;
  final String visibleTo;
  final DateTime date;
  bool isViewed;
  bool myStory = false; // Default to false
  final List views;
  final int dbIndex; // Default to 0, can be used for database indexing

  UserStory({
    required this.id,
    required this.user,
    required this.name,
    required this.username,
    required this.profilePic,
    required this.media,
    required this.visibleTo,
    required this.views,
    this.isViewed = false, // Default to false
    required this.date,
    this.myStory = false,
    required this.dbIndex,
  });

  factory UserStory.fromJson(Map<String, dynamic> json) {
    return UserStory(
      id: json['_id'],
      user: json['user'],
      name: json['name'],
      profilePic: json['profilePic'] ?? "https://picsum.photos/200/300",
      username: json['username'],
      visibleTo: json['visibleTo'],
      views: json['views'] ?? [],
      date: DateTime.parse(json['createdAt']),
      media: (json['media'] as List)
          .map((item) => MediaItem.fromJson(item))
          .toList(),
      dbIndex: json['dbIndex'] ?? 0,
    );
  }

  Color getColor() {
    if (visibleTo == "members") return Colors.yellow;
    if (visibleTo == "singleUser") return Colors.green;
    if (visibleTo == "me") return Colors.transparent;
    return Colors.red;
  }
}

class MediaItem {
  final String type;
  final String url;

  MediaItem({required this.type, required this.url});

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      type: json['type'],
      url: json['url'],
    );
  }
  // To help remove duplicates
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          url == other.url;

  @override
  int get hashCode => type.hashCode ^ url.hashCode;
}

class StoryService {
  static String baseUrl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  // static String? token =
  //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3NDA3YjgwZmRkODEwZjUzYmU2OGE5NSIsInVzZXJJZCI6IjY3NDA3YjgwZmRkODEwZjUzYmU2OGE5NSIsImVtYWlsIjoiYW5pa2FfMzAwQGV4YW1wbGUuY29tIiwicHJvZmlsZVBpYyI6Imh0dHBzOi8vcmFuZG9tdXNlci5tZS9hcGkvcG9ydHJhaXRzL3dvbWVuLzk0LmpwZz9uYXQ9aW4iLCJuYW1lIjoiQW5pa2EiLCJ1c2VybmFtZSI6ImFuaWthXzMwMCIsImJpbyI6IkhpLCBJJ20gQW5pa2EuIEV4Y2l0ZWQgdG8gY29ubmVjdCEiLCJlZHVjYXRpb25MZXZlbCI6IlBhc3NvdXQiLCJ1bml2ZXJzaXR5IjoiRGVsaGkgVW5pdmVyc2l0eSIsImNvbGxlZ2UiOiJIaW5kdSBDb2xsZWdlIiwic2Nob29sIjoiU2FpbmlrIFNjaG9vbCIsInNlbWVzdGVyIjpudWxsLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOiIyMDAyIiwiYmlydGhkYXkiOiIyMDA5LTExLTMwVDE4OjMwOjAwLjAwMFoiLCJkYkluZGV4IjowLCJpYXQiOjE3MzIyNzkxNjh9.gRcD-2161J6ltUhKR7b6C24pd3_6VXc3taO8xZ0kCLE";

  static List<UserStory> parseAndMergeStories(String responseBody) {
    List<dynamic> data = jsonDecode(responseBody);

    Map<String, UserStory> mergedMap = {};

    for (var storyJson in data) {
      UserStory story = UserStory.fromJson(storyJson);
      String key = '${story.user}-${story.visibleTo}';

      if (mergedMap.containsKey(key)) {
        // Merge media, avoiding duplicates
        var existingMedia = mergedMap[key]!.media.toSet();
        var newMedia = story.media.toSet();
        mergedMap[key]!.media
          ..clear()
          ..addAll([...existingMedia.union(newMedia)]);
      } else {
        mergedMap[key] = UserStory(
          id: story.id,
          user: story.user,
          visibleTo: story.visibleTo,
          name: story.name,
          username: story.username,
          profilePic: story.profilePic,
          media: [...story.media],
          date: story.date,
          views: [...story.views],
          isViewed: story.isViewed,
          dbIndex: story.dbIndex,
        );
      }
    }

    return mergedMap.values.toList();
  }

  static Future<List<UserStory>> getMyStories(
      {bool? invalidate = false}) async {
    // String? token = await UserService.getAccessToken();
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    print("my token $token");

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/my/chits').replace(queryParameters: {
          if (invalidate == true) 'invalidate': 'true',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        List<UserStory> fetchedStories = parseAndMergeStories(response.body);

        for (var e in fetchedStories) {
          e.myStory = true;
        }
        return fetchedStories;
      } else {
        return [];
      }
    } on Exception catch (e) {
      print('Error: $e');
      throw Exception('Failed to load stories');
    }
  }

  static Future<List<UserStory>> getStories({bool? invalidate = false}) async {
    String? uid = await UserService.getUserId();
    // String? token = await UserService.getAccessToken();
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    print(token);
    if (uid == null) {
      throw Exception('User ID not found');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chits/$uid').replace(queryParameters: {
          if (invalidate == true) 'invalidate': 'true',
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        List<UserStory> fetchedStories = parseAndMergeStories(response.body);

        return fetchedStories;
      } else {
        return [];
      }
    } on Exception catch (e) {
      print('Error: $e');
      throw Exception('Failed to load stories');
    }
  }

  static Future<Map<String, dynamic>> CreateStory({
    required List<String> members,
    required List<String> files,
    required String myGroupId,
    bool? invalidate = false,
    bool sendToAll = false,
  }) async {
    String? uid = await UserService.getUserId();
    if (uid == null) {
      throw Exception('User ID not found');
    }
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    List<Map<String, dynamic>> media = [];
    for (String file in files) {
      String mediaType;
      String extension = file.toLowerCase().split('.').last;

      // Video formats
      if (['mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', '3gp', 'm4v']
          .contains(extension)) {
        mediaType = 'video';
      }
      // Audio formats
      else if (['mp3', 'wav', 'ogg', 'aac', 'flac', 'm4a', 'wma', 'opus']
          .contains(extension)) {
        mediaType = 'audio';
      }
      // Document formats
      else if ([
        'pdf',
        'doc',
        'docx',
        'txt',
        'rtf',
        'odt',
        'xls',
        'xlsx',
        'ppt',
        'pptx'
      ].contains(extension)) {
        mediaType = 'document';
      }
      // Image formats
      else if ([
        'jpg',
        'jpeg',
        'png',
        'gif',
        'bmp',
        'webp',
        'svg',
        'tiff',
        'heic',
        'raw'
      ].contains(extension)) {
        mediaType = 'image';
      }
      // Default case for unknown formats
      else {
        throw Exception('Unsupported file format: $extension');
      }

      media.add({
        "type": mediaType,
        "url": file,
      });
    }

    try {
      final response = await http.post(
          Uri.parse('$baseUrl/chits').replace(queryParameters: {
            if (invalidate == true) 'invalidate': 'true',
          }),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            "media": media,
            "visibleTo": sendToAll
                ? "all"
                : members.length == 1
                    ? 'singleUser'
                    : members.length > 1
                        ? 'members'
                        : 'all',
            "members": members,
            "SingleUser": members.length == 1 ? members[0] : null,
            "myGroup": myGroupId
          }));
      print(response.body);
      print(response.statusCode);
      if (response.statusCode == 201) {
        Map<String, dynamic> data = jsonDecode(response.body);
        print(data);
        UserStory fetchedStories = UserStory.fromJson(data["chit"]);

        return {"success": true, "chit": fetchedStories};
      } else {
        return {"success": false, "chit": null};
      }
    } on Exception catch (e) {
      print('Error: $e');
      throw Exception('Failed to load stories');
    }
  }

  static List<UserStory> sortStories(List<UserStory> stories) {
    stories.sort((a, b) {
      if (a.isViewed && !b.isViewed) return 1; // Move viewed to end
      if (!a.isViewed && b.isViewed) return -1;
      return 0;
    });
    return stories;
  }

  static Future<void> markStoryAsViewed(String storyId, int dbIndex) async {
    String? uid = await UserService.getUserId();
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    if (uid == null) {
      throw Exception('User ID not found');
    }
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chits/$storyId/$dbIndex/views'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"userId": uid}),
      );
      if (response.statusCode == 200) {
        print('Story marked as viewed successfully');
      } else {
        print('Failed to mark story as viewed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking story as viewed: $e');
      throw Exception('Failed to mark story as viewed');
    }
  }
}
