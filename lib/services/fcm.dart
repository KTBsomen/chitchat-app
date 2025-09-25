import 'dart:convert';

import 'package:chatview/chatview.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/services/chats.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/notification.dart';
import 'package:chitchat/services/user.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:chitchat/appstate/variables.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:chatview/chatview.dart' as chatview;

class FCMService {
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserId = 'userId';
  static const String _keyFcmToken = 'fcmToken';
  static FirebaseMessaging messaging = FirebaseMessaging.instance;

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> uploadFcmToken(String token) async {
    String? AccessToken = await UserService.getAccessToken();
    if (AccessToken != null) {
      String baseurl = AppVariables.get<String>('baseurl')!.trim() ??
          'http://localhost:3000';
      final url = Uri.parse('$baseurl/set/fcm');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $AccessToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );
    } else {
      print("user token is null. login again");
    }
  }

  static Future<String?> getFcmToken() async {
    String? token = await messaging.getToken();

    return token;
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFcmToken);
  }
}

class FCMHandler {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
    initCallKitListener();

    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
    FirebaseMessaging.onBackgroundMessage(_onBackground);
  }

  static Future<void> _onMessage(RemoteMessage message) async {
    await _processMessage(message, showNotification: true);
  }

  static Future<void> _onTap(RemoteMessage message) async {
    await _processMessage(message, showNotification: false);
  }

  static Future<void> handleNotificationTap(RemoteMessage message) async {
    await _onTap(message);
  }

  static Future<void> _onBackground(RemoteMessage message) async {
    await _processMessage(message, showNotification: false, isBackGround: true);
  }

  static Future<void> _processMessage(RemoteMessage message,
      {bool showNotification = false, bool isBackGround = false}) async {
    final data = message.data;
    final type = data['type'];
    final id = data['id'];
    print("FCM Message: $data");

    if (id != null) {
      await NotificationService.storeUnreadIds([id]);
    }
    if (type == "text" && isBackGround) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => ChatScreen()),
        (route) => route.isFirst,
      );
    }

    if (showNotification) {
      _localNotifications.show(
        0,
        data['title'] ?? 'New Notification',
        data['body'] ?? '',
        const NotificationDetails(
          android: AndroidNotificationDetails('default', 'General'),
        ),
      );
    }
    if (type == "text") {
      await ChatServices.incrementMessageNotificationCount();
    }

    if (type == 'call') {
      var _data = jsonDecode(data['message']);
      chatview.Message joinDetails = chatview.Message.fromJson(data);
      String roomId = joinDetails.message;
      String callerId = joinDetails.sentBy;
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls.isNotEmpty) {
        // Don't show another incoming call
        print("⚠️ Call already active. Skipping duplicate CallKit.");
        final calls = await FlutterCallkitIncoming.activeCalls();
        for (final call in calls) {
          await FlutterCallkitIncoming.endCall(call['id']);
        }
      }
      await _showCallKit(data, isBackground: isBackGround);
    }

    // You can add other types like 'chat', 'story', etc.
  }

  static Future<void> _showCallKit(Map<String, dynamic> data,
      {bool isBackground = false}) async {
    final uuid = DateTime.now().millisecondsSinceEpoch.toString();
    FriendCircleMember? caller;
    FriendCircleGroup? groupDetails;
    Map<String, dynamic>? profileDetails;

    // End any previous lingering calls
    final calls = await FlutterCallkitIncoming.activeCalls();
    for (final call in calls) {
      await FlutterCallkitIncoming.endCall(call['id']);
    }
    var _data = jsonDecode(data['message']);

    chatview.Message joinDetails = chatview.Message.fromJson(_data);
    if (!isBackground) {
      final Map<String, dynamic>? profileDetails =
          AppVariables.get<Map<String, dynamic>>('profile');

      final groupDetails =
          GroupsService.buildFriendCircleGroup(profileDetails?['myGroup']);

      caller = groupDetails?.members.firstWhere(
          (e) => e.id == joinDetails.sentBy,
          orElse: () => FriendCircleMember(
              id: joinDetails.sentBy, avatarUrl: '', additionalData: {}));
    }
    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: uuid,
      nameCaller:
          caller?.additionalData['memberName'] ?? 'Friends From ChitChat',
      appName: 'ChitChat',
      avatar: caller?.avatarUrl ?? '',
      handle: caller?.additionalData['memberName'] ?? '',
      type: 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: {
        'roomId': joinDetails.message,
        'callerId': joinDetails.sentBy,
      },
      headers: {},
    ));
  }

  static void initCallKitListener() {
    FlutterCallkitIncoming.onEvent.listen((event) async {
      print('CallKit Event: ${event!.event.name}');

      switch (event.event) {
        case Event.actionCallAccept:
          // User accepted the call from CallKit UI
          final roomId = event.body['extra']['roomId'];
          final callerId = event.body['extra']['callerId'];
          // You may want to navigate to JitsiMeet screen here directly
          await _joinJitsiMeeting(roomId, callerId);
          break;

        case Event.actionCallDecline:
          // User declined the call
          break;

        // handle other events if needed
        case Event.actionDidUpdateDevicePushTokenVoip:
        // TODO: Handle this case.
        case Event.actionCallIncoming:
        // TODO: Handle this case.
        case Event.actionCallStart:
        // TODO: Handle this case.
        case Event.actionCallEnded:
        // TODO: Handle this case.
        case Event.actionCallTimeout:
        // TODO: Handle this case.
        case Event.actionCallCallback:
        // TODO: Handle this case.
        case Event.actionCallToggleHold:
        // TODO: Handle this case.
        case Event.actionCallToggleMute:
        // TODO: Handle this case.
        case Event.actionCallToggleDmtf:
        // TODO: Handle this case.
        case Event.actionCallToggleGroup:
        // TODO: Handle this case.
        case Event.actionCallToggleAudioSession:
        // TODO: Handle this case.
        case Event.actionCallCustom:
        // TODO: Handle this case.
        case Event.actionCallConnected:
          // TODO: Handle this case.
          throw UnimplementedError();
      }
    });
  }

  static Future<void> _joinJitsiMeeting(String roomId, String callerId) async {
    final Map<String, dynamic>? profileDetails =
        AppVariables.get<Map<String, dynamic>>('profile');
    // Get user info from your app state
    final userName = profileDetails?["name"] ?? "Unknown";
    final userEmail = profileDetails?["email"] ?? "";
    final userAvatar = profileDetails?["profilePic"] ?? "";

    final options = JitsiMeetConferenceOptions(
        room: roomId,
        serverURL: 'https://meet.ffmuc.net/',
        userInfo: JitsiMeetUserInfo(
          displayName: userName,
          email: userEmail,
          avatar: userAvatar,
        ),
        featureFlags: {
          "prejoinpage.enabled": false,
        },
        configOverrides: {
          "prejoinPageEnabled": false,
          "startWithAudioMuted": false,
          "startWithVideoMuted": false,
          'disableInviteFunctions': true, // Hides invite UI
          'toolbarButtons': [
            'camera',
            'microphone',
            'hangup',
            'select-background',
            // add any other buttons you want
          ],
        });

    try {
      await JitsiMeet().join(options);
    } catch (e) {
      print("Join error: $e");
    }
  }
}
