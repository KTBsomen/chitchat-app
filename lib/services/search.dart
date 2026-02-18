import 'dart:convert';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/user.dart';
import 'package:http/http.dart' as http;

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';

class SearchService {
  static String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  //String? token = await UserService.getAccessToken();
  static Future<List<FriendCircleGroup>> searchByGroup(String q) async {
    String? token = await UserService.getAccessToken();
    // "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    final response = await http.get(
      Uri.parse('$baseurl/search/groups?q=$q'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      print(data);
      return (data["results"] as List).map<FriendCircleGroup>((item) {
        // Parsing individual group
        return GroupsService.buildFriendCircleGroup(item);
      }).toList();
    } else {
      throw Exception('Failed to load groups: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> searchByUser(String q) async {
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    final response = await http.get(
      Uri.parse('$baseurl/search/users?q=$q'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      print(data);
      return (data["results"] as List).map<Map<String, dynamic>>((item) {
        // Parsing individual user
        return {
          "id": item["_id"],
          "name": item["name"],
          "email": item["email"],
          "profilePic": item["profilePic"],
          "bio": item["bio"],
          "college": item["college"],
          "university": item["university"],
          "dbIndex": item["dbIndex"],
        };
      }).toList();
    } else {
      throw Exception('Failed to load groups: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> searchByCollege(String q) async {
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    final response = await http.get(
      Uri.parse('$baseurl/autocomplete/college?q=$q'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load APIs: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> searchByUniversity(String q) async {
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    final response = await http.get(
      Uri.parse('$baseurl/autocomplete/university?q=$q'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load APIs: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> searchBySchool(String q) async {
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    final response = await http.get(
      Uri.parse('$baseurl/autocomplete/school?q=$q'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load schools: ${response.statusCode}');
    }
  }

  static String _getAutocompletePath(String level) {
    switch (level) {
      case 'School':
        return '/autocomplete';
      case 'College':
        return '/autocomplete/college';
      case 'University':
        return '/autocomplete/university';
      default:
        return '/autocomplete/university';
    }
  }

  static Future<Map<String, dynamic>?> fetchInstitutionById(
      String id, String level) async {
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    final prefix = _getAutocompletePath(level);
    final response = await http.get(
      Uri.parse('$baseurl$prefix/institution/$id'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      return null;
    } else {
      print('Failed to fetch institution: ${response.statusCode}');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchRecommendedInstitutions(
      String level) async {
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    final prefix = _getAutocompletePath(level);
    final response = await http.get(
      Uri.parse('$baseurl$prefix/recommended'),
      headers: {
        "content-type": "application/json",
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      print('Failed to load recommended institutions: ${response.statusCode}');
      return [];
    }
  }
}
