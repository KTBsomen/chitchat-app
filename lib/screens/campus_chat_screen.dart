import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chatview/chatview.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/constants/theams.dart';
import 'package:chitchat/services/mqtt.dart';
import 'package:chitchat/screens/campus_members_screen.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:http/http.dart' as http;

class CampusChatScreen extends StatefulWidget {
  const CampusChatScreen({Key? key}) : super(key: key);

  @override
  State<CampusChatScreen> createState() => _CampusChatScreenState();
}

class _CampusChatScreenState extends State<CampusChatScreen> {
  final AppTheme theme = DarkTheme();
  final bool isDarkTheme = true;

  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');

  static String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';

  late final MQTTService mqtt;
  bool _mqttInitialized = false;
  bool isConnected = false;
  late ChatController _chatController;
  bool _isControllerInitialized = false;
  Timer? timer;
  List<Message> messageQueue = [];

  // --- Pagination state ---
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingHistory = false;
  bool _initialLoadDone = false;

  late final UploadService uploadService;
  final Set<String> _memorySentUrls = {};
  final ValueNotifier<String> typingUserIdProfilePic = ValueNotifier('');

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

  // ---------- API: Fetch chat history with cursor-based pagination ----------

  /// Fetches a page of chat history from the server.
  /// Returns the list of [Message] objects in chronological order (oldest first).
  Future<List<Message>> _fetchChatHistory(
      {String? cursor, int limit = 20}) async {
    try {
      String? token = await UserService.getAccessToken();
      if (token == null) return [];

      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (cursor != null) {
        queryParams['cursor'] = cursor;
      }

      final uri = Uri.parse('$baseurl/campus/chat/history')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        _nextCursor = data['nextCursor'];
        _hasMore = data['hasMore'] ?? false;

        return results.map((item) {
          final payload = item['payload'];
          // payload is the original chat message JSON stored by the broker
          if (payload is Map<String, dynamic>) {
            // Ensure we have the sender info for otherUsers registration
            _registerOtherUser(payload);
            var _t = Message.fromJson(payload);
            _t.setStatus = MessageStatus.delivered;
            return _t;
          }
          // Fallback: if payload is a string, try parsing
          if (payload is String) {
            try {
              final parsed = jsonDecode(payload) as Map<String, dynamic>;
              _registerOtherUser(parsed);
              var _t = Message.fromJson(parsed);
              _t.setStatus = MessageStatus.delivered;
              return _t;
            } catch (_) {}
          }
          // Last resort: create a placeholder
          return Message(
            id: item['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
            message: payload?.toString() ?? '',
            createdAt:
                DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
            sentBy: 'unknown',
            uploadProgress: ValueNotifier(1.0),
            messageType: MessageType.text,
            status: MessageStatus.delivered,
          );
        }).toList();
      } else {
        print('Failed to fetch chat history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching chat history: $e');
      return [];
    }
  }

  /// Registers a sender as an otherUser in the ChatController if not already known.
  void _registerOtherUser(Map<String, dynamic> data) {
    final senderId = data['sentBy'] as String?;
    if (senderId == null || senderId == _chatController.currentUser.id) return;

    final alreadyKnown =
        _chatController.otherUsers.any((u) => u.id == senderId);
    if (!alreadyKnown) {
      _chatController.otherUsers.add(ChatUser(
        id: senderId,
        name: data['senderName'] ?? 'Student',
        profilePhoto: data['senderPic'],
      ));
    }
  }

  // ---------- Lifecycle ----------

  @override
  void initState() {
    super.initState();
    _initializeUploadService();

    _chatController = ChatController(
      initialMessageList: [],
      scrollController: ScrollController(),
      onReaction: (reaction) {
        debugPrint('Message Reacted${reaction.toString()}');
        _setReaction(reaction, false);
      },
      onReactionRemoved: (reaction) {
        debugPrint('Message Reacted Removed ${reaction.toString()}');
        _setReaction(reaction, false);
      },
      currentUser: ChatUser(
        id: profileDetails?["_id"] ?? "unknown",
        name: profileDetails?["name"] ?? "Unknown",
        profilePhoto: profileDetails?["profilePic"],
      ),
      otherUsers: [],
    );

    // Load initial history from DB, then connect MQTT for realtime
    _loadInitialHistory();
  }

  void _initializeUploadService() async {
    uploadService = UploadService(
        baseUrl: "https://chitzchat.com/api/storage/api/v1/upload-url",
        apiKey: (await UserService.getAccessToken()) ?? '');
  }

  Future<void> _loadInitialHistory() async {
    final messages = await _fetchChatHistory(limit: 20);

    if (mounted) {
      if (messages.isNotEmpty) {
        _chatController.initialMessageList.addAll(messages);
        _chatController.messageStreamController
            .add(_chatController.initialMessageList);
      }
      setState(() {
        _isControllerInitialized = true;
        _initialLoadDone = true;
      });
    }

    // Now connect MQTT for live messages
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

  Message? _findMessage(Message message) {
    try {
      return _chatController.initialMessageList
          .firstWhere((m) => m.id == message.id);
    } catch (_) {
      return null;
    }
  }

  void _setReaction(Message reactions, bool isFromMQTT) async {
    try {
      Message? mtu = _findMessage(reactions);
      if (mtu != null) {
        setState(() {
          mtu.reaction = reactions.reaction;
        });
      }
      if (!isFromMQTT) {
        mqtt.publish(
          jsonEncode({
            'type': 'reaction',
            'message': reactions.toJson(),
          }),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  void _openMore(Message message, bool isFromCurrentUser) {
    if (message.messageType != MessageType.text) {
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFromCurrentUser &&
                    message.messageType == MessageType.text)
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blue),
                    title: const Text("Edit"),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditMessagePopup(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditMessagePopup(Message message) {
    final TextEditingController controller =
        TextEditingController(text: message.message);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newMessage = message.copyWith(message: controller.text);
              Navigator.of(context).pop();
              _editMessage(newMessage);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editMessage(Message message, {bool isFromMQTT = false}) {
    print('editing message: ${message.message}');
    if (message.createdAt
        .isBefore(DateTime.now().subtract(const Duration(days: 2)))) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Editing Not Allowed'),
          content: const Text(
              'You can only Edit messages sent within the last 2 days.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    } else {
      final mtu = _findMessage(message);
      if (mtu != null) {
        mtu.message = message.message;
      }
      _chatController.removeReplySuggestions();

      if (!isFromMQTT) {
        mqtt.publish(
          jsonEncode({
            'type': 'edit',
            'message': message.toJson(),
          }),
        );
      }
    }
    setState(() {});
  }

  void unsendMessage(Message message, {bool isFromMQTT = false}) {
    print('Unsend message: ${message.message}');
    if (message.createdAt
        .isBefore(DateTime.now().subtract(const Duration(days: 2)))) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsend Not Allowed'),
          content: const Text(
              'You can only unsend messages sent within the last 2 days.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final mtu = _findMessage(message);
                if (mtu != null) {
                  _chatController.initialMessageList.remove(mtu);
                }
                _chatController.removeReplySuggestions();
                Navigator.of(context).pop();
              },
              child: const Text('Delete for me'),
            ),
          ],
        ),
      );
    } else {
      final mtu = _findMessage(message);
      if (mtu != null) {
        _chatController.initialMessageList.remove(mtu);
      }
      _chatController.removeReplySuggestions();

      if (!isFromMQTT && !message.isOneTime) {
        mqtt.publish(
          jsonEncode({
            'type': 'unsend',
            'message': message.toJson(),
          }),
        );
      }
    }
    setState(() {});
  }

  void _markAsRead(Message message, {bool isFromMQTT = false}) {
    final Message? messageToUpdate = _findMessage(message);
    if (messageToUpdate != null) {
      messageToUpdate.setStatus = MessageStatus.read;
    }
    if (!isFromMQTT) {
      mqtt.publish(
        jsonEncode({
          'type': 'read',
          'status': "read",
          'sentBy': _chatController.currentUser.id,
          'groupId': _campusTopic,
          'message': message.toJson(),
        }),
      );
    }
  }

  void _handleMessage(String message, {String? topic}) {
    if (topic != null && !topic.startsWith(_campusTopic)) {
      print(
          "Ignoring personal/other group message from topic: $topic (current campus topic: $_campusTopic)");
      return;
    }
    try {
      if (message.contains('"type":"typing"')) {
        var data = jsonDecode(message);
        if (data['status'] == "TypeWriterStatus.typing") {
          String typingUserId = data['sentBy'];
          final matchingUsers = _chatController.otherUsers
              .where((user) => user.id == typingUserId);
          typingUserIdProfilePic.value = matchingUsers.isNotEmpty
              ? matchingUsers.first.profilePhoto ?? ''
              : '';
          _chatController.setTypingIndicator = true;
          setState(() {});
        } else {
          typingUserIdProfilePic.value = '';
          _chatController.setTypingIndicator = false;
          setState(() {});
        }
        return;
      }
      if (message.contains('"type":"unsend"')) {
        var data = jsonDecode(message);
        Message messageToUnsend = Message.fromJson(data['message']);
        if (messageToUnsend.createdAt
            .isBefore(DateTime.now().subtract(const Duration(days: 2)))) {
          print("message is older than 2 days so not unsending");
          return;
        }
        unsendMessage(messageToUnsend, isFromMQTT: true);
        return;
      }
      if (message.contains('"type":"read"')) {
        var data = jsonDecode(message);
        Message seenMessage = Message.fromJson(data['message']);
        _markAsRead(seenMessage, isFromMQTT: true);
        return;
      }
      if (message.contains('"type":"reaction"')) {
        var data = jsonDecode(message);
        Message seenMessage = Message.fromJson(data['message']);
        _setReaction(seenMessage, true);
        return;
      }
      if (message.contains('"type":"edit"')) {
        var data = jsonDecode(message);
        Message messageToEdit = Message.fromJson(data['message']);
        if (messageToEdit.createdAt
            .isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
          print("message is older than 1 days so not editing.");
          return;
        }
        _editMessage(messageToEdit, isFromMQTT: true);
        return;
      }

      var data = jsonDecode(message);
      Message msg = Message.fromJson(data);
      msg.setStatus = MessageStatus.delivered;
      if (msg.sentBy == _chatController.currentUser.id) return;

      _registerOtherUser(data);
      if (mounted) {
        _chatController.addMessage(msg);
      }
    } catch (e) {
      print("Error parsing campus message: $e");
    }
  }

  // ---------- Load older messages (scroll up pagination) ----------

  Future<void> _loadOlderMessages() async {
    if (_isLoadingHistory || !_hasMore) return;
    _isLoadingHistory = true;

    try {
      final olderMessages =
          await _fetchChatHistory(cursor: _nextCursor, limit: 20);

      if (olderMessages.isNotEmpty && mounted) {
        // Insert at the beginning of the list (these are older)
        _chatController.initialMessageList.insertAll(0, olderMessages);
        _chatController.messageStreamController
            .add(_chatController.initialMessageList);
        setState(() {});
      }
    } catch (e) {
      print('Error loading older messages: $e');
    } finally {
      _isLoadingHistory = false;
    }
  }

  // ---------- Send ----------

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

  Future<void> _onSendTap(List<String> filePaths, ReplyMessage replyMessage,
      MessageType messageType, bool isOneTime,
      {String? id}) async {
    if (filePaths.isEmpty) return;

    for (final path in filePaths) {
      final file = File(path);

      final message = Message(
          id: id ?? '${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
          message: path,
          reaction: Reaction(reactions: [], reactedUserIds: []),
          sentBy: _chatController.currentUser.id,
          replyMessage: replyMessage,
          messageType: messageType,
          uploadProgress: ValueNotifier(0.0),
          onRetry: onRetryTap,
          isOneTime: isOneTime);

      _chatController.addMessage(message);
      if (messageType == MessageType.video ||
          messageType == MessageType.image ||
          messageType == MessageType.voice) {
        // Start upload and track progress
        message.setStatus = MessageStatus.uploading;
        await uploadService
            .uploadFile(
          file: file,
          path: 'uploads/chat',
          progressNotifier: message.uploadProgress,
        )
            .then((uploadResponse) {
          // Update message URL with final public URL after upload completes
          message.message = uploadResponse.publicUrl;
          setState(() {});

          final payload = message.toJson();
          payload['senderName'] = _chatController.currentUser.name;
          payload['senderPic'] = _chatController.currentUser.profilePhoto;

          if (isConnected) {
            try {
              mqtt.publish(jsonEncode(payload));
              message.setStatus = MessageStatus.delivered;
            } catch (e) {
              print('Failed to publish message: $e');
              message.setStatus = MessageStatus.undelivered;
              messageQueue.add(message);
            }
          } else {
            message.setStatus = MessageStatus.undelivered;
            messageQueue.add(message);
          }
        }).catchError((error) {
          print('Upload failed: $error');
          message.setStatus = MessageStatus.error;
        });
      } else {
        final payload = message.toJson();
        payload['senderName'] = _chatController.currentUser.name;
        payload['senderPic'] = _chatController.currentUser.profilePhoto;

        if (isConnected) {
          try {
            mqtt.publish(jsonEncode(payload));
            message.setStatus = MessageStatus.delivered;
          } catch (e) {
            print('Failed to publish message: $e');
            messageQueue.add(message);
            message.setStatus = MessageStatus.undelivered;
          }
        } else {
          message.setStatus = MessageStatus.undelivered;
          messageQueue.add(message);
        }
      }
    }

    _chatController.scrollToLastMessage(doit: true);
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

  // ---------- Build ----------

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
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarColor,
        elevation: theme.elevation ?? 1,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios, color: theme.backArrowColor, size: 20),
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
                style: TextStyle(
                  color: theme.appBarTitleTextStyle,
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
        isLastPage: !_hasMore,
        loadMoreData: _loadOlderMessages,
        loadingWidget: const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(
              color: Colors.tealAccent,
              strokeWidth: 2,
            ),
          ),
        ),
        featureActiveConfig: const FeatureActiveConfig(
          enablePagination: true,
          enableScrollToBottomButton: true,
        ),
        chatController: _chatController,
        onSendTap: _onSendTap,
        chatViewState: ChatViewState.hasMessages,
        appBar: const SizedBox.shrink(),
        chatBackgroundConfig: ChatBackgroundConfiguration(
          messageTimeIconColor: theme.messageTimeIconColor,
          messageTimeTextStyle: TextStyle(color: theme.messageTimeTextColor),
          defaultGroupSeparatorConfig: DefaultGroupSeparatorConfiguration(
            textStyle: TextStyle(
              color: theme.chatHeaderColor,
              fontSize: 17,
            ),
          ),
          backgroundColor: theme.backgroundColor,
        ),
        sendMessageConfig: SendMessageConfiguration(
          imagePickerIconsConfig: ImagePickerIconsConfiguration(
            cameraIconColor: theme.cameraIconColor,
            galleryIconColor: theme.galleryIconColor,
          ),
          replyMessageColor: theme.replyMessageColor,
          defaultSendButtonColor: theme.sendButtonColor,
          replyDialogColor: theme.replyDialogColor,
          replyTitleColor: theme.replyTitleColor,
          textFieldBackgroundColor: theme.textFieldBackgroundColor,
          closeIconColor: theme.closeIconColor,
          textFieldConfig: TextFieldConfiguration(
            maxLines: 10,
            textStyle: TextStyle(color: theme.textFieldTextColor),
            compositionThresholdTime: const Duration(seconds: 1),
            onMessageTyping: (status) {
              mqtt.publish(
                jsonEncode({
                  'type': 'typing',
                  'status': status.toString(),
                  'sentBy': _chatController.currentUser.id,
                  'groupId': _campusTopic,
                }),
              );
            },
          ),
          micIconColor: theme.replyMicIconColor,
          voiceRecordingConfiguration: VoiceRecordingConfiguration(
            bitRate: 64000,
            backgroundColor: theme.waveformBackgroundColor,
            recorderIconColor: theme.recordIconColor,
            waveStyle: WaveStyle(
              showMiddleLine: false,
              waveColor: theme.waveColor ?? Colors.white,
              extendWaveform: true,
            ),
          ),
        ),
        chatBubbleConfig: ChatBubbleConfiguration(
          outgoingChatBubbleConfig: ChatBubble(
            linkPreviewConfig: LinkPreviewConfiguration(
              backgroundColor: theme.linkPreviewOutgoingChatColor,
              bodyStyle: theme.outgoingChatLinkBodyStyle,
              titleStyle: theme.outgoingChatLinkTitleStyle,
            ),
            receiptsWidgetConfig: const ReceiptsWidgetConfig(
              showReceiptsIn: ShowReceiptsIn.all,
            ),
            color: theme.outgoingChatBubbleColor,
            textStyle: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          inComingChatBubbleConfig: ChatBubble(
            linkPreviewConfig: LinkPreviewConfiguration(
              linkStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor,
                decoration: TextDecoration.underline,
              ),
              backgroundColor: theme.linkPreviewIncomingChatColor,
              bodyStyle: theme.incomingChatLinkBodyStyle,
              titleStyle: theme.incomingChatLinkTitleStyle,
            ),
            textStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor, fontSize: 16),
            onMessageRead: (message) {
              _markAsRead(message);
            },
            senderNameTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            color: theme.inComingChatBubbleColor,
          ),
        ),
        replyPopupConfig: ReplyPopupConfiguration(
          backgroundColor: theme.replyPopupColor,
          buttonTextStyle: TextStyle(color: theme.replyPopupButtonColor),
          topBorderColor: theme.replyPopupTopBorderColor,
          onUnsendTap: unsendMessage,
          onMoreTap: (message, sentByCurrentUser) {
            _openMore(message, sentByCurrentUser);
          },
        ),
        reactionPopupConfig: ReactionPopupConfiguration(
          shadow: BoxShadow(
            color: isDarkTheme ? Colors.black54 : Colors.grey.shade400,
            blurRadius: 20,
          ),
          backgroundColor: theme.reactionPopupColor,
        ),
        messageConfig: MessageConfiguration(
          messageReactionConfig: MessageReactionConfiguration(
            backgroundColor: theme.messageReactionBackGroundColor,
            borderColor: theme.messageReactionBackGroundColor,
            reactedUserCountTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            reactionCountTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            reactionsBottomSheetConfig: ReactionsBottomSheetConfiguration(
              backgroundColor: theme.backgroundColor,
              reactedUserTextStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor,
              ),
              reactionWidgetDecoration: BoxDecoration(
                color: theme.inComingChatBubbleColor,
                boxShadow: [
                  BoxShadow(
                    color: isDarkTheme ? Colors.black12 : Colors.grey.shade200,
                    offset: const Offset(0, 20),
                    blurRadius: 40,
                  )
                ],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          imageMessageConfig: ImageMessageConfiguration(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            onTap: (Message message) {
              debugPrint(message.message);
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  barrierDismissible: true,
                  pageBuilder: (BuildContext context, _, __) {
                    return ZoomableImagePopup(
                      imageUrl: message.message,
                      onClose: () => Navigator.of(context).pop(),
                    );
                  },
                ),
              );
              if (message.isOneTime) {
                unsendMessage(message);
              }
            },
            shareIconConfig: ShareIconConfiguration(
              defaultIconBackgroundColor: theme.shareIconBackgroundColor,
              defaultIconColor: theme.shareIconColor,
            ),
          ),
        ),
        profileCircleConfig: ProfileCircleConfiguration(
          profileImageUrl: typingUserIdProfilePic,
        ),
        repliedMessageConfig: RepliedMessageConfiguration(
          backgroundColor: theme.repliedMessageColor,
          verticalBarColor: theme.verticalBarColor,
          repliedMsgAutoScrollConfig: const RepliedMsgAutoScrollConfig(
            enableHighlightRepliedMsg: true,
            highlightColor: Colors.pinkAccent,
            highlightScale: 1.1,
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.25,
          ),
          replyTitleTextStyle: TextStyle(color: theme.repliedTitleTextColor),
        ),
        swipeToReplyConfig: SwipeToReplyConfiguration(
          replyIconColor: theme.swipeToReplyIconColor,
        ),
        scrollToBottomButtonConfig: ScrollToBottomButtonConfig(
          backgroundColor: theme.textFieldBackgroundColor,
          border: Border.all(
            color: isDarkTheme ? Colors.transparent : Colors.grey,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.themeIconColor,
            weight: 10,
            size: 30,
          ),
        ),
        typeIndicatorConfig: TypeIndicatorConfiguration(
          flashingCircleBrightColor: theme.flashingCircleBrightColor,
          flashingCircleDarkColor: theme.flashingCircleDarkColor,
        ),
      ),
    );
  }
}
