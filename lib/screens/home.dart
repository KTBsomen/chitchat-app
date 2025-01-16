import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/profilePrivet.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/screens/register.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:page_transition/page_transition.dart';
import 'profilePublic.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final List<String> _feedItems = List.generate(
    10,
    (index) =>
        "https://picsum.photos/${300 + (index % 3) * 100}/${400 + (index % 2) * 100}",
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    AppVariables.registerState(this);
    AppVariables.set("selectedTabIndex", 0);
  }

  int? _selectedIndex = AppVariables.get<int>("selectedTabIndex");

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);

      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _feedItems.addAll(
          List.generate(
            5,
            (index) =>
                "https://picsum.photos/500/${600 + _feedItems.length + index}",
          ),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        cardColor: const Color(0xFF1E1E1E),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.background,
          selectedItemColor: Color.fromARGB(255, 85, 0, 150),
          unselectedItemColor: Colors.grey,
        ),
      ),
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(),
            _buildStories(),
            _buildFeed(),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
        floatingActionButton: Container(
          height: 65,
          width: 65,
          margin: const EdgeInsets.only(top: 0),
          child: FloatingActionButton(
            backgroundColor: Colors.blue,
            elevation: 8,
            onPressed: () {
              UserService.signOut(
                (p0) {},
              ).then(
                (value) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    PageTransition(
                      child: LoginScreen(),
                      type: PageTransitionType.fade,
                    ),
                    (route) => false,
                  );
                },
              );
            },
            child: const Icon(
              Icons.camera_alt_rounded,
              size: 35,
            ),
            shape: const CircleBorder(),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        notchMargin: 10,
        shape: const CircularNotchedRectangle(),
        color: AppColors.Secondarybackground,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 0, onPressed: () {
              AppVariables.update("selectedTabIndex", 0);
              print(AppVariables.get<int>("selectedTabIndex"));
            }),
            _buildNavItem(Icons.search_rounded, 1, onPressed: () {
              AppVariables.update("selectedTabIndex", 1);
              print(AppVariables.get<int>("selectedTabIndex"));
              Navigator.push(
                context,
                PageTransition(
                  isIos: true,
                  type: PageTransitionType.rightToLeft,
                  child: RegistrationScreen(),
                  curve: Curves.fastEaseInToSlowEaseOut,
                  duration: const Duration(milliseconds: 500),
                ),
              );
            }),
            const SizedBox(width: 30),
            _buildNavItem(Icons.favorite_rounded, 2, onPressed: () {
              AppVariables.update("selectedTabIndex", 2);
              print(AppVariables.get<int>("selectedTabIndex"));
              Navigator.push(
                context,
                PageTransition(
                  isIos: true,
                  type: PageTransitionType.rightToLeft,
                  child: Recomandedgroups(),
                  curve: Curves.fastEaseInToSlowEaseOut,
                  duration: const Duration(milliseconds: 500),
                ),
              );
            }),
            _buildNavItem(Icons.groups, 3, onPressed: () {
              Navigator.push(
                context,
                PageTransition(
                  isIos: true,
                  type: PageTransitionType.rightToLeft,
                  child: PrivetProfilePage(),
                  curve: Curves.fastEaseInToSlowEaseOut,
                  duration: const Duration(milliseconds: 500),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, {Function()? onPressed}) {
    bool isSelected = AppVariables.get<int>("selectedTabIndex") == index;

    return IconButton(
      icon: Icon(
        icon,
        size: 30,
      ),
      onPressed: onPressed,
      color: isSelected ? AppColors.warning : Colors.white,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      elevation: 9,
      floating: true,
      backgroundColor: AppColors.background,
      title: const Text(
        "chitchat",
        style: TextStyle(
          fontFamily: "Poppins",
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () {},
              color: Colors.white,
              iconSize: 30,
              padding: const EdgeInsets.only(right: 20),
            ),
            Positioned(
              right: 20,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.messenger_outline_rounded),
              onPressed: () {},
              color: Colors.white,
              iconSize: 30,
              padding: const EdgeInsets.only(right: 30),
            ),
            Positioned(
              right: 25,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStories() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          left: 5,
        ),
        child: SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            itemBuilder: (context, index) => _StoryItem(index: index),
          ),
        ),
      ),
    );
  }

  Widget _buildFeed() {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemBuilder: (context, index) {
          return _FeedItem(
            imageUrl: _feedItems[index],
            onTap: () => _showPost(context),
          );
        },
        childCount: _feedItems.length,
      ),
    );
  }

  void _showPost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PostDetails(),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _StoryItem extends StatelessWidget {
  final int index;

  const _StoryItem({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 198, 101, 10),
                  Color.fromARGB(255, 255, 179, 0),
                  Color.fromARGB(255, 96, 4, 194)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                shape: BoxShape.circle,
              ),
              child: CachedNetworkImage(
                imageUrl: "https://picsum.photos/200/${200 + index}",
                imageBuilder: (context, imageProvider) => CircleAvatar(
                  radius: 35,
                  backgroundImage: imageProvider,
                ),
                placeholder: (context, url) => const CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0xFF2A2A2A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "User $index",
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const _FeedItem({
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: "$imageUrl?${DateTime.now()}",
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            children: [
              CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                        height: 200,
                        color: const Color(0xFF2A2A2A),
                      ),
                  errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: const Color(0xFF2A2A2A),
                      child: const Center(
                        child: Icon(Icons.error),
                      ))),
              const Positioned(
                  top: 5,
                  left: 5,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 15, color: Colors.grey),
                      ),
                      const SizedBox(width: 10),
                      Text('Image 2', style: TextStyle(fontSize: 12)),
                    ],
                  ))
            ],
          ),
        ),
      ),
    );
  }
}

class PostDetails extends StatelessWidget {
  const PostDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Add your post details content here
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
