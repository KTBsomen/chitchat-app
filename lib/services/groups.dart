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
        "dbIndex": groupData["dbIndex"] ?? 0,
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
                  'dbIndex': member["dbIndex"] ?? 0,
                },
              ))
          .toList(),
    );
  }

  static Future<List<FriendCircleGroup>> getRecommendedGroups() async {
    String? token = await UserService.getAccessToken();

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

  static Future<List<FriendCircleGroup>> getGroupDetails(
      {required String gid}) async {
    final response = await http.get(
      Uri.parse('$baseurl/group/details/$gid'),
      headers: {
        "content-type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> _Responsedata = json.decode(response.body);
      final List<dynamic> data = _Responsedata['group'];
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
            'dbIndex': item["dbIndex"] ?? 0,
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
      String? token = await UserService.getAccessToken();

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

  static Future<Map<String, dynamic>> updateGroup(
      {String? groupNames,
      String? groupPics,
      required String groupId,
      required int dbIndex}) async {
    try {
      final url = Uri.parse('$baseurl/groups');
      String? token = await UserService.getAccessToken();

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "groupId": groupId,
          'dbIndex': dbIndex,
          'name': groupNames,
          'description': 'This is a new group',
          'GroupProfilePic': groupPics,
        }),
      );

      if (response.statusCode == 200) {
        await UserService.fetchMyProfile();

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

  static UserBio parseBio(String fullBio) {
    const delimiter = '\u2063'; // INVISIBLE SEPARATOR
    final parts = fullBio.split(delimiter);

    final cleanBio = parts.isNotEmpty ? parts[0] : '';
    final editedBy = (parts.length > 1 &&
            parts[1].startsWith('<!--u:') &&
            parts[1].endsWith('-->'))
        ? parts[1].replaceAll(RegExp(r'<!--u:|-->'), '')
        : '';
    print('Parsed bio: $cleanBio, editedBy: $editedBy');
    return UserBio(
      bio: cleanBio,
      editedBy: editedBy,
    );
  }

  static Future<Map<String, dynamic>> updateMemberBio(
      {String? bio, required String groupId, required String userId}) async {
    try {
      final url = Uri.parse('$baseurl/groups/bio/$groupId');
      String? token = await UserService.getAccessToken();

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bio': bio,
          "userId": userId,
        }),
      );

      if (response.statusCode == 200) {
        await UserService.fetchMyProfile();

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
      String? token = await UserService.getAccessToken();

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

  static Future<Map<String, dynamic>> cancelJoinRequest(
    String groupId, {
    String? requestId,
  }) async {
    try {
      // Use direct request ID endpoint if available, otherwise fallback to groupId
      final url = (requestId != null && requestId.isNotEmpty)
          ? Uri.parse('$baseurl/groups/join/request/$requestId')
          : Uri.parse('$baseurl/groups/join/$groupId');
      String? token = await UserService.getAccessToken();

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

  static Future<Map<String, dynamic>> leaveGroup(
    String groupId,
  ) async {
    try {
      final url = Uri.parse('$baseurl/groups/leave/$groupId');

      String? token = await UserService.getAccessToken();
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
      String? token = await UserService.getAccessToken();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
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
      String? token = await UserService.getAccessToken();

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

class UserBio {
  String? bio;
  String? editedBy;

  UserBio({this.bio, this.editedBy});
  factory UserBio.fromJson(Map<String, dynamic> json) {
    return UserBio(
      bio: json['bio'],
      editedBy: json['editedBy'],
    );
  }
}
