import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/personal_chat_screen.dart';
import 'package:chitchat/services/personal_chat_service.dart';
import 'package:flutter/material.dart';

class LastMessageInfo {
  final String id;
  final String text;
  final String sentBy;
  final String messageType;
  final dynamic timestamp;

  LastMessageInfo({
    required this.id,
    required this.text,
    required this.sentBy,
    required this.messageType,
    required this.timestamp,
  });

  factory LastMessageInfo.fromChat(Map<String, dynamic> chat) {
    final rawMsg = chat['lastMessage'];
    if (rawMsg is Map) {
      final msgMap = Map<String, dynamic>.from(rawMsg);
      return LastMessageInfo(
        id: msgMap['id']?.toString() ?? chat['_id']?.toString() ?? '',
        text: msgMap['message']?.toString() ?? '',
        sentBy: msgMap['sentBy']?.toString() ?? chat['senderId']?.toString() ?? '',
        messageType: msgMap['message_type']?.toString() ?? 'text',
        timestamp: msgMap['createdAt'] ?? chat['lastMessageAt'] ?? chat['updatedAt'],
      );
    } else if (rawMsg is String) {
      return LastMessageInfo(
        id: chat['lastMessageId']?.toString() ?? chat['_id']?.toString() ?? rawMsg,
        text: rawMsg,
        sentBy: chat['senderId']?.toString() ?? '',
        messageType: 'text',
        timestamp: chat['lastMessageAt'] ?? chat['updatedAt'],
      );
    } else {
      return LastMessageInfo(
        id: chat['_id']?.toString() ?? '',
        text: '',
        sentBy: chat['senderId']?.toString() ?? '',
        messageType: 'text',
        timestamp: chat['lastMessageAt'] ?? chat['updatedAt'],
      );
    }
  }
}

class PersonalChatListScreen extends StatefulWidget {
  const PersonalChatListScreen({Key? key}) : super(key: key);

  @override
  State<PersonalChatListScreen> createState() => _PersonalChatListScreenState();
}

class _PersonalChatListScreenState extends State<PersonalChatListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _activeChats = [];
  List<dynamic> _pendingRequests = [];
  Map<String, bool> _unseenMap = {};

  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await PersonalChatService.getPersonalChats();
      if (!mounted) return;

      if (res['success'] == true) {
        final active = res['activeChats'] as List<dynamic>? ?? [];
        final pending = res['pendingRequests'] as List<dynamic>? ?? [];

        final currentUserId = profileDetails?['_id']?.toString() ?? '';
        Map<String, bool> unseen = {};

        for (var rawChat in [...active, ...pending]) {
          if (rawChat is! Map) continue;
          final chat = Map<String, dynamic>.from(rawChat);
          final pairKey = chat['pairKey']?.toString() ?? '';
          final info = LastMessageInfo.fromChat(chat);

          if (info.id.isNotEmpty) {
            // Only mark unseen if the last message was NOT sent by current user
            if (info.sentBy.isNotEmpty && info.sentBy != currentUserId) {
              final isUnseen = await PersonalChatService.isChatUnseen(
                pairKey,
                info.id,
              );
              unseen[pairKey] = isUnseen;
            } else {
              unseen[pairKey] = false;
            }
          } else {
            unseen[pairKey] = false;
          }
        }

        // If there are pending requests and no active chats, automatically focus Requests tab
        if (active.isEmpty && pending.isNotEmpty && _tabController.index == 0) {
          _tabController.animateTo(1);
        }

        setState(() {
          _activeChats = active;
          _pendingRequests = pending;
          _unseenMap = unseen;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['error'] ?? 'Failed to load chats';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error in _loadChats: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading chats: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '';
    try {
      DateTime dt;
      if (rawTime is String) {
        dt = DateTime.tryParse(rawTime) ?? DateTime.now();
      } else if (rawTime is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(rawTime);
      } else {
        return '';
      }

      // Convert UTC to local device timezone
      dt = dt.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dt.year, dt.month, dt.day);
      final differenceInDays = today.difference(messageDate).inDays;

      if (differenceInDays == 0) {
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        return hour.toString() + ':' + minute + ' ' + ampm;
      } else if (differenceInDays == 1) {
        return 'Yesterday';
      } else if (differenceInDays < 7 && differenceInDays > 0) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return days[dt.weekday - 1];
      } else {
        return dt.day.toString() + '/' + dt.month.toString();
      }
    } catch (_) {
      return '';
    }
  }

  void _openChat(Map<String, dynamic> chat) async {
    final pairKey = chat['pairKey']?.toString() ?? '';
    final otherUser = chat['otherUser'] is Map
        ? Map<String, dynamic>.from(chat['otherUser'])
        : <String, dynamic>{};
    final otherUserId = otherUser['_id']?.toString() ?? '';
    final otherUserName = otherUser['name']?.toString() ?? 'User';
    final otherUserPic = otherUser['profilePic']?.toString();

    final info = LastMessageInfo.fromChat(chat);
    if (info.id.isNotEmpty) {
      await PersonalChatService.markChatAsSeen(
        pairKey,
        info.id,
      );
      setState(() {
        _unseenMap[pairKey] = false;
      });
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalChatScreen(
          pairKey: pairKey,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserPic: otherUserPic,
        ),
      ),
    );

    // Refresh chat list upon return to get updated messages
    _loadChats();
  }

  Widget _buildChatItem(Map<String, dynamic> chat, {bool isPending = false}) {
    final pairKey = chat['pairKey']?.toString() ?? '';
    final otherUser = chat['otherUser'] is Map
        ? Map<String, dynamic>.from(chat['otherUser'])
        : <String, dynamic>{};
    final otherUserName = otherUser['name']?.toString() ?? 'Unknown User';
    final otherUserPic = otherUser['profilePic']?.toString();

    final info = LastMessageInfo.fromChat(chat);
    final lastMsgText = info.text.isNotEmpty
        ? info.text
        : (isPending ? 'Chat request pending' : 'No messages yet');
    final timeStr = _formatTime(info.timestamp);

    final isUnseen = _unseenMap[pairKey] == true;

    String displaySubtitle = lastMsgText;
    if (info.messageType == 'image') {
      displaySubtitle = '📷 Photo';
    } else if (info.messageType == 'voice') {
      displaySubtitle = '🎤 Voice message';
    } else if (info.messageType == 'video') {
      displaySubtitle = '🎥 Video';
    }

    return InkWell(
      onTap: () => _openChat(chat),
      splashColor: Colors.tealAccent.withOpacity(0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.06),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFF232838),
                  backgroundImage: (otherUserPic != null && otherUserPic.isNotEmpty)
                      ? NetworkImage(otherUserPic)
                      : null,
                  child: (otherUserPic == null || otherUserPic.isEmpty)
                      ? Text(
                          otherUserName.isNotEmpty
                              ? otherUserName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                if (isPending)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hourglass_empty,
                        color: Colors.black,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherUserName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: isUnseen ? FontWeight.bold : FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isUnseen ? Colors.tealAccent : Colors.white38,
                          fontSize: 12,
                          fontWeight: isUnseen ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displaySubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isUnseen ? Colors.white : Colors.white60,
                            fontSize: 14,
                            fontWeight: isUnseen ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isUnseen) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: Colors.tealAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(List<dynamic> items, {bool isPending = false}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPending ? Icons.mark_email_read_outlined : Icons.chat_bubble_outline,
                size: 64,
                color: Colors.white24,
              ),
              const SizedBox(height: 16),
              Text(
                isPending ? 'No pending requests' : 'No personal chats yet',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPending
                    ? 'When someone replies to your tag or requests a chat, it will appear here.'
                    : 'Discover people on the radar or start a conversation from their profile!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.tealAccent,
      backgroundColor: const Color(0xFF1B1F2D),
      onRefresh: _loadChats,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item is! Map) return const SizedBox.shrink();
          final chat = Map<String, dynamic>.from(item);
          return _buildChatItem(chat, isPending: isPending);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF141722),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Chats',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Poppins',
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          indicatorWeight: 3,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chats'),
                  if (_activeChats.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _activeChats.length.toString(),
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Requests'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _pendingRequests.length.toString(),
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _loadChats,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChatList(_activeChats, isPending: false),
                    _buildChatList(_pendingRequests, isPending: true),
                  ],
                ),
    );
  }
}
