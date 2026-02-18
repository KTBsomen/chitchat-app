import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/components/bottomnav.dart';
import 'package:chitchat/components/comments.dart';
import 'package:chitchat/components/createPost.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/memoryviewer.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/components/videoWidget.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/profilePrivet.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/userOnline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vs_media_picker/vs_media_picker.dart';

// Import the LikeButton widget
import 'package:chitchat/components/like.dart';

class GroupPrivateViewScreen extends StatefulWidget {
  final bool? fromRegister;
  const GroupPrivateViewScreen({super.key, this.fromRegister});
  @override
  _GroupPrivateViewScreenState createState() => _GroupPrivateViewScreenState();
}

class MemoryItem {
  final String id;
  final String url;
  final MessageType type;
  final String author;
  final String group;
  final int dbIndex;
  final String authorName;
  final String profilePic;
  final DateTime createdAt;
  bool _isPublic;

  MemoryItem({
    required this.id,
    required this.url,
    required this.type,
    required this.author,
    required this.group,
    required this.dbIndex,
    required this.authorName,
    required this.profilePic,
    required this.createdAt,
    bool isPublic = false,
  }) : _isPublic = isPublic;

  bool get isPublic => _isPublic;
  set isPublic(bool value) {
    _isPublic = value;
  }
}

class _GroupPrivateViewScreenState extends State<GroupPrivateViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ScrollController? _sheetScrollController;

  final List<dynamic> posts = [];
  final Map<String, bool> likeStatus = {};
  final Map<String, int> likeCountForMember = {};
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');
  FriendCircleGroup? groupDetails;

  int selectedTab = 0;
  String? expandedMemberId; // Track which member's bio is expanded

  int windowSize = 20;
  int pageinmemories = 2;
  FriendCircleGroup? userGroup;
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? myProfile;
  Timer? _refreshTimer;

  final ScrollController _scrollController = ScrollController();
  String? next;
  bool isLoadingPost = false;
  bool hasMore = true;
  bool isLoadingMore = false;
  bool isLoadingGroup = true;
  bool isInWatchList = false;
  bool isWatchListLoading = false;
  bool isJoinLoading = false;
  List<MemoryItem> remoteMemories = [];
  String? nextPageCursor;
  bool isLoading = false;

  Future<void> _fetchMemories({bool refresh = false}) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      Map<String, dynamic> data = await PostService.fetchMyGroupMemories(
          groupId: groupDetails!.groupId, limit: 10, next: nextPageCursor);

      if (data['success']) {
        final List<dynamic> fetched = data["data"]['_memories'];
        List<MemoryItem> newRemoteMemories = fetched.map((item) {
          String url = item['media'][0]['url'];
          String type = item['media'][0]['type'];
          final isVideo = type.contains("video");
          return MemoryItem(
            id: item['_id'] ?? '',
            url: url.toString(),
            type: isVideo ? MessageType.video : MessageType.image,
            author: item['author'] ?? '',
            group: item['group'] ?? '',
            dbIndex: item['dbIndex'] ?? 0,
            authorName: item['authorName'] ?? '',
            profilePic: item['profilePic'] ?? '',
            createdAt:
                DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
            isPublic: item['public'] ?? false,
          );
        }).toList();

        // Deduplicate by id
        final existingIds = remoteMemories.map((m) => m.id).toSet();
        newRemoteMemories = newRemoteMemories
            .where((m) => !existingIds.contains(m.id))
            .toList();

        setState(() {
          if (refresh) remoteMemories.clear();
          remoteMemories.addAll(newRemoteMemories);
          nextPageCursor = data["next"];
          hasMore = data["next"] != null;
        });
      }
    } catch (e) {
      print("Error fetching memories: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<MemoryItem> get allMemories {
    return remoteMemories;
  }

  void _handleProfileUpdate(Map<String, dynamic>? data) {
    if (mounted) {
      setState(() {
        groupDetails = GroupsService.buildFriendCircleGroup(data!['myGroup']);
      });
    }
  }

  void _handlePostUpdate(value) {
    print("Posts updated from AppVariables listener $value");
    if (mounted) {
      setState(() {
        posts.insert(0, value);
      });
    }
  }

  void _handleMemoryUpdate(value) {
    print("Memories updated from AppVariables listener $value");
    if (mounted) {
      setState(() {
        remoteMemories.insert(
            0,
            MemoryItem(
              id: value['_id'] ?? '',
              url: value['media'][0]['url'],
              type: value['media'][0]['type'].contains("video")
                  ? MessageType.video
                  : MessageType.image,
              author: value['author'] ?? '',
              group: value['group'] ?? '',
              dbIndex: value['dbIndex'] ?? 0,
              authorName: value['authorName'] ?? '',
              profilePic: value['profilePic'] ?? '',
              createdAt:
                  DateTime.tryParse(value['createdAt'] ?? '') ?? DateTime.now(),
              isPublic: value['public'] ?? false,
            ));
      });
    }
  }

  void _handlePostDelete(value) {
    print("Post deleted from AppVariables listener: $value");
    if (mounted) {
      setState(() {
        posts.removeWhere((post) => post['_id'] == value);
      });
    }
  }

  void shareGroupInvitation() {
    SharePlus.instance.share(ShareParams(
      title: "ChitChat Group Invitation",
      text:
          'Join our group ${groupDetails?.groupData['name']}!\n\n https://groups.chitzchat.com/join?group=${groupDetails!.groupId}',
      subject: 'Join my group on ChitChat!',
    ));
  }

  @override
  void initState() {
    super.initState();
    try {
      if (widget.fromRegister != null && widget.fromRegister == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          shareGroupInvitation();
        });
      }
    } catch (e) {
      print("Error in shareing group invitation : $e");
    }
    print(profileDetails);
    groupDetails =
        GroupsService.buildFriendCircleGroup(profileDetails!['myGroup']);
    _getUserLikes();
    _tabController = TabController(length: 2, vsync: this);
    AppVariables.registerState(this);
    AppVariables.addListener("profile", _handleProfileUpdate);
    AppVariables.addListener("group_posts", _handlePostUpdate);
    AppVariables.addListener("memories", _handleMemoryUpdate);
    AppVariables.addListener("deleted_posts", _handlePostDelete);
    _tabController.addListener(() {
      setState(() {
        selectedTab = _tabController.index;
      });
    });
    _fetchPosts();
    _fetchMemories();
    _fetchUserStatus();
    _startRandomRefreshTimer();
  }

  void _fetchUserStatus() async {
    final ids = groupDetails!.members.map((e) => e.id).toList();

    try {
      final result = await PresenceManager().fetchMembersStatus(userIds: ids);
      print("Presence Data: $result");

      if (result['success'] != true || result['data'] == null) {
        throw Exception('Failed to get user status');
      }

      final List<dynamic> data = result['data'];

      if (!mounted) return;

      setState(() {
        for (var member in groupDetails!.members) {
          final presence = data.firstWhere(
            (entry) => entry['userId'] == member.id,
            orElse: () => null,
          );

          if (presence != null) {
            member.status = presence['status'] ?? 'offline';
            member.lastSeen = presence['timestamp'].toString();
          } else {
            member.status = 'offline';
            member.lastSeen = null;
          }
        }
      });
    } catch (e) {
      print("Failed to fetch presence data: $e");
    }
  }

  void _startRandomRefreshTimer() {
    _refreshTimer?.cancel();

    void scheduleNext() {
      final random = Random();
      final seconds = 60 + random.nextInt(61);
      print("Next presence refresh in $seconds seconds");

      _refreshTimer = Timer(Duration(seconds: seconds), () async {
        _fetchUserStatus();
        scheduleNext();
      });
    }

    scheduleNext();
  }

  void _sheetScrollListener() {
    if (_sheetScrollController!.position.pixels >=
        _sheetScrollController!.position.maxScrollExtent - 200) {
      if (selectedTab == 0) {
        if (!isLoadingPost && hasMore) {
          _fetchPosts();
        }
      } else {
        if (hasMore && !isLoading) {
          _fetchMemories();
        }
      }
    }
  }

  void _fetchPosts() async {
    if (isLoadingPost) return;
    setState(() {
      isLoadingPost = true;
    });
    Map<String, dynamic> result = await PostService.fetchMyGroupPosts(
      groupId: groupDetails!.groupId,
      limit: 10,
      next: next,
    );
    if (result['success']) {
      print(result);

      next = result['data']['next'];
      final newPosts = result['data']['posts'] as List;
      final existingIds = posts.map((p) => p['_id']).toSet();
      posts.addAll(newPosts.where((p) => !existingIds.contains(p['_id'])));
      setState(() {
        isLoadingPost = false;
        hasMore = next != null;
      });
    } else {
      print(result);
      setState(() {
        isLoadingPost = false;
      });
    }
  }

  void updatePublicPostStatus(postid) {
    posts.map((e) {
      if (e['_id'] == postid) {
        e['public'] = !e['public'];
      }
      return e;
    });
    setState(() {});
  }

  void _getUserLikes() async {
    var _userLikes = await AppVariables.getPersistent<Map<String, bool>>(
        'likeStatusForMember');
    if (_userLikes != null) {
      setState(() {
        likeStatus.addAll(_userLikes);
      });
    }
    List<String>? ids =
        groupDetails?.members.map((member) => member.id).toList();
    Map<String, dynamic> result =
        await UserService.fetchUserLikes(ids: ids!, invalidate: true);
    if (result['success']) {
      for (var user in result['data']) {
        likeCountForMember[user['_id']] = user['likes'];
      }
    }
    setState(() {});
  }

  void toggleLike(String userid) async {
    // Store original state before optimistic update
    final bool originalLikeStatus = likeStatus[userid] ?? false;
    final int originalLikeCount = likeCountForMember[userid] ?? 0;

    print(
        "likeStatusForMember>>${await AppVariables.getPersistent<Map<String, dynamic>>('likeStatusForMember')}");
    setState(() {
      likeStatus[userid] = !originalLikeStatus;
      likeCountForMember[userid] =
          (originalLikeCount + (likeStatus[userid]! ? 1 : -1)) < 0
              ? 0
              : (originalLikeCount + (likeStatus[userid]! ? 1 : -1));
    });
    AppVariables.setPersistent<Map<String, bool>>(
        'likeStatusForMember', likeStatus);
    print(likeStatus);

    Map<String, dynamic> result = await UserService.likeUser(userId: userid);
    print(result);
    if (result['success']) {
      print(result['data']);
      if (result['status'] == 201) {
        AppVariables.setPersistent<Map<String, bool>>(
            'likeStatusForMember', likeStatus);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liked')),
          );
        }
      } else if (result['status'] == 200) {
        if (mounted) {
          AppVariables.setPersistent<Map<String, bool>>(
              'likeStatusForMember', likeStatus);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('like removed')),
          );
        }
      }
    } else {
      // Revert to original state on failure
      setState(() {
        likeStatus[userid] = originalLikeStatus;
        likeCountForMember[userid] = originalLikeCount;
      });
      AppVariables.setPersistent<Map<String, bool>>(
          'likeStatusForMember', likeStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
    }
  }

  _editgroup(BuildContext context) async {
    String groupName = groupDetails!.groupData['name'];
    File? logoFile;
    bool isNameEmpty = false;
    bool isSubmitted = false;
    S3Uploader? uploader;
    TextEditingController groupNameController = TextEditingController();
    groupNameController.text = groupName;
    String baseurl =
        AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
    ValueNotifier<FileUploadProgress> _progressNotifier =
        ValueNotifier<FileUploadProgress>(
      FileUploadProgress(fileName: 'Uploading...'),
    );
    uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: _progressNotifier,
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (BuildContext context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.group_add, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Edit Group',
                  style: TextStyle(
                      fontSize: 18,
                      color: AppColors.background,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: groupNameController,
                        decoration: InputDecoration(
                          labelText: 'New Group Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.group),
                        ),
                        onChanged: (value) {
                          setState(() {
                            groupName = value;
                            isNameEmpty = false;
                          });
                        },
                      ),
                      Visibility(
                        visible: isNameEmpty,
                        child: const Text(
                          "Group Name must be filled",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  isSubmitted
                      ? Visibility(
                          visible: isSubmitted,
                          child: UploadProgressWidget(
                              progressNotifier: _progressNotifier))
                      : InkWell(
                          onTap: () async {
                            final ImagePicker _picker = ImagePicker();
                            final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image != null) {
                              logoFile = File(image.path);
                              setState(() {});
                            }
                          },
                          child: Container(
                            height: 100,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue,
                              ),
                            ),
                            child: logoFile == null
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate,
                                            size: 40, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('Choose new Logo'),
                                      ],
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      logoFile!,
                                      fit: BoxFit.fitHeight,
                                    ),
                                  ),
                          ),
                        ),
                ],
              ),
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: isSubmitted
                    ? null
                    : () async {
                        if (groupName.length > 0) {
                          print(groupName);
                          setState(() {
                            isNameEmpty = false;
                            isSubmitted = true;
                          });
                          List<String> url = [
                            groupDetails!.groupData['GroupProfilePic']
                          ];
                          if (logoFile != null) {
                            url = await uploader!.uploadFiles(files: [
                              logoFile!
                            ], compressionParams: {
                              "width": 400,
                              "quality": 100,
                            });
                          }
                          print(url);
                          Map<String, dynamic> result =
                              await GroupsService.updateGroup(
                                  groupId: groupDetails!.groupId,
                                  dbIndex: groupDetails!.groupData['dbIndex'],
                                  groupNames: groupName,
                                  groupPics: url[0]);
                          print(result);
                          if (result['success'] == true) {
                            if (mounted) {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                            groupDetails = GroupsService.buildFriendCircleGroup(
                                result['data']);
                            setState(() {});
                          } else {
                            _progressNotifier.value =
                                _progressNotifier.value.copyWith(
                              stage: UploadStage.failed,
                              customStageText: "Error Editing Group",
                              customStageTextDetail:
                                  "Only one group can be created at a time",
                              errorMessage: result['error'],
                            );
                          }
                        } else {
                          setState(() {
                            isNameEmpty = true;
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save Edits',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _scrollController.dispose();

    AppVariables.unregisterState(this);
    AppVariables.removeListener("profile", _handleProfileUpdate);
    AppVariables.removeListener("group_posts", _handlePostUpdate);
    AppVariables.removeListener("memories", _handleMemoryUpdate);
    AppVariables.removeListener("deleted_posts", _handlePostDelete);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 12, 38),
      extendBody: true,
      bottomNavigationBar: AppBottomNav(),
      appBar: AppBar(
        leading: null,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 3,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                barrierDismissible: true,
                pageBuilder: (BuildContext context, _, __) {
                  return ZoomableImagePopup(
                    imageUrl: groupDetails!.groupData['GroupProfilePic'],
                    onEdit: () => _editgroup(context),
                    onClose: () => Navigator.of(context).pop(),
                  );
                },
              ),
            );
          },
          onLongPress: () => _editgroup(context),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(
                    groupDetails?.groupData['GroupProfilePic']),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupDetails?.groupData['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          NotificationIcon(
            icon: Icons.notifications,
            type: NotificationIconType.Notification,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              switch (value) {
                case 'share':
                  SharePlus.instance.share(ShareParams(
                    title: "ChitChat Group Invitation",
                    text:
                        'Join our group ${groupDetails?.groupData['name']}!\n\n https://groups.chitzchat.com/join?group=${groupDetails!.groupId}',
                    subject: 'Join my group on ChitChat!',
                  ));
                  break;
                case 'leave':
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Leave Group'),
                        content: const Text(
                            'Are you sure you want to leave this group?'),
                        actions: [
                          TextButton(
                            child: const Text('Cancel'),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: const Text('Leave'),
                            onPressed: () async {
                              await GroupsService.leaveGroup(
                                  groupDetails!.groupId);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    },
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share Group'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('Leave Group'),
                ),
              ),
            ],
          )
        ],
      ),
      body: Stack(
        children: [
          // Modern Members List
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: groupDetails!.members.length,
              itemBuilder: (context, index) {
                final member = groupDetails!.members[index];
                final isExpanded = expandedMemberId == member.id;
                final List<dynamic> rawBios =
                    member.additionalData['memberBio'] as List;

                final Map<String, UserBio> latestBioByUser = {};

                for (final bioEntry in rawBios) {
                  final parsedBio = GroupsService.parseBio(bioEntry);

                  if (parsedBio.editedBy != null &&
                      parsedBio.editedBy!.isNotEmpty) {
                    // This overwrites older entries → keeps the LAST one
                    latestBioByUser[parsedBio.editedBy!] = parsedBio;
                  }
                }

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (member.id == profileDetails!['uid']) {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: PrivetProfilePage(),
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: PublicProfilePage(
                              dbIndex:
                                  member.additionalData['dbIndex'].toString(),
                              uid: member.id,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors
                              .transparent, // const Color.fromARGB(255, 20, 20, 50),
                          borderRadius: BorderRadius.circular(12),
                          // border: Border.all(
                          //   color: isExpanded
                          //       ? Colors.blue.withOpacity(0.5)
                          //       : Colors.transparent,
                          //   width: 2,
                          // ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Avatar with status
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundImage:
                                          NetworkImage(member.avatarUrl),
                                    ),
                                    if (member.status != null)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: member.status == 'online'
                                                ? Colors.green
                                                : member.status == 'offline'
                                                    ? Colors.grey
                                                    : Colors.orange,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color.fromARGB(
                                                  255, 20, 20, 50),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Name and bio toggle
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.additionalData['memberName'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isExpanded) {
                                              expandedMemberId = null;
                                            } else {
                                              expandedMemberId = member.id;
                                            }
                                          });
                                        },
                                        child: Row(
                                          children: [
                                            const Text(
                                              'bio',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Like button
                                LikeButton(
                                  buttonType: ButtonType.user,
                                  postId: member.id,
                                  initialLikes:
                                      likeCountForMember[member.id] ?? 0,
                                  initiallyLiked:
                                      likeStatus[member.id] ?? false,
                                  showLikeCount: true,
                                  onLikeChanged: (isLiked) async {
                                    toggleLike(member.id);
                                    return true;
                                  },
                                ),
                              ],
                            ),

                            // Expanded bio section
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(
                                    top: 12,
                                    left: MediaQuery.of(context).size.width *
                                        0.15),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 30, 30, 60),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (member
                                                .additionalData['memberBio'] !=
                                            null &&
                                        member.additionalData['memberBio']
                                            is List &&
                                        member.additionalData['memberBio']
                                            .isNotEmpty)
                                      // ...member.additionalData['memberBio']
                                      //     .map<Widget>((bioEntry) {
                                      ...latestBioByUser.values
                                          .map<Widget>((parsedBio) {
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color.fromARGB(
                                                255, 25, 25, 55),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Wrap(
                                            children: [
                                              RichText(
                                                  text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: parsedBio.editedBy ??
                                                        '',
                                                    style: const TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  WidgetSpan(
                                                      child:
                                                          SizedBox(width: 6)),
                                                  TextSpan(
                                                    text: parsedBio.bio ?? '',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                    ),
                                                  )
                                                ],
                                              )),
                                            ],
                                          ),
                                        );
                                      }).toList()
                                    else
                                      const Text(
                                        'No bio yet',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          _showAddBioDialog(member);
                                        },
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        label: const Text(
                                          'Add Bio',
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              crossFadeState: isExpanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 300),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // DraggableScrollableSheet
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              scrollController.addListener(() {
                if (scrollController.position.pixels >=
                    scrollController.position.maxScrollExtent - 200) {
                  if (selectedTab == 0) {
                    if (!isLoadingPost && hasMore) {
                      _fetchPosts();
                    }
                  } else {
                    if (hasMore && !isLoading) {
                      _fetchMemories();
                    }
                  }
                }
              });
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width * 0.8,
                            decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                border:
                                    Border.all(color: Colors.grey, width: 0.5),
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(50)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.5),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ]),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    _tabController.animateTo(0);
                                    setState(() {
                                      selectedTab = 0;
                                    });
                                  },
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.4,
                                    height: 50,
                                    decoration: selectedTab == 0
                                        ? const BoxDecoration(
                                            color:
                                                Color.fromARGB(255, 0, 46, 124),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(50),
                                              bottomLeft: Radius.circular(50),
                                              topRight: Radius.circular(50),
                                            ))
                                        : null,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Text(
                                            'posts',
                                            style: TextStyle(
                                              color: selectedTab == 0
                                                  ? Colors.blue
                                                  : Colors.grey,
                                              fontSize: 13,
                                              fontFamily: "Poppins",
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    _tabController.animateTo(1);
                                    setState(() {
                                      selectedTab = 1;
                                    });
                                  },
                                  child: Container(
                                    width: MediaQuery.of(context).size.width *
                                            0.4 -
                                        1,
                                    height: 50,
                                    decoration: selectedTab == 1
                                        ? const BoxDecoration(
                                            color:
                                                Color.fromARGB(255, 0, 46, 124),
                                            borderRadius: BorderRadius.only(
                                              topRight: Radius.circular(50),
                                              bottomRight: Radius.circular(50),
                                              topLeft: Radius.circular(50),
                                            ))
                                        : null,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Text(
                                            'memories',
                                            style: TextStyle(
                                              color: selectedTab == 1
                                                  ? Colors.blue
                                                  : Colors.grey,
                                              fontSize: 13,
                                              fontFamily: "Poppins",
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundColor:
                                    const Color.fromARGB(255, 0, 46, 124),
                                child: IconButton(
                                  icon: const Icon(Icons.chat,
                                      color: Colors.white),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ChatScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Posts View
                            MasonryGridView.builder(
                              controller: scrollController,
                              gridDelegate:
                                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                if (post?['media'] == null)
                                  return Container();
                                else if (post?['media'].runtimeType == String) {
                                  post['media'] = jsonDecode(post['media']);
                                }
                                try {
                                  return DynamicPostWidget(
                                    content: post['content'],
                                    media: List<Map<String, dynamic>>.from(
                                        (post['media'] as List<dynamic>)
                                            .map((m) => {
                                                  'type': m['type'],
                                                  'url': m['url'],
                                                })),
                                    postId: post['_id'],
                                    author: post['author'],
                                    group: post['group'],
                                    authorName: post['authorName'],
                                    profilePic: post['profilePic'],
                                    likes: post['likes'],
                                    isGroupPost: post['isGroupPost'] ?? false,
                                    public: post['public'],
                                    comments: post['comments'],
                                    onRefresh: updatePublicPostStatus,
                                    showMenu: true,
                                  );
                                } on Exception catch (e) {
                                  return Container();
                                }
                              },
                            ),

                            // Memories View
                            MasonryGridView.builder(
                              controller: scrollController,
                              gridDelegate:
                                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                              ),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              itemCount: allMemories.length + 2,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return GestureDetector(
                                    onTap: () {
                                      CreatePost.show(
                                        context,
                                        myGroupId: groupDetails!.groupId,
                                        isGroupPost: false,
                                        isPost: false,
                                        isMemory: true,
                                        message: "Share a memory",
                                      );
                                    },
                                    child: Container(
                                      height: 150,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.upload,
                                                color: Colors.white, size: 30),
                                            Text(
                                              "Upload",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                if (index == allMemories.length + 1) {
                                  return hasMore
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : const SizedBox.shrink();
                                }

                                final memory = allMemories[index - 1];

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MemoryViewer(
                                          memories: allMemories,
                                          initialIndex: index - 1,
                                          onMemoryDeleted: (memoryId) {
                                            setState(() {
                                              remoteMemories.removeWhere(
                                                  (m) => m.id == memoryId);
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: memory.type == MessageType.video
                                        ? VideoMessageView(
                                            url: memory.url,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => MemoryViewer(
                                                    memories: allMemories,
                                                    initialIndex: index - 1,
                                                    onMemoryDeleted:
                                                        (memoryId) {
                                                      setState(() {
                                                        remoteMemories
                                                            .removeWhere((m) =>
                                                                m.id ==
                                                                memoryId);
                                                      });
                                                    },
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : memory.type == MessageType.image
                                            ? Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child: CachedNetworkImage(
                                                    imageUrl: memory.url,
                                                    placeholder: (context,
                                                            url) =>
                                                        const CircularProgressIndicator(),
                                                    errorWidget: (context, url,
                                                            error) =>
                                                        const Icon(Icons.error),
                                                  ),
                                                ))
                                            : null,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddBioDialog(member) {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController bioController = TextEditingController(
          text: member.additionalData['memberBio'] != null &&
                  member.additionalData['memberBio'] is List &&
                  member.additionalData['memberBio'].isNotEmpty
              ? GroupsService.parseBio(member.additionalData['memberBio'].last)
                  .bio
              : '',
        );
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "Add a bio for this friend",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Let them know how you feel about them! Write something nice or memorable.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: bioController,
                    maxLength: 80,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: "#${profileDetails!['name']}",
                      hintText: "E.g. Best teammate ever! 🎉",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (bioController.text.trim().isEmpty) {
                            setState(() {
                              errorText = "Bio cannot be empty";
                            });
                            return;
                          }
                          setState(() {
                            isSubmitting = true;
                            errorText = null;
                          });
                          final result = await GroupsService.updateMemberBio(
                            groupId: groupDetails!.groupId,
                            userId: member.id,
                            bio: bioController.text.trim(),
                          );
                          setState(() {
                            isSubmitting = false;
                          });
                          if (result['success'] == true) {
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Bio updated!")),
                              );
                            }
                            this.setState(() {
                              member.additionalData['memberBio'] = [
                                GroupsService.parseBio(bioController.text).bio
                              ];
                            });
                          } else {
                            setState(() {
                              errorText =
                                  result['error'] ?? "Failed to update bio";
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Save",
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
