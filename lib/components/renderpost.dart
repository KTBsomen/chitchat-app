import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/comments.dart';
import 'package:chitchat/components/like.dart';
import 'package:chitchat/components/relatedpost.dart';
import 'package:chitchat/components/simpleaudioplayer.dart';
import 'package:chitchat/components/feedVideoPlayer.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/notifications.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/notification.dart';
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
  final String? group;
  final bool? isGroupPost;
  final String? authorName;
  final String? profilePic;
  final double borderRadius;
  final int likes;
  final int comments;
  final bool? showAuthor;
  final bool? showCount;
  final bool? showMenu;
  final bool? showMenuInPreview;
  final bool? public;
  final Function? onRefresh;
  final bool isFullPage;
  final String? initialCommentId;
  final Map<String, dynamic>? initialCommentData;

  DynamicPostWidget({
    Key? key,
    required this.content,
    required this.media,
    required this.postId,
    required this.author,
    this.group,
    this.authorName,
    this.profilePic,
    this.borderRadius = 12,
    this.likes = 0,
    this.comments = 0,
    this.showAuthor = false,
    this.showCount = false,
    this.public = true,
    this.showMenu = false,
    this.showMenuInPreview = false,
    this.onRefresh,
    this.isGroupPost,
    this.isFullPage = false,
    this.initialCommentId,
    this.initialCommentData,
  }) : super(key: key);

  @override
  State<DynamicPostWidget> createState() => _DynamicPostWidgetState();
}

class _DynamicPostWidgetState extends State<DynamicPostWidget> {
  List<Comment> comments = [];
  List<Comment> posts = [];
  int _commentCount = 0;
  Map<String, dynamic> myProfile =
      AppVariables.get<Map<String, dynamic>>('profile') ?? {};
  bool isPanning = false;
  bool isLoading = true;
  int mediaIndex = 1;
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
                    const Text(
                      'Uploading image...',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 10),
                    if (showErrorText)
                      const Text(
                        'Do not close this dialog until the upload is complete.',
                        style: TextStyle(
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
          _commentCount++;
        });
        this.setState(() {});
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
    _initializeProfile();
    AppVariables.registerState(this);
    _commentCount = widget.comments;
    if (widget.initialCommentId != null &&
        widget.initialCommentId!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCommentSheet(context);
      });
    }
  }

  final ValueNotifier<List<NotificationModel>> notificationsNotifier =
      ValueNotifier([]);
  bool _isLoading = false;
  void _getNotifications() async {
    if (widget.public == true) {
      return;
    }
    List<Map<String, dynamic>> jsonData =
        (await NotificationService.getGroupPostRequests(context, widget.postId,
            showLoaders: false))!;
    print("jsonData: $jsonData");

    if (mounted) {
      setState(() {
        notificationsNotifier.value =
            jsonData.map((data) => NotificationModel.fromJson(data)).toList();

        _isLoading = false;
      });
    }
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
          final incoming = fetchedComments["comments"] as List<Comment>;
          if (comments.isNotEmpty) {
            // Deduplicate: only add comments not already in the list
            final existingIds = comments.map((c) => c.Id).toSet();
            final uniqueIncoming =
                incoming.where((c) => !existingIds.contains(c.Id)).toList();

            comments.addAll(uniqueIncoming);
            _commentCount = comments.length;
            lastCommentId = fetchedComments["lastId"];
            hasMoreComments = fetchedComments["hasMore"];
          } else {
            if (incoming.length > comments.length) {
              _commentCount = incoming.length;
            }
            comments = incoming;
            lastCommentId = fetchedComments["lastId"];
            hasMoreComments = fetchedComments["hasMore"];
          }
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
                  color: Colors.black
                      .withValues(alpha: 0.2), // Optional overlay color
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
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
                child: CachedNetworkImage(
                  imageUrl: mediaItem['url']!,
                  fit: BoxFit.fitWidth,
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

  Widget _buildDetailedView(ScrollController? scrollController) {
    ScrollController effectiveController =
        scrollController ?? ScrollController();
    _getNotifications();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bottomSheetBackground,
        borderRadius: widget.isFullPage
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(20)),
        border: widget.isFullPage
            ? null
            : Border.all(color: AppColors.bottomSheetBorder, width: 0.5),
      ),
      child: Column(
        children: [
          if (!widget.isFullPage)
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
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // Collapsible media section
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  pinned: true,
                  expandedHeight: widget.isFullPage ? 400 : 500,
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
                          child: _buildMediaContent(widget.media[index]),
                        );
                      },
                    ),
                  ),
                ),
                //likes comments
                if (widget.public == false)
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildPrivateHeader(),
                        _buildVotingSection(),
                      ],
                    ),
                  )
                else
                  RelatedPostsWidget(
                    postId: widget.postId,
                    authorId: widget.author,
                    profilePic: widget.profilePic ?? "",
                    authorName: widget.authorName ?? "",
                    scrollController: effectiveController,
                    isGroupPost: widget.isGroupPost,
                    showMoreButton: widget.showMenu != null && widget.showMenu!
                        ? () {
                            _openMore(context);
                          }
                        : null,
                    middleItem: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
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
                                      await PostService.toggleLikeOnPost(
                                          widget.postId);
                                  if (result["success"] && mounted) {
                                    return true;
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(result["message"])));
                                    return false;
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: Row(
                                children: [
                                  const Icon(Icons.comment,
                                      color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    _commentCount.toString(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                              onPressed: () => _openCommentSheet(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      enableDrag: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.3,
              maxChildSize: 1,
              builder: (context, scrollController) {
                return _buildDetailedView(scrollController);
              },
            ),
          );
        });
      },
    );
  }

  // Open BottomSheet with media slider
  void _openCommentSheet(BuildContext context) {
    StreamSubscription? subscription;
    int mediaIndex = 1;
    bool isCommenting = false;
    comments = [];
    if (widget.initialCommentId != null && widget.initialCommentData != null) {
      try {
        final data = widget.initialCommentData!;
        // Construct a safe Comment object
        final prefilled = Comment(
          Id: data['_id']?.toString() ?? widget.initialCommentId!,
          author: data['author']?.toString() ?? '',
          postId: data['post']?.toString() ?? widget.postId,
          content: data['content']?.toString() ?? '',
          authorName: data['authorName']?.toString() ?? 'User',
          profilePic: data['profilePic']?.toString() ?? '',
          media: (data['media'] as List?)
                  ?.map((m) => Media.fromJson(m as Map<String, dynamic>))
                  .toList() ??
              [],
          likes: data['likes'] as int? ?? 0,
          createdAt: data['createdAt'] != null
              ? DateTime.parse(data['createdAt'])
              : DateTime.now(),
        );
        comments.add(prefilled);
      } catch (e) {
        print('Error pre-filling comment: $e');
      }
    }
    ScrollController? activeScrollController;
    bool haveScrolledToInitial = false;
    _getComments();
    var commentController = TextEditingController();
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
                final newComments = data[0] as List<Comment>;
                setState(() {
                  comments = newComments;
                  isCommentsAreLoading = data[1] as bool;
                });

                // Auto-scroll to highlighted comment if present
                if (!haveScrolledToInitial &&
                    widget.initialCommentId != null &&
                    widget.initialCommentId!.isNotEmpty) {
                  final index = newComments
                      .indexWhere((c) => c.Id == widget.initialCommentId);
                  if (index != -1) {
                    haveScrolledToInitial = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      try {
                        // Approximate scroll to the item
                        if (activeScrollController != null &&
                            activeScrollController!.hasClients) {
                          activeScrollController!.animateTo(
                            index * 120.0, // Rough estimate of comment height
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                          );
                        }
                      } catch (e) {
                        print('Error scrolling to comment: $e');
                      }
                    });
                  }
                }
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
              maxChildSize: 1,
              builder: (context, scrollController) {
                activeScrollController = scrollController;
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
                            cacheExtent:
                                1000, // Pre-render some items for smoother scrolling
                            slivers: [
                              // Comments list
                              const SliverToBoxAdapter(
                                  child: Column(
                                children: [
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
                                        child: const Center(
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
                                          final isHighlighted =
                                              widget.initialCommentId ==
                                                  comment.Id;

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: isHighlighted
                                                  ? Colors.blue.withOpacity(0.1)
                                                  : null,
                                              border: isHighlighted
                                                  ? const Border(
                                                      left: BorderSide(
                                                          color: Colors.blue,
                                                          width: 4))
                                                  : null,
                                            ),
                                            child: ListTile(
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
                                                    ScaffoldMessenger.of(
                                                            context)
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
                                                    ScaffoldMessenger.of(
                                                            context)
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
                                    child: const Center(
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
                              color: Colors.black.withValues(alpha: 0.1),
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
                                ? const CircularProgressIndicator()
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
                                            _commentCount++;
                                          });
                                          // Update parent state as well
                                          this.setState(() {});
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

// ValueNotifiers for reactive updates

  ValueNotifier<double> votesNotifier = ValueNotifier<double>(0);
  bool _hasInitializedVotes =
      false; // Track if votes have been initialized from API

  int get totalMembers {
    return notificationsNotifier.value.isNotEmpty
        ? notificationsNotifier.value.last.totalMembers
        : 0;
  }

  double get _voteProgress {
    if (totalMembers == 0) return 0.0;
    return (votesNotifier.value / totalMembers).clamp(0.0, 1.0);
  }

// Get progress for majority (>50% of total members)
  double get _majorityProgress {
    if (totalMembers == 0) return 0.0;
    final majorityNeeded = (totalMembers / 2) + 1;
    return (votesNotifier.value / majorityNeeded).clamp(0.0, 1.0);
  }

  void _handleVote() async {
    votesNotifier.value += 1;
    bool success = await NotificationService.vote(
        context, notificationsNotifier.value.last.id, onRefresh: () {
      if (widget.onRefresh != null) {
        widget.onRefresh!(widget.postId);
      }
      setState(() {
        notificationsNotifier.value = notificationsNotifier.value;
      });
    });
    if (!success) {
      votesNotifier.value -= 1; // Revert if vote failed
    }
    print("valuenotier==== ${votesNotifier.value}, sucess =$success");
  }

  Widget _buildPrivateHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundImage: widget.profilePic != null
                    ? NetworkImage(widget.profilePic!)
                    : null,
                child: widget.profilePic == null
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                widget.authorName ?? "",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (widget.showMenu == true)
            GestureDetector(
              onTap: () => _openMore(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.more_vert, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildVotingSection() {
    return ValueListenableBuilder<List<NotificationModel>>(
      valueListenable: notificationsNotifier,
      builder: (context, notifications, _) {
        if (notifications.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Only initialize votesNotifier once from API data
        if (!_hasInitializedVotes) {
          votesNotifier.value = notifications.last.votes.toDouble();
          _hasInitializedVotes = true;
        }
        return _buildvotingSectionUI();
      },
    );
  }

  Widget _buildvotingSectionUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ValueListenableBuilder<double>(
        valueListenable: votesNotifier,
        builder: (context, votes, child) {
          final majorityProgress = _majorityProgress;
          final isNearMajority = majorityProgress >= 0.8;
          final isMajority = majorityProgress >= 1.0;

          return Column(
            children: [
              // Combined Button-ProgressBar with Animation
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _handleVote,
                    borderRadius: BorderRadius.circular(12),
                    splashColor:
                        AppColors.Secondarybackground.withValues(alpha: 0.3),
                    highlightColor:
                        AppColors.Secondarybackground.withValues(alpha: 0.1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMajority
                              ? Colors.green.withValues(alpha: 0.5)
                              : AppColors.Secondarybackground.withValues(
                                  alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isMajority
                                    ? Colors.green
                                    : AppColors.Secondarybackground)
                                .withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            // Background with subtle pattern
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),

                            // Animated Progress fill
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutCubic,
                              width: MediaQuery.of(context).size.width *
                                  majorityProgress,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isMajority
                                      ? [
                                          Colors.green[400]!
                                              .withValues(alpha: 0.8),
                                          Colors.green[500]!,
                                        ]
                                      : isNearMajority
                                          ? [
                                              AppColors.Secondarybackground
                                                  .withValues(alpha: 0.6),
                                              AppColors.Secondarybackground
                                                  .withValues(alpha: 0.9),
                                            ]
                                          : [
                                              AppColors.Secondarybackground
                                                  .withValues(alpha: 0.3),
                                              AppColors.Secondarybackground
                                                  .withValues(alpha: 0.6),
                                            ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                            ),

                            // Shimmer effect when near majority
                            if (isNearMajority && !isMajority)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 1000),
                                opacity: 0.6,
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(alpha: 0.4),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                      stops: const [0.0, 0.5, 1.0],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ),

                            // Button content with dynamic colors
                            Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: majorityProgress > 0.4
                                      ? Colors.white
                                      : AppColors.Secondarybackground,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Icon(
                                        isMajority
                                            ? Icons.check_circle
                                            : Icons.touch_app,
                                        key: ValueKey(isMajority),
                                        size: 20,
                                        color: majorityProgress > 0.4
                                            ? Colors.white
                                            : AppColors.Secondarybackground,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: Text(
                                        isMajority
                                            ? 'Majority Reached!'
                                            : 'Tap in (${votes.toInt()})',
                                        key: ValueKey(isMajority),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Ripple effect overlay
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _handleVote,
                                  borderRadius: BorderRadius.circular(12),
                                  splashColor:
                                      Colors.white.withValues(alpha: 0.3),
                                  highlightColor:
                                      Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Progress info with better styling
              Column(
                children: [
                  Text(
                    '${votes.toInt()} / ${((totalMembers / 2) + 1).ceil()} votes for majority',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isMajority) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${(((totalMembers / 2) + 1).ceil() - votes.toInt())} more needed • ${totalMembers} total members',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      '🎉 Decision can proceed with majority support',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[600],
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

// Don't forget to dispose the ValueNotifier
  @override
  void dispose() {
    votesNotifier.dispose();
    super.dispose();
  }

  void _openMore(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.author == myProfile['_id']) ...[
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text("Delete"),
                    onTap: () {
                      Navigator.pop(context); // Close dialog
                      _showDeleteConfirmation(context);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.report, color: Colors.orange),
                    title: const Text("Report Post"),
                    onTap: () {
                      Navigator.pop(context);
                      _showReportDialog(context, "post");
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.red),
                    title: const Text("Block User"),
                    onTap: () {
                      Navigator.pop(context);
                      _showBlockConfirmation(context);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFullPage) {
      return _buildDetailedView(null);
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _openBottomSheet(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            if (widget.media.first['type'] == 'video')
              FittedBox(
                child: FeedVideoPlayer(
                  url: widget.media[0]['url'] ?? '',
                  onTap: () => _openBottomSheet(context),
                ),
              )
            else
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
            if (widget.showAuthor != null && widget.showAuthor == true)
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
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: widget.profilePic != null
                                  ? NetworkImage(widget.profilePic!)
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
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                      ),
                                    ])),
                          ],
                        ),
                      ),
                    ),
                  )),
            if (widget.showCount != null && widget.showCount == true)
              widget.media.length == 1
                  ? const SizedBox.shrink()
                  : Positioned(
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
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Text("1/${widget.media.length}",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: const Offset(0, 1),
                                            blurRadius: 3.0,
                                            color: Colors.black
                                                .withValues(alpha: 0.5),
                                          ),
                                        ])),
                              ],
                            ),
                          ),
                        ),
                      )),
            if (widget.public == false)
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
                          color: Colors.red.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text("Private",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 1),
                                        blurRadius: 3.0,
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                      ),
                                    ])),
                          ],
                        ),
                      ),
                    ),
                  )),
            if (widget.showMenu == true && (widget.showMenuInPreview ?? false))
              Positioned(
                  bottom: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: () {
                      _openMore(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.more_vert, color: Colors.white),
                        ],
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Post"),
          content: const Text("Are you sure you want to delete this post?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close confirmation
                _deletePost(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _deletePost(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const Center(child: CircularProgressIndicator()),
    );

    final navigator = Navigator.of(context);
    PostService.deletePost(widget.postId).then((result) {
      if (!mounted) return;
      navigator.pop(); // Close loader using captured navigator
      if (result['success'] == true) {
        AppVariables.update('deleted_posts', widget.postId);
        _showStatusDialog(navigator.context, 'Success', 'Post deleted successfully!', isError: false);
      } else {
        _showStatusDialog(navigator.context, 'Error', result['error'] ?? 'Failed to delete post', isError: true);
      }
    }).catchError((e) {
      if (mounted) {
        navigator.pop();
        _showStatusDialog(navigator.context, 'Error', 'An error occurred while deleting the post', isError: true);
      }
    });
  }

  void _showReportDialog(BuildContext context, String type) {
    final List<String> reasons = [
      "Spam",
      "Inappropriate Content",
      "Harassment",
      "False Information",
      "Other"
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Report $type"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: reasons.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(reasons[index]),
                  onTap: () {
                    Navigator.pop(context);
                    _submitReport(context, reasons[index]);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _submitReport(BuildContext context, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const Center(child: CircularProgressIndicator()),
    );

    final navigator = Navigator.of(context);
    PostService.reportPost(postId: widget.postId, reason: reason).then((result) {
      if (!mounted) return;
      navigator.pop(); // Close loader using captured navigator
      if (result['success']) {
        _showStatusDialog(navigator.context, 'Report Result', 'Report submitted. Thank you for your feedback.', isError: false);
      } else {
        _showStatusDialog(navigator.context, 'Report failed', 'Failed to submit report. Please try again.', isError: true);
      }
    }).catchError((e) {
      if (mounted) {
        navigator.pop();
        _showStatusDialog(navigator.context, 'Error', 'An error occurred while submitting report.', isError: true);
      }
    });
  }

  void _showStatusDialog(BuildContext context, String title, String message, {required bool isError}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green)),
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

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Block User"),
          content: const Text(
              "Are you sure you want to block this user? You will no longer see their posts or messages."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _blockUser(context);
              },
              child: const Text("Block", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _blockUser(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          const Center(child: CircularProgressIndicator()),
    );

    final navigator = Navigator.of(context);
    UserService.blockUser(userId: widget.author).then((result) {
      if (!mounted) return;
      navigator.pop(); // Close loader using captured navigator
      if (result['success']) {
        _showStatusDialog(navigator.context, 'Success', 'User blocked.', isError: false);
      } else {
        _showStatusDialog(navigator.context, 'Error', 'Failed to block user.', isError: true);
      }
    }).catchError((e) {
      if (mounted) {
        navigator.pop();
        _showStatusDialog(navigator.context, 'Error', 'An error occurred while blocking user.', isError: true);
      }
    });
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
          showMenu: true,
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
