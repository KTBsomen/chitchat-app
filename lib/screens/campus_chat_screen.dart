import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chatview/chatview.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/services/mqtt.dart';
import 'package:chitchat/screens/campus_members_screen.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';

class CampusChatScreen extends StatefulWidget {
  const CampusChatScreen({Key? key}) : super(key: key);

  @override
  State<CampusChatScreen> createState() => _CampusChatScreenState();
}

class _CampusChatScreenState extends State<CampusChatScreen> {
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');

  late final MQTTService mqtt;
  bool _mqttInitialized = false;
  bool isConnected = false;
  late ChatController _chatController;
  bool _isControllerInitialized = false;
  Timer? timer;
  List<Message> messageQueue = [];

  String get _educationLevel {
    return profileDetails?["educationLevel"] ?? "University";
  }

  String? _getInstitutionNameFromProfile() {
    if (profileDetails == null) return null;
    final level = profileDetails!['educationLevel'] as String?;
    switch (level) {
      case 'School':
        return profileDetails!['school'] as String?;
      case 'College':
        return profileDetails!['college'] as String?;
      case 'University':
        return profileDetails!['university'] as String?;
      default:
        return profileDetails!['university'] as String?;
    }
  }

  String _normalizeTopicName(String name) {
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  String get _campusTopic {
    final name = _getInstitutionNameFromProfile();
    final level = _educationLevel.toLowerCase();
    if (name == null || name.isEmpty) return "campus/general/chat";
    return "campus/$level/${_normalizeTopicName(name)}/chat";
  }

  @override
  void initState() {
    super.initState();
    _chatController = ChatController(
      initialMessageList: [],
      scrollController: ScrollController(),
      onReaction: (reaction) {},
      onReactionRemoved: (reaction) {},
      currentUser: ChatUser(
        id: profileDetails?["_id"] ?? "unknown",
        name: profileDetails?["name"] ?? "Unknown",
        profilePhoto: profileDetails?["profilePic"],
      ),
      otherUsers: [],
    );
    setState(() {
      _isControllerInitialized = true;
    });

    _getToken();
  }

  void _getToken() async {
    if (_mqttInitialized) return;
    _mqttInitialized = true;

    final userId = await UserService.getUserId();

    mqtt = MQTTService(
      broker: '13.204.86.50',
      clientId:
          (userId.toString().substring(0, min(20, userId.toString().length))),
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
      onSubscribed: _onSubscribed,
      onUnSubscribed: (topic) => print('📌 Unsubscribed from $topic'),
      onMessageReceived: _handleMessage,
    );

    final topic = _campusTopic;
    mqtt.setTopic = "$topic/+";

    mqtt.connect("$topic/+").then((value) {
      print('Connected to MQTT broker for Campus Chat: $topic');
    }).catchError((error) {
      print('Error connecting to MQTT broker: $error');
    });
    runMqttCheck();
  }

  void runMqttCheck() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (!mqtt.isConnected) {
        print('🔁 Auto reconnecting to Campus Chat...');
        mqtt.connect("${_campusTopic}/+");
      } else {
        if (messageQueue.isNotEmpty) {
          print("Publishing queued campus messages: ${messageQueue.length}");
          final List<Message> sentMessages = [];
          for (var element in messageQueue) {
            try {
              final payload = element.toJson();
              payload['senderName'] = _chatController.currentUser.name;
              payload['senderPic'] = _chatController.currentUser.profilePhoto;
              mqtt.publish(jsonEncode(payload));
              element.setStatus = MessageStatus.delivered;
              sentMessages.add(element);
            } catch (e) {
              print("Failed to publish queued message: $e");
            }
          }
          messageQueue.removeWhere((msg) => sentMessages.contains(msg));
          setState(() {});
        }
      }
    });
  }

  void _onConnected() {
    if (mounted) {
      setState(() {
        isConnected = true;
      });
    }
  }

  void _onDisconnected() {
    if (mounted && isConnected) {
      setState(() {
        isConnected = false;
      });
    }
  }

  void _onSubscribed(String topic) {
    print('📌 Subscribed to campus chat: $topic');
  }

  void _handleMessage(String message) {
    try {
      var data = jsonDecode(message);

      // Ignore typing / read receipts / unsends for simplicity in global chat
      if (data['type'] == 'typing' ||
          data['type'] == 'read' ||
          data['type'] == 'unsend' ||
          data['type'] == 'edit') {
        return;
      }

      Message msg = Message.fromJson(data);

      // Avoid duplicating our own messages if we receive them back
      if (msg.sentBy == _chatController.currentUser.id) return;

      // Check if user exists in otherUsers, if not add them temporarily
      bool userExists =
          _chatController.otherUsers.any((u) => u.id == msg.sentBy);
      if (!userExists) {
        // We'll use a placeholder since we don't have their profile info directly,
        // unless you pass it in the message payload.
        _chatController.otherUsers.add(ChatUser(
          id: msg.sentBy,
          name: data['senderName'] ?? "Student",
          profilePhoto: data['senderPic'],
        ));
      }

      if (mounted) {
        _chatController.addMessage(msg);
      }
    } catch (e) {
      print("Error parsing campus message: $e");
    }
  }

  void onRetryTap(Message message) {
    if (isConnected) {
      final payload = message.toJson();
      payload['senderName'] = _chatController.currentUser.name;
      payload['senderPic'] = _chatController.currentUser.profilePhoto;
      try {
        mqtt.publish(jsonEncode(payload));
        message.setStatus = MessageStatus.delivered;
        setState(() {});
      } catch (e) {
        print("Retry failed: $e");
      }
    } else {
      print('Cannot retry: MQTT not connected');
    }
  }

  void _onSendTap(List<String> messages, ReplyMessage replyMessage,
      MessageType messageType, bool isOneTime) {
    if (messages.isEmpty) return;
    for (final message in messages) {
      final msg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: message,
        createdAt: DateTime.now(),
        sentBy: _chatController.currentUser.id,
        replyMessage: replyMessage,
        messageType: messageType,
        uploadProgress: ValueNotifier(1.0),
        onRetry: onRetryTap,
      );

      _chatController.addMessage(msg);

      // Add sender info so others can display it without DB lookup
      final payload = msg.toJson();
      payload['senderName'] = _chatController.currentUser.name;
      payload['senderPic'] = _chatController.currentUser.profilePhoto;

      if (isConnected) {
        try {
          mqtt.publish(jsonEncode(payload));
          msg.setStatus = MessageStatus.delivered;
        } catch (e) {
          print('Failed to publish message: $e');
          msg.setStatus = MessageStatus.undelivered;
          messageQueue.add(msg);
        }
      } else {
        msg.setStatus = MessageStatus.undelivered;
        messageQueue.add(msg);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    timer = null;
    if (_mqttInitialized) {
      try {
        mqtt.disconnect();
      } catch (e) {
        print("Error disconnecting: $e");
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isControllerInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body:
            Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }

    final instName = _getInstitutionNameFromProfile() ?? "Your Campus";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CampusMembersScreen(
                  institutionName: instName,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected ? Colors.tealAccent : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isConnected ? 'Connected to Global Chat' : 'Connecting...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: ChatView(
        chatController: _chatController,
        onSendTap: _onSendTap,
        chatViewState:
            ChatViewState.hasMessages, // Start with empty state or has messages
        appBar: const SizedBox.shrink(), // We use Scaffold's AppBar
        chatBackgroundConfig: ChatBackgroundConfiguration(
          backgroundColor: AppColors.background,
        ),
        sendMessageConfig: SendMessageConfiguration(
          textFieldBackgroundColor: const Color(0xFF1E1E2C),
          defaultSendButtonColor: Colors.tealAccent,
          textFieldConfig: const TextFieldConfiguration(
            textStyle: TextStyle(color: Colors.white),
          ),
          replyDialogColor: const Color(0xFF1E1E2C),
          replyTitleColor: Colors.tealAccent,
          replyMessageColor: Colors.white,
          closeIconColor: Colors.white,
        ),
        chatBubbleConfig: ChatBubbleConfiguration(
          outgoingChatBubbleConfig: ChatBubble(
            color: Colors.teal.shade700,
            textStyle: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          inComingChatBubbleConfig: ChatBubble(
            color: const Color(0xFF2A2A3D),
            textStyle: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        messageConfig: const MessageConfiguration(
          messageReactionConfig: MessageReactionConfiguration(
            backgroundColor: Color(0xFF2A2A3D),
            borderColor: Colors.tealAccent,
            reactedUserCountTextStyle: TextStyle(color: Colors.white),
            reactionCountTextStyle: TextStyle(color: Colors.white),
            reactionsBottomSheetConfig: ReactionsBottomSheetConfiguration(
              backgroundColor: Color(0xFF1E1E2C),
              reactedUserTextStyle: TextStyle(color: Colors.white),
              reactionWidgetDecoration: BoxDecoration(
                color: Color(0xFF2A2A3D),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        profileCircleConfig: ProfileCircleConfiguration(
          profileImageUrl: ValueNotifier(
              'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png'),
        ),
        repliedMessageConfig: const RepliedMessageConfiguration(
          backgroundColor: Color(0xFF1E1E2C),
          verticalBarColor: Colors.tealAccent,
          repliedMsgAutoScrollConfig: RepliedMsgAutoScrollConfig(),
        ),
        swipeToReplyConfig: const SwipeToReplyConfiguration(
          replyIconColor: Colors.tealAccent,
        ),
        replyPopupConfig: const ReplyPopupConfiguration(
          backgroundColor: Color(0xFF1E1E2C),
          buttonTextStyle: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
