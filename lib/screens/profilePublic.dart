// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:math';

import 'package:chitchat/appstate/joinRequestPrefs.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/components/bottomnav.dart';
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
import 'package:chitchat/components/like.dart';

class PublicProfilePage extends StatefulWidget {
  final String dbIndex;
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
  List<dynamic> watchlist = [];
  String? next;
  bool isLoadingPost = false;
  bool hasMore = true;
  bool isLoadingMore = false;
  bool isLoadingGroup = true;
  bool isInWatchList = false;
  bool isWatchListLoading = false;

  // Like state management
  final Map<String, bool> likeStatus = {};
  final Map<String, int> likeCountForMember = {};
  bool isJoinLoading = false;
  bool isRequestSent = false;

  // Animation variables for FriendCircle
  late AnimationController _friendCircleAnimationController;
  late Animation<double> _maxVisibleAnimation;
  late Animation<double> _upperContainerHeightAnimation;
  late Animation<int> _circleSizeAnimation;
  double currentMaxVisible = 5.0; // Initial max visible users
  double currentUpperContainerHeightMultiplier = 0.4;
  int currentCircleSize = 200;
  String? _getEducationField(Map<String, dynamic> member) {
    // Get the enum value
    final level = member['educationLevel'] as String?;
    if (level == null) return null;

    switch (level) {
      case "School":
        return member['school'] as String?;
      case "College":
        return member['college'] as String?;
      case "University":
        return member['university'] as String?;
      case "Passout":
        return member['year']?.toString(); // maybe year or some graduation info
      default:
        return "";
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _friendCircleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _maxVisibleAnimation = Tween<double>(
      begin: 5.0,
      end: 8.0, // Maximum users to show
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
    _getUserLikes();

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

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Error',
              style: TextStyle(
                  color: AppColors.background, fontFamily: 'Poppins')),
          content: Text(message,
              style: const TextStyle(color: Colors.red, fontFamily: 'Poppins')),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
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
        // Check local prefs for pending join request
        await JoinRequestPrefs.init();
        setState(() {
          isRequestSent = JoinRequestPrefs.hasRequestedSync(userGroup!.groupId);
        });
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
    watchlist = AppVariables.get<List<dynamic>>('watchlist') ?? [];
    print("watchlist:$watchlist");
    if (watchlist != null) {
      setState(() {
        isInWatchList = watchlist.contains(userGroup?.groupId);
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
    // Get the user ID to fetch their likes
    if (widget.uid.isNotEmpty) {
      Map<String, dynamic> result =
          await UserService.fetchUserLikes(ids: [widget.uid], invalidate: true);
      if (result['success']) {
        for (var user in result['data']) {
          likeCountForMember[user['_id']] = user['likes'];
        }
      }
      setState(() {});
    }
  }

  Future<bool> toggleLike(String userid) async {
    // Store original state before optimistic update
    final bool originalLikeStatus = likeStatus[userid] ?? false;
    final int originalLikeCount = likeCountForMember[userid] ?? 0;

    setState(() {
      likeStatus[userid] = !originalLikeStatus;
      likeCountForMember[userid] =
          (originalLikeCount + (likeStatus[userid]! ? 1 : -1)) < 0
              ? 0
              : (originalLikeCount + (likeStatus[userid]! ? 1 : -1));
    });
    AppVariables.setPersistent<Map<String, bool>>(
        'likeStatusForMember', likeStatus);

    Map<String, dynamic> result = await UserService.likeUser(userId: userid);
    if (result['success']) {
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
            const SnackBar(content: Text('Like removed')),
          );
        }
      }
      return true;
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
      return false;
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
      extendBody: true,
      bottomNavigationBar: AppBottomNav(),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 3,
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
          Row(
            children: [
              Expanded(
                child: Container(
                  color: const Color.fromARGB(255, 12, 12, 38),
                ),
              ),
            ],
          ),
          // Top Container for Friend Circle
          Container(
            height: MediaQuery.of(context).size.height *
                currentUpperContainerHeightMultiplier,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                if (userGroup != null && userGroup!.members.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: isJoinLoading
                              ? null
                              : () async {
                                  setState(() {
                                    isJoinLoading = true;
                                  });

                                  Map<String, dynamic> result;

                                  if (isRequestSent) {
                                    // ── Unsend request ──
                                    result =
                                        await GroupsService.cancelJoinRequest(
                                            userGroup!.groupId,
                                            requestId:
                                                JoinRequestPrefs.getRequestId(
                                                    userGroup!.groupId));
                                    setState(() {
                                      isJoinLoading = false;
                                    });
                                    if (result['success']) {
                                      await JoinRequestPrefs.unmarkRequested(
                                          userGroup!.groupId);
                                      setState(() {
                                        isRequestSent = false;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Join request cancelled'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      }
                                    } else {
                                      _showErrorDialog(
                                          context,
                                          result['error'] ??
                                              'Failed to cancel request');
                                    }
                                  } else {
                                    // ── Send join request ──
                                    result = await GroupsService.joinGroup(
                                        userGroup!.groupId);
                                    setState(() {
                                      isJoinLoading = false;
                                    });
                                    if (result['success']) {
                                      final requestId = result['data']
                                              ?['joinrequest']?['_id'] ??
                                          '';
                                      await JoinRequestPrefs.markRequested(
                                          userGroup!.groupId, requestId);
                                      setState(() {
                                        isRequestSent = true;
                                      });
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                '🚀 Request Sent! Wait for members to let you in 🎉'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    } else {
                                      _showErrorDialog(
                                          context,
                                          result['error'] ??
                                              'Failed to join group');
                                    }
                                  }
                                },
                          style: TextButton.styleFrom(
                            backgroundColor:
                                isRequestSent ? Colors.deepOrange : Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: isJoinLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  isRequestSent
                                      ? Icons.undo_rounded
                                      : Icons.add,
                                  color: Colors.white),
                          label: Text(
                              isJoinLoading
                                  ? (isRequestSent
                                      ? 'Cancelling...'
                                      : 'Joining...')
                                  : (isRequestSent
                                      ? 'Unsend Request'
                                      : 'Join Group'),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white)),
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
                decoration: BoxDecoration(
                  color: AppColors.bottomSheetBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                  border: Border.all(
                      color: AppColors.bottomSheetBorder, width: 0.5),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            PageRouteBuilder(
                                              opaque: false,
                                              barrierDismissible: true,
                                              pageBuilder:
                                                  (BuildContext context, _,
                                                      __) {
                                                return ZoomableImagePopup(
                                                  imageUrl: userProfile?[
                                                      'profilePic'],
                                                  onEdit: null,
                                                  onClose: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                        child: CircleAvatar(
                                          radius: 35,
                                          backgroundColor: Colors.orange,
                                          backgroundImage: userProfile?[
                                                      'profilePic'] !=
                                                  null
                                              ? NetworkImage(
                                                  userProfile?['profilePic'])
                                              : null,
                                          child: userProfile?['profilePic'] ==
                                                  null
                                              ? Icon(Icons.person,
                                                  color: Colors.white)
                                              : null, // Avoid overlapping the icon if there's an image
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${userProfile?['username'] ?? 'No username'}",
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                          Text(
                                            "${userProfile?['name'] ?? 'No Name'}",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                      SizedBox(width: 30),
                                    ],
                                  ),
                                  // Like button for the user profile
                                  LikeButton(
                                    buttonType: ButtonType.user,
                                    postId: widget.uid,
                                    initialLikes:
                                        likeCountForMember[widget.uid] ?? 0,
                                    initiallyLiked:
                                        likeStatus[widget.uid] ?? false,
                                    showLikeCount: true,
                                    // Custom colors for white background
                                    likedColor: Colors.red,
                                    unlikedColor: Colors.grey[400],
                                    textColor: Colors.white70,
                                    iconSize: 32,
                                    fontSize: 14,
                                    onLikeChanged: (isLiked) async {
                                      return await toggleLike(widget.uid);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Padding(
                            //   padding: const EdgeInsets.symmetric(
                            //       horizontal: 20, vertical: 10),
                            //   child: GestureDetector(
                            //     onTap: () {
                            //       showDialog(
                            //         context: context,
                            //         builder: (BuildContext context) {
                            //           final bioList = userProfile?['bio'] ?? [];
                            //           bioList.removeWhere((bio) => bio == null);
                            //           return AlertDialog(
                            //             backgroundColor: AppColors.background,
                            //             shape: RoundedRectangleBorder(
                            //                 borderRadius:
                            //                     BorderRadius.circular(20)),
                            //             title: Row(
                            //               children: [
                            //                 Icon(Icons.info_outline,
                            //                     color: AppColors.textSecondary),
                            //                 SizedBox(width: 8),
                            //                 Text('Bio History',
                            //                     style: TextStyle(
                            //                         fontFamily: "Poppins",
                            //                         color: AppColors.primary)),
                            //               ],
                            //             ),
                            //             content: bioList.isEmpty
                            //                 ? Text("No bio available.",
                            //                     style: TextStyle(
                            //                         fontFamily: "Poppins",
                            //                         color: AppColors.success))
                            //                 : SizedBox(
                            //                     width: double.maxFinite,
                            //                     child: ListView.separated(
                            //                       shrinkWrap: true,
                            //                       itemCount: bioList.length,
                            //                       separatorBuilder: (_, __) =>
                            //                           Divider(),
                            //                       itemBuilder: (context, idx) {
                            //                         final bioObj =
                            //                             GroupsService.parseBio(
                            //                                 bioList[idx]);
                            //                         return ListTile(
                            //                           title: Text(
                            //                             bioObj.bio ?? "No bio",
                            //                             style: TextStyle(
                            //                                 fontFamily:
                            //                                     "Poppins",
                            //                                 color:
                            //                                     Colors.white),
                            //                           ),
                            //                           subtitle: Text(
                            //                             "Edited by: ${bioObj.editedBy ?? 'Unknown'}",
                            //                             style: TextStyle(
                            //                               fontSize: 12,
                            //                               color:
                            //                                   Colors.grey[700],
                            //                               fontFamily: "Poppins",
                            //                             ),
                            //                           ),
                            //                         );
                            //                       },
                            //                     ),
                            //                   ),
                            //             actions: [
                            //               TextButton(
                            //                 child: Text('Close',
                            //                     style: TextStyle(
                            //                         fontFamily: "Poppins",
                            //                         color: AppColors.primary)),
                            //                 onPressed: () =>
                            //                     Navigator.of(context).pop(),
                            //               ),
                            //             ],
                            //           );
                            //         },
                            //       );
                            //     },
                            //     child: Text(
                            //       userProfile?['bio'].length > 0 &&
                            //               !(userProfile?['bio'] as List)
                            //                   .every((bio) => bio == null)
                            //           ? "#${GroupsService.parseBio(userProfile?['bio'].last).editedBy ?? ''} ${GroupsService.parseBio(userProfile?['bio'].last).bio}"
                            //           : 'No bio available',
                            //       style: TextStyle(
                            //           fontSize: 14,
                            //           color: AppColors.background,
                            //           fontFamily: "Poppins"),
                            //       textAlign: TextAlign.left,
                            //     ),
                            //   ),
                            // ),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _getEducationField(userProfile ?? {}) ??
                                    "No Education",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontFamily: "Poppins"),
                                textAlign: TextAlign.left,
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
                                          color: Colors.white)),
                                ],
                              ),
                            ),
                            SizedBox(height: 10),
                            if (posts.isEmpty)
                              Center(
                                child: Text("No Post Yet 😔",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.white)),
                              ),
                            SizedBox(height: 10),
                            if (posts.isNotEmpty)
                              MasonryGridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                addAutomaticKeepAlives: true,
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
                                    return Container(
                                        key: ValueKey('post-empty-$index'));
                                  else if (post?['media'].runtimeType ==
                                      String) {
                                    post['media'] = jsonDecode(post['media']);
                                  }
                                  try {
                                    return DynamicPostWidget(
                                      key: ValueKey('post-${post['_id']}'),
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
                                      isGroupPost: post['isGroupPost'] ?? false,
                                      authorName: post['authorName'],
                                      profilePic: post['profilePic'],
                                      likes: post['likes'],
                                      comments: post['comments'],
                                    );
                                  } on Exception catch (e) {
                                    return Container(
                                        key: ValueKey('post-error-$index'));
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
