import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/story.dart';
import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';

class StoryViewScreen extends StatefulWidget {
  final List<UserStory> storyItems;
  final String initialIndex;

  const StoryViewScreen({
    Key? key,
    required this.storyItems,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  final StoryController controller = StoryController();

  int currentUserIndex = 0;

  void updateViewOnStory(StoryItem item, int index) async {
    print(
        "Story shown: $item at index $index for user index $currentUserIndex");
    if (currentUserIndex < widget.storyItems.length - 1) {
      if (widget.storyItems[currentUserIndex].isViewed == false) {
        if (widget.storyItems[currentUserIndex].myStory) {
          return;
        }
        await StoryService.markStoryAsViewed(
          widget.storyItems[currentUserIndex].id,
          widget.storyItems[currentUserIndex].dbIndex,
        );
      }
      widget.storyItems[currentUserIndex].isViewed = true;
      AppVariables.update("story_viewed_index", widget.initialIndex);
      print("this is called");
    } else {
      if (widget.storyItems[currentUserIndex].myStory) {
        return;
      }
      if (widget.storyItems[currentUserIndex].isViewed == false) {
        StoryService.markStoryAsViewed(
          widget.storyItems[currentUserIndex].id,
          widget.storyItems[currentUserIndex].dbIndex,
        );
      }
      widget.storyItems[currentUserIndex].isViewed = true;
      AppVariables.update("story_viewed_index", widget.initialIndex);
    }
  }

  void goToNextUser() async {
    if (currentUserIndex < widget.storyItems.length - 1) {
      print(
          "before user index $currentUserIndex ${widget.storyItems[currentUserIndex]}");
      setState(() {
        currentUserIndex++;
      });
      print(
          "after user index $currentUserIndex ${widget.storyItems[currentUserIndex]}");

      if (widget.storyItems[currentUserIndex].isViewed == false) {
        if (widget.storyItems[currentUserIndex].myStory) {
          return;
        }
        await StoryService.markStoryAsViewed(
          widget.storyItems[currentUserIndex].id,
          widget.storyItems[currentUserIndex].dbIndex,
        );
      }
      widget.storyItems[currentUserIndex].isViewed = true;
      AppVariables.update("story_viewed_index", widget.initialIndex);
    } else {
      if (widget.storyItems[currentUserIndex].myStory) {
        return;
      }
      if (widget.storyItems[currentUserIndex].isViewed == false) {
        StoryService.markStoryAsViewed(
          widget.storyItems[currentUserIndex].id,
          widget.storyItems[currentUserIndex].dbIndex,
        );
      }
      widget.storyItems[currentUserIndex].isViewed = true;
      AppVariables.update("story_viewed_index", widget.initialIndex);

      Navigator.pop(context); // Close when all stories are done
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStories(currentUserIndex);
  }

  List<StoryItem> _loadStories(int index) {
    UserStory story = widget.storyItems[index];
    List<StoryItem> storyItems = [];
    for (var item in story.media) {
      if (item.type == 'video') {
        storyItems.add(
          StoryItem.pageVideo(
            item.url,
            controller: controller,
          ),
        );
      } else {
        storyItems.add(
          StoryItem.pageImage(
            url: item.url,
            controller: controller,
          ),
        );
      }
    }
    storyItems.sort((a, b) => (a.shown ? 1 : 0).compareTo(b.shown ? 1 : 0));

    return storyItems;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static String _timeAgo(dynamic mongoDate) {
    try {
      if (mongoDate is String) {
        mongoDate = DateTime.parse(mongoDate);
      } else if (mongoDate is int) {
        mongoDate = DateTime.fromMillisecondsSinceEpoch(mongoDate);
      } else if (mongoDate is DateTime) {
        // Already a DateTime object
      } else {
        return 'Invalid date';
      }
      final date = mongoDate;
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} seconds ago';
      }
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      }
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      }
      if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()} months ago';
      }
      return '${(difference.inDays / 365).floor()} years ago';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background

          StoryView(
            indicatorColor: widget.storyItems[currentUserIndex].getColor(),
            storyItems: _loadStories(currentUserIndex),
            controller: controller,
            inline: false,
            repeat: false,
            onComplete: () {
              goToNextUser();
            },
            onStoryShow: updateViewOnStory,
            onVerticalSwipeComplete: (direction) {
              if (direction == Direction.down) {
                Navigator.pop(context);
              }
            },
          ),
          Positioned(
            top: 50,
            left: 10,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PublicProfilePage(
                        uid: widget.storyItems[currentUserIndex].user,
                        dbIndex: 'x',
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        // gradient: LinearGradient(
                        //   colors: [
                        //     Color.fromARGB(255, 198, 101, 10),
                        //     Color.fromARGB(255, 255, 179, 0),
                        //     Color.fromARGB(255, 96, 4, 194)
                        //   ],
                        // ),
                        color: widget.storyItems[currentUserIndex].getColor(),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFF121212),
                          shape: BoxShape.circle,
                        ),
                        child: CachedNetworkImage(
                          imageUrl:
                              widget.storyItems[currentUserIndex].profilePic,
                          imageBuilder: (context, imageProvider) =>
                              CircleAvatar(
                            radius: 20,
                            backgroundImage: imageProvider,
                          ),
                          placeholder: (context, url) => const CircleAvatar(
                            radius: 20,
                            backgroundColor: Color(0xFF2A2A2A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.storyItems[currentUserIndex].username}",
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${_timeAgo(widget.storyItems[currentUserIndex].date)}",
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.storyItems[currentUserIndex].myStory)
            DraggableScrollableSheet(
              initialChildSize: 0.1,
              minChildSize: 0.08,
              maxChildSize: 0.5,
              expand: true,
              builder: (context, scrollController) {
                final views = widget.storyItems[currentUserIndex].views;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Column(
                    children: [
                      SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            children: [
                              Container(
                                width: 40,
                                height: 5,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.remove_red_eye,
                                        color: Colors.black, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${views.length} views',
                                      style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(color: Colors.white24, height: 1),
                            ],
                          )),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: views.length,
                          itemBuilder: (context, index) {
                            final user = views[index];
                            return ListTile(
                              trailing: Icon(
                                Icons.circle,
                                color: widget.storyItems[currentUserIndex]
                                    .getColor(),
                              ),
                              leading: CircleAvatar(
                                backgroundImage:
                                    NetworkImage(user['profilePic'] ?? ''),
                                backgroundColor: Colors.grey[800],
                              ),
                              title: Text(
                                user['username'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.black),
                              ),
                              subtitle: user['viewedAt'] != null
                                  ? Text(
                                      _timeAgo(user['viewedAt']),
                                      style: const TextStyle(
                                          color: Colors.black87, fontSize: 11),
                                    )
                                  : null,
                            );
                          },
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
