import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
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
import 'package:flutterdb/flutterdb.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vs_media_picker/vs_media_picker.dart';

class GroupPrivateViewScreen extends StatefulWidget {
  @override
  _GroupPrivateViewScreenState createState() => _GroupPrivateViewScreenState();
}

class MemoryItem {
  final String url;
  final MessageType type;
  final bool isLocal;

  MemoryItem({
    required this.url,
    required this.type,
    this.isLocal = false,
  });
}

class _GroupPrivateViewScreenState extends State<GroupPrivateViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<dynamic> posts = [];
  final Map<String, bool> likeStatus = {};
  final Map<String, int> likeCountForMember = {};
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');
  FriendCircleGroup? groupDetails;

  int selectedTab = 0;

  late Collection chats;
  int windowSize = 20;
  int pageinmemories = 2;
  List<MemoryItem> memories = [];
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
  List<MemoryItem> remoteMemories = []; // fetched from API
  String? nextPageCursor; // API pagination cursor
  bool isLoading = false;

  final ScrollController _memoriesController = ScrollController();

  Future<List<MemoryItem>> initDB() async {
    final db = FlutterDB();

    try {
      chats = await db.collection('chats');
      final _memories = await chats.find({
        "\$or": [
          {"message_type": "voice"},
          {"message_type": "image"},
          {"message_type": "video"}
        ]
      });
      return _memories.map((e) {
        Message _temp = Message.fromJson(e);
        return MemoryItem(
            url: _temp.message, type: _temp.messageType, isLocal: true);
      }).toList();
    } on Exception catch (e) {
      // Handle the exception here
      print('Error initializing database: $e');
      return Future.value([]);
    }
  }

  Future<void> _fetchMemories({bool refresh = false}) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      Map<String, dynamic> data = await PostService.fetchMyGroupMemories(
          groupId: groupDetails!.groupId, limit: 10, next: nextPageCursor);

      if (data['success']) {
        final List<dynamic> fetched = data["data"]['_memories'];
        // normalize
        List<MemoryItem> newRemoteMemories = fetched.map((item) {
          String url = item['media'][0]['url'];
          String type = item['media'][0]['type'];
          // your API gives image/video URLs — detect type by extension
          final isVideo = type.contains("video");
          return MemoryItem(
            url: url.toString(),
            type: isVideo ? MessageType.video : MessageType.image,
            isLocal: false,
          );
        }).toList();

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
    return [...memories, ...remoteMemories];
  }

  void _handleProfileUpdate(Map<String, dynamic>? data) {
    if (mounted) {
      setState(() {
        groupDetails = GroupsService.buildFriendCircleGroup(data!['myGroup']);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    print(profileDetails);
    initDB().then((value) {
      setState(() {
        memories = value;
      });
    });
    groupDetails =
        GroupsService.buildFriendCircleGroup(profileDetails!['myGroup']);
    _getUserLikes();
    _tabController = TabController(length: 2, vsync: this);
    AppVariables.registerState(this);
    AppVariables.addListener("profile", _handleProfileUpdate);
    _tabController.addListener(() {
      setState(() {
        selectedTab = _tabController.index;
      });
    });
    _fetchPosts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingPost &&
          hasMore) {
        _fetchPosts();
      }
    });
    _fetchMemories();

    _memoriesController.addListener(() {
      if (_memoriesController.position.pixels >=
          _memoriesController.position.maxScrollExtent - 200) {
        if (hasMore && !isLoading) {
          _fetchMemories();
        }
        ;
      }
    });
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
    _refreshTimer?.cancel(); // cancel old timer if any

    void scheduleNext() {
      final random = Random();
      // Pick a random interval between 60–120 seconds
      final seconds = 60 + random.nextInt(61);
      print("Next presence refresh in $seconds seconds");

      _refreshTimer = Timer(Duration(seconds: seconds), () async {
        _fetchUserStatus();
        scheduleNext(); // schedule again after completion
      });
    }

    scheduleNext(); // start the loop
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
      posts.addAll(result['data']['posts']);
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
        await UserService.fetchUserLikes(ids: ids!, invalidate: false);
    if (result['success']) {
      for (var user in result['data']) {
        likeCountForMember[user['_id']] = user['likes'];
      }
    }
    setState(() {});
  }

  void toggleLike(String userid, {bool internal = false}) async {
    print(
        "likeStatusForMember>>${await AppVariables.getPersistent<Map<String, dynamic>>('likeStatusForMember')}");
    setState(() {
      likeStatus[userid] = !(likeStatus[userid] ?? false);
      int? user = likeCountForMember[userid];
      likeCountForMember[userid] = (user! + (likeStatus[userid]! ? 1 : -1)) < 0
          ? 0
          : (user! + (likeStatus[userid]! ? 1 : -1));
      //+= likeStatus[userid]! ? 1 : -1;
    });
    AppVariables.setPersistent<Map<String, bool>>(
        'likeStatusForMember', likeStatus);
    print(likeStatus);
    if (internal == false) {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['error'])),
          );
        }
        toggleLike(userid, internal: true);
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
    // Add your create functionality here
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
                  // Group Name Input
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

                  // Logo Picker
                  isSubmitted
                      // ignore: dead_code
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
              // Cancel Button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              // Create Button
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
                            // Navigator.pushReplacement(
                            //     context,
                            //     PageTransition(
                            //         type: PageTransitionType.leftToRight,
                            //         child: GroupPrivateViewScreen(),
                            //         duration: Duration(milliseconds: 400)));
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

    AppVariables.unregisterState(this);
    AppVariables.removeListener("posts", _handleProfileUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 12, 38),
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
                  // Add share functionality
                  SharePlus.instance.share(ShareParams(
                    title: "ChitChat Group Invitation",
                    text:
                        'Join our group ${groupDetails?.groupData['name']}!\n\n https://groups.chitzchat.com/join?group=${groupDetails!.groupId}',
                    subject: 'Join my group on ChitChat!',
                  ));
                  break;
                case 'leave':
                  // Show confirmation dialog
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
                              // Add leave group functionality
                              await GroupsService.leaveGroup(
                                  groupDetails!.groupId);
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(
                                  context); // Return to previous screen
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
          // Top Container for Group Members
          Container(
            padding: const EdgeInsets.all(8),
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              itemCount: groupDetails!.members.length,
              itemBuilder: (context, index) {
                final member = groupDetails!.members[index];
                print(
                    'Member ${member.id}: ${member.avatarUrl} ${member.additionalData['memberName']}');
                return ListTile(
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
                          dbIndex: member.additionalData['dbIndex'],
                          uid: member.id,
                        ),
                      ),
                    );
                  },
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundImage: NetworkImage(member.avatarUrl),
                      ),
                      if (member.status != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: member.status == 'online'
                                  ? Colors.green
                                  : member.status == 'offline'
                                      ? Colors.grey
                                      : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    member.additionalData['memberName'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          TextEditingController bioController =
                              TextEditingController(
                            text: member.additionalData['memberBio'] != null &&
                                    member.additionalData['memberBio']
                                        is List &&
                                    member
                                        .additionalData['memberBio'].isNotEmpty
                                ? GroupsService.parseBio(
                                        member.additionalData['memberBio'].last)
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
                                        hintText: "E.g. Best teammate ever! 🎉",
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        errorText: errorText,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: isSubmitting
                                        ? null
                                        : () async {
                                            if (bioController.text
                                                .trim()
                                                .isEmpty) {
                                              setState(() {
                                                errorText =
                                                    "Bio cannot be empty";
                                              });
                                              return;
                                            }
                                            setState(() {
                                              isSubmitting = true;
                                              errorText = null;
                                            });
                                            // Call API to update bio
                                            final result = await GroupsService
                                                .updateMemberBio(
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
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content:
                                                          Text("Bio updated!")),
                                                );
                                              }
                                              setState(() {
                                                member.additionalData[
                                                    'memberBio'] = [
                                                  GroupsService.parseBio(
                                                          bioController.text)
                                                      .bio
                                                ];
                                              });
                                            } else {
                                              setState(() {
                                                errorText = result['error'] ??
                                                    "Failed to update bio";
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
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Text("Save",
                                            style:
                                                TextStyle(color: Colors.white)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                    child: Wrap(
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              if (member.additionalData['memberBio'] != null &&
                                  member.additionalData['memberBio'] is List &&
                                  member.additionalData['memberBio'].isNotEmpty)
                                TextSpan(
                                    text: GroupsService.parseBio(member
                                            .additionalData['memberBio'][0])
                                        .editedBy,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              WidgetSpan(child: SizedBox(width: 5)),
                              TextSpan(
                                text:
                                    "${(member.additionalData['memberBio'] != null && member.additionalData['memberBio'] is List && member.additionalData['memberBio'].isNotEmpty) ? GroupsService.parseBio(member.additionalData['memberBio'].last).bio : ''}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.edit,
                                          color: Colors.blue, size: 18),
                                      if (member.additionalData['memberBio']
                                              .length <
                                          1)
                                        const Text(
                                          "Add a bio",
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => toggleLike(member.id),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          likeStatus[member.id] == true
                              ? const Icon(Icons.favorite, color: Colors.red)
                              : const Icon(Icons.favorite_border_outlined,
                                  color: Colors.white),
                          const SizedBox(width: 4),
                          likeCountForMember[member.id] != null
                              ? Text(
                                  '${likeCountForMember[member.id] ?? 0}',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : SizedBox(
                                  width: 20,
                                  height: 10,
                                  child: Shimmer.fromColors(
                                    direction: ShimmerDirection.ttb,
                                    baseColor: AppColors.background,
                                    highlightColor: const Color.fromARGB(
                                        255, 200, 200, 200)!,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        color: AppColors.gradientStart,
                                      ),
                                      width: 20,
                                      height: 10,
                                    ),
                                  ),
                                )
                        ],
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
                    // TabBar for Chat and Posts
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width * 0.6,
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
                                        MediaQuery.of(context).size.width * 0.3,
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
                                            0.3 -
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
                                const SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 46, 124),
                                  child: IconButton(
                                    icon: const Icon(Icons.add_a_photo_sharp,
                                        color: Colors.white),
                                    onPressed: () {
                                      CreatePost.show(context,
                                          myGroupId: groupDetails!.groupId,
                                          isGroupPost: true,
                                          isPost: true);
                                    },
                                  ),
                                ),
                              ]),
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
                            // post View
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
                                  else if (post?['media'].runtimeType ==
                                      String) {
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
                                      public: post['public'],
                                    );
                                  } on Exception catch (e) {
                                    return Container();
                                  }
                                }),

                            // memories View (Masonry Grid)
                            MasonryGridView.builder(
                              controller: _memoriesController,
                              gridDelegate:
                                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                              ),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              // add +1 for one static item
                              itemCount: allMemories.length + 2,
                              itemBuilder: (context, index) {
                                // First static item
                                if (index == 0) {
                                  return GestureDetector(
                                    onTap: () {
                                      // Upload action
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
                                  // Loader
                                  return hasMore
                                      ? const Center(
                                          child: CircularProgressIndicator())
                                      : const SizedBox.shrink();
                                }
                                // Adjust index for memories list
                                final memory = allMemories[index - 1];

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MemoryViewer(
                                          memories: allMemories,
                                          initialIndex: index -
                                              1, // adjust since first item is Upload
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
                                                    initialIndex: index -
                                                        1, // adjust since first item is Upload
                                                  ),
                                                ),
                                              );
                                            },
                                          )
                                        : memory.type == MessageType.image
                                            ? CachedNetworkImage(
                                                imageUrl: memory.url,
                                                placeholder: (context, url) =>
                                                    const CircularProgressIndicator(),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(Icons.error),
                                              )
                                            : null,
                                  ),
                                );
                              },
                            )
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
}

// Mockup of Group Edit Page
class GroupEditPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Group Details"),
      ),
      body: const Center(
        child: Text("Group Edit Page"),
      ),
    );
  }
}
