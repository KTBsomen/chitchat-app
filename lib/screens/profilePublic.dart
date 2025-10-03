// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:math';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';

import '../components/friendcircle.dart';

class PublicProfilePage extends StatefulWidget {
  final int dbIndex;
  final String uid;
  const PublicProfilePage(
      {super.key, required this.dbIndex, required this.uid});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage>
    with TickerProviderStateMixin {
  FriendCircleGroup? userGroup;
  Map<String, dynamic>? userProfile;
  Map<String, dynamic>? myProfile;

  final ScrollController _scrollController = ScrollController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  List<dynamic> posts = [];
  String? next;
  bool isLoadingPost = false;
  bool hasMore = true;
  bool isLoadingMore = false;
  bool isLoadingGroup = true;
  bool isInWatchList = false;
  bool isWatchListLoading = false;
  bool isJoinLoading = false;

  // Animation variables for FriendCircle
  late AnimationController _friendCircleAnimationController;
  late Animation<int> _maxVisibleAnimation;
  late Animation<double> _upperContainerHeightAnimation;
  late Animation<int> _circleSizeAnimation;
  int currentMaxVisible = 4; // Initial max visible users
  double currentUpperContainerHeightMultiplier = 0.4;
  int currentCircleSize = 200;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _friendCircleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _maxVisibleAnimation = IntTween(
      begin: 4,
      end: 6, // Maximum users to show
    ).animate(CurvedAnimation(
      parent: _friendCircleAnimationController,
      curve: Curves.easeInOut,
    ));

    _upperContainerHeightAnimation = Tween<double>(
      begin: 0.4,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _friendCircleAnimationController,
      curve: Curves.easeInOut,
    ));

    _circleSizeAnimation = IntTween(
      begin: 200,
      end: 350,
    ).animate(CurvedAnimation(
      parent: _friendCircleAnimationController,
      curve: Curves.easeInOut,
    ));

    _getprofile();
    _fetchPosts();

    // Listen to scroll changes
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingPost &&
          hasMore) {
        _fetchPosts();
      }
    });

    // Listen to sheet drag changes
    _sheetController.addListener(_onSheetPositionChanged);
  }

  void _onSheetPositionChanged() {
    if (!_sheetController.isAttached) return;

    final double currentPosition = _sheetController.size;

    // Calculate progress based on sheet position
    // When sheet is at 0.6 (initial), progress = 0
    // When sheet is at 1.0 (fully expanded), progress = 1
    final double progress =
        ((0.6 - currentPosition) / (0.6 - 0.2)).clamp(0.0, 1.0);

    // Update animation progress
    _friendCircleAnimationController.value = progress;
    // Update current max visible based on animation
    setState(() {
      currentMaxVisible = _maxVisibleAnimation.value;
      currentUpperContainerHeightMultiplier =
          _upperContainerHeightAnimation.value;
      currentCircleSize = _circleSizeAnimation.value;
    });
  }

  @override
  void dispose() {
    _friendCircleAnimationController.dispose();
    _sheetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _getprofile() async {
    final result = await UserService.fetchUserPublicProfile(
        dbIndex: widget.dbIndex, uid: widget.uid);

    if (result['success']) {
      print('Profile fetched successfully:');
      print(result['data']);
      userProfile = result['data'];
      setState(() {});

      if (result['group'] != null) {
        userGroup = result['group'] as FriendCircleGroup;
        setState(() {});
        print('Group Name: ${userGroup?.groupData['name']}');
        print('Members:');
        for (var member in userGroup!.members) {
          print('  - ${member.additionalData['memberName']}');
        }
      } else {
        print('No group found for this user.');
        userGroup = FriendCircleGroup(
          groupId: 'defaultGroup',
          groupData: {'name': 'Default Group'},
          members: [],
        );
      }
    } else {
      userGroup = FriendCircleGroup(
        groupId: 'defaultGroup',
        groupData: {'name': 'Default Group'},
        members: [],
      );
      print('Error fetching profile: ${result['error']}');
    }
    setState(() {});
    List? watchlist = AppVariables.get<List<dynamic>>('watchlist');
    print(watchlist);
    if (watchlist != null) {
      setState(() {
        isInWatchList = watchlist.contains(userGroup?.groupId);
      });
    }
  }

  _fetchPosts() async {
    if (isLoadingPost) return;
    setState(() {
      isLoadingPost = true;
    });
    Map<String, dynamic> result = await PostService.fetchUserPosts(
      userid: widget.uid,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 12, 38),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          NotificationIcon(
              icon: Icons.notifications,
              type: NotificationIconType.Notification),
          NotificationIcon(
            icon: Icons.messenger_outline_rounded,
            type: NotificationIconType.Message,
          ),
        ],
        title: const Text(
          "Chit Chat",
          style: TextStyle(
              color: Colors.white,
              fontFamily: "Poppins",
              fontWeight: FontWeight.bold,
              fontSize: 30),
        ),
      ),
      body: Stack(
        children: [
          // Top Container for Friend Circle
          Container(
            height: MediaQuery.of(context).size.height *
                currentUpperContainerHeightMultiplier,
            child: Column(
              children: [
                Center(
                  child: userGroup == null
                      ? CircularProgressIndicator() // Show a loader until the group is available
                      : userGroup!.members.length == 0
                          ? Center(
                              child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "😔 No Groups Found ",
                                  style: TextStyle(
                                      fontSize: 25,
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ],
                            ))
                          : AnimatedBuilder(
                              animation: _maxVisibleAnimation,
                              builder: (context, child) {
                                return FriendCircle(
                                  group: userGroup!,
                                  size: currentCircleSize * 1.0,
                                  nodeSize: (userGroup!.members.length > 5
                                      ? userGroup!.members.length *
                                          currentUpperContainerHeightMultiplier *
                                          15
                                      : 90.0),
                                  nodeBorderColor: Colors.white24,
                                  maxVisibleMembers: currentMaxVisible,
                                  edgeStyle: EdgeStyle(
                                    width: 2,
                                    outerGlow: 2,
                                    outerGlowColor: Colors.white,
                                    gradientColors: [
                                      Color.fromARGB(255, 198, 101, 10),
                                      Color.fromARGB(255, 255, 179, 0),
                                      Color.fromARGB(255, 96, 4, 194)
                                    ],
                                  ),
                                  onGroupTap: () {
                                    print(
                                        "Group tapped! ${userGroup!.groupId}");
                                    Navigator.push(
                                      context,
                                      PageTransition(
                                        type: PageTransitionType.rightToLeft,
                                        child: GroupPublicViewScreen(
                                          groupId: userGroup!.groupId,
                                        ),
                                      ),
                                    );
                                  },
                                  onMemberTap: (index) {
                                    if (index < userGroup!.members.length) {
                                      print(
                                          "Member ${userGroup!.members[index].id} tapped!");
                                      Navigator.push(
                                        context,
                                        PageTransition(
                                          type: PageTransitionType.rightToLeft,
                                          child: GroupPublicViewScreen(
                                            groupId: userGroup!.groupId,
                                          ),
                                        ),
                                      );
                                    } else {
                                      print("Invalid member tapped!");
                                    }
                                  },
                                );
                              },
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          // Handle the "Join" button press
                          setState(() {
                            isJoinLoading = true;
                          });

                          Map<String, dynamic> result =
                              await GroupsService.joinGroup(userGroup!.groupId);
                          setState(() {
                            isJoinLoading = false;
                          });
                          if (result['success']) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Success'),
                                  content:
                                      Text("🚀Group Joined successfully 🎉🎉"),
                                  actions: [
                                    TextButton(
                                      child: Text('OK'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
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
                                  title: Text('Error',
                                      style: TextStyle(
                                          color: AppColors.background,
                                          fontFamily: "Poppins")),
                                  content: Text(
                                      "Failed to join group😔\n${result['error']}",
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontFamily: "Poppins")),
                                  actions: [
                                    TextButton(
                                      child: Text('OK'),
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
                            ? CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Icon(Icons.add, color: Colors.white),
                        label: Text(isJoinLoading ? "Joining..." : "Join Group",
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // DraggableScrollableSheet for the Bottom Container
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.6, // Default open height (60% of the screen)
            minChildSize: 0.2, // Minimum height (cannot be dragged below 20%)
            maxChildSize: 1, // Maximum height (100% of the screen)
            builder: (context, scrollController) {
              scrollController.addListener(() {
                if (scrollController.position.pixels >=
                        scrollController.position.maxScrollExtent &&
                    !isLoadingPost &&
                    hasMore) {
                  // Reached the bottom of the scrollable area

                  _fetchPosts();
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
                padding: const EdgeInsets.all(16),
                child: userProfile == null
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          opaque: false,
                                          barrierDismissible: true,
                                          pageBuilder:
                                              (BuildContext context, _, __) {
                                            return ZoomableImagePopup(
                                              imageUrl:
                                                  userProfile?['profilePic'],
                                              onEdit: null,
                                              onClose: () =>
                                                  Navigator.of(context).pop(),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 35,
                                      backgroundColor: Colors.orange,
                                      backgroundImage:
                                          userProfile?['profilePic'] != null
                                              ? NetworkImage(
                                                  userProfile?['profilePic'])
                                              : null,
                                      child: userProfile?['profilePic'] == null
                                          ? Icon(Icons.person,
                                              color: Colors.white)
                                          : null, // Avoid overlapping the icon if there's an image
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${userProfile?['username'] ?? 'No username'}",
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "${userProfile?['name'] ?? 'No Name'}",
                                        style: TextStyle(
                                            fontSize: 16, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 30),
                                  Tooltip(
                                    message: "Add to watchList",
                                    child: InkWell(
                                      onTap: isInWatchList
                                          ? null
                                          : () async {
                                              setState(() {
                                                isWatchListLoading = true;
                                              });
                                              Map<String, dynamic> result =
                                                  await GroupsService
                                                      .addToWatchList(
                                                          userGroup!.groupId);
                                              setState(() {
                                                isWatchListLoading = false;
                                              });
                                              if (result['success']) {
                                                setState(() {
                                                  isInWatchList = true;
                                                });
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: Text('Success'),
                                                      content: Text(
                                                          "Group added to watchlist successfully"),
                                                      actions: [
                                                        TextButton(
                                                          child: Text('OK'),
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              } else {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (BuildContext context) {
                                                    return AlertDialog(
                                                      title: Text('Error',
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .background,
                                                              fontFamily:
                                                                  "Poppins")),
                                                      content: Text(
                                                          "Failed to add group to watchlist: ${result['error']}",
                                                          style: TextStyle(
                                                              color: Colors.red,
                                                              fontFamily:
                                                                  "Poppins")),
                                                      actions: [
                                                        TextButton(
                                                          child: Text('OK'),
                                                          onPressed: () {
                                                            Navigator.of(
                                                                    context)
                                                                .pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );
                                              }
                                            },
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Colors.transparent,
                                        child: isWatchListLoading
                                            ? CircularProgressIndicator()
                                            : Icon(
                                                isInWatchList
                                                    ? Icons
                                                        .remove_red_eye_rounded
                                                    : Icons
                                                        .remove_red_eye_outlined,
                                                color: Colors.red,
                                                size: 30,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      final bioList = userProfile?['bio'] ?? [];
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
                                                            fontFamily:
                                                                "Poppins",
                                                            color:
                                                                Colors.white),
                                                      ),
                                                      subtitle: Text(
                                                        "Edited by: ${bioObj.editedBy ?? 'Unknown'}",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
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
                                  userProfile?['bio'].length > 0 &&
                                          !(userProfile?['bio'] as List)
                                              .every((bio) => bio == null)
                                      ? "#${GroupsService.parseBio(userProfile?['bio'].last).editedBy ?? ''} ${GroupsService.parseBio(userProfile?['bio'].last).bio}"
                                      : 'No bio available',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.background,
                                      fontFamily: "Poppins"),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ),
                            Divider(
                              color: const Color.fromARGB(95, 158, 158, 158),
                              thickness: 1,
                              endIndent: 20,
                              indent: 20,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Pics",
                                      style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: "Poppins",
                                          color: Colors.black)),
                                ],
                              ),
                            ),
                            SizedBox(height: 10),
                            if (posts.isEmpty)
                              Center(
                                child: Text("No Post Yet 😔",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black)),
                              ),
                            SizedBox(height: 10),
                            if (posts.isNotEmpty)
                              MasonryGridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
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
                                    );
                                  } on Exception catch (e) {
                                    return Container();
                                  }
                                  // return ClipRRect(
                                  //   borderRadius: BorderRadius.circular(8),
                                  //   child: Image.network(
                                  //     posts[index],
                                  //     fit: BoxFit.cover,
                                  //   ),
                                  // );
                                },
                              ),
                            if (isLoadingPost) ...[
                              Center(
                                child: CircularProgressIndicator(),
                              ),
                              SizedBox(height: 10),
                            ]
                          ],
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}
