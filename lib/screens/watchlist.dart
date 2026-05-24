import 'dart:ui';

import 'package:chitchat/components/bottomnav.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/components/recomandedgroups.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/watchlist.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:chitchat/screens/instant_match_screen.dart';
import 'package:chitchat/screens/campus_chat_screen.dart';
import 'package:chitchat/services/groups.dart';
import 'package:page_transition/page_transition.dart';

class WatchlistPage extends StatefulWidget {
  @override
  _WatchlistPageState createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  int selectedTab = 0; // 0: campus lounge, 1: my watchlist, 2: for you
  bool isLoading = false;
  bool isLoadingMore = false;
  List<dynamic> friendGroups = [];
  bool isLoadingCampusLounge = false;
  List<dynamic> campusLoungeGroups = [];
  // Cursor-based pagination state for campus lounge
  String? _campusLoungeCursor;
  bool _campusLoungeHasMore = true;
  // Cursor-based pagination state for recommended groups (For You tab)
  String? _recommendedCursor;
  bool _recommendedHasMore = true;
  final TransformationController _transformationController =
      TransformationController();
  final ScrollController _scrollController = ScrollController();
  double currentScale = 1.0;

  // Fixed small size - always consistent
  static const double FIXED_CIRCLE_SIZE = 120.0;
  static const double FIXED_NODE_SIZE = 35.0;
  static const double FIXED_SPACING = 140.0;

  @override
  void initState() {
    super.initState();
    _loadCampusLoungeData();
    _loadWatchlistData();

    // Listen to transformation changes to track scale
    _transformationController.addListener(_onTransformChanged);

    // Listen to scroll for pagination
    _scrollController.addListener(_onScroll);
  }

  void _onTransformChanged() {
    setState(() {
      currentScale = _transformationController.value.getMaxScaleOnAxis();
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore) {
      if (selectedTab == 1) {
        _loadMoreWatchlistData();
      } else if (selectedTab == 0) {
        _loadMoreCampusLoungeData();
      }
    }
  }

  Future<void> _loadCampusLoungeData() async {
    setState(() {
      isLoadingCampusLounge = true;
      _campusLoungeCursor = null;
      _campusLoungeHasMore = true;
    });

    try {
      PaginatedGroupResult result = await GroupsService.getCampusLoungeGroups();
      setState(() {
        campusLoungeGroups = result.groups;
        _campusLoungeCursor = result.nextCursor;
        _campusLoungeHasMore = result.hasMore;
      });
    } catch (e) {
      print('Error loading campus lounge data: $e');
    } finally {
      setState(() {
        isLoadingCampusLounge = false;
      });
    }
  }

  Future<void> _loadWatchlistData() async {
    setState(() {
      isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      Map<String, dynamic> data =
          await WatchlistServices.getWatchList(await UserService.getUserId());
      if (data['success'] == true) {
        print(data);
        setState(() {
          friendGroups = data['data'];
        });
      } else {
        print(data);
        setState(() {
          friendGroups = [];
        });
      }
    } catch (e) {
      print('Error loading watchlist: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadMoreWatchlistData() async {
    if (isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      Map<String, dynamic> data =
          await WatchlistServices.getWatchList(await UserService.getUserId());

      if (data['success'] == true && data['data'].isNotEmpty) {
        setState(() {
          List<dynamic> newGroups = data['data'];
          for (var group in newGroups) {
            if (!friendGroups.any((g) => g.groupId == group.groupId)) {
              friendGroups.add(group);
            }
          }
        });
      }
    } catch (e) {
      print('Error loading more watchlist: $e');
    } finally {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreCampusLoungeData() async {
    if (isLoadingMore || !_campusLoungeHasMore) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      PaginatedGroupResult result = await GroupsService.getCampusLoungeGroups(
        cursor: _campusLoungeCursor,
      );
      setState(() {
        campusLoungeGroups.addAll(result.groups);
        _campusLoungeCursor = result.nextCursor;
        _campusLoungeHasMore = result.hasMore;
      });
    } catch (e) {
      print('Error loading more campus lounge data: $e');
    } finally {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      bottomNavigationBar: AppBottomNav(highlightIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section with Lounge & Annoymouse Buttons inside the Peanut-shaped Container
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: CustomPaint(
                painter: PeanutShapePainter(),
                child: Padding(
                  padding: const EdgeInsets.all(6.0), // Outer container padding
                  child: Row(
                    children: [
                      Expanded(
                        child: GenzButton(
                          title: 'Campus Lounge',
                          subtitle: 'Public Chat',
                          glowColor: const Color(0xFF00FF9D), // neon green
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF00FF9D),
                            size: 20,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                isIos: true,
                                type: PageTransitionType.rightToLeft,
                                child: const CampusChatScreen(),
                                curve: Curves.fastEaseInToSlowEaseOut,
                                duration: const Duration(milliseconds: 500),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(
                          width: 14), // Spacing aligned with the middle shrink
                      Expanded(
                        child: GenzButton(
                          title: 'Anonymous Chat',
                          subtitle: 'Private Chat',
                          glowColor: const Color(0xFFC084FC), // neon purple
                          icon: CustomPaint(
                            size: const Size(20, 20),
                            painter: FedoraGlassesPainter(
                              color: const Color(0xFFC084FC),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                isIos: true,
                                type: PageTransitionType.rightToLeft,
                                child: const InstantMatchScreen(),
                                curve: Curves.fastEaseInToSlowEaseOut,
                                duration: const Duration(milliseconds: 500),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tab Bar Row with Dark Background
            Container(
              width: double.infinity,
              color: const Color(0xFF0A0A1F), // Dark tab bar container
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabHeader(1, 'Watchlist'),
                  _buildTabHeader(0, 'Campus'),
                  _buildTabHeader(2, 'For you'),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: selectedTab == 0
                  ? _buildCampusLoungeTab()
                  : selectedTab == 1
                      ? _buildWatchlistTab()
                      : _buildForYouTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabHeader(int index, String label) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
        setState(() => selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildCampusLoungeTab() {
    if (isLoadingCampusLounge) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF9D)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading campus lounge...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (campusLoungeGroups.isEmpty) {
      return const Center(
        child: Text(
          'No campus groups available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Calculate positions with fixed small size
    List<Offset> positions =
        _calculateCampusLoungePositions(campusLoungeGroups.length);

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Content dimensions expand with zoom
    double contentWidth = screenWidth * max(1.0, currentScale * 1.5);
    double contentHeight = max(
      screenHeight - 100,
      _calculateContentHeight(positions),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: contentHeight,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.all(currentScale > 1.5 ? 150 : 30),
          minScale: 0.8,
          maxScale: 4.0,
          constrained: false,
          child: Container(
            width: contentWidth,
            height: contentHeight,
            child: Stack(
              children: [
                ...campusLoungeGroups.asMap().entries.map((entry) {
                  int index = entry.key;
                  FriendCircleGroup group = entry.value;
                  Offset position = positions[index];

                  return Positioned(
                    left: position.dx - FIXED_CIRCLE_SIZE / 2,
                    top: position.dy - FIXED_CIRCLE_SIZE / 2,
                    child: FriendCircle(
                      group: group,
                      size: FIXED_CIRCLE_SIZE,
                      nodeSize: FIXED_NODE_SIZE,
                      onGroupTap: () {
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
                      onMemberTap: (memberIndex) {
                        print(
                            'Member ${group.members[memberIndex].id} in group ${group.groupId} tapped');
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
                      edgeStyle: EdgeStyle(
                        width: 3,
                        outerGlow: 3,
                        gradientColors: [
                          Colors.blue,
                          Colors.pink,
                          Colors.orange
                        ],
                      ),
                    ),
                  );
                }).toList(),

                // Loading indicator at bottom
                if (isLoadingMore)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00FF9D)),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Loading more...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Offset> _calculateCampusLoungePositions(int length) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Always use fixed small spacing
    double spacing = FIXED_SPACING;

    // Calculate how many columns fit on screen with small circles
    int itemsPerRow = max(2, (screenWidth / spacing).floor());

    List<Offset> positions = [];
    Random random = Random(42);

    for (int i = 0; i < length; i++) {
      int row = i ~/ itemsPerRow;
      int col = i % itemsPerRow;

      // Calculate base position in tight grid
      double baseX = (col + 0.5) * spacing + 20;
      double baseY = (row + 0.5) * spacing + 100;

      // Add slight randomness for organic look
      double offsetX = (random.nextDouble() - 0.5) * 30;
      double offsetY = (random.nextDouble() - 0.5) * 30;

      Offset position = Offset(
        baseX + offsetX,
        baseY + offsetY,
      );

      positions.add(position);
    }

    return positions;
  }

  Widget _buildWatchlistTab() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: 16),
            Text(
              'Loading your watchlist...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (friendGroups.isEmpty) {
      return const Center(
        child: Text(
          'No groups in watchlist',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    // Calculate positions with fixed small size
    List<Offset> positions = _calculateCompactPositions();

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Content dimensions expand with zoom
    double contentWidth = screenWidth * max(1.0, currentScale * 1.5);
    double contentHeight = max(
      screenHeight - 100,
      _calculateContentHeight(positions),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        height: contentHeight,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.all(currentScale > 1.5 ? 150 : 30),
          minScale: 0.8,
          maxScale: 4.0,
          constrained: false,
          child: Container(
            width: contentWidth,
            height: contentHeight,
            child: Stack(
              children: [
                ...friendGroups.asMap().entries.map((entry) {
                  int index = entry.key;
                  FriendCircleGroup group = entry.value;
                  Offset position = positions[index];

                  return Positioned(
                    left: position.dx - FIXED_CIRCLE_SIZE / 2,
                    top: position.dy - FIXED_CIRCLE_SIZE / 2,
                    child: FriendCircle(
                      group: group,
                      size: FIXED_CIRCLE_SIZE,
                      nodeSize: FIXED_NODE_SIZE,
                      onGroupTap: () {
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
                        print(
                            'Member ${group.members[index].id} in group ${group.groupId} tapped');
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
                      edgeStyle: EdgeStyle(
                        width: 3,
                        outerGlow: 3,
                        gradientColors: [
                          Colors.blue,
                          Colors.pink,
                          Colors.orange
                        ],
                      ),
                    ),
                  );
                }).toList(),

                // Loading indicator at bottom
                if (isLoadingMore)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Loading more...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Offset> _calculateCompactPositions() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Always use fixed small spacing
    double spacing = FIXED_SPACING;

    // Calculate how many columns fit on screen with small circles
    int itemsPerRow = max(2, (screenWidth / spacing).floor());

    List<Offset> positions = [];
    Random random = Random(42);

    for (int i = 0; i < friendGroups.length; i++) {
      int row = i ~/ itemsPerRow;
      int col = i % itemsPerRow;

      // Calculate base position in tight grid
      double baseX = (col + 0.5) * spacing + 20;
      double baseY = (row + 0.5) * spacing + 100;

      // Add slight randomness for organic look
      double offsetX = (random.nextDouble() - 0.5) * 30;
      double offsetY = (random.nextDouble() - 0.5) * 30;

      Offset position = Offset(
        baseX + offsetX,
        baseY + offsetY,
      );

      positions.add(position);
    }

    return positions;
  }

  double _calculateContentHeight(List<Offset> positions) {
    if (positions.isEmpty) return MediaQuery.of(context).size.height;

    double maxY = positions.map((p) => p.dy).reduce(max);
    return maxY + 250;
  }

  Widget _buildForYouTab() {
    return Recomandedgroups(
      height: MediaQuery.of(context).size.height * 0.64,
    );
  }
}

class GenzButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final Color glowColor;
  final VoidCallback onTap;

  const GenzButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F26)
              .withOpacity(0.8), // dark transparent background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: glowColor.withOpacity(0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon section with colored glass circle background
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: glowColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            const SizedBox(width: 8),
            // Text section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: glowColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FedoraGlassesPainter extends CustomPainter {
  final Color color;
  FedoraGlassesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Brim of the hat
    final brimPath = Path();
    brimPath.moveTo(size.width * 0.15, size.height * 0.45);
    brimPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.55,
      size.width * 0.85,
      size.height * 0.45,
    );
    canvas.drawPath(brimPath, paint);

    // Crown of the hat
    final crownPath = Path();
    crownPath.moveTo(size.width * 0.3, size.height * 0.45);
    // Left side of crown
    crownPath.lineTo(size.width * 0.28, size.height * 0.25);
    // Top dent of the hat
    crownPath.cubicTo(
      size.width * 0.35,
      size.height * 0.2,
      size.width * 0.45,
      size.height * 0.25,
      size.width * 0.5,
      size.height * 0.25,
    );
    crownPath.cubicTo(
      size.width * 0.55,
      size.height * 0.25,
      size.width * 0.65,
      size.height * 0.2,
      size.width * 0.72,
      size.height * 0.25,
    );
    // Right side of crown
    crownPath.lineTo(size.width * 0.7, size.height * 0.45);
    canvas.drawPath(crownPath, paint);

    // Hat ribbon / band
    final bandPath = Path();
    bandPath.moveTo(size.width * 0.295, size.height * 0.41);
    bandPath.lineTo(size.width * 0.705, size.height * 0.41);
    bandPath.lineTo(size.width * 0.7, size.height * 0.45);
    bandPath.lineTo(size.width * 0.3, size.height * 0.45);
    bandPath.close();
    canvas.drawPath(bandPath, fillPaint);

    // Glasses
    // Left lens
    canvas.drawCircle(
      Offset(size.width * 0.38, size.height * 0.68),
      size.width * 0.1,
      paint,
    );
    // Right lens
    canvas.drawCircle(
      Offset(size.width * 0.62, size.height * 0.68),
      size.width * 0.1,
      paint,
    );
    // Bridge
    canvas.drawLine(
      Offset(size.width * 0.48, size.height * 0.68),
      Offset(size.width * 0.52, size.height * 0.68),
      paint,
    );
    // Side temples (arms) of glasses
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.68),
      Offset(size.width * 0.18, size.height * 0.62),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.68),
      Offset(size.width * 0.82, size.height * 0.62),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PeanutShapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A0A1F) // Match screenshot's background color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double r = 24.0; // corner radius
    final double shrinkX = w / 2;
    final double shrinkDepth = 10.0; // depth of the middle shrink
    final double shrinkWidth = 45.0; // horizontal span of the shrink

    // Top-left starting point
    path.moveTo(r, 0);

    // Curve inward in the middle of the top edge
    path.lineTo(shrinkX - shrinkWidth, 0);
    path.cubicTo(
      shrinkX - shrinkWidth * 0.5,
      0,
      shrinkX - shrinkWidth * 0.3,
      shrinkDepth,
      shrinkX,
      shrinkDepth,
    );
    path.cubicTo(
      shrinkX + shrinkWidth * 0.3,
      shrinkDepth,
      shrinkX + shrinkWidth * 0.5,
      0,
      shrinkX + shrinkWidth,
      0,
    );

    // Top-right corner
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);

    // Right side
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);

    // Bottom edge with inward curve in the middle
    path.lineTo(shrinkX + shrinkWidth, h);
    path.cubicTo(
      shrinkX + shrinkWidth * 0.5,
      h,
      shrinkX + shrinkWidth * 0.3,
      h - shrinkDepth,
      shrinkX,
      h - shrinkDepth,
    );
    path.cubicTo(
      shrinkX - shrinkWidth * 0.3,
      h - shrinkDepth,
      shrinkX - shrinkWidth * 0.5,
      h,
      shrinkX - shrinkWidth,
      h,
    );

    // Bottom-left corner
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);

    // Left side
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);

    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(PeanutShapePainter oldDelegate) => false;
}
