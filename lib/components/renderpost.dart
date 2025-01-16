import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class DynamicPostWidget extends StatelessWidget {
  final String content;
  final List<Map<String, dynamic>> media;
  final String postId;
  final String author;
  final String group;
  final String? authorName;
  final String? profilePic;

  DynamicPostWidget({
    required this.content,
    required this.media,
    required this.postId,
    required this.author,
    required this.group,
    this.authorName,
    this.profilePic,
  });

  // Method to handle dynamic media rendering based on type
  Widget _buildMediaContent(Map<String, dynamic> mediaItem) {
    switch (mediaItem['type']) {
      case 'image':
        return Image.network(mediaItem['url']!);
      case 'video':
        return _buildVideoPlayer(mediaItem['url']!);
      case 'audio':
        return Column(
          children: [
            Icon(Icons.music_note),
            Text('Audio content'),
            ElevatedButton(
              onPressed: () {
                // Play audio logic here
              },
              child: Text('Play Audio'),
            ),
          ],
        );
      default:
        return SizedBox.shrink(); // Handle unsupported types
    }
  }

  // You can extend this for any video, not just YouTube
  Widget _buildVideoPlayer(String url) {
    if (url.contains('youtube.com')) {
      return YoutubePlayer(
        controller: YoutubePlayerController(
          initialVideoId: YoutubePlayer.convertUrlToId(url)!,
          flags: YoutubePlayerFlags(
              autoPlay: false,
              disableDragSeek: true,
              showLiveFullscreenButton: false),
        ),
      );
    } else {
      return Container(
        height: 200,
        child: Center(
          child: Text(
              'Video player for URL: $url'), // Replace with actual video player logic
        ),
      );
    }
  }

  // Open BottomSheet with media slider
  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PageView for slider effect
              Container(
                height: 300,
                child: PageView(
                  children: media.map((mediaItem) {
                    return _buildMediaContent(mediaItem);
                  }).toList(),
                ),
              ),
              SizedBox(height: 16),
              Text('Likes: 0 Comments: 0'),
              SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.thumb_up),
                    onPressed: () {
                      // Add Like logic
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.comment),
                    onPressed: () {
                      // Add Comment logic
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openBottomSheet(context),
      child: Hero(
        tag: "${media[0]['url']}?${DateTime.now()}",
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              CachedNetworkImage(
                  imageUrl: media[0]['url'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                        height: 200,
                        color: const Color(0xFF2A2A2A),
                      ),
                  errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: const Color(0xFF2A2A2A),
                      child: const Center(
                        child: Icon(Icons.error),
                      ))),
              Positioned(
                  top: 5,
                  left: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: profilePic != null
                                  ? CachedNetworkImageProvider(profilePic!)
                                  : null,
                              child: profilePic != null
                                  ? null
                                  : Icon(Icons.person,
                                      size: 15, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text('${authorName ?? ""}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 3.0,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ])),
                          ],
                        ),
                      ),
                    ),
                  )),
              Positioned(
                  top: 5,
                  right: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text('1/${media.length}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 3.0,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ])),
                          ],
                        ),
                      ),
                    ),
                  ))
            ],
          ),
        ),
      ),
    );
    //  Card(
    //     margin: EdgeInsets.all(8.0),
    //     child: Padding(
    //       padding: const EdgeInsets.all(16.0),
    //       child: Column(
    //         crossAxisAlignment: CrossAxisAlignment.start,
    //         children: [
    //           Text(content,
    //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    //           SizedBox(height: 8),
    //           ElevatedButton(
    //             onPressed: () => _openBottomSheet(context),
    //             child: Text('Open Media'),
    //           ),
    //           SizedBox(height: 8),
    //           // Additional dynamic content like author, group info, etc.
    //           Row(
    //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //             children: [
    //               Text('Author: $author'),
    //               Text('Group: $group'),
    //             ],
    //           ),
    //         ],
    //       ),
    //     ),
    //   );
  }
}

class PostList extends StatelessWidget {
  final List<Map<String, dynamic>> posts;

  PostList({required this.posts});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return DynamicPostWidget(
          content: post['content'],
          media: List<Map<String, String>>.from(post['media'].map((m) => {
                'type': m['type'],
                'url': m['url'],
              })),
          postId: post['_id'],
          author: post['author'],
          group: post['group'],
          authorName: post['authorName'],
          profilePic: post['profilePic'],
        );
      },
    );
  }
}
