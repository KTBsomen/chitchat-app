import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/user.dart';
import 'package:chitchat/screens/profilePublic.dart';
import 'package:chitchat/constants/colors.dart';

class CampusMembersScreen extends StatefulWidget {
  final String institutionName;
  const CampusMembersScreen({Key? key, required this.institutionName})
      : super(key: key);

  @override
  _CampusMembersScreenState createState() => _CampusMembersScreenState();
}

class _CampusMembersScreenState extends State<CampusMembersScreen> {
  final List<dynamic> _members = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _fetchMembers();
    }
  }

  Future<void> _fetchMembers({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    if (reset) {
      _page = 1;
      _members.clear();
      _hasMore = true;
    }

    try {
      final token = await UserService.getAccessToken();
      final baseUrl = AppVariables.get<String>('baseurl')!.trim();
      
      final response = await http.get(
        Uri.parse('$baseUrl/campus/members?page=$_page&limit=$_limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> newMembers = data['results'] ?? [];
        setState(() {
          _page++;
          _members.addAll(newMembers);
          if (newMembers.length < _limit) {
            _hasMore = false;
          }
        });
      } else {
        print("Failed to fetch members: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching members: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredMembers {
    if (_searchQuery.isEmpty) return _members;
    final query = _searchQuery.toLowerCase();
    return _members.where((m) {
      final name = (m['name'] ?? "").toString().toLowerCase();
      final username = (m['username'] ?? "").toString().toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.institutionName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: Column(
        children: [
          // Elegant Glassmorphic Search Bar with Neon Border Glow
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontFamily: 'Poppins',
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _members.isEmpty && _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                    ),
                  )
                : _filteredMembers.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'No other members found.'
                              : 'No matches found.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.tealAccent,
                        backgroundColor: const Color(0xFF1E1E2C),
                        onRefresh: () => _fetchMembers(reset: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          itemCount: _filteredMembers.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredMembers.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.tealAccent,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final member = _filteredMembers[index];
                            final String name = member['name'] ?? "Student";
                            final String username = member['username'] ?? "student";
                            final String? pic = member['profilePic'];
                            final String edu = member['educationLevel'] ?? "";
                            final String details =
                                member['semester'] ?? member['courseName'] ?? "";

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.tealAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: const Color(0xFF2A2A3D),
                                    backgroundImage: pic != null && pic.isNotEmpty
                                        ? NetworkImage(pic)
                                        : const NetworkImage(
                                            'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png',
                                          ),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '@$username',
                                      style: TextStyle(
                                        color: Colors.tealAccent.withOpacity(0.8),
                                        fontSize: 13,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    if (edu.isNotEmpty || details.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${edu.toUpperCase()} ${details.isNotEmpty ? "• $details" : ""}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.tealAccent,
                                  size: 24,
                                ),
                                onTap: () {
                                  final String? uid = member['_id'];
                                  final dynamic dbIndex = member['dbIndex'];
                                  if (uid != null && dbIndex != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PublicProfilePage(
                                          dbIndex: dbIndex.toString(),
                                          uid: uid,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
