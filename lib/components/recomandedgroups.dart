// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';

class Recomandedgroups extends StatefulWidget {
  final double? height;
  const Recomandedgroups({super.key, this.height});
  @override
  State<Recomandedgroups> createState() => _RecomandedgroupsState();
}

class _RecomandedgroupsState extends State<Recomandedgroups> {
  List<FriendCircleGroup> groups = [];
  double scale = 0.0;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool isLoadingError = false;

  // Cursor-based pagination state
  String? _nextCursor;
  bool _hasMore = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _getGroups();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !isLoadingMore &&
        _hasMore) {
      _loadMoreGroups();
    }
  }

  _getGroups() async {
    setState(() {
      isLoading = true;
      _nextCursor = null;
      _hasMore = true;
    });
    try {
      PaginatedGroupResult result =
          await GroupsService.getRecommendedGroups();
      setState(() {
        groups = result.groups;
        _nextCursor = result.nextCursor;
        _hasMore = result.hasMore;
      });
      print(groups);
    } catch (error) {
      print(error);
      setState(() {
        isLoadingError = true;
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadMoreGroups() async {
    if (isLoadingMore || !_hasMore) return;

    setState(() {
      isLoadingMore = true;
    });

    try {
      PaginatedGroupResult result = await GroupsService.getRecommendedGroups(
        cursor: _nextCursor,
      );
      setState(() {
        groups.addAll(result.groups);
        _nextCursor = result.nextCursor;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      print('Error loading more recommended groups: $error');
    } finally {
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
          ),
          child: Column(
            children: [
              SizedBox(
                height: 20,
              ),
              SizedBox(
                height: 10,
              ),
              Expanded(
                child: isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      )
                    : isLoadingError
                        ? Center(
                            child: Text('Error loading data',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)))
                        : Padding(
                            padding: const EdgeInsets.all(2),
                            child: FriendCircleLayout(
                              scrollController: _scrollController,
                              groups: groups,
                              spacing: 20,
                              crossAxisCount: 2,
                              defaultEdgeStyle: EdgeStyle(
                                color:
                                    const Color.fromARGB(255, 189, 190, 190),
                                width: 3.5,
                                outerGlow: 3.0,
                                outerGlowColor: Colors.blue.withOpacity(0.3),
                                cornerRadius: 100.0,
                              ),
                              onGroupTap: (groupId, groupData) {
                                print(
                                    'Group $groupId tapped with data: $groupData');
                                Navigator.push(
                                  context,
                                  PageTransition(
                                    type: PageTransitionType.rightToLeft,
                                    child: GroupPublicViewScreen(
                                      groupId: groupId,
                                    ),
                                  ),
                                );
                              },
                              onMemberTap: (groupId, memberId, memberData) {
                                print(
                                    'Member $memberId in group $groupId tapped with data: $memberData');
                                Navigator.push(
                                  context,
                                  PageTransition(
                                    type: PageTransitionType.rightToLeft,
                                    child: GroupPublicViewScreen(
                                      groupId: groupId,
                                    ),
                                  ),
                                );
                              },
                              footerWidget: _buildFooter(),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildFooter() {
    if (isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white54,
            strokeWidth: 2,
          ),
        ),
      );
    }
    if (!_hasMore && groups.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'No more groups',
            style: TextStyle(color: Colors.white38, fontFamily: 'Poppins'),
          ),
        ),
      );
    }
    return null;
  }
}
