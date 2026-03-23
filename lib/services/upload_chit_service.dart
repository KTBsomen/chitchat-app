import 'package:flutter/material.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/posts.dart';
import 'package:chitchat/services/story.dart';
import 'package:chitchat/screens/home.dart';
import 'package:page_transition/page_transition.dart';

enum ChitType { post, groupPost, memory, story }

class UploadChitService {
  static Future<void> upload({
    required BuildContext context,
    required List<String> filePaths,
    required ChitType type,
    String? groupId,
    List<String>? members,
    bool sendToAll = false,
  }) async {
    final String baseurl = AppVariables.get<String>('baseurl')!.trim();

    final ValueNotifier<FileUploadProgress> progressNotifier =
        ValueNotifier<FileUploadProgress>(
      FileUploadProgress(fileName: 'Uploading...'),
    );

    final S3Uploader uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: progressNotifier,
    );

    bool uploadFinished = false;
    bool showErrorText = false;
    Map<String, dynamic> result = {};

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, res) {
            if (!didPop) {
              showErrorText = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please wait for the upload to complete.')),
              );
            }
          },
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AlertDialog(
                title: Column(
                  children: [
                    Text(
                      _getDialogTitle(type),
                      style: const TextStyle(
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
                    UploadProgressWidget(progressNotifier: progressNotifier),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      if (uploadFinished) {
                        Navigator.of(dialogContext).pop();
                        // Navigate to HomePage and clear stack
                        Navigator.pushAndRemoveUntil(
                          context,
                          PageTransition(
                            type: PageTransitionType.leftToRight,
                            child: const HomePage(),
                          ),
                          (route) => false,
                        );
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

    try {
      // 1. Upload files to S3
      final List<String> uploadedFiles =
          await uploader.uploadFiles(files: filePaths, compressionParams: {
        'width': 600,
        'quality': 95,
      });

      progressNotifier.value = progressNotifier.value.copyWith(
        stage: UploadStage.uploading,
        customStageText: "Processing...",
        customStageTextDetail: "Saving on server...",
      );

      // 2. Determine Group ID
      final effectiveGroupId =
          groupId ?? AppVariables.get<String>('myGroupId') ?? '';

      // 3. Call specific service based on ChitType
      switch (type) {
        case ChitType.post:
        case ChitType.groupPost:
          result = await PostService.createPost(
            files: uploadedFiles,
            myGroupId: effectiveGroupId,
            isGroupPost: type == ChitType.groupPost,
          );
          if (result['success']) {
            final key = type == ChitType.groupPost ? "group_posts" : "posts";
            AppVariables.update(key, result['data']);
          }
          break;
        case ChitType.memory:
          result = await PostService.createMemories(
            files: uploadedFiles,
            myGroupId: effectiveGroupId,
          );
          if (result['success']) {
            AppVariables.update("memories", result['data']);
          }
          break;
        case ChitType.story:
          result = await StoryService.CreateStory(
            members: members ?? [],
            files: uploadedFiles,
            myGroupId: effectiveGroupId,
            sendToAll: sendToAll,
          );
          break;
      }

      if (result['success'] == true) {
        progressNotifier.value = progressNotifier.value.copyWith(
          stage: UploadStage.completed,
          customStageText: "Uploaded Successfully",
          customStageTextDetail: "You are set! Now you can close this dialog",
        );
      } else {
        throw Exception(result['error'] ?? "Upload failed on server");
      }
    } catch (e) {
      print("Upload error: $e");
      progressNotifier.value = progressNotifier.value.copyWith(
        stage: UploadStage.failed,
        customStageTextDetail: "Can't upload: ${e.toString()}",
      );
    } finally {
      uploadFinished = true;
    }
  }

  static String _getDialogTitle(ChitType type) {
    switch (type) {
      case ChitType.post:
      case ChitType.groupPost:
        return 'Uploading Post...';
      case ChitType.memory:
        return 'Uploading Memory...';
      case ChitType.story:
        return 'Uploading Chits...';
    }
  }
}
