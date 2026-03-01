import 'dart:async';
import 'dart:io';

import 'package:better_open_file/better_open_file.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:chitchat/constants/colors.dart';
import 'package:chitchat/screens/filePreview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:vs_media_picker/vs_media_picker.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

class CreatePost {
  // late StreamSubscription<MediaCapture?> _captureStateSubscription;

  static ScrollController _scrollController2 = ScrollController();

  static dynamic show(BuildContext context,
      {bool isGroupPost = false,
      bool isPost = true,
      bool isMemory = false,
      String? message,
      required String? myGroupId}) {
    ValueNotifier<bool> isNextButtonVisible = ValueNotifier(false);
    List<PickedAssetModel> selectedFiles = <PickedAssetModel>[];
    if (isMemory) {
      ImagePicker picker = ImagePicker();
      BuildContext rootcontext = context;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: false,
        builder: (context) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.bottomSheetBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border:
                  Border.all(color: AppColors.bottomSheetBorder, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[500],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  _MediaTile(
                    icon: Icons.image_rounded,
                    color: Colors.blue,
                    title: 'Pick Image',
                    onTap: () async {
                      Navigator.pop(context);

                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);

                      if (image == null) return;

                      final asset = PickedAssetModel(
                        id: image.path,
                        path: image.path,
                        type: 'image',
                      );

                      Navigator.push(
                        rootcontext,
                        MaterialPageRoute(
                          builder: (context) => FilePreviewPage(
                            files: [asset],
                            isGroupPost: isGroupPost,
                            isPost: isPost,
                            isMemory: isMemory,
                            myGroupId: myGroupId,
                          ),
                        ),
                      );
                    },
                  ),

                  _MediaTile(
                    icon: Icons.videocam_rounded,
                    color: Colors.red,
                    title: 'Pick Video',
                    onTap: () async {
                      Navigator.pop(context);

                      final XFile? video =
                          await picker.pickVideo(source: ImageSource.gallery);

                      if (video == null) return;

                      final asset = PickedAssetModel(
                        id: video.path,
                        path: video.path,
                        type: 'video',
                      );

                      Navigator.push(
                        rootcontext,
                        MaterialPageRoute(
                          builder: (context) => FilePreviewPage(
                            files: [asset],
                            isGroupPost: isGroupPost,
                            isPost: isPost,
                            isMemory: isMemory,
                            myGroupId: myGroupId,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromRGBO(0, 0, 0, 1),
      builder: (context) => Stack(
        children: [
          VSMediaPicker(
            maxPickImages: 100,
            gridViewController: _scrollController2,
            singlePick: isMemory ? true : false,
            onlyImages: false,
            appBarColor: Colors.black,
            gridViewPhysics: const ScrollPhysics(),
            pathList: (path) {
              if (path.isNotEmpty) {
                print("path: ${path.map((e) => e.type).toList()}");
              }
              selectedFiles = path;
              isNextButtonVisible.value = selectedFiles.isNotEmpty;
            },
            appBarLeadingWidget: Padding(
              padding: const EdgeInsets.only(bottom: 15, right: 15),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.2,
                            )),
                        child: const Row(
                          children: [
                            Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    RepaintBoundary(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: isNextButtonVisible,
                        builder: (context, isVisible, child) {
                          return isVisible
                              ? InkWell(
                                  onTap: () async {
                                    await Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => FilePreviewPage(
                                                files: selectedFiles,
                                                isGroupPost: isGroupPost,
                                                isPost: isPost,
                                                isMemory: isMemory,
                                                myGroupId: myGroupId,
                                              )),
                                    );
                                    // Navigator.pop(context);
                                    // showModalBottomSheet(
                                    //   context: context,
                                    //   isScrollControlled: true,
                                    //   isDismissible: false,
                                    //   enableDrag: false,
                                    //   backgroundColor: Colors.black,
                                    //   builder: (context) =>
                                    //       FlutterStoryEditor(
                                    //     controller: controller,
                                    //     captionController:
                                    //         _captionController,
                                    //     selectedFiles: selectedFiles
                                    //         .map(
                                    //           (e) =>
                                    //               e.file ??
                                    //               File(e.path ?? ""),
                                    //         )
                                    //         .toList(),
                                    //     onSaveClickListener: (files) {
                                    //       // Handle save click logic here
                                    //       print(
                                    //         "Selected files: ${files.map((e) => e.path).toList()}",
                                    //       );
                                    //     },
                                    //   ),
                                    // );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.2,
                                        )),
                                    child: const Row(
                                      children: [
                                        Text(
                                          'Next',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w400),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Text(
                  message ?? 'Select files to send',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to save the file to the gallery
  List<String> _filePaths = [];
  void _saveToGallery(String filePath, bool isVideo) {
    // Check if the file path is already saved to avoid duplicates
    if (!_filePaths.contains(filePath)) {
      _filePaths.add(filePath);
    } else {
      debugPrint('File already saved: $filePath');
      return;
    }
    if (isVideo) {
      GallerySaver.saveVideo(filePath).then((success) {
        if (success == true) {
          debugPrint('Video saved to gallery: $filePath');
        } else {
          debugPrint('Failed to save video: $filePath');
        }
      });
    } else {
      GallerySaver.saveImage(filePath).then((success) {
        if (success == true) {
          debugPrint('Image saved to gallery: $filePath');
        } else {
          debugPrint('Failed to save image: $filePath');
        }
      });
    }
  }

  // Function to preview the file
  void _previewFile(String filePath) {
    OpenFile.open(filePath);
  }
}

class _MediaTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  const _MediaTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      onTap: onTap,
    );
  }
}
