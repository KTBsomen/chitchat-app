import 'dart:ui';

import 'package:chitchat/components/bottomnav.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/components/recomandedgroups.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/search.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/watchlist.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:page_transition/page_transition.dart';

class SearchResultsPage extends StatefulWidget {
  final String name;
  final String type;

  SearchResultsPage({required this.name, required this.type});

  @override
  _SearchResultsPageState createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  int selectedTab = 0;
  final Random _random = Random();
  bool isLoading = false;

  // Sample data with positions for map-like layout
  List<dynamic> friendGroups = [];
  List<List<int>> connections = []; // Which circles connect to which
  String escapeRegex(String input) {
    return input.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (Match m) => '\\${m[0]}',
    );
  }

  // Simulate API call - replace with your actual API call
  Future<void> _loadWatchlistData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Generate friend groups with positions
      friendGroups =
          await SearchService.searchByGroup(escapeRegex(widget.name));
      print("Loaded groups: $friendGroups");

      // Generate connections between circles (like a network map)
      //_generateConnections();
    } catch (e) {
      print('Error loading groups: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _generateConnections() {
    connections.clear();
    for (int i = 0; i < friendGroups.length; i++) {
      // Each circle connects to 1-3 other circles
      int numConnections = 1;
      for (int j = 0; j < numConnections; j++) {
        int targetIndex = _random.nextInt(friendGroups.length);
        if (targetIndex != i && !_connectionExists(i, targetIndex)) {
          connections.add([i, targetIndex]);
        }
      }
    }
  }

  bool _connectionExists(int from, int to) {
    return connections.any((conn) =>
        (conn[0] == from && conn[1] == to) ||
        (conn[0] == to && conn[1] == from));
  }

  @override
  void initState() {
    super.initState();
    _loadWatchlistData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: AppBottomNav(),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Tab Header only
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => setState(() => selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        '${friendGroups.isNotEmpty ? "Showing Top ${friendGroups.length} Groups" : isLoading ? 'Searching for groups...' : 'No groups found'} ',
                        style: TextStyle(
                          color: selectedTab == 0 ? Colors.white : Colors.grey,
                          fontSize: 16,
                          fontWeight: selectedTab == 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(width: 40),
                  // GestureDetector(
                  //   onTap: () => setState(() => selectedTab = 1),
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(
                  //         horizontal: 16, vertical: 8),
                  //     child: Text(
                  //       'for you',
                  //       style: TextStyle(
                  //         color: selectedTab == 1 ? Colors.white : Colors.grey,
                  //         fontSize: 16,
                  //         fontWeight: selectedTab == 1
                  //             ? FontWeight.w600
                  //             : FontWeight.w400,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child:
                  selectedTab == 0 ? _buildWatchlistTab() : _buildForYouTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchlistTab() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your ${widget.type.toLowerCase()} groups...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    // Calculate all positions with collision detection
    List<Offset> positions = _calculateAllCirclePositions();
    print("===================???${(friendGroups.length ~/ 3)}");
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(80),
      minScale: 0.3,
      maxScale: 1,
      constrained: false,
      child: Container(
        width: MediaQuery.of(context).size.width * 3,
        height: ((friendGroups.length / 3) * 300) + 500,
        child: CustomPaint(
          painter: ConnectionsPainter(
            friendGroups: friendGroups,
            connections: connections,
            context: context,
          ),
          child: Stack(
            children: friendGroups.asMap().entries.map((entry) {
              int index = entry.key;
              FriendCircleGroup group = entry.value;

              Offset position = positions[index];

              return Positioned(
                left: position.dx - 125, // Half of circle size (250/2)
                top: position.dy - 125,
                child: FriendCircle(
                  group: group,
                  size: 250,
                  nodeSize: 70,
                  onGroupTap: () {
                    print('Tapped on group: ${group.groupId}');
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: GroupPublicViewScreen(
                          groupId: group.groupId,
                        ),
                      ),
                    );
                  },
                  onMemberTap: (index) {
                    print('Tapped on member $index of group ${group.groupId}');
                    Navigator.push(
                      context,
                      PageTransition(
                        type: PageTransitionType.rightToLeft,
                        child: PublicProfilePage(
                            dbIndex:
                                group.members[index].additionalData['dbIndex'],
                            uid: group.members[index].id),
                      ),
                    );
                  },
                  edgeStyle: EdgeStyle(
                    width: 6,
                    outerGlow: 5,
                    gradientColors: [Colors.blue, Colors.pink, Colors.orange],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<Offset> _calculateAllCirclePositions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Expanded canvas size
    final canvasWidth = screenWidth * 3;
    final canvasHeight = (friendGroups.length / 3) * 300 + 500;

    const double circleRadius = 125; // Half of circle size (250/2)
    const double minDistance = 250; // Minimum distance between circle centers
    const int maxAttempts = 100; // Max attempts to place each circle

    List<Offset> positions = [];
    Random random = Random(42); // Fixed seed for consistent layout

    for (int i = 0; i < friendGroups.length; i++) {
      Offset? newPosition;
      int attempts = 0;

      while (newPosition == null && attempts < maxAttempts) {
        // Try different placement strategies based on number of circles
        Offset candidate;

        if (friendGroups.length <= 0) {
          // For few circles, use corners and center
          candidate =
              _getCornerPosition(i, canvasWidth, canvasHeight, circleRadius);
        } else {
          // For medium number, use grid with some randomness
          candidate = _getGridPosition(
              i, canvasWidth, canvasHeight, circleRadius, random);
        }
        // Check collision with existing circles
        bool hasCollision = false;
        for (Offset existingPos in positions) {
          double distance = (candidate - existingPos).distance;
          if (distance < minDistance) {
            hasCollision = true;
            break;
          }
        }

        if (!hasCollision) {
          newPosition = candidate;
        }

        attempts++;
      }

      // If we couldn't find a good position, use fallback
      if (newPosition == null) {
        newPosition = _getFallbackPosition(
            i, canvasWidth, canvasHeight, circleRadius, positions);
      }

      positions.add(newPosition);
    }

    return positions;
  }

  Offset _getCornerPosition(
      int index, double width, double height, double radius) {
    const double margin = 200;
    switch (index % 4) {
      case 0:
        return Offset(margin + radius, margin + radius);
      case 1:
        return Offset(width - margin - radius, margin + radius);
      case 2:
        return Offset(margin + radius, height - margin - radius);
      case 3:
        return Offset(width - margin - radius, height - margin - radius);
      default:
        return Offset(width / 2, height / 2);
    }
  }

  Offset _getGridPosition(
      int index, double width, double height, double radius, Random random) {
    int cols = 3;
    int row = index ~/ cols;
    int col = index % cols;

    double baseX = (col + 0.5) * (width / cols);
    double baseY = (row + 0.5) * (height / (friendGroups.length / cols).ceil());

    // Add controlled randomness
    double offsetX = (random.nextDouble() - 0.5) * 150;
    double offsetY = (random.nextDouble() - 0.5) * 150;

    return Offset(
      (baseX + offsetX).clamp(radius + 50, width - radius - 50),
      (baseY + offsetY).clamp(radius + 50, height - radius - 50),
    );
  }

  Offset _getSpiralPosition(
      int index, double width, double height, double radius, Random random) {
    double centerX = width / 2;
    double centerY = height / 2;

    // Spiral parameters
    double angle = index * 0.8; // Angle increment
    double spiralRadius = 50 + (index * 40); // Increasing radius

    double x = centerX + spiralRadius * cos(angle);
    double y = centerY + spiralRadius * sin(angle);

    // Add some randomness to break perfect spiral
    double offsetX = (random.nextDouble() - 0.5) * 100;
    double offsetY = (random.nextDouble() - 0.5) * 100;

    return Offset(
      (x + offsetX).clamp(radius + 50, width - radius - 50),
      (y + offsetY).clamp(radius + 50, height - radius - 50),
    );
  }

  Offset _getFallbackPosition(int index, double width, double height,
      double radius, List<Offset> existingPositions) {
    // Simple fallback: place in a line with enough spacing
    double spacing = 350;
    int itemsPerRow = (width / spacing).floor();

    int row = index ~/ itemsPerRow;
    int col = index % itemsPerRow;

    double x = (col + 0.5) * spacing;
    double y = (row + 0.5) * spacing + 200;

    return Offset(
      x.clamp(radius + 50, width - radius - 50),
      y.clamp(radius + 50, height - radius - 50),
    );
  }

  Color _getAvatarColor(int avatarType) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];
    return colors[avatarType % colors.length];
  }

  Widget _buildForYouTab() {
    return Recomandedgroups();
  }
}

// Custom painter to draw connection lines between circles
class ConnectionsPainter extends CustomPainter {
  final List<dynamic> friendGroups;
  final List<List<int>> connections;
  final BuildContext context;

  ConnectionsPainter({
    required this.friendGroups,
    required this.connections,
    required this.context,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final screenWidth = MediaQuery.of(context).size.width;

    for (var connection in connections) {
      int fromIndex = connection[0];
      int toIndex = connection[1];

      if (fromIndex < friendGroups.length && toIndex < friendGroups.length) {
        Offset fromPos = _calculateCirclePosition(fromIndex, screenWidth);
        Offset toPos = _calculateCirclePosition(toIndex, screenWidth);

        // Draw curved lines for more organic feel
        Path path = Path();
        path.moveTo(fromPos.dx, fromPos.dy);

        // Add slight curve to the connection
        Offset midPoint = Offset(
          (fromPos.dx + toPos.dx) / 2 +
              (Random(fromIndex + toIndex).nextDouble() - 0.5) * 50,
          (fromPos.dy + toPos.dy) / 2,
        );

        path.quadraticBezierTo(midPoint.dx, midPoint.dy, toPos.dx, toPos.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  Offset _calculateCirclePosition(int index, double screenWidth) {
    final Random posRandom = Random(index);
    int cols = 3;
    int row = index ~/ cols;
    int col = index % cols;

    double baseX = (col + 0.5) * (screenWidth * 2 / cols);
    double baseY = (row + 0.5) * 200 + 100;

    double offsetX = (posRandom.nextDouble() - 0.5) * 100;
    double offsetY = (posRandom.nextDouble() - 0.5) * 80;

    return Offset(
      (baseX + offsetX).clamp(100.0, screenWidth * 2 - 100),
      (baseY + offsetY).clamp(100.0, double.infinity),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
