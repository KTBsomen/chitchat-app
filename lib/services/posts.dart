import 'dart:convert';

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

  static Future<Map<String, dynamic>> fetchMyPosts(
      {required String userid, int limit = 10, String? next}) async {
    String? token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    try {
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

  static Future<Map<String, dynamic>> createPost(
      {required List<String> files,
      required bool isGroupPost,
      required String myGroupId}) async {
    String? token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";
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
}
