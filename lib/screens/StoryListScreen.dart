import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/camera.dart';
import 'package:chitchat/screens/filePreview.dart';
import 'package:chitchat/screens/mystoryviewscreen.dart';
import 'package:chitchat/services/story.dart';
import 'package:flutter/material.dart';
import 'package:vs_media_picker/vs_media_picker.dart';

class StoryListScreen extends StatefulWidget {
  final List<UserStory> storyItems;
  final String initialIndex;

  const StoryListScreen({
    required this.storyItems,
    required this.initialIndex,
  });

  @override
  State<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen> {
  Map<String, List<UserStory>> categorizedStories = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserStories();
  }

  Future<void> _loadUserStories() async {
    // TODO: Replace with your actual API call to fetch user's stories
    // This is a placeholder - implement according to your backend
    try {
      // Example: final stories = await StoryService.getUserStories(widget.userId);

      // For now, using dummy categorization logic
      // Categorize stories based on visibleTo parameter
      Map<String, List<UserStory>> temp = {
        'all': [],
        'singleUser': [],
        'members': [],
      };

      for (var story in widget.storyItems) {
        if (story.visibleTo == 'all') {
          temp['all']!.add(story);
        } else if (story.visibleTo == 'singleUser') {
          temp['singleUser']!.add(story);
        } else if (story.visibleTo == 'members') {
          temp['members']!.add(story);
        }
      }

      // Remove empty categories
      temp.removeWhere((key, value) => value.isEmpty);

      setState(() {
        categorizedStories = temp;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Colors.red;
      case 'singleuser':
        return Colors.green;
      case 'members':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.favorite;
      case 'singleuser':
        return Icons.check_circle;
      case 'members':
        return Icons.star;
      default:
        return Icons.circle;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return 'For Everyone';
      case 'singleuser':
        return 'For Someone Spacial';
      case 'members':
        return 'For Selected members';
      default:
        return category;
    }
  }

  int _getTotalViews(List<UserStory> stories) {
    int total = 0;
    for (var story in stories) {
      total += story.views.length;
    }
    return total;
  }

  String _timeAgo(dynamic mongoDate) {
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

      if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return '${(difference.inDays / 7).floor()}w ago';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CachedNetworkImage(
              imageUrl: AppVariables.get<Map<String, dynamic>>(
                      'profile')?['profilePic'] ??
                  '',
              imageBuilder: (context, imageProvider) => CircleAvatar(
                radius: 18,
                backgroundImage: imageProvider,
              ),
              placeholder: (context, url) => const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF2A2A2A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppVariables.get<Map<String, dynamic>>(
                            'profile')?['name'] ??
                        'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'My Chits',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : categorizedStories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined,
                          size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text(
                        'No chits available',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to create new chit screen
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add a Chit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categorizedStories.keys.length + 1,
                  itemBuilder: (context, index) {
                    if (index == categorizedStories.keys.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Text(
                              'Create a new chit',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // CAMERA BUTTON
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const CameraPage()),
                                      );
                                    },
                                    icon: const Icon(Icons.camera_alt_rounded,
                                        size: 22),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // GALLERY BUTTON
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      show(context);
                                    },
                                    icon: const Icon(
                                        Icons.photo_library_rounded,
                                        size: 22),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } else {
                      final category = categorizedStories.keys.elementAt(index);
                      final stories = categorizedStories[category]!;
                      final totalViews = _getTotalViews(stories);
                      final latestStory = stories.first;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getCategoryColor(category).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  _getCategoryColor(category).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getCategoryIcon(category),
                              color: _getCategoryColor(category),
                              size: 28,
                            ),
                          ),
                          title: Text(
                            _getCategoryLabel(category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '${stories.length} ${stories.length == 1 ? 'chit' : 'chits'}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '$totalViews ${totalViews == 1 ? 'view' : 'views'}',
                                style: TextStyle(
                                  color: _getCategoryColor(category)
                                      .withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.arrow_forward_ios,
                                color: _getCategoryColor(category),
                                size: 16,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _timeAgo(latestStory.date),
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MyStoryViewScreen(
                                  storyItems: stories,
                                  initialIndex: '0',
                                  category: category,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }
                  },
                ),
    );
  }

  final ScrollController _scrollController2 = ScrollController();
  void show(BuildContext context) {
    ValueNotifier<bool> isNextButtonVisible = ValueNotifier(false);
    List<PickedAssetModel> selectedFiles = <PickedAssetModel>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
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

  @override
  void dispose() {
    // TODO: implement dispose
    _scrollController2.dispose();
    super.dispose();
  }
}
