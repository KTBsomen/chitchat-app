// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'dart:math';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/services/fileUploader.dart';
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getMyprofile();
    _fetchPosts();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 100 &&
          !isLoadingPost &&
          hasMore) {
        _fetchPosts();
      }
    });
  }

  _getMyprofile() async {
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

  _fetchPosts() async {
    if (isLoadingPost) return;
    setState(() {
      isLoadingPost = true;
    });
    Map<String, dynamic> result = await PostService.fetchMyPosts(
      userid: "673f607d6fbb68a8c5368967",
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

  pickimage(context) async {
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
                color: Colors.white,
                iconSize: 30,
                padding: const EdgeInsets.only(right: 20),
              ),
              Positioned(
                right: 20,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.messenger_outline_rounded),
                onPressed: () {},
                color: Colors.white,
                iconSize: 30,
                padding: const EdgeInsets.only(right: 30),
              ),
              Positioned(
                right: 25,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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
                          group: myGroup!,
                          size: 200,
                          nodeSize: (myGroup!.members.length > 5
                              ? myGroup!.members.length * 10.0
                              : 90.0),
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
                child: isLoadingPost
                    ? Center(
                        child: CircularProgressIndicator(),
                      )
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
                                      CircleAvatar(
                                        radius: 35,
                                        backgroundColor: Colors.orange,
                                        backgroundImage:
                                            myProfile?['profilePic'] != null
                                                ? NetworkImage(
                                                    myProfile?['profilePic'])
                                                : null,
                                        child: myProfile?['profilePic'] == null
                                            ? Icon(Icons.person,
                                                color: Colors.white)
                                            : null, // Avoid overlapping the icon if there's an image
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
                                    onPressed: () => pickimage(context),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: Text(
                                "${myProfile?['bio'] ?? 'No bio available'}",
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
                            if (posts.isEmpty)
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
