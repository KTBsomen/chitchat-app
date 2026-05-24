import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/services/instant_match_service.dart';
import 'package:flutter/material.dart';

class InstantMatchScreen extends StatefulWidget {
  const InstantMatchScreen({Key? key}) : super(key: key);

  @override
  _InstantMatchScreenState createState() => _InstantMatchScreenState();
}

class _InstantMatchScreenState extends State<InstantMatchScreen> {
  final InstantMatchService _service = InstantMatchService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  
  StreamSubscription? _stateSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _readStatusSubscription;
  StreamSubscription? _errorSubscription;

  bool _partnerIsTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _service.init();
    
    _stateSubscription = _service.stateStream.listen((state) {
      if (mounted) setState(() {});
      if (state == MatchState.chatting) {
        // Clear messages when a new match starts
        setState(() {
          _messages.clear();
          _partnerIsTyping = false;
        });
      }
    });

    _messageSubscription = _service.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add({
            ...msg,
            'isRead': false,
          });
        });
        _scrollToBottom();
      }
    });

    _typingSubscription = _service.typingStream.listen((data) {
      if (mounted && data['userId'] == _service.partnerId) {
        setState(() {
          _partnerIsTyping = data['isTyping'] ?? false;
        });
      }
    });

    _readStatusSubscription = _service.readStatusStream.listen((data) {
      if (mounted) {
        setState(() {
          for (var msg in _messages) {
            if (msg['messageId'] == data['messageId']) {
              msg['isRead'] = true;
            }
          }
        });
      }
    });

    _errorSubscription = _service.errorStream.listen((errMsg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errMsg,
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    });

    // Show gender selection bottom sheet on start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGenderSelection();
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _readStatusSubscription?.cancel();
    _errorSubscription?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _service.leaveMatch();
    super.dispose();
  }

  void _onTypingChanged(String value) {
    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
    
    _service.sendTyping(true);
    
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _service.sendTyping(false);
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? _lastPreference;

  void _showGenderSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const GenderSelectionSheet(),
    ).then((selection) {
      if (selection != null) {
        _lastPreference = selection;
        _service.startMatching(selection);
      } else if (_service.state == MatchState.idle) {
        Navigator.pop(context);
      }
    });
  }

  void _findNextMatch() {
    if (_lastPreference != null) {
      _service.leaveMatch();
      _service.startMatching(_lastPreference!);
    } else {
      _showGenderSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SafeArea(
            child: _buildBody(),
          ),
          
          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () {
                _service.leaveMatch();
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_service.state) {
      case MatchState.idle:
        return const Center(
          child: Text(
            "Ready to connect?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontFamily: 'PassionOne',
            ),
          ),
        );
      case MatchState.searching:
        return _buildSearchingView();
      case MatchState.chatting:
      case MatchState.ended:
        return _buildChatView();
    }
  }

  Widget _buildSearchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const RadarAnimation(),
          const SizedBox(height: 40),
          const Text(
            "Finding someone special...",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Hold tight, matching you with Gen Z stars",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 50),
          _buildActionButton(
            "Cancel",
            Colors.white24,
            () {
              _service.leaveMatch();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(60, 20, 20, 10),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _service.partnerAlias ?? "Anonymous",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'PassionOne',
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    "${_service.partnerProfile?['institute'] ?? 'Student'} • ${_service.partnerProfile?['gender'] ?? 'Unknown'}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (_service.state == MatchState.chatting)
                _buildActionButton(
                  "Skip",
                  Colors.redAccent.withOpacity(0.8),
                  _findNextMatch,
                  compact: true,
                ),
            ],
          ),
        ),
        
        const Divider(color: Colors.white10),
        
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final isMe = msg['from'] != _service.partnerId;
              return _buildMessageBubble(msg, isMe);
            },
          ),
        ),
        
        // Input or Ended View
        _service.state == MatchState.ended 
          ? _buildMatchEndedOverlay()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_partnerIsTyping)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "${_service.partnerAlias ?? 'Partner'} is typing...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                _buildMessageInput(),
              ],
            ),
      ],
    );
  }

  Widget _buildMatchEndedOverlay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Match ended by partner",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  "Find Next",
                  AppColors.primary,
                  _findNextMatch,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildActionButton(
                  "Exit",
                  Colors.white24,
                  () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primary : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 20),
              ),
            ),
            child: Text(
              msg['message'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'Poppins',
              ),
            ),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 8),
              child: Icon(
                Icons.done_all,
                size: 14,
                color: (msg['isRead'] ?? false) ? Colors.blueAccent : Colors.white38,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _messageController,
                onChanged: _onTypingChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    _service.sendMessage(_messageController.text.trim());
    setState(() {
      _messages.add({
        'from': 'me',
        'message': _messageController.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _messageController.clear();
    _scrollToBottom();
    _service.sendTyping(false);
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap, {bool compact = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 40,
          vertical: compact ? 8 : 15,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 13 : 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }
}

class GenderSelectionSheet extends StatelessWidget {
  const GenderSelectionSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF16163F).withOpacity(0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Who's on your mind?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'PassionOne',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Select who you'd like to vibe with tonight",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 40),
            _buildOption(context, "Connect with Boys", "Male", Icons.male, Colors.blueAccent),
            const SizedBox(height: 15),
            _buildOption(context, "Connect with Girls", "Female", Icons.female, Colors.pinkAccent),
            const SizedBox(height: 15),
            _buildOption(context, "Anyone is Cool!", "Any", Icons.all_inclusive, Colors.purpleAccent),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String title, String value, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}

class RadarAnimation extends StatefulWidget {
  const RadarAnimation({Key? key}) : super(key: key);

  @override
  _RadarAnimationState createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Radar Circles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: RadarPainter(_controller.value),
              size: const Size(250, 250),
            );
          },
        ),
        
        // Central Logo/Avatar
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.flash_on, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }
}

class RadarPainter extends CustomPainter {
  final double value;
  RadarPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final currentProgress = (value + i / 3) % 1.0;
      final radius = maxRadius * currentProgress;
      final opacity = 1.0 - currentProgress;

      final paint = Paint()
        ..color = AppColors.primary.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(center, radius, paint);
      
      final fillPaint = Paint()
        ..color = AppColors.primary.withOpacity(opacity * 0.1)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(center, radius, fillPaint);
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}
