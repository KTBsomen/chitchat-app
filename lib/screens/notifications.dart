import 'dart:async';

import 'package:chitchat/appstate/joinRequestPrefs.dart';
import 'package:chitchat/appstate/notification_store.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/notification.dart';
import 'package:chitchat/services/notification_manager.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationModel — for group join/post voting requests
// ─────────────────────────────────────────────────────────────────────────────
class NotificationModel {
  final String id;
  final String type;
  final dynamic requestBody;
  final int votes;
  final int totalMembers;
  final String userId;

  NotificationModel({
    required this.id,
    required this.type,
    required this.requestBody,
    required this.votes,
    required this.totalMembers,
    required this.userId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['_id'],
      type: json['requestType'],
      requestBody: json['requestBody'],
      votes: json['votes']?.length ?? 0,
      totalMembers: json['groupDetails']?['members']?.length ?? 1,
      userId: json['userId'] ?? 'Unknown',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationCard — renders a single group join/post request card
// ─────────────────────────────────────────────────────────────────────────────
class NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final Function(String) onVote;

  const NotificationCard({
    Key? key,
    required this.notification,
    required this.onVote,
  }) : super(key: key);

  @override
  _NotificationCardState createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  late int votes;
  late int totalMembers;

  @override
  void initState() {
    super.initState();
    votes = widget.notification.votes;
    totalMembers = widget.notification.totalMembers;
  }

  void _handleVote() {
    setState(() {
      votes += 1;
    });
    widget.onVote(widget.notification.id);
  }

  String get _notificationTitle {
    switch (widget.notification.type) {
      case 'joinGroup':
        return "Group Join Request";
      case 'addPost':
        return "Make Post Public";
      default:
        return "New Notification";
    }
  }

  Color get _typeColor {
    switch (widget.notification.type) {
      case 'joinGroup':
        return Colors.blue;
      case 'addPost':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  double get _voteProgress {
    if (totalMembers == 0) return 0.0;
    return (votes / totalMembers).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return widget.notification.type != 'joinGroup'
        ? const SizedBox.shrink()
        : Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.Secondarybackground,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildMainContent(),
                    _buildVotingSection(),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _typeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.notification.type == 'joinGroup'
                    ? Icons.person_add
                    : Icons.public,
                size: 16,
                color: _typeColor,
              ),
              const SizedBox(width: 6),
              Text(
                _notificationTitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _typeColor,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Icon(
          Icons.notifications_active,
          size: 20,
          color: Colors.grey[400],
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (widget.notification.type == 'joinGroup') {
      return _buildJoinGroupContent();
    } else {
      return _buildPostContent();
    }
  }

  Widget _buildJoinGroupContent() {
    final requestBody = widget.notification.requestBody;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.fade,
            child: PublicProfilePage(
              dbIndex: requestBody['dbIndex'].toString(),
              uid: requestBody['memberId'],
            ),
          ),
        );
      },
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.network(
                    requestBody['memberProfilePic'] ??
                        'https://via.placeholder.com/80',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requestBody['memberName'] ?? 'Unknown User',
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildEducationInfo(
                    'Education Level', requestBody['educationLevel']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationInfo(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color.fromARGB(255, 222, 222, 222),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DynamicPostWidget(
          borderRadius: 12,
          content: widget.notification.requestBody['content'],
          media: List<Map<String, dynamic>>.from(
            (widget.notification.requestBody['media'] as List<dynamic>? ?? [])
                .map((m) => {
                      'type': m['type'],
                      'url': m['url'],
                    }),
          ),
          postId: widget.notification.requestBody['id'] ?? '',
          author: widget.notification.requestBody['author'],
          group: widget.notification.requestBody['group'] ?? '',
          isGroupPost: widget.notification.requestBody['isGroupPost'] ?? false,
          authorName: widget.notification.requestBody['authorName'],
          profilePic: widget.notification.requestBody['profilePic'],
          likes: widget.notification.requestBody['likes'] ?? 0,
          comments: widget.notification.requestBody['comments'] ?? 0,
        ),
      ),
    );
  }

  Widget _buildVotingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: _handleVote,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _voteProgress,
                    minHeight: 50,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _voteProgress > 0.5 ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                Text(
                  'Tapin ($votes)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black45,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$votes out of $totalMembers members voted',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JoinRequestStatusCard — shows the user's own outgoing request status
// ─────────────────────────────────────────────────────────────────────────────
class JoinRequestStatusCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const JoinRequestStatusCard({Key? key, required this.request})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final groupName = request['groupName'] ?? 'Unknown Group';
    final votes = request['votes'] ?? 0;
    final totalMembers = request['totalMembers'] ?? 1;
    final status = request['status'] ?? 'pending';
    final progress =
        totalMembers > 0 ? (votes / totalMembers).clamp(0.0, 1.0) : 0.0;

    // Parse expiry
    String expiryText = '';
    final expiresAt = request['expiresAt'] as String?;
    if (expiresAt != null) {
      try {
        final expiry = DateTime.parse(expiresAt);
        final remaining = expiry.difference(DateTime.now());
        if (remaining.isNegative) {
          expiryText = 'Expired';
        } else if (remaining.inHours > 0) {
          expiryText = '${remaining.inHours}h remaining';
        } else {
          expiryText = '${remaining.inMinutes}m remaining';
        }
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.Secondarybackground,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send, size: 14, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('My Request',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue)),
                    ],
                  ),
                ),
                const Spacer(),
                if (expiryText.isNotEmpty)
                  Text(expiryText,
                      style: TextStyle(
                          fontSize: 11,
                          color: expiryText == 'Expired'
                              ? Colors.red
                              : Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 12),

            // Group name
            Text(
              groupName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Vote progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 28,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(
                  status == 'approved'
                      ? Colors.green
                      : progress > 0.5
                          ? Colors.green
                          : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Vote count text
            Text(
              status == 'approved'
                  ? '✅ Approved! You\'re in!'
                  : '$votes / $totalMembers votes',
              style: TextStyle(
                fontSize: 12,
                color: status == 'approved' ? Colors.green : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsScreen — main screen with Personal / Group tabs
// ─────────────────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<NotificationModel> _groupNotifications = [];
  List<Map<String, dynamic>> _personalNotifications = [];
  List<Map<String, dynamic>> _myJoinRequests = [];

  FriendCircleGroup? myGroup;
  Map<String, dynamic>? myProfile;
  late TabController _tabController;

  // Unread counts per tab
  int _personalUnread = 0;
  int _groupUnread = 0;

  /// Auto-poll interval (configurable).
  static const Duration _pollInterval = Duration(seconds: 60);
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadData();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    await NotificationStore.init();
    await JoinRequestPrefs.init();

    // Fetch profile + group
    await _getMyprofile();

    // Fetch new notifications from server (stores locally)
    await NotificationService.getNotifications(context, showLoaders: false);

    // Fetch group join requests if user has a group
    if (myGroup != null && myGroup!.groupId != 'defaultGroup') {
      await _fetchGroupJoinRequests();
    }

    // Fetch my outgoing join request statuses
    await _fetchMyJoinRequestStatuses();

    // Load stored notifications for display
    _loadFromStore();

    setState(() => _isLoading = false);
  }

  _getMyprofile() async {
    final result = await UserService.fetchMyProfile();

    if (result['success']) {
      myProfile = result['data'];
      if (result['group'] != null) {
        myGroup = result['group'] as FriendCircleGroup;
      } else {
        myGroup = FriendCircleGroup(
          groupId: 'defaultGroup',
          groupData: {'name': 'Default Group'},
          members: [],
        );
      }
    } else {
      myGroup = FriendCircleGroup(
        groupId: 'defaultGroup',
        groupData: {'name': 'Default Group'},
        members: [],
      );
    }
  }

  Future<void> _fetchGroupJoinRequests() async {
    final jsonData = await NotificationService.getGroupJoinRequests(
        context, myGroup!.groupId,
        showLoaders: false);
    if (jsonData != null && mounted) {
      _groupNotifications =
          jsonData.map((data) => NotificationModel.fromJson(data)).toList();
    }
  }

  Future<void> _fetchMyJoinRequestStatuses() async {
    final requestIds = JoinRequestPrefs.getAllRequestIds();
    if (requestIds.isEmpty) {
      _myJoinRequests = [];
      return;
    }

    final results =
        await NotificationService.checkJoinRequestStatuses(requestIds);

    // Update prefs with server data (removes expired/missing)
    await JoinRequestPrefs.updateStatuses(results, requestIds);

    // Get updated pending list
    _myJoinRequests = JoinRequestPrefs.getAllPending();
  }

  void _loadFromStore() {
    final allStored = NotificationStore.getAll();

    // Personal = source type 'redis'
    _personalNotifications =
        allStored.where((n) => n['sourceType'] == 'redis').toList();

    // Count unreads per tab
    _personalUnread =
        _personalNotifications.where((n) => n['isRead'] == false).length;
    _groupUnread = allStored
        .where((n) => n['sourceType'] == 'api' && n['isRead'] == false)
        .length;
  }

  List _voted = [];
  void _onVote(String id) async {
    if (_voted.contains(id)) return;

    bool res = await NotificationService.vote(context, id, onRefresh: () {
      _loadData();
    });
    if (res) {
      _voted.add(id);
      // Mark as read in store
      await NotificationStore.markAsRead(id);
      if (mounted) {
        _loadFromStore();
        setState(() {});
      }
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadData();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            _buildTab('Personal', _personalUnread),
            _buildTab('Group', _groupUnread),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalTab(),
                _buildGroupTab(),
              ],
            ),
    );
  }

  /// Tab with optional red badge dot
  Widget _buildTab(String label, int unreadCount) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Personal Tab ─────────────────────────────────────────────────────

  Widget _buildPersonalTab() {
    final hasJoinRequests = _myJoinRequests.isNotEmpty;
    final hasPersonal = _personalNotifications.isNotEmpty;

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.primary,
      onRefresh: _refreshNotifications,
      child: (!hasJoinRequests && !hasPersonal)
          ? const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 500,
                child: Center(
                  child: Text('No notifications yet.',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // ── My Join Requests section ──
                if (hasJoinRequests) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'My Join Requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._myJoinRequests.map((r) => GestureDetector(
                        onTap: () {
                          final groupId = r['groupId'] as String?;
                          if (groupId != null && groupId.isNotEmpty) {
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.rightToLeft,
                                child: GroupPublicViewScreen(groupId: groupId),
                              ),
                            );
                          }
                        },
                        child: JoinRequestStatusCard(request: r),
                      )),
                  const Divider(
                      color: Colors.white12,
                      indent: 16,
                      endIndent: 16,
                      height: 24),
                ],

                // ── Personal Notifications ──
                ..._personalNotifications.map((n) {
                  final id = n['id'] as String? ?? '';
                  final isUnread = n['isRead'] == false;
                  final appNotif = AppNotification.fromStoreMap(n);

                  return Dismissible(
                    key: ValueKey(id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.white, size: 28),
                    ),
                    onDismissed: (_) async {
                      await NotificationStore.removeNotification(id);
                      NotificationManager.instance.refreshCount();
                      _loadFromStore();
                      if (mounted) setState(() {});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification dismissed'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: _buildPersonalNotifTile(appNotif, isUnread, id),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildPersonalNotifTile(
      AppNotification notif, bool isUnread, String id) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: isUnread
            ? Border.all(color: Colors.tealAccent.withOpacity(0.35), width: 1)
            : null,
        color: isUnread
            ? Colors.tealAccent.withOpacity(0.08)
            : Colors.white.withOpacity(0.03),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: notif.icon != null
            ? GestureDetector(
                onTap: () {
                  if (notif.type == "post_like" && notif.data != null) {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.fade,
                        child: PublicProfilePage(
                          dbIndex: notif.data!['dbIndex']?.toString() ?? "x",
                          uid: notif.data!['author'],
                        ),
                      ),
                    );
                  }
                },
                child: ClipOval(
                  child: Image.network(
                    notif.icon!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[800],
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 24),
                    ),
                  ),
                ),
              )
            : const Icon(Icons.notifications, color: Colors.white54),
        trailing: isUnread
            ? Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.tealAccent,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        title: Text(
          notif.title ?? "Notification",
          style: TextStyle(
            color: isUnread ? Colors.white : Colors.white60,
            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
            fontSize: isUnread ? 15 : 14,
          ),
        ),
        subtitle: Text(
          notif.body ?? "",
          style: TextStyle(
            color: isUnread ? Colors.white70 : Colors.white38,
          ),
        ),
        onTap: () async {
          // Mark as read on tap
          if (isUnread && id.isNotEmpty) {
            await NotificationManager.instance.markAsRead(id);
            _loadFromStore();
            if (mounted) setState(() {});
          }

          if (notif.link != null) {
            // Handle deep link or navigation
          }
        },
      ),
    );
  }

  // ── Group Tab ────────────────────────────────────────────────────────

  Widget _buildGroupTab() {
    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.primary,
      onRefresh: _refreshNotifications,
      child: _groupNotifications.isEmpty
          ? const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 500,
                child: Center(
                  child: Text('No group notifications yet.',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _groupNotifications.length,
              itemBuilder: (context, index) {
                return NotificationCard(
                  notification: _groupNotifications[index],
                  onVote: _onVote,
                );
              },
            ),
    );
  }
}
