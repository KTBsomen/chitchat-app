import 'dart:convert';
import 'package:chitchat/appstate/storyPrefs.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserStory {
  final String id; // Primary story ID (first in group)
  final String user;
  final String name;
  final String username;
  final String profilePic;
  final List<MediaItem> media;
  final String visibleTo;
  final DateTime date;
  bool _isViewed = false;
  bool myStory = false;
  final List views;
  final int dbIndex;

  // NEW: Track all individual story IDs in this merged group
  final List<String> allStoryIds;
  // NEW: Track all dbIndices for each story
  final List<int> allStoryDbIndices;
  // NEW: Latest story timestamp for "new story" detection
  final DateTime latestStoryDate;
  // NEW: Map individual story IDs to their respective views
  final Map<String, List<dynamic>> storyViewsMap;

  UserStory({
    required this.id,
    required this.user,
    required this.name,
    required this.username,
    required this.profilePic,
    required this.media,
    required this.visibleTo,
    required this.views,
    bool isViewed = false,
    required this.date,
    this.myStory = false,
    required this.dbIndex,
    List<String>? allStoryIds,
    List<int>? allStoryDbIndices,
    DateTime? latestStoryDate,
    Map<String, List<dynamic>>? storyViewsMap,
  })  : allStoryIds = allStoryIds ?? [id],
        allStoryDbIndices = allStoryDbIndices ?? [dbIndex],
        latestStoryDate = latestStoryDate ?? date,
        storyViewsMap = storyViewsMap ?? {id: views} {
    // Initialize viewed state - check if ALL stories in the group are viewed
    _isViewed = isViewed || _areAllStoriesViewed();
  }

  /// Check if ALL individual stories in this group have been viewed
  bool _areAllStoriesViewed() {
    for (final storyId in allStoryIds) {
      if (!StoryPrefs.hasViewedSync(storyId)) {
        return false;
      }
    }
    return true;
  }

  /// Check if there are any unviewed stories in this group
  bool hasUnviewedStories() {
    for (final storyId in allStoryIds) {
      if (!StoryPrefs.hasViewedSync(storyId)) {
        return true;
      }
    }
    return false;
  }

  /// Get total view count across all stories in the group
  int get totalViewCount {
    final Set<String> uniqueViewers = {};
    for (final viewsList in storyViewsMap.values) {
      for (final view in viewsList) {
        if (view['userId'] != null) {
          uniqueViewers.add(view['userId'].toString());
        }
      }
    }
    return uniqueViewers.length;
  }

  /// Get all unique views across all stories (deduplicated by userId)
  List<dynamic> get allUniqueViews {
    final Map<String, dynamic> uniqueViewsMap = {};
    for (final viewsList in storyViewsMap.values) {
      for (final view in viewsList) {
        final viewerId = view['userId']?.toString() ?? view['_id']?.toString();
        if (viewerId != null && !uniqueViewsMap.containsKey(viewerId)) {
          uniqueViewsMap[viewerId] = view;
        }
      }
    }
    return uniqueViewsMap.values.toList();
  }

  bool get isViewed => _isViewed;

  set isViewed(bool value) {
    _isViewed = value;
    if (value) {
      // Mark ALL stories in this group as viewed
      for (final storyId in allStoryIds) {
        StoryPrefs.markAsViewed(storyId);
      }
    } else {
      // Unmark ALL stories in this group
      for (final storyId in allStoryIds) {
        StoryPrefs.unmarkAsViewed(storyId);
      }
    }
  }

  /// Mark all stories in this group as viewed on the server
  Future<void> markAllAsViewedOnServer() async {
    for (int i = 0; i < allStoryIds.length; i++) {
      final storyId = allStoryIds[i];
      final dbIdx =
          i < allStoryDbIndices.length ? allStoryDbIndices[i] : dbIndex;
      if (!StoryPrefs.hasViewedSync(storyId)) {
        await StoryService.markStoryAsViewed(storyId, dbIdx);
      }
    }
    isViewed = true;
  }

  /// Get the index of the first media item that belongs to an unviewed story
  /// Returns 0 if all stories are viewed or no unviewed media found
  int getFirstUnviewedMediaIndex() {
    for (int i = 0; i < media.length; i++) {
      final mediaItem = media[i];
      // Check if this media's parent story is unviewed
      if (mediaItem.storyId != null &&
          !StoryPrefs.hasViewedSync(mediaItem.storyId!)) {
        return i;
      }
    }
    // If no media has storyId or all are viewed, try checking allStoryIds
    for (int i = 0; i < allStoryIds.length; i++) {
      if (!StoryPrefs.hasViewedSync(allStoryIds[i])) {
        // Return the index of first media that might be from this story
        // Since media is ordered, we can estimate based on story position
        int mediaPerStory = media.length ~/ allStoryIds.length;
        return (i * mediaPerStory).clamp(0, media.length - 1);
      }
    }
    return 0; // Default to first media
  }

  factory UserStory.fromJson(Map<String, dynamic> json) {
    final storyId = json['_id'];
    final storyViews = json['views'] ?? [];
    return UserStory(
      id: storyId,
      user: json['user'],
      name: json['name'],
      profilePic: json['profilePic'] ?? "https://picsum.photos/200/300",
      username: json['username'],
      visibleTo: json['visibleTo'],
      views: storyViews,
      date: DateTime.parse(json['createdAt']),
      media: (json['media'] as List)
          .map((item) => MediaItem.fromJson(item))
          .toList(),
      dbIndex: json['dbIndex'] ?? 0,
      allStoryIds: [storyId],
      allStoryDbIndices: [json['dbIndex'] ?? 0],
      latestStoryDate: DateTime.parse(json['createdAt']),
      storyViewsMap: {storyId: storyViews},
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
  final String? storyId; // Track which story this media belongs to

  MediaItem({required this.type, required this.url, this.storyId});

  factory MediaItem.fromJson(Map<String, dynamic> json, {String? storyId}) {
    return MediaItem(
      type: json['type'],
      url: json['url'],
      storyId: storyId,
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
        final existing = mergedMap[key]!;

        // Merge media with storyId tracking, avoiding duplicates
        var existingMedia = existing.media.toSet();
        var newMedia = story.media
            .map((m) => MediaItem(
                  type: m.type,
                  url: m.url,
                  storyId: story.id,
                ))
            .toSet();
        existing.media
          ..clear()
          ..addAll([...existingMedia.union(newMedia)]);

        // Add this story's ID to the list of all IDs
        if (!existing.allStoryIds.contains(story.id)) {
          existing.allStoryIds.add(story.id);
          existing.allStoryDbIndices.add(story.dbIndex);
        }

        // Merge views into the storyViewsMap
        existing.storyViewsMap[story.id] = story.views;

        // Update latestStoryDate if this story is newer
        // Note: We need to recreate with updated latestStoryDate
        // Since latestStoryDate is final, we track it separately
      } else {
        // Create media items with storyId tracking
        final mediaWithIds = story.media
            .map((m) => MediaItem(
                  type: m.type,
                  url: m.url,
                  storyId: story.id,
                ))
            .toList();

        mergedMap[key] = UserStory(
          id: story.id,
          user: story.user,
          visibleTo: story.visibleTo,
          name: story.name,
          username: story.username,
          profilePic: story.profilePic,
          media: mediaWithIds,
          date: story.date,
          views: [...story.views],
          isViewed: false, // Will be recalculated based on allStoryIds
          dbIndex: story.dbIndex,
          allStoryIds: [story.id],
          allStoryDbIndices: [story.dbIndex],
          latestStoryDate: story.date,
          storyViewsMap: {story.id: story.views},
        );
      }
    }

    // After merging, recalculate viewed state for each merged story
    final result = mergedMap.values.toList();

    // Sort by latest story date (newest first within each group)
    result.sort((a, b) {
      // Unviewed stories should come first
      if (a.hasUnviewedStories() && !b.hasUnviewedStories()) return -1;
      if (!a.hasUnviewedStories() && b.hasUnviewedStories()) return 1;
      // Then sort by date (newest first)
      return b.latestStoryDate.compareTo(a.latestStoryDate);
    });

    return result;
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
