import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/story.dart';
import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';

class MyStoryViewScreen extends StatefulWidget {
  final List<UserStory> storyItems;
  final String initialIndex;
  final String? category; // Optional category for filtered viewing

  const MyStoryViewScreen({
    Key? key,
    required this.storyItems,
    required this.initialIndex,
    this.category,
  }) : super(key: key);

  @override
  State<MyStoryViewScreen> createState() => _MyStoryViewScreenState();
}

class _MyStoryViewScreenState extends State<MyStoryViewScreen> {
  final StoryController controller = StoryController();
  int currentStoryIndex = 0;
  String? currentChitId;

  void goToNextStory() async {
    if (currentStoryIndex < widget.storyItems.length - 1) {
      setState(() {
        currentStoryIndex++;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize currentChitId with the first media item of the first story
    if (widget.storyItems.isNotEmpty && widget.storyItems[0].media.isNotEmpty) {
      currentChitId = widget.storyItems[0].media[0].storyId;
    }
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
    return storyItems;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  static String _timeAgo(dynamic mongoDate) {
    try {
      DateTime date;
      if (mongoDate is String) {
        date = DateTime.parse(mongoDate);
      } else if (mongoDate is int) {
        date = DateTime.fromMillisecondsSinceEpoch(mongoDate);
      } else if (mongoDate is DateTime) {
        date = mongoDate;
      } else {
        return 'Invalid date';
      }

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
    final currentStory = widget.storyItems[currentStoryIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Story View
          StoryView(
            indicatorColor: currentStory.getColor(),
            storyItems: _loadStories(currentStoryIndex),
            controller: controller,
            inline: false,
            repeat: false,
            onComplete: goToNextStory,
            onStoryShow: (item, index) {
              if (index < currentStory.media.length) {
                final newChitId = currentStory.media[index].storyId;
                if (newChitId != currentChitId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        currentChitId = newChitId;
                      });
                    }
                  });
                }
              }
            },
            onVerticalSwipeComplete: (direction) {
              if (direction == Direction.down) {
                Navigator.pop(context);
              }
            },
          ),

          // Top User Info Bar
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(
                            uid: currentStory.user,
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
                            color: currentStory.getColor(),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF121212),
                              shape: BoxShape.circle,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: currentStory.profilePic,
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
                              currentStory.username,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _timeAgo(currentStory.date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: currentStory.getColor().withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: currentStory.getColor(),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.category!,
                        style: TextStyle(
                          color: currentStory.getColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Views Sheet (only for user's own stories)
          if (currentStory.myStory)
            DraggableScrollableSheet(
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.5,
              expand: true,
              builder: (context, scrollController) {
                // Get views for the specific current chit
                final rawViews = currentChitId != null
                    ? currentStory.storyViewsMap[currentChitId] ?? []
                    : currentStory.views;

                // Make views unique by user ID or username
                final Map<String, dynamic> uniqueViewsMap = {};
                for (var v in rawViews) {
                  final key = v['username'] ?? v['user'] ?? '';
                  if (!uniqueViewsMap.containsKey(key)) {
                    uniqueViewsMap[key] = v;
                  }
                }
                final views = uniqueViewsMap.values.toList();
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.bottomSheetBackground.withOpacity(0.92),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border.all(
                        color: AppColors.bottomSheetBorder, width: 0.5),
                  ),
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: views.length + 1, // +1 for the header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header section
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 1, 8, 1),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.remove_red_eye,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${views.length} views',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Drag handle inside the row
                                  Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (currentChitId != null)
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 22,
                                      ),
                                      onPressed: () => _confirmDelete(
                                          context, currentChitId!),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.grey, height: 1),
                          ],
                        );
                      }

                      // Viewers list item
                      final user = views[index - 1];
                      return ListTile(
                        trailing: Icon(
                          Icons.circle,
                          color: currentStory.getColor(),
                          size: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundImage:
                              NetworkImage(user['profilePic'] ?? ''),
                          backgroundColor: Colors.grey[800],
                        ),
                        title: Text(
                          user['username'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: user['viewedAt'] != null
                            ? Text(
                                _timeAgo(user['viewedAt']),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String chitId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title:
            const Text('Delete Story', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this story?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              // Capture the messenger before any async gaps or pops
              final messenger = ScaffoldMessenger.of(context);
              final parentContext = context;
              
              // Find the correct dbIndex for this chitId
              int dbIdx = 0;
              try {
                final story = widget.storyItems
                    .firstWhere((s) => s.allStoryIds.contains(chitId));
                int idIdx = story.allStoryIds.indexOf(chitId);
                if (idIdx != -1 && idIdx < story.allStoryDbIndices.length) {
                  dbIdx = story.allStoryDbIndices[idIdx];
                }
              } catch (e) {
                // Fallback to first story's dbIndex if not found
                dbIdx = widget.storyItems[0].dbIndex;
              }

              final success = await StoryService.deleteChit(chitId, dbIdx);
              if (success) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Story deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                if (mounted) {
                  Navigator.pop(parentContext, true); // Pop screen
                }
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete story (Server Error 500)'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
