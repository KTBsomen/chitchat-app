import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/renderpost.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/posts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:page_transition/page_transition.dart';

class RelatedPostsWidget extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;
  final String authorId;
  final String authorName;
  final String profilePic;
  final Widget middleItem;

  const RelatedPostsWidget(
      {Key? key,
      required this.postId,
      required this.scrollController,
      required this.authorId,
      required this.profilePic,
      required this.middleItem,
      required this.authorName})
      : super(key: key);

  @override
  _RelatedPostsWidgetState createState() => _RelatedPostsWidgetState();
}

class _RelatedPostsWidgetState extends State<RelatedPostsWidget> {
  List<Map<String, dynamic>> allPosts = [];
  bool isLoading = false;
  bool hasMoreData = true;
  FriendCircleGroup? group; // Add this to store group data

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

    // Store group data
    if (related["groupDetails"] != null) {
      group = GroupsService.buildFriendCircleGroup(related["groupDetails"]);
    }

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
        showAuthor: true,
        showCount: true,
        borderRadius: 12,
        content: post['content']?.toString() ?? '',
        media: (post['media'] as List<dynamic>?)
                ?.map((m) => {
                      'type': m['type']?.toString() ?? '',
                      'url': m['url']?.toString() ?? '',
                    })
                .toList() ??
            [],
        postId: post['_id']?.toString() ?? '',
        author: post['author']?.toString() ?? '',
        group: post['group']?.toString() ?? '',
        authorName: post['authorName']?.toString() ?? '',
        profilePic: post['profilePic']?.toString() ?? '',
        likes: (post['likes'] ?? 0) as int,
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

  // Build the group header row
  Widget _buildGroupHeader() {
    if (group == null) return const SizedBox.shrink();

    return Container(
      // padding: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withValues(alpha: 0.4),
            Colors.black.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: group!.groupData["GroupProfilePic"].isNotEmpty
                ? NetworkImage(group!.groupData['GroupProfilePic'])
                : null,
            child: group!.groupData["GroupProfilePic"].isEmpty
                ? Text(
                    group!.groupData["name"].isNotEmpty
                        ? group!.groupData["name"][0].toUpperCase()
                        : 'G',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group!.groupData["name"],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Scroll down to Explore my group",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getEducationField(Map<String, dynamic> member) {
    // Get the enum value
    final level = member['educationLevel'] as String?;
    if (level == null) return null;

    switch (level) {
      case "School":
        return member['school'] as String?;
      case "College":
        return member['college'] as String?;
      case "University":
        return member['university'] as String?;
      case "Passout":
        return member['year']?.toString(); // maybe year or some graduation info
      default:
        return "";
    }
  }

  Widget _buildUserInfo() {
    FriendCircleMember authorMember = group!.members.firstWhere(
      (element) => element.id == widget.authorId,
    );

    String? educationField = _getEducationField(authorMember.additionalData);
    String displayEducation = _formatEducationTextTwoLine(educationField);

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: IntrinsicWidth(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile Picture with subtle glow
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundImage: widget.profilePic != null
                        ? CachedNetworkImageProvider(widget.profilePic!)
                        : null,
                    child: widget.profilePic != null
                        ? null
                        : const Icon(Icons.person,
                            size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),

                // Text information with better layout
                Flexible(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name with elegant styling
                      Text(
                        widget.authorName ?? "",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 1),
                              blurRadius: 2.0,
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 12),

                      if (displayEducation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        // Education with smart formatting - supports two lines
                        Text(
                          displayEducation,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Colors.blue[200],
                            letterSpacing: 0.2,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 2.0,
                                color: Colors.black.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Helper method for two-line education display
  String _formatEducationTextTwoLine(String? educationField) {
    if (educationField == null || educationField.isEmpty) return "";

    String original = educationField.trim();

    // Handle parentheses content
    RegExp parenthesesRegex = RegExp(r'^(.+?)\s*\((.+?)\)\s*(.*)$');
    Match? match = parenthesesRegex.firstMatch(original);

    if (match != null) {
      String mainName = match.group(1)?.trim() ?? "";
      String parenthesesContent = match.group(2)?.trim() ?? "";
      String afterParentheses = match.group(3)?.trim() ?? "";

      // Add content after parentheses to main name if it exists
      if (afterParentheses.isNotEmpty) {
        mainName = "$mainName $afterParentheses";
      }

      // For two-line display, we can be more generous with space
      if (mainName.length <= 32) {
        return mainName;
      }

      // Try to show both main name and former name if space allows
      if (parenthesesContent.toLowerCase().startsWith('formerly') &&
          parenthesesContent.length <= 30) {
        String formattedFormer =
            parenthesesContent.substring(0, 1).toUpperCase() +
                parenthesesContent.substring(1);
        if (formattedFormer.endsWith('.')) {
          formattedFormer =
              formattedFormer.substring(0, formattedFormer.length - 1);
        }
        return '$mainName\n$formattedFormer';
      }
    }

    // For very long names, split intelligently across two lines
    if (original.length > 35) {
      List<String> words = original.split(RegExp(r'\s+'));
      if (words.length >= 2) {
        int midPoint = words.length ~/ 2;
        String firstLine = words.sublist(0, midPoint).join(' ');
        String secondLine = words.sublist(midPoint).join(' ');

        // Adjust if lines are too uneven
        if (firstLine.length < 12 && words.length > 3) {
          firstLine = words.sublist(0, midPoint + 1).join(' ');
          secondLine = words.sublist(midPoint + 1).join(' ');
        }

        // Ensure neither line is too long
        if (firstLine.length > 25 || secondLine.length > 25) {
          return _truncateEducationName(original);
        }

        return '$firstLine\n$secondLine';
      }
    }

    return original.length > 35 ? '${original.substring(0, 32)}...' : original;
  }

// Fallback truncation method
  String _truncateEducationName(String name) {
    List<String> words = name.split(RegExp(r'\s+'));

    if (words.length == 1) {
      return name.length > 25 ? '${name.substring(0, 25)}...' : name;
    }

    // Build name word by word until we hit length limit
    String result = words[0];

    for (int i = 1; i < words.length; i++) {
      String candidate = '$result ${words[i]}';

      if (candidate.length <= 28) {
        result = candidate;
      } else {
        break;
      }
    }

    return result.length > 30 ? '${result.substring(0, 27)}...' : result;
  }

  @override
  Widget build(BuildContext context) {
    return buildSliverWithHeader();
  }

  Widget buildSliverWithHeader() {
    if (isLoading && allPosts.isEmpty) {
      return SliverToBoxAdapter(child: _buildLoadingIndicator());
    }

    if (allPosts.isEmpty && !isLoading) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    // Create a column that contains the header and masonry grid
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [_buildUserInfo()],
                ),
              ),
              widget.middleItem,
              if (group != null)
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: GroupPublicViewScreen(
                          groupId: group!.groupId,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("<-- explore my group -->",
                                      style: TextStyle(color: Colors.white))
                                ],
                              ),
                              SizedBox(
                                height: 15,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    group!.groupData["name"],
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              group!.groupData["GroupProfilePic"].isNotEmpty
                                  ? NetworkImage(
                                      group!.groupData['GroupProfilePic'])
                                  : null,
                          child: group!.groupData["GroupProfilePic"].isEmpty
                              ? Text(
                                  group!.groupData["name"].isNotEmpty
                                      ? group!.groupData["name"][0]
                                          .toUpperCase()
                                      : 'G',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Masonry grid of posts
          Padding(
            padding: const EdgeInsets.all(8),
            child: MasonryGridView.count(
              shrinkWrap: true, // Important: let it size itself
              physics:
                  const NeverScrollableScrollPhysics(), // Disable internal scrolling
              crossAxisCount: 2,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              itemCount: allPosts.length + (hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == allPosts.length) {
                  return _buildLoadingIndicator();
                }
                return _buildPostItem(allPosts[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }
}
