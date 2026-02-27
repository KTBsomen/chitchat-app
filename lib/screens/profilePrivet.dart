import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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

import '../components/friendcircle.dart';

class PrivetProfilePage extends StatefulWidget {
  const PrivetProfilePage({super.key});

  @override
  State<PrivetProfilePage> createState() => _PrivetProfilePageState();
}

class _PrivetProfilePageState extends State<PrivetProfilePage> {
  FriendCircleGroup? myGroup;
  Map<String, dynamic>? myProfile;
  final ScrollController _scrollController = ScrollController();
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
        posts.add(value);
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
    _getMyprofile();
    _fetchPosts();
    AppVariables.registerState(this);
    AppVariables.addListener<Map<String, dynamic>>("posts", _handlePostUpdate);
    AppVariables.addListener("deleted_posts", _handlePostDelete);
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

  @override
  void dispose() {
    AppVariables.unregisterState(this);
    AppVariables.removeListener("posts", _handlePostUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  Completer<void> profileReady = Completer();

  _getMyprofile() async {
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
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: () {
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
            },
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
            height: MediaQuery.of(context).size.height * 0.3,
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
                          size: 200,
                          nodeSize: (myGroup!.members.length > 5
                              ? myGroup!.members.length * 8.0
                              : 80.0),
                          nodeBorderColor: Colors.white24,
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
            initialChildSize: 0.6, // Default open height (50% of the screen)
            minChildSize: 0.6, // Minimum height (cannot be dragged below 50%)
            maxChildSize: 1, // Maximum height (90% of the screen)
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
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            "${myProfile?['name'] ?? 'No Name'}",
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey),
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
                                    color: AppColors.background,
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
                                          color: Colors.black)),
                                ],
                              ),
                            ),
                            SizedBox(height: 10),
                            if (posts.isEmpty && !isLoadingPost)
                              Center(
                                child: Text("You Didn't Post Yet 😔",
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
