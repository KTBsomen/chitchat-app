import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A self-contained feed video widget that auto-plays muted when visible
/// and pauses when scrolled out of view.
class FeedVideoPlayer extends StatefulWidget {
  final String url;
  final VoidCallback? onTap;

  const FeedVideoPlayer({
    Key? key,
    required this.url,
    this.onTap,
  }) : super(key: key);

  @override
  State<FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<FeedVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0.0); // start muted
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        // If already visible when init completes, start playing
        if (_isVisible) {
          _controller!.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction >= 0.5;
    _isVisible = visible;

    if (!_initialized || _controller == null) return;

    if (visible) {
      if (!_controller!.value.isPlaying) {
        _controller!.play();
      }
    } else {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('feed-video-${widget.url}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 200,
          height: 300,
          child: _hasError
              ? _buildErrorFallback()
              : _initialized
                  ? _buildPlayer()
                  : _buildLoading(),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        // Mute toggle
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorFallback() {
    return Container(
      color: Colors.black12,
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 48,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
