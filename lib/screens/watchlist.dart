import 'dart:ui';

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

import 'package:page_transition/page_transition.dart';

class WatchlistPage extends StatefulWidget {
  @override
  _WatchlistPageState createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  int selectedTab = 0;
  bool isLoading = false;
  bool isLoadingMore = false;
  List<dynamic> friendGroups = [];
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
      _loadMoreWatchlistData();
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
      body: SafeArea(
        child: Column(
          children: [
            // Custom Tab Header
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => selectedTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'my watchlist',
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
                  const SizedBox(width: 40),
                  GestureDetector(
                    onTap: () => setState(() => selectedTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        'for you',
                        style: TextStyle(
                          color: selectedTab == 1 ? Colors.white : Colors.grey,
                          fontSize: 16,
                          fontWeight: selectedTab == 1
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
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
                            child: PublicProfilePage(
                                dbIndex: group
                                    .members[index].additionalData['dbIndex'],
                                uid: group.members[index].id),
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
      height: MediaQuery.of(context).size.height * 0.825,
    );
  }
}
