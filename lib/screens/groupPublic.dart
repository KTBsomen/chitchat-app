import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/components/comments.dart';
import 'package:chitchat/components/createPost.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/like.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/components/videoWidget.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutterdb/flutterdb.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shimmer/shimmer.dart';

class GroupPublicViewScreen extends StatefulWidget {
  final String groupId;
  GroupPublicViewScreen({required this.groupId});
  @override
  _GroupPublicViewScreenState createState() => _GroupPublicViewScreenState();
}

class _GroupPublicViewScreenState extends State<GroupPublicViewScreen>
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
  List<Message> memories = [];
  FriendCircleGroup? userGroup;
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? myProfile;

  final ScrollController _scrollController = ScrollController();
  String? next;
  bool isLoadingPost = false;
  bool hasMore = true;
  bool isLoadingMore = false;
  bool isLoadingGroup = true;
  bool isInWatchList = false;
  bool isWatchListLoading = false;
  bool isJoinLoading = false;

  Future _getGroupDetails() async {
    setState(() {
      isLoadingGroup = true;
    });
    groupDetails =
        (await GroupsService.getGroupDetails(gid: widget.groupId)).first;
    setState(() {
      isLoadingGroup = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _getGroupDetails().then((x) {
      _fetchPosts();
    });

    _getUserLikes();
    _tabController = TabController(length: 1, vsync: this);
    AppVariables.registerState(this);

    _tabController.addListener(() {
      setState(() {
        selectedTab = _tabController.index;
      });
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingPost &&
          hasMore) {
        _fetchPosts();
      }
    });
  }

  _fetchPosts() async {
    if (isLoadingPost) return;
    setState(() {
      isLoadingPost = true;
    });
    Map<String, dynamic> result = await PostService.fetchGroupPosts(
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

  Future<bool> toggleLike(String userid, {bool internal = false}) async {
    Map<String, dynamic> result = await UserService.likeUser(userId: userid);
    print(result);
    if (result['success']) {
      print(result['data']);
      if (result['status'] == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Liked')),
          );
        }
        return true;
      } else if (result['status'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('like removed')),
          );
        }
        return false;
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
      }
      return false;
    }
    return false;
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
                            //         child: GroupPublicViewScreen(),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return groupDetails == null
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Scaffold(
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
                          onClose: () => Navigator.of(context).pop(),
                        );
                      },
                    ),
                  );
                },
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(left: 20, right: 20),
                  child: const Stack(
                    children: [
                      NotificationIcon(
                          icon: Icons.notifications,
                          type: NotificationIconType.Notification)
                    ],
                  ),
                ),
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
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundImage: NetworkImage(member.avatarUrl),
                          ),
                          title: Text(
                            member.additionalData['memberName'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  final bioList =
                                      member.additionalData['memberBio'] ?? [];
                                  bioList.removeWhere((bio) => bio == null);
                                  return AlertDialog(
                                    backgroundColor: AppColors.background,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            color: AppColors.textSecondary),
                                        SizedBox(width: 8),
                                        Text('Bio History',
                                            style: TextStyle(
                                                fontFamily: "Poppins",
                                                color: AppColors.primary)),
                                      ],
                                    ),
                                    content: bioList.isEmpty
                                        ? Text("No bio available.",
                                            style: TextStyle(
                                                fontFamily: "Poppins",
                                                color: AppColors.success))
                                        : SizedBox(
                                            width: double.maxFinite,
                                            child: ListView.separated(
                                              shrinkWrap: true,
                                              itemCount: bioList.length,
                                              separatorBuilder: (_, __) =>
                                                  Divider(),
                                              itemBuilder: (context, idx) {
                                                final bioObj =
                                                    GroupsService.parseBio(
                                                        bioList[idx]);
                                                return ListTile(
                                                  title: Text(
                                                    bioObj.bio ?? "No bio",
                                                    style: TextStyle(
                                                        fontFamily: "Poppins",
                                                        color: Colors.white),
                                                  ),
                                                  subtitle: Text(
                                                    "Edited by: ${bioObj.editedBy ?? 'Unknown'}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[700],
                                                      fontFamily: "Poppins",
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                    actions: [
                                      TextButton(
                                        child: Text('Close',
                                            style: TextStyle(
                                                fontFamily: "Poppins",
                                                color: AppColors.primary)),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Text(
                              member.additionalData['memberBio'].length > 0
                                  ? "#${GroupsService.parseBio(member.additionalData['memberBio'].last).editedBy} ${GroupsService.parseBio(member.additionalData['memberBio'].last).bio}"
                                  : 'No bio available',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontFamily: "Poppins"),
                              textAlign: TextAlign.left,
                            ),
                          ),
                          trailing: LikeButton(
                              postId: member.id,
                              buttonType: ButtonType.user,
                              initialLikes: member.additionalData['likes'] ?? 0,
                              initiallyLiked: false,
                              onLikeChanged: (bool x) =>
                                  toggleLike(member.id)));
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
                                  height: 40,
                                  width:
                                      MediaQuery.of(context).size.width * 0.4,
                                  child: Column(
                                    children: [
                                      Text(
                                        textAlign: TextAlign.center,
                                        "Pics",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Container(
                                        height: 6,
                                        width: 50,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.blue,
                                              Colors.purple,
                                              Colors.pink
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    // Handle the "Join" button press
                                    setState(() {
                                      isJoinLoading = true;
                                    });

                                    Map<String, dynamic> result =
                                        await GroupsService.joinGroup(
                                            widget.groupId);
                                    setState(() {
                                      isJoinLoading = false;
                                    });
                                    if (result['success']) {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Success'),
                                            content: const Text(
                                                "🚀Request Sent! wait for members to let you in.🎉🎉"),
                                            actions: [
                                              TextButton(
                                                child: const Text('OK'),
                                                onPressed: () {
                                                  Navigator.pushReplacement(
                                                    context,
                                                    PageTransition(
                                                        type: PageTransitionType
                                                            .rightToLeft,
                                                        child: HomePage()),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Error',
                                                style: TextStyle(
                                                    color: AppColors.background,
                                                    fontFamily: "Poppins")),
                                            content: Text(
                                                "Failed to join group😔\n ${result["error"]}",
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontFamily: "Poppins")),
                                            actions: [
                                              TextButton(
                                                child: const Text('OK'),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  icon: isJoinLoading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : const Icon(Icons.add,
                                          color: Colors.white),
                                  label: Text(
                                      isJoinLoading
                                          ? "Joining..."
                                          : "Join Group",
                                      style: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
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
                                  // Chat View
                                  groupDetails == null
                                      ? const Center(
                                          child: Text("Loading..."),
                                        )
                                      : posts.isEmpty
                                          ? const Center(
                                              child: const Text(
                                                "No Posts Yet 😔",
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            )
                                          : MasonryGridView.builder(
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
                                                else if (post?['media']
                                                        .runtimeType ==
                                                    String) {
                                                  post['media'] =
                                                      jsonDecode(post['media']);
                                                }
                                                try {
                                                  return DynamicPostWidget(
                                                    content: post['content'],
                                                    media: List<
                                                            Map<String,
                                                                dynamic>>.from(
                                                        (post['media'] as List<
                                                                dynamic>)
                                                            .map((m) => {
                                                                  'type':
                                                                      m['type'],
                                                                  'url':
                                                                      m['url'],
                                                                })),
                                                    postId: post['_id'],
                                                    author: post['author'],
                                                    group: post['group'],
                                                    authorName:
                                                        post['authorName'],
                                                    profilePic:
                                                        post['profilePic'],
                                                    likes: post['likes'],
                                                  );
                                                } on Exception catch (e) {
                                                  return Container();
                                                }
                                              }),
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
