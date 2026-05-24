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
    try {
      PaginatedGroupResult result =
          await GroupsService.getRecommendedGroups();
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
              SizedBox(
                height: 20,
              ),
              // Padding(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              //   child: TextField(
              //     style: TextStyle(color: Colors.black),
              //     decoration: InputDecoration(
              //       hintText: 'Search friend circles...',
              //       hintStyle: TextStyle(color: Colors.black54),
              //       prefixIcon: Icon(Icons.search, color: Colors.grey),
              //       filled: true,
              //       fillColor: const Color.fromARGB(255, 255, 255, 255),
              //       enabledBorder: OutlineInputBorder(
              //         borderRadius: BorderRadius.circular(30),
              //         borderSide: BorderSide(color: Colors.grey[800]!),
              //       ),
              //       focusedBorder: OutlineInputBorder(
              //         borderRadius: BorderRadius.circular(30),
              //         borderSide: BorderSide(color: Colors.blue),
              //       ),
              //     ),
              //     onChanged: (value) {
              //       // Add search functionality here
              //     },
              //   ),
              // ),
              SizedBox(
                height: 10,
              ),
              Container(
                width: double.infinity,
                height:
                    widget.height ?? MediaQuery.of(context).size.height * 0.45,
                // margin: EdgeInsets.only(left: 15, right: 15),
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
                              padding: const EdgeInsets.all(2),
                              child: FriendCircleLayout(
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
                                  // Navigator.push(
                                  //   context,
                                  //   PageTransition(
                                  //     type: PageTransitionType.rightToLeft,
                                  //     child: PublicProfilePage(
                                  //         dbIndex:
                                  //             memberData['dbIndex'].toString(),
                                  //         uid: memberId),
                                  //   ),
                                  // );
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
