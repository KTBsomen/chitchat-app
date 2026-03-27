import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// Data class for member information
class FriendCircleMember {
  final String avatarUrl;
  final String id;
  final Map<String, dynamic> additionalData;
  String? status; // e.g., 'online', 'offline','away'.
  String? lastSeen; // Optional lastSeen field

  FriendCircleMember(
      {required this.avatarUrl,
      required this.id,
      this.additionalData = const {},
      this.status,
      this.lastSeen});
}

// Data class for group information
class FriendCircleGroup {
  final List<FriendCircleMember> members;
  final String groupId;
  final Map<String, dynamic> groupData;

  const FriendCircleGroup({
    required this.members,
    required this.groupId,
    this.groupData = const {},
  });

  FriendCircleGroup copyWith({
    List<FriendCircleMember>? members,
    String? groupId,
    Map<String, dynamic>? groupData,
  }) {
    return FriendCircleGroup(
      members: members ?? this.members,
      groupId: groupId ?? this.groupId,
      groupData: groupData ?? this.groupData,
    );
  }

  FriendCircleGroup copy() {
    return FriendCircleGroup(
      members: members,
      groupId: groupId,
      groupData: groupData,
    );
  }
}

// Layout widget for multiple friend circles
class FriendCircleLayout extends StatelessWidget {
  final List<FriendCircleGroup> groups;
  final double spacing;
  final int crossAxisCount;
  final Function(String groupId, Map<String, dynamic> groupData)? onGroupTap;
  final Function(
          String groupId, String memberId, Map<String, dynamic> memberData)?
      onMemberTap;
  final ScrollController? scrollController;
  final EdgeStyle defaultEdgeStyle;

  const FriendCircleLayout({
    Key? key,
    required this.groups,
    this.spacing = 16.0,
    this.crossAxisCount = 3,
    this.onGroupTap,
    this.onMemberTap,
    this.scrollController,
    this.defaultEdgeStyle = const EdgeStyle(),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      controller: scrollController,
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildFriendCircleItem(context, group);
      },
    );
  }

  Widget _buildFriendCircleItem(BuildContext context, FriendCircleGroup group) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return SizedBox(
          width: size,
          height: size,
          child: FriendCircle(
            group: group,
            size: size,
            edgeStyle: defaultEdgeStyle,
            onGroupTap: onGroupTap != null
                ? () => onGroupTap!(group.groupId, group.groupData)
                : null,
            onMemberTap: onMemberTap != null
                ? (index) => onMemberTap!(
                      group.groupId,
                      group.members[index].id,
                      group.members[index].additionalData,
                    )
                : null,
          ),
        );
      },
    );
  }
}

// Enhanced FriendCircle widget
class FriendCircle extends StatelessWidget {
  final FriendCircleGroup group;
  final double size;
  final double? nodeSize;
  final EdgeStyle edgeStyle;
  final Color nodeBorderColor;
  final double maxVisibleMembers;
  final Function()? onGroupTap;
  final Function(int index)? onMemberTap;

  const FriendCircle({
    Key? key,
    required this.group,
    required this.size,
    this.nodeSize,
    this.edgeStyle = const EdgeStyle(),
    this.nodeBorderColor = Colors.white,
    this.maxVisibleMembers = 6.0,
    this.onGroupTap,
    this.onMemberTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine how many members to build - up to the ceil of maxVisibleMembers
    final int buildCount = min(group.members.length, maxVisibleMembers.ceil());
    final double effectiveMaxVisible =
        min(group.members.length.toDouble(), maxVisibleMembers);

    // Dynamic node size calculation
    double effectiveNodeSize = nodeSize ?? (size * 0.27);
    if (buildCount > 0 && buildCount <= 3) {
      effectiveNodeSize = size * 0.40;
    } else if (buildCount > 3 && buildCount <= 5) {
      effectiveNodeSize = size * 0.32;
    }

    // painter should use a fixed integer for the ring smoothness
    final painterCount = buildCount >= 2 ? 10 : 0;

    // ✅ Create a single shuffled index list once
    final shuffledIndices = List.generate(buildCount, (idx) => idx)..shuffle();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onGroupTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Stack(
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: OuterEdgePainter(
                  memberCount: painterCount,
                  edgeStyle: edgeStyle,
                ),
              ),
              // ✅ Use indices up to buildCount
              ...List.generate(
                buildCount,
                (i) {
                  return _buildNode(i, effectiveMaxVisible,
                      effectiveNodeSize); // Pass effective version for angle
                },
              ),
              if (group.members.length > maxVisibleMembers)
                _buildExtraCountNode(effectiveNodeSize, effectiveMaxVisible),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNode(
      int index, double effectiveMaxVisible, double effectiveNodeSize) {
    // Current display total is used for angle calculation to allow sliding
    final angle = (2 * pi * index) / effectiveMaxVisible;
    final centerOffset = size / 2;
    final radius = (size - effectiveNodeSize) / 2;

    // Calculate individual node opacity for smooth fading
    final double nodeOpacity = (maxVisibleMembers - index).clamp(0.0, 1.0);

    return Positioned(
      left: centerOffset + radius * cos(angle - pi / 2) - effectiveNodeSize / 2,
      top: centerOffset + radius * sin(angle - pi / 2) - effectiveNodeSize / 2,
      child: Opacity(
        opacity: nodeOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onMemberTap?.call(index),
            borderRadius: BorderRadius.circular(effectiveNodeSize / 2),
            child: Container(
              width: effectiveNodeSize,
              height: effectiveNodeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: nodeBorderColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.network(
                  group.members[index].avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: Icon(
                        Icons.person,
                        size: effectiveNodeSize * 0.6,
                        color: Colors.grey[600],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraCountNode(
      double effectiveNodeSize, double effectiveMaxVisible) {
    final extraCount = group.members.length - maxVisibleMembers.floor();
    final angle = (2 * pi * maxVisibleMembers) / effectiveMaxVisible;
    final centerOffset = size / 2;
    final radius = (size - effectiveNodeSize) / 2;

    return Positioned(
      left: centerOffset + radius * cos(angle - pi / 2) - effectiveNodeSize / 2,
      top: centerOffset + radius * sin(angle - pi / 2) - effectiveNodeSize / 2,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onMemberTap?.call(maxVisibleMembers.floor()),
          borderRadius: BorderRadius.circular(effectiveNodeSize / 2),
          child: Container(
            width: effectiveNodeSize,
            height: effectiveNodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[300],
              border: Border.all(
                color: nodeBorderColor,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '+$extraCount',
                style: TextStyle(
                  fontSize: effectiveNodeSize * 0.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EdgeStyle {
  final Color color;
  final double width;
  final List<Color>? gradientColors;
  final double? innerGlow;
  final Color? innerGlowColor;
  final double? outerGlow;
  final Color? outerGlowColor;
  final double cornerRadius;

  const EdgeStyle({
    this.color = const Color(0xFF666666),
    this.width = 1.5,
    this.gradientColors,
    this.innerGlow,
    this.innerGlowColor,
    this.outerGlow,
    this.outerGlowColor,
    this.cornerRadius = 8.0,
  });
}

class OuterEdgePainter extends CustomPainter {
  final int memberCount;
  final EdgeStyle edgeStyle;

  OuterEdgePainter({
    required this.memberCount,
    required this.edgeStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (memberCount < 2) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 40) / 2;

    final points = List.generate(memberCount, (index) {
      final angle = (2 * pi * index) / memberCount - (pi / 2);
      return Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    });

    final path = Path();

    // Create curved path
    if (points.length > 2) {
      path.moveTo(points[0].dx, points[0].dy);

      for (var i = 0; i < points.length; i++) {
        final current = points[i];
        final next = points[(i + 1) % points.length];
        final controlPoint1 = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );

        path.quadraticBezierTo(
          current.dx,
          current.dy,
          controlPoint1.dx,
          controlPoint1.dy,
        );
      }
    } else {
      // For 2 points, just draw a line
      path.moveTo(points[0].dx, points[0].dy);
      path.lineTo(points[1].dx, points[1].dy);
    }

    path.close();

    if (edgeStyle.outerGlow != null) {
      final outerGlowPaint = Paint()
        ..color = edgeStyle.outerGlowColor ?? edgeStyle.color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeStyle.width + (edgeStyle.outerGlow! * 2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, edgeStyle.outerGlow!);
      canvas.drawPath(path, outerGlowPaint);
    }

    if (edgeStyle.innerGlow != null) {
      final innerGlowPaint = Paint()
        ..color = edgeStyle.innerGlowColor ?? edgeStyle.color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeStyle.width
        ..maskFilter = MaskFilter.blur(BlurStyle.inner, edgeStyle.innerGlow!);
      canvas.drawPath(path, innerGlowPaint);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = edgeStyle.width;

    if (edgeStyle.gradientColors != null) {
      paint.shader = SweepGradient(
        colors: edgeStyle.gradientColors!,
        transform: GradientRotation(-pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      paint.color = edgeStyle.color;
    }

    canvas.drawPath(path, paint);
  }

  Offset _getControlPoint(Offset start, Offset end, double radius, double t) {
    return Offset(
      start.dx + (end.dx - start.dx) * t,
      start.dy + (end.dy - start.dy) * t,
    );
  }

  @override
  bool shouldRepaint(OuterEdgePainter oldDelegate) {
    return oldDelegate.memberCount != memberCount;
  }
}

// Example usage:
