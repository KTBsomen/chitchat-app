import 'dart:math';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/watchlist.dart';

/// A standalone Watchlist view widget that can be used directly in tabs
/// or inside a bottom sheet with seamless scrolling and pagination.
class WatchlistView extends StatefulWidget {
  final ScrollController? scrollController;

  const WatchlistView({super.key, this.scrollController});

  @override
  State<WatchlistView> createState() => _WatchlistViewState();
}

class _WatchlistViewState extends State<WatchlistView> {
  late final ScrollController _scrollController;
  final TransformationController _transformationController =
      TransformationController();

  List<dynamic> friendGroups = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  double currentScale = 1.0;

  static const double FIXED_CIRCLE_SIZE = 120.0;
  static const double FIXED_NODE_SIZE = 35.0;
  static const double FIXED_SPACING = 140.0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    _transformationController.addListener(_onTransformChanged);
    _loadWatchlistData();
  }

  void _onTransformChanged() {
    if (mounted) {
      setState(() {
        currentScale = _transformationController.value.getMaxScaleOnAxis();
      });
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore) {
      _loadMoreWatchlistData();
    }
  }

  Future<void> _loadWatchlistData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final userId = await UserService.getUserId();
      if (userId == null) {
        setState(() => isLoading = false);
        return;
      }

      final data = await WatchlistServices.getWatchList(userId);
      if (mounted) {
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            friendGroups = data['data'];
          });
        } else {
          setState(() {
            friendGroups = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading watchlist: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMoreWatchlistData() async {
    if (isLoadingMore) return;
    setState(() => isLoadingMore = true);

    try {
      final userId = await UserService.getUserId();
      if (userId == null) {
        setState(() => isLoadingMore = false);
        return;
      }

      final data = await WatchlistServices.getWatchList(userId);
      if (mounted && data['success'] == true && data['data'] != null) {
        final List<dynamic> newGroups = data['data'];
        setState(() {
          for (var group in newGroups) {
            if (!friendGroups.any((g) => g.groupId == group.groupId)) {
              friendGroups.add(group);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading more watchlist: $e');
    } finally {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  List<Offset> _calculateCompactPositions() {
    final screenWidth = MediaQuery.of(context).size.width;
    double spacing = FIXED_SPACING;
    int itemsPerRow = max(2, (screenWidth / spacing).floor());

    List<Offset> positions = [];
    Random random = Random(42);

    for (int i = 0; i < friendGroups.length; i++) {
      int row = i ~/ itemsPerRow;
      int col = i % itemsPerRow;

      double baseX = (col + 0.5) * spacing + 20;
      double baseY = (row + 0.5) * spacing + 60;

      double offsetX = (random.nextDouble() - 0.5) * 30;
      double offsetY = (random.nextDouble() - 0.5) * 30;

      positions.add(Offset(baseX + offsetX, baseY + offsetY));
    }

    return positions;
  }

  double _calculateContentHeight(List<Offset> positions) {
    if (positions.isEmpty) return MediaQuery.of(context).size.height;
    double maxY = positions.map((p) => p.dy).reduce(max);
    return maxY + 250;
  }

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(color: Colors.white54, fontFamily: 'Poppins'),
            ),
          ],
        ),
      );
    }

    if (friendGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 60, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 14),
            const Text(
              'No groups in watchlist yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add friends or groups to your watchlist to track them here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final positions = _calculateCompactPositions();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    double contentWidth = screenWidth * max(1.0, currentScale * 1.5);
    double contentHeight = max(
      screenHeight - 100,
      _calculateContentHeight(positions),
    );

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: contentHeight,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.all(currentScale > 1.5 ? 150 : 30),
          minScale: 0.8,
          maxScale: 4.0,
          constrained: false,
          child: SizedBox(
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
                        if (group.groupData["name"] == 'Fake Group') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No groups found showing personal profile.')),
                          );
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: PublicProfilePage(
                                uid: group.groupId,
                                dbIndex: group.groupData["dbIndex"].toString(),
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: GroupPublicViewScreen(
                                groupId: group.groupId,
                              ),
                            ),
                          );
                        }
                      },
                      onMemberTap: (memberIndex) {
                        if (group.groupData["name"] == 'Fake Group') {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: PublicProfilePage(
                                uid: group.groupId,
                                dbIndex: group.groupData["dbIndex"].toString(),
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: GroupPublicViewScreen(
                                groupId: group.groupId,
                              ),
                            ),
                          );
                        }
                      },
                      edgeStyle: EdgeStyle(
                        width: 3,
                        outerGlow: 3,
                        gradientColors: const [
                          Colors.blue,
                          Colors.pink,
                          Colors.orange
                        ],
                      ),
                    ),
                  );
                }).toList(),
                if (isLoadingMore)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Loading more...',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13),
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
}
