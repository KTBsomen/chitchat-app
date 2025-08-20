import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RelatedPostsWidget extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const RelatedPostsWidget({
    Key? key,
    required this.postId,
    required this.scrollController,
  }) : super(key: key);

  @override
  _RelatedPostsWidgetState createState() => _RelatedPostsWidgetState();
}

class _RelatedPostsWidgetState extends State<RelatedPostsWidget> {
  List<Map<String, dynamic>> allPosts = [];
  bool isLoading = false;
  bool hasMoreData = true;

  // Pagination cursors for different post types
  String? groupPostsCursor;
  String? memberPostsCursor;
  String? authorPostsCursor;

  // Track if each type has more data
  bool hasMoreGroupPosts = true;
  bool hasMoreMemberPosts = true;
  bool hasMoreAuthorPosts = true;

  final int limit = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController.position.pixels >=
        widget.scrollController.position.maxScrollExtent - 200) {
      if (!isLoading && hasMoreData) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await _fetchRelatedPosts();
      if (response != null) {
        _processResponse(response["data"], isInitial: true);
      }
    } catch (e) {
      print('Error loading initial posts: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (isLoading || !hasMoreData) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await _fetchRelatedPosts();
      if (response != null) {
        _processResponse(response["data"], isInitial: false);
      }
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchRelatedPosts() async {
    try {
      return await PostService.fetchRelatedPosts(
          postId: widget.postId,
          groupPostsCursor: groupPostsCursor,
          memberPostsCursor: memberPostsCursor,
          authorPostsCursor: authorPostsCursor);
    } catch (e) {
      print('Network error: $e');
      return null;
    }
  }

  void _processResponse(Map<String, dynamic> response,
      {required bool isInitial}) {
    final related = response['related'] as Map<String, dynamic>;
    final pagination = response['pagination'] as Map<String, dynamic>;
    final cursors = pagination['cursors'] as Map<String, dynamic>;

    // Collect all new posts from different types
    List<Map<String, dynamic>> newPosts = [];

    // Process group posts
    final groupPosts = related['groupPosts'] as Map<String, dynamic>;
    final groupPostsList =
        List<Map<String, dynamic>>.from(groupPosts['posts'] as List);
    hasMoreGroupPosts = groupPosts['hasMore'] as bool;

    for (var post in groupPostsList) {
      newPosts.add({
        ...Map<String, dynamic>.from(post),
        'postType': 'group',
        'sortKey': _getSortKey(post),
      });
    }

    // Process member personal posts
    final memberPosts = related['memberPersonalPosts'] as Map<String, dynamic>;
    final memberPostsList =
        List<Map<String, dynamic>>.from(memberPosts['posts'] as List);
    hasMoreMemberPosts = memberPosts['hasMore'] as bool;

    for (var post in memberPostsList) {
      newPosts.add({
        ...Map<String, dynamic>.from(post),
        'postType': 'member',
        'sortKey': _getSortKey(post),
      });
    }

    // Process author personal posts
    final authorPosts = related['authorPersonalPosts'] as Map<String, dynamic>;
    final authorPostsList =
        List<Map<String, dynamic>>.from(authorPosts['posts'] as List);
    hasMoreAuthorPosts = authorPosts['hasMore'] as bool;

    for (var post in authorPostsList) {
      newPosts.add({
        ...Map<String, dynamic>.from(post),
        'postType': 'author',
        'sortKey': _getSortKey(post),
      });
    }

    // Update cursors (they can be null)
    groupPostsCursor = cursors['groupPosts'];
    memberPostsCursor = cursors['memberPosts'];
    authorPostsCursor = cursors['authorPosts'];

    // Check if we have more data from any source
    hasMoreData = hasMoreGroupPosts || hasMoreMemberPosts || hasMoreAuthorPosts;

    setState(() {
      if (isInitial) {
        allPosts = newPosts;
      } else {
        allPosts.addAll(newPosts);
      }

      // Remove duplicates by post ID
      final uniquePosts = <Map<String, dynamic>>[];
      final ids = <String>{};
      for (final post in allPosts) {
        final postId = post['_id'];
        if (postId is String && ids.add(postId)) {
          uniquePosts.add(post);
        }
      }
      allPosts = uniquePosts;

      // Sort all posts by creation time (most recent first)
      // Use createdAt for sorting since that's available in your response
      allPosts.sort((a, b) {
        final aTime = DateTime.parse(a['createdAt'] as String);
        final bTime = DateTime.parse(b['createdAt'] as String);
        return bTime.compareTo(aTime);
      });
    });
  }

  int _getSortKey(Map<String, dynamic> post) {
    // Use createdAt timestamp as sort key
    if (post.containsKey('createdAt')) {
      return DateTime.parse(post['createdAt'] as String).millisecondsSinceEpoch;
    }
    return 0;
  }

  Widget _buildPostItem(Map<String, dynamic> post, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: DynamicPostWidget(
        showAuthor: true, // Show author for related posts
        showCount: true,
        borderRadius: 12,
        content: post['content'] ?? '',
        media: post['media'] != null
            ? List<Map<String, dynamic>>.from(
                (post['media'] as List).map((m) => {
                      'type': m['type'] as String,
                      'url': m['url'] as String,
                    }),
              )
            : [],
        postId: post['_id'] as String,
        author: post['author'] as String,
        group: post['group'] as String,
        authorName: post['authorName'] as String,
        profilePic: post['profilePic'] as String,
        likes: post['likes'] as int,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.post_add,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No related posts found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for more content',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSliverList() {
    if (isLoading && allPosts.isEmpty) {
      // Show loading indicator in a sliver
      return SliverToBoxAdapter(child: _buildLoadingIndicator());
    }

    if (allPosts.isEmpty && !isLoading) {
      // Show empty state in a sliver
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    // Build the actual list of posts + optional loading indicator at the end
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 0,
        crossAxisSpacing: 0,
        itemBuilder: (context, index) {
          if (index == allPosts.length) {
            // Loading indicator at the bottom
            return _buildLoadingIndicator();
          }
          return _buildPostItem(allPosts[index], index);
        },
        childCount: allPosts.length + (hasMoreData ? 1 : 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildSliverList();
  }
}
