// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/components/searchBar.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/groupPrivet.dart';
import 'package:chitchat/screens/groupPublic.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/screens/searchResults.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';

class SearchPage extends StatefulWidget {
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<FriendCircleGroup> groups = [];
  List<Map<String, dynamic>> searchResultUsers = [];
  List<Map<String, dynamic>> searchResultColleges = [];
  List<Map<String, dynamic>> searchResultUniversities = [];
  List<Map<String, dynamic>> topUniversities = [
    {
      "_id": "674dc00e8cefe7ce6e00c3d4",
      "Name of the University": "COER University, Roorkee",
      "Address": "7KM. on Roorkee -Haridwar Road, Vardhmanpuram, Roorkee",
      "Zip": "247667",
      "State": "Uttarakhand"
    },
    {
      "_id": "674dc00e8cefe7ce6e00c64e",
      "Name of the University":
          "Rani Rashmoni Green University(formerly West Bengal Green University.)",
      "Address":
          "At the premises of Singur General Degree College, Singur, Hooghly, West Bengal",
      "Zip": "712409",
      "state": "West Bengal"
    },
    {
      "_id": "674dc00e8cefe7ce6e00c31f",
      "Name of the University": "Amity University",
      "Address": "Rajarhat,  New Town,  Dist. North 24 Parganas",
      "Zip": "700135",
      "State": "West Bengal"
    },
    {
      "_id": "674dc00f8cefe7ce6e00c792",
      "Name of the University": "Woxsen University",
      "Address": "Woxsen Campus, Kamkole, Sadasivpet, Medak District",
      "State": "Telangana"
    },
    {
      "_id": "674dc00e8cefe7ce6e00c430",
      "Name of the University": "Flame University",
      "Address": "GAT No. 1270Village LavaleTaluka Mulshi, Pune",
      "Zip": "411042",
      "state": "Maharashtra"
    },
    {
      "_id": "674dc00e8cefe7ce6e00c397",
      "Name of the University": "Calcutta University",
      "Address": "Calcutta University, College Square, Kolkata",
      "Zip": "700073",
      "state": "West Bengal"
    },
    {
      "_id": "674dc00f8cefe7ce6e00c70b",
      "Name of the University": "Symbiosis International University",
      "Address": "Gram: Lavale, Taluka: Mulshi, District: Pune",
      "Zip": "412115",
      "state": "Maharashtra"
    }
  ];
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

  _getByName() async {
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

  String selectedType = "University";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            SizedBox(
              height: 50,
            ),
            Text(
              "Search Your Friend Circle",
              style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(
              height: 20,
            ),
            ImprovedSearchBar(
              onLoading: (p0) {
                setState(() {
                  isLoading = p0;
                });
              },
              onSelectedType: (p0) {
                setState(() {
                  selectedType = p0;
                });
              },
              onGroupSearchResult: (ResultGroups) {
                setState(() {
                  groups = ResultGroups;
                });
              },
              onCollegeSearchResult: (p0) {
                setState(() {
                  searchResultColleges = p0;
                });
              },
              onUniversitySearchResult: (p0) {
                setState(() {
                  searchResultUniversities = p0;
                });
              },
              onUserSearchResult: (p0) {
                if (mounted) {
                  setState(() {
                    searchResultUsers = p0;
                  });
                }
              },
              debounceDuration: Duration(milliseconds: 800),
            ),
            SizedBox(
              height: 10,
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.75,
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
                        : Column(
                            children: selectedType == "Name"
                                ? _searchUsers()
                                : selectedType == "University"
                                    ? _searchUniversities()
                                    : selectedType == "College"
                                        ? _searchColleges()
                                        : _recomandedFC(),
                          ),
              ),
            ),
            // ElevatedButton(
            //   onPressed: () async {
            //     String groupName = '';
            //     File? logoFile;
            //     bool isNameEmpty = false;
            //     bool isSubmitted = false;
            //     S3Uploader? uploader;

            //     String baseurl =
            //         AppVariables.get<String>('baseurl')!.trim() ??
            //             'http://localhost:3000';
            //     ValueNotifier<FileUploadProgress> _progressNotifier =
            //         ValueNotifier<FileUploadProgress>(
            //       FileUploadProgress(fileName: 'Uploading...'),
            //     );
            //     uploader = S3Uploader(
            //       presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
            //       progressNotifier: _progressNotifier,
            //     );
            //     // Add your create functionality here
            //     showDialog(
            //       barrierDismissible: false,
            //       context: context,
            //       builder: (BuildContext context) {
            //         return StatefulBuilder(
            //             builder: (BuildContext context, setState) {
            //           return AlertDialog(
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(16),
            //             ),
            //             title: Row(
            //               children: [
            //                 Icon(Icons.group_add, color: Colors.blue),
            //                 SizedBox(width: 8),
            //                 Text(
            //                   'Create New Group',
            //                   style: TextStyle(
            //                       fontSize: 18,
            //                       color: AppColors.background,
            //                       fontWeight: FontWeight.bold,
            //                       fontFamily: 'Poppins'),
            //                 ),
            //               ],
            //             ),
            //             content: SingleChildScrollView(
            //               child: Column(
            //                 mainAxisSize: MainAxisSize.min,
            //                 children: [
            //                   // Group Name Input
            //                   Column(
            //                     mainAxisAlignment: MainAxisAlignment.start,
            //                     crossAxisAlignment: CrossAxisAlignment.start,
            //                     children: [
            //                       TextField(
            //                         decoration: InputDecoration(
            //                           labelText: 'Group Name',
            //                           border: OutlineInputBorder(
            //                             borderRadius:
            //                                 BorderRadius.circular(12),
            //                           ),
            //                           prefixIcon: Icon(Icons.group),
            //                         ),
            //                         onChanged: (value) {
            //                           setState(() {
            //                             groupName = value;
            //                             isNameEmpty = false;
            //                           });
            //                         },
            //                       ),
            //                       Visibility(
            //                         visible: isNameEmpty,
            //                         child: Text(
            //                           "Group Name must be filled",
            //                           style: TextStyle(color: Colors.red),
            //                         ),
            //                       ),
            //                     ],
            //                   ),
            //                   SizedBox(height: 20),

            //                   // Logo Picker
            //                   isSubmitted
            //                       // ignore: dead_code
            //                       ? Visibility(
            //                           visible: isSubmitted,
            //                           child: UploadProgressWidget(
            //                               progressNotifier:
            //                                   _progressNotifier))
            //                       : InkWell(
            //                           onTap: () async {
            //                             final ImagePicker _picker =
            //                                 ImagePicker();
            //                             final XFile? image =
            //                                 await _picker.pickImage(
            //                               source: ImageSource.gallery,
            //                             );
            //                             if (image != null) {
            //                               logoFile = File(image.path);
            //                               setState(() {});
            //                             }
            //                           },
            //                           child: Container(
            //                             height: 100,
            //                             width: double.infinity,
            //                             decoration: BoxDecoration(
            //                               color: Colors.grey[200],
            //                               borderRadius:
            //                                   BorderRadius.circular(12),
            //                               border: Border.all(
            //                                 color: Colors.blue,
            //                               ),
            //                             ),
            //                             child: logoFile == null
            //                                 ? Center(
            //                                     child: Column(
            //                                       mainAxisAlignment:
            //                                           MainAxisAlignment
            //                                               .center,
            //                                       children: [
            //                                         Icon(
            //                                             Icons
            //                                                 .add_photo_alternate,
            //                                             size: 40,
            //                                             color: Colors.grey),
            //                                         SizedBox(height: 8),
            //                                         Text('Choose Logo'),
            //                                       ],
            //                                     ),
            //                                   )
            //                                 : ClipRRect(
            //                                     borderRadius:
            //                                         BorderRadius.circular(12),
            //                                     child: Image.file(
            //                                       logoFile!,
            //                                       fit: BoxFit.fitHeight,
            //                                     ),
            //                                   ),
            //                           ),
            //                         ),
            //                 ],
            //               ),
            //             ),
            //             actionsPadding:
            //                 EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //             actions: [
            //               // Cancel Button
            //               TextButton(
            //                 onPressed: () {
            //                   Navigator.of(context).pop();
            //                 },
            //                 child: Text(
            //                   'Cancel',
            //                   style: TextStyle(color: Colors.grey),
            //                 ),
            //               ),
            //               // Create Button
            //               ElevatedButton(
            //                 onPressed: isSubmitted
            //                     ? null
            //                     : () async {
            //                         if (groupName.length > 0) {
            //                           print(groupName);
            //                           setState(() {
            //                             isNameEmpty = false;
            //                             isSubmitted = true;
            //                           });
            //                           List<String> url =
            //                               await uploader!.uploadFiles(files: [
            //                             logoFile!
            //                           ], compressionParams: {
            //                             "width": 100,
            //                             "quality": 100,
            //                           });
            //                           print(url);
            //                           Map<String, dynamic> result =
            //                               await GroupsService.createGroup(
            //                                   groupName, url[0]);
            //                           print(result);
            //                           if (result['success'] == true) {
            //                             Navigator.pop(context);
            //                             Navigator.push(
            //                                 context,
            //                                 PageTransition(
            //                                     type: PageTransitionType
            //                                         .leftToRight,
            //                                     child:
            //                                         GroupPrivateViewScreen(),
            //                                     duration: Duration(
            //                                         milliseconds: 400)));
            //                           } else {
            //                             _progressNotifier.value =
            //                                 _progressNotifier.value.copyWith(
            //                               stage: UploadStage.failed,
            //                               customStageText:
            //                                   "Error Creating Group",
            //                               customStageTextDetail:
            //                                   "Only one group can be created at a time",
            //                               errorMessage: result['error'],
            //                             );
            //                           }
            //                         } else {
            //                           setState(() {
            //                             isNameEmpty = true;
            //                           });
            //                         }
            //                       },
            //                 style: ElevatedButton.styleFrom(
            //                   backgroundColor: Colors.blue,
            //                   shape: RoundedRectangleBorder(
            //                     borderRadius: BorderRadius.circular(12),
            //                   ),
            //                 ),
            //                 child: Text('Create',
            //                     style: TextStyle(color: Colors.white)),
            //               ),
            //             ],
            //           );
            //         });
            //       },
            //     );
            //   },
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.blue,
            //     padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(16),
            //     ),
            //   ),
            //   child: Text(
            //     'Create Your Own',
            //     style: TextStyle(
            //       fontSize: 18,
            //       fontFamily: 'Poppins',
            //       fontWeight: FontWeight.bold,
            //       color: Colors.white,
            //     ),
            //   ),
            // ),
            // InkWell(
            //   onTap: () {
            //     // Add skip functionality here
            //     showDialog(
            //       context: context,
            //       builder: (BuildContext context) {
            //         return AlertDialog(
            //           title: Text(
            //             'Skip Group Creation',
            //             style: TextStyle(
            //               fontFamily: 'Poppins',
            //               fontWeight: FontWeight.bold,
            //             ),
            //           ),
            //           content: Text(
            //             'You cannot do anything in this app until you create or join one group.',
            //             style: TextStyle(
            //               fontFamily: 'Poppins',
            //             ),
            //           ),
            //           actions: [
            //             TextButton(
            //               onPressed: () {
            //                 Navigator.of(context).pop();
            //               },
            //               child: Text(
            //                 'Cancel',
            //                 style: TextStyle(
            //                   color: Colors.grey[600],
            //                   fontFamily: 'Poppins',
            //                 ),
            //               ),
            //             ),
            //             TextButton(
            //               onPressed: () {
            //                 Navigator.push(
            //                     context,
            //                     PageTransition(
            //                         type: PageTransitionType.leftToRight,
            //                         child: HomePage(),
            //                         duration: Duration(milliseconds: 400)));
            //                 // Add navigation logic here
            //               },
            //               child: Text(
            //                 'Skip',
            //                 style: TextStyle(
            //                   color: Colors.blue,
            //                   fontFamily: 'Poppins',
            //                   fontWeight: FontWeight.bold,
            //                 ),
            //               ),
            //             ),
            //           ],
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(12),
            //           ),
            //         );
            //       },
            //     );
            //   },
            //   child: Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Text(
            //       'Skip >',
            //       style: TextStyle(
            //         fontSize: 16,
            //         fontFamily: 'Poppins',
            //         fontWeight: FontWeight.bold,
            //         color: Colors.grey[600],
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  List<Widget> _recomandedFC() {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(
            height: 10,
          ),
          Text(
            "Recommended Friend Circles",
            textAlign: TextAlign.left,
            style: TextStyle(
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          SizedBox(
            height: 10,
            child: Divider(),
          ),
        ],
      ),
      Expanded(
        child: InteractiveViewer(
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
                  color: const Color.fromARGB(255, 189, 190, 190),
                  width: 6,
                  outerGlow: 3.0,
                  outerGlowColor: Colors.blue.withOpacity(0.3),
                  cornerRadius: 100.0,
                  gradientColors: [
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                  ]),
              onGroupTap: (groupId, groupData) {
                print('Group $groupId tapped with data: $groupData');
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
                    child: PublicProfilePage(
                        dbIndex: memberData['dbIndex'], uid: memberId),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _searchUsers() {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 10,
          ),
          Text(
            "${searchResultUsers.length} Users Found",
            textAlign: TextAlign.left,
            style: TextStyle(
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          SizedBox(
            height: 10,
            child: Divider(),
          ),
        ],
      ),
      Expanded(
          child: ListView.builder(
        itemCount: searchResultUsers.length,
        itemBuilder: (context, index) {
          final user = searchResultUsers[index];
          return Card(
            color: Colors.transparent,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(user['profilePic'] ?? ''),
                radius: 25,
              ),
              title: Text(
                user['name'] ?? 'Unknown',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user['bio'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              final bioList = user?['bio'] ?? [];
                              return AlertDialog(
                                backgroundColor: AppColors.background,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                title: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: AppColors.textSecondary),
                                    SizedBox(width: 8),
                                    Text('Bio History',
                                        style: TextStyle(
                                            fontFamily: "Poppins",
                                            color: AppColors.primary)),
                                  ],
                                ),
                                content: bioList.isEmpty
                                    ? Text("No bio available.",
                                        style: TextStyle(
                                            fontFamily: "Poppins",
                                            color: AppColors.success))
                                    : SizedBox(
                                        width: double.maxFinite,
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: bioList.length,
                                          separatorBuilder: (_, __) =>
                                              Divider(),
                                          itemBuilder: (context, idx) {
                                            final bioObj =
                                                GroupsService.parseBio(
                                                    bioList[idx]);
                                            return ListTile(
                                              title: Text(
                                                bioObj.bio ?? "No bio",
                                                style: TextStyle(
                                                    fontFamily: "Poppins",
                                                    color: Colors.white),
                                              ),
                                              subtitle: Text(
                                                "Edited by: ${bioObj.editedBy ?? 'Unknown'}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                  fontFamily: "Poppins",
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                actions: [
                                  TextButton(
                                    child: Text('Close',
                                        style: TextStyle(
                                            fontFamily: "Poppins",
                                            color: AppColors.primary)),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: Text(
                          user?['bio'].length > 0 &&
                                  !(user?['bio'] as List).contains(null)
                              ? "#${GroupsService.parseBio(user?['bio'].last).editedBy ?? ''} ${GroupsService.parseBio(user?['bio'].last).bio}"
                              : 'No bio available',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontFamily: "Poppins"),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  if (user['university'] != null)
                    Text(
                      'University: ${user['university']}',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: Colors.white70),
                    ),
                  if (user['college'] != null)
                    Text(
                      'College: ${user['college']}',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: Colors.white70),
                    ),
                  if (user['school'] != null)
                    Text(
                      'School: ${user['school']}',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: Colors.white70),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeft,
                    child: PublicProfilePage(
                        dbIndex: user['dbIndex'].toString(), uid: user['id']),
                  ),
                );
              },
            ),
          );
        },
      )),
    ];
  }

  List<Widget> _searchUniversities() {
    return searchResultUniversities.isEmpty
        ? [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 10,
                ),
                Text(
                  "Top Universities",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(
                  height: 10,
                  child: Divider(),
                ),
              ],
            ),
            Expanded(
                child: ListView.builder(
              itemCount: topUniversities.length,
              itemBuilder: (context, index) {
                final user = topUniversities[index];
                return Card(
                  color: Colors.transparent,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      user['Name of the University'] ?? 'Unknown',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user['Address'] != null)
                          Text(
                            'Address: ${user['Address']}',
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Poppins',
                                color: Colors.white70),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: SearchResultsPage(
                            name: user['Name of the University'],
                            type: "University",
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            )),
          ]
        : [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 10,
                ),
                Text(
                  "${searchResultUniversities.length} Universities Found",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                SizedBox(
                  height: 10,
                  child: Divider(),
                ),
              ],
            ),
            Expanded(
                child: ListView.builder(
              itemCount: searchResultUniversities.length,
              itemBuilder: (context, index) {
                final user = searchResultUniversities[index];
                return Card(
                  color: Colors.transparent,
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      user['Name of the University'] ?? 'Unknown',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user['Address'] != null)
                          Text(
                            'Address: ${user['Address']}',
                            style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Poppins',
                                color: Colors.white70),
                          ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: SearchResultsPage(
                            name: user['Name of the University'],
                            type: "University",
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            )),
          ];
  }

  List<Widget> _searchColleges() {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 10,
          ),
          Text(
            "${searchResultColleges.length} Colleges Found",
            textAlign: TextAlign.left,
            style: TextStyle(
                fontSize: 15,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          SizedBox(
            height: 10,
            child: Divider(),
          ),
        ],
      ),
      Expanded(
          child: ListView.builder(
        itemCount: searchResultColleges.length,
        itemBuilder: (context, index) {
          final user = searchResultColleges[index];
          return Card(
            color: Colors.transparent,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                user['Name of the college'] ?? 'Unknown',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: Colors.white),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user['Affiliated To University'] != null)
                    Text(
                      'Affiliated To University: ${user['Affiliated To University']}',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: Colors.white70),
                    ),
                  if (user['College address'] != null)
                    Text(
                      'College address: ${user['College address']}',
                      style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Poppins',
                          color: Colors.white70),
                    ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  PageTransition(
                    type: PageTransitionType.rightToLeft,
                    child: SearchResultsPage(
                      name: user['Name of the college'],
                      type: "College",
                    ),
                  ),
                );
              },
            ),
          );
        },
      )),
    ];
  }
}
