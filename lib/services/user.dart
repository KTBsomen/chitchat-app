import 'dart:convert';

import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/services/groups.dart';
import 'package:http/http.dart' as http;

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/fcm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class UserService {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserId = 'userId';
  static const String _keyFcmToken = 'fcmToken';
  static const String _keyAccessToken = 'serverAccessToken';
  static String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';

  static Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, value);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  static Future<void> setUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> setFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFcmToken, token);
  }

  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFcmToken);
  }

  static Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, token);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFcmToken);
    await prefs.remove(_keyAccessToken);
  }

  static Future<bool> checkLoginStatus() async {
    final isLoggedIn = await UserService.isLoggedIn();
    final userId = await UserService.getUserId();
    return isLoggedIn && userId != null;
  }

  /// Signs in the user using Google authentication.
  ///
  /// This method handles the Google Sign-In process, including:
  /// - Initiating Google Sign-In
  /// - Retrieving authentication tokens
  /// - Sending the token to the server for authentication
  /// - Storing user and session information
  ///
  /// [onLoading] is a callback function that receives a boolean indicating
  /// the loading state of the sign-in process.
  ///
  /// Throws an exception if sign-in fails or the server authentication is unsuccessful.
  static Future<void> signInWithGoogle(Function(bool) onLoading) async {
    onLoading(true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        throw Exception('User canceled the sign-in process');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print(
          "==========================\n$googleUser\n${googleAuth.accessToken}");
      String? token = await FCMService.getFcmToken();
      if (token != null) {
        AppVariables.update("fcmToken", token);
        setFcmToken(token);
      }
      final response = await http.post(
        Uri.parse('${AppVariables.get("baseurl")}/google/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': googleAuth.accessToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data);
        Map<String, dynamic> user = data['user'] as Map<String, dynamic>;
        await setAccessToken(data['token']);
        await setLoggedIn(true);
        await setUserId(user['_id']);
        print('Signedin: ${googleUser.displayName}');
        print('FCM Token: $token');
        final profile = AuthProfile(
          email: googleUser.email,
          name: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
          provider: 'google',
        );
        AppVariables.update("userProfile", profile);
        AppVariables.update("serverProfile", user);
        AppVariables.update("fcmToken", token);
        await FCMService.uploadFcmToken(token!);
        await fetchMyProfile();
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        await UserService.signOut(onLoading);

        if (data['code'] == 'account_pending_deletion') {
          throw Exception('ACCOUNT_PENDING_DELETION');
        }
        throw Exception(data['message'] ?? 'Access denied');
      } else if (response.statusCode == 401) {
        await UserService.signOut(onLoading);
        throw Exception('Invalid Token try to login again');
      } else if (response.statusCode == 404) {
        //user not found so needs to registerd.
        final profile = AuthProfile(
          email: googleUser.email,
          name: googleUser.displayName,
          photoUrl: googleUser.photoUrl,
          provider: 'google',
        );
        AppVariables.update("userProfile", profile);
      } else {
        throw Exception('Failed to authenticate with server');
      }

      // if (response.statusCode != 400) {
      //   throw Exception('Failed to authenticate with server');
      // }
      // print("response.body ${response.body}");
      // await setLoggedIn(true);
      // await setUserId(googleUser.id);
      // String? token = await FCMService.getFcmToken();
      // print('Signed in: ${googleUser.displayName}');
      // print('FCM Token: $token');
      // AppVariables.update("userProfile", googleUser);
      // AppVariables.update("fcmToken", token);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow; // Re-throw to handle in UI
    } finally {
      onLoading(false);
    }
  }

  /// Signs in the user using Apple authentication.
  static Future<void> signInWithApple(Function(bool) onLoading) async {
    onLoading(true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? identityToken = credential.identityToken;
      if (identityToken == null) {
        throw Exception('Apple Sign-In failed: No identity token returned');
      }

      // Reconstruct user's name if provided by Apple (only first time)
      String? name;
      if (credential.givenName != null || credential.familyName != null) {
        name = '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
            .trim();
      }

      String? token = await FCMService.getFcmToken();
      if (token != null) {
        AppVariables.update("fcmToken", token);
        setFcmToken(token);
      }

      final response = await http.post(
        Uri.parse('${AppVariables.get("baseurl")}/apple/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': identityToken,
          if (name != null && name.isNotEmpty) 'name': name,
        }),
      );

      final authProfile = AuthProfile(
        email: credential.email ?? '',
        name: name,
        photoUrl: null,
        appleId: credential.userIdentifier,
        provider: 'apple',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(data);
        Map<String, dynamic> user = data['user'] as Map<String, dynamic>;
        await setAccessToken(data['token']);
        await setLoggedIn(true);
        await setUserId(user['_id']);
        print('Signed in with Apple: ${user['name']}');
        print('FCM Token: $token');

        final finalProfile = AuthProfile(
          email: user['email'] ?? authProfile.email,
          name: user['name'] ?? authProfile.name,
          photoUrl: user['profilePic'],
          appleId: user['appleId'] ?? authProfile.appleId,
          provider: 'apple',
        );

        AppVariables.update("userProfile", finalProfile);
        AppVariables.update("serverProfile", user);
        AppVariables.update("fcmToken", token);
        await FCMService.uploadFcmToken(token!);
        await fetchMyProfile();
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        await UserService.signOut(onLoading);

        if (data['code'] == 'account_pending_deletion') {
          throw Exception('ACCOUNT_PENDING_DELETION');
        }
        throw Exception(data['message'] ?? 'Access denied');
      } else if (response.statusCode == 401) {
        await UserService.signOut(onLoading);
        throw Exception('Invalid Token try to login again');
      } else if (response.statusCode == 404) {
        // User not found so needs to be registered.
        final data = jsonDecode(response.body);
        final details = data['detailsFromApple'] ?? {};

        final registrationProfile = AuthProfile(
          email: details['email'] ?? authProfile.email,
          name: details['name'] ?? authProfile.name,
          photoUrl: null,
          appleId: authProfile.appleId,
          provider: 'apple',
        );
        AppVariables.update("userProfile", registrationProfile);
      } else {
        throw Exception('Failed to authenticate with server');
      }
    } catch (e) {
      print('Error signing in with Apple: $e');
      rethrow;
    } finally {
      onLoading(false);
    }
  }

  static refreshFCMToken() {
    FCMService.getFcmToken().then((token) {
      if (token != null) {
        AppVariables.update("fcmToken", token);
        setFcmToken(token);
        FCMService.uploadFcmToken(token);
      }
    });
  }

  static Future<void> signOut(Function(bool) onLoading) async {
    onLoading(true);
    try {
      await GoogleSignIn().signOut();
      await clearUserData();
      print('User signed out');
    } catch (e) {
      print('Error signing out: $e');
      rethrow; // Re-throw to handle in UI
    } finally {
      onLoading(false);
    }
  }

  // Profile-fetching function
  static Future<Map<String, dynamic>> fetchMyProfile({
    bool invalidate = false,
  }) async {
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    try {
      final url = Uri.parse(
          '$baseurl/myprofile${invalidate ? "?invalidate=true" : ""}');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('user')) {
          // Response schema 1
          final userProfile = responseData['user'];
          print(userProfile);

          // Check for account deletion flags
          if (userProfile['deleted'] == true ||
              userProfile['deleteRequestedAt'] != null) {
            return {
              'success': false,
              'error': 'ACCOUNT_PENDING_DELETION',
              'isDeletionPending': true,
            };
          }

          AppVariables.update('profile', userProfile);

          AppVariables.update(
              'watchlist', userProfile['watchList'] as List<dynamic>);

          // Check for `myGroup` and parse if present
          if (userProfile.containsKey('myGroup') &&
              userProfile['myGroup'] != null) {
            final groupData = userProfile['myGroup'];
            final friendCircleGroup =
                GroupsService.buildFriendCircleGroup(groupData);
            AppVariables.set('myGroupId', friendCircleGroup.groupId);

            return {
              'success': true,
              'data': userProfile,
              'group': friendCircleGroup,
            };
          }

          return {'success': true, 'data': userProfile, 'group': null};
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Failed to fetch profile'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchUserPublicProfile(
      {required String dbIndex, required String uid}) async {
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    try {
      final url = Uri.parse('$baseurl/profile/$dbIndex/$uid');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('user')) {
          // Response schema 1
          final userProfile = responseData['user'];

          // Check for `myGroup` and parse if present
          if (userProfile.containsKey('myGroup')) {
            final groupData = userProfile['myGroup'];
            final friendCircleGroup =
                GroupsService.buildFriendCircleGroup(groupData);

            return {
              'success': true,
              'data': userProfile,
              'group': friendCircleGroup,
            };
          }

          return {'success': true, 'data': userProfile, 'group': null};
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Failed to fetch profile'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchUserLikes(
      {required List<String> ids, bool invalidate = false}) async {
    // String? token =
    //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";
    String? token = await UserService.getAccessToken();
    if (token == null) {
      throw Exception('User is not authenticated. Please log in.');
    }
    try {
      final url = Uri.parse('$baseurl/get/user/likes?invalidate=$invalidate');
      print("url : $url");
      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'ids': ids,
          }));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('results')) {
          // Response schema 1
          final userProfile = responseData['results'];

          return {'success': true, 'data': userProfile, 'group': null};
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      } else {
        return {
          'success': false,
          'error':
              jsonDecode(response.body)['message'] ?? 'Failed to fetch profile'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> likeUser({
    required String userId,
  }) async {
    try {
      final url = Uri.parse('$baseurl/user/$userId/like');
      // String? token =
      //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";
      String? token = await UserService.getAccessToken();
      if (token == null) {
        throw Exception('User is not authenticated. Please log in.');
      }
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return {
          'success': true,
          "status": response.statusCode,
          'data': responseData
        };
      } else if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return {
          'success': true,
          "status": response.statusCode,
          'data': responseData
        };
      } else {
        return {
          'success': false,
          "status": response.statusCode,
          'error': jsonDecode(response.body)['message'] ?? 'Failed to like post'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfilePic(
      {String? profilePic}) async {
    try {
      final url = Uri.parse('$baseurl/myprofile/image');
      String? token = await UserService.getAccessToken();

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          "image": profilePic,
        }),
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

  static Future<Map<String, dynamic>> blockUser({
    required String userId,
  }) async {
    try {
      String? token = await UserService.getAccessToken();
      final response = await http.post(
        Uri.parse('$baseurl/user/$userId/block'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );
      return {
        "success": response.statusCode == 200 || response.statusCode == 201
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      String? token = await UserService.getAccessToken();
      final response = await http.delete(
        Uri.parse('$baseurl/user/account'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );
      return {"success": response.statusCode == 200};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> unblockUser({
    required String userId,
  }) async {
    try {
      String? token = await UserService.getAccessToken();
      final response = await http.post(
        Uri.parse('$baseurl/user/$userId/unblock'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );
      return {
        "success": response.statusCode == 200 || response.statusCode == 201
      };
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchBlockedUsers() async {
    try {
      String? token = await UserService.getAccessToken();
      final response = await http.get(
        Uri.parse('$baseurl/user/blocked'),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );
      if (response.statusCode == 200) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "error": "Failed to fetch blocked users",
        };
      }
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}

class AuthProfile {
  final String email;
  final String? name;
  final String? photoUrl;
  final String provider;
  final String? appleId;

  AuthProfile({
    required this.email,
    this.name,
    this.photoUrl,
    required this.provider,
    this.appleId,
  });
}
