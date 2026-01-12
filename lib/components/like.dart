import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ButtonType { post, comment, user }

class LikeButton extends StatefulWidget {
  final String postId;
  final ButtonType buttonType;
  final int initialLikes;
  final bool initiallyLiked;
  final bool showLikeCount;
  final Future<bool> Function(bool isLiked) onLikeChanged;

  LikeButton({
    required this.buttonType,
    required this.initialLikes,
    required this.initiallyLiked,
    required this.onLikeChanged,
    this.showLikeCount = false,
    required this.postId,
  });

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  late bool isLiked;
  late int likes;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    isLiked = widget.initiallyLiked;
    likes = widget.initialLikes;

    loadLike();
  }

  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLikes != widget.initialLikes) {
      setState(() {
        likes = widget.initialLikes;
      });
    }
    if (oldWidget.initiallyLiked != widget.initiallyLiked) {
      setState(() {
        isLiked = widget.initiallyLiked;
      });
    }
  }

  String formatLikes(int number) {
    if (number >= 1000000000) {
      return (number / 1000000000).toStringAsFixed(1) + 'B';
    } else if (number >= 1000000) {
      return (number / 1000000).toStringAsFixed(1) + 'M';
    } else if (number >= 1000) {
      return (number / 1000).toStringAsFixed(1) + 'K';
    } else {
      return number.toString();
    }
  }

  void loadLike() async {
    prefs = await SharedPreferences.getInstance();
    if (widget.postId != null) {
      final like = await prefs.getString(widget.postId!);
      if (like != null) {
        setState(() {
          isLiked = true;
        });
      }
    }
  }

  void toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likes += isLiked ? 1 : -1;
      if (likes < 0) likes = 0;
    });

    bool result = await widget.onLikeChanged(isLiked); // Notify parent widget
    if (result == false) {
      if (widget.postId != null) {
        await prefs.remove(widget.postId!);
      }
      setState(() {
        isLiked = false;
        likes += isLiked ? 1 : -1;
        if (likes < 0) likes = 0;
      });
    } else {
      if (widget.postId != null) {
        prefs.setString(widget.postId!, isLiked.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.buttonType == ButtonType.post
        ? buildLikeButtonForPosts()
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: toggleLike,
                child: Icon(
                  Icons.favorite,
                  color: isLiked ? Colors.red : Colors.white54,
                ),
              ),
              if (widget.showLikeCount)
                Text(
                  formatLikes(likes),
                  style: TextStyle(fontSize: 10, color: Colors.white54),
                ),
            ],
          );
  }

  Widget buildLikeButtonForPosts() {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: toggleLike,
            child: Icon(
              Icons.favorite,
              color: isLiked ? Colors.red : Colors.grey,
              size: 24.0,
            ),
          ),
          SizedBox(width: 8.0),
          Text(
            formatLikes(likes),
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
