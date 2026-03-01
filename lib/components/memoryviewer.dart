import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:chitchat/appstate/storage.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/videoWidget.dart';
import 'package:chitchat/screens/filePreview.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';

class MemoryViewer extends StatefulWidget {
  final List<MemoryItem> memories;
  final int initialIndex;
  final Function(String memoryId)? onMemoryDeleted;

  const MemoryViewer({
    Key? key,
    required this.memories,
    this.initialIndex = 0,
    this.onMemoryDeleted,
  }) : super(key: key);

  @override
  _MemoryViewerState createState() => _MemoryViewerState();
}

class _MemoryViewerState extends State<MemoryViewer> {
  late PageController _controller;
  bool _isDeleting = false;
  bool _isTogglingPublic = false;

  @override
  void initState() {
    super.initState();

    _controller = PageController(initialPage: widget.initialIndex);
    _controller.addListener(() {
      setState(() {}); // Rebuild to update icon visibility on page change
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Make memory public
  Future<void> _makePublic() async {
    if (_isTogglingPublic) return;

    final int currentIndex = _controller.page!.round();
    final MemoryItem currentMemory = widget.memories[currentIndex];

    // Already public, do nothing
    if (currentMemory.isPublic) return;

    final profile = AppVariables.get<Map<String, dynamic>>('profile');
    if (profile == null || profile['myGroup'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find group information.')),
      );
      return;
    }

    final String groupId = profile['myGroup']['_id'];

    setState(() {
      _isTogglingPublic = true;
    });

    final result = await PostService.toggleMemoryPublic(
      memoryId: currentMemory.id,
      isPublic: true,
    );

    setState(() {
      _isTogglingPublic = false;
    });

    if (result['success']) {
      setState(() {
        currentMemory.isPublic = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory is now public')),
        );
      }

      // Create a group post for the public memory
      Map<String, dynamic> postResult = await PostService.createPost(
          files: [currentMemory.url],
          isGroupPost: true,
          myGroupId: groupId,
          memoryId: currentMemory.id,
          memoryDBIndex: currentMemory.dbIndex,
          isMemory: true);

      if (postResult['success']) {
        AppVariables.update("group_posts", postResult['data']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Memory added to your Group posts'),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to update memory')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Delete memory using the API
  Future<void> _deleteMemory() async {
    if (_isDeleting) return;

    final int currentIndex = _controller.page!.round();
    final MemoryItem currentMemory = widget.memories[currentIndex];

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Memory'),
        content: const Text(
            'Are you sure you want to delete this memory? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final result = await PostService.deleteMemory(memoryId: currentMemory.id);

    setState(() {
      _isDeleting = false;
    });

    if (result['success']) {
      // Notify parent about deletion
      widget.onMemoryDeleted?.call(currentMemory.id);

      // Remove from local list
      widget.memories.removeAt(currentIndex);

      // If no more memories, close the viewer
      if (widget.memories.isEmpty) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // Adjust page if needed
      if (currentIndex >= widget.memories.length) {
        _controller.jumpToPage(widget.memories.length - 1);
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory deleted successfully')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to delete memory')),
        );
      }
    }
  }

  Widget _buildMemoryView(MemoryItem item) {
    if (item.type == MessageType.video) {
      return Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: VideoMessageView(
            url: item.url,
          ),
        ),
      );
    } else {
      return InteractiveViewer(
        child: Image.network(
          item.url,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.memories.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No memories', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final int currentPage = _controller.hasClients
        ? _controller.page!.round()
        : widget.initialIndex;
    final currentMemory =
        widget.memories[currentPage.clamp(0, widget.memories.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.memories.length,
            itemBuilder: (context, index) {
              return _buildMemoryView(widget.memories[index]);
            },
          ),
          // Close button (top-right)
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Public toggle button (top-left)
          Positioned(
            top: 40,
            left: 10,
            child: _isTogglingPublic
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : currentMemory.isPublic
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(
                          Icons.public,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _makePublic,
                        tooltip: 'Make public',
                      ),
          ),
          // Delete button (top-left, next to public button)
          Positioned(
            top: 40,
            left: 60,
            child: _isDeleting
                ? const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 30),
                    onPressed: _deleteMemory,
                    tooltip: 'Delete memory',
                  ),
          ),
          // Author info overlay (bottom)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: currentMemory.profilePic.isNotEmpty
                        ? NetworkImage(currentMemory.profilePic)
                        : null,
                    radius: 22,
                    child: currentMemory.profilePic.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentMemory.authorName.isNotEmpty
                              ? currentMemory.authorName
                              : 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(currentMemory.createdAt),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Public status indicator
                  if (currentMemory.isPublic)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, color: Colors.green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Public',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
