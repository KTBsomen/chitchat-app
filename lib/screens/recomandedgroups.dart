// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
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

  @override
  void initState() {
    // TODO: implement initState
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
    });
    print(groups);
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            // gradient: LinearGradient(
            //   begin: Alignment.topCenter,
            //   end: Alignment.bottomCenter,
            //   colors: [
            //     Colors.blue.shade900,
            //     Colors.blue.shade800,
            //     Colors.blue.shade700,
            //     Colors.blue.shade600,
            //     Colors.blue.shade500,
            //     Colors.blue.shade400,
            //     Colors.blue.shade300,
            //     Colors.blue.shade200,
            //     Colors.blue.shade100,
            //     Colors.blue.shade50,
            //   ],
            // ),
          ),
          child: Column(
            children: [
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
              SizedBox(
                height: 20,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: TextField(
                  style: TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search friend circles...',
                    hintStyle: TextStyle(color: Colors.black54),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color.fromARGB(255, 255, 255, 255),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.grey[800]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                  onChanged: (value) {
                    // Add search functionality here
                  },
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.55,
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
                        : InteractiveViewer(
                            onInteractionUpdate: (details) {
                              setState(() {
                                scale = details.scale;
                              });
                              print(details.scale);
                            },
                            maxScale: 10.0,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: FriendCircleLayout(
                                groups: groups,
                                spacing: 10 * scale,
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
                                      child: GroupPrivateViewScreen(),
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
                                      child: PublicProfilePage(
                                          dbIndex: memberData['dbIndex'],
                                          uid: memberId),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
              ),
              ElevatedButton(
                onPressed: () async {
                  String groupName = '';
                  File? logoFile;
                  bool isNameEmpty = false;
                  bool isSubmitted = false;
                  S3Uploader? uploader;

                  String baseurl =
                      AppVariables.get<String>('baseurl')!.trim() ??
                          'http://localhost:3000';
                  ValueNotifier<FileUploadProgress> _progressNotifier =
                      ValueNotifier<FileUploadProgress>(
                    FileUploadProgress(fileName: 'Uploading...'),
                  );
                  uploader = S3Uploader(
                    presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
                    progressNotifier: _progressNotifier,
                  );
                  // Add your create functionality here
                  showDialog(
                    barrierDismissible: false,
                    context: context,
                    builder: (BuildContext context) {
                      return StatefulBuilder(
                          builder: (BuildContext context, setState) {
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
                                // Group Name Input
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Group Name',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
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

                                // Logo Picker
                                isSubmitted
                                    // ignore: dead_code
                                    ? Visibility(
                                        visible: isSubmitted,
                                        child: UploadProgressWidget(
                                            progressNotifier:
                                                _progressNotifier))
                                    : InkWell(
                                        onTap: () async {
                                          final ImagePicker _picker =
                                              ImagePicker();
                                          final XFile? image =
                                              await _picker.pickImage(
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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.blue,
                                            ),
                                          ),
                                          child: logoFile == null
                                              ? Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                          Icons
                                                              .add_photo_alternate,
                                                          size: 40,
                                                          color: Colors.grey),
                                                      SizedBox(height: 8),
                                                      Text('Choose Logo'),
                                                    ],
                                                  ),
                                                )
                                              : ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
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
                            // Cancel Button
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            // Create Button
                            ElevatedButton(
                              onPressed: isSubmitted
                                  ? null
                                  : () async {
                                      if (groupName.length > 0) {
                                        print(groupName);
                                        setState(() {
                                          isNameEmpty = false;
                                          isSubmitted = true;
                                        });
                                        List<String> url =
                                            await uploader!.uploadFiles(files: [
                                          logoFile!
                                        ], compressionParams: {
                                          "width": 100,
                                          "quality": 100,
                                        });
                                        print(url);
                                        Map<String, dynamic> result =
                                            await GroupsService.createGroup(
                                                groupName, url[0]);
                                        print(result);
                                        if (result['success'] == true) {
                                          Navigator.pop(context);
                                          Navigator.push(
                                              context,
                                              PageTransition(
                                                  type: PageTransitionType
                                                      .leftToRight,
                                                  child:
                                                      GroupPrivateViewScreen(),
                                                  duration: Duration(
                                                      milliseconds: 400)));
                                        } else {
                                          _progressNotifier.value =
                                              _progressNotifier.value.copyWith(
                                            stage: UploadStage.failed,
                                            customStageText:
                                                "Error Creating Group",
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
                              child: Text('Create',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      });
                    },
                  );
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
                  // Add skip functionality here
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
                              // Add navigation logic here
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
    );
  }
}
