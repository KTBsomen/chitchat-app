import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/components/simpleaudioplayer.dart';
import 'package:chitchat/components/zoomableimagepopup.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class DynamicPostWidget extends StatefulWidget {
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

  @override
  State<DynamicPostWidget> createState() => _DynamicPostWidgetState();
}

class _DynamicPostWidgetState extends State<DynamicPostWidget> {
  List comments = [];

  bool isPanning = false;

  // Method to handle dynamic media rendering based on type
  Widget _buildMediaContent(Map<String, dynamic> mediaItem) {
    switch (mediaItem['type']) {
      case 'image':
        return Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: mediaItem['url']!,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color:
                      Colors.black.withOpacity(0.2), // Optional overlay color
                ),
              ),
            ),
            GestureDetector(
              onDoubleTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    barrierDismissible: true,
                    pageBuilder: (BuildContext context, _, __) {
                      return ZoomableImagePopup(
                        imageUrl: mediaItem['url']!,
                        onEdit: null,
                        onClose: () => Navigator.of(context).pop(),
                      );
                    },
                  ),
                );
              },
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: mediaItem['url']!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      case 'video':
        return _buildVideoPlayer(mediaItem['url']!);
      case 'audio':
        return SimpleAudioPlayer(
            title: "Audio", audioUrl: mediaItem['url'], artist: 'unknown');
      default:
        return const SizedBox.shrink(); // Handle unsupported types
    }
  }

  // You can extend this for any video, not just YouTube
  Widget _buildVideoPlayer(String url) {
    if (url.contains('youtube.com')) {
      return YoutubePlayer(
        controller: YoutubePlayerController(
          initialVideoId: YoutubePlayer.convertUrlToId(url)!,
          flags: const YoutubePlayerFlags(
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
      enableDrag: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              var commentController = TextEditingController();
              return Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Main content
                    Expanded(
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          // Collapsible media section
                          SliverAppBar(
                            backgroundColor: Colors.transparent,
                            pinned: true,
                            expandedHeight: 400,
                            automaticallyImplyLeading: false,
                            flexibleSpace: FlexibleSpaceBar(
                              background: PageView.builder(
                                itemCount: widget.media.length,
                                itemBuilder: (context, index) {
                                  return GestureDetector(
                                    child:
                                        _buildMediaContent(widget.media[index]),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Comments list
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return ListTile(
                                  leading: const CircleAvatar(),
                                  title: const Text(
                                    'User Name',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.textSecondary,
                                        fontFamily: "Poppins"),
                                  ),
                                  subtitle: Text(
                                    comments[index],
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.surface,
                                        fontFamily: "Poppins"),
                                  ),
                                  trailing: const Text('2h ago'),
                                  tileColor: AppColors.surface,
                                );
                              },
                              childCount: comments.length,
                            ),
                          ),
                          // Bottom padding for input field
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 70),
                          ),
                        ],
                      ),
                    ),
                    // Fixed comment input at bottom
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, -2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          IconButton(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.attach_file,
                                color: AppColors.surface,
                              )),
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send,
                                color: AppColors.success),
                            onPressed: () {
                              if (commentController.text.isNotEmpty) {
                                setState(() {
                                  comments.add(commentController.text);
                                });
                                commentController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openBottomSheet(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            CachedNetworkImage(
                imageUrl: widget.media[0]['url'] ?? '',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: widget.profilePic != null
                                ? CachedNetworkImageProvider(widget.profilePic!)
                                : null,
                            child: widget.profilePic != null
                                ? null
                                : const Icon(Icons.person,
                                    size: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Text('${widget.authorName ?? ""}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text('1/${widget.media.length}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
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
      cacheExtent: 1000, // Cache extra content
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

// class SimpleAudioPlayer extends StatefulWidget {
//   final String title;
//   final String artist;

//   const SimpleAudioPlayer({
//     Key? key,
//     required this.title,
//     required this.artist,
//   }) : super(key: key);

//   @override
//   _SimpleAudioPlayerState createState() => _SimpleAudioPlayerState();
// }

// class _SimpleAudioPlayerState extends State<SimpleAudioPlayer>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _waveController;
//   bool isPlaying = false;

//   @override
//   void initState() {
//     super.initState();
//     _waveController = AnimationController(
//       vsync: this,
//       duration: Duration(seconds: 2),
//     )..repeat();
//   }

//   @override
//   void dispose() {
//     _waveController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Colors.blue.shade900, Colors.blue.shade700],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         //borderRadius: BorderRadius.circular(16),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             children: [
//               CircleAvatar(
//                 radius: 24,
//                 backgroundColor: Colors.white24,
//                 child: Icon(Icons.music_note, color: Colors.white),
//               ),
//               SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       widget.title,
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       widget.artist,
//                       style: TextStyle(
//                         color: Colors.white70,
//                         fontSize: 14,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 16),
//           // Animated Waveform
//           SizedBox(
//             height: 40,
//             child: AnimatedBuilder(
//               animation: _waveController,
//               builder: (context, child) {
//                 return CustomPaint(
//                   size: Size(double.infinity, 40),
//                   painter: WaveformPainter(
//                     progress: _waveController.value,
//                     isPlaying: isPlaying,
//                   ),
//                 );
//               },
//             ),
//           ),
//           SizedBox(height: 16),
//           // Controls
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // IconButton(
//               //   icon: Icon(Icons.skip_previous, color: Colors.white70),
//               //   onPressed: () {},
//               // ),
//               FloatingActionButton(
//                 mini: true,
//                 backgroundColor: Colors.white,
//                 child: Icon(
//                   isPlaying ? Icons.pause : Icons.play_arrow,
//                   color: Colors.blue.shade900,
//                 ),
//                 onPressed: () {
//                   setState(() {
//                     isPlaying = !isPlaying;
//                   });
//                 },
//               ),
//               // IconButton(
//               //   icon: Icon(Icons.skip_next, color: Colors.white70),
//               //   onPressed: () {},
//               // ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// class WaveformPainter extends CustomPainter {
//   final double progress;
//   final bool isPlaying;

//   WaveformPainter({required this.progress, required this.isPlaying});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.white.withOpacity(0.5)
//       ..strokeWidth = 2
//       ..strokeCap = StrokeCap.round;

//     final width = size.width;
//     final height = size.height;
//     final barWidth = 4.0;
//     final space = 3.0;
//     final barCount = (width / (barWidth + space)).floor();

//     for (var i = 0; i < barCount; i++) {
//       final x = i * (barWidth + space);
//       final normalized = (i / barCount);
//       final amplitude = isPlaying
//           ? sin((normalized * 8 + progress * 2) * pi) * 0.5 + 0.5
//           : 0.2;

//       final barHeight = height * amplitude;
//       final y = (height - barHeight) / 2;

//       canvas.drawLine(Offset(x, y), Offset(x, y + barHeight), paint);
//     }
//   }

//   @override
//   bool shouldRepaint(WaveformPainter oldDelegate) =>
//       progress != oldDelegate.progress || isPlaying != oldDelegate.isPlaying;
// }
