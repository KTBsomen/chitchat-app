import 'dart:convert';

import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/services/user.dart';
import 'package:http/http.dart' as http;

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/fcm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GroupsService {
  static String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  //String? token = await UserService.getAccessToken();
  static String? token =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

// Function to build FriendCircleGroup from JSON or object
  static FriendCircleGroup buildFriendCircleGroup(
      Map<String, dynamic> groupData) {
    return FriendCircleGroup(
      groupId: groupData["_id"],
      groupData: {
        'name': groupData["name"],
        'description': groupData["description"],
        'GroupProfilePic': groupData["GroupProfilePic"],
        'createdBy': groupData["createdBy"],
        'createdAt': groupData["createdAt"],
      },
      members: (groupData["members"] as List<dynamic>)
          .map((member) => FriendCircleMember(
                id: member["memberId"],
                avatarUrl: member["memberProfilePic"] ?? '',
                additionalData: {
                  'memberName': member["memberName"],
                  'memberBio': member["memberBio"],
                  'educationLevel': member["educationLevel"],
                  'school': member["school"],
                  'college': member["college"],
                  'university': member["university"],
                  'semester': member["semester"],
                  'year': member["year"],
                  'userClass': member["userClass"],
                },
              ))
          .toList(),
    );
  }

  static Future<List<FriendCircleGroup>> getRecommendedGroups() async {
    String? token =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    final response = await http.get(
      Uri.parse('$baseurl/recommend/groups'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print(data);
      return data.map((item) {
        // Parsing individual group
        return FriendCircleGroup(
          groupId: item["_id"],
          groupData: {
            'name': item["name"],
            'description': item["description"],
            'GroupProfilePic': item["GroupProfilePic"],
            'createdBy': item["createdBy"],
            'createdAt': item["createdAt"],
            'dbIndex': item["dbIndex"],
          },
          members: (item["members"] as List<dynamic>)
              .map((member) {
                // Parsing individual member
                return FriendCircleMember(
                  id: member["memberId"],
                  avatarUrl: member["memberProfilePic"],
                  additionalData: {
                    'memberName': member["memberName"],
                    'memberBio': member["memberBio"],
                    'educationLevel': member["educationLevel"],
                    'school': member["school"],
                    'college': member["college"],
                    'university': member["university"],
                    'semester': member["semester"],
                    'year': member["year"],
                    'userClass': member["userClass"],
                    'dbIndex': member["dbIndex"] ?? 0,
                  },
                );
              })
              .toList()
              .cast<FriendCircleMember>(), // Ensure proper casting
        );
      }).toList();
    } else {
      throw Exception('Failed to load groups: ${response.statusCode}');
    }
  }

  static Future<List<FriendCircleGroup>> getGroupDetaills(
      {required String gid}) async {
    final response = await http.get(
      Uri.parse('$baseurl//group/details/$gid'),
      headers: {
        "content-type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      print(data);
      return data.map((item) {
        // Parsing individual group
        return FriendCircleGroup(
          groupId: item["_id"],
          groupData: {
            'name': item["name"],
            'description': item["description"],
            'GroupProfilePic': item["GroupProfilePic"],
            'createdBy': item["createdBy"],
            'createdAt': item["createdAt"],
            'dbIndex': item["dbIndex"],
          },
          members: (item["members"] as List<dynamic>)
              .map((member) {
                // Parsing individual member
                return FriendCircleMember(
                  id: member["memberId"],
                  avatarUrl: member["memberProfilePic"],
                  additionalData: {
                    'memberName': member["memberName"],
                    'memberBio': member["memberBio"],
                    'educationLevel': member["educationLevel"],
                    'school': member["school"],
                    'college': member["college"],
                    'university': member["university"],
                    'semester': member["semester"],
                    'year': member["year"],
                    'userClass': member["userClass"],
                    'dbIndex': member["dbIndex"] ?? 0,
                  },
                );
              })
              .toList()
              .cast<FriendCircleMember>(), // Ensure proper casting
        );
      }).toList();
    } else {
      throw Exception('Failed to load groups: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createGroup(
    String groupNames,
    String groupPics,
  ) async {
    try {
      final url = Uri.parse('$baseurl/groups');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': groupNames,
          'description': 'This is a new group',
          'GroupProfilePic': groupPics,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> joinGroup(
    String groupId,
  ) async {
    try {
      final url = Uri.parse('$baseurl/groups/join/$groupId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> leaveGroup(
    String groupId,
  ) async {
    try {
      final url = Uri.parse('$baseurl/groups/leave/$groupId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addToWatchList(
    String groupId,
  ) async {
    try {
      final url = Uri.parse('$baseurl/watchlist/$groupId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeFromWatchList(
    String groupId,
  ) async {
    try {
      final url = Uri.parse('$baseurl/watchlist/$groupId');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Unknown error occurred',
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
