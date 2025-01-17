import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math';

class SimpleAudioPlayer extends StatefulWidget {
  final String title;
  final String artist;
  final String audioUrl;

  const SimpleAudioPlayer({
    Key? key,
    required this.title,
    required this.artist,
    required this.audioUrl,
  }) : super(key: key);

  @override
  _SimpleAudioPlayerState createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late AnimationController _waveController;
  bool isPlaying = false;
  bool isBuffering = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _audioPlayer.playerStateStream.listen((state) {
      print(state);
      setState(() {
        isPlaying = state.playing;
        isBuffering = state.processingState == ProcessingState.buffering ||
            state.processingState == ProcessingState.loading;
      });
    });

    _audioPlayer.setUrl(widget.audioUrl);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(Icons.music_note, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 69),
          // Animated Waveform
          SizedBox(
            height: 40,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 40),
                  painter: WaveformPainter(
                    progress: _waveController.value,
                    isPlaying: isPlaying && !isBuffering,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // IconButton(
              //   icon: const Icon(Icons.skip_previous, color: Colors.white70),
              //   onPressed: () {},
              // ),
              FloatingActionButton(
                // mini: true,
                backgroundColor: Colors.white,
                child: isBuffering
                    ? CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation(Colors.blue.shade900),
                      )
                    : Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.blue.shade900,
                      ),
                onPressed: () async {
                  if (isPlaying) {
                    await _audioPlayer.pause();
                  } else {
                    await _audioPlayer.play();
                  }
                },
              ),
              // IconButton(
              //   icon: const Icon(Icons.skip_next, color: Colors.white70),
              //   onPressed: () {},
              // ),
            ],
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;

  WaveformPainter({required this.progress, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final barWidth = 4.0;
    final space = 3.0;
    final barCount = (width / (barWidth + space)).floor();

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + space);
      final normalized = (i / barCount);
      final amplitude = isPlaying
          ? (sin((normalized * 8 + progress * 2) * pi + 45) * 0.5 + 0.5) +
              sin((normalized * 4.3 + progress * 2) * pi + 456) * 0.9 +
              sin((normalized * 2.7 + progress * 2) * pi + 450) * 0.7
          : 0.2;

      final barHeight = height * amplitude;
      final y = (height - barHeight) / 2;

      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      progress != oldDelegate.progress || isPlaying != oldDelegate.isPlaying;
}
