import 'dart:convert';

// chatview imported as alias below; avoid duplicate unaliased import
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/services/chats.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/appstate/notification_store.dart';
import 'package:chitchat/services/notification_manager.dart';
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
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
// no extra dart:math required

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

Map<String, dynamic> _tryParseNotificationBody(String body) {
  try {
    final parsed = jsonDecode(body);
    if (parsed is Map<String, dynamic>) return parsed;
    return {'body': body};
  } catch (e) {
    // Not JSON — return as simple body field
    return {'body': body};
  }
}

// Top-level background handler required by firebase_messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FCMHandler._processMessage(message,
      showNotification: false, isBackgroundMessage: true, wasTapped: false);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  try {
    final payload = notificationResponse.payload;
    final input = notificationResponse.input;
    if (payload != null &&
        payload.isNotEmpty &&
        input is String &&
        input.trim().isNotEmpty) {
      final Map<String, dynamic> data = jsonDecode(payload);
      // Save the reply to SharedPreferences for the app to process when it starts
      SharedPreferences.getInstance().then((prefs) async {
        final key = 'pending_notification_replies';
        final existing = prefs.getStringList(key) ?? [];
        final entry = jsonEncode({
          'payload': data,
          'reply': input,
          'ts': DateTime.now().toIso8601String()
        });
        existing.add(entry);
        await prefs.setStringList(key, existing);
      });

      // Fire-and-forget headless MQTT publish; fallback to pending-storage exists
      publishReplyViaMqtt(data, input).catchError((e) {
        print('Headless publish attempt failed: $e');
      });
    }
  } catch (e) {
    print('Background notification response error: $e');
  }
}

/// Try to publish a reply via MQTT from background context. This is best-effort
/// — if it fails, the reply is already saved in SharedPreferences by the
/// background handler.
Future<void> publishReplyViaMqtt(
    Map<String, dynamic> payload, String reply) async {
  try {
    final userId = await UserService.getUserId();
    if (userId == null) return;

    // Determine topic (group/room)
    final groupId = payload['groupId'] ??
        payload['roomId'] ??
        payload['group'] ??
        payload['topic'];
    if (groupId == null) {
      print(
          'No groupId/roomId found in payload; cannot publish reply via MQTT');
      return;
    }

    // Broker fallback (same as used in ChatScreen)
    final broker = payload['mqttBroker'] ?? '192.168.139.222';

    // Get chat token for MQTT auth
    final token = await ChatServices.getChatToken();
    if (token.isEmpty) {
      print('No chat token available; cannot publish via MQTT');
      return;
    }

    final clientIdRaw = (userId.toString());
    final clientId =
        clientIdRaw.length > 20 ? clientIdRaw.substring(0, 20) : clientIdRaw;

    final client = MqttServerClient.withPort(broker, clientId, 1883);
    client.logging(on: false);
    client.keepAlivePeriod = 30;

    final connMess = mqtt.MqttConnectMessage()
        .authenticateAs('user', token)
        .withClientIdentifier(clientId)
        .withWillTopic('clients/$clientId/disconnect')
        .withWillMessage('Client $clientId disconnected unexpectedly')
        .withWillQos(mqtt.MqttQos.atLeastOnce);

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print('MQTT connect error: $e');
      client.disconnect();
      return;
    }

    if (client.connectionStatus?.state != mqtt.MqttConnectionState.connected) {
      print('MQTT failed to connect: ${client.connectionStatus?.state}');
      client.disconnect();
      return;
    }

    // Construct minimal message to match other clients
    final message = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'createdAt': DateTime.now().toIso8601String(),
      'message': reply,
      'sentBy': userId,
      'messageType': 'text'
    };

    final pubTopic = '$groupId/$clientId';
    final builder = mqtt.MqttClientPayloadBuilder();
    builder.addUTF8String(jsonEncode(message));
    client.publishMessage(pubTopic, mqtt.MqttQos.atLeastOnce, builder.payload!);
    await Future.delayed(const Duration(milliseconds: 300));
    client.disconnect();
    print('Headless MQTT publish successful to $pubTopic');
  } catch (e) {
    print('Error in headless MQTT publish: $e');
  }
}

class FCMHandler {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Stores notification data when the app is opened from a terminated/background
  /// state so that navigation can happen after the app is fully initialized.
  static Map<String, dynamic>? _pendingNotificationData;

  /// Call this after the app is fully initialized (profile loaded, navigator ready)
  /// to navigate to ChatScreen if the app was opened via a notification.
  static void consumePendingNotification() {
    if (_pendingNotificationData != null) {
      final data = _pendingNotificationData!;
      _pendingNotificationData = null;
      try {
        navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => ChatScreen(data: data)));
      } catch (e) {
        print('Pending notification navigation failed: $e');
      }
    }
  }

  static Future<void> initialize() async {
    // Request FCM / platform notification permissions
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('FCM permission status: ${settings.authorizationStatus}');

    // Ask iOS/macOS local notification permissions
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Try to request Android (Android 13+) notification permission if supported
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // ignore if not supported by plugin/platform
    }

    // Ensure foreground presentation for iOS
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
            alert: true, badge: true, sound: true);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings,iOS:  DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ));
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        try {
          final payload = notificationResponse.payload;
          if (payload != null && payload.isNotEmpty) {
            final Map<String, dynamic> data = jsonDecode(payload);
            // If this response contains an inline reply input (Android), payload will
            // be delivered in `notificationResponse.input` (older versions use `responseInput`)
            final input = notificationResponse.input;
            if (input is String && input.trim().isNotEmpty) {
              // User used inline reply — open chat with prefilled message so ChatScreen
              // will send it on init.
              navigatorKey.currentState?.push(MaterialPageRoute(
                  builder: (context) => ChatScreen(data: {'message': input})));
              return;
            }

            // Standard notification tap — open chat with payload so ChatScreen can act
            navigatorKey.currentState?.push(MaterialPageRoute(
                builder: (context) => ChatScreen(data: data)));
          }
        } catch (e) {
          print('Notification tap handler error: $e');
        }
      },
      // Background notification response (Android: inline reply when app is terminated)
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    initCallKitListener();

    FirebaseMessaging.onMessage.listen(_onMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      // Save for deferred navigation — navigator/profile may not be ready
      final Map<String, dynamic> data = (message.data.isNotEmpty)
          ? Map<String, dynamic>.from(message.data)
          : (message.notification?.body != null
              ? _tryParseNotificationBody(message.notification!.body!)
              : <String, dynamic>{});
      if (data['type'] == 'text') {
        _pendingNotificationData = data;
        consumePendingNotification();
      } else {
        await _onTap(message);
      }
    });
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) async {
      if (message != null) {
        // App opened from terminated state — save data for deferred navigation
        final Map<String, dynamic> data = (message.data.isNotEmpty)
            ? Map<String, dynamic>.from(message.data)
            : (message.notification?.body != null
                ? _tryParseNotificationBody(message.notification!.body!)
                : <String, dynamic>{});
        if (data['type'] == 'text') {
          _pendingNotificationData = data;
          // Don't navigate now — main.dart will call consumePendingNotification()
          // after profile is loaded and navigator is ready.
        } else {
          await _onTap(message);
        }
      }
    });
    // onBackgroundMessage requires a top-level function; register it below.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static Future<void> _onMessage(RemoteMessage message) async {
    await _processMessage(message,
        showNotification: true, isBackgroundMessage: false, wasTapped: false);
  }

  static Future<void> _onTap(RemoteMessage message) async {
    await _processMessage(message,
        showNotification: false, isBackgroundMessage: false, wasTapped: true);
  }

  static Future<void> handleNotificationTap(RemoteMessage message) async {
    await _onTap(message);
  }

  static Future<void> _processMessage(RemoteMessage message,
      {bool showNotification = false,
      bool isBackgroundMessage = false,
      bool wasTapped = false}) async {
    // Prefer data payload but fall back to notification body if server sent
    // an Android "notification" payload (system may deliver only notification
    // when app is backgrounded). Log both for debugging.
    print('RemoteMessage.notification: ${message.notification}');
    final Map<String, dynamic> data = (message.data.isNotEmpty)
        ? Map<String, dynamic>.from(message.data)
        : (message.notification?.body != null
            ? _tryParseNotificationBody(message.notification!.body!)
            : <String, dynamic>{});
    final type = data['type'];
    final id = data['id'];
    print("FCM Message: $data");

    // Helper: log the raw message for easier debugging
    print(
        'RemoteMessage.raw: ${message.data} | notification=${message.notification}');

    if (id != null) {
      await NotificationStore.addNotifications([
        {
          'id': id,
          'title': data['title'],
          'body': data['body'] ?? data['message'],
          'type': type,
          'sourceType': 'redis',
          'data': data,
        }
      ]);
      NotificationManager.instance.refreshCount();
    }

    // If this message was delivered because the user tapped the notification
    // (app opened via notification), `wasTapped` will be true — navigate to chat
    // screen with the payload so that ChatScreen can send/open appropriately.
    if (wasTapped && type == 'text') {
      try {
        navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (context) => ChatScreen(data: data)));
      } catch (e) {
        print('Navigation on notification tap failed: $e');
      }
    }

    if (showNotification) {
      try {
        // // Keep notifications grouped per chat/group. We include the data payload
        // // as the notification payload so taps and inline replies can be handled.
        // final groupKey =
        //     data['roomId'] ?? data['groupId'] ?? id ?? 'chitchat_group';
        // final androidDetails = AndroidNotificationDetails(
        //   'default',
        //   'General',
        //   groupKey: groupKey.toString(),
        //   // set only basic details to avoid complex API mismatches
        // );

        // await _localNotifications.show(
        //   groupKey.hashCode & 0x7FFFFFFF,
        //   data['title'] ?? 'New Message',
        //   jsonDecode(data['message'])["message"] ?? "click to see it.",
        //   NotificationDetails(android: androidDetails),
        //   payload: jsonEncode(data),
        // );
        //Dont show local notification
      } catch (e) {
        print('Failed to show local notification: $e');
      }
    }
    if (type == "text") {
      await ChatServices.incrementMessageNotificationCount();
    }

    if (type == 'call') {
      try {
        var _data = jsonDecode(data['message']);
        chatview.Message joinDetails = chatview.Message.fromJson(_data);
        String roomId = joinDetails.message;
        // Use a stable uuid based on roomId to avoid duplicate incoming call instances
        data['__call_uuid'] = roomId;
        final calls = await FlutterCallkitIncoming.activeCalls();
        // If a call with this id already exists, skip showing another
        final exists = calls.any((c) => c['id'] == roomId);
        if (exists) {
          print('Incoming call already shown for $roomId - skipping duplicate');
        } else {
          await _showCallKit(data, isBackground: isBackgroundMessage);
        }
      } catch (e) {
        print('Call processing error: $e');
      }
    }

    // You can add other types like 'chat', 'story', etc.
  }

  static Future<void> _showCallKit(Map<String, dynamic> data,
      {bool isBackground = false}) async {
    final uuid = data['__call_uuid']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    FriendCircleMember? caller;

    var _data = jsonDecode(data['message']);

    chatview.Message joinDetails = chatview.Message.fromJson(_data);
    if (!isBackground) {
      final Map<String, dynamic>? profileDetails =
          AppVariables.get<Map<String, dynamic>>('profile');

      final groupDetails =
          GroupsService.buildFriendCircleGroup(profileDetails?['myGroup']);

      caller = groupDetails.members.firstWhere(
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
          // User declined the call — ensure CallKit call is ended
          try {
            final callId = event.body['id'] ??
                event.body['uuid'] ??
                event.body['extra']?['roomId'];
            if (callId != null) {
              await FlutterCallkitIncoming.endCall(callId);
            }
          } catch (e) {
            print('Error ending declined call: $e');
          }
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
          // Call connected — nothing special to do here in this handler
          break;
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
