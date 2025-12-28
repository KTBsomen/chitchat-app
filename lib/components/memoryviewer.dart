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

  const MemoryViewer({
    Key? key,
    required this.memories,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _MemoryViewerState createState() => _MemoryViewerState();
}

class _MemoryViewerState extends State<MemoryViewer> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();

    _controller = PageController(initialPage: widget.initialIndex);
    fetchPublicStatus();
    _controller.addListener(() {
      setState(() {}); // Rebuild to update icon visibility on page change
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  fetchPublicStatus() async {
    for (var memory in widget.memories) {
      bool isPublic = await AppVariables.getPersistent(memory.url) ?? false;
      setState(() {
        memory.isPublic = isPublic;
      });
    }
  }

  Future<void> _createPost() async {
    final int currentIndex = _controller.page!.round();
    final MemoryItem currentMemory = widget.memories[currentIndex];

    final profile = AppVariables.get<Map<String, dynamic>>('profile');
    if (profile == null || profile['myGroup'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find group information.')),
      );
      return;
    }

    final String groupId = profile['myGroup']['_id'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await PostService.createPost(
      files: [currentMemory.url],
      isGroupPost: true,
      myGroupId: groupId,
    );

    Navigator.pop(context); // Close loading dialog

    if (result['success']) {
      setState(() {
        currentMemory.isPublic = true;
      });
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['success'] ? 'Success' : 'Error'),
        content: Text(result['success']
            ? 'Your memory has been posted publicly.'
            : 'Failed to post memory: ${result['error']}'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
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
        child: CachedNetworkImage(
          imageUrl: item.url,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int currentPage = _controller.hasClients
        ? _controller.page!.round()
        : widget.initialIndex;

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
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (!widget.memories[currentPage].isPublic)
            Positioned(
              top: 40,
              left: 10,
              child: IconButton(
                icon: const Icon(Icons.public, color: Colors.white, size: 30),
                onPressed: _createPost,
              ),
            ),
        ],
      ),
    );
  }
}
