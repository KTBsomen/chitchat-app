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
import 'package:chitchat/services/personal_chat_service.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';

class PersonalChatScreen extends StatefulWidget {
  final String pairKey;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPic;

  const PersonalChatScreen({
    Key? key,
    required this.pairKey,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPic,
  }) : super(key: key);

  @override
  State<PersonalChatScreen> createState() => _PersonalChatScreenState();
}

class _PersonalChatScreenState extends State<PersonalChatScreen> {
  final AppTheme theme = DarkTheme();
  final bool isDarkTheme = true;

  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');

  static String get baseurl =>
      AppVariables.get<String>('baseurl')?.trim() ?? 'http://localhost:3000';

  late final MQTTService mqtt;
  bool _mqttInitialized = false;
  bool isConnected = false;
  late ChatController _chatController;
  bool _isControllerInitialized = false;
  Timer? timer;
  List<Message> messageQueue = [];

  // --- Chat request & permissions state ---
  String _chatStatus = 'loading'; // 'none', 'pending', 'accepted', 'blocked'
  String? _requestSenderId;
  String? _requestReceiverId;

  // --- Pagination state ---
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingHistory = false;
  bool _initialLoadDone = false;

  late final UploadService uploadService;
  final ValueNotifier<String> typingUserIdProfilePic = ValueNotifier('');

  String get _personalTopic => 'personal/' + widget.pairKey + '/chat';

  // ---------- API: Fetch chat history with cursor-based pagination ----------

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

      final uri =
          Uri.parse(baseurl + '/personal/chat/history/' + widget.pairKey)
              .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        _nextCursor = data['nextCursor'];
        _hasMore = data['hasMore'] ?? false;

        if (mounted) {
          setState(() {
            _chatStatus = (data['chatStatus'] ?? 'none').toString();
            _requestSenderId = data['senderId']?.toString();
            _requestReceiverId = data['receiverId']?.toString();
          });
        }

        return results.map((item) {
          final payload = item['payload'];
          if (payload is Map) {
            final p = Map<String, dynamic>.from(payload);
            if (p['createdAt'] != null) {
              final parsed = DateTime.tryParse(p['createdAt'].toString());
              if (parsed != null) {
                p['createdAt'] = parsed.toLocal().toIso8601String();
              }
            }
            _registerOtherUser(p);
            var t = Message.fromJson(p);
            t.setStatus = MessageStatus.delivered;
            return t;
          }
          if (payload is String) {
            try {
              final parsed = jsonDecode(payload);
              if (parsed is Map) {
                final p = Map<String, dynamic>.from(parsed);
                _registerOtherUser(p);
                var t = Message.fromJson(p);
                t.setStatus = MessageStatus.delivered;
                return t;
              }
            } catch (_) {}
          }
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
        print('Failed to fetch personal chat history: ' +
            response.statusCode.toString());
        return [];
      }
    } catch (e) {
      print('Error fetching personal chat history: ' + e.toString());
      return [];
    }
  }

  void _registerOtherUser(Map<String, dynamic> data) {
    final senderId = data['sentBy'] as String?;
    if (senderId == null || senderId == _chatController.currentUser.id) return;

    final alreadyKnown =
        _chatController.otherUsers.any((u) => u.id == senderId);
    if (!alreadyKnown) {
      _chatController.otherUsers.add(ChatUser(
        id: senderId,
        name: data['senderName'] ?? widget.otherUserName,
        profilePhoto: data['senderPic'] ?? widget.otherUserPic,
      ));
    }
  }

  // ---------- Lifecycle ----------

  @override
  void initState() {
    super.initState();
    _initializeUploadService();

    final currentUserId = profileDetails?['_id'] ?? 'me';
    final currentUserName = profileDetails?['name'] ?? 'Me';
    final currentUserPic = profileDetails?['profilePic'];

    _chatController = ChatController(
      initialMessageList: [],
      scrollController: ScrollController(),
      onReaction: (reaction) {
        debugPrint('Message Reacted' + reaction.toString());
        _setReaction(reaction, false);
      },
      onReactionRemoved: (reaction) {
        debugPrint('Message Reacted Removed ' + reaction.toString());
        _setReaction(reaction, false);
      },
      currentUser: ChatUser(
        id: currentUserId,
        name: currentUserName,
        profilePhoto: currentUserPic,
      ),
      otherUsers: [
        ChatUser(
          id: widget.otherUserId,
          name: widget.otherUserName,
          profilePhoto: widget.otherUserPic,
        ),
      ],
    );

    _loadInitialHistory();
  }

  void _initializeUploadService() async {
    uploadService = UploadService(
        baseUrl: 'https://chitzchat.com/api/storage/api/v1/upload-url',
        apiKey: (await UserService.getAccessToken()) ?? '');
  }

  Future<void> _loadInitialHistory() async {
    final messages = await _fetchChatHistory(limit: 20);

    if (mounted) {
      if (messages.isNotEmpty) {
        _chatController.initialMessageList.addAll(messages);
        _chatController.messageStreamController
            .add(_chatController.initialMessageList);
        PersonalChatService.markChatAsSeen(widget.pairKey, messages.last.id);
      }
      setState(() {
        _isControllerInitialized = true;
        _initialLoadDone = true;
      });
    }

    // Only connect MQTT if chat is accepted
    if (_chatStatus == 'accepted') {
      _getToken();
    }
  }

  void _getToken() async {
    if (_mqttInitialized) return;
    _mqttInitialized = true;

    final userId = await UserService.getUserId();

    mqtt = MQTTService(
      broker: 'chitzchat.com',
      clientId:
          (userId.toString().substring(0, min(20, userId.toString().length))),
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
      onSubscribed: _onSubscribed,
      onUnSubscribed: (topic) => print('Unsubscribed from $topic'),
      onMessageReceived: _handleMessage,
    );

    final topic = _personalTopic;
    mqtt.setTopic = topic + '/+';

    mqtt.connect(topic + '/+').then((value) {
      print('Connected to MQTT broker for Personal Chat: ' + topic);
    }).catchError((error) {
      print('Error connecting to MQTT broker for Personal Chat: ' +
          error.toString());
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

      // Do NOT attempt MQTT reconnect if chat is not accepted
      if (_chatStatus != 'accepted') return;

      if (!mqtt.isConnected) {
        print('Auto reconnecting to Personal Chat...');
        mqtt.connect(_personalTopic + '/+');
      } else {
        if (messageQueue.isNotEmpty) {
          print('Publishing queued personal messages: ' +
              messageQueue.length.toString());
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
              print(
                  'Failed to publish queued personal message: ' + e.toString());
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
    print('Subscribed to personal chat: ' + topic);
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
      if (!isFromMQTT && isConnected && _chatStatus == 'accepted') {
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
                    title: const Text('Edit'),
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

      if (!isFromMQTT && isConnected && _chatStatus == 'accepted') {
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

      if (!isFromMQTT &&
          !message.isOneTime &&
          isConnected &&
          _chatStatus == 'accepted') {
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
    if (!isFromMQTT && isConnected && _chatStatus == 'accepted') {
      mqtt.publish(
        jsonEncode({
          'type': 'read',
          'status': 'read',
          'sentBy': _chatController.currentUser.id,
          'groupId': _personalTopic,
          'message': message.toJson(),
        }),
      );
    }
  }

  void _handleMessage(String message, {String? topic}) {
    if (topic != null && !topic.startsWith(_personalTopic)) {
      return;
    }
    try {
      if (message.contains('"type":"typing"')) {
        var data = jsonDecode(message);
        if (data['status'] == 'TypeWriterStatus.typing') {
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
      PersonalChatService.markChatAsSeen(widget.pairKey, msg.id);

      if (mounted) {
        _chatController.addMessage(msg);
      }
    } catch (e) {
      print('Error parsing personal chat message: ' + e.toString());
    }
  }

  // ---------- Load older messages ----------

  Future<void> _loadOlderMessages() async {
    if (_isLoadingHistory || !_hasMore) return;
    _isLoadingHistory = true;

    try {
      final olderMessages =
          await _fetchChatHistory(cursor: _nextCursor, limit: 20);

      if (olderMessages.isNotEmpty && mounted) {
        _chatController.initialMessageList.insertAll(0, olderMessages);
        _chatController.messageStreamController
            .add(_chatController.initialMessageList);
        setState(() {});
      }
    } catch (e) {
      print('Error loading older personal messages: ' + e.toString());
    } finally {
      _isLoadingHistory = false;
    }
  }

  // ---------- Send ----------

  void onRetryTap(Message message) {
    if (isConnected && _chatStatus == 'accepted') {
      final payload = message.toJson();
      payload['senderName'] = _chatController.currentUser.name;
      payload['senderPic'] = _chatController.currentUser.profilePhoto;
      try {
        mqtt.publish(jsonEncode(payload));
        message.setStatus = MessageStatus.delivered;
        setState(() {});
      } catch (e) {
        print('Retry failed: ' + e.toString());
      }
    } else {
      print('Cannot retry: MQTT not connected or chat not accepted');
    }
  }

  Future<void> _onSendTap(List<String> filePaths, ReplyMessage replyMessage,
      MessageType messageType, bool isOneTime,
      {String? id}) async {
    if (filePaths.isEmpty) return;

    final currentUserId = _chatController.currentUser.id;

    // Blocked check
    if (_chatStatus == 'blocked') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot message this user.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 1. Pending check
    if (_chatStatus == 'pending') {
      // If current user is the one who already sent the request:
      if (currentUserId == _requestSenderId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Waiting for ' +
                widget.otherUserName +
                ' to reply before you can send more messages.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      // If current user is the recipient replying to the pending request:
      if (currentUserId == _requestReceiverId) {
        final replyText = filePaths.first;
        final res = await PersonalChatService.sendChatRequest(
          targetUserId: widget.otherUserId,
          initialMessage: replyText,
        );

        if (!mounted) return;
        if (res['success'] == true) {
          setState(() {
            _chatStatus = 'accepted';
          });

          final message = Message(
            id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            createdAt: DateTime.now(),
            message: replyText,
            reaction: Reaction(reactions: [], reactedUserIds: []),
            sentBy: currentUserId,
            replyMessage: replyMessage,
            messageType: messageType,
            uploadProgress: ValueNotifier(1.0),
            onRetry: onRetryTap,
            isOneTime: isOneTime,
            status: MessageStatus.delivered,
          );

          _chatController.addMessage(message);
          _chatController.scrollToLastMessage(doit: true);
          PersonalChatService.markChatAsSeen(widget.pairKey, message.id);

          // Connect MQTT now that chat is accepted
          _getToken();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat accepted! Realtime messaging connected.'),
              backgroundColor: Color(0xFF00FF9D),
            ),
          );
          return;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Failed to reply to request'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    }

    // 2. Initial chat request (no request exists yet)
    if (_chatStatus == 'none') {
      final initialText = filePaths.first;
      final res = await PersonalChatService.sendChatRequest(
        targetUserId: widget.otherUserId,
        initialMessage: initialText,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _chatStatus = 'pending';
          _requestSenderId = currentUserId;
        });

        final message = Message(
          id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          createdAt: DateTime.now(),
          message: initialText,
          reaction: Reaction(reactions: [], reactedUserIds: []),
          sentBy: currentUserId,
          replyMessage: replyMessage,
          messageType: messageType,
          uploadProgress: ValueNotifier(1.0),
          onRetry: onRetryTap,
          isOneTime: isOneTime,
          status: MessageStatus.delivered,
        );

        _chatController.addMessage(message);
        _chatController.scrollToLastMessage(doit: true);
        PersonalChatService.markChatAsSeen(widget.pairKey, message.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message request sent to ' + widget.otherUserName),
            backgroundColor: Colors.tealAccent,
          ),
        );
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to send request'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    // 3. Accepted chat: send via MQTT
    for (final path in filePaths) {
      final file = File(path);

      final message = Message(
          id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
      PersonalChatService.markChatAsSeen(widget.pairKey, message.id);

      if (messageType == MessageType.video ||
          messageType == MessageType.image ||
          messageType == MessageType.voice) {
        message.setStatus = MessageStatus.uploading;
        await uploadService
            .uploadFile(
          file: file,
          path: 'uploads/chat',
          progressNotifier: message.uploadProgress,
        )
            .then((uploadResponse) {
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
              print('Failed to publish message: ' + e.toString());
              message.setStatus = MessageStatus.undelivered;
              messageQueue.add(message);
            }
          } else {
            message.setStatus = MessageStatus.undelivered;
            messageQueue.add(message);
          }
        }).catchError((error) {
          print('Upload failed: ' + error.toString());
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
            print('Failed to publish personal message: ' + e.toString());
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

  // ---------- Block / Report Handlers ----------

  void _handleBlockUser() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to block ' +
              widget.otherUserName +
              '? You will no longer receive messages from them.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final res =
                  await PersonalChatService.blockUser(widget.otherUserId);
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Blocked ' + widget.otherUserName)),
                  );
                  Navigator.pop(context); // Go back from chat
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(res['error'] ?? 'Failed to block user')),
                  );
                }
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleReportUser() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text('Report User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Report ' +
                  widget.otherUserName +
                  ' for inappropriate behavior or harassment.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter reason for report...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () async {
              final reason = textController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final res = await PersonalChatService.reportUser(
                targetUserId: widget.otherUserId,
                reason: reason,
              );
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Report submitted successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(res['error'] ?? 'Failed to report user')),
                  );
                }
              }
            },
            child: const Text('Submit Report',
                style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    timer = null;
    if (_mqttInitialized) {
      try {
        mqtt.disconnect();
      } catch (e) {
        print('Error disconnecting: ' + e.toString());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isControllerInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );
    }

    final currentUserId = _chatController.currentUser.id;

    Color statusColor;
    String statusText;
    if (_chatStatus == 'accepted') {
      statusColor = isConnected ? Colors.tealAccent : Colors.redAccent;
      statusText = isConnected ? 'Connected' : 'Connecting...';
    } else if (_chatStatus == 'pending') {
      statusColor = Colors.orangeAccent;
      statusText = 'Request Pending';
    } else if (_chatStatus == 'none') {
      statusColor = Colors.lightBlueAccent;
      statusText = 'New Request';
    } else {
      statusColor = Colors.grey;
      statusText = 'Chat';
    }

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
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: (widget.otherUserPic != null &&
                      widget.otherUserPic!.isNotEmpty)
                  ? NetworkImage(widget.otherUserPic!)
                  : null,
              child:
                  (widget.otherUserPic == null || widget.otherUserPic!.isEmpty)
                      ? Text(
                          widget.otherUserName.isNotEmpty
                              ? widget.otherUserName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.appBarTitleTextStyle,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: const Color(0xFF1E2230),
            onSelected: (value) {
              if (value == 'block') {
                _handleBlockUser();
              } else if (value == 'report') {
                _handleReportUser();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Report User', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text('Block User',
                        style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Informative Banner depending on chat request state
          if (_chatStatus == 'pending' && currentUserId == _requestSenderId)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF262112),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: Colors.orangeAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Message request pending. Waiting for ' +
                          widget.otherUserName +
                          ' to reply.',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_chatStatus == 'pending' && currentUserId == _requestReceiverId)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF132A24),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_unread_outlined,
                      color: Color(0xFF00FF9D), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.otherUserName +
                          ' sent you a message request. Reply to accept.',
                      style: const TextStyle(
                        color: Color(0xFF00FF9D),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_chatStatus == 'none')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF161E30),
              child: Row(
                children: [
                  const Icon(Icons.waving_hand_outlined,
                      color: Colors.lightBlueAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Send your first message to request a chat with ' +
                          widget.otherUserName +
                          '.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ChatView(
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
                messageTimeTextStyle:
                    TextStyle(color: theme.messageTimeTextColor),
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
                    if (isConnected && _chatStatus == 'accepted') {
                      mqtt.publish(
                        jsonEncode({
                          'type': 'typing',
                          'status': status.toString(),
                          'sentBy': _chatController.currentUser.id,
                          'groupId': _personalTopic,
                        }),
                      );
                    }
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
                          color: isDarkTheme
                              ? Colors.black12
                              : Colors.grey.shade200,
                          offset: const Offset(0, 20),
                          blurRadius: 40,
                        )
                      ],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                imageMessageConfig: ImageMessageConfiguration(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
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
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
