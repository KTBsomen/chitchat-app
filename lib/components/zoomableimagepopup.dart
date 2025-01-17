import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ZoomableImagePopup extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  const ZoomableImagePopup({
    super.key,
    required this.imageUrl,
    required this.onClose,
    this.onEdit,
  });

  @override
  State<ZoomableImagePopup> createState() => _ZoomableImagePopupState();
}

class _ZoomableImagePopupState extends State<ZoomableImagePopup>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  final double _minScale = 1.0;
  final double _maxScale = 4.0;
  late TapDownDetails _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    Matrix4 matrix = _transformationController.value;
    final double currentScale = matrix.getMaxScaleOnAxis();

    final Offset position = _doubleTapDetails.localPosition;

    if (currentScale == _minScale) {
      final Matrix4 zoomed = Matrix4.identity()
        ..translate(
            -position.dx * (_maxScale - 1), -position.dy * (_maxScale - 1))
        ..scale(_maxScale);
      _animateMatrix(zoomed);
    } else {
      _animateMatrix(Matrix4.identity());
    }
  }

  void _animateMatrix(Matrix4 end) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: end,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onDoubleTapDown: _handleDoubleTapDown,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: _minScale,
          maxScale: _maxScale,
          clipBehavior: Clip.none,
          child: Stack(
            children: [
              Container(
                color: Colors.black.withOpacity(0.9),
                child: Center(
                  child: Hero(
                    tag: widget.imageUrl,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (widget.onEdit != null)
                Positioned(
                  top: 40,
                  right: 300,
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: widget.onEdit,
                  ),
                ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ZoomableImage extends StatefulWidget {
  final String imageUrl;

  const ZoomableImage({required this.imageUrl, Key? key}) : super(key: key);

  @override
  _ZoomableImageState createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  double _scale = 1.0; // Current scale
  double _previousScale = 1.0; // Scale before the current gesture
  Offset _offset = Offset.zero; // Current translation offset
  Offset _startOffset = Offset.zero; // Offset at the start of the gesture

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _previousScale = _scale;
        _startOffset = details.focalPoint - _offset;
      },
      onScaleUpdate: (details) {
        setState(() {
          // Update the scale and offset
          _scale = (_previousScale * details.scale)
              .clamp(1.0, 4.0); // Limit zoom between 1x and 4x
          _offset = details.focalPoint - _startOffset;
        });
      },
      onScaleEnd: (_) {
        // Optionally, add logic to reset or snap back to bounds
      },
      child: ClipRect(
        // Clip the image to prevent it from overflowing
        child: Transform.translate(
          offset: _offset,
          child: Transform.scale(
            scale: _scale,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
