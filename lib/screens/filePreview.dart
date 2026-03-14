import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/chat.dart';
import 'package:chitchat/screens/createStory.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/groups.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/story.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:page_transition/page_transition.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:vs_media_picker/vs_media_picker.dart';
import 'package:vs_story_designer/vs_story_designer.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:http/http.dart' as http;

abstract class FileFormat {
  const FileFormat(this.extension, {required this.mimeType});

  /// Extension of the file without the dot `.`.
  final String extension;

  /// The MIME type of the file format.
  final String mimeType;

  factory FileFormat.fromMimeType(String? mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return CoverExportFormat.jpg;
      case 'image/png':
        return CoverExportFormat.png;
      case 'image/webp':
        return CoverExportFormat.webp;
      case 'video/mp4':
        return VideoExportFormat.mp4;
      case 'video/quicktime':
        return VideoExportFormat.mov;
      case 'video/x-msvideo':
        return VideoExportFormat.avi;
      case 'image/gif':
        return const GifExportFormat();
      default:
        return const UnknownFileFormat();
    }
  }
}

/// Specify the file format to use when exporting the video
/// some common formats such as `avi`, `gif`, `mov` and `mp4` has a default constructor.
///
/// If you need another file format you can specify it like
/// ```dart
/// VideoExportFormat('mkv');
/// ```
class VideoExportFormat extends FileFormat {
  const VideoExportFormat(String extension, {required String mimeType})
      : super(extension, mimeType: mimeType);

  static const avi = VideoExportFormat('avi', mimeType: 'video/x-msvideo');
  static const gif = GifExportFormat();
  static const mov = VideoExportFormat('mov', mimeType: 'video/quicktime');
  static const mp4 = VideoExportFormat('mp4', mimeType: 'video/mp4');
}

/// To export the video as a GIF file
/// You can use this class to custom the [fps] of the exported GIF file.
class GifExportFormat extends VideoExportFormat {
  const GifExportFormat({this.fps = 10}) : super('gif', mimeType: 'image/gif');

  /// The frame rate of the GIF file.
  ///
  /// Defaults to `10`.
  final int fps;
}

/// Specify the file format to use when exporting the video cover
/// some common formats such as `jpg`, `png` and `webp` has a default constructor.
///
/// If you need another file format you can specify it like
/// ```dart
/// CoverExportFormat('jpeg');
/// ```
class CoverExportFormat extends FileFormat {
  const CoverExportFormat(String extension, {required String mimeType})
      : super(extension, mimeType: mimeType);

  static const jpg = CoverExportFormat('jpg', mimeType: 'image/jpeg');
  static const png = CoverExportFormat('png', mimeType: 'image/png');
  static const webp = CoverExportFormat('webp', mimeType: 'image/webp');
}

class UnknownFileFormat extends FileFormat {
  const UnknownFileFormat() : super('', mimeType: 'application/octet-stream');
}

class FilePreviewPage extends StatefulWidget {
  final List<PickedAssetModel> files;
  bool? isGroupPost = false;
  bool? isPost = false;
  String? myGroupId = "";
  bool? isMemory = false;

  FilePreviewPage(
      {super.key,
      required this.files,
      this.isGroupPost = false,
      this.isPost = false,
      this.isMemory = false,
      this.myGroupId = ""});

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

Set<String> _selectedMemberIds = {};
bool AllSelected = true;
String myGroupId = '';
List<Member> _members = [];
bool _isLoading = true;
bool _hasError = false;

String _errorMessage = '';

class _FilePreviewPageState extends State<FilePreviewPage> {
  int _currentIndex = 0;
  late List<File> editedFiles;
  late List<PickedAssetModel> _files;

  static String baseUrl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  PageController _pageController = PageController(initialPage: 0);

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
        final membersList = (jsonData['usersOwnGroupMembers']['myGroup']
                ?['members'] as List?) ??
            [];
        final watchList = (jsonData['membersOfUserWatchList']?['results']?[0]
                ?['members'] as List?) ??
            [];

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
          myGroupId =
              (jsonData['usersOwnGroupMembers']?['myGroup']?["_id"]) ?? '';
          if (myGroupId.isEmpty) {
            throw Exception('You dont have a group so you cannot post a chit.');
          }

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

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    editedFiles = List.from(widget.files.map((file) => File(file.path!)));
    _files = List.from(widget.files);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editedFiles.length == 1 && !widget.isPost! && !widget.isGroupPost!) {
        _editFile(editedFiles[0], 0);
      }
    });
  }

//ImageEditor(image: file.readAsBytesSync())
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
    Map<String, dynamic> result =
        AppVariables.get<Map<String, dynamic>>("posts") ?? {};
    final List<String>? images = editedFiles.map((f) => f.path).toList();

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
                  SnackBar(
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
                      Text(
                        'Uploading...',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 10),
                      if (showErrorText)
                        Text(
                          'Do not close this dialog until the upload is complete.',
                          style: const TextStyle(
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
                          Navigator.of(context).pop(result["data"]);
                        } else {
                          setState(() {
                            showErrorText = true;
                          });
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
      result = await PostService.createPost(
        files: files,
        myGroupId: widget.myGroupId ?? '',
        isGroupPost: widget.isGroupPost ?? false,
      ).catchError((error) {
        print(error);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload these ",
        );
        setState(() {
          uploadFinished = true;
        });
      });
      if (result['success']) {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.completed,
          customStageText: "Uploaded Successfully",
          customStageTextDetail: "You are set! now you can close this dialog",
        );
        setState(() {
          if (widget.isGroupPost == true) {
            AppVariables.update("group_posts", result['data']);
          } else {
            AppVariables.update("posts", result['data']);
          }
          uploadFinished = true;
        });
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

  uploadMemory(context) async {
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
    final List<String>? images = editedFiles.map((f) => f.path).toList();

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
                  SnackBar(
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
                      Text(
                        'Uploading...',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 10),
                      if (showErrorText)
                        Text(
                          'Do not close this dialog until the upload is complete.',
                          style: const TextStyle(
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
                          Navigator.of(context).pop();
                        } else {
                          setState(() {
                            showErrorText = true;
                          });
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
      Map<String, dynamic> result = await PostService.createMemories(
        files: files,
        myGroupId: widget.myGroupId ?? '',
      ).catchError((error) {
        print(error);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload this memory",
        );
        setState(() {
          uploadFinished = true;
        });
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
          AppVariables.update("memories", result['data']);
          uploadFinished = true;
        });
      } else {
        print(result);
        _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          customStageTextDetail: "can't upload this memory",
        );
        setState(() {
          uploadFinished = true;
        });
      }
    }
  }

  void _editFile(File file, int index) async {
    if (_isImage(file)) {
      final editedImage = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => VSStoryDesigner(
                  centerText: "Start Creating Your chit",
                  // fontFamilyList: const [
                  //   FontType.abrilFatface,
                  //   FontType.alegreya,
                  //   FontType.typewriter
                  // ],
                  mediaPath: file.path,
                  themeType:
                      ThemeType.light, // OPTIONAL, Default ThemeType.dark
                  onDone: (uri) async {
                    debugPrint(uri);
                    //Share.shareUri(Uri.file(uri));
                    //Navigator.pop(context, uri);
                    // Show bottom-right circular selector
                    if (editedFiles.length > 1 ||
                        widget.isPost! ||
                        widget.isGroupPost! ||
                        widget.isMemory!) {
                      Navigator.pop(context, uri);
                      return;
                    }
                    await showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.bottomSheetBackground,
                      barrierColor: Colors.black.withValues(alpha: 0.6),
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _OptionSelector(uri: [uri]),
                    );
                  },
                  middleBottomWidget: SizedBox(),
                  onDoneButtonStyle: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        'Done',
                        style: TextStyle(color: Colors.white),
                      )),
                )),
      );
      if (editedImage != null) {
        if (editedImage is Uint8List) {
          final tempDir = Directory.systemTemp;
          final tempFile = await File('${tempDir.path}/edited_image_$index.png')
              .writeAsBytes(editedImage);
          setState(() => editedFiles[index] = tempFile);
        } else {
          setState(() => editedFiles[index] = File(editedImage));
        }
      }
    } else if (_isVideo(file)) {
      final editedVideo = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => VideoEditor(
                  file: file,
                  totalFiles: editedFiles.length,
                  isPost: widget.isPost ?? false,
                  isGroupPost: widget.isGroupPost ?? false,
                  isMemory: widget.isMemory ?? false,
                )),
      );
      if (editedVideo != null) {
        setState(() => editedFiles[index] = File(editedVideo));
      }
    }
  }

  bool _isImage(File file) {
    return [".jpg", ".jpeg", ".png", ".gif", ".bmp", '.webp']
        .any((ext) => file.path.toLowerCase().endsWith(ext));
  }

  bool _isVideo(File file) {
    return [".mp4", ".mov", ".avi"]
        .any((ext) => file.path.toLowerCase().endsWith(ext));
  }

  void _showDeleteConfirmationDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Chit"),
        content: const Text("Are you sure you want to remove this chit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                try {
                  editedFiles.removeAt(index);
                  if (_files.isNotEmpty) {
                    _files.removeAt(index);
                  }
                } on Exception catch (e) {
                  // TODO
                  print("Error removing file: $e");
                }
              });
              Navigator.of(context).pop();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Preview & Edit",
          style: TextStyle(fontSize: 15, fontFamily: 'Poppins'),
        ),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Upload editedFiles list
              if (widget.isMemory == true) {
                uploadMemory(context);
              } else if (widget.isPost != null && widget.isPost != true) {
                print(
                    "Files to upload: ${editedFiles.map((f) => f.path).toList()}");
                await showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    barrierColor: Colors.black.withValues(alpha: 0.6),
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => _OptionSelector(
                        uri: editedFiles.map((f) => f.path).toList()));
                // Navigator.pushReplacement(
                //     context,
                //     MaterialPageRoute(
                //       builder: (context) => MemberSelectionPage(
                //           files: editedFiles.map((f) => f.path).toList()),
                //     ));
              } else {
                uploadChits(context);
              }
            },
            child: const Text("Next"),
          ),
          const SizedBox(
            width: 10,
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: editedFiles.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final file = editedFiles[index];
                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: _isImage(file)
                          ? Image.file(file, fit: BoxFit.contain)
                          : VideoPlayerWidget(videoFile: file),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        onPressed: () => _editFile(file, index),
                        child: const Icon(Icons.edit),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: editedFiles.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => setState(() {
                    _currentIndex = index;
                    _pageController.jumpToPage(index);
                  }),
                  child: GestureDetector(
                    onLongPress: () {
                      _showDeleteConfirmationDialog(index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _currentIndex == index
                                ? Colors.blue
                                : Colors.grey,
                            width: 3,
                          ),
                        ),
                        child: _isImage(editedFiles[index])
                            ? Image.file(editedFiles[index],
                                width: 60, height: 60)
                            : _files.length >= index &&
                                    _files[index].thumbnail != null
                                ? Stack(
                                    children: [
                                      Image.memory(
                                        _files[index].thumbnail!,
                                        width: 60,
                                        height: 60,
                                      ),
                                      const Icon(
                                        Icons.play_arrow,
                                        size: 60,
                                        color: Colors.blue,
                                      ),
                                    ],
                                  )
                                : const Icon(
                                    Icons.video_file,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final File videoFile;

  const VideoPlayerWidget({super.key, required this.videoFile});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) => setState(() {}));
    // _controller.play();
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoFile.path != widget.videoFile.path) {
      _controller.dispose();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
    _controller.pause();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.blue,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.black,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      color: Colors.white,
                      _controller.value.isPlaying
                          ? Icons.pause
                          : _controller.value.isCompleted
                              ? Icons.play_arrow
                              : Icons.play_arrow,
                    ),
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.replay_10,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final newPosition = _controller.value.position -
                          const Duration(seconds: 10);
                      _controller.seekTo(newPosition > Duration.zero
                          ? newPosition
                          : Duration.zero);
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.forward_10,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      final newPosition = _controller.value.position +
                          const Duration(seconds: 10);
                      _controller.seekTo(
                          newPosition < _controller.value.duration
                              ? newPosition
                              : _controller.value.duration);
                    },
                  ),
                ],
              ),
            ],
          )
        : const CircularProgressIndicator();
  }
}

// Placeholder VideoEditorPage

//-------------------//
//VIDEO EDITOR SCREEN//
//-------------------//
class VideoEditor extends StatefulWidget {
  const VideoEditor(
      {super.key,
      required this.file,
      required this.totalFiles,
      required this.isPost,
      required this.isGroupPost,
      required this.isMemory});

  final File file;
  final int totalFiles;
  final bool isPost;
  final bool isGroupPost;
  final bool isMemory;

  @override
  State<VideoEditor> createState() => _VideoEditorState();
}

class _VideoEditorState extends State<VideoEditor> {
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  final double height = 60;
  bool _canPop = false;

  late final VideoEditorController _controller = VideoEditorController.file(
    widget.file,
    minDuration: const Duration(seconds: 1),
    maxDuration: const Duration(seconds: 60),
  );

  @override
  void initState() {
    super.initState();
    _controller
        .initialize(aspectRatio: 9 / 16)
        .then((_) => setState(() {}))
        .catchError((error) {
      // handle minumum duration bigger than video duration error
      Navigator.pop(context);
    }, test: (e) => e is VideoMinDurationError);
  }

  @override
  void dispose() async {
    _exportingProgress.dispose();
    _isExporting.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );

  Future<void> trimVideo({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    void Function(double progress)? onProgress,
  }) async {
    final editor = VideoEditorBuilder(videoPath: inputPath)
        .trim(startTimeMs: startMs, endTimeMs: endMs);

    final result = await editor.export(
      outputPath: outputPath,
      onProgress: onProgress,
    );

    // result is a file path string
    print('Trimmed video output at: $result');
  }

  void _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;

    final startTime = _controller.startTrim.inSeconds;
    final duration = _controller.endTrim.inSeconds - startTime;

    final config = VideoFFmpegVideoEditorConfig(
      _controller,
      outputDirectory: (await getApplicationSupportDirectory()).path,
      commandBuilder: (config, videoPath, outputPath) {
        final command =
            '-i $videoPath -ss $startTime -t $duration -c copy -y $outputPath';
        return command;
      },
    );

    final execute = await config.getExecuteConfig();

    trimVideo(
      inputPath: config.controller.file.path,
      outputPath: execute.outputPath,
      startMs: _controller.startTrim.inMilliseconds,
      endMs: _controller.endTrim.inMilliseconds,
      onProgress: (p) => _exportingProgress.value = p,
    ).then((_) async {
      if (widget.totalFiles > 1) {
        Navigator.pop(context, execute.outputPath);
        return;
      }
      if (widget.totalFiles > 1 ||
          widget.isPost! ||
          widget.isGroupPost! ||
          widget.isMemory!) {
        Navigator.pop(context, execute.outputPath);
        return;
      }
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        barrierColor: Colors.black.withValues(alpha: 0.6),
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _OptionSelector(uri: [execute.outputPath]),
      );
    }).catchError((e) {
      _showErrorSnackBar('Error trimming video: $e');
    });
  }

  void _exportCover() async {
    final config = CoverFFmpegVideoEditorConfig(_controller);
    final execute = await config.getExecuteConfig();
    if (execute == null) {
      _showErrorSnackBar("Error on cover exportation initialization.");
      return;
    }

    // await ExportService.runFFmpegCommand(
    //   execute,
    //   onError: (e, s) => _showErrorSnackBar("Error on cover exportation :("),
    //   onCompleted: (cover) {
    //     if (!mounted) return;

    //     showDialog(
    //       context: context,
    //       builder: (_) => CoverResultPopup(cover: cover),
    //     );
    //   },
    // );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Future.delayed(Duration.zero, () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Exit"),
              content: const Text("Are you sure you want to exit?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("No"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    setState(() => _canPop = true);
                    Navigator.pop(context); // Close screen
                  },
                  child: const Text("Yes"),
                ),
              ],
            ),
          );
        });
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _controller.initialized
            ? SafeArea(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _topNavBar(),
                        Expanded(
                          child: DefaultTabController(
                            length: 1,
                            child: Column(
                              children: [
                                Expanded(
                                  child: TabBarView(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CropGridViewer.preview(
                                              controller: _controller),
                                          AnimatedBuilder(
                                            animation: _controller.video,
                                            builder: (_, __) => AnimatedOpacity(
                                              opacity:
                                                  _controller.isPlaying ? 0 : 1,
                                              duration: kThemeAnimationDuration,
                                              child: GestureDetector(
                                                onTap: _controller.video.play,
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.play_arrow,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      //CoverViewer(controller: _controller)
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 200,
                                  margin: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    children: [
                                      const TabBar(
                                        tabs: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Padding(
                                                    padding: EdgeInsets.all(5),
                                                    child: Icon(
                                                        Icons.content_cut)),
                                                Text('Trim')
                                              ]),
                                          // Row(
                                          //   mainAxisAlignment:
                                          //       MainAxisAlignment.center,
                                          //   children: [
                                          //     Padding(
                                          //         padding: EdgeInsets.all(5),
                                          //         child: Icon(
                                          //           Icons.video_label,
                                          //           color: Colors.white,
                                          //         )),
                                          //     Text('Cover',
                                          //         style: TextStyle(
                                          //             fontSize: 12,
                                          //             color: Colors.white)),
                                          //   ],
                                          // ),
                                        ],
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          children: [
                                            Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: _trimSlider(),
                                            ),
                                            // _coverSelection(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: _isExporting,
                                  builder: (_, bool export, Widget? child) =>
                                      AnimatedSize(
                                    duration: kThemeAnimationDuration,
                                    child: export ? child : null,
                                  ),
                                  child: AlertDialog(
                                    title: ValueListenableBuilder(
                                      valueListenable: _exportingProgress,
                                      builder: (_, double value, __) => Text(
                                        "Exporting video ${(value * 100).ceil()}%",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _topNavBar() {
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: 'Leave editor',
              ),
            ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: IconButton(
                onPressed: () =>
                    _controller.rotate90Degrees(RotateDirection.left),
                icon: const Icon(Icons.rotate_left, color: Colors.white),
                tooltip: 'Rotate unclockwise',
              ),
            ),
            Expanded(
              child: IconButton(
                onPressed: () =>
                    _controller.rotate90Degrees(RotateDirection.right),
                icon: const Icon(Icons.rotate_right, color: Colors.white),
                tooltip: 'Rotate clockwise',
              ),
            ),
            // Expanded(
            //   child: IconButton(
            //     onPressed: () => Navigator.push(
            //       context,
            //       MaterialPageRoute<void>(
            //         builder: (context) => CropPage(controller: _controller),
            //       ),
            //     ),
            //     icon: const Icon(Icons.crop),
            //     tooltip: 'Open crop screen',
            //   ),
            // ),
            const VerticalDivider(endIndent: 22, indent: 22),
            Expanded(
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _exportVideo,
                    child: const Text("Next"),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatter(Duration duration) => [
        duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
        duration.inSeconds.remainder(60).toString().padLeft(2, '0')
      ].join(":");

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _controller.video,
        ]),
        builder: (_, __) {
          final int duration = _controller.videoDuration.inSeconds;
          final double pos = _controller.trimPosition * duration;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: height / 4),
            child: Row(children: [
              Text(formatter(Duration(seconds: pos.toInt()))),
              const Expanded(child: SizedBox()),
              AnimatedOpacity(
                opacity: _controller.isTrimming ? 1 : 0,
                duration: kThemeAnimationDuration,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(formatter(_controller.startTrim)),
                  const SizedBox(width: 10),
                  Text(formatter(_controller.endTrim)),
                ]),
              ),
            ]),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(vertical: height / 4, horizontal: 15),
        child: TrimSlider(
          controller: _controller,
          height: height,
          horizontalMargin: height / 4,
          child: TrimTimeline(
            controller: _controller,
            padding: const EdgeInsets.only(top: 10),
          ),
        ),
      )
    ];
  }

  Widget _coverSelection() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(15),
          child: CoverSelection(
            controller: _controller,
            size: height + 10,
            quantity: 12,
            selectedCoverBuilder: (cover, size) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  cover,
                  Icon(
                    Icons.check_circle,
                    color: const CoverSelectionStyle().selectedBorderColor,
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OptionSelector extends StatefulWidget {
  final List<String> uri;
  const _OptionSelector({required this.uri});

  @override
  State<_OptionSelector> createState() => _OptionSelectorState();
}

class _OptionSelectorState extends State<_OptionSelector> {
  final Map<String, dynamic>? profileDetails =
      AppVariables.get<Map<String, dynamic>>('profile');
  FriendCircleGroup? groupDetails;

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
    final List<String> images = widget.uri;

    if (images.isNotEmpty) {
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
                  SnackBar(
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
                      Text(
                        'Uploading Chits...',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Poppins'),
                      ),
                      const SizedBox(height: 10),
                      if (showErrorText)
                        Text(
                          'Do not close this dialog until the upload is complete.',
                          style: const TextStyle(
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
                          Navigator.pushReplacement(
                              context,
                              PageTransition(
                                  type: PageTransitionType.leftToRight,
                                  child: HomePage()));
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
        members: _members.map((m) => m.id).toList(),
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

  @override
  void initState() {
    super.initState();
    // _controller.initialize();
    // _fetchMembers();
    try {
      if (profileDetails!['myGroup'] != null) {
        groupDetails =
            GroupsService.buildFriendCircleGroup(profileDetails!['myGroup']);
      }
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      decoration: const BoxDecoration(
        color: Color.fromARGB(97, 0, 0, 0),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          const Text("Share To",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (groupDetails != null)
                _circleButton(
                  icon: Icon(Icons.groups_2_outlined, color: Colors.white),
                  image: groupDetails!.groupData['GroupProfilePic'],
                  label: "Group",
                  onTap: () {
                    // Save file logic here
                    Navigator.pushAndRemoveUntil(
                        context,
                        PageTransition(
                          type: PageTransitionType.leftToRight,
                          child: ChatScreen(data: widget.uri),
                        ),
                        (route) => route.isFirst);
                  },
                ),
              _circleButton(
                icon: Icon(Icons.share, color: Colors.redAccent),
                label: "All",
                onTap: () {
                  uploadChits(context);
                },
              ),
              _circleButton(
                icon: Icon(Icons.send, color: Colors.lightGreenAccent),
                label: "Members",
                onTap: () {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemberSelectionPage(
                            files: widget.uri is List<String>
                                ? widget.uri
                                : [widget.uri.toString()]),
                      ));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required Widget icon,
    String? image,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Try loading image
                if (image != null)
                  ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: image,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (context, error, stackTrace) {
                        return CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white10,
                          child: icon,
                        );
                      },
                    ),
                  )
                else
                  // No image provided, show icon directly
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white10,
                    child: icon,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
