// ignore_for_file: prefer_const_constructors

import 'dart:io';

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

class Recomandedgroups extends StatefulWidget {
  @override
  State<Recomandedgroups> createState() => _RecomandedgroupsState();
}

class _RecomandedgroupsState extends State<Recomandedgroups> {
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

  @override
  void initState() {
    super.initState();
    _getGroups();
  }

  _getGroups() async {
    setState(() {
      isLoading = true;
    });
    groups = await GroupsService.getRecommendedGroups().catchError((error) {
      print(error);
      setState(() {
        isLoading = false;
        isLoadingError = true;
      });
      return <FriendCircleGroup>[];
    });
    print(groups);
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
                child: PublicProfilePage(
                    dbIndex: memberData['dbIndex'], uid: memberId),
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
          return AlertDialog(
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
            actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: [
              TextButton(
                onPressed: () {
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
                          });
                          List<String> url =
                              await uploader!.uploadFiles(files: [
                            logoFile!
                          ], compressionParams: {
                            "width": 600,
                            "height": 600,
                            "quality": 100,
                          });
                          print(url);
                          Map<String, dynamic> result =
                              await GroupsService.createGroup(
                                  groupName, url[0]);
                          print(result);
                          if (result['success'] == true) {
                            // Refresh profile so AppVariables has the new myGroup data
                            await UserService.fetchMyProfile();
                            Navigator.pop(context);
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const HomePage()),
                                (route) => false);
                            Navigator.push(
                                context,
                                PageTransition(
                                    type: PageTransitionType.leftToRight,
                                    child: GroupPrivateViewScreen(
                                      fromRegister: true,
                                    ),
                                    duration: Duration(milliseconds: 400)));
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
                child: Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }
}
