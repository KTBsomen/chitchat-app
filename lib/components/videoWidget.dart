import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:chatview/chatview.dart';
import 'package:chitchat/main.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:visibility_detector/visibility_detector.dart';

class VideoMessageView extends StatefulWidget {
  const VideoMessageView({
    super.key,
    required this.url,
    this.onTap,
    this.height, // Made height configurable
    this.highlightVideo = false,
    this.highlightScale = 1.2,
  });

  final String url;
  final VoidCallback? onTap;
  final double? height;
  final bool highlightVideo;
  final double highlightScale;

  @override
  State<VideoMessageView> createState() => _VideoMessageViewState();
}

class _VideoMessageViewState extends State<VideoMessageView> with RouteAware {
  Uint8List? _thumbnailBytes;
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVisible = false;
  bool _isMuted = true;
  bool _isRouteActive = true;
  bool _disposed = false;
  bool _isInitializing = false;

  String get videoUrl => widget.url;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
    // DO NOT init controller here — wait until visible (lazy init)
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _isRouteActive = false;
    // Fully dispose the controller to release the native hardware decoder
    _releaseController();
  }

  @override
  void didPopNext() {
    _isRouteActive = true;
    // Lazy re-init will pick it up if visible via _onVisibilityChanged
    if (_isVisible && !_isInitialized && !_isInitializing) {
      _initController();
    }
  }

  void _releaseController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isInitializing = false;
    if (mounted) setState(() {});
  }

  Future<void> _initController() async {
    if (_isInitializing || _disposed) return;
    _isInitializing = true;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      // Check disposed BEFORE the expensive network call
      if (_disposed) {
        controller.dispose();
        return;
      }
      await controller.initialize();
      // Check disposed AFTER the async gap
      if (_disposed) {
        controller.dispose();
        return;
      }
      _controller = controller;
      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        if (_isVisible && _isRouteActive) {
          _controller!.play();
        }
      }
    } catch (e) {
      debugPrint("VideoMessageView: Error initializing video: $e");
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _generateThumbnail() async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.PNG,
        quality: 75,
      );
      if (uint8list != null && mounted && !_disposed) {
        setState(() {
          _thumbnailBytes = uint8list;
        });
      }
    } catch (e) {
      // silently fail, fallback to placeholder
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted || _disposed) return;
    final visible = info.visibleFraction >= 0.5;
    _isVisible = visible;

    // Lazy init: only create the controller when scrolled into view
    if (visible && !_isInitialized && !_isInitializing) {
      _initController();
      return;
    }

    if (!_isInitialized || _controller == null) return;

    if (visible && _isRouteActive) {
      if (!_controller!.value.isPlaying) {
        _controller!.play();
      }
    } else {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    routeObserver.unsubscribe(this);
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-view-${widget.url}-${identityHashCode(this)}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: SizedBox(
        width: double.infinity,
        height: widget.height ?? 240,
        child: Stack(
          children: [
            GestureDetector(
              onTap: widget.onTap ??
                  () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenVideoPlayer(
                            videoUrl: videoUrl,
                            heroTag: widget.url,
                            fromMemory: false,
                          ),
                        ),
                      ),
              onPanUpdate: (_) {
                if (_isInitialized &&
                    _controller != null &&
                    !_controller!.value.isPlaying &&
                    _isVisible &&
                    _isRouteActive) {
                  _controller!.play();
                }
              },
              child: SizedBox.expand(
                child: _isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      )
                    : (_thumbnailBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _thumbnailBytes!,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                color: Colors.black26,
                              ),
                              Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 48,
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: Colors.black12,
                            child: Center(
                              child: Icon(
                                Icons.videocam,
                                size: 32,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          )),
              ),
            ),
            if (_isInitialized)
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool fromMemory;
  final String heroTag;

  const FullScreenVideoPlayer({
    Key? key,
    required this.videoUrl,
    required this.heroTag,
    this.fromMemory = false,
  }) : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();

    if (widget.fromMemory) {
      // decode base64 video string to bytes and create temp file
      final base64String =
          widget.videoUrl.substring(widget.videoUrl.indexOf('base64') + 7);
      final bytes = base64Decode(base64String);
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/${widget.heroTag}_video.mp4');
      file.writeAsBytesSync(bytes);
      _controller = VideoPlayerController.file(file);
    } else if (widget.videoUrl.startsWith('http')) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }

    _controller?.initialize().then((_) {
      setState(() {});
      _controller?.play();
      _controller?.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 1, 31),
      body: Center(
        child: Hero(
          tag: widget.heroTag,
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
            } else {
              _controller!.play();
            }
          });
        },
        child: Icon(
          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}
