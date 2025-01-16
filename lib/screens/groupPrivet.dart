import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

class GroupPrivateViewScreen extends StatefulWidget {
  @override
  _GroupPrivateViewScreenState createState() => _GroupPrivateViewScreenState();
}

class _GroupPrivateViewScreenState extends State<GroupPrivateViewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> posts = List.generate(
    100,
    (index) =>
        "https://picsum.photos/${300 + (index % 3) * 100}/${400 + (index % 2) * 100}",
  );
  final Map<String, bool> likeStatus = {};
  final Map<String, int> likeCountForMember = {};
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');
  FriendCircleGroup? groupDetails;

  int selectedTab = 0;
  @override
  void initState() {
    super.initState();
    print(profileDetails);
    groupDetails =
        GroupsService.buildFriendCircleGroup(profileDetails!['myGroup']);
    _getUserLikes();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        selectedTab = _tabController.index;
      });
    });
  }

  void _getUserLikes() async {
    List<String>? ids =
        groupDetails?.members.map((member) => member.id).toList();
    Map<String, dynamic> result =
        await UserService.fetchUserLikes(ids: ids!, invalidate: false);
    if (result['success']) {
      for (var user in result['data']) {
        likeCountForMember[user['_id']] = user['likes'];
      }
    }
    setState(() {});
    AppVariables.setPersistent<Map<String, int>>(
        'likeCountForMember', likeCountForMember);
    print(likeCountForMember);
  }

  void toggleLike(String userid, {bool internal = false}) async {
    print(await AppVariables.getPersistent<Map<String, dynamic>>(
        'likeCountForMember'));
    setState(() {
      likeStatus[userid] = !(likeStatus[userid] ?? false);
      int? user = likeCountForMember[userid];
      likeCountForMember[userid] = user! + (likeStatus[userid]! ? 1 : -1);
      //+= likeStatus[userid]! ? 1 : -1;
    });
    if (internal == false) {
      Map<String, dynamic> result = await UserService.likeUser(userId: userid);
      if (result['success']) {
        print(result['data']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'])),
        );
        toggleLike(userid, internal: true);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 12, 12, 38),
      appBar: AppBar(
        leading: null,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 3,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(
                  groupDetails?.groupData['GroupProfilePic']),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                groupDetails?.groupData['name'],
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(left: 20, right: 20),
            child: Stack(
              children: [
                Icon(Icons.notifications, color: Colors.white),
                Positioned(
                  right: 0,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.red,
                    child: const Text(
                      '3',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Top Container for Group Members
          Container(
            padding: const EdgeInsets.all(8),
            height: MediaQuery.of(context).size.height * 0.4,
            child: ListView.builder(
              itemCount: groupDetails!.members.length,
              itemBuilder: (context, index) {
                final member = groupDetails!.members[index];
                print(
                    'Member ${member.id}: ${member.avatarUrl} ${member.additionalData['memberName']}');
                return ListTile(
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(member.avatarUrl),
                  ),
                  title: Text(
                    member.additionalData['memberName'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    member.additionalData['memberBio'] ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => toggleLike(member.id),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          likeStatus[member.id] == true
                              ? const Icon(Icons.favorite, color: Colors.red)
                              : const Icon(Icons.favorite_border_outlined,
                                  color: Colors.white),
                          const SizedBox(width: 4),
                          likeCountForMember[member.id] != null
                              ? Text(
                                  '${likeCountForMember[member.id] ?? 0}',
                                  style: const TextStyle(color: Colors.white),
                                )
                              : SizedBox(
                                  width: 20,
                                  height: 10,
                                  child: Shimmer.fromColors(
                                    direction: ShimmerDirection.ttb,
                                    baseColor: AppColors.background,
                                    highlightColor: const Color.fromARGB(
                                        255, 200, 200, 200)!,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        color: AppColors.gradientStart,
                                      ),
                                      width: 20,
                                      height: 10,
                                    ),
                                  ),
                                )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // DraggableScrollableSheet
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: Column(
                  children: [
                    // TabBar for Chat and Posts
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width * 0.6,
                            decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 255, 255, 255),
                                border:
                                    Border.all(color: Colors.grey, width: 0.5),
                                borderRadius:
                                    BorderRadius.all(Radius.circular(50)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 5,
                                    offset: const Offset(0, 3),
                                  ),
                                ]),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    _tabController.animateTo(0);
                                    setState(() {
                                      selectedTab = 0;
                                    });
                                  },
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.3,
                                    height: 50,
                                    decoration: selectedTab == 0
                                        ? BoxDecoration(
                                            color: const Color.fromARGB(
                                                255, 0, 46, 124),
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(50),
                                              bottomLeft: Radius.circular(50),
                                              topRight: Radius.circular(50),
                                            ))
                                        : null,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Text(
                                            'posts',
                                            style: TextStyle(
                                              color: selectedTab == 0
                                                  ? Colors.blue
                                                  : Colors.grey,
                                              fontSize: 13,
                                              fontFamily: "Poppins",
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    _tabController.animateTo(1);
                                    setState(() {
                                      selectedTab = 1;
                                    });
                                  },
                                  child: Container(
                                    width: MediaQuery.of(context).size.width *
                                            0.3 -
                                        1,
                                    height: 50,
                                    decoration: selectedTab == 1
                                        ? BoxDecoration(
                                            color: const Color.fromARGB(
                                                255, 0, 46, 124),
                                            borderRadius: BorderRadius.only(
                                              topRight: Radius.circular(50),
                                              bottomRight: Radius.circular(50),
                                              topLeft: Radius.circular(50),
                                            ))
                                        : null,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Text(
                                            'memories',
                                            style: TextStyle(
                                              color: selectedTab == 1
                                                  ? Colors.blue
                                                  : Colors.grey,
                                              fontSize: 13,
                                              fontFamily: "Poppins",
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 46, 124),
                                  child: IconButton(
                                    icon: Icon(Icons.chat, color: Colors.white),
                                    onPressed: () {
                                      // Handle search button press
                                    },
                                  ),
                                ),
                                SizedBox(width: 10),
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 46, 124),
                                  child: IconButton(
                                    icon: Icon(Icons.add_a_photo_sharp,
                                        color: Colors.white),
                                    onPressed: () {
                                      // Handle search button press
                                    },
                                  ),
                                ),
                              ]),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Chat View
                            MasonryGridView.builder(
                              controller: scrollController,
                              gridDelegate:
                                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    posts[index],
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),

                            // Posts View (Masonry Grid)
                            MasonryGridView.builder(
                              controller: scrollController,
                              gridDelegate:
                                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    posts[index],
                                    fit: BoxFit.cover,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
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
}

// Mockup of Group Edit Page
class GroupEditPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Group Details"),
      ),
      body: const Center(
        child: Text("Group Edit Page"),
      ),
    );
  }
}
