import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:chitchat/screens/StoryListScreen.dart';
import 'package:chitchat/screens/camera.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/createStory.dart';
import 'package:chitchat/screens/filePreview.dart';
import 'package:chitchat/screens/search.dart';
import 'package:chitchat/screens/story.dart';
import 'package:chitchat/screens/watchlist.dart';
import 'package:chitchat/services/chats.dart';
import 'package:chitchat/services/story.dart';
import 'package:deep_link_router/deep_link_router.dart';
import 'package:event_handeler/event_handeler.dart';
import 'package:shimmer/shimmer.dart';
import "package:story_view/story_view.dart";
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/appstate/storyPrefs.dart';

import 'package:chitchat/components/appbar.dart';
import 'package:chitchat/components/bottomnav.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/profilePrivet.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/screens/register.dart';
import 'package:chitchat/services/feed.dart';
import 'package:chitchat/services/notification.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:page_transition/page_transition.dart';
import 'package:vs_story_designer/vs_story_designer.dart';
import 'profilePublic.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:vs_media_picker/vs_media_picker.dart';
// import 'package:flutter_story_editor/src/controller/controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  // FlutterStoryEditorController controller = FlutterStoryEditorController();

  final TextEditingController _captionController = TextEditingController();
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');

  bool _isLoading = false;
  bool _isRefreshing = false;
  List<dynamic> _feedItems = [];
  StreamSubscription? _subscription;
  Future<void> _handelDeepLinks() async {
    Uri? pendingLink = await DeepLinkRouter.getPendingDeepLink();
    print("Pending Link on homepage: $pendingLink");
    if (pendingLink != null) {
      await DeepLinkRouter.completePendingNavigation(context);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    AppVariables.registerState(this);
    AppVariables.set("selectedTabIndex", 0);
    _handelDeepLinks();
    _loadMoreItems(invalidate: "true");
    _getMyStories();
    _getStories();
    _subscription =
        addCustomEventListener("messageNotificationCountUpdate", (d) async {
      print("Message notification count updated: $d");
      print(await _getMessageNotificationCount());
    });
  }

  int? _selectedIndex = AppVariables.get<int>("selectedTabIndex");

  // Future<void> _onScroll() async {
  //   if (_scrollController.position.pixels >=
  //           _scrollController.position.maxScrollExtent - 500 &&
  //       hasMore) {
  //     final oldScrollOffset = _scrollController.offset;
  //     await _loadMoreItems(invalidate: "true");
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       if (_scrollController.hasClients) {
  //         _scrollController.jumpTo(oldScrollOffset + 100);
  //       }
  //     });
  //   }
  // }
  Timer? _scrollDebounce;
  bool _isFetchingMore = false;
  void _onScroll() {
    if (_scrollDebounce?.isActive ?? false) return;

    _scrollDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 500 &&
          hasMore &&
          !_isFetchingMore) {
        _isFetchingMore = true;
        await _loadMoreItems(invalidate: "true");
        _isFetchingMore = false;
      }
    });
  }

  void show(BuildContext context) {
    ValueNotifier<bool> isNextButtonVisible = ValueNotifier(false);
    List<PickedAssetModel> selectedFiles = <PickedAssetModel>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bottomSheetBackground,
      builder: (context) => Stack(
        children: [
          VSMediaPicker(
            maxPickImages: 100,
            gridViewController: _scrollController2,
            singlePick: false,
            onlyImages: false,
            appBarColor: Colors.black,
            gridViewPhysics: const ScrollPhysics(),
            pathList: (path) {
              if (path.isNotEmpty) {
                print("path: ${path.map((e) => e.type).toList()}");
              }
              selectedFiles = path;
              isNextButtonVisible.value = selectedFiles.isNotEmpty;
            },
            appBarLeadingWidget: Padding(
              padding: const EdgeInsets.only(bottom: 15, right: 15),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.2,
                            )),
                        child: const Row(
                          children: [
                            Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    RepaintBoundary(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isNextButtonVisible,
                        builder: (context, isVisible, child) {
                          return isVisible
                              ? InkWell(
                                  onTap: () async {
                                    await Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FilePreviewPage(
                                                files: selectedFiles,
                                              )),
                                    );
                                    // Navigator.pop(context);
                                    // showModalBottomSheet(
                                    //   context: context,
                                    //   isScrollControlled: true,
                                    //   isDismissible: false,
                                    //   enableDrag: false,
                                    //   backgroundColor: Colors.black,
                                    //   builder: (context) =>
                                    //       FlutterStoryEditor(
                                    //     controller: controller,
                                    //     captionController:
                                    //         _captionController,
                                    //     selectedFiles: selectedFiles
                                    //         .map(
                                    //           (e) =>
                                    //               e.file ??
                                    //               File(e.path ?? ""),
                                    //         )
                                    //         .toList(),
                                    //     onSaveClickListener: (files) {
                                    //       // Handle save click logic here
                                    //       print(
                                    //         "Selected files: ${files.map((e) => e.path).toList()}",
                                    //       );
                                    //     },
                                    //   ),
                                    // );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.2,
                                        )),
                                    child: const Row(
                                      children: [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  'Select files to send',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreFakeItems() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);

      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _feedItems.addAll(
          List.generate(
            5,
            (index) =>
                "https://picsum.photos/500/${600 + _feedItems.length + index}",
          ),
        );
        _isLoading = false;
      });
    }
  }

  bool hasMore = true;
  String? lastSeenPostId;
  int page = 1;
  Future<void> _refreshItems({String? invalidate}) async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final response = await FeedService.fetchFeed(
          page: page,
          limit: 10,
          lastSeenPostId: null,
          invalidateCache: invalidate);

      setState(() {
        _feedItems = response["posts"];
        hasMore = response["hasMore"];

        // Update lastSeenPostId for pagination
        if (_feedItems.isNotEmpty) {
          lastSeenPostId = _feedItems.last["_id"];
          page++;
        }
      });
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadMoreItems({String? invalidate}) async {
    if (!hasMore || _isLoading) return; // Stop fetching if no more data

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await FeedService.fetchFeed(
          page: page,
          limit: 10,
          lastSeenPostId: lastSeenPostId,
          invalidateCache: invalidate);

      setState(() {
        _feedItems.addAll(response["posts"]);
        hasMore = response["hasMore"];

        // Update lastSeenPostId for pagination
        if (_feedItems.isNotEmpty) {
          lastSeenPostId = _feedItems.last["_id"];
          page++;
        }
      });
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  List<UserStory> userStories = [];
  List<UserStory> myStories = [];

  Future<void> _getStories({bool? invalidate}) async {
    // Ensure StoryPrefs is initialized for the current user before fetching
    try {
      await StoryPrefs.init();
      final response = await StoryService.getStories(invalidate: invalidate);
      setState(() {
        userStories = StoryService.sortStories(response);
      });
      print(userStories);
    } on Exception catch (e) {
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

  Future<void> _getMyStories({bool? invalidate}) async {
    final response = await StoryService.getMyStories(invalidate: invalidate);
    if (mounted) {
      setState(() {
        myStories = StoryService.sortStories(response);
      });
    }
  }

  @override
  dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    AppVariables.unregisterState(this);
    super.dispose();
  }

  Future<bool?> _showExitConfirmationDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Exit App', style: TextStyle(color: Colors.white)),
        content: const Text('Do you really want to exit?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final bool shouldExit =
            await _showExitConfirmationDialog(context) ?? false;
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.background,
          cardColor: const Color(0xFF1E1E1E),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppColors.background,
            selectedItemColor: Color.fromARGB(255, 85, 0, 150),
            unselectedItemColor: Colors.grey,
          ),
        ),
        child: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              _refreshItems(invalidate: "true");
              _getStories();
              _getMyStories(invalidate: true);
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 170,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: userStories.length + 1, // +1 for "Me"
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // --- My Story ---
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _StoryItem(
                              clicked_index: 0,
                              onTap: () {
                                if (myStories.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    PageTransition(
                                      isIos: true,
                                      type: PageTransitionType.rightToLeft,
                                      child: StoryListScreen(
                                        storyItems: myStories,
                                        initialIndex: "Me",
                                      ),
                                      curve: Curves.fastEaseInToSlowEaseOut,
                                      duration:
                                          const Duration(milliseconds: 500),
                                    ),
                                  );
                                } else {
                                  show(context);
                                }
                              },
                              userStory: UserStory(
                                dbIndex: 0,
                                id: "__",
                                username: "Me",
                                name: "Me",
                                user: profileDetails?["_id"] ?? "__",
                                media: [],
                                views: [],
                                visibleTo: "me",
                                date: DateTime.now(),
                                profilePic: profileDetails?["profilePic"] ??
                                    "https://unsplash.it/200/300",
                              ),
                              stories: myStories,
                            ),
                          );
                        } else {
                          // --- Other users' stories ---
                          final userStory = userStories[index - 1];
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _StoryItem(
                              clicked_index: index - 1,
                              // onTap: () => openStory(userStory),
                              userStory: userStory,
                              stories: userStories, //all stories,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                _buildFeed(),
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            highlightIndex: 0,
            showCenterButton: true,
            centerButtonFloat: true,
            centerButtonIcon: Icons.camera_alt_rounded,
            centerButtonColor: Colors.blue,
            centerButtonSize: 58,
            onCenterButtonTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const CameraPage()));
            },
            items: [
              NavMenuItem(
                icon: Icons.home_rounded,
                onTap: () {
                  _loadMoreItems(invalidate: "true");
                  _getStories();
                },
              ),
              NavMenuItem(
                icon: Icons.search_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      isIos: true,
                      type: PageTransitionType.rightToLeft,
                      child: SearchPage(),
                      curve: Curves.fastEaseInToSlowEaseOut,
                      duration: const Duration(milliseconds: 500),
                    ),
                  );
                },
              ),
              NavMenuItem(
                icon: Icons.favorite_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      isIos: true,
                      type: PageTransitionType.rightToLeft,
                      child: WatchlistPage(),
                      curve: Curves.fastEaseInToSlowEaseOut,
                      duration: const Duration(milliseconds: 500),
                    ),
                  );
                },
              ),
              NavMenuItem(
                icon: Icons.groups,
                onTap: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      isIos: true,
                      type: PageTransitionType.rightToLeft,
                      child: const PrivetProfilePage(),
                      curve: Curves.fastEaseInToSlowEaseOut,
                      duration: const Duration(milliseconds: 500),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _notificationCount = 0;
  int _messageNotificationCount = 0;
  Future<int> _getMessageNotificationCount() async {
    int count = await ChatServices.getMessageNotificationCount();
    setState(() {
      _messageNotificationCount = count;
    });
    return count;
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      elevation: 9,
      floating: true,
      backgroundColor: AppColors.background,
      title: const Text(
        "chitchat",
        style: TextStyle(
          fontFamily: "Poppins",
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        const NotificationIcon(
          icon: Icons.notifications_none_rounded,
          type: NotificationIconType.Notification,
        ),
        NotificationIcon(
          icon: Icons.messenger_outline_rounded,
          type: NotificationIconType.Message,
          onPressed: () {
            print("Messages clicked!");
            Navigator.push(
              context,
              PageTransition(
                isIos: true,
                type: PageTransitionType.rightToLeft,
                child: const ChatScreen(),
                curve: Curves.fastEaseInToSlowEaseOut,
                duration: const Duration(milliseconds: 500),
              ),
            );
          },
          rightPadding: 25,
        ),
      ],
    );
  }

  Widget _buildStories() {
    return Padding(
      padding: const EdgeInsets.only(
        left: 5,
      ),
      child: SizedBox(
        height: 170,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: userStories.length,
          itemBuilder: (context, index) => _StoryItem(
              userStory: userStories[index],
              stories: userStories,
              clicked_index: index),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    if (_isRefreshing) {
      // 🔹 Show shimmer placeholders
      return SliverPadding(
        padding: const EdgeInsets.all(8),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childCount: 6, // number of shimmer placeholders
          itemBuilder: (context, index) {
            return Shimmer.fromColors(
              baseColor: AppColors.background,
              highlightColor: Colors.grey.shade100,
              child: Container(
                height: 220 + (index % 3) * 30, // random varied heights
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
        ),
      );
    }

    // 🔹 Normal feed
    return SliverPadding(
      padding: const EdgeInsets.all(1),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemBuilder: (context, index) {
          final post = _feedItems[index];

          if (post?['media'] == null) return const SizedBox.shrink();

          if (post?['media'].runtimeType == String) {
            post['media'] = jsonDecode(post['media']);
          }

          return AnimatedSwitcher(
            key: ValueKey(post['_id']),
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: DynamicPostWidget(
              showAuthor: false,
              showCount: true,
              borderRadius: 12,
              content: post['content'],
              media: List<Map<String, dynamic>>.from(
                (post['media'] as List<dynamic>).map((m) => {
                      'type': m['type'],
                      'url': m['url'],
                    }),
              ),
              postId: post['_id'],
              author: post['author'],
              group: post['group'],
              isGroupPost: post['isGroupPost'] ?? false,
              authorName: post['authorName'],
              profilePic: post['profilePic'],
              showMenu: true,
              likes: post['likes'],
              comments: post['comments'],
            ),
          );
        },
        childCount: _feedItems.length,
      ),
    );
  }

  void _showPost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PostDetails(),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final UserStory userStory;
  final List<UserStory> stories;
  final Function? onTap;
  final int clicked_index;

  const _StoryItem(
      {required this.userStory,
      required this.stories,
      this.onTap,
      required this.clicked_index,
      super.key});
  List<UserStory> filterStories() {
    return stories
        .where((story) =>
            (story.getColor().toString() == userStory.getColor().toString()) &&
            (story.username == userStory.username))
        .toList();
  }

  bool isEverythingViewed() {
    // Use the new method that checks ALL story IDs in each merged group
    for (var story in filterStories()) {
      // If any story in the filtered list has unviewed stories, return false
      if (story.hasUnviewedStories()) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (onTap != null) {
          onTap!();
          return;
        }
        print("Story clicked: ${userStory.username} at index $clicked_index");
        Navigator.push(
          context,
          PageTransition(
            isIos: true,
            type: PageTransitionType.rightToLeft,
            child: StoryViewScreen(
              storyItems: filterStories(),
              initialIndex: userStory.username,
            ),
            curve: Curves.fastEaseInToSlowEaseOut,
            duration: const Duration(milliseconds: 500),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 67,
              height: 80,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                // gradient: LinearGradient(
                //   colors: [
                //     Color.fromARGB(255, 198, 101, 10),
                //     Color.fromARGB(255, 255, 179, 0),
                //     Color.fromARGB(255, 96, 4, 194)
                //   ],
                // ),
                color: userStory.username == "Me"
                    ? Colors.transparent
                    : isEverythingViewed()
                        ? Colors.grey
                        : userStory.getColor(),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Stack(
                children: [
                  Container(
                      width: 67,
                      height: 80,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Color(0xFF121212),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: SizedBox(
                          width: 67,
                          height: 80,
                          child: Image.network(
                            userStory.profilePic,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.error);
                            },
                          ),
                        ),
                      )),
                  if (userStory.username == "Me")
                    Positioned(
                        bottom: 0,
                        right: 0,
                        child: Icon(
                          Icons.add_circle_outlined,
                          color: AppColors.surface,
                          size: 25,
                        ))
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Small bars at bottom (status indicators - always show type color)
            ...[
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 3,
                    decoration: BoxDecoration(
                      // Always show type color - these indicate story type, not viewed state
                      color: userStory.getColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 15,
                    height: 3,
                    decoration: BoxDecoration(
                      // Always show type color - these indicate story type, not viewed state
                      color: userStory.getColor(),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ],

            Text(
              userStory.username,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const _FeedItem({
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: "$imageUrl?${DateTime.now()}",
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            children: [
              CachedNetworkImage(
                  imageUrl: imageUrl,
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
              const Positioned(
                  top: 5,
                  left: 5,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 15, color: Colors.grey),
                      ),
                      const SizedBox(width: 10),
                      Text('Image 2', style: TextStyle(fontSize: 12)),
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

class PostDetails extends StatelessWidget {
  const PostDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Add your post details content here
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
