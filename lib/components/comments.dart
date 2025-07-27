import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/simpleaudioplayer.dart';
import 'package:chitchat/components/videoWidget.dart';
import 'package:flutter/material.dart';

Map<String, dynamic> myProfile =
    AppVariables.get<Map<String, dynamic>>('profile') ?? {};

class Media {
  final String type;
  final String url;

  Media({
    required this.type,
    required this.url,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      type: json['type'],
      url: json['url'],
    );
  }
}

class Comment {
  final String Id;
  final String author;
  final String postId;
  final String content;
  final String authorName;
  final String profilePic;
  final DateTime createdAt;
  final List<Media> media; // List of media objects
  final int likes;
  final bool hasMore;
  final String lastId;

  Comment({
    required this.Id,
    required this.author,
    required this.postId,
    required this.content,
    required this.authorName,
    required this.profilePic,
    required this.createdAt,
    required this.media,
    required this.likes,
    this.hasMore = false,
    this.lastId = '',
  });
  factory Comment.fromJson(Map<String, dynamic> json) {
    var mediaList = (json['media'] as List)
        .map((mediaJson) => Media.fromJson(mediaJson))
        .toList();

    return Comment(
      Id: json['_id'],
      author: json['author'],
      postId: json['post'],
      content: json['content'],
      authorName: json['authorName'],
      profilePic: json['profilePic'],
      media: mediaList,
      likes: json['likes'],
      createdAt: DateTime.parse(json['createdAt']),
      hasMore: json['hasMore'] ?? false,
      lastId: json['lastId'] ?? '',
    );
  }
  String get timeAgo => _timeAgo(createdAt.toIso8601String());

  // Method to format "time ago"
  static String _timeAgo(String mongoDate) {
    try {
      final date = DateTime.parse(mongoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inSeconds < 60) {
        return '${difference.inSeconds} seconds ago';
      }
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} minutes ago';
      }
      if (difference.inHours < 24) return '${difference.inHours} hours ago';
      if (difference.inDays < 7) return '${difference.inDays} days ago';
      if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      }
      if (difference.inDays < 365) {
        return '${(difference.inDays / 30).floor()} months ago';
      }
      return '${(difference.inDays / 365).floor()} years ago';
    } catch (e) {
      return 'Invalid date';
    }
  }
}

class CommentsManager {
  final List<Comment> _comments = [];
  final StreamController<List<Comment>> _commentsStreamController =
      StreamController.broadcast();
  Timer? _timer;

  CommentsManager() {
    // Periodically update the comments list with refreshed "time ago"
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _commentsStreamController.add(_comments); // Notify listeners
    });
  }

  Stream<List<Comment>> get commentsStream => _commentsStreamController.stream;

  List<Comment> get comments => List.unmodifiable(_comments);

  void addComment(String content, String author, String PostId,
      String authorName, String profilePic, List<Media> media) {
    final newComment = Comment(
      Id: '${_comments.length + 1}',
      author: author,
      postId: PostId,
      content: content,
      authorName: authorName,
      profilePic: profilePic,
      createdAt: DateTime.now(),
      media: media,
      likes: 0,
    );
    _comments.add(newComment);
    _commentsStreamController.add(_comments); // Notify listeners
  }

  void loadComments(List<Map<String, dynamic>> mongoComments) {
    for (var commentData in mongoComments) {
      _comments.add(
        Comment(
          Id: commentData['_id'],
          author: commentData['author'],
          postId: commentData['post'],
          content: commentData['content'],
          authorName: commentData['authorName'],
          profilePic: commentData['profilePic'],
          createdAt: DateTime.parse(commentData['createdAt']),
          media: List<Media>.from(commentData['media']),
          likes: commentData['likes'],
        ),
      );
    }
    _commentsStreamController.add(_comments); // Notify listeners
  }

  void dispose() {
    _commentsStreamController.close();
    _timer?.cancel();
  }
}

class CommentMedia extends StatelessWidget {
  final List<Media> media;

  CommentMedia({required this.media});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: media.map((mediaItem) {
        switch (mediaItem.type) {
          case 'video':
            return VideoWidget(url: mediaItem.url);
          case 'image':
            return CachedNetworkImage(
              imageUrl: mediaItem.url,
              placeholder: (context, url) => CircularProgressIndicator(),
              errorWidget: (context, url, error) => Icon(Icons.error),
            );
          case 'audio':
            return AudioWidget(url: mediaItem.url);
          default:
            return SizedBox.shrink();
        }
      }).toList(),
    );
  }
}

class VideoWidget extends StatefulWidget {
  final String url;

  const VideoWidget({Key? key, required this.url}) : super(key: key);

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 200,
        child: VideoMessageView(
          url: widget.url,
        ));
  }
}

class AudioWidget extends StatelessWidget {
  final String url;

  AudioWidget({required this.url});

  @override
  Widget build(BuildContext context) {
    return SimpleAudioPlayer(title: "", artist: "", audioUrl: url);
  }
}

class CommentListView extends StatelessWidget {
  final List<Comment> comments;

  CommentListView({required this.comments});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            leading:
                CircleAvatar(backgroundImage: NetworkImage(comment.profilePic)),
            title: Text(comment.authorName),
            trailing: IconButton(onPressed: null, icon: Icon(Icons.favorite)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.content),
                SizedBox(height: 8),
                Text(comment.timeAgo),
                SizedBox(height: 8),
                CommentMedia(media: comment.media),
              ],
            ),
          ),
        );
      },
    );
  }
}
