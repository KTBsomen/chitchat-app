import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:page_transition/page_transition.dart';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/watchlist_view.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/beacon_extractor.dart';
import 'package:chitchat/services/nearby_service.dart';

/// The main Nearby Radar Screen displaying the Solar System Orbit Web UI.
class NearbyRadarView extends StatefulWidget {
  final VoidCallback? onOpenWatchlist;

  const NearbyRadarView({super.key, this.onOpenWatchlist});

  @override
  State<NearbyRadarView> createState() => _NearbyRadarViewState();
}

class _NearbyRadarViewState extends State<NearbyRadarView>
    with SingleTickerProviderStateMixin {
  final NearbyService _nearbyService = NearbyService.instance;

  bool _isCheckingPermissions = true;
  bool _hasPermissions = false;
  bool _isRequesting = false;

  late AnimationController _radarAnimController;

  @override
  void initState() {
    super.initState();
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isCheckingPermissions = true);
    final hasEnabled = await _nearbyService.hasUserEnabledNearby();
    final areGranted = await _nearbyService.arePermissionsGranted();

    if (mounted) {
      setState(() {
        _hasPermissions = hasEnabled && areGranted;
        _isCheckingPermissions = false;
      });

      if (_hasPermissions) {
        _startNearbyOperations();
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    final granted = await _nearbyService.requestPermissions();
    if (mounted) {
      setState(() {
        _hasPermissions = granted;
        _isRequesting = false;
      });

      if (granted) {
        _startNearbyOperations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bluetooth and Location permissions are required for Nearby discovery.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startNearbyOperations() {
    _nearbyService.startBroadcasting();
    _nearbyService.startScanning();
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    super.dispose();
  }

  void _openWatchlistBottomSheet() {
    debugPrint("NearbyRadarView: opening watchlist bottom sheet");
    if (widget.onOpenWatchlist != null) {
      widget.onOpenWatchlist!();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          height: MediaQuery.of(bottomSheetContext).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.favorite_rounded,
                            color: Colors.orange, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Watchlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Watchlist Content
              const Expanded(
                child: WatchlistView(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens a BottomSheet with a simple ListView containing all nearby users.
  /// Displayed when there are more than 15 profiles in range.
  void _openAllNearbyUsersBottomSheet(List<NearbyUserFound> allUsers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(sheetContext).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF9D).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.radar_rounded,
                            color: Color(0xFF00FF9D),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "All Nearby Users",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            Text(
                              "${allUsers.length} active peers discovered",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              // Simple ListView with ListTiles
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: allUsers.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 1, indent: 76, endIndent: 20),
                  itemBuilder: (context, index) {
                    final user = allUsers[index];
                    final details = user.details;
                    final name = (details?['name'] ?? details?['username'] ?? 'User ${index + 1}').toString();
                    final username = details?['username']?.toString();
                    final profilePic = details?['profilePic']?.toString();
                    final institution = details?['university'] ?? details?['college'] ?? details?['school'];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: user.isLoading
                          ? Shimmer.fromColors(
                              baseColor: const Color(0xFF1E1E38),
                              highlightColor: const Color(0xFF383860),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00FF9D).withOpacity(0.7),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: profilePic != null && profilePic.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: profilePic,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: const Color(0xFF16162A),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white70,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFF16162A),
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white70,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            "${user.distanceMeters.toStringAsFixed(1)}m away",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          if (institution != null && institution.toString().isNotEmpty) ...[
                            Text(
                              " • ",
                              style: TextStyle(color: Colors.white.withOpacity(0.3)),
                            ),
                            Expanded(
                              child: Text(
                                institution.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ] else if (username != null && username.isNotEmpty) ...[
                            Text(
                              " • ",
                              style: TextStyle(color: Colors.white.withOpacity(0.3)),
                            ),
                            Expanded(
                              child: Text(
                                "@$username",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF9D).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00FF9D).withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              size: 11,
                              color: Color(0xFF00FF9D),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "~${user.distanceMeters.toStringAsFixed(1)}m",
                              style: const TextStyle(
                                color: Color(0xFF00FF9D),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openUserProfileDialog(user);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Toggles 20 mock nearby profiles in debug mode to test the 15+ threshold and bottomsheet
  void _toggleDebugMockUsers() {
    final current = Map<String, NearbyUserFound>.from(_nearbyService.usersFoundNotifier.value);
    final hasMock = current.keys.any((k) => k.startsWith('mock_'));
    if (hasMock) {
      current.removeWhere((k, v) => k.startsWith('mock_'));
      _nearbyService.usersFoundNotifier.value = current;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Cleared mock test profiles"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Add 20 mock users to easily test 15+ threshold
      for (int i = 1; i <= 20; i++) {
        final mockId = 'mock_user_$i';
        final dist = 1.2 + (i * 0.8);
        current[mockId] = NearbyUserFound(
          id: '60c72b2f9b1d8b2bad1234${i.toString().padLeft(2, '0')}',
          distanceMeters: dist,
          distanceFormatted: "${dist.toStringAsFixed(1)}m",
          rssi: -50 - (i * 2),
          isLoading: false,
          details: {
            'name': 'Student $i',
            'username': 'student_$i',
            'bio': 'Computer Science • ChitChat peer #$i',
            'university': i % 2 == 0 ? 'Engineering Campus' : 'Tech University',
            'profilePic': null,
          },
        );
      }
      _nearbyService.usersFoundNotifier.value = current;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Added 20 mock nearby profiles! Long-press 'You' to reset."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF9D)),
        ),
      );
    }

    if (!_hasPermissions) {
      return _buildPermissionExplanationView();
    }

    return _buildRadarSolarSystemView();
  }

  // ─────────────────────────────────────────────
  //  1. PERMISSION EXPLANATION / ONBOARDING VIEW
  // ─────────────────────────────────────────────
  Widget _buildPermissionExplanationView() {
    return Stack(
      children: [
        // 1. Scrollable Permission Explanation Content (rendered first so toolbar is on top)
        Positioned.fill(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28.0, 56.0, 28.0, 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glowing Radar Aura Icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _radarAnimController,
                        builder: (context, child) {
                          final scale = 1.0 + (_radarAnimController.value * 0.25);
                          final opacity = (1.0 - _radarAnimController.value).clamp(0.0, 0.7);
                          return Container(
                            width: 140 * scale,
                            height: 140 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00FF9D).withOpacity(opacity * 0.25),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00FF9D), Color(0xFF00B4D8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF9D).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          size: 46,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Title
                  const Text(
                    "Discover Nearby Friends",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  // Subtitle / Description
                  Text(
                    "Find people and classmates right around you using secure Bluetooth beacons. "
                    "Your phone broadcasts an anonymous beacon in the background so students on your campus can spot and connect with you.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'Poppins',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Feature Highlights
                  _buildFeaturePill(
                    icon: Icons.bluetooth_searching_rounded,
                    title: "Instant BLE Discovery",
                    subtitle: "Detects active peers in your immediate area",
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturePill(
                    icon: Icons.battery_charging_full_rounded,
                    title: "Ultra Low Energy",
                    subtitle: "Minimal battery consumption with native beaconing",
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturePill(
                    icon: Icons.lock_outline_rounded,
                    title: "Safe & Privacy-First",
                    subtitle: "Only your public profile is visible to nearby peers",
                  ),

                  const SizedBox(height: 36),

                  // Grant Permission Big Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isRequesting ? null : _requestPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF9D),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isRequesting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded, color: Colors.black, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  "Enable Nearby Discovery",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You can pause or disable this feature at any time.",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Top Toolbar with Watchlist Heart Icon Button (rendered on top so taps are captured)
        Positioned(
          top: 8,
          right: 16,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                debugPrint("Watchlist button tapped from permission view!");
                _openWatchlistBottomSheet();
              },
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A26).withOpacity(0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePill({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF9D).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF00FF9D), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  2. RADAR & SOLAR SYSTEM ORBIT VIEW
  // ─────────────────────────────────────────────
  Widget _buildRadarSolarSystemView() {
    final myProfile = AppVariables.get<Map<String, dynamic>>('profile');
    final myProfilePic = myProfile?['profilePic'];

    return Stack(
      children: [
        // Solar System Orbit Canvas & Planet Nodes (rendered first)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(
                constraints.maxWidth / 2,
                constraints.maxHeight / 2,
              );
              // Radius definitions for 4 concentric oval rings (horizontal & vertical radii)
              final baseRadiusX = constraints.maxWidth * 0.44;
              final baseRadiusY = constraints.maxHeight * 0.38;

              final orbitRatios = [0.32, 0.54, 0.76, 0.98];

              return ValueListenableBuilder<Map<String, NearbyUserFound>>(
                valueListenable: _nearbyService.usersFoundNotifier,
                builder: (context, usersMap, _) {
                  final usersList = usersMap.values.toList();
                  // Sort by estimated distance
                  usersList.sort(
                      (a, b) => a.distanceMeters.compareTo(b.distanceMeters));

                  // When more than 15 profiles are detected, display at most 15 on radar
                  const int maxRadarPlanets = 15;
                  final displayedUsers = usersList.length > maxRadarPlanets
                      ? usersList.take(maxRadarPlanets).toList()
                      : usersList;
                  final extraUsersCount = usersList.length > maxRadarPlanets
                      ? usersList.length - maxRadarPlanets
                      : 0;

                  // Assign users to orbits
                  final orbitUsers = _groupUsersIntoOrbits(displayedUsers);

                  return Stack(
                    children: [
                      // Animated Orbit Web Canvas
                      AnimatedBuilder(
                        animation: _radarAnimController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight),
                            painter: OrbitWebPainter(
                              radarProgress: _radarAnimController.value,
                              orbitRatios: orbitRatios,
                              baseRadiusX: baseRadiusX,
                              baseRadiusY: baseRadiusY,
                            ),
                          );
                        },
                      ),

                      // Center: "The Sun" (Current User Profile)
                      Positioned(
                        left: center.dx - 36,
                        top: center.dy - 36,
                        child: _buildCenterSunAvatar(myProfilePic),
                      ),

                      // Planet Nodes (Discovered Devices)
                      ...orbitUsers.entries.expand((entry) {
                        int orbitIndex = entry.key;
                        List<NearbyUserFound> usersInOrbit = entry.value;
                        final rx = baseRadiusX * orbitRatios[orbitIndex];
                        final ry = baseRadiusY * orbitRatios[orbitIndex];

                        return usersInOrbit.asMap().entries.map((userEntry) {
                          int index = userEntry.key;
                          NearbyUserFound user = userEntry.value;

                          // Distribute planets evenly around the oval orbit
                          final count = usersInOrbit.length;
                          // Stagger start angles across orbits so they don't line up strictly
                          final baseAngle = orbitIndex * 0.7;
                          final angle =
                              baseAngle + (index * (2 * pi / max(1, count)));

                          final px = center.dx + rx * cos(angle);
                          final py = center.dy + ry * sin(angle);

                          return Positioned(
                            left: px - 35,
                            top: py - 42,
                            child: _buildPlanetNode(user),
                          );
                        });
                      }),

                      // "View N+ more" bottom button when more than 15 users found
                      if (extraUsersCount > 0)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                              child: InkWell(
                                onTap: () =>
                                    _openAllNearbyUsersBottomSheet(usersList),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D0D28)
                                        .withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: const Color(0xFF00FF9D)
                                          .withOpacity(0.65),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF9D)
                                            .withOpacity(0.25),
                                        blurRadius: 14,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.people_alt_rounded,
                                        color: Color(0xFF00FF9D),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "View $extraUsersCount+ more",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        color: Color(0xFF00FF9D),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Empty state hint if no devices found yet
                      if (usersList.isEmpty)
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00FF9D)),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Scanning for nearby beacons...",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Top Toolbar: Status & Watchlist Heart Icon Button (rendered on top so taps always work)
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active Broadcasting Indicator
              ValueListenableBuilder<bool>(
                valueListenable: _nearbyService.isBroadcastingNotifier,
                builder: (context, isBroadcasting, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A26).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isBroadcasting
                            ? const Color(0xFF00FF9D).withOpacity(0.4)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isBroadcasting
                                ? const Color(0xFF00FF9D)
                                : Colors.grey,
                            boxShadow: isBroadcasting
                                ? [
                                    const BoxShadow(
                                      color: Color(0xFF00FF9D),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isBroadcasting ? "Broadcasting Active" : "Nearby Scanning",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Heart Icon Button -> Opens Watchlist Bottomsheet
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    debugPrint("Watchlist button tapped from radar view!");
                    _openWatchlistBottomSheet();
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0A26).withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.orange,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Groups users into 4 orbit levels based on distance
  Map<int, List<NearbyUserFound>> _groupUsersIntoOrbits(
      List<NearbyUserFound> users) {
    final Map<int, List<NearbyUserFound>> orbits = {
      0: [],
      1: [],
      2: [],
      3: [],
    };

    for (final u in users) {
      if (u.distanceMeters < 3.0) {
        orbits[0]!.add(u);
      } else if (u.distanceMeters < 8.0) {
        orbits[1]!.add(u);
      } else if (u.distanceMeters < 18.0) {
        orbits[2]!.add(u);
      } else {
        orbits[3]!.add(u);
      }
    }
    return orbits;
  }

  // ─────────────────────────────────────────────
  //  3. SUN / CENTER AVATAR
  // ─────────────────────────────────────────────
  Widget _buildCenterSunAvatar(String? photoUrl) {
    return GestureDetector(
      onLongPress: kDebugMode ? _toggleDebugMockUsers : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Glowing pulsing ring around the Sun
              AnimatedBuilder(
                animation: _radarAnimController,
                builder: (context, child) {
                  final pulse = sin(_radarAnimController.value * 2 * pi) * 0.15;
                  return Container(
                    width: 72 * (1.0 + pulse),
                    height: 72 * (1.0 + pulse),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF9D).withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00FF9D), width: 2.5),
                  color: const Color(0xFF16162A),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 32,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF9D),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "You",
              style: TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  4. PLANET NODE (Discovered Device)
  // ─────────────────────────────────────────────
  Widget _buildPlanetNode(NearbyUserFound user) {
    final details = user.details;
    final name = (details?['name'] ?? details?['username'] ?? 'User').toString();
    final profilePic = details?['profilePic']?.toString();

    // Heavily trimmed name badge (max 8-10 chars)
    String trimmedName = name.length > 9 ? "${name.substring(0, 8)}…" : name;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openUserProfileDialog(user),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Badge: Heavily trimmed name / status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D26).withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: user.isLoading
                    ? Colors.white24
                    : const Color(0xFF00FF9D).withOpacity(0.5),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: user.isLoading
                ? Shimmer.fromColors(
                    baseColor: Colors.grey.shade700,
                    highlightColor: Colors.grey.shade400,
                    child: Container(
                      width: 32,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )
                : Text(
                    trimmedName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
          ),
          const SizedBox(height: 3),

          // Planet Avatar Node (Shimmer while loading, Profile pic once loaded)
          user.isLoading
              ? Shimmer.fromColors(
                  baseColor: const Color(0xFF1E1E38),
                  highlightColor: const Color(0xFF383860),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white38, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white38,
                      size: 26,
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00FF9D),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF9D).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: profilePic != null && profilePic.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: profilePic,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF16162A),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF16162A),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ),
                  ),
                ),
          const SizedBox(height: 3),

          // Bottom Badge: Estimated Distance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sensors_rounded,
                  color: Color(0xFF00FF9D),
                  size: 9,
                ),
                const SizedBox(width: 3),
                Text(
                  user.distanceFormatted,
                  style: const TextStyle(
                    color: Color(0xFF00FF9D),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  5. PROFILE POPUP MODAL (On Planet Node Tap)
  // ─────────────────────────────────────────────
  void _openUserProfileDialog(NearbyUserFound user) {
    final details = user.details;
    final name = (details?['name'] ?? 'Nearby User').toString();
    final username = details?['username'] != null ? "@${details!['username']}" : "";
    final profilePic = details?['profilePic']?.toString();
    final bio = details?['bio']?.toString();
    final institution = details?['university'] ?? details?['college'] ?? details?['school'];
    final dbIndex = (details?['dbIndex'] ?? '0').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          decoration: const BoxDecoration(
            color: Color(0xFF121226),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 25,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Avatar with glowing ring
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00FF9D), width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF9D).withOpacity(0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: profilePic != null && profilePic.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profilePic,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white54,
                                size: 40,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 40,
                            ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FF9D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bluetooth_connected_rounded,
                      color: Colors.black,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Name and Username
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              if (username.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  username,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],

              // Distance badge
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF9D).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00FF9D).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF00FF9D),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "~${user.distanceFormatted} away (BLE Beacon)",
                      style: const TextStyle(
                        color: Color(0xFF00FF9D),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Bio or Institution if present
              if (institution != null || (bio != null && bio.isNotEmpty)) ...[
                const SizedBox(height: 14),
                if (institution != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.school_outlined,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            institution.toString(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (bio != null && bio.isNotEmpty)
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // Action Buttons: Open Chat & View Profile
              Row(
                children: [
                  // View Profile Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageTransition(
                            isIos: true,
                            type: PageTransitionType.rightToLeft,
                            child: PublicProfilePage(
                              uid: user.id,
                              dbIndex: dbIndex,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        "View Profile",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Open Chat Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          PageTransition(
                            isIos: true,
                            type: PageTransitionType.rightToLeft,
                            child: ChatScreen(
                              data: {
                                'userId': user.id,
                                'name': name,
                                'profilePic': profilePic,
                              },
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Colors.black, size: 18),
                      label: const Text(
                        "Open Chat",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF9D),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  6. CUSTOM PAINTER: ORBIT WEB & RADAR SWEEP
// ─────────────────────────────────────────────
class OrbitWebPainter extends CustomPainter {
  final double radarProgress; // 0.0 to 1.0
  final List<double> orbitRatios;
  final double baseRadiusX;
  final double baseRadiusY;

  OrbitWebPainter({
    required this.radarProgress,
    required this.orbitRatios,
    required this.baseRadiusX,
    required this.baseRadiusY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final orbitPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final webLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Draw radial web grid lines (8 spokes)
    const int spokes = 8;
    for (int i = 0; i < spokes; i++) {
      final angle = (i * 2 * pi) / spokes;
      final maxRx = baseRadiusX * orbitRatios.last;
      final maxRy = baseRadiusY * orbitRatios.last;
      final end = Offset(
        center.dx + maxRx * cos(angle),
        center.dy + maxRy * sin(angle),
      );
      canvas.drawLine(center, end, webLinePaint);
    }

    // Draw concentric oval orbit rings
    for (int i = 0; i < orbitRatios.length; i++) {
      final rx = baseRadiusX * orbitRatios[i];
      final ry = baseRadiusY * orbitRatios[i];

      final rect = Rect.fromCenter(
        center: center,
        width: rx * 2,
        height: ry * 2,
      );

      // Distinct subtle colors for inner vs outer orbits
      if (i == 0) {
        orbitPaint.color = const Color(0xFF00FF9D).withOpacity(0.18);
      } else {
        orbitPaint.color = Colors.white.withOpacity(0.06 + (i * 0.02));
      }

      canvas.drawOval(rect, orbitPaint);
    }

    // Draw animated rotating radar sweep beam
    final sweepAngle = radarProgress * 2 * pi;
    final maxRx = baseRadiusX * orbitRatios.last;
    final maxRy = baseRadiusY * orbitRatios.last;

    final sweepEnd = Offset(
      center.dx + maxRx * cos(sweepAngle),
      center.dy + maxRy * sin(sweepAngle),
    );

    final sweepLinePaint = Paint()
      ..color = const Color(0xFF00FF9D).withOpacity(0.22)
      ..strokeWidth = 1.5;
    canvas.drawLine(center, sweepEnd, sweepLinePaint);

    // Subtle sweeping gradient arc
    final sweepRect = Rect.fromCenter(
      center: center,
      width: maxRx * 2,
      height: maxRy * 2,
    );

    final arcGradient = SweepGradient(
      center: Alignment.center,
      startAngle: sweepAngle - (pi / 3),
      endAngle: sweepAngle,
      colors: [
        Colors.transparent,
        const Color(0xFF00FF9D).withOpacity(0.08),
      ],
      transform: GradientRotation(0),
    );

    final arcPaint = Paint()
      ..shader = arcGradient.createShader(sweepRect)
      ..style = PaintingStyle.fill;

    canvas.drawOval(sweepRect, arcPaint);
  }

  @override
  bool shouldRepaint(covariant OrbitWebPainter oldDelegate) {
    return oldDelegate.radarProgress != radarProgress;
  }
}
