import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? commentId;
  final Map<String, dynamic>? commentData;
  final Map<String, dynamic>? postData;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.commentId,
    this.commentData,
    this.postData,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.postData != null) {
      _post = widget.postData;
      _isLoading = false;
    } else {
      _fetchPost();
    }
  }

  Future<void> _fetchPost() async {
    try {
      final result = await PostService.fetchPostById(widget.postId);
      if (result['success']) {
        setState(() {
          _post = result['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to load post';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Post',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchPost();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_post == null) {
      return const Center(
        child: Text('Post not found', style: TextStyle(color: Colors.white)),
      );
    }

    return DynamicPostWidget(
      content: _post!['content'] ?? '',
      media: List<Map<String, dynamic>>.from(_post!['media'] ?? []),
      postId: _post!['_id'] ?? '',
      author: _post!['author'] ?? '',
      authorName: _post!['authorName'],
      profilePic: _post!['profilePic'],
      group: _post!['group'],
      isGroupPost: _post!['isGroupPost'],
      likes: _post!['likes'] ?? 0,
      comments: _post!['comments'] ?? 0,
      public: _post!['public'] ?? true,
      showAuthor: true,
      showCount: true,
      showMenu: true,
      isFullPage: true,
      initialCommentId: widget.commentId,
      initialCommentData: widget.commentData,
      onRefresh: (id) => _fetchPost(),
    );
  }
}
