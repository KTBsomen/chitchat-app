// ignore_for_file: prefer_const_constructors

import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/searchBar.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

class Recomandedgroups extends StatefulWidget {
  @override
  State<Recomandedgroups> createState() => _RecomandedgroupsState();
}

class _RecomandedgroupsState extends State<Recomandedgroups>
    with WidgetsBindingObserver {
  List<FriendCircleGroup> groups = [];
  double scale = 0.0;
  bool isLoading = true;
  bool isLoadingError = false;

  // Search result state
  String selectedType = 'Groups';
  List<Map<String, dynamic>> searchResultUsers = [];
  List<Map<String, dynamic>> searchResultColleges = [];
  List<Map<String, dynamic>> searchResultUniversities = [];
  List<Map<String, dynamic>> searchResultSchools = [];

  // Share tracking state for invite bottom sheet
  DateTime? _shareTriggeredAt;
  bool _waitingForShareResult = false;
  VoidCallback? _onShareResumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getGroups();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForShareResult) {
      if (_shareTriggeredAt != null) {
        final elapsed = DateTime.now().difference(_shareTriggeredAt!);
        if (elapsed.inMilliseconds > 4000) {
          _onShareResumed?.call();
        }
      }
      _waitingForShareResult = false;
      _shareTriggeredAt = null;
    }
  }

  _getGroups() async {
    setState(() {
      isLoading = true;
    });
    try {
      PaginatedGroupResult result = await GroupsService.getRecommendedGroups();
      groups = result.groups;
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        Navigator.pushReplacement(
          context,
          PageTransition(
            type: PageTransitionType.leftToRight,
            child: HomePage(),
            duration: Duration(milliseconds: 400),
          ),
        );
      },
      child: SafeArea(
        child: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
            ),
            child: Column(
              children: [
                SizedBox(height: 20),
                Text(
                  "Join or Create",
                  style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  "Your Friend Circle",
                  style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(height: 10),
                ImprovedSearchBar(
                  selectedType: selectedType,
                  onLoading: (loading) {
                    setState(() {
                      isLoading = loading;
                    });
                  },
                  onSelectedType: (type) {
                    setState(() {
                      selectedType = type;
                    });
                    // Reload recommended groups when switching back to Groups
                    if (type == 'Groups' || type == 'Passout') {
                      _getGroups();
                    }
                  },
                  onGroupSearchResult: (resultGroups) {
                    setState(() {
                      groups = resultGroups;
                    });
                  },
                  onUserSearchResult: (results) {
                    setState(() {
                      searchResultUsers = results;
                    });
                  },
                  onCollegeSearchResult: (results) {
                    setState(() {
                      searchResultColleges = results;
                    });
                  },
                  onUniversitySearchResult: (results) {
                    setState(() {
                      searchResultUniversities = results;
                    });
                  },
                  onSchoolSearchResult: (results) {
                    setState(() {
                      searchResultSchools = results;
                    });
                  },
                  debounceDuration: Duration(milliseconds: 800),
                ),
                SizedBox(height: 10),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(left: 25, right: 25),
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
                            : _buildSearchResults(),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    _showCreateGroupDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Create Your Own',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            'Skip Group Creation',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            'You cannot do anything in this app until you create or join one group.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    PageTransition(
                                        type: PageTransitionType.leftToRight,
                                        child: HomePage(),
                                        duration: Duration(milliseconds: 400)));
                              },
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Skip >',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
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

  /// Build search results based on the selected type
  Widget _buildSearchResults() {
    switch (selectedType) {
      case 'Name':
        return _buildUserResults();
      case 'University':
        return _buildInstitutionResults(searchResultUniversities, 'university');
      case 'College':
        return _buildInstitutionResults(searchResultColleges, 'college');
      case 'School':
        return _buildInstitutionResults(searchResultSchools, 'school');
      case 'Groups':
      case 'Passout':
      default:
        return _buildGroupResults();
    }
  }

  /// Group ring display (same as before)
  Widget _buildGroupResults() {
    if (groups.isEmpty) {
      return Center(
        child: Text('No groups found. Try searching!',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }
    return InteractiveViewer(
      onInteractionUpdate: (details) {
        setState(() {
          scale = details.scale;
        });
      },
      maxScale: 10.0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FriendCircleLayout(
          groups: groups,
          spacing: 10 * scale,
          crossAxisCount: 2,
          defaultEdgeStyle: EdgeStyle(
            color: const Color.fromARGB(255, 189, 190, 190),
            width: 3.5,
            outerGlow: 3.0,
            outerGlowColor: Colors.blue.withOpacity(0.3),
            cornerRadius: 100.0,
          ),
          onGroupTap: (groupId, groupData) {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: GroupPublicViewScreen(groupId: groupId),
              ),
            );
          },
          onMemberTap: (groupId, memberId, memberData) {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: GroupPublicViewScreen(groupId: groupId),
              ),
            );
          },
        ),
      ),
    );
  }

  /// User search results list
  Widget _buildUserResults() {
    if (searchResultUsers.isEmpty) {
      return Center(
        child: Text('Search for users by name',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }
    return ListView.builder(
      itemCount: searchResultUsers.length,
      itemBuilder: (context, index) {
        final user = searchResultUsers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
                user['profilePic'] ?? 'https://unsplash.it/200/200'),
          ),
          title: Text(user['name'] ?? '',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
          subtitle: Text(user['education'] ?? '',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          onTap: () {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: PublicProfilePage(
                    dbIndex: user['dbIndex'] ?? 0, uid: user['_id'] ?? ''),
              ),
            );
          },
        );
      },
    );
  }

  /// Institution search results (college / university / school)
  Widget _buildInstitutionResults(
      List<Map<String, dynamic>> results, String type) {
    if (results.isEmpty) {
      return Center(
        child: Text('Search for ${type}s...',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: Icon(
            type == 'school'
                ? Icons.menu_book_outlined
                : type == 'college'
                    ? Icons.school_outlined
                    : Icons.account_balance_outlined,
            color: Colors.white70,
          ),
          title: Text(
              item['name'] ?? item['institution_name'] ?? item['Name'] ?? '',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins')),
          subtitle: Text(
              item['address'] ?? item['district'] ?? item['District'] ?? '',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        );
      },
    );
  }

  /// Create group dialog — extracted from original inline code
  void _showCreateGroupDialog() {
    String groupName = '';
    File? logoFile;
    bool isNameEmpty = false;
    bool isSubmitted = false;
    S3Uploader? uploader;
    CancelToken? cancelToken;

    String baseurl =
        AppVariables.get<String>('baseurl')?.trim() ?? 'http://localhost:3000';
    ValueNotifier<FileUploadProgress> progressNotifier =
        ValueNotifier<FileUploadProgress>(
      FileUploadProgress(fileName: 'Uploading...'),
    );
    uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: progressNotifier,
    );

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (BuildContext context, setState) {
          return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                if (isSubmitted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Please wait for the group to be created or cancel the process.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(Icons.group_add, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Create New Group',
                      style: TextStyle(
                          fontSize: 18,
                          color: AppColors.background,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins'),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Group Name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: Icon(Icons.group),
                            ),
                            onChanged: (value) {
                              setState(() {
                                groupName = value;
                                isNameEmpty = false;
                              });
                            },
                          ),
                          Visibility(
                            visible: isNameEmpty,
                            child: Text(
                              "Group Name must be filled",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      isSubmitted
                          ? Visibility(
                              visible: isSubmitted,
                              child: UploadProgressWidget(
                                  progressNotifier: progressNotifier))
                          : InkWell(
                              onTap: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (image != null) {
                                  logoFile = File(image.path);
                                  setState(() {});
                                }
                              },
                              child: Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: logoFile == null
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate,
                                                size: 40, color: Colors.grey),
                                            SizedBox(height: 8),
                                            Text('Choose Logo'),
                                          ],
                                        ),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          logoFile!,
                                          fit: BoxFit.fitHeight,
                                        ),
                                      ),
                              ),
                            ),
                    ],
                  ),
                ),
                actionsPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (isSubmitted) {
                        cancelToken?.cancel("User cancelled the process");
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isSubmitted
                        ? null
                        : () async {
                            if (groupName.length > 0) {
                              setState(() {
                                isNameEmpty = false;
                                isSubmitted = true;
                                cancelToken = CancelToken();
                              });
                              try {
                                List<String> url = await uploader!.uploadFiles(
                                  files: [logoFile!],
                                  compressionParams: {
                                    "width": 600,
                                    "height": 600,
                                    "quality": 100,
                                  },
                                  cancelToken: cancelToken,
                                );
                                print(url);
                                Map<String, dynamic> result =
                                    await GroupsService.createGroup(
                                        groupName, url[0],
                                        cancelToken: cancelToken);
                                print(result);
                                if (result['success'] == true) {
                                  // Refresh profile so AppVariables has the new myGroup data
                                  await UserService.fetchMyProfile();
                                  Navigator.pop(context); // close create dialog
                                  _showInviteBottomSheet(
                                      result['data']['group']);
                                } else {
                                  progressNotifier.value =
                                      progressNotifier.value.copyWith(
                                    stage: UploadStage.failed,
                                    customStageText: "Error Creating Group",
                                    customStageTextDetail:
                                        "Only one group can be created at a time",
                                    errorMessage: result['error'],
                                  );
                                }
                              } catch (e) {
                                if (e is DioException &&
                                    e.type == DioExceptionType.cancel) {
                                  print("Process cancelled by user");
                                } else {
                                  setState(() {
                                    isSubmitted = false;
                                  });
                                  progressNotifier.value =
                                      progressNotifier.value.copyWith(
                                    stage: UploadStage.failed,
                                    customStageText: "Error",
                                    errorMessage: e.toString(),
                                  );
                                }
                              }
                            } else {
                              setState(() {
                                isNameEmpty = true;
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        Text('Create', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ));
        });
      },
    );
  }

  // ── Invite Friends Bottom Sheet ──────────────────────────────────────────

  void _showInviteBottomSheet(Map<String, dynamic> groupData) {
    int shareCount = 0;
    List<bool> circleShared = List.filled(6, false);
    bool skipVisible = false;
    bool skipTimerStarted = false;
    String groupId = groupData['_id'] ?? '';
    String groupName = groupData['name'] ?? 'our group';

    void doNavigateContinue() {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.leftToRight,
          child: GroupPrivateViewScreen(fromRegister: true),
          duration: Duration(milliseconds: 400),
        ),
      );
    }

    void doNavigateSkip() {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false, // DraggableScrollableSheet handles drag
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.7,
          maxChildSize: 0.9,
          shouldCloseOnMinExtent: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return StatefulBuilder(
              builder: (BuildContext ctx, StateSetter setSheetState) {
                // Wire up the lifecycle callback so share-detect can update UI
                _onShareResumed = () {
                  if (shareCount < 6) {
                    setSheetState(() {
                      circleShared[shareCount] = true;
                      shareCount++;
                    });
                  }
                };

                // Delayed skip button (fire-once)
                if (!skipTimerStarted) {
                  skipTimerStarted = true;
                  Future.delayed(Duration(seconds: 60), () {
                    if (ctx.mounted) {
                      setSheetState(() => skipVisible = true);
                    }
                  });
                }

                String inviteBtnText() {
                  if (shareCount == 0) return 'invite ur bestie 💌';
                  if (shareCount == 1) return '3 more to go! 🔥';
                  if (shareCount == 2) return 'just 2 more 🚀';
                  if (shareCount == 3) return 'almost there! 1 more 🚀';
                  return 'invite more 🎉';
                }

                void triggerShare() {
                  _shareTriggeredAt = DateTime.now();
                  _waitingForShareResult = true;
                  SharePlus.instance.share(ShareParams(
                    title: 'join my frndcircle 🔥',
                    text:
                        'Join our group $groupName!\n\nhttps://groups.chitzchat.com/join?group=$groupId',
                    subject: 'Join my group on ChitChat!',
                  ));
                }

                void showSkipConfirmation() {
                  showDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      backgroundColor: Color(0xFF1a1a2e),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text(
                        'nah fr? 😭',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      content: Text(
                        'without ur squad it\'s lowkey boring\nyou\'ll miss all the fun bestie 💔',
                        style: TextStyle(
                          color: Colors.white70,
                          fontFamily: 'Poppins',
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      actionsAlignment: MainAxisAlignment.center,
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dCtx);
                            doNavigateSkip();
                          },
                          child: Text(
                            'skip anyway 🥲',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontFamily: 'Poppins',
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'nah i\'ll invite 😎',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, result) {
                    if (didPop) return;
                    if (shareCount >= 4) {
                      doNavigateContinue();
                    } else {
                      showSkipConfirmation();
                    }
                  },
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF1a1a2e).withOpacity(0.90),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Handle
                            Container(
                              margin: EdgeInsets.only(top: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),

                            // Scrollable Top Section
                            Expanded(
                              child: ListView(
                                controller: scrollController,
                                padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                                children: [
                                  // Header
                                  Text(
                                    'yoo squad up! 🔥',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    shareCount >= 4
                                        ? 'you\'re goated 🐐 squad\'s ready!'
                                        : 'invite atleast 4 homies to keep the vibe alive 💫',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 32),

                                  // Circles Grid (Top)
                                  _buildCircleGrid(circleShared, triggerShare),
                                ],
                              ),
                            ),

                            // Fixed Bottom Section (Buttons)
                            Padding(
                              padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                              child: Column(
                                children: [
                                  if (shareCount >= 4) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 54,
                                            child: OutlinedButton(
                                              onPressed: triggerShare,
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                    color: Colors.blue),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: Text(
                                                'invite more',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            height: 54,
                                            child: ElevatedButton(
                                              onPressed: doNavigateContinue,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                elevation: 8,
                                                shadowColor: Colors.blue
                                                    .withOpacity(0.5),
                                              ),
                                              child: Text(
                                                'let\'s goo →',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Container(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: triggerShare,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 8,
                                          shadowColor:
                                              Colors.blue.withOpacity(0.5),
                                        ),
                                        child: Text(
                                          inviteBtnText(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Skip button — fades in after 50s
                                  AnimatedOpacity(
                                    opacity: skipVisible ? 1.0 : 0.0,
                                    duration: Duration(milliseconds: 500),
                                    child: skipVisible
                                        ? Padding(
                                            padding: EdgeInsets.only(top: 16),
                                            child: TextButton(
                                              onPressed: showSkipConfirmation,
                                              child: Text(
                                                'skip for now',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontFamily: 'Poppins',
                                                  fontSize: 13,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor:
                                                      Colors.grey[500],
                                                ),
                                              ),
                                            ),
                                          )
                                        : SizedBox(height: 52),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Builds the 2×3 grid of share-indicator circles
  Widget _buildCircleGrid(List<bool> circleShared, VoidCallback onTap) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              3, (i) => _buildShareCircle(circleShared[i], onTap)),
        ),
        SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              3, (i) => _buildShareCircle(circleShared[i + 3], onTap)),
        ),
      ],
    );
  }

  /// Single share-indicator circle (grey person → glowing check)
  Widget _buildShareCircle(bool isShared, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isShared
              ? Colors.green.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          border: Border.all(
            color: isShared ? Colors.green : Colors.white10,
            width: isShared ? 3 : 1.5,
          ),
          boxShadow: isShared
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 400),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: isShared
                ? Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 40,
                    key: ValueKey('check'),
                  )
                : Icon(
                    Icons.person_add_rounded,
                    color: Colors.white24,
                    size: 32,
                    key: ValueKey('person'),
                  ),
          ),
        ),
      ),
    );
  }
}
