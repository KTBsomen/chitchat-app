import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/story.dart';
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
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  // static String? xtoken =
  //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3ZGRiOWRmOWQ1OTE0ZDYwOGEyODk4ZSIsInVzZXJJZCI6IjY3ZGRiOWRmOWQ1OTE0ZDYwOGEyODk4ZSIsImVtYWlsIjoiYWlzaHdhcnlhXzEzN0BleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy93b21lbi80My5qcGc_bmF0PWluIiwibmFtZSI6IkFpc2h3YXJ5YSIsInVzZXJuYW1lIjoiYWlzaHdhcnlhXzEzNyIsImJpbyI6IkhpLCBJJ20gQWlzaHdhcnlhLiBFeGNpdGVkIHRvIGNvbm5lY3QhIiwiZWR1Y2F0aW9uTGV2ZWwiOiJVbml2ZXJzaXR5IiwidW5pdmVyc2l0eSI6IkRlbGhpIFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGFuc3JhaiBDb2xsZWdlIiwic2Nob29sIjoiTmF2b2RheWEgVmlkeWFsYXlhIiwic2VtZXN0ZXIiOiJTZW0gMyIsInVzZXJDbGFzcyI6bnVsbCwieWVhciI6bnVsbCwiYmlydGhkYXkiOiIyMDA5LTAyLTA4VDE4OjMwOjAwLjAwMFoiLCJkYkluZGV4IjowLCJpYXQiOjE3NDI1ODQyODd9.Y8L0Pz-UtrXzXFSkAZqgJ3aqaknHeL9Rcvh7UEivQV8";

  // static String? token =
  //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA";

  // static String? token =
  //     "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3NDA3YjgwZmRkODEwZjUzYmU2OGE5NSIsInVzZXJJZCI6IjY3NDA3YjgwZmRkODEwZjUzYmU2OGE5NSIsImVtYWlsIjoiYW5pa2FfMzAwQGV4YW1wbGUuY29tIiwicHJvZmlsZVBpYyI6Imh0dHBzOi8vcmFuZG9tdXNlci5tZS9hcGkvcG9ydHJhaXRzL3dvbWVuLzk0LmpwZz9uYXQ9aW4iLCJuYW1lIjoiQW5pa2EiLCJ1c2VybmFtZSI6ImFuaWthXzMwMCIsImJpbyI6IkhpLCBJJ20gQW5pa2EuIEV4Y2l0ZWQgdG8gY29ubmVjdCEiLCJlZHVjYXRpb25MZXZlbCI6IlBhc3NvdXQiLCJ1bml2ZXJzaXR5IjoiRGVsaGkgVW5pdmVyc2l0eSIsImNvbGxlZ2UiOiJIaW5kdSBDb2xsZWdlIiwic2Nob29sIjoiU2FpbmlrIFNjaG9vbCIsInNlbWVzdGVyIjpudWxsLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOiIyMDAyIiwiYmlydGhkYXkiOiIyMDA5LTExLTMwVDE4OjMwOjAwLjAwMFoiLCJkYkluZGV4IjowLCJpYXQiOjE3MzIyNzkxNjh9.gRcD-2161J6ltUhKR7b6C24pd3_6VXc3taO8xZ0kCLE";

  //'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsInVzZXJJZCI6IjY3M2Y2MDdkNmZiYjY4YThjNTM2ODk2NyIsImVtYWlsIjoicHJhbmF2XzYwNUBleGFtcGxlLmNvbSIsInByb2ZpbGVQaWMiOiJodHRwczovL3JhbmRvbXVzZXIubWUvYXBpL3BvcnRyYWl0cy9tZW4vNTMuanBnP25hdD1pbiIsIm5hbWUiOiJQcmFuYXYiLCJ1c2VybmFtZSI6InByYW5hdl82MDUiLCJiaW8iOiJIaSwgSSdtIFByYW5hdi4gRXhjaXRlZCB0byBjb25uZWN0ISIsImVkdWNhdGlvbkxldmVsIjoiVW5pdmVyc2l0eSIsInVuaXZlcnNpdHkiOiJCYW5hcmFzIEhpbmR1IFVuaXZlcnNpdHkiLCJjb2xsZWdlIjoiSGluZHUgQ29sbGVnZSIsInNjaG9vbCI6Ik5hdm9kYXlhIFZpZHlhbGF5YSIsInNlbWVzdGVyIjoiU2VtIDIiLCJ1c2VyQ2xhc3MiOm51bGwsInllYXIiOm51bGwsImJpcnRoZGF5IjoiMjAwNS0wOS0wMlQxODozMDowMC4wMDBaIiwiZGJJbmRleCI6MCwiaWF0IjoxNzMyMjA2NzE3fQ.RnRHKaY82lze39GppuXsJHxWphfpA8sFkQXKUGCm5OA';

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

// List x= [https://chitchatpublicbucket.s3.ap-south-1.amazonaws.com/uploads/d27e3bba-a4a2-4467-b6e5-87a74c075c27-1743780638348.jpg, https://chitchatpublicbucket.s3.ap-south-1.amazonaws.com/uploads/03bc6208-0e7f-4860-816d-ab1d2fdd509d-1743780638383.jpg, https://chitchatpublicbucket.s3.ap-south-1.amazonaws.com/uploads/b38c5a19-809d-4578-ad0c-84fb06614592-1743780638383.mp4, https://chitchatpublicbucket.s3.ap-south-1.amazonaws.com/uploads/1c408b24-2024-438d-a1c6-624d480ec302-1743780638383.jpg, https://chitchatpublicbucket.s3.ap-south-1.amazonaws.com/uploads/301e104a-7449-4bbd-903e-455268398004-1743780638383.mp4]
  uploadChits(context) async {
    String? xtoken = await UserService.getAccessToken();

    String baseurl =
        AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
    ValueNotifier<FileUploadProgress> _progressNotifier =
        ValueNotifier<FileUploadProgress>(
      FileUploadProgress(fileName: 'Uploading...'),
    );

    S3Uploader uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: _progressNotifier,
    );
    bool uploadFinished = false;
    bool showErrorText = false;
    final List<String>? images = widget.files;

    if (images != null && images.isNotEmpty) {
      // Handle the selected image
      images.map((e) => print);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopScope(
            canPop: false,

            // Optional: Handle the attempted pop with onPopInvoked
            onPopInvokedWithResult: (didPop, res) {
              // This callback is triggered when a pop is attempted
              // didPop will be false since canPop is false

              // You could show a snackbar or provide feedback here
              if (!didPop) {
                setState(() {
                  showErrorText = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Please use the close button to dismiss this dialog')),
                );
              }
            },
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AlertDialog(
                  title: Column(
                    children: [
                      const Text(
                        'Uploading Chits...',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 10),
                      if (showErrorText)
                        const Text(
                          'Do not close this dialog until the upload is complete.',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Poppins'),
                        ),
                    ],
                  ),
                  content:
                      UploadProgressWidget(progressNotifier: _progressNotifier),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('OK'),
                      onPressed: () {
                        if (uploadFinished == true) {
                          Navigator.of(context).pop();
                          Navigator.pushReplacement(
                              context,
                              PageTransition(
                                  type: PageTransitionType.leftToRight,
                                  child: const HomePage()));
                        } else {
                          if (showErrorText == true) {
                            Navigator.of(context).pop();
                          } else {
                            setState(() {
                              showErrorText = true;
                            });
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
      List<String> files =
          await uploader.uploadFiles(files: images, compressionParams: {
        'width': 600,
        'quality': 95,
      });
      print(files);
      _progressNotifier.value = _progressNotifier.value.copyWith(
        stage: UploadStage.uploading,
        customStageText: "Processing...",
        customStageTextDetail: "saving on server...",
      );
      Map<String, dynamic> result = await StoryService.CreateStory(
        members: _selectedMemberIds.toList(),
        files: files,
        myGroupId: myGroupId,
        sendToAll: AllSelected,
      ).catchError((error) {
        print(error);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload this chits",
        );
        setState(() {
          uploadFinished = true;
        });
        return {'success': false, 'error': error.toString()};
      });
      if (result['success']) {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.completed,
          customStageText: "Uploaded Successfully",
          customStageTextDetail: "You are set! now you can close this dialog",
        );
        setState(() {
          // posts.add(result['data']);
          uploadFinished = true;
        });
        Navigator.of(context).pop();
        Navigator.pushReplacement(
            context,
            PageTransition(
                type: PageTransitionType.leftToRight, child: const HomePage()));
      } else {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload this chits",
        );
        setState(() {
          uploadFinished = true;
        });
      }
    }
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    String? userId = await UserService.getUserId();
    if (userId == null) {
      throw Exception('User ID is null');
    }
    String? xtoken = await UserService.getAccessToken();

    try {
      print("baseUrl: $baseUrl");
      print("token: $xtoken");
      final response = await http.get(
        Uri.parse('$baseUrl/chits/members/$userId'),
        headers: {'Authorization': 'Bearer $xtoken'},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print("jsonData: $jsonData");
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
          final member = Member(
            id: memberData['memberId'],
            name: memberData['memberName'],
            profilePic: memberData['memberProfilePic'],
          );
          uniqueMembers[member.id] = member;
        }

        setState(() {
          _members = uniqueMembers.values.toList();
          // myGroupId =
          //     (jsonData['usersOwnGroupMembers']?['myGroup']?["_id"]) ?? '';
          // if (myGroupId.isEmpty) {
          //   throw Exception('You dont have a group so you cannot post a chit.');
          // }

          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load members: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
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
    print(widget.files);
    if (_selectedMemberIds.isEmpty) {
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
    if (myGroupId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You dont have a group so you cannot post a chit.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    uploadChits(context);
    // Call the callback with selected member IDs
    onMemberSelection(_selectedMemberIds.toList());
  }

  void onMemberSelection(List<String> selectedMemberIds) {
    // Handle the selected member IDs
    // You can use the selectedMemberIds list to perform further actions
    // For example, you can navigate to a new screen or perform some other operation
    // based on the selected members.
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => CreateStoryPage(
    //       selectedMemberIds: selectedMemberIds,
    //       myGroupId: myGroupId,
    //     ),
    //   ),
    // );

    print(selectedMemberIds);
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
                  value: _selectedMemberIds.length == _members.length,
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
              style: const TextStyle(fontSize: 16, color: Colors.red),
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
                      fontSize: 18,
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
          style: TextStyle(fontSize: 16),
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
