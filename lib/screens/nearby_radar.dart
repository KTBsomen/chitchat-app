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
import 'package:chitchat/screens/personal_chat_screen.dart';
import 'package:chitchat/services/personal_chat_service.dart';
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
  void _showBroadcastTagDialog() {
    final textController = TextEditingController();
    String selectedTag = '';
    int selectedTtlSeconds = 1800;
    bool isSubmitting = false;
    bool isDeleting = false;

    final predefinedTags = [
      '\u2615 Coffee Break',
      '\u{1F4DA} Library Study',
      '\u{1F4BB} Coding Project',
      '\u{1F354} Grabbing Food',
      '\u{1F3C0} Playing Sports',
      '\u{1F4AC} Open to Chat',
    ];

    final ttlOptions = [
      {'label': '5 mins', 'seconds': 300},
      {'label': '30 mins', 'seconds': 1800},
      {'label': '1 hr', 'seconds': 3600},
      {'label': '4 hrs', 'seconds': 14400},
      {'label': '12 hrs', 'seconds': 43200},
      {'label': '24 hrs (1 Day)', 'seconds': 86400},
    ];

    String formatRemaining(Map<String, dynamic>? tag) {
      if (tag == null) return '';
      if (tag['expiresAt'] != null) {
        final exp = (tag['expiresAt'] as num).toInt();
        final diffMs = exp - DateTime.now().millisecondsSinceEpoch;
        if (diffMs <= 0) return 'Expired';
        final mins = (diffMs / 60000).ceil();
        if (mins < 60) return '${mins}m left';
        final hours = mins ~/ 60;
        final remMins = mins % 60;
        if (hours < 24)
          return remMins > 0 ? '${hours}h ${remMins}m left' : '${hours}h left';
        return '${hours ~/ 24}d left';
      } else if (tag['remainingTtlSeconds'] != null) {
        final secs = (tag['remainingTtlSeconds'] as num).toInt();
        if (secs <= 0) return 'Expired';
        if (secs < 3600) return '${(secs / 60).ceil()}m left';
        final hours = secs ~/ 3600;
        final remMins = (secs % 3600) ~/ 60;
        if (hours < 24)
          return remMins > 0 ? '${hours}h ${remMins}m left' : '${hours}h left';
        return '${hours ~/ 24}d left';
      }
      return '';
    }

    final initialActiveTag = _nearbyService.myActiveTagNotifier.value;
    if (initialActiveTag != null) {
      textController.text = (initialActiveTag['message'] ?? '').toString();
      if (initialActiveTag['ttlSeconds'] is num) {
        selectedTtlSeconds = (initialActiveTag['ttlSeconds'] as num).toInt();
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeTag = _nearbyService.myActiveTagNotifier.value;
            final hasActiveTag = activeTag != null &&
                (activeTag['message']?.toString().isNotEmpty ?? false);
            final remainingText = formatRemaining(activeTag);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF141728),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.local_offer_rounded,
                                  color: Color(0xFF00FF9D), size: 22),
                              SizedBox(width: 8),
                              Text(
                                "Nearby Broadcast Tag",
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
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Set an active status tag with a chosen duration visible to nearby students.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12.5,
                        ),
                      ),
                      if (hasActiveTag) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1F36),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF00FF9D).withOpacity(0.4),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF00FF9D).withOpacity(0.12),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFF00FF9D),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0xFF00FF9D),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Currently Active",
                                        style: TextStyle(
                                          color: Color(0xFF00FF9D),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (remainingText.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.timer_outlined,
                                              size: 12, color: Colors.white70),
                                          const SizedBox(width: 4),
                                          Text(
                                            remainingText,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '"${activeTag['message']}"',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF5252),
                                    backgroundColor: const Color(0xFFFF5252)
                                        .withOpacity(0.12),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: const Color(0xFFFF5252)
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                  icon: isDeleting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFFF5252)),
                                          ),
                                        )
                                      : const Icon(Icons.delete_outline_rounded,
                                          size: 16),
                                  label: Text(
                                    isDeleting
                                        ? "Deleting..."
                                        : "Delete / Clear Tag",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: isDeleting
                                      ? null
                                      : () async {
                                          setModalState(
                                              () => isDeleting = true);
                                          final success = await _nearbyService
                                              .deleteMyActiveTag();
                                          setModalState(() {
                                            isDeleting = false;
                                            textController.clear();
                                            selectedTag = '';
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  success
                                                      ? "Nearby tag cleared successfully!"
                                                      : "Failed to delete nearby tag",
                                                ),
                                                backgroundColor: success
                                                    ? const Color(0xFF00FF9D)
                                                    : Colors.redAccent,
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white12, height: 1),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: const [
                          Icon(Icons.hourglass_bottom_rounded,
                              color: Color(0xFF00FF9D), size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Time To Live (Duration)",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ttlOptions.map((opt) {
                          final secs = opt['seconds'] as int;
                          final label = opt['label'] as String;
                          final isSelected = selectedTtlSeconds == secs;
                          return ChoiceChip(
                            label: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00FF9D),
                            backgroundColor: const Color(0xFF1F2338),
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => selectedTtlSeconds = secs);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Quick Tags",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: predefinedTags.map((tag) {
                          final isSelected = selectedTag == tag;
                          return ChoiceChip(
                            label: Text(
                              tag,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00FF9D),
                            backgroundColor: const Color(0xFF1F2338),
                            onSelected: (selected) {
                              setModalState(() {
                                selectedTag = selected ? tag : '';
                                if (selected) {
                                  textController.text = tag;
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: textController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Or type a custom status...",
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.35)),
                          filled: true,
                          fillColor: const Color(0xFF1F2338),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : const Icon(Icons.broadcast_on_personal,
                                  color: Colors.black, size: 18),
                          label: Text(
                            isSubmitting
                                ? "Broadcasting..."
                                : (hasActiveTag
                                    ? "Update Broadcast Tag"
                                    : "Broadcast Tag"),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF9D),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final msg = textController.text.trim();
                                  if (msg.isEmpty) return;

                                  setModalState(() => isSubmitting = true);
                                  final res = await PersonalChatService
                                      .broadcastNearbyTag(
                                    message: msg,
                                    tagType: selectedTag.isNotEmpty
                                        ? 'preset'
                                        : 'custom',
                                    ttlSeconds: selectedTtlSeconds,
                                  );

                                  if (res['success'] == true &&
                                      res['tag'] != null) {
                                    _nearbyService.myActiveTagNotifier.value =
                                        Map<String, dynamic>.from(res['tag']);
                                  }

                                  Navigator.pop(ctx);

                                  if (mounted) {
                                    if (res['success'] == true) {
                                      final ttlItem = ttlOptions.firstWhere(
                                        (o) =>
                                            o['seconds'] == selectedTtlSeconds,
                                        orElse: () => {
                                          'label':
                                              '${selectedTtlSeconds ~/ 60}m'
                                        },
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Nearby tag active for ${ttlItem['label']}!",
                                          ),
                                          backgroundColor:
                                              const Color(0xFF00FF9D),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(res['error'] ??
                                              "Failed to broadcast tag"),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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

    _nearbyService.fetchMyActiveTag();
    _nearbyService.loadCachedUsers();
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
    _nearbyService.stopScanning();
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
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white70),
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
                  separatorBuilder: (_, __) => const Divider(
                      color: Colors.white10,
                      height: 1,
                      indent: 76,
                      endIndent: 20),
                  itemBuilder: (context, index) {
                    final user = allUsers[index];
                    final details = user.details;
                    final name = (details?['name'] ??
                            details?['username'] ??
                            'User ${index + 1}')
                        .toString();
                    final username = details?['username']?.toString();
                    final profilePic = details?['profilePic']?.toString();
                    final institution = details?['university'] ??
                        details?['college'] ??
                        details?['school'];
                    final bool isActive = user.isRecentlyActive;
                    final Color itemColor =
                        isActive ? const Color(0xFF00FF9D) : Colors.grey.shade500;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
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
                                  color: itemColor.withOpacity(0.7),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: profilePic != null &&
                                        profilePic.isNotEmpty
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
                          if (institution != null &&
                              institution.toString().isNotEmpty) ...[
                            Text(
                              " • ",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3)),
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
                          ] else if (username != null &&
                              username.isNotEmpty) ...[
                            Text(
                              " • ",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.3)),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: itemColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: itemColor.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive
                                  ? Icons.near_me_rounded
                                  : Icons.access_time_rounded,
                              size: 11,
                              color: itemColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive
                                  ? "~${user.distanceFormatted}"
                                  : "Offline",
                              style: TextStyle(
                                color: itemColor,
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
    final current = Map<String, NearbyUserFound>.from(
        _nearbyService.usersFoundNotifier.value);
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
            'activeTag': {
              'message': i % 3 == 0
                  ? '\u2615 Coffee Break'
                  : (i % 2 == 0
                      ? '\u{1F4BB} Coding Project'
                      : '\u{1F4DA} Study Session'),
              'ttlSeconds': 3600,
            },
          },
        );
      }
      _nearbyService.usersFoundNotifier.value = current;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Added 20 mock nearby profiles! Long-press 'You' to reset."),
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
                          final scale =
                              1.0 + (_radarAnimController.value * 0.25);
                          final opacity = (1.0 - _radarAnimController.value)
                              .clamp(0.0, 0.7);
                          return Container(
                            width: 140 * scale,
                            height: 140 * scale,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00FF9D)
                                  .withOpacity(opacity * 0.25),
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
                    subtitle:
                        "Minimal battery consumption with native beaconing",
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturePill(
                    icon: Icons.lock_outline_rounded,
                    title: "Safe & Privacy-First",
                    subtitle:
                        "Only your public profile is visible to nearby peers",
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bolt_rounded,
                                    color: Colors.black, size: 24),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight / 2,
        );
        // Radius definitions for 4 concentric oval rings (horizontal & vertical radii)
        final baseRadiusX = constraints.maxWidth * 0.44;
        final baseRadiusY = constraints.maxHeight * 0.38;

        final orbitRatios = [0.42, 0.62, 0.80, 0.98];

        return RefreshIndicator(
          color: const Color(0xFF00FF9D),
          backgroundColor: const Color(0xFF141728),
          strokeWidth: 2.5,
          edgeOffset: 70.0,
          onRefresh: () async {
            await _nearbyService.refreshRadarDetails();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Stack(
                children: [
                  // Solar System Orbit Canvas & Planet Nodes (rendered first)
                  Positioned.fill(
                    child: ValueListenableBuilder<Map<String, NearbyUserFound>>(
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

                      // Planet Nodes with invisible bounding box collision prevention
                      ...(() {
                        final placedNodes = _calculateNonOverlappingPositions(
                          displayedUsers: displayedUsers,
                          orbitUsers: orbitUsers,
                          center: center,
                          containerSize:
                              Size(constraints.maxWidth, constraints.maxHeight),
                          baseRadiusX: baseRadiusX,
                          baseRadiusY: baseRadiusY,
                          orbitRatios: orbitRatios,
                        );

                        return placedNodes.map((placed) {
                          return Positioned(
                            left: placed.position.dx - (kNodeBoxWidth / 2),
                            top: placed.position.dy - (kNodeBoxHeight / 2),
                            child: SizedBox(
                              width: kNodeBoxWidth,
                              height: kNodeBoxHeight,
                              child: Center(
                                child: _buildPlanetNode(placed.user),
                              ),
                            ),
                          );
                        });
                      })(),

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          isBroadcasting
                              ? "Broadcasting Active"
                              : "Nearby Scanning",
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

              // Right Controls: Active Tag Chip + Watchlist Heart Button
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ],
          ),
        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const double kNodeBoxWidth = 88.0;
  static const double kNodeBoxHeight = 118.0;

  List<_PlacedRadarNode> _calculateNonOverlappingPositions({
    required List<NearbyUserFound> displayedUsers,
    required Map<int, List<NearbyUserFound>> orbitUsers,
    required Offset center,
    required Size containerSize,
    required double baseRadiusX,
    required double baseRadiusY,
    required List<double> orbitRatios,
  }) {
    if (displayedUsers.isEmpty) return [];

    final List<NearbyUserFound> orderedUsers = [];
    final List<Offset> positions = [];

    orbitUsers.forEach((orbitIndex, usersInOrbit) {
      if (usersInOrbit.isEmpty) return;
      final rx = baseRadiusX * orbitRatios[orbitIndex];
      final ry = baseRadiusY * orbitRatios[orbitIndex];
      final count = usersInOrbit.length;
      // Stagger start angles using golden angle offset so concentric orbits don't align radially
      final baseAngle = orbitIndex * (pi * 0.618);

      for (int i = 0; i < count; i++) {
        final angle = baseAngle + (i * (2 * pi / max(1, count)));
        final px = center.dx + rx * cos(angle);
        final py = center.dy + ry * sin(angle);

        orderedUsers.add(usersInOrbit[i]);
        positions.add(Offset(px, py));
      }
    });

    // Iterative collision resolution with invisible bounding box
    const int iterations = 35;
    const double minSunDist =
        92.0; // Clears the center sun (radius 36) + margin

    for (int iter = 0; iter < iterations; iter++) {
      // Repel from center sun
      for (int i = 0; i < positions.length; i++) {
        final dCenter = (positions[i] - center).distance;
        if (dCenter < minSunDist) {
          final normal = dCenter > 0.1
              ? (positions[i] - center) / dCenter
              : const Offset(0, -1);
          positions[i] = center + normal * minSunDist;
        }
      }

      // Repel overlapping nodes using invisible bounding box
      for (int i = 0; i < positions.length; i++) {
        for (int j = i + 1; j < positions.length; j++) {
          final dx = positions[j].dx - positions[i].dx;
          final dy = positions[j].dy - positions[i].dy;

          // Normalized elliptical metric for bounding box
          final normDistSq = (dx * dx) / (kNodeBoxWidth * kNodeBoxWidth) +
              (dy * dy) / (kNodeBoxHeight * kNodeBoxHeight);

          if (normDistSq < 1.0) {
            final normDist = sqrt(max(0.0001, normDistSq));
            final overlap = 1.0 - normDist;

            // Push apart along the collision vector
            final pushX = (dx / (normDist * kNodeBoxWidth)) *
                overlap *
                0.5 *
                kNodeBoxWidth;
            final pushY = (dy / (normDist * kNodeBoxHeight)) *
                overlap *
                0.5 *
                kNodeBoxHeight;

            positions[i] =
                Offset(positions[i].dx - pushX, positions[i].dy - pushY);
            positions[j] =
                Offset(positions[j].dx + pushX, positions[j].dy + pushY);
          }
        }
      }

      // Keep within visible bounds
      for (int i = 0; i < positions.length; i++) {
        final halfW = kNodeBoxWidth / 2;
        final halfH = kNodeBoxHeight / 2;
        final clampedX =
            positions[i].dx.clamp(halfW + 4, containerSize.width - halfW - 4);
        final clampedY =
            positions[i].dy.clamp(halfH + 8, containerSize.height - halfH - 24);
        positions[i] = Offset(clampedX, clampedY);
      }
    }

    return List.generate(orderedUsers.length, (i) {
      return _PlacedRadarNode(
        user: orderedUsers[i],
        position: positions[i],
      );
    });
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
      onTap: _showBroadcastTagDialog,
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
                  border:
                      Border.all(color: const Color(0xFF00FF9D), width: 2.5),
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
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _nearbyService.myActiveTagNotifier,
            builder: (context, myTag, _) {
              final activeMsg = myTag?['message']?.toString();
              if (activeMsg == null || activeMsg.isEmpty) {
                return const SizedBox.shrink();
              }
              final trimmedTag = activeMsg.length > 10
                  ? "${activeMsg.substring(0, 9)}…"
                  : activeMsg;
              return Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF9D).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00FF9D).withOpacity(0.55),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded,
                        color: Color(0xFF00FF9D), size: 9),
                    const SizedBox(width: 2),
                    Text(
                      trimmedTag,
                      style: const TextStyle(
                        color: Color(0xFF00FF9D),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
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
    final name =
        (details?['name'] ?? details?['username'] ?? 'User').toString();
    final profilePic = details?['profilePic']?.toString();

    final bool isActive = user.isRecentlyActive;
    final Color activeColor =
        isActive ? const Color(0xFF00FF9D) : Colors.grey.shade500;

    // Heavily trimmed name badge (max 8-10 chars)
    final activeTagRaw = details?['activeTag'];
    String? activeTagMsg;
    if (activeTagRaw is Map) {
      activeTagMsg = activeTagRaw['message']?.toString();
    } else if (activeTagRaw is String) {
      activeTagMsg = activeTagRaw;
    }
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
                    : activeColor.withOpacity(0.6),
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
          if (activeTagMsg != null && activeTagMsg.isNotEmpty) ...[
            const SizedBox(height: 2),
            Container(
              constraints: const BoxConstraints(maxWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: activeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: activeColor.withOpacity(0.6),
                  width: 0.8,
                ),
              ),
              child: Text(
                activeTagMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: activeColor,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
                      color: activeColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(isActive ? 0.35 : 0.15),
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

          // Bottom Badge: Estimated Distance / Activity
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isActive ? Icons.sensors_rounded : Icons.access_time_rounded,
                  color: activeColor,
                  size: 9,
                ),
                const SizedBox(width: 3),
                Text(
                  isActive ? user.distanceFormatted : "Offline",
                  style: TextStyle(
                    color: activeColor,
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
    final username =
        details?['username'] != null ? "@${details!['username']}" : "";
    final profilePic = details?['profilePic']?.toString();
    final bio = details?['bio']?.toString();
    final institution =
        details?['university'] ?? details?['college'] ?? details?['school'];
    final dbIndex = (details?['dbIndex'] ?? '0').toString();
    final activeTagRaw = details?['activeTag'];
    String? activeTagMsg;
    if (activeTagRaw is Map) {
      activeTagMsg = activeTagRaw['message']?.toString();
    } else if (activeTagRaw is String) {
      activeTagMsg = activeTagRaw;
    }
    final replyController = TextEditingController();

    final bool isActive = user.isRecentlyActive;
    final Color activeColor =
        isActive ? const Color(0xFF00FF9D) : Colors.grey.shade500;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final bottomInset = MediaQuery.of(modalContext).viewInsets.bottom;
            return AnimatedPadding(
              padding: EdgeInsets.only(bottom: bottomInset),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                ),
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
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
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
                              border: Border.all(
                                  color: activeColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor
                                      .withOpacity(isActive ? 0.35 : 0.15),
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
                            decoration: BoxDecoration(
                              color: activeColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              user.discoverySource == 'location'
                                  ? Icons.location_on_rounded
                                  : Icons.bluetooth_connected_rounded,
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

                      // Distance / Activity badge
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: activeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: activeColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isActive
                                  ? (user.discoverySource == 'location'
                                      ? Icons.location_searching_rounded
                                      : Icons.radar_rounded)
                                  : Icons.history_toggle_off_rounded,
                              color: activeColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isActive
                                  ? "~${user.distanceFormatted} away (${user.discoverySource == 'location' ? 'GPS Location' : 'BLE Beacon'})"
                                  : "Previously seen ~${user.distanceFormatted} • Offline",
                              style: TextStyle(
                                color: activeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bio or Institution if present
                      if (institution != null ||
                          (bio != null && bio.isNotEmpty)) ...[
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

                      // Active broadcast tag banner & reply field (ONLY shown if user has an active tag)
                      if (activeTagMsg != null && activeTagMsg.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF9D).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF00FF9D).withOpacity(0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.tag_rounded,
                                      color: Color(0xFF00FF9D), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    "Active Broadcast Tag",
                                    style: TextStyle(
                                      color: Color(0xFF00FF9D),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeTagMsg,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: replyController,
                                scrollPadding:
                                    const EdgeInsets.only(bottom: 120),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: "Reply to $name's tag...",
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 13,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E38),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                              ),
                              child: isSending
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black,
                                        ),
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.send_rounded,
                                          color: Colors.black, size: 18),
                                      onPressed: () async {
                                        final replyText =
                                            replyController.text.trim();
                                        if (replyText.isEmpty) return;

                                        final myId = (AppVariables.get<
                                                        Map<String, dynamic>>(
                                                    'profile')?['_id'] ??
                                                '')
                                            .toString();
                                        if (myId.isNotEmpty &&
                                            myId == user.id) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Cannot reply to your own node"),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                          return;
                                        }

                                        setModalState(() {
                                          isSending = true;
                                        });

                                        final modalNav =
                                            Navigator.of(modalContext);
                                        final messenger =
                                            ScaffoldMessenger.of(context);

                                        final res =
                                            await PersonalChatService.replyToTag(
                                          targetUserId: user.id,
                                          replyText: replyText,
                                          broadcastTagText: activeTagMsg,
                                        );

                                        if (!mounted) return;

                                        if (res['success'] == true) {
                                          modalNav.pop();

                                          final pairList = [myId, user.id]
                                            ..sort();
                                          final pairKey = (res['data'] is Map &&
                                                  res['data']['pairKey'] !=
                                                      null)
                                              ? res['data']['pairKey']
                                                  .toString()
                                              : pairList.join('_');

                                          Navigator.push(
                                            context,
                                            PageTransition(
                                              isIos: true,
                                              type: PageTransitionType
                                                  .rightToLeft,
                                              child: PersonalChatScreen(
                                                pairKey: pairKey,
                                                otherUserId: user.id,
                                                otherUserName: name,
                                                otherUserPic: profilePic,
                                              ),
                                            ),
                                          );
                                        } else {
                                          setModalState(() {
                                            isSending = false;
                                          });
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(res['error'] ??
                                                  'Failed to send message'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Action Buttons: Open Chat & View Profile
                      Row(
                        children: [
                          // View Profile Button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(modalContext).pop();
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
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
                                Navigator.of(modalContext).pop();
                                final myId = (AppVariables.get<
                                                Map<String, dynamic>>(
                                            'profile')?['_id'] ??
                                        '')
                                    .toString();
                                final pairList = [myId, user.id]..sort();
                                final pairKey = pairList.join('_');

                                Navigator.push(
                                  context,
                                  PageTransition(
                                    isIos: true,
                                    type: PageTransitionType.rightToLeft,
                                    child: PersonalChatScreen(
                                      pairKey: pairKey,
                                      otherUserId: user.id,
                                      otherUserName: name,
                                      otherUserPic: profilePic,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Colors.black,
                                  size: 18),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  6. CUSTOM PAINTER: ORBIT WEB & RADAR SWEEP
// ─────────────────────────────────────────────

class _PlacedRadarNode {
  final NearbyUserFound user;
  final Offset position;
  _PlacedRadarNode({required this.user, required this.position});
}

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
