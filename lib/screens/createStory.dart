import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/services/upload_chit_service.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';

class MemberSelectionPage extends StatefulWidget {
  final List<String> files;
  MemberSelectionPage({
    Key? key,
    required this.files,
  });

  @override
  State<MemberSelectionPage> createState() => _MemberSelectionPageState();
}

class _MemberSelectionPageState extends State<MemberSelectionPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String myGroupId = '';
  String _errorMessage = '';
  List<Member> _members = [];
  Set<String> _selectedMemberIds = {};
  bool AllSelected = false;

  static String baseUrl =
      AppVariables.get<String>('baseurl')?.trim() ?? 'http://localhost:3000';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    String? userId = await UserService.getUserId();
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'User ID is null';
        });
      }
      return;
    }
    String? xtoken = await UserService.getAccessToken();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chits/members/$userId'),
        headers: {'Authorization': 'Bearer $xtoken'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final membersList = (jsonData['usersOwnGroupMembers']?['myGroup']
                ?['members'] as List?) ??
            [];
        final watchListResults = jsonData['membersOfUserWatchList']?['results'];
        final watchList =
            (watchListResults != null && watchListResults.isNotEmpty)
                ? (watchListResults[0]?['members'] as List?) ?? []
                : [];

        // Remove duplicate members by ID
        final uniqueMembers = <String, Member>{};

        for (var memberData in [...membersList, ...watchList]) {
          final memberId = memberData['memberId'];
          if (memberId != null) {
            final member = Member(
              id: memberId,
              name: memberData['memberName'] ?? 'Unknown',
              profilePic: memberData['memberProfilePic'] ?? '',
            );
            uniqueMembers[member.id] = member;
          }
        }

        if (mounted) {
          setState(() {
            _members = uniqueMembers.values.toList();
            myGroupId =
                (jsonData['usersOwnGroupMembers']?['myGroup']?["_id"]) ?? '';
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load members: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _toggleMemberSelection(String memberId) {
    setState(() {
      if (_selectedMemberIds.contains(memberId)) {
        _selectedMemberIds.remove(memberId);
      } else {
        _selectedMemberIds.add(memberId);
      }
    });
  }

  Future<void> _submitSelection() async {
    if (_selectedMemberIds.isEmpty && !AllSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (widget.files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Use the upload service
    UploadChitService.upload(
      context: context,
      filePaths: widget.files,
      type: ChitType.story,
      members: _selectedMemberIds.toList(),
      sendToAll: AllSelected,
      groupId: myGroupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: AppColors.background,
        title: const Text(
          'Select Members',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Checkbox(
                  activeColor: Colors.green,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  value: _members.isNotEmpty && _selectedMemberIds.length == _members.length,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedMemberIds =
                            _members.map((member) => member.id).toSet();
                        AllSelected = true;
                      } else {
                        _selectedMemberIds.clear();
                        AllSelected = false;
                      }
                    });
                  },
                ),
                Center(
                  child: _selectedMemberIds.length != _members.length
                      ? const Text(
                          "Send to All",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'All selected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageTransition(
                  type: PageTransitionType.leftToRight,
                  child: ChatScreen(data: widget.files),
                ),
              );
            },
            child: const Card(
              margin: EdgeInsets.all(16.0),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.group, size: 24),
                    SizedBox(width: 16),
                    Text(
                      'Send to Group',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(fontSize: 14, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (myGroupId.isEmpty) ...[
              ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        PageTransition(
                            type: PageTransitionType.leftToRight,
                            child: Recomandedgroups()));
                  },
                  child: const Text(
                    "Create or Join A Group 🚀",
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  )),
              const SizedBox(
                height: 20,
              ),
              const Text(
                'Or',
                style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(
                height: 20,
              ),
            ],
            ElevatedButton(
              onPressed: _fetchMembers,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return const Center(
        child: Text(
          'No members found in your group',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final isSelected = _selectedMemberIds.contains(member.id);

        return _buildMemberCard(member, isSelected);
      },
    );
  }

  Widget _buildMemberCard(Member member, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleMemberSelection(member.id),
      child: Card(
        elevation: isSelected ? 6 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(40),
          side: BorderSide(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    child: Image.network(
                      member.profilePic,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.person,
                            size: 64,
                            color: Colors.grey,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _submitSelection,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedMemberIds.length == 1
                ? Colors.green
                : _selectedMemberIds.length > 1 && !AllSelected
                    ? Colors.yellowAccent
                    : AllSelected
                        ? Colors.red
                        : Colors.grey,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            AllSelected
                ? "Send to All 🚀"
                : 'Continue with ${_selectedMemberIds.length} selected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedMemberIds.length > 1 && !AllSelected
                  ? Colors.black
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class Member {
  final String id;
  final String name;
  final String profilePic;

  Member({
    required this.id,
    required this.name,
    required this.profilePic,
  });
}
