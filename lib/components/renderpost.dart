import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/store.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/comments.dart';
import 'package:chitchat/components/like.dart';
import 'package:chitchat/components/simpleaudioplayer.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:event_handeler/event_handeler.dart';

class DynamicPostWidget extends StatefulWidget {
  final String content;
  final List<Map<String, dynamic>> media;
  final String postId;
  final String author;
  final String group;
  final String? authorName;
  final String? profilePic;
  final double borderRadius;
  final int likes;

  DynamicPostWidget({
    required this.content,
    required this.media,
    required this.postId,
    required this.author,
    required this.group,
    this.authorName,
    this.profilePic,
    this.borderRadius = 12,
    this.likes = 0,
  });

  @override
  State<DynamicPostWidget> createState() => _DynamicPostWidgetState();
}

class _DynamicPostWidgetState extends State<DynamicPostWidget> {
  List<Comment> comments = [];
  List<Comment> posts = [];
  Map<String, dynamic> myProfile =
      AppVariables.get<Map<String, dynamic>>('profile') ?? {};
  bool isPanning = false;
  bool isLoading = true;
  void pickimage(context, TextEditingController commentController,
      {String filetype = "image"}) async {
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
    List<XFile>? images = [];

    if (filetype == "image") {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      images = image != null ? [image] : [];
    } else if (filetype == "video") {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      images = video != null ? [video] : [];
    } else {
      images = await _picker.pickMultipleMedia();
    }

    if (images.isNotEmpty) {
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
        'quality': 85,
      });
      print(files);
      _progressNotifier.value = _progressNotifier.value.copyWith(
        stage: UploadStage.uploading,
        customStageText: "Processing...",
        customStageTextDetail: "saving on server...",
      );
      Map<String, dynamic> result = await PostService.createComment(
        files: files,
        postId: widget.postId,
        comment:
            commentController.text.isEmpty ? "..." : commentController.text,
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
        _getComments();
      } else {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload this post",
        );
        setState(() {
          uploadFinished = true;
        });
        _getComments();
      }
    }
  }

  Future<void> _initializeProfile() async {
    final storedProfile =
        AppVariables.get<Map<String, dynamic>>('profile') ?? {};

    if (storedProfile.isNotEmpty) {
      setState(() {
        myProfile = storedProfile;
        isLoading = false;
      });
    } else {
      final fetchedProfile = await UserService.fetchMyProfile();
      if (fetchedProfile['success']) {
        setState(() {
          myProfile = fetchedProfile['data'];
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    AppVariables.registerState(this);
    //initStores();
  }

  bool isCommentsAreLoading = false;
  bool hasMoreComments = true;
  String? lastCommentId;
//get comments
  Future<void> _getComments() async {
    if (isCommentsAreLoading) return;
    if (!mounted) return;
    setState(() {
      isCommentsAreLoading = true;
    });

    try {
      final fetchedComments = await PostService.fetchComments(widget.postId,
          limit: 20, lastId: lastCommentId);
      print(fetchedComments);
      if (mounted) {
        setState(() {
          if (comments.isNotEmpty &&
              !comments.contains(fetchedComments["comments"])) {
            comments.addAll(fetchedComments["comments"]);
            lastCommentId = fetchedComments["lastId"];
            hasMoreComments = fetchedComments["hasMore"];
          } else {
            comments = fetchedComments["comments"];

            lastCommentId = fetchedComments["lastId"];
            hasMoreComments = fetchedComments["hasMore"];
          }
          // comments = fetchedComments;
        });
      }
      dispatchCustomEvent([comments, isCommentsAreLoading], "comments");
    } catch (e) {
      print('Failed to fetch comments: $e');
    } finally {
      if (mounted) {
        setState(() {
          isCommentsAreLoading = false;
        });
      }
      dispatchCustomEvent([comments, isCommentsAreLoading], "comments");
    }
  }

  // Method to handle dynamic media rendering based on type
  Widget _buildMediaContent(Map<String, dynamic> mediaItem) {
    switch (mediaItem['type']) {
      case 'image':
        return Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: mediaItem['url']!,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color:
                      Colors.black.withOpacity(0.2), // Optional overlay color
                ),
              ),
            ),
            GestureDetector(
              onDoubleTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    barrierDismissible: true,
                    pageBuilder: (BuildContext context, _, __) {
                      return ZoomableImagePopup(
                        imageUrl: mediaItem['url']!,
                        onEdit: null,
                        onClose: () => Navigator.of(context).pop(),
                      );
                    },
                  ),
                );
              },
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: mediaItem['url']!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      case 'video':
        return _buildVideoPlayer(mediaItem['url']!);
      case 'audio':
        return SimpleAudioPlayer(
            title: "Audio", audioUrl: mediaItem['url'], artist: 'unknown');
      default:
        return const SizedBox.shrink(); // Handle unsupported types
    }
  }

  // You can extend this for any video, not just YouTube
  Widget _buildVideoPlayer(String url) {
    if (url.contains('youtube.com')) {
      return YoutubePlayer(
        controller: YoutubePlayerController(
          initialVideoId: YoutubePlayer.convertUrlToId(url)!,
          flags: const YoutubePlayerFlags(
              autoPlay: false,
              disableDragSeek: true,
              showLiveFullscreenButton: false),
        ),
      );
    } else {
      return VideoWidget(url: url);
    }
  }

  bool showFileOptions = false; // Controls animation visibility

  void toggleFileOptions() {
    setState(() {
      showFileOptions = !showFileOptions;
    });
  }

  // Open BottomSheet with media slider
  void _openBottomSheet(BuildContext context) {
    StreamSubscription? subscription;
    int mediaIndex = 1;
    bool isCommenting = false;
    comments = [];
    _getComments();
    showModalBottomSheet(
      enableDrag: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          if (mounted) {
            subscription ??= addCustomEventListener("comments", (data) {
              if (mounted) {
                setState(() {
                  comments = data[0];
                  isCommentsAreLoading = data[1];
                });
              }
            });
          }
          ;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                var commentController = TextEditingController();
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Main content
                      Expanded(
                        child: NotificationListener<ScrollEndNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.extentAfter == 0 &&
                                hasMoreComments) {
                              _getComments();
                            }
                            return true;
                          },
                          child: CustomScrollView(
                            controller: scrollController,
                            slivers: [
                              // Collapsible media section
                              SliverAppBar(
                                backgroundColor: Colors.transparent,
                                pinned: true,
                                expandedHeight: 400,
                                automaticallyImplyLeading: false,
                                flexibleSpace: FlexibleSpaceBar(
                                  background: PageView.builder(
                                    onPageChanged: (value) {
                                      setState(() {
                                        mediaIndex = value + 1;
                                      });
                                    },
                                    itemCount: widget.media.length,
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        child: _buildMediaContent(
                                            widget.media[index]),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              // Comments list
                              SliverToBoxAdapter(
                                  child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: LikeButton(
                                          buttonType: ButtonType.post,
                                          postId: widget.postId,
                                          initialLikes: widget.likes,
                                          initiallyLiked: false,
                                          onLikeChanged: (isLiked) async {
                                            Map<String, dynamic> result =
                                                await PostService
                                                    .toggleLikeOnPost(
                                                        widget.postId);
                                            if (result["success"] && mounted) {
                                              setState(() {
                                                // Update the like count and state based on the result
                                              });
                                              return true;
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          result["message"])));
                                              return false;
                                            }
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          "$mediaIndex/${widget.media.length}",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text('Comments',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ]),
                                ],
                              )),
                              comments.isEmpty && !isCommentsAreLoading
                                  ? SliverToBoxAdapter(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 100),
                                        child: Center(
                                          child: Text('No comments yet',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white)),
                                        ),
                                      ),
                                    )
                                  : SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        childCount: comments.length,
                                        (context, index) {
                                          final comment = comments[index];
                                          bool likefound = false;

                                          return ListTile(
                                            isThreeLine: true,
                                            leading: CircleAvatar(
                                                backgroundImage: NetworkImage(
                                                    comment.profilePic)),
                                            title: Text(comment.authorName,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white54,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            //TODO: Add like functionality
                                            trailing: LikeButton(
                                              postId: comment.Id,
                                              buttonType: ButtonType.comment,
                                              initialLikes: comment.likes,
                                              initiallyLiked: likefound,
                                              onLikeChanged: (isLiked) async {
                                                print(comment.Id);
                                                Map<String, dynamic> result =
                                                    await PostService
                                                        .toggleLikeOnComment(
                                                            comment.Id);
                                                print(result);

                                                if (result["success"] &&
                                                    mounted) {
                                                  setState(() {});
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(result[
                                                              "message"])));
                                                  if (result["status"] ==
                                                      "unliked") {
                                                    return false;
                                                  } else {
                                                    return true;
                                                  }
                                                } else {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(SnackBar(
                                                          content: Text(result[
                                                              "message"])));
                                                  return false;
                                                }
                                              },
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(comment.content,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                    )),
                                                const SizedBox(height: 8),
                                                Text(comment.timeAgo,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white54,
                                                    )),
                                                const SizedBox(height: 8),
                                                CommentMedia(
                                                    media: comment.media),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                              // Bottom padding for input field
                              const SliverPadding(
                                padding: EdgeInsets.only(bottom: 70),
                              ),
                              if (isCommentsAreLoading)
                                SliverToBoxAdapter(
                                  child: Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 1),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      // Fixed comment input at bottom
                      AnimatedContainer(
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: Color.fromARGB(111, 67, 67, 148),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            )),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastEaseInToSlowEaseOut,
                        height: showFileOptions ? 100 : 0, // Expand when active
                        width: MediaQuery.of(context)
                            .size
                            .width, // Same width as the attach button
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Handle image picker
                                  pickimage(context, commentController);
                                },
                                child: CircleAvatar(
                                  radius:
                                      28, // Adjust size for a prominent look
                                  backgroundColor:
                                      Colors.green[600], // Strong contrast
                                  child: const Icon(Icons.image,
                                      color: Colors.white, size: 28),
                                ),
                              ),
                              const SizedBox(
                                  width: 12), // Adds spacing between icons
                              GestureDetector(
                                onTap: () {
                                  // Handle video picker
                                  pickimage(context, commentController,
                                      filetype: "video");
                                },
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      Colors.red[600], // Eye-catching contrast
                                  child: const Icon(Icons.video_library,
                                      color: Colors.white, size: 28),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  // Handle document picker
                                  pickimage(context, commentController,
                                      filetype: "document");
                                },
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      Colors.blue[600], // Professional contrast
                                  child: const Icon(Icons.insert_drive_file,
                                      color: Colors.white, size: 28),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(0, -2),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            IconButton(
                                onPressed: () {
                                  setState(() {
                                    showFileOptions = !showFileOptions;
                                  });
                                },
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: AppColors.surface,
                                )),
                            Expanded(
                              child: TextField(
                                controller: commentController,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  filled: true,
                                  //fillColor: Colors.grey[100],
                                ),
                              ),
                            ),
                            isCommenting
                                ? CircularProgressIndicator()
                                : IconButton(
                                    icon: const Icon(Icons.send,
                                        color: AppColors.success),
                                    onPressed: () async {
                                      if (commentController.text.isNotEmpty) {
                                        setState(() {
                                          isCommenting = true;
                                        });
                                        // comments.add(Comment(
                                        //   Id: DateTime.now()
                                        //       .millisecondsSinceEpoch
                                        //       .toString(),
                                        //   content: commentController.text,
                                        //   postId: widget.postId,
                                        //   media: [],
                                        //   createdAt: DateTime.now(),
                                        //   likes: 0,
                                        //   author: myProfile['_id'],
                                        //   authorName: myProfile['name'],
                                        //   profilePic: myProfile['profilePic'],
                                        // ));
                                        Map<String, dynamic> result =
                                            await PostService.createComment(
                                          comment: commentController.text,
                                          files: [],
                                          postId: widget.postId,
                                        );
                                        print(result);
                                        if (result['success']) {
                                          print('Comment created successfully');
                                          setState(() {
                                            comments.add(result['data']);
                                            comments =
                                                comments.reversed.toList();
                                          });
                                        } else {
                                          print('Failed to create comment');
                                        }

                                        commentController.clear();
                                        setState(() {
                                          isCommenting = false;
                                        });
                                      }
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    ).whenComplete(() {
      subscription?.cancel();
      subscription = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
    // EventManager().dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openBottomSheet(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            CachedNetworkImage(
                imageUrl: widget.media[0]['url'] ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                      height: 200,
                      color: const Color(0xFF2A2A2A),
                    ),
                errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: const Color(0xFF2A2A2A),
                    child: const Center(
                      child: Icon(Icons.error),
                    ))),
            Positioned(
                top: 5,
                left: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: widget.profilePic != null
                                ? CachedNetworkImageProvider(widget.profilePic!)
                                : null,
                            child: widget.profilePic != null
                                ? null
                                : const Icon(Icons.person,
                                    size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Text('${widget.authorName ?? ""}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 3.0,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ])),
                        ],
                      ),
                    ),
                  ),
                )),
            Positioned(
                top: 5,
                right: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text('1/${widget.media.length}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 3.0,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ])),
                        ],
                      ),
                    ),
                  ),
                ))
          ],
        ),
      ),
    );
    //  Card(
    //     margin: EdgeInsets.all(8.0),
    //     child: Padding(
    //       padding: const EdgeInsets.all(16.0),
    //       child: Column(
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [
    //           Text(content,
    //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    //           SizedBox(height: 8),
    //           ElevatedButton(
    //             onPressed: () => _openBottomSheet(context),
    //             child: Text('Open Media'),
    //           ),
    //           SizedBox(height: 8),
    //           // Additional dynamic content like author, group info, etc.
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Text('Author: $author'),
    //               Text('Group: $group'),
    //             ],
    //           ),
    //         ],
    //       ),
    //     ),
    //   );
  }
}

class PostList extends StatelessWidget {
  final List<Map<String, dynamic>> posts;

  PostList({required this.posts});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: posts.length,
      cacheExtent: 1000, // Cache extra content
      itemBuilder: (context, index) {
        final post = posts[index];
        return DynamicPostWidget(
          content: post['content'],
          media: List<Map<String, String>>.from(post['media'].map((m) => {
                'type': m['type'],
                'url': m['url'],
              })),
          postId: post['_id'],
          author: post['author'],
          group: post['group'],
          authorName: post['authorName'],
          profilePic: post['profilePic'],
        );
      },
    );
  }
}
