import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/mystoryviewscreen.dart';
import 'package:chitchat/services/story.dart';
import 'package:flutter/material.dart';

class MyChitListScreen extends StatefulWidget {
  final List<UserStory> individualStories;
  final String category;

  const MyChitListScreen({
    Key? key,
    required this.individualStories,
    required this.category,
  }) : super(key: key);

  @override
  State<MyChitListScreen> createState() => _MyChitListScreenState();
}

class _MyChitListScreenState extends State<MyChitListScreen> {
  late List<UserStory> _stories;

  @override
  void initState() {
    super.initState();
    _stories = List.from(widget.individualStories);
    // Sort by date newest first
    _stories.sort((a, b) => b.date.compareTo(a.date));
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

  void _handleDelete(String chitId, int dbIndex) async {
    final success = await StoryService.deleteChit(chitId, dbIndex);
    if (success) {
      setState(() {
        _stories.removeWhere((s) => s.id == chitId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chit deleted successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete chit')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, String chitId, int dbIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Chit', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this chit?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _handleDelete(chitId, dbIndex);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(widget.category);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Manage ${widget.category} Chits',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _stories.isEmpty
          ? const Center(
              child: Text(
                'No chits in this category',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _stories.length,
              itemBuilder: (context, index) {
                final story = _stories[index];
                final firstMedia = story.media.isNotEmpty ? story.media[0] : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: firstMedia != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: firstMedia.type == 'video'
                                  ? const Icon(Icons.play_circle_outline,
                                      color: Colors.white54)
                                  : CachedNetworkImage(
                                      imageUrl: firstMedia.url,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.white10,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.image_not_supported,
                                              color: Colors.white24),
                                    ),
                            )
                          : const Icon(Icons.article_outlined,
                              color: Colors.white24),
                    ),
                    title: Text(
                      _timeAgo(story.date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${story.views.map((v) => v['username'] ?? v['user'] ?? '').toSet().length} views',
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () =>
                          _confirmDelete(context, story.id, story.dbIndex),
                    ),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyStoryViewScreen(
                            storyItems: [story],
                            initialIndex: '0',
                            category: widget.category,
                          ),
                        ),
                      );
                      if (result == true) {
                        setState(() {
                          _stories.removeWhere((s) => s.id == story.id);
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
