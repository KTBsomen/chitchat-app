import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:chitchat/components/videoWidget.dart';
import 'package:chitchat/screens/filePreview.dart';
import 'package:chitchat/screens/groupPrivet.dart';
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        ],
      ),
    );
  }
}
