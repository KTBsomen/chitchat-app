import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/components/bottomnav.dart';
import 'package:chitchat/components/createPost.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/friendcircle.dart';

class PrivetProfilePage extends StatefulWidget {
  const PrivetProfilePage({super.key});

  @override
  State<PrivetProfilePage> createState() => _PrivetProfilePageState();
}

class _PrivetProfilePageState extends State<PrivetProfilePage>
    with TickerProviderStateMixin {
  FriendCircleGroup? myGroup;
  Map<String, dynamic>? myProfile;
  final ScrollController _scrollController = ScrollController();
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // Animation variables for FriendCircle
  late AnimationController _friendCircleAnimationController;
  late Animation<double> _maxVisibleAnimation;
  late Animation<double> _upperContainerHeightAnimation;
  late Animation<int> _circleSizeAnimation;

  double currentMaxVisible = 5.0;
  double currentUpperContainerHeightMultiplier = 0.4;
  int currentCircleSize = 180;

  List<dynamic> posts = [];
  String? next;
  bool isLoadingPost = false;
  bool hasMore = true;
  bool isLoadingMore = false;
  bool isLoadingGroup = true;
  int profileVersion = 0;

  String? _getBustedUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return "$url${separator}v=$profileVersion";
  }

  FriendCircleGroup _getBustedGroup(FriendCircleGroup group) {
    return group.copyWith(
      members: group.members
          .map((m) => FriendCircleMember(
                avatarUrl: _getBustedUrl(m.avatarUrl) ?? "",
                id: m.id,
                additionalData: m.additionalData,
                status: m.status,
                lastSeen: m.lastSeen,
              ))
          .toList(),
    );
  }

  void _handlePostUpdate(value) {
    print("Posts updated from AppVariables listener $value");
    if (mounted) {
      setState(() {
        posts.insert(0, value);
      });
    }
  }

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
      end: 8.0,
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
      begin: 180,
      end: 315,
    ).animate(CurvedAnimation(
      parent: _friendCircleAnimationController,
      curve: Curves.easeInOut,
    ));

    _getMyprofile();
    _fetchPosts();
    AppVariables.registerState(this);
    AppVariables.addListener<Map<String, dynamic>>("posts", _handlePostUpdate);
    AppVariables.addListener("deleted_posts", _handlePostDelete);
    AppVariables.addListener("profile", _handleProfileUpdate);

    _sheetController.addListener(_onSheetPositionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onSheetPositionChanged();
    });
  }

  void _onSheetPositionChanged() {
    if (!_sheetController.isAttached) return;

    final double currentPosition = _sheetController.size;

    // When sheet is at 0.6 (initial), progress = 0
    // When sheet is at 0.2 (collapsed), progress = 1
    // Note: minChildSize in PublicProfile is 0.2, we should probably follow that.
    final double progress =
        ((0.6 - currentPosition) / (0.6 - 0.2)).clamp(0.0, 1.0);

    _friendCircleAnimationController.value = progress;
    setState(() {
      currentMaxVisible = _maxVisibleAnimation.value;
      currentUpperContainerHeightMultiplier =
          _upperContainerHeightAnimation.value;
      currentCircleSize = _circleSizeAnimation.value;
    });
  }

  void _handlePostDelete(value) {
    print("Post deleted from AppVariables listener: $value");
    if (mounted) {
      Navigator.canPop(context) ? Navigator.pop(context) : null;
      setState(() {
        posts.removeWhere((post) => post['_id'] == value);
      });
    }
  }

  void _handleProfileUpdate(Map<String, dynamic>? data) {
    if (mounted && data != null) {
      setState(() {
        myProfile = data;
        if (data['myGroup'] != null) {
          myGroup = GroupsService.buildFriendCircleGroup(data['myGroup']);
        } else {
          // User left their group — show empty state
          myGroup = FriendCircleGroup(
            groupId: 'defaultGroup',
            groupData: {'name': 'Default Group'},
            members: [],
          );
        }
      });
    }
  }

  @override
  void dispose() {
    AppVariables.unregisterState(this);
    AppVariables.removeListener("posts", _handlePostUpdate);
    AppVariables.removeListener("profile", _handleProfileUpdate);
    _friendCircleAnimationController.dispose();
    _sheetController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Completer<void> profileReady = Completer();

  _getMyprofile() async {
    try {
      final result = await UserService.fetchMyProfile();

      if (result['success']) {
        print('Profile fetched successfully:');
        print(result['data']);
        myProfile = result['data'];
        if (mounted) {
          setState(() {});
        }
        if (result['group'] != null) {
          myGroup = result['group'] as FriendCircleGroup;
          if (mounted) {
            setState(() {});
          }
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
      profileVersion++;
      if (!profileReady.isCompleted) {
        profileReady.complete();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (e.toString().contains("User is not authenticated")) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text("Session Expired"),
                  content:
                      Text("Your session has expired. Please login again."),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await UserService.signOut((b) {});
                        Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ));
                      },
                      child: Text("Login"),
                    ),
                  ],
                ));
      }
    }
  }

  _fetchPosts() async {
    if (!mounted) return;
    if (isLoadingPost) return;
    setState(() {
      isLoadingPost = true;
    });

    await profileReady.future;
    Map<String, dynamic> result = await PostService.fetchMyPosts(
      userid: myProfile?['_id'] ?? "673f607d6fbb68a8c5368967",
      limit: 10,
      next: next,
    );
    if (result['success']) {
      print(result);

      next = result['data']['next'];
      posts.addAll(result['data']['posts']);
      // AppVariables.update("posts", posts);
      if (mounted) {
        setState(() {
          isLoadingPost = false;
          hasMore = next != null;
        });
      }
    } else {
      print(result);
      if (mounted) {
        setState(() {
          isLoadingPost = false;
        });
      }
    }
  }

  void pickimage(context) async {
    String baseurl =
        AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
    ValueNotifier<FileUploadProgress> _progressNotifier =
        ValueNotifier<FileUploadProgress>(
      FileUploadProgress(fileName: 'Uploading...'),
    );

    S3Uploader uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: _progressNotifier,
    );
    bool uploadFinished = false;
    bool showErrorText = false;
    final ImagePicker _picker = ImagePicker();
    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      // Handle the selected image
      images.map((e) => print);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Column(
                  children: [
                    Text(
                      'Uploading image...',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 10),
                    if (showErrorText)
                      Text(
                        'Do not close this dialog until the upload is complete.',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            fontFamily: 'Poppins'),
                      ),
                  ],
                ),
                content:
                    UploadProgressWidget(progressNotifier: _progressNotifier),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      if (uploadFinished == true) {
                        Navigator.of(context).pop();
                      } else {
                        setState(() {
                          showErrorText = true;
                        });
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      );
      List<String> files =
          await uploader.uploadFiles(files: images, compressionParams: {
        'width': 600,
        'quality': 95,
      });
      print(files);
      _progressNotifier.value = _progressNotifier.value.copyWith(
        stage: UploadStage.uploading,
        customStageText: "Processing...",
        customStageTextDetail: "saving on server...",
      );
      Map<String, dynamic> result = await PostService.createPost(
        files: files,
        isGroupPost: false,
        myGroupId: myGroup!.groupId,
      );
      if (result['success']) {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.completed,
          customStageText: "Uploaded Successfully",
          customStageTextDetail: "You are set! now you can close this dialog",
        );
        setState(() {
          posts.add(result['data']);
          uploadFinished = true;
        });
      } else {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload this post",
        );
        setState(() {
          uploadFinished = true;
        });
      }
    }
  }

  String? extractS3Key(String? oldPic) {
    if (oldPic == null || oldPic.isEmpty) return null;

    try {
      // Parse URL and get path without leading '/'
      String path = Uri.parse(oldPic).path;
      if (path.startsWith('/')) path = path.substring(1);

      // Ensure the path starts with 'uploads/'
      if (!path.startsWith('uploads/')) return null;

      return path;
    } catch (e) {
      // Invalid URL or parsing failed
      return null;
    }
  }

  Future<void> editProfilePic(BuildContext context, String? oldPicUrl) async {
    final ImagePicker picker = ImagePicker();

    // 1️⃣ Pick image
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) return;

    final File selectedFile = File(image.path);

    final String baseurl =
        AppVariables.get<String>('baseurl')?.trim() ?? 'http://localhost:3000';

    final progressNotifier = ValueNotifier<FileUploadProgress>(
      FileUploadProgress(fileName: 'Uploading profile picture...'),
    );

    final uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: progressNotifier,
    );

    bool isUploading = false;

    // 2️⃣ Preview + Upload dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Update Profile Picture',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 300,
                child: isUploading
                    ? UploadProgressWidget(
                        progressNotifier: progressNotifier,
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              selectedFile,
                              height: 180,
                              width: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Do you want to upload this picture?',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
              actions: isUploading
                  ? null
                  : [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            isUploading = true;
                          });

                          try {
                            String? oldPicKey = extractS3Key(oldPicUrl);
                            final urls = await uploader.uploadFiles(
                              files: [selectedFile],
                              keys: [oldPicKey ?? ""],
                              sendingKeys: oldPicKey != null ? true : false,
                              compressionParams: {
                                "width": 600,
                              },
                            );

                            if (urls.isEmpty) {
                              throw Exception('Upload failed');
                            }

                            // 4️⃣ Update backend
                            final result = await UserService.updateProfilePic(
                              profilePic: urls.first,
                            );

                            if (result['success'] != true) {
                              throw Exception(
                                result['error'] ?? 'Failed to update profile',
                              );
                            }

                            // 5️⃣ Update local state
                            _getMyprofile();

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              setState(() {});
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e
                                        .toString()
                                        .replaceFirst('Exception: ', ''),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Upload'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 12, 38),
      extendBody: true,
      bottomNavigationBar: AppBottomNav(highlightIndex: 3),
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
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'logout') {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Settings"),
                      content: Text("Do you want to sign out?"),
                      actions: [
                        TextButton(
                          child: Text("Cancel"),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text("Sign Out"),
                          onPressed: () async {
                            //Navigator.of(context).pop();
                            await UserService.signOut((x) => {});
                            Navigator.pushAndRemoveUntil(
                              context,
                              PageTransition(
                                type: PageTransitionType.leftToRight,
                                child: LoginScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              }
              if (value == 'contact') {
                launchUrl(Uri.parse(AppVariables.get<String>('contactUrl') ??
                    "https://chitzchat.com/#contact"));
              }
              if (value == 'privacy') {
                launchUrl(
                    Uri.parse("https://chitzchat.com/privacy-policy.html"));
              }
              if (value == 'delete_account') {
                _showDeleteAccountConfirmation(context);
              }
              if (value == 'blocked_users') {
                _showBlockedUsersList(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                    leading: Icon(Icons.logout), title: Text('Logout')),
              ),
              const PopupMenuItem<String>(
                value: 'contact',
                child: ListTile(
                    leading: Icon(Icons.contact_mail),
                    title: Text('Contact Us')),
              ),
              const PopupMenuItem<String>(
                value: 'privacy',
                child: ListTile(
                    leading: Icon(Icons.privacy_tip),
                    title: Text('Privacy Policy')),
              ),
              const PopupMenuItem<String>(
                value: 'blocked_users',
                child: ListTile(
                    leading: Icon(Icons.block), title: Text('Blocked Users')),
              ),
              const PopupMenuItem<String>(
                value: 'delete_account',
                child: ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: Text('Delete Account',
                        style: TextStyle(color: Colors.red))),
              ),
            ],
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
            child: Center(
              child: myGroup == null
                  ? CircularProgressIndicator() // Show a loader until the group is available
                  : myGroup!.members.length == 0
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
                            SizedBox(height: 10),
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                      context,
                                      PageTransition(
                                          type: PageTransitionType.leftToRight,
                                          child: Recomandedgroups()));
                                },
                                child: Text(
                                  "Create or Join A Group 🚀",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ))
                          ],
                        ))
                      : FriendCircle(
                          group: _getBustedGroup(myGroup!),
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
                            print("Group tapped! ${myGroup!.groupId}");
                            Navigator.push(
                              context,
                              PageTransition(
                                type: PageTransitionType.rightToLeft,
                                child: GroupPrivateViewScreen(),
                              ),
                            );
                          },
                          onMemberTap: (index) {
                            if (index < myGroup!.members.length) {
                              print(
                                  "Member ${myGroup!.members[index].id} tapped!");
                              Navigator.push(
                                context,
                                PageTransition(
                                  type: PageTransitionType.rightToLeft,
                                  child: GroupPrivateViewScreen(),
                                ),
                              );
                            } else {
                              print("Invalid member tapped!");
                            }
                          },
                        ),
            ),
          ),
          // DraggableScrollableSheet for the Bottom Container
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.6, // Default open height
            minChildSize: 0.2, // Allow dragging down further to expand circle
            maxChildSize: 1,
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
                child: myProfile == null
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
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
                                                  imageUrl: _getBustedUrl(
                                                          myProfile?[
                                                              'profilePic']) ??
                                                      "",
                                                  onEdit: () => editProfilePic(
                                                      context,
                                                      myProfile?['profilePic']),
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
                                          backgroundImage: myProfile?[
                                                      'profilePic'] !=
                                                  null
                                              ? NetworkImage(_getBustedUrl(
                                                  myProfile?['profilePic'])!)
                                              : null,
                                          child: myProfile?['profilePic'] ==
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
                                            "${myProfile?['username'] ?? 'No username'}",
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                          Text(
                                            "${myProfile?['name'] ?? 'No Name'}",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[400]),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: () {
                                      CreatePost.show(context,
                                          isGroupPost: false,
                                          isPost: true,
                                          myGroupId: myGroup!.groupId);
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    icon: const Icon(Icons.add,
                                        color: Colors.white),
                                    label: const Text("Post",
                                        style: TextStyle(
                                            fontSize: 16, color: Colors.white)),
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
                            //           final bioList = myProfile?['bio'] ?? [];
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
                            //       myProfile?['bio'].length > 0 &&
                            //               !(myProfile?['bio'] as List)
                            //                   .every((bio) => bio == null)
                            //           ? "#${GroupsService.parseBio(myProfile?['bio'].last).editedBy} ${GroupsService.parseBio(myProfile?['bio'].last).bio}"
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
                                _getEducationField(myProfile ?? {}) ??
                                    "No education",
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
                            if (posts.isEmpty && !isLoadingPost)
                              Center(
                                child: Text("You Didn't Post Yet 😔",
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
                                  if (post?['media'] == null) {
                                    return Container(
                                        key: ValueKey('post-empty-$index'));
                                  } else if (post?['media'].runtimeType ==
                                      String) {
                                    post['media'] = jsonDecode(post['media']);
                                  }
                                  try {
                                    return DynamicPostWidget(
                                      key: ValueKey('post-${post['_id']}'),
                                      borderRadius: 12,
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
                                      showMenu: true,
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

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Request Account Deletion"),
          content: const Text(
              "Are you sure you want to request account deletion? Once requested, you will be logged out and unable to login. An admin will manually remove your account and all related data (posts, comments, etc.)."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteAccount(context);
              },
              child: const Text("Request Deletion",
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const Center(child: CircularProgressIndicator()),
    );

    final navigator = Navigator.of(context);
    UserService.deleteAccount().then((result) {
      if (!mounted) return;
      if (result['success']) {
        UserService.signOut((loading) {}).then((_) {
          if (!mounted) return;
          navigator.pop(); // Close loader using captured navigator
          _showStatusDialog(navigator.context, 'Request Sent',
              'Your deletion request has been sent. Admin will manually remove your account and all related data soon.',
              isError: false);
          Future.delayed(const Duration(seconds: 3), () {
            navigator.pushAndRemoveUntil(
              PageTransition(
                type: PageTransitionType.leftToRight,
                child: LoginScreen(),
              ),
              (route) => false,
            );
          });
        }).catchError((e) {
          if (mounted) {
            navigator.pop();
            _showStatusDialog(navigator.context, 'Error',
                'Error signing out after deletion: $e',
                isError: true);
          }
        });
      } else {
        navigator.pop(); // Close loader using captured navigator
        _showStatusDialog(navigator.context, 'Error',
            result['error'] ?? 'Failed to delete account.',
            isError: true);
      }
    }).catchError((e) {
      if (mounted) {
        navigator.pop(); // Close loader using captured navigator
        _showStatusDialog(
            navigator.context, 'Error', 'An unexpected error occurred: $e',
            isError: true);
      }
    });
  }

  void _showStatusDialog(BuildContext context, String title, String message,
      {required bool isError}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title,
              style: TextStyle(color: isError ? Colors.red : Colors.green)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showBlockedUsersList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 20, 20, 50),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      "Blocked Users",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: "Poppins",
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: UserService.fetchBlockedUsers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError ||
                            snapshot.data?['success'] == false) {
                          return Center(
                            child: Text(
                              snapshot.data?['error'] ??
                                  "Failed to load blocked users",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        final dynamic rawData = snapshot.data?['data'];
                        List blockedUsers = [];
                        if (rawData is List) {
                          blockedUsers = rawData;
                        } else if (rawData is Map &&
                            rawData.containsKey('blockedUsers')) {
                          blockedUsers = rawData['blockedUsers'] is List
                              ? rawData['blockedUsers']
                              : [];
                        }

                        if (blockedUsers.isEmpty) {
                          return const Center(
                            child: Text(
                              "No blocked users",
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: blockedUsers.length,
                          itemBuilder: (context, index) {
                            final user = blockedUsers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['profilePic'] != null
                                    ? CachedNetworkImageProvider(
                                        user['profilePic'])
                                    : null,
                                child: user['profilePic'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                user['name'] ??
                                    user['username'] ??
                                    "Unknown User",
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                "@${user['username'] ?? ''}",
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              trailing: TextButton(
                                onPressed: () => _unblockUser(context,
                                    user['_id'], () => setModalState(() {})),
                                child: const Text("Unblock",
                                    style: TextStyle(color: Colors.red)),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _unblockUser(
      BuildContext context, String userId, VoidCallback onUnblocked) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const Center(child: CircularProgressIndicator()),
    );

    final navigator = Navigator.of(context);
    UserService.unblockUser(userId: userId).then((result) {
      if (!mounted) return;
      navigator.pop(); // Close loader
      if (result['success']) {
        onUnblocked();
        _showStatusDialog(
            navigator.context, 'Success', 'User unblocked successfully!',
            isError: false);
      } else {
        _showStatusDialog(navigator.context, 'Error',
            result['error'] ?? 'Failed to unblock user.',
            isError: true);
      }
    }).catchError((e) {
      if (mounted) {
        navigator.pop();
        _showStatusDialog(navigator.context, 'Error',
            'An error occurred while unblocking user.',
            isError: true);
      }
    });
  }
}
