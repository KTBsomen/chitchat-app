import 'dart:async';

import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/notification.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

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

class NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final Function(String) onVote; // Callback for voting

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return widget.notification.type != 'joinGroup'
        ? const SizedBox.shrink()
        : Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: isDarkMode ? 8 : 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.Secondarybackground,
                // gradient: LinearGradient(
                //   begin: Alignment.topLeft,
                //   end: Alignment.bottomRight,
                //   colors: [Colors.black, Colors.grey[900]!],
                // ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and type indicator
                    _buildHeader(),
                    const SizedBox(height: 16),

                    // Main content area
                    _buildMainContent(),

                    // Voting section
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
              dbIndex: requestBody['dbIndex'],
              uid: requestBody['memberId'],
            ),
          ),
        );
      },
      child: Row(
        children: [
          // Profile image with online indicator
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

          // User details
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
                // _buildEducationInfo('School', requestBody['school']),
                // _buildEducationInfo('College', requestBody['college']),
                // _buildEducationInfo('University', requestBody['university']),
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
          authorName: widget.notification.requestBody['authorName'],
          profilePic: widget.notification.requestBody['profilePic'],
          likes: widget.notification.requestBody['likes'] ?? 0,
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
        // border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // "Progress" text row
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     Text(
          //       'Progress',
          //       style: TextStyle(
          //         fontSize: 14,
          //         color: Colors.grey[600],
          //         fontWeight: FontWeight.w500,
          //       ),
          //     ),
          //     Text(
          //       '${(_voteProgress * 100).toInt()}%',
          //       style: TextStyle(
          //         fontSize: 14,
          //         color: Colors.grey[600],
          //         fontWeight: FontWeight.w600,
          //       ),
          //     ),
          //   ],
          // ),
          // const SizedBox(height: 8),

          // Progress bar styled like a button
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
                // Centered text on top of progress bar
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

          // "x out of y members voted" text
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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  List<NotificationModel> _notifications = [];
  int _page = 1;
  int _limit = 10;
  int _total = 0;
  int _totalPages = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  FriendCircleGroup? myGroup;
  Map<String, dynamic>? myProfile;
  _getMyprofile() async {
    setState(() {
      _isLoading = true;
    });
    final result = await UserService.fetchMyProfile();

    if (result['success']) {
      print('Profile fetched successfully:');
      print(result['data']);
      myProfile = result['data'];
      setState(() {});

      if (result['group'] != null) {
        myGroup = result['group'] as FriendCircleGroup;
        setState(() {});
        print('Group Name: ${myGroup?.groupData['name']}');
        print('Members:');
        for (var member in myGroup!.members) {
          print('  - ${member.additionalData['memberName']}');
        }
      } else {
        print('No group found for this user.');
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
      print('Error fetching profile: ${result['error']}');
    }
    setState(() {});
  }

  void _getGroupJoinReqests() async {
    List<Map<String, dynamic>> jsonData =
        (await NotificationService.getGroupJoinRequests(
            context, myGroup!.groupId,
            showLoaders: false))!;
    print(jsonData);

    if (mounted) {
      setState(() {
        _notifications =
            jsonData.map((data) => NotificationModel.fromJson(data)).toList();
        _isLoading = false;
      });
    }
  }

  List _voted = [];
  void _onVote(String id) async {
    if (_voted.contains(id)) {
      return;
    }
    bool res = await NotificationService.vote(context, id);
    setState(() {
      _notifications = _notifications.map((n) {
        if (n.id == id && res) {
          return NotificationModel(
            id: n.id,
            type: n.type,
            requestBody: n.requestBody,
            votes: n.votes + 1,
            totalMembers: n.totalMembers,
            userId: n.userId,
          );
        }
        return n;
      }).toList();
    });
    _voted.add(id);
  }

  Timer? _notificationTimer;

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _getGroupJoinReqests();
      }
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    NotificationService.clearAllUnreadNotifications();
    _startNotificationTimer();
    _getMyprofile().then((_) {
      _getGroupJoinReqests();
    });
  }

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);
    try {
      _getGroupJoinReqests(); // replace with your API or DB fetch function
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        title: const Text('Notifications'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: Colors.white,
              backgroundColor: AppColors.primary,
              onRefresh: _refreshNotifications,
              child: _notifications.isEmpty
                  ? const SingleChildScrollView(
                      // required to allow pull-down gesture even when empty
                      physics: AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 500, // give some height to allow pull
                        child: Center(
                          child: Text(
                            'No notifications yet.',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification =
                            _notifications.reversed.toList()[index];
                        return NotificationCard(
                          notification: notification,
                          onVote: _onVote,
                        );
                      },
                    ),
            ),
    );
  }
}
