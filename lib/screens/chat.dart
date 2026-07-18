import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:chitchat/screens/search.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/userOnline.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/constants/theams.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/services/chats.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/mqtt.dart';
import 'package:flutterdb/flutterdb.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
//TODO
//Add retry for each message if not delivered
//add refresh of mqtt connection if disconnected
//Add message status for each message
// remove reaction on bottomsheet

class ChatScreen extends StatefulWidget {
  final dynamic data;
  const ChatScreen({super.key, this.data});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');
  FriendCircleGroup? groupDetails;
  late final MQTTService mqtt;
  bool _mqttInitialized = false;

  AppTheme theme = DarkTheme();
  bool isDarkTheme = true;
  late ChatController _chatController;
  bool _isControllerInitialized = false;
  late Collection chats;
  int windowSize = 20;
  int pageinmemory = 2;
  List<Message> messageQueue = [];
  final Set<String> _memorySentUrls = {}; // prevent duplicate memory uploads
  Future<List<Message>> initDB() async {
    final db = FlutterDB();

    try {
      chats = await db.collection('chats');
      return getInitialMessages(days: 2);
    } on Exception catch (e) {
      // Handle the exception here
      print('Error initializing database: $e');
      return Future.value([]);
    }
  }

  String chatToken = '';
  String? accessToken = '';

  late final UploadService uploadService;

  void _initializeUploadService() async {
    uploadService = UploadService(
        baseUrl: "https://chitzchat.com/api/storage/api/v1/upload-url",
        apiKey: (await UserService.getAccessToken()) ?? '');
  }

  void _getToken(d) async {
    // Prevent duplicate MQTT initialization
    if (_mqttInitialized) {
      print('⚠️ MQTT already initialized, skipping');
      return;
    }
    _mqttInitialized = true;

    mqtt = MQTTService(
      broker: '13.204.75.73',
      // broker: '192.168.0.114',
      clientId: ((await UserService.getUserId()).toString().substring(0, 20)),
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
      onSubscribed: _onSubscribed,
      onUnSubscribed: _onUnSubscribed,
      onMessageReceived: _handleMessage,
    );
    mqtt.setTopic = "$d/+";
    mqtt.connect("$d/+").then((value) {
      print('Connected to MQTT broker');
    }).catchError((error) {
      print('Error connecting to MQTT broker: $error');
    });
    runMqttCheck(d);
  }

  Timer? timer;
  void runMqttCheck(d) {
    // Cancel existing timer before creating new one
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 10), (t) {
      // Check if widget is still mounted before doing anything
      if (!mounted) {
        t.cancel();
        return;
      }

      if (!mqtt.isConnected) {
        print('🔁 Auto reconnecting...');
        mqtt.connect("$d/+");
      } else {
        print("elements of messageQueue: ${messageQueue}");
        for (var element in messageQueue) {
          mqtt.publish(jsonEncode(element.toJson()));
          element.setStatus = MessageStatus.delivered;
          chats.insert(element.toJson());
        }
        messageQueue.clear();
      }
    });
  }

  void _showIncomingCallDialog(String roomId, String callerId) {
    return;
    // final caller = groupDetails?.members.firstWhere((e) => e.id == callerId,
    //     orElse: () => FriendCircleMember(
    //         id: callerId, avatarUrl: '', additionalData: {}));
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => IncomingCallWidget(
    //       callerName: caller?.additionalData["memberName"] ?? "Unknown",
    //       callerAvatarUrl: caller?.avatarUrl ?? "",
    //       onAccept: () async {
    //         Navigator.pop(context);
    //         final options = JitsiMeetConferenceOptions(
    //             room: roomId,
    //             serverURL: 'https://meet.ffmuc.net/',
    //             configOverrides: {
    //               "allowUnsafeActions": true,
    //               "welcomePageEnabled": false,
    //             },
    //             userInfo: JitsiMeetUserInfo(
    //               displayName: profileDetails?["name"] ?? "Unknown",
    //               email: profileDetails?["email"] ?? "",
    //               avatar: profileDetails?["profilePic"] ?? "",
    //             ));
    //         try {
    //           await JitsiMeet().join(options);
    //         } catch (e) {
    //           print("Join error: $e");
    //         }
    //       },
    //       onDecline: () {
    //         Navigator.pop(context);
    //       },
    //     ),
    //   ),
    // );
  }

  String _typingUserIdProfilePic = '';
  ValueNotifier<String> typingUserIdProfilePic = ValueNotifier('');
  void _handleMessage(String message, {String? topic}) {
    if (topic != null &&
        groupDetails?.groupId != null &&
        !topic.startsWith(groupDetails!.groupId!)) {
      print(
          "Ignoring campus/other group message from topic: $topic (current group: ${groupDetails?.groupId})");
      return;
    }
    // Deduplicate and store locally
    //  LocalMessageStore.instance.saveMessageIfUnique(topic, message);
    // Handle the message as needed
    if (message.contains('"message_type":"custom"')) {
      var data = jsonDecode(message);
      Message joinDetails = Message.fromJson(data);
      String roomId = joinDetails.message;
      String callerId = joinDetails.sentBy;
      print("Incoming call from $callerId in room $roomId");
      _showIncomingCallDialog(roomId, callerId);
      // return;
    }
    print('Received message: $message');
    if (message.contains('"type":"typing"')) {
      var data = jsonDecode(message);
      if (data['status'] == "TypeWriterStatus.typing") {
        String typingUserId = data['sentBy'];
        typingUserIdProfilePic.value = _chatController.otherUsers
                .where((user) => user.id == typingUserId)
                .first
                .profilePhoto ??
            '';
        _chatController.setTypingIndicator = true;
        setState(() {});
      } else {
        typingUserIdProfilePic.value = '';
        _chatController.setTypingIndicator = false;
        setState(() {});
      }

      print("typing user profile pic $typingUserIdProfilePic");

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

    // You can also notify listeners or update the UI here
    receiveMessage(mess: message);
  }

  List<Message> _initialMessages = [];
  int page = 1;
  Map<String, dynamic> messagePerPage = {};
  Future<List<Message>> getInitialMessages({int days = 2}) async {
    // var messages = await chats.find({
    //   'createdAt': {
    //     '\$gte': DateTime.now().subtract(Duration(days: days)),
    //   },
    // });
    // var messages = await chats.findByDateRange(
    //   DateTime.now().subtract(Duration(days: days)),
    //   DateTime.now(),
    // );
    var messages = await chats.findByPage(page: page, limit: windowSize);
    print("messages: $messages");
    if (messages.isNotEmpty) {
      _initialMessages = messages.map((e) {
        return Message.fromJson(e);
      }).toList();
    }

    if (_initialMessages.isNotEmpty) {
      oldestLoadedAt = DateTime.now().subtract(Duration(days: days));
      newestLoadedAt = DateTime.now();
    }

    page++;

    return _initialMessages.reversed.toList();
  }

  void deletePageData(page) {
    if (page <= 0) {
      print("page is less than 0");
      return;
    }
    print("page to delete: $page");
    if (messagePerPage.containsKey("page$page")) {
      int startIndex = _chatController.initialMessageList.indexWhere(
          (element) => element.id == messagePerPage["page$page"]["start_id"]);
      int endIndex = _chatController.initialMessageList.indexWhere(
          (element) => element.id == messagePerPage["page$page"]["end_id"]);
      if (startIndex != -1 && endIndex != -1) {
        _chatController.initialMessageList
            .removeRange(startIndex, endIndex + 1);
      }
      messagePerPage.remove("page$page");
      print("page removed");
    } else {
      print("page not found");
    }
  }

  void _onConnected() {
    print('✅ Connected');
    if (mounted) {
      setState(() {
        isConnected = true;
      });
    }
  }

  void _onDisconnected() {
    print('❌ Disconnected');
    if (mounted && !isConnected) {
      isConnected = false;
    }
  }

  void _onSubscribed(String topic) => print('📌 Subscribed to $topic');
  void _onUnSubscribed(String? topic) => print('📌 Unsubscribed from $topic');
  void clearMessageNotification() async {
    ChatServices.resetMessageNotificationCount();
  }

  bool isConnected = false;
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dialogShown) return;

    clearMessageNotification();
    if (profileDetails != null && profileDetails!['myGroup'] != null) {
      groupDetails =
          GroupsService.buildFriendCircleGroup(profileDetails!['myGroup']);
      if (mounted) {
        setState(() {
          groupDetails = groupDetails;
        });
      }
    }
    if (profileDetails != null && profileDetails!['myGroup'] == null) {
      _dialogShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('No group Found'),
              content: Text('Please create or join one to continue.'),
              actions: <Widget>[
                TextButton(
                  child: Text('ok'),
                  onPressed: () async {
                    Navigator.of(context).pop();

                    Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => SearchPage(),
                        ),
                        (route) => route.isFirst);
                  },
                ),
              ],
            );
          },
        );
      });
      return;
    } else if (profileDetails == null) {
      _dialogShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('No Profile Found'),
              content: Text('Please login to continue.'),
              actions: <Widget>[
                TextButton(
                  child: Text('Login'),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      });
      return;
    }
    _getToken(groupDetails?.groupId);
  }

  void _setReaction(Message reactions, bool isFromMQTT) async {
    try {
      await chats
          .updateMany({"id": reactions.id}, {"reaction": reactions.reaction});
      Message mtu = _findMessage(reactions);
      setState(() {
        mtu.reaction = reactions.reaction;
      });
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initializeUploadService();
    clearMessageNotification();
    print(profileDetails);
    PresenceManager().onChatPageOpened();
    initDB().then((value) {
      print('Database initialized successfully');

      // if (value.isNotEmpty) {
      //   oldestLoadedAt = value.first.createdAt;
      //   newestLoadedAt = value.last.createdAt;
      // }
      _chatController = ChatController(
          initialMessageList: value,
          scrollController: ScrollController(),
          onReaction: (reaction) {
            /// Do something when user reacts to message
            debugPrint('Message Reacted${reaction.toString()}');
            _setReaction(reaction, false);
          },
          onReactionRemoved: (reaction) {
            /// Do something when user removes reaction from message
            debugPrint('Message Reacted Removed ${reaction.toString()}');
            _setReaction(reaction, false);
          },
          currentUser: ChatUser(
            id: profileDetails?["_id"],
            name: profileDetails?["name"],
            profilePhoto: profileDetails?["profilePic"],
          ),
          otherUsers: groupDetails?.members
                  .map(
                    (e) => ChatUser(
                      id: e.id,
                      name: e.additionalData["memberName"],
                      profilePhoto: e.avatarUrl,
                    ),
                  )
                  .toList() ??
              []);
      if (mounted) {
        setState(() {
          _isControllerInitialized = true;
        });
      }
      print("widget data=${widget.data}");
      if (widget.data != null) {
        print("widget type ${widget.data.runtimeType}");
        if (widget.data.runtimeType == List<String>) {
          List<String> data = widget.data as List<String>;
          String id = DateTime.now().millisecondsSinceEpoch.toString();
          _onSendTap(
              id: id,
              data
                  .where((x) =>
                      x.contains(".jpeg") ||
                      x.contains(".jpg") ||
                      x.contains(".webp") ||
                      x.contains(".png"))
                  .toList(),
              ReplyMessage(
                  replyBy: _chatController.currentUser.id,
                  replyTo: _chatController.currentUser.id,
                  messageId: id,
                  message:
                      "${_chatController.currentUser.name} sent you a chit"),
              MessageType.image,
              true);

          data
              .where((x) => x.contains(".mp4") || x.contains(".mov"))
              .forEach((element) {
            _onSendTap(
                [element],
                ReplyMessage(
                    replyBy: _chatController.currentUser.id,
                    replyTo: _chatController.currentUser.id,
                    messageId: _chatController.initialMessageList.first.id,
                    message: "sent you a chit"),
                MessageType.video,
                true);
          });
        } else if (widget.data.runtimeType == String) {
          _onSendTap(
              [widget.data], const ReplyMessage(), MessageType.text, true);
        } else if (widget.data.runtimeType == Map) {
          Map<String, dynamic> data = widget.data as Map<String, dynamic>;
          if (data['message'] != null) {
            _onSendTap([data['message']], const ReplyMessage(),
                MessageType.text, true);
          }
        }
      }
    }).catchError((error) {
      print('Error initializing database: $error');
    });
  }

  @override
  void dispose() {
    // Cancel timer first to stop reconnection attempts
    timer?.cancel();
    timer = null;

    // Disconnect MQTT
    try {
      if (_mqttInitialized) {
        mqtt.disconnect();
      }
    } catch (e) {
      print('Error disconnecting MQTT: $e');
    }

    PresenceManager().onChatPageClosed();
    clearMessageNotification();

    // Call super.dispose() LAST
    super.dispose();
  }

  void _showHideTypingIndicator() {
    _chatController.setTypingIndicator = !_chatController.showTypingIndicator;
  }

  void receiveMessage({String? mess}) async {
    print('Received message: $mess');
    Message j;
    try {
      var msg = jsonDecode(mess!);
      print(msg);
      j = Message.fromJson(msg);
      _chatController.addMessage(j);
    } catch (e) {
      j = Message(
          id: Random().nextInt(1000000000).toString(),
          message: mess ?? "ranom",
          createdAt: DateTime.now(),
          sentBy: groupDetails!.members[0].id,
          reaction: Reaction(reactions: [], reactedUserIds: []),
          replyMessage: ReplyMessage(
            messageId: Random().nextInt(1000000000).toString(),
            messageType: MessageType.text,
          ),
          messageType: MessageType.text,
          uploadProgress: ValueNotifier(1.0));
      print(e);
      _chatController.addMessage(j);
    }
    chats.insert(j.toJson()).then((value) {
      print('Message inserted successfully: $value');
    }).catchError((error) {
      print('Error inserting message: $error');
    });
    await Future.delayed(const Duration(milliseconds: 500));
    _chatController.addReplySuggestions([
      const SuggestionItemData(text: 'Thanks.'),
      const SuggestionItemData(text: 'Great.'),
      const SuggestionItemData(text: 'Ok.'),
      const SuggestionItemData(text: 'Yes.'),
      const SuggestionItemData(text: 'No.'),
      const SuggestionItemData(text: 'Maybe.'),
    ]);
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
                    leading: Icon(Icons.edit, color: Colors.blue),
                    title: Text("Edit"),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditMessagePopup(message);
                    },
                  ),
                // ListTile(
                //   leading: Icon(Icons.push_pin, color: Colors.orange),
                //   title: Text("Pin"),
                //   onTap: () {
                //     Navigator.pop(context);
                //     // Handle pin action
                //   },
                // ),
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
              'You can only Edit messages sent within the last 1 days.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    } else {
      //_chatController.initialMessageList.remove(_findMessage(message));
      _findMessage(message).message = message.message;
      _chatController.removeReplySuggestions();

      chats.updateMany({
        'id': message.id,
      }, {
        "message": message.message
      }).then((value) {
        print('Message edited successfully: $value');
      }).catchError((error) {
        print('Error edited message: $error');
      });
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
                _chatController.initialMessageList
                    .remove(_findMessage(message));
                _chatController.removeReplySuggestions();
                chats.deleteMany({
                  'id': message.id,
                }).then((value) {
                  print('Message deleted successfully: $value');
                }).catchError((error) {
                  print('Error deleting message: $error');
                });
                Navigator.of(context).pop();
              },
              child: const Text('Delete for me'),
            ),
          ],
        ),
      );
    } else {
      _chatController.initialMessageList.remove(_findMessage(message));
      _chatController.removeReplySuggestions();

      chats.deleteMany({
        'id': message.id,
      }).then((value) {
        print('Message deleted successfully: $value');
      }).catchError((error) {
        print('Error deleting message: $error');
      });
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
    // if (message.status == MessageStatus.read) {
    //   return;
    // }
    final Message messageToUpdate = _findMessage(message);
    messageToUpdate.setStatus = MessageStatus.read;
    chats.updateMany({
      'id': message.id,
    }, {
      'readBy': _chatController.currentUser.id,
      "status": "read"
    }).then((value) {
      print('Message read successfully: $value');
      if (!isFromMQTT) {
        mqtt.publish(
          jsonEncode({
            'type': 'read',
            'status': "read",
            'sentBy': _chatController.currentUser.id,
            'groupId': groupDetails!.groupId,
            'message': message.toJson(),
          }),
        );
      }
    }).catchError((error) {
      print('Error marking message as read: $error');
    });
  }

  /// find the message on the ui so it can be updated on the uis also
  Message _findMessage(Message message) {
    // try {

    //locate the message in chatlist
    final Message messageToupdate = _chatController.initialMessageList
        .firstWhere((m) => m.id == message.id);
    return messageToupdate;
    // } catch (e) {

    // }
  }

  bool isLoading = false;
  DateTime? oldestLoadedAt; //scroll up
  DateTime? newestLoadedAt; //scroll up
  DateTime? previousStartLoadedAt; //scroll down
  DateTime? previousEndLoadedAt; //scroll down

  bool _isLoadingOlder = false;
  bool _isLoadingNewer = false;
  List<Message> _visibleMessages = [];

  // Window configuration
  final int _windowSize = 50; // Number of messages to keep in memory
  final int _fetchThreshold = 15; // When to fetch more messages

  // Pagination tracking
  int _oldestVisibleId = -1; // Database ID of oldest message in view
  int _newestVisibleId = -1; // Database ID of newest message in view
  int _totalMessageCount = 0; // Total count in database

  bool _isAtNewestMessages = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isControllerInitialized
          ? ChatView(
              isLastPage: false,
              loadMoreData: () async {
                print("page when loading old message: $page");
                print(messagePerPage);
                if (page > 0) {
                } else {
                  print("page is less than 0 so no loading needed");
                  return;
                }
                if (isLoading || messagePerPage.containsKey("page$page")) {
                  print('1Already loading data');
                  return;
                }
                double previousPosition =
                    _chatController.scrollController.position.pixels;
                // Save current scroll position and total height
                double oldScrollOffset =
                    _chatController.scrollController.offset;
                double oldMaxExtent =
                    _chatController.scrollController.position.maxScrollExtent;

                // Fetch older messages
                isLoading = true;
                print('Load old Data');
                print("oldestLoadedAt: $oldestLoadedAt");
                print("newestLoadedAt: $newestLoadedAt");
                // var messages = await chats.findByDateRange(
                //   oldestLoadedAt!.subtract(const Duration(days: 2)),
                //   oldestLoadedAt!, //end is the start of the ui, first message from it we fetch new older message like 2 days back
                // );
                var messages =
                    await chats.findByPage(page: page, limit: windowSize);
                print("page: $page");
                if (messages.isNotEmpty) {
                  messagePerPage["page$page"] = {
                    "count": messages.length,
                    "start_id": messages.first["id"],
                    "end_id": messages.last["id"],
                  };

                  page++;
                }
                print("messages: $messages");

                if (messages.isNotEmpty) {
                  _chatController.initialMessageList.insertAll(
                      0,
                      messages.reversed.map((e) {
                        return Message.fromJson(e);
                      }).toList());
                  _chatController.messageStreamController
                      .add(_chatController.initialMessageList);

                  newestLoadedAt = oldestLoadedAt;

                  oldestLoadedAt = oldestLoadedAt!.subtract(const Duration(
                      days:
                          2)); // on every scroll search for 2 days older messages.

                  print("newestLoadedAt: $newestLoadedAt");
                  print("oldestLoadedAt: $oldestLoadedAt");
                  // if (mounted) {
                  //   WidgetsBinding.instance.addPostFrameCallback((_) {
                  //     // if (_chatController.scrollController.hasClients) {
                  //     //   _chatController.scrollController.jumpTo(
                  //     //     previousPosition + (messages.length * 70),
                  //     //   );
                  //     // }
                  //     double newMaxExtent = _chatController
                  //         .scrollController.position.maxScrollExtent;
                  //     double delta = newMaxExtent - oldMaxExtent;

                  //     // Adjust scroll position without animation
                  //     _chatController.scrollController.jumpTo(oldScrollOffset);
                  //     if (_chatController.initialMessageList.length >
                  //         windowSize) {
                  //       deletePageData(page - (pageinmemory ~/ 2) - 1);
                  //       print("messead deleted");
                  //       previousStartLoadedAt =
                  //           _chatController.initialMessageList.last.createdAt;
                  //       previousEndLoadedAt =
                  //           DateTime.tryParse(messages.last["createdAt"]);
                  //     }
                  //   });
                  // }
                }
                isLoading = false;
              },
              loadPreviousData: () async {
                if (_isLoadingOlder) return;
                _isLoadingOlder = true;
                Future.delayed(const Duration(seconds: 2), () {
                  _isLoadingOlder = false;
                  print('Load previous data');
                });
              },
              loadingWidget: const Center(
                child: CircularProgressIndicator(),
              ),
              chatController: _chatController,
              onSendTap: _onSendTap,
              onChatListTap: () {
                /// Do something when chat list is tapped
                debugPrint('Chat List Tapped');
              },
              featureActiveConfig: const FeatureActiveConfig(
                lastSeenAgoBuilderVisibility: true,
                receiptsBuilderVisibility: true,
                enableScrollToBottomButton: true,
                enablePagination: true,
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
              chatViewState: ChatViewState.hasMessages,
              chatViewStateConfig: ChatViewStateConfiguration(
                loadingWidgetConfig: ChatViewStateWidgetConfiguration(
                  loadingIndicatorColor: theme.outgoingChatBubbleColor,
                ),
                onReloadButtonTap: () {
                  print("kjhgfcvthis is reload button");
                },
              ),
              typeIndicatorConfig: TypeIndicatorConfiguration(
                flashingCircleBrightColor: theme.flashingCircleBrightColor,
                flashingCircleDarkColor: theme.flashingCircleDarkColor,
              ),
              appBar: ChatViewAppBar(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GroupPrivateViewScreen()));
                },
                elevation: theme.elevation,
                backGroundColor: theme.appBarColor,
                profilePicture:
                    groupDetails?.groupData['GroupProfilePic'] ?? "",
                backArrowColor: theme.backArrowColor,
                chatTitle: groupDetails?.groupData['name'] ?? "",
                chatTitleTextStyle: TextStyle(
                  color: theme.appBarTitleTextStyle,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.25,
                ),
                userStatus: isConnected ? "online" : "offline",
                userStatusTextStyle: const TextStyle(color: Colors.grey),
                actions: [
                  IconButton(
                    onPressed: _onThemeIconTap,
                    icon: Icon(
                      isDarkTheme
                          ? Icons.brightness_4_outlined
                          : Icons.dark_mode_outlined,
                      color: theme.themeIconColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'video call',
                    onPressed: () =>
                        makeAcall("video"), // _showHideTypingIndicator,
                    icon: Icon(
                      Icons.video_call_rounded,
                      color: theme.themeIconColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Audio call',
                    onPressed: () => makeAcall("audio"), //receiveMessage,
                    icon: Icon(
                      Icons.call,
                      color: theme.themeIconColor,
                    ),
                  ),
                ],
              ),
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
                cancelRecordConfiguration: CancelRecordConfiguration(
                  onCancel: () {
                    print("resdnsdjfns");
                  },
                ),
                textFieldConfig: TextFieldConfiguration(
                  maxLines: 10,
                  onMessageTyping: (status) {
                    /// Do with status
                    mqtt.publish(
                      jsonEncode({
                        'type': 'typing',
                        'status': status.toString(),
                        'sentBy': _chatController.currentUser.id,
                        'groupId': groupDetails!.groupId,
                      }),
                    );
                  },
                  compositionThresholdTime: const Duration(seconds: 1),
                  textStyle: TextStyle(color: theme.textFieldTextColor),
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
                      showReceiptsIn: ShowReceiptsIn.all),
                  color: theme.outgoingChatBubbleColor,
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
                  textStyle:
                      TextStyle(color: theme.inComingChatBubbleTextColor),
                  onMessageRead: (message) {
                    /// send your message reciepts to the other client
                    debugPrint('Message Read');
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
                  //show popover menu with a option edit
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
                customMessageBuilder: (message) {
                  /// Do something with custom message
                  debugPrint('Custom Message: ${message.message}');
                  // Show a custom widget for call invitations
                  if (message.message.startsWith('chitchat_video_call_')) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 15),
                      decoration: BoxDecoration(
                          color: theme.inComingChatBubbleColor,
                          borderRadius: BorderRadius.circular(50)),
                      child: ListTile(
                        leading: Icon(Icons.video_call, color: Colors.green),
                        title: Text('Join Video Call',
                            style: TextStyle(
                                color: theme.inComingChatBubbleTextColor)),
                        subtitle: Text('Tap to join the video call'),
                        onTap: () async {
                          final options = JitsiMeetConferenceOptions(
                              room: message.message,
                              serverURL: 'https://meet.ffmuc.net/',
                              userInfo: JitsiMeetUserInfo(
                                displayName:
                                    profileDetails?["name"] ?? "Unknown",
                                email: profileDetails?["email"] ?? "",
                                avatar: profileDetails?["profilePic"] ?? "",
                              ),
                              featureFlags: {
                                "prejoinpage.enabled": false,
                              },
                              configOverrides: {
                                "prejoinPageEnabled": false,
                                "startWithAudioMuted": false,
                                "startWithVideoMuted": false,
                                'disableInviteFunctions':
                                    true, // Hides invite UI
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
                        },
                      ),
                    );
                  }
                  if (message.message.startsWith('chitchat_audio_call_')) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 15),
                      decoration: BoxDecoration(
                          color: theme.inComingChatBubbleColor,
                          borderRadius: BorderRadius.circular(50)),
                      child: ListTile(
                        leading: Icon(Icons.call, color: Colors.blue),
                        title: Text('Join Audio Call',
                            style: TextStyle(
                                color: theme.inComingChatBubbleTextColor)),
                        subtitle: Text('Tap to join the audio call'),
                        onTap: () async {
                          final options = JitsiMeetConferenceOptions(
                            room: message.message,
                            serverURL: 'https://meet.ffmuc.net/',
                            userInfo: JitsiMeetUserInfo(
                              displayName: profileDetails?["name"] ?? "Unknown",
                              email: profileDetails?["email"] ?? "",
                              avatar: profileDetails?["profilePic"] ?? "",
                            ),
                            featureFlags: {
                              "prejoinpage.enabled": false,
                            },
                            configOverrides: {
                              'startWithAudioMuted': false,
                              'startWithVideoMuted': true,
                              "prejoinPageEnabled": false,
                              'disableInviteFunctions': true, // Hides invite UI
                              'toolbarButtons': [
                                'camera',
                                'microphone',
                                'hangup',
                                'select-background',
                                // add any other buttons you want
                              ],
                            },
                          );
                          try {
                            await JitsiMeet().join(options);
                          } catch (e) {
                            print("Join error: $e");
                          }
                        },
                      ),
                    );
                  }
                  return Text(
                    message.message,
                    style: TextStyle(color: theme.inComingChatBubbleTextColor),
                  );
                },
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
                    /// Do something when user taps on image

                    debugPrint(message.message);
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierDismissible: true,
                        pageBuilder: (BuildContext context, _, __) {
                          return ZoomableImagePopup(
                            imageUrl: message.message,
                            // onEdit: () => _editgroup(context),
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
                    onPressed: (imageUrl) {
                      /// Do something when user taps on share icon
                      debugPrint(imageUrl);
                      // Implement sharing functionality here
                      // For example, using the 'share_plus' package:

                      //   Share.share(imageUrl);
                    },
                  ),
                ),
              ),
              profileCircleConfig: ProfileCircleConfiguration(
                profileImageUrl: typingUserIdProfilePic,
              ),
              repliedMessageConfig: RepliedMessageConfiguration(
                backgroundColor: theme.repliedMessageColor,
                verticalBarColor: theme.verticalBarColor,
                repliedMsgAutoScrollConfig: RepliedMsgAutoScrollConfig(
                  enableHighlightRepliedMsg: true,
                  highlightColor: Colors.pinkAccent.shade100,
                  highlightScale: 1.1,
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.25,
                ),
                replyTitleTextStyle:
                    TextStyle(color: theme.repliedTitleTextColor),
              ),
              swipeToReplyConfig: SwipeToReplyConfiguration(
                replyIconColor: theme.swipeToReplyIconColor,
              ),
              replySuggestionsConfig: ReplySuggestionsConfig(
                itemConfig: SuggestionItemConfig(
                  decoration: BoxDecoration(
                    color: theme.textFieldBackgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.outgoingChatBubbleColor ?? Colors.white,
                    ),
                  ),
                  textStyle: TextStyle(
                    color: isDarkTheme ? Colors.white : Colors.black,
                  ),
                ),
                onTap: (item) => _onSendTap(
                    [item.text], const ReplyMessage(), MessageType.text, false),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  void onRetryTap(Message message) {
    mqtt.publish(jsonEncode(message.toJson()));
    message.setStatus = MessageStatus.delivered;
    setState(() {});
    chats.insert(message.toJson()).then((value) {
      print('Message inserted: $value');
    }).catchError((e) {
      print('DB error: $e');
    });
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
          mqtt.publish(jsonEncode(message.toJson()));
          message.setStatus = MessageStatus.delivered;

          // Auto-add media to memories (fire-and-forget, skip duplicates)
          final url = uploadResponse.publicUrl;
          if ((messageType == MessageType.image ||
                  messageType == MessageType.video) &&
              groupDetails != null &&
              !_memorySentUrls.contains(url) &&
              !isOneTime) {
            _memorySentUrls.add(url);
            PostService.createMemories(
              files: [url],
              myGroupId: groupDetails!.groupId,
            ).then((result) {
              if (result['success']) {
                print('[MEMORY] Auto-saved chat media as memory');
              } else {
                print('[MEMORY] Failed: ${result['error']}');
                _memorySentUrls.remove(url); // allow retry
              }
            });
          }
        }).catchError((error) {
          print('Upload failed: $error');
          message.setStatus = MessageStatus.error;
        });
      } else {
        try {
          mqtt.publish(jsonEncode(message.toJson()));
        } on Exception catch (e) {
          print('Failed to publish message: $e');
          messageQueue.add(message);
          return;
        }
        message.setStatus = MessageStatus.delivered;
      }

      chats.insert(message.toJson()).then((value) {
        print('Message inserted: $value');
      }).catchError((e) {
        print('DB error: $e');
      });
    }

    _chatController.scrollToLastMessage(doit: true);
  }

  void _onThemeIconTap() {
    if (mounted)
      setState(() {
        if (isDarkTheme) {
          theme = LightTheme();
          isDarkTheme = false;
        } else {
          theme = DarkTheme();
          isDarkTheme = true;
        }
      });
  }

  Future<void> makeAcall(String type) async {
    final roomId =
        'chitchat_${type}_call_${DateTime.now().millisecondsSinceEpoch}';

    // Step 1: Send invitation message
    final callMessage = Message(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      message: roomId,
      reaction: Reaction(reactions: [], reactedUserIds: []),
      sentBy: _chatController.currentUser.id,
      replyMessage: const ReplyMessage(),
      messageType: MessageType.custom,
      uploadProgress: ValueNotifier(1.0),
    );

    mqtt.publish(jsonEncode(callMessage.toJson()));
    // _chatController.addMessage(callMessage);
    // callMessage.setStatus = MessageStatus.delivered;

    // Step 2: Join call
    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://meet.ffmuc.net/',
      room: roomId,
      userInfo: JitsiMeetUserInfo(
        displayName: _chatController.currentUser.name,
        email: profileDetails?['email'],
        avatar: _chatController.currentUser.profilePhoto,
      ),
      featureFlags: {
        'welcomepage.enabled': false,
        'pip.enabled': true,
        'add-people.enabled': false,
        'chat.enabled': true,
        'raise-hand.enabled': true,
        'video-share.enabled': true,
        'meeting-name.enabled': false,
        "prejoinpage.enabled": false,
        'select-background': true,
      },
      configOverrides: {
        'startWithAudioMuted': type == 'video',
        'startWithVideoMuted': type == 'audio',
        "prejoinPageEnabled": false,
        'disableInviteFunctions': true, // Hides invite UI
        'toolbarButtons': [
          'camera',
          'microphone',
          'hangup',
          'select-background',
          // add any other buttons you want
        ],
      },

      // Mute video if audio call
    );

    try {
      await JitsiMeet().join(options);
    } catch (e) {
      print('Jitsi join error: $e');
    }
  }
}



  // loadMoreData: () async {
  //               print("page when loading old message: $page");
  //               print(messagePerPage);
  //               // if (page > 0) {
  //               //   page++;
  //               // } else {
  //               //   print("page is less than 0 so no loading needed");
  //               //   return;
  //               // }
  //               if (isLoading || messagePerPage.containsKey("page$page")) {
  //                 print('1Already loading data');
  //                 return;
  //               }
  //               double previousPosition =
  //                   _chatController.scrollController.position.pixels;
  //               // Save current scroll position and total height
  //               double oldScrollOffset =
  //                   _chatController.scrollController.offset;
  //               double oldMaxExtent =
  //                   _chatController.scrollController.position.maxScrollExtent;

  //               // Fetch older messages
  //               isLoading = true;
  //               print('Load old Data');
  //               print("oldestLoadedAt: $oldestLoadedAt");
  //               print("newestLoadedAt: $newestLoadedAt");
  //               // var messages = await chats.findByDateRange(
  //               //   oldestLoadedAt!.subtract(const Duration(days: 2)),
  //               //   oldestLoadedAt!, //end is the start of the ui, first message from it we fetch new older message like 2 days back
  //               // );
  //               var messages = await chats.findByPage(page, windowSize);
  //               print("page: $page");
  //               if (messages.isNotEmpty) {
  //                 messagePerPage["page$page"] = {
  //                   "count": messages.length,
  //                   "start_id": messages.first["id"],
  //                   "end_id": messages.last["id"],
  //                 };

  //                 page++;
  //               }
  //               print("messages: $messages");

  //               if (messages.isNotEmpty) {
  //                 _chatController.initialMessageList.insertAll(
  //                     0,
  //                     messages.map((e) {
  //                       return Message.fromJson(e);
  //                     }).toList());
  //                 _chatController.messageStreamController
  //                     .add(_chatController.initialMessageList);

  //                 newestLoadedAt = oldestLoadedAt;

  //                 oldestLoadedAt = oldestLoadedAt!.subtract(const Duration(
  //                     days:
  //                         2)); // on every scroll search for 2 days older messages.

  //                 print("newestLoadedAt: $newestLoadedAt");
  //                 print("oldestLoadedAt: $oldestLoadedAt");
  //                 if (mounted) {
  //                   WidgetsBinding.instance.addPostFrameCallback((_) {
  //                     // if (_chatController.scrollController.hasClients) {
  //                     //   _chatController.scrollController.jumpTo(
  //                     //     previousPosition + (messages.length * 70),
  //                     //   );
  //                     // }
  //                     double newMaxExtent = _chatController
  //                         .scrollController.position.maxScrollExtent;
  //                     double delta = newMaxExtent - oldMaxExtent;

  //                     // Adjust scroll position without animation
  //                     _chatController.scrollController.jumpTo(oldScrollOffset);
  //                     if (_chatController.initialMessageList.length >
  //                         windowSize) {
  //                       deletePageData(page - (pageinmemory ~/ 2) - 1);
  //                       print("messead deleted");
  //                       previousStartLoadedAt =
  //                           _chatController.initialMessageList.last.createdAt;
  //                       previousEndLoadedAt =
  //                           DateTime.tryParse(messages.last["createdAt"]);
  //                     }
  //                   });
  //                 }
  //               }
  //               isLoading = false;
  //             },
  //             loadPreviousData: () async {
  //               if (page > 0) {
  //                 page--;
  //               } else {
  //                 print("page is less than 0 so no loading needed");
  //                 return;
  //               }
  //               if (isLoading) {
  //                 print('2Already loading data');
  //                 // return;
  //               }
  //               if (messagePerPage.containsKey("page${page}")) {
  //                 print('3Already loading data');
  //                 return;
  //               }
  //               isLoading = true;
  //               double previousPosition =
  //                   _chatController.scrollController.position.pixels;
  //               double oldScrollOffset =
  //                   _chatController.scrollController.offset;
  //               double oldMaxExtent =
  //                   _chatController.scrollController.position.maxScrollExtent;

  //               print('Load newer Data');
  //               if (page == 1) {
  //                 print('No more data to load');
  //                 isLoading = false;
  //                 return;
  //               }
  //               // var messages = await chats.findByDateRange(
  //               //   previousStartLoadedAt!,
  //               //   previousEndLoadedAt!,
  //               // );

  //               var messages = await chats.findByPage(page, windowSize);
  //               print("page: $page");

  //               print("messages: $messages");

  //               if (messages.isNotEmpty) {
  //                 messagePerPage["page$page"] = {
  //                   "count": messages.length,
  //                   "start_id": messages.first["id"],
  //                   "end_id": messages.last["id"],
  //                 };
  //                 _chatController.initialMessageList.addAll(messages.map((e) {
  //                   return Message.fromJson(e);
  //                 }).toList());

  //                 if (_chatController.initialMessageList.length > windowSize) {
  //                   deletePageData(page + (pageinmemory ~/ 2) + 1);

  //                   oldestLoadedAt = _chatController.initialMessageList.first
  //                       .createdAt; //start time when again sccrolling down
  //                 }
  //                 _chatController.messageStreamController
  //                     .add(_chatController.initialMessageList);
  //                 newestLoadedAt = DateTime.tryParse(messages
  //                     .first["createdAt"]); // last point of time to scroll
  //                 print("newestLoadedAt: $newestLoadedAt");
  //                 print("oldestLoadedAt: $oldestLoadedAt");
  //                 WidgetsBinding.instance.addPostFrameCallback((_) {
  //                   // if (_chatController.scrollController.hasClients) {
  //                   //   _chatController.scrollController.jumpTo(
  //                   //     previousPosition - (messages.length * 70),
  //                   //   );
  //                   // }

  //                   double newMaxExtent = _chatController
  //                       .scrollController.position.maxScrollExtent;
  //                   double delta = newMaxExtent - oldMaxExtent;

  //                   // Adjust scroll position without animation
  //                   _chatController.scrollController.jumpTo(oldScrollOffset);
  //                 });
  //               }
  //               isLoading = false;
  //             },
            